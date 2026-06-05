import json
import os
import re
import time
import traceback
import uuid
from typing import Any, Dict

from celery.utils.log import get_task_logger

# Prevent default app initialization during import so we can control app context here.
os.environ.setdefault("SKIP_DEFAULT_APP_INIT", "1")

from google.api_core import exceptions as google_exceptions

from backend.celery_config import celery
from backend.data.superhero_matrix import (
    apply_nemesis_override as _superhero_apply_nemesis,
)
from backend.data.superhero_matrix import pick_pairing as _superhero_pick_pairing
from backend.database import db
from backend.models.character import Character
from backend.models.story import Story
from backend.models.user import User
from backend.services.openrouter_story_generator import OpenRouterStoryGenerator
from backend.services.prompt_service import PromptService
from backend.services.prompt_versioning import resolve as _resolve_prompt_version
from backend.services.story_generation_service import StoryGenerationService
from backend.services.story_service import (
    AGE_CONSTRAINTS,
    AdvancedStoryEngine,
    _build_bedtime_prompt,
    _build_learning_to_read_prompt,
    _build_prior_adventures_block,
    _build_rhyme_time_prompt,
    _get_age_band,
    _safe_extract_title_and_gem,
    pseudonymize_hero_name,
    restore_hero_name,
)


def _is_superhero_theme(theme: str | None) -> bool:
    """True when the request is for the ages-3-5 Superhero Mode chain."""
    return isinstance(theme, str) and theme.strip().lower() == "superhero"


logger = get_task_logger(__name__)

# Lazy app initialization to avoid circular imports
_flask_app = None


def get_flask_app():
    """Lazy initialization of Flask app to avoid circular imports."""
    global _flask_app
    if _flask_app is None:
        from backend.app import create_app  # lazy import to break circular dependency

        _config_name = os.getenv("FLASK_CONFIG") or "dev"
        if _config_name not in {"dev", "prod", "production", "testing"}:
            _config_name = "dev"
        _flask_app = create_app(_config_name)
    return _flask_app


def _fallback_story(
    theme: str, character_name: str | dict, companion: str = None
) -> str:
    """Local fallback when all AI providers fail — returns valid JSON so tags never leak to the UI."""
    if isinstance(character_name, dict):
        name = character_name.get("name", "Hero")
    else:
        name = character_name

    theme_plain = theme.rstrip("! ").lower()
    theme_title = theme.rstrip("! ").title()
    comp = f" with their friend {companion}" if companion else ""

    return json.dumps(
        {
            "title": f"The {theme_title} Adventure",
            "pages": [
                {
                    "text": f"One bright morning, {name}{comp} set off on a wonderful {theme_plain} adventure. The sun was warm and anything felt possible."
                },
                {
                    "text": f"{name} took a deep breath and walked forward with a brave and curious heart. Every step brought something new and exciting to discover."
                },
                {
                    "text": f"Along the way{comp}, {name} found that the best adventures happen when you are kind and brave. Challenges became fun puzzles to solve together."
                },
                {
                    "text": f"When the adventure was done, {name} came home with a happy heart. Tomorrow there would be a whole new adventure waiting — and {name} could not wait!"
                },
            ],
        }
    )


def _classify_provider_failure(
    exc: Exception | None = None, message: str | None = None
) -> str:
    raw_text = ""
    if exc is not None:
        raw_text = str(exc).strip()
    elif message:
        raw_text = str(message).strip()

    lowered = raw_text.lower()
    if (
        isinstance(exc, google_exceptions.ResourceExhausted)
        or "quota" in lowered
        or "resourceexhausted" in lowered
    ):
        return "429"
    if (
        "401" in lowered
        or "unauthorized" in lowered
        or "invalid api key" in lowered
        or "api key not valid" in lowered
    ):
        return "401"
    if "openrouter_api_key not set" in lowered:
        return "no_key"
    if "timeout" in lowered:
        return "timeout"
    if not raw_text:
        return "unknown"
    return raw_text.splitlines()[0][:80]


def _resolve_story_provider() -> str:
    """Read the MT-171 provider switch.

    Looks at the Flask app config first (set in app.py from STORY_GEN_PROVIDER
    + the Config class default), falling back to the env var directly so this
    helper still works outside an app context (Celery worker bootstrap, scripts).
    """
    try:
        from flask import current_app  # local import; Celery may not have app context

        provider = current_app.config.get("STORY_GEN_PROVIDER")
    except Exception:
        provider = None
    if not provider:
        provider = os.environ.get("STORY_GEN_PROVIDER") or "gemini"
    provider = str(provider).strip().lower()
    if provider not in ("gemini", "openrouter", "auto"):
        logger.warning(
            "STORY_GEN_PROVIDER=%r is not a recognized value; defaulting to 'gemini'.",
            provider,
        )
        provider = "gemini"
    return provider


# PERF-01 slice 2: per-story partial-state emission for /task-status polling.
# As Gemini's stream API yields chunks, the accumulated story text is written
# to Redis under `partial_story:<task_id>`. Slice 3 will surface it through
# /task-status so clients see story progress within ~5s of the model starting
# to respond instead of waiting for the full ~55-110s generation.
# Best-effort: a Redis hiccup never aborts generation.
_PARTIAL_STORY_TTL_SECONDS = 600  # outlives the longest plausible generation


def _get_partial_story_redis():
    """Connect to Redis using the same env-var pattern as ai_quota._get_redis."""
    redis_url = os.getenv("REDIS_URL") or os.getenv("REDIS_PRIVATE_URL")
    if not redis_url:
        return None
    try:
        import redis as redis_lib

        client = redis_lib.from_url(redis_url, socket_connect_timeout=1)
        client.ping()
        return client
    except Exception as exc:
        logger.warning(
            "partial-story Redis unavailable (%s); streaming will be silent", exc
        )
        return None


def _emit_partial_story(task_id: str | None, accumulated_text: str) -> None:
    """Write accumulated streamed text for `task_id` to Redis. Best-effort."""
    if not task_id:
        return
    client = _get_partial_story_redis()
    if client is None:
        return
    try:
        client.setex(
            f"partial_story:{task_id}", _PARTIAL_STORY_TTL_SECONDS, accumulated_text
        )
    except Exception as exc:
        logger.debug("partial-story write skipped (%s)", exc)


def _clear_partial_story(task_id: str | None) -> None:
    """Drop the partial-state key. Best-effort — TTL would clean up otherwise."""
    if not task_id:
        return
    client = _get_partial_story_redis()
    if client is None:
        return
    try:
        client.delete(f"partial_story:{task_id}")
    except Exception as exc:
        logger.debug("partial-story clear skipped (%s)", exc)


def _try_gemini(
    prompt: str,
    user_tier: str | None,
    provider_sequence: list[str],
    task_id: str | None = None,
) -> str | None:
    """Attempt Gemini story generation. Returns text on success, None on failure
    (any failure mode appends a tagged entry to provider_sequence).

    When `task_id` is provided, uses the streaming API and emits accumulated
    text to Redis as each chunk arrives — clients polling /task-status see
    partial progress (PERF-01). Without `task_id`, uses the single blocking
    call (legacy/regeneration call sites without a task context).
    """
    try:
        logger.info("Attempting story generation with Gemini...")
        gemini_generator = StoryGenerationService(user_tier=user_tier)
        if task_id:
            chunks: list[str] = []
            for chunk in gemini_generator.generate_story_stream(prompt):
                chunks.append(chunk)
                _emit_partial_story(task_id, "".join(chunks))
            story_text = "".join(chunks) or None
            if not story_text:
                # Stream produced nothing (safety block or empty model output).
                # Drop the stale partial key and fall through to the
                # non-streaming call so existing retry / fallback semantics
                # still apply.
                _clear_partial_story(task_id)
                logger.info("Stream returned empty; falling back to non-streaming call")
                story_text = gemini_generator.generate_story(prompt)
        else:
            story_text = gemini_generator.generate_story(prompt)
        if story_text and not story_text.startswith("Sorry"):
            logger.info("Successfully generated story with Gemini.")
            provider_sequence.append("gemini(success)")
            return story_text

        logger.warning("Gemini returned a 'Sorry' message.")
        provider_sequence.append(
            f"gemini(fail:{_classify_provider_failure(message=story_text)})"
        )
    except google_exceptions.ResourceExhausted as exc:
        logger.warning("Gemini is rate-limited.")
        provider_sequence.append(f"gemini(fail:{_classify_provider_failure(exc=exc)})")
    except Exception as exc:
        logger.exception("Gemini failed with an unexpected error.")
        provider_sequence.append(f"gemini(fail:{_classify_provider_failure(exc=exc)})")
    return None


def _try_openrouter(
    prompt: str, user_tier: str | None, provider_sequence: list[str]
) -> str | None:
    """Attempt OpenRouter story generation. Returns text on success, None on
    failure (any failure mode appends a tagged entry to provider_sequence)."""
    if not os.getenv("OPENROUTER_API_KEY"):
        logger.warning("OPENROUTER_API_KEY not set. Skipping OpenRouter.")
        provider_sequence.append("openrouter(fail:no_key)")
        return None

    try:
        logger.info("Attempting story generation with OpenRouter...")
        openrouter_generator = OpenRouterStoryGenerator(user_tier=user_tier)
        story_text = openrouter_generator.generate_story(prompt)
        if story_text and not story_text.startswith("Sorry"):
            logger.info("Successfully generated story with OpenRouter.")
            provider_sequence.append("openrouter(success)")
            return story_text

        logger.warning("OpenRouter returned a 'Sorry' message.")
        provider_sequence.append(
            f"openrouter(fail:{_classify_provider_failure(message=story_text)})"
        )
    except Exception as exc:
        logger.exception("OpenRouter failed.")
        provider_sequence.append(
            f"openrouter(fail:{_classify_provider_failure(exc=exc)})"
        )
    return None


def _generate_story_text_with_metadata(
    prompt: str,
    theme: str,
    character_name: str,
    companion: str = None,
    user_tier: str | None = None,
    task_id: str | None = None,
) -> tuple[str, str, list[str]]:
    """Generate story text with tier-aware provider sequencing (MT-171 Phase 1).

    Sequencing is controlled by STORY_GEN_PROVIDER (app.config + env):
        'gemini'     — Gemini -> OpenRouter -> static  (legacy default)
        'openrouter' — OpenRouter -> static            (skip Gemini; ToS-compliant)
        'auto'       — OpenRouter -> Gemini -> static  (rollback-safe migration)

    `task_id` forwards to `_try_gemini` for PERF-01 streaming. When provided,
    Gemini uses its streaming API and writes partial story text to Redis.
    OpenRouter generation is not streamed (slice 2 scope).

    The returned ``provider_sequence`` list traces every attempt for observability
    (success/fail reasons surface in the audit_log + Sentry breadcrumbs).
    """
    provider_sequence: list[str] = []
    provider_choice = _resolve_story_provider()

    if provider_choice == "openrouter":
        # OpenRouter only — do NOT fall back to Gemini (Phase 1 target order;
        # Gemini's child-directed-app ToS is the whole reason for the flag).
        text = _try_openrouter(prompt, user_tier, provider_sequence)
        if text is not None:
            return text, "openrouter", provider_sequence

    elif provider_choice == "auto":
        # Rollback-safe: try OpenRouter first; if it fails for any reason, fall
        # back to Gemini so a flipped flag never produces a static fallback
        # when Gemini would have worked. Use during migration validation only.
        text = _try_openrouter(prompt, user_tier, provider_sequence)
        if text is not None:
            return text, "openrouter", provider_sequence

        text = _try_gemini(prompt, user_tier, provider_sequence, task_id=task_id)
        if text is not None:
            return text, "gemini", provider_sequence

    else:
        # 'gemini' — legacy default: Gemini first, OpenRouter as soft fallback.
        text = _try_gemini(prompt, user_tier, provider_sequence, task_id=task_id)
        if text is not None:
            return text, "gemini", provider_sequence

        text = _try_openrouter(prompt, user_tier, provider_sequence)
        if text is not None:
            return text, "openrouter", provider_sequence

    logger.warning(
        "All story generation providers failed. Returning local static fallback."
    )
    provider_sequence.append("static")
    return (
        _fallback_story(theme, character_name, companion),
        "static",
        provider_sequence,
    )


def _generate_story_text(
    prompt: str,
    theme: str,
    character_name: str,
    companion: str = None,
    user_tier: str | None = None,
) -> str:
    """
    Generate story text with a tiered fallback system.
    1. Try Gemini via StoryGenerationService.
    2. On rate limit error, fall back to a free OpenRouter model.
    3. If all else fails, use a local static story.
    """
    story_text, _provider_name, _provider_sequence = _generate_story_text_with_metadata(
        prompt,
        theme,
        character_name,
        companion,
        user_tier=user_tier,
    )
    return story_text


def _extract_page_end_word(page_text: str) -> str:
    """Extract the last meaningful word from a page for rhyme checks."""
    if not page_text:
        return ""
    tokens = re.findall(r"[a-zA-Z']+", page_text.lower())
    if not tokens:
        return ""
    return tokens[-1].strip("'")


def _extract_sentence_end_words(page_text: str) -> list[str]:
    """Extract sentence-ending words from a page."""
    if not page_text:
        return []
    sentence_chunks = re.split(r"[.!?]+", page_text)
    words: list[str] = []
    for chunk in sentence_chunks:
        tokens = re.findall(r"[a-zA-Z']+", chunk.lower())
        if tokens:
            words.append(tokens[-1].strip("'"))
    return words


def _rhyme_key(word: str) -> str:
    """Get a simple phonetic-ish tail used for lightweight rhyme matching."""
    clean = re.sub(r"[^a-z]", "", word.lower())
    clean = clean.replace("y", "i")  # Normalize y to i for phonetic matching
    if len(clean) < 2:
        return clean
    if clean.endswith("e") and len(clean) > 3:
        clean = clean[:-1]
    # Use substring from last vowel to end (e.g., "cat" -> "at", "sun" -> "un")
    match = re.search(r"[aeiou][a-z]*$", clean)
    if match:
        return match.group(0)
    return clean[-2:]


def _words_rhyme(word_a: str, word_b: str) -> bool:
    if not word_a or not word_b:
        return False
    key_a = _rhyme_key(word_a)
    key_b = _rhyme_key(word_b)
    return len(key_a) >= 2 and key_a == key_b


def _is_ltr_rhyme_quality_ok(pages: list[str], min_pair_ratio: float = 0.6) -> bool:
    """Check that LTR output has clear rhyming.

    Accept either:
    1) cross-page ending couplets (pages 1&2, 3&4, ...), or
    2) strong within-page sentence-ending rhymes.
    """
    end_words = [
        _extract_page_end_word(page) for page in pages if page and page.strip()
    ]
    if len(end_words) < 2:
        return False

    pair_checks = 0
    rhyme_hits = 0
    for i in range(0, len(end_words) - 1, 2):
        pair_checks += 1
        if _words_rhyme(end_words[i], end_words[i + 1]):
            rhyme_hits += 1

    cross_page_ok = pair_checks > 0 and (rhyme_hits / pair_checks) >= min_pair_ratio

    in_page_checks = 0
    in_page_hits = 0
    for page in pages:
        sentence_end_words = _extract_sentence_end_words(page)
        if len(sentence_end_words) < 2:
            continue
        in_page_checks += 1
        if _words_rhyme(sentence_end_words[-2], sentence_end_words[-1]):
            in_page_hits += 1

    in_page_ok = (
        in_page_checks > 0 and (in_page_hits / in_page_checks) >= min_pair_ratio
    )
    return cross_page_ok or in_page_ok


def _post_process_ltr_pages(
    pages: list[str],
    target_pages: int = 5,
    max_words: int = 25,
    sentences_per_page: int = 2,
) -> list[str]:
    """Programmatically split LTR output into ≥target_pages × ≤max_words/page.

    Used as a deterministic fallthrough after the validation+retry loop exhausts
    on Sprout LTR mode (Gemini-flash routinely compresses LTR output to 2-3 dense
    pages even after explicit retry feedback). Splits on sentence boundaries
    first (preserves AABB couplet pairing), falls back to comma boundaries for
    sentences that exceed max_words on their own.
    """
    if not pages:
        return pages

    body = " ".join(p.strip() for p in pages if p and p.strip())
    if not body:
        return pages

    sentence_parts = re.split(r"(?<=[.!?])(?=\s)|(?<=[.!?][\"')\]])(?=\s)", body)
    sentences = [s.strip() for s in sentence_parts if s.strip()]
    if not sentences:
        return pages

    def _split_oversize_sentence(sent: str) -> list[str]:
        """Split a single >max_words sentence on commas, then word boundaries."""
        chunks = [c.strip() for c in sent.split(",") if c.strip()]
        out: list[str] = []
        buf: list[str] = []
        buf_words = 0
        for chunk in chunks:
            cw = len(chunk.split())
            if cw > max_words:
                if buf:
                    out.append(", ".join(buf))
                    buf, buf_words = [], 0
                words = chunk.split()
                for i in range(0, len(words), max_words):
                    out.append(" ".join(words[i : i + max_words]))
                continue
            if buf and buf_words + cw > max_words:
                out.append(", ".join(buf))
                buf, buf_words = [chunk], cw
            else:
                buf.append(chunk)
                buf_words += cw
        if buf:
            out.append(", ".join(buf))
        return out

    for spp in (sentences_per_page, 1):
        grouped = [
            " ".join(sentences[i : i + spp]).strip()
            for i in range(0, len(sentences), spp)
        ]
        if len(grouped) >= target_pages and all(
            len(g.split()) <= max_words for g in grouped
        ):
            return grouped

    new_pages: list[str] = []
    current: list[str] = []
    current_words = 0

    def _flush_current() -> None:
        nonlocal current, current_words
        if current:
            new_pages.append(" ".join(current))
            current = []
            current_words = 0

    for sent in sentences:
        sent_words = len(sent.split())
        if sent_words > max_words:
            _flush_current()
            new_pages.extend(_split_oversize_sentence(sent))
            continue
        if current and current_words + sent_words > max_words:
            _flush_current()
        current.append(sent)
        current_words += sent_words
    _flush_current()

    return new_pages or pages


def _post_process_sprout_pages(
    pages: list[str],
    min_pages: int = 8,
    max_pages: int = 12,
    max_words: int = 25,
) -> list[str]:
    """Programmatically split Sprout output into min_pages–max_pages × ≤max_words/page.

    Used as a deterministic fallthrough after the Sprout non-LTR validation+retry
    loop exhausts (MT-098). Joins all pages into one body, splits on sentence
    boundaries, then groups into pages within the word cap. Mirrors
    _post_process_ltr_pages but targets the Sprout page-count band (8-12).
    """
    if not pages:
        return pages

    body = " ".join(p.strip() for p in pages if p and p.strip())
    if not body:
        return pages

    sentence_parts = re.split(r"(?<=[.!?])(?=\s)|(?<=[.!?][\"')\]])(?=\s)", body)
    sentences = [s.strip() for s in sentence_parts if s.strip()]
    if not sentences:
        return pages

    # Try grouping 1 sentence per page first; fall back to word-boundary split
    # for sentences that individually exceed max_words.
    new_pages: list[str] = []
    for sent in sentences:
        sent_words = len(sent.split())
        if sent_words <= max_words:
            new_pages.append(sent)
        else:
            # Hard-split oversize sentence at word boundaries
            words = sent.split()
            for i in range(0, len(words), max_words):
                new_pages.append(" ".join(words[i : i + max_words]))

    if not new_pages:
        return pages

    # If we produced too many pages, merge adjacent pairs until we fit max_pages.
    while len(new_pages) > max_pages:
        merged: list[str] = []
        i = 0
        while i < len(new_pages):
            if (
                i + 1 < len(new_pages)
                and len(new_pages) > max_pages
                and len((new_pages[i] + " " + new_pages[i + 1]).split()) <= max_words
            ):
                merged.append(new_pages[i] + " " + new_pages[i + 1])
                i += 2
            else:
                merged.append(new_pages[i])
                i += 1
        if len(merged) >= len(new_pages):
            # No progress possible — stop to avoid infinite loop
            break
        new_pages = merged

    # If we produced too few pages, accept what we have (better than crashing).
    return new_pages or pages


# --- Sprout word-cap enforcement (post-generation safety belt) ----------------
# The Sprout prompt (ages 3-5) tells Gemini to stop at 130 words (lowered from
# 150 to leave headroom). Models still overshoot. This safety belt counts words
# AFTER generation and, if a Sprout story exceeds 150 words, tries one stricter
# regeneration, then falls back to a sentence-boundary truncation that always
# preserves the cheer-beat ending. Applies to BOTH the superhero theme path AND
# every other Sprout story path.

SPROUT_WORD_CAP = 150
# MT-108: Explorer (6-8) Superhero stories target 250-350 words. The post-gen
# cap (upper bound) is enforced via the same regen+truncate helper as Sprout;
# the lower bound is already covered by the existing length-validation loop.
EXPLORER_SUPERHERO_WORD_CAP = 350
# Detect existing cheer-beat ending so we don't double-append.
_CHEER_BEAT_RE = re.compile(
    r"Everyone\s+cheered\.\s*[A-Z][\w'\- ]*?\s+saved\s+the\s+day!?",
    re.IGNORECASE,
)


def _count_words(text: str) -> int:
    """Whitespace-token word count, matching how the rest of the pipeline counts."""
    if not text:
        return 0
    return len(text.split())


def _has_cheer_beat(text: str) -> bool:
    if not text:
        return False
    return bool(_CHEER_BEAT_RE.search(text))


def _truncate_to_word_cap(text: str, cap: int, hero_name: str) -> str:
    """Truncate `text` at the last sentence boundary that keeps the body at or
    under `cap` words. Always preserves a cheer-beat ending — if truncation
    drops the original cheer, append a generic "Everyone cheered. {hero_name}
    saved the day!" so the story still resolves.
    """
    if cap <= 0:
        return ""
    body = (text or "").strip()
    if not body:
        return body

    original_had_cheer = _has_cheer_beat(body)

    # Split into sentences while preserving the terminators.
    sentence_parts = re.findall(r"[^.!?]+[.!?]+|\S[^.!?]*$", body, flags=re.DOTALL)
    sentences = [s.strip() for s in sentence_parts if s and s.strip()]

    cheer_suffix = f"Everyone cheered. {hero_name} saved the day!"
    # Reserve words for the cheer beat if we need to re-append it.
    reserved_for_cheer = _count_words(cheer_suffix) if original_had_cheer else 0
    effective_cap = max(0, cap - reserved_for_cheer)

    kept: list[str] = []
    running = 0
    for sent in sentences:
        sw = _count_words(sent)
        if running + sw > effective_cap:
            break
        kept.append(sent)
        running += sw

    truncated = " ".join(kept).strip()
    if not truncated:
        # Fallback: hard word slice + period if no sentence fits at all.
        words = body.split()[: max(1, effective_cap)]
        truncated = " ".join(words).rstrip(",;:") + "."

    # Re-append cheer beat if the original had one and it was cut off.
    if original_had_cheer and not _has_cheer_beat(truncated):
        truncated = (truncated + " " + cheer_suffix).strip()

    return truncated


def _enforce_sprout_word_cap(
    *,
    age: int,
    theme: str,
    pages: list[str],
    story_body: str,
    title: str,
    post_story: dict,
    character_name: str,
    base_prompt: str,
    regen_fn,
    cap: int = SPROUT_WORD_CAP,
    band_label: str = "Sprout",
    age_max: int = 5,
) -> tuple[str, list[str], dict]:
    """Two-stage word-cap safety belt (default = Sprout, ages 3-5, cap 150).

    Stage 1: if word_count > cap, regenerate ONCE with a stricter prompt prefix.
    Stage 2: if regen still > cap, truncate at last sentence boundary that fits,
             preserving the cheer beat (when present in the original).

    Reused by Explorer Superhero (MT-108) with cap=350 and band_label="Explorer";
    the sentence splitter and truncation helper are shared, only the cap and
    log labels differ.

    Returns the (possibly updated) (story_body, pages, info_dict). `info_dict`
    is logged by the caller; it carries `original_words`, `regen_used`,
    `truncated`, `final_words`.
    """
    info = {
        "original_words": 0,
        "regen_used": False,
        "truncated": False,
        "final_words": 0,
        "theme": theme,
    }
    if age is None or age > age_max:
        info["final_words"] = sum(_count_words(p) for p in (pages or []))
        return story_body, pages, info

    total_words = sum(_count_words(p) for p in (pages or []))
    info["original_words"] = total_words
    info["final_words"] = total_words

    if total_words <= cap:
        return story_body, pages, info

    # --- Stage 1: one stricter regen attempt ---
    stricter_prefix = (
        f"STRICT CONSTRAINT: Your previous attempt was {total_words} words. "
        f"The MAXIMUM is {cap}. Write the same story but UNDER "
        f"{cap} words. Count carefully. Cut anything non-essential.\n\n"
    )
    regen_prompt = stricter_prefix + (base_prompt or "")
    try:
        regen_text = regen_fn(regen_prompt)
    except Exception:  # noqa: BLE001 — never crash the user-visible path
        logger.exception(
            "%s word-cap regen call failed; falling back to truncate.", band_label
        )
        regen_text = None

    if regen_text:
        info["regen_used"] = True
        try:
            r_title, _, r_body, r_pages, r_post, _ = _safe_extract_title_and_gem(
                regen_text, theme
            )
        except Exception:  # noqa: BLE001
            logger.exception(
                "%s word-cap regen parse failed; ignoring regen.", band_label
            )
            r_body, r_pages, r_title, r_post = None, None, None, None

        if r_body and r_pages:
            regen_words = sum(_count_words(p) for p in r_pages)
            if regen_words <= cap:
                logger.info(
                    "%s word-cap regen succeeded: theme=%s %s→%s words.",
                    band_label,
                    theme,
                    total_words,
                    regen_words,
                )
                info["final_words"] = regen_words
                return r_body, r_pages, info
            # Regen still over — use the regen pages as input to truncation.
            pages = r_pages
            story_body = r_body
            title = r_title or title
            post_story = r_post or post_story
            total_words = regen_words

    # --- Stage 2: truncate at sentence boundary ---
    truncated_body = _truncate_to_word_cap(story_body, cap, character_name)
    truncated_pages = [truncated_body] if truncated_body else pages
    info["truncated"] = True
    info["final_words"] = _count_words(truncated_body)
    logger.warning(
        "%s word-cap truncation applied: theme=%s original=%s regen_used=%s final=%s words.",
        band_label,
        theme,
        info["original_words"],
        info["regen_used"],
        info["final_words"],
    )
    return truncated_body, truncated_pages, info


@celery.task(
    bind=True,
    name="tasks.generate_story",
    # W1: survive a worker restart mid-task. With the default acks_late=False
    # a task is acked when picked up, so a redeploy/OOM between ack and
    # completion silently loses it and the client polls PENDING forever.
    # acks_late defers the ack until completion, and reject_on_worker_lost
    # requeues a task whose worker died — so a lost story is redelivered
    # instead of vanishing. task_time_limit (600s) stays well under the Redis
    # broker visibility timeout, so a slow task is not double-delivered.
    acks_late=True,
    reject_on_worker_lost=True,
)
def generate_story_task(self, **kwargs: Dict[str, Any]) -> Dict[str, Any]:
    """
    Async story generation task.

    Expected kwargs:
        character_id: ID of character to personalize the story
        theme: Story theme
        user_id: Requesting user
        user_tier: Subscription tier ('free'/'premium'/'family'/'byok'); drives
            tier-aware text-model selection. Optional — falls back to a DB
            lookup, then to the full model, when omitted.
        include_illustrations, rhyme_time_mode, learning_to_read_mode: Feature flags
        companion, therapeutic_prompt, feelings_prompt: Additional context
        character: Optional character name fallback when no ID is provided
    """
    with get_flask_app().app_context():
        # PERF-04: bail before any expensive work if the client already
        # cancelled (e.g., they navigated away in the gap between dispatch
        # and worker pickup). Fail-open — a Redis hiccup just lets the
        # generation proceed.
        from ..utils.task_cancellation import clear_cancellation, is_cancelled

        if is_cancelled(self.request.id):
            logger.info(
                "Task %s cancelled before work began; skipping generation.",
                self.request.id,
            )
            # Best-effort: drop the cancel flag so it never lingers past task
            # end (the helper swallows Redis errors and the TTL is a backstop).
            clear_cancellation(self.request.id)
            return {
                "status": "cancelled",
                "user_id": str(kwargs.get("user_id") or "anonymous"),
            }

        total_task_start = time.perf_counter()
        prompt_build_ms = 0.0
        ai_call_ms = 0.0
        validation_ms = 0.0
        provider_name = "unknown"
        validation_attempts = 0
        provider_sequence: list[str] = []
        character_id = kwargs.get("character_id")
        theme = kwargs.get("theme") or "Adventure"
        user_id = kwargs.get("user_id") or "anonymous"
        # Subscription tier from the route (drives tier-aware text-model
        # selection). May be None for legacy callers that predate the kwarg —
        # the validation-loop block below falls back to a DB lookup, and a
        # still-missing tier defaults to the full model (fail toward quality).
        user_tier = (kwargs.get("user_tier") or "").strip().lower() or None
        include_illustrations = kwargs.get("include_illustrations", False)
        rhyme_time_mode = kwargs.get("rhyme_time_mode", False)
        learning_to_read_mode = kwargs.get("learning_to_read_mode", False)
        bedtime_mode = kwargs.get("bedtime_mode", False)
        story_length = kwargs.get(
            "story_length", "standard"
        )  # 'quick', 'standard', or 'epic' (legacy)
        story_duration = kwargs.get(
            "story_duration"
        )  # NEW: '5_minutes' or '10_minutes'
        age = kwargs.get("age", 5)  # User's age
        companion = kwargs.get("companion")  # Legacy support
        character_name_raw = kwargs.get("character") or "a brave adventurer"
        if isinstance(character_name_raw, dict):
            character_name = character_name_raw.get("name", "Hero")
        else:
            character_name = str(character_name_raw)

        char_details = kwargs.get("character_details") or {}
        custom_elements = kwargs.get(
            "custom_elements", ""
        )  # Free-form custom story requests

        # NEW: Extract structured companion data
        companion_pets = kwargs.get("companion_pets", [])  # List of pet dicts
        companion_characters = kwargs.get(
            "companion_characters", []
        )  # List of character names

        try:
            character = (
                db.session.get(Character, character_id) if character_id else None
            )
            if character:
                character_name = character.name
            elif character_id:
                raise ValueError(f"Character {character_id} not found")

            # M-7: pseudonymize the hero name before ANY provider call. The
            # entire pipeline (prompt build, validation, fallbacks, word-cap
            # cheer beat) runs on the opaque HERO_1 token; the child's real
            # name is substituted back into the output locally before the
            # story is returned, so no provider ever receives the real name.
            real_hero_name = character_name
            character_name = pseudonymize_hero_name(real_hero_name)

            def _scrub_real_name(text):
                """Replace stray real-name occurrences (from character_details,
                feelings_prompt, the prior-adventures recall block, etc.) with
                the token so the assembled prompt never carries the real name."""
                if not text or not real_hero_name or not str(real_hero_name).strip():
                    return text
                return re.sub(
                    r"\b" + re.escape(str(real_hero_name).strip()) + r"\b",
                    character_name,
                    text,
                    flags=re.IGNORECASE,
                )

            try:
                self.update_state(
                    state="PROCESSING", meta={"status": "Generating story..."}
                )
            except Exception as e:
                logger.warning(
                    f"Failed to update task state (Redis likely unavailable): {e}"
                )

            # Fetch companion character details from database or use provided dicts
            companion_character_details = []
            if companion_characters:
                for char_data in companion_characters:
                    if isinstance(char_data, dict):
                        # It's already a full companion object (from frontend mapping)
                        companion_character_details.append(char_data)
                    else:
                        # It's a name string, try to look up in DB
                        char_name = str(char_data)
                        char_record = Character.query.filter_by(name=char_name).first()
                        if char_record:
                            companion_character_details.append(
                                {
                                    "name": char_record.name,
                                    "age": char_record.age,
                                    "role": char_record.role,
                                    "gender": char_record.gender,
                                }
                            )
                            logger.info(
                                f"Found companion character: {char_name} (age {char_record.age}, {char_record.role})"
                            )
                        else:
                            # Character not found in database, just pass the name
                            logger.warning(
                                f"Companion character '{char_name}' not found in database"
                            )
                            companion_character_details.append({"name": char_name})

            engine = AdvancedStoryEngine()

            prompt_build_start = time.perf_counter()

            # Superhero Mode (ages 3-5) short-circuit. Picks a sensible
            # (villain, problem) pair from the compatibility matrix, then
            # hands the 6-beat prompt to the same model pipeline. The
            # chosen IDs are surfaced back in the response payload so the
            # frontend can store recent_villains/recent_problems history
            # and avoid repeats on the next call.
            superhero_meta: dict | None = None
            if _is_superhero_theme(theme):
                hero_power = kwargs.get("hero_power")
                recent_villains = kwargs.get("recent_villains") or []
                recent_problems = kwargs.get("recent_problems") or []
                # Derive band from age: 3-5 -> sprout, 6-8 -> explorer.
                # Default to sprout for anything outside the band ranges so
                # legacy callers continue to work unchanged.
                try:
                    _sh_age_int = int(age) if age is not None else 5
                except (TypeError, ValueError):
                    _sh_age_int = 5
                if _sh_age_int >= 6 and _sh_age_int <= 8:
                    sh_band = "explorer"
                elif _sh_age_int >= 9 and _sh_age_int <= 12:
                    # Adventurer (9-12) has its own villain/problem tables. Without
                    # this branch the pairing was drawn from the Sprout table, so
                    # the Adventurer prompt builder silently re-rolled the villain
                    # (and the C4 nemesis override never stuck — see below).
                    sh_band = "adventurer"
                else:
                    sh_band = "sprout"
                try:
                    sh_villain_id, sh_problem_id = _superhero_pick_pairing(
                        hero_power or "super_smile",
                        recent_villains=recent_villains,
                        recent_problems=recent_problems,
                        band=sh_band,
                    )
                except ValueError:
                    # Unknown power id — pick_pairing raises; fall back to a
                    # universally-safe default rather than 500ing the request.
                    # super_smile exists in both Sprout and Explorer tables.
                    sh_villain_id, sh_problem_id = _superhero_pick_pairing(
                        "super_smile",
                        band=sh_band,
                    )

                # C4: honor a kid-chosen arch-villain (Adventurer nemesis picker).
                # If the client supplied a nemesis id, swap it in AND re-pair it to
                # a problem it actually fits — the prompt builder re-rolls both
                # villain and problem when either is invalid for the band, which
                # would otherwise silently discard the kid's choice. Unknown ids
                # fall through to the server's surprise-pick.
                sh_villain_id, sh_problem_id = _superhero_apply_nemesis(
                    sh_band,
                    sh_villain_id,
                    sh_problem_id,
                    kwargs.get("hero_nemesis_id"),
                )

                superhero_meta = {
                    "villain_id": sh_villain_id,
                    "problem_id": sh_problem_id,
                    "hero_power": hero_power or "super_smile",
                    "band": sh_band,
                }
                logger.info(
                    "Superhero Mode: band=%s hero_power=%s villain=%s problem=%s",
                    sh_band,
                    hero_power,
                    sh_villain_id,
                    sh_problem_id,
                )

                prompt = PromptService.build_story_prompt(
                    character=character_name,
                    theme="superhero",
                    age=age,
                    hero_costume_color=kwargs.get("hero_costume_color"),
                    hero_cape_style=kwargs.get("hero_cape_style"),
                    hero_emblem=kwargs.get("hero_emblem"),
                    hero_power=hero_power,
                    hero_catchphrase=kwargs.get("hero_catchphrase"),
                    superhero_villain_id=sh_villain_id,
                    superhero_problem_id=sh_problem_id,
                )
                # (prompt_build_ms is computed after the if/elif chain below)
            # Use specialized prompts based on story mode flags
            elif bedtime_mode:
                logger.info(f"Using Bedtime prompt (length: {story_length})")
                extra_chars = kwargs.get("additional_characters") or char_details.get(
                    "additionalCharacters"
                )
                prompt = _build_bedtime_prompt(
                    character_name=character_name,
                    age=age,
                    theme=theme,
                    mood=kwargs.get("bedtime_mood", "calming"),
                    all_listeners=extra_chars,
                    companion=companion,
                    companion_pets=companion_pets,
                    companion_characters=companion_character_details,
                    story_length=story_length,
                    duration_minutes=kwargs.get("bedtime_duration_minutes"),
                )
            elif learning_to_read_mode:

                logger.info(f"Using Learning to Read prompt (length: {story_length})")
                prompt = _build_learning_to_read_prompt(
                    character_name=character_name,
                    theme=theme,
                    age=age,
                    character_details=char_details,
                    companion=companion,
                    companion_pets=companion_pets,
                    companion_characters=companion_characters,
                    extra_characters=kwargs.get("additional_characters")
                    or char_details.get("additionalCharacters"),
                    story_length=story_length,
                    custom_elements=custom_elements,
                )
            elif rhyme_time_mode:
                logger.info(f"Using Rhyme Time prompt (length: {story_length})")
                age = kwargs.get("age", 8)
                prompt = _build_rhyme_time_prompt(
                    character_name=character_name,
                    theme=theme,
                    age=age,
                    character_details=char_details,
                    companion_pets=companion_pets,
                    companion_characters=companion_character_details,
                    extra_characters=kwargs.get("additional_characters")
                    or char_details.get("additionalCharacters"),
                    story_length=story_length,
                    custom_elements=custom_elements,
                    world_bible=kwargs.get("world_bible", ""),
                    conflict_hook=kwargs.get("conflict_hook", ""),
                    sensory_palette=kwargs.get("sensory_palette", ""),
                )
                logger.info(f"Full prompt for rhyme time mode: {prompt}")
            else:
                # Standard enhanced prompt
                logger.info(
                    f"Using standard enhanced prompt (length: {story_length}, duration: {story_duration})"
                )
                prompt = engine.generate_enhanced_prompt(
                    character=character_name,
                    theme=theme,
                    companion=companion,  # Legacy: keep for backward compatibility
                    companion_pets=companion_pets,  # NEW: List of pet companions
                    companion_characters=companion_character_details,  # NEW: List of character companion DETAILS
                    spark_tool=kwargs.get("spark_tool"),  # NEW
                    mood_physics=kwargs.get("mood_physics"),  # NEW
                    conflict_hook=kwargs.get("conflict_hook"),  # NEW
                    sensory_palette=kwargs.get("sensory_palette"),  # NEW
                    custom_elements=custom_elements,  # NEW: Free-form custom story requests
                    additional_characters=kwargs.get("additional_characters")
                    or char_details.get("additionalCharacters"),
                    therapeutic_prompt=kwargs.get("therapeutic_prompt", ""),
                    feelings_prompt=kwargs.get("feelings_prompt"),
                    character_details=char_details,
                    story_length=story_length,  # Legacy: Story length option
                    story_duration=story_duration,  # NEW: Duration-based generation
                    age=age,  # NEW: Pass age for calibration
                )
            # Recall loop: inject this character's prior themes / supporting cast so
            # the model varies or builds on past adventures instead of looping the
            # same plot. Anonymous + first-time characters get an empty block and
            # the prompt is untouched. See _build_prior_adventures_block.
            prior_block = _build_prior_adventures_block(character_id)
            if prior_block:
                prompt = prior_block + prompt
                # WARNING level intentionally: prod root logger runs at WARNING
                # (backend/app.py), so an INFO line here is invisible — leaving
                # themes-recall with no production-observable signal.
                logger.warning(
                    "prior_adventures injected for character_id=%s (block_len=%d)",
                    character_id,
                    len(prior_block),
                )

            # M-7: final boundary scrub before the prompt leaves for any provider.
            prompt = _scrub_real_name(prompt)

            # F-01 (MT-187): resolve the template id + live revision hash so we
            # can persist them on the Story row. Derived from the same mode
            # flags that the if/elif chain above branched on.
            if superhero_meta is not None:
                _pv_mode = "superhero"
            elif bedtime_mode:
                _pv_mode = "bedtime"
            elif learning_to_read_mode:
                _pv_mode = "ltr"
            elif rhyme_time_mode:
                _pv_mode = "rhyme_time"
            else:
                _pv_mode = "standard"
            prompt_template_id, prompt_revision_hash = _resolve_prompt_version(
                mode=_pv_mode,
                age=age,
            )

            prompt_build_ms = (time.perf_counter() - prompt_build_start) * 1000.0
            logger.debug("perf phase=prompt_build ms=%.1f", prompt_build_ms)

            logger.info(f"Companion Pets: {companion_pets}")
            logger.info(f"Companion Character Details: {companion_character_details}")
            logger.info(f"Generated Prompt Snippet: {prompt[:500]}...")

            # Collect mandatory names for validation
            mandatory_names = [character_name]
            for p in companion_pets:
                if isinstance(p, dict) and p.get("name"):
                    mandatory_names.append(p["name"])
            for c in companion_character_details:
                if isinstance(c, dict) and c.get("name"):
                    mandatory_names.append(c["name"])

            extra_chars = kwargs.get("additional_characters") or char_details.get(
                "additionalCharacters"
            )
            if extra_chars:
                for ec in extra_chars:
                    name = ec.get("name") if isinstance(ec, dict) else str(ec)
                    if name:
                        mandatory_names.append(name)

            logger.info(f"Mandatory names for validation: {mandatory_names}")

            # Tier-aware retry cap: free tier gets 2 attempts (not 3) to bound
            # Gemini cost on validation failures. Premium/Family/BYOK keep 3.
            # The tier is normally passed in via task kwargs (from the route);
            # fall back to a DB lookup for legacy callers that omit it.
            if user_tier is None:
                resolved_tier = "free"
                if user_id and user_id != "anonymous":
                    try:
                        _u = User.query.filter_by(id=user_id).first()
                        if _u and _u.subscription_tier:
                            resolved_tier = _u.subscription_tier.lower()
                    except Exception:
                        logger.debug("could not resolve user tier", exc_info=True)
                user_tier = resolved_tier
            max_attempts = 2 if user_tier == "free" else 3
            attempt = 0
            validation_loop_start = time.perf_counter()
            while attempt < max_attempts:
                attempt += 1
                validation_attempts = attempt
                logger.info(
                    f"Generation attempt {attempt}/{max_attempts} (tier={user_tier})"
                )

                # PERF-04: bail before each (re)generation if the client
                # abandoned the wait. The dominant cost is the Gemini call
                # below, so checking here saves a full generation on every
                # cancelled regeneration attempt. Fail-open via is_cancelled.
                if is_cancelled(self.request.id):
                    logger.info(
                        "Task %s cancelled before generation attempt %d; aborting.",
                        self.request.id,
                        attempt,
                    )
                    _clear_partial_story(self.request.id)
                    clear_cancellation(self.request.id)
                    return {
                        "status": "cancelled",
                        "user_id": str(user_id),
                    }

                ai_call_start = time.perf_counter()
                story_text, provider_name, provider_sequence = (
                    _generate_story_text_with_metadata(
                        prompt,
                        theme,
                        character_name,
                        companion,
                        user_tier=user_tier,
                        # PERF-01 slice 2: forward the Celery task id so Gemini
                        # streaming can write partial state to Redis under
                        # `partial_story:<task_id>` as chunks arrive.
                        task_id=self.request.id,
                    )
                )
                attempt_ai_call_ms = (time.perf_counter() - ai_call_start) * 1000.0
                ai_call_ms += attempt_ai_call_ms
                logger.debug(
                    "perf phase=ai_call provider=%s ms=%.1f",
                    provider_name,
                    attempt_ai_call_ms,
                )
                title, _, story_body, pages, post_story, story_metadata = (
                    _safe_extract_title_and_gem(story_text, theme)
                )

                # Validation Logic (Content Sanitizer)
                is_clean = True
                validation_error = None
                forbidden_patterns = ["REQUEST SUMMARY", "SIGNATURE POWER", "CRITICAL:"]
                page_pattern = re.compile(r"\bPAGE\s+\d+\b", re.IGNORECASE)

                for page in pages:
                    if any(
                        p in page for p in forbidden_patterns
                    ) or page_pattern.search(page):
                        is_clean = False
                        validation_error = "Meta leakage detected"
                        break

                missing_names = []
                for name in mandatory_names:
                    # Basic case-insensitive check for name in story
                    if name.lower() not in story_body.lower():
                        missing_names.append(name)

                if missing_names:
                    is_clean = False
                    validation_error = f"Missing characters: {', '.join(missing_names)}"

                # Rhyme validation for learning-to-read mode (easy reader).
                # This keeps mode behavior aligned with user expectations.
                is_rhyme_quality_ok = True
                # LTR page-count + per-page word-count validation.
                # Models tend to compress LTR output to 2-3 dense pages; this enforces
                # the picture-book pacing the prompt asks for.
                is_ltr_format_ok = True
                ltr_format_error = ""
                ltr_expected_pages = 0
                ltr_pages_count = 0
                ltr_over_word_pages: list[int] = []
                # MT-098: Sprout non-LTR page-count + per-page word-count validation.
                # Mirrors the LTR validation block above for the Sprout band when not
                # in any specialised mode (LTR/rhyme/bedtime all have their own guards).
                is_sprout_format_ok = True
                sprout_format_error = ""
                sprout_pages_count = 0
                sprout_over_word_pages: list[int] = []
                _is_sprout_nonltr = (
                    age <= 5
                    and not learning_to_read_mode
                    and not rhyme_time_mode
                    and not bedtime_mode
                )
                if _is_sprout_nonltr:
                    sprout_pages_count = len(pages)
                    sprout_over_word_pages = [
                        i for i, p in enumerate(pages) if len(p.split()) > 25
                    ]
                    if (
                        sprout_pages_count < 8
                        or sprout_pages_count > 12
                        or sprout_over_word_pages
                    ):
                        is_sprout_format_ok = False
                        sprout_format_error = (
                            f"Sprout format check failed: {sprout_pages_count} pages "
                            f"(need 8-12), "
                            f"{len(sprout_over_word_pages)} pages exceed 25 words."
                        )
                        validation_error = sprout_format_error
                if learning_to_read_mode:
                    is_rhyme_quality_ok = _is_ltr_rhyme_quality_ok(pages)
                    if not is_rhyme_quality_ok:
                        validation_error = (
                            "Learning-to-read story did not meet rhyme quality checks"
                        )

                    # Compute expected page count for this age/length to match prompt floor.
                    try:
                        _ltr_band = _get_age_band(age)
                        _ltr_cfg = AGE_CONSTRAINTS[_ltr_band]["ltr"]
                        if story_length in ("short", "quick"):
                            _ltr_len_key = "short"
                        elif story_length in ("long", "epic"):
                            _ltr_len_key = "long"
                        else:
                            _ltr_len_key = "medium"
                        ltr_expected_pages = max(5, _ltr_cfg[_ltr_len_key])
                    except (
                        Exception
                    ):  # noqa: BLE001 — defensive, never break generation
                        ltr_expected_pages = 5

                    ltr_pages_count = len(pages)
                    ltr_over_word_pages = [
                        i for i, p in enumerate(pages) if len(p.split()) > 25
                    ]
                    if ltr_pages_count < 5 or ltr_over_word_pages:
                        is_ltr_format_ok = False
                        ltr_format_error = (
                            f"LTR format check failed: {ltr_pages_count} pages "
                            f"(need ≥5, target {ltr_expected_pages}), "
                            f"{len(ltr_over_word_pages)} pages exceed 25 words."
                        )
                        validation_error = ltr_format_error

                # Length Validation with dynamic thresholds
                # LTR mode is measured in pages (not words), so skip word-count check.
                is_long_enough = True
                if not learning_to_read_mode:
                    total_words = sum(len(p.split()) for p in pages)

                    # Determine minimum words based on age and mode
                    min_words_threshold = 0
                    is_long_mode = (
                        story_duration == "10_minutes" or story_length == "epic"
                    )
                    is_standard_mode = story_length == "standard"

                    if age <= 5:
                        min_words_threshold = 250 if is_standard_mode else 100
                    elif age <= 7:
                        min_words_threshold = 500 if is_standard_mode else 300
                    elif age == 8:
                        min_words_threshold = 1300 if is_long_mode else 700
                    elif age <= 12:
                        min_words_threshold = 1700 if is_long_mode else 1100
                    else:  # 13+
                        min_words_threshold = 2400 if is_long_mode else 1700

                    if total_words < min_words_threshold:
                        is_long_enough = False
                        validation_error = f"Story too short ({total_words} words, needed {min_words_threshold})"

                if (
                    is_clean
                    and is_long_enough
                    and is_rhyme_quality_ok
                    and is_ltr_format_ok
                    and is_sprout_format_ok
                ):
                    logger.info("Story passed validation.")
                    break
                else:
                    logger.warning(
                        f"Validation failed on attempt {attempt}: {validation_error}"
                    )
                    if attempt < max_attempts:
                        # Append feedback to prompt for next attempt
                        if not is_clean:
                            prompt += "\n\nRETRY INSTRUCTION: Never output internal meta or 'PAGE X' markers. Return ONLY story text in the pages array."
                            if missing_names:
                                prompt += (
                                    "\n\nRETRY INSTRUCTION: The story MUST include these characters by name: "
                                    + ", ".join(missing_names)
                                )
                        if not is_long_enough:
                            prompt += f"\n\nRETRY INSTRUCTION: The story was too short ({total_words} words). Please expand descriptions, dialogue, and scenes to reach at least {min_words_threshold} words."
                        if not is_rhyme_quality_ok:
                            prompt += (
                                "\n\nRETRY INSTRUCTION: This is LEARNING TO READ mode and MUST rhyme. "
                                "Use strong end-rhyming couplets by page endings: pages 1&2 rhyme, 3&4 rhyme, 5&6 rhyme. "
                                "Prefer simple child-hearable rhymes like cat/hat, sun/fun, hop/top."
                            )
                        if not is_ltr_format_ok:
                            prompt += (
                                f"\n\nRETRY INSTRUCTION: Your previous response had {ltr_pages_count} pages "
                                f"with {len(ltr_over_word_pages)} pages exceeding 30 words. "
                                f"You MUST return EXACTLY {ltr_expected_pages} pages, with each page 25 words or fewer. "
                                f"Split any long page into two shorter pages. Do not compress the story into a few dense pages."
                            )
                        if not is_sprout_format_ok:
                            prompt += (
                                f"\n\nRETRY INSTRUCTION: This is a Sprout (3-4 year old) story and MUST be between 8 and 12 short pages "
                                f"(10-25 words each). Your previous response had {sprout_pages_count} pages "
                                f"with {len(sprout_over_word_pages)} pages exceeding 25 words. "
                                f"Return EXACTLY 8-12 pages. Split any dense page into two shorter ones. "
                                f"Traditional picture-book pacing: one short scene per page, never more than 25 words per page."
                            )
                    else:
                        logger.error("Max attempts reached. Returning best effort.")
            validation_loop_ms = (time.perf_counter() - validation_loop_start) * 1000.0
            validation_ms = max(validation_loop_ms - ai_call_ms, 0.0)
            logger.debug("perf phase=validation ms=%.1f", validation_ms)

            # SE1/G2: provider_name == "static" means BOTH Gemini and
            # OpenRouter failed and the child received the generic canned
            # fallback story. This is invisible to the user, so surface it as
            # an alertable Sentry signal — a spike means an all-providers-down
            # outage that no exception would otherwise report.
            if provider_name == "static":
                logger.error(
                    "story_generation_static_fallback theme=%s user_tier=%s sequence=%s",
                    theme,
                    user_tier,
                    provider_sequence,
                )
                try:
                    import sentry_sdk

                    with sentry_sdk.push_scope() as _scope:
                        _scope.set_tag("reliability_signal", "static_fallback")
                        _scope.set_tag("user_tier", user_tier or "unknown")
                        _scope.set_context(
                            "provider_sequence", {"attempts": provider_sequence}
                        )
                        sentry_sdk.capture_message(
                            "story_generation_static_fallback", level="warning"
                        )
                except Exception:  # noqa: BLE001 — never break generation on telemetry
                    logger.debug("Sentry static-fallback signal failed", exc_info=True)

            if learning_to_read_mode and not is_ltr_format_ok:
                _ltr_target = ltr_expected_pages or 5
                pre_split = [(i, len(p.split())) for i, p in enumerate(pages)]
                pages = _post_process_ltr_pages(
                    pages, target_pages=_ltr_target, max_words=25
                )
                story_body = "\n\n".join(pages)
                post_split = [(i, len(p.split())) for i, p in enumerate(pages)]
                logger.warning(
                    "LTR post-process split applied: pages %s → %s",
                    pre_split,
                    post_split,
                )

            # MT-098: Sprout non-LTR page-count post-process fallthrough.
            # When the validation+retry loop exhausts without producing a
            # conforming 8-12 page story, split programmatically at sentence
            # boundaries (same pattern as LTR post-process above).
            if _is_sprout_nonltr and not is_sprout_format_ok:
                pre_split = [(i, len(p.split())) for i, p in enumerate(pages)]
                pages = _post_process_sprout_pages(
                    pages, min_pages=8, max_pages=12, max_words=25
                )
                story_body = "\n\n".join(pages)
                post_split = [(i, len(p.split())) for i, p in enumerate(pages)]
                logger.warning(
                    "Sprout non-LTR post-process split applied: pages %s → %s",
                    pre_split,
                    post_split,
                )

            # --- Sprout (ages 3-5) 150-word post-generation cap ---
            # Two-stage safety belt: one stricter regen attempt, then sentence-
            # boundary truncation that preserves the cheer beat. Applies to
            # superhero theme AND every other Sprout story path.
            try:
                _sprout_age = int(age) if age is not None else 5
            except (TypeError, ValueError):
                _sprout_age = 5
            if _sprout_age <= 5:
                story_body, pages, _sprout_info = _enforce_sprout_word_cap(
                    age=_sprout_age,
                    theme=theme,
                    pages=pages,
                    story_body=story_body,
                    title=title,
                    post_story=post_story,
                    character_name=character_name,
                    base_prompt=prompt,
                    regen_fn=lambda p: _generate_story_text(
                        p, theme, character_name, companion, user_tier=user_tier
                    ),
                )
                if _sprout_info.get("original_words", 0) > SPROUT_WORD_CAP:
                    logger.info(
                        "sprout_word_cap event=enforced theme=%s original=%s regen=%s "
                        "truncated=%s final=%s",
                        _sprout_info.get("theme"),
                        _sprout_info.get("original_words"),
                        _sprout_info.get("regen_used"),
                        _sprout_info.get("truncated"),
                        _sprout_info.get("final_words"),
                    )

            # --- MT-108: Explorer (ages 6-8) Superhero 350-word post-gen cap ---
            # Mirrors the Sprout safety belt above, reusing the same retry+truncate
            # helper with cap=350. Only fires for the Superhero theme on Explorer
            # ages, where the prompt targets 250-350 words and the model still
            # occasionally overshoots.
            elif _sprout_age >= 6 and _sprout_age <= 8 and _is_superhero_theme(theme):
                story_body, pages, _explorer_info = _enforce_sprout_word_cap(
                    age=_sprout_age,
                    theme=theme,
                    pages=pages,
                    story_body=story_body,
                    title=title,
                    post_story=post_story,
                    character_name=character_name,
                    base_prompt=prompt,
                    regen_fn=lambda p: _generate_story_text(
                        p, theme, character_name, companion, user_tier=user_tier
                    ),
                    cap=EXPLORER_SUPERHERO_WORD_CAP,
                    band_label="Explorer",
                    age_max=8,
                )
                if (
                    _explorer_info.get("original_words", 0)
                    > EXPLORER_SUPERHERO_WORD_CAP
                ):
                    logger.info(
                        "explorer_superhero_word_cap event=enforced theme=%s original=%s regen=%s "
                        "truncated=%s final=%s",
                        _explorer_info.get("theme"),
                        _explorer_info.get("original_words"),
                        _explorer_info.get("regen_used"),
                        _explorer_info.get("truncated"),
                        _explorer_info.get("final_words"),
                    )

            # PERF-04: last cancellation gate before the moderation phase.
            # Moderation is an LLM call (and a flag can trigger a safe-fallback
            # regeneration) — skip it if the client already abandoned the wait.
            if is_cancelled(self.request.id):
                logger.info(
                    "Task %s cancelled before moderation; aborting.",
                    self.request.id,
                )
                _clear_partial_story(self.request.id)
                clear_cancellation(self.request.id)
                return {
                    "status": "cancelled",
                    "user_id": str(user_id),
                }

            # --- Output content moderation ---
            # Two-layer safety check on the generated story before it reaches the child.
            # Layer 1: fast age-band-aware keyword filter.
            # Layer 2: LLM-based contextual classifier (skipped if Layer 1 already flagged).
            # Both layers fail open — story is delivered and logged rather than crashed.
            from backend.utils.app_helpers import make_filter_story_content
            from backend.utils.content_moderator import moderate_story_content

            _filter_fn = make_filter_story_content(logger)
            # F-13: screen the title too — it is as child-visible as the body.
            _, _keyword_flagged_body = _filter_fn(story_body, age)
            _, _keyword_flagged_title = _filter_fn(title or "", age)
            keyword_flagged = _keyword_flagged_body or _keyword_flagged_title

            llm_flagged = False
            llm_flag_reason = ""
            if not keyword_flagged:
                # F-04/F-06: fail closed for pre-teens (age <= 12) so a
                # classifier outage routes a young child's story into the
                # safe-fallback regeneration below instead of serving it
                # unverified. F-05: also fail closed when the weaker
                # OpenRouter fallback model produced the story — it has no
                # provider-side safety filtering of its own.
                try:
                    _mod_age = int(age) if age is not None else 5
                except (TypeError, ValueError):
                    _mod_age = 5
                _fail_closed = _mod_age <= 12 or provider_name == "openrouter"
                # Moderate title + body together (F-13).
                _moderation_text = f"{title}\n\n{story_body}" if title else story_body
                llm_safe, llm_flag_reason = moderate_story_content(
                    _moderation_text, age, fail_closed=_fail_closed
                )
                llm_flagged = not llm_safe

            if keyword_flagged or llm_flagged:
                flag_source = (
                    "keyword filter"
                    if keyword_flagged
                    else f"LLM classifier ({llm_flag_reason})"
                )
                logger.warning(
                    f"Story flagged by {flag_source} for age {age} — "
                    f"substituting safe fallback story."
                )
                # Replace with a safe, generic story using the character and theme
                # but without the custom elements that may have contributed to the issue.
                fallback_prompt = engine.generate_enhanced_prompt(
                    character=character_name,
                    theme=theme,
                    companion=companion,
                    companion_pets=companion_pets,
                    companion_characters=companion_character_details,
                    custom_elements="",  # Strip custom elements for fallback
                    additional_characters=kwargs.get("additional_characters")
                    or char_details.get("additionalCharacters"),
                    therapeutic_prompt=kwargs.get("therapeutic_prompt", ""),
                    feelings_prompt=kwargs.get("feelings_prompt"),
                    character_details=char_details,
                    story_length=story_length,
                    story_duration=story_duration,
                    age=age,
                )
                fallback_prompt = _scrub_real_name(fallback_prompt)  # M-7
                fallback_text = _generate_story_text(
                    fallback_prompt,
                    theme,
                    character_name,
                    companion,
                    user_tier=user_tier,
                )
                (
                    fallback_title,
                    _,
                    fallback_body,
                    fallback_pages,
                    fallback_post,
                    fallback_metadata,
                ) = _safe_extract_title_and_gem(fallback_text, theme)
                if fallback_body:
                    title = fallback_title
                    story_body = fallback_body
                    pages = fallback_pages
                    post_story = fallback_post
                    # Fallback path replaces story body; metadata must follow or
                    # we'd be tagging the new story with the flagged story's themes.
                    story_metadata = fallback_metadata
                    # F-01: the safety fallback always uses the standard prompt
                    # builder regardless of the original mode — re-tag so the
                    # row reflects what actually produced the persisted body.
                    prompt_template_id, prompt_revision_hash = _resolve_prompt_version(
                        mode="standard",
                        age=age,
                    )

            # --- End output content moderation ---

            # NEW: Page-based story structure for duration-based generation
            adventure_steps = []
            validation_issues = []

            if story_duration and not rhyme_time_mode and not learning_to_read_mode:
                # Use page-based system for regular duration stories
                try:
                    from backend.services.story_duration_service import (
                        AdventureStepGenerator,
                        DurationConfig,
                    )

                    # Get configuration
                    config = DurationConfig.get_config(story_duration, age)

                    # Use pages from LLM if it returned at least min_pages; otherwise re-split.
                    # Models routinely under-paginate (3 dense pages instead of 5-8), leaving a
                    # tiny tail page or unbalanced pacing — PageSplitter rebalances on word counts.
                    _min_pages = max(2, int(config.get("min_pages", 2)))
                    if not pages or len(pages) < _min_pages:
                        from backend.services.story_duration_service import PageSplitter

                        if pages:
                            logger.info(
                                "Under-paginated: model returned %d pages, "
                                "min %d expected — re-splitting body.",
                                len(pages),
                                _min_pages,
                            )
                        pages = PageSplitter.split_into_pages(
                            story_body,
                            target_words_per_page=config["words_per_page"],
                            min_pages=config["min_pages"],
                            max_pages=config["max_pages"],
                        )

                    # Generate adventure step labels
                    adventure_steps = AdventureStepGenerator.generate_steps(
                        story_duration, age, len(pages)
                    )

                    # Validate story
                    from backend.services.story_duration_service import StoryValidator

                    is_valid, issues = StoryValidator.validate_story(
                        story_body, pages, story_duration, age
                    )

                    from backend.services.story_duration_service import PageSplitter

                    total_words = sum(len(p.split()) for p in pages)

                    if not is_valid:
                        validation_issues = issues
                        logger.warning(f"Story validation issues: {', '.join(issues)}")

                    logger.info(
                        f"Generated {len(pages)} pages, {total_words} words "
                        f"(target: {config['min_words']}-{config['max_words']} words, "
                        f"{config['min_pages']}-{config['max_pages']} pages)"
                    )

                except ImportError as e:
                    logger.error(f"Failed to import story_duration_service: {e}")
                    # Fallback to single-page mode
                    pages = [story_body]
                    adventure_steps = ["The Story"]
                    total_words = len(story_body.split())
                except Exception as e:
                    logger.exception(f"Error during page splitting: {e}")
                    # Fallback to single-page mode
                    pages = [story_body]
                    adventure_steps = ["The Story"]
                    total_words = len(story_body.split())
            else:
                # Legacy mode: no page splitting
                pages = pages if pages else [story_body]
                adventure_steps = ["The Story"]
                total_words = sum(len(p.split()) for p in pages)

            # Illustrations are now generated separately via /generate-illustrations endpoint
            # Initialize as empty list - frontend will request illustrations async if needed
            illustrations = []

            # Generate a unique ID for the story
            story_id = str(uuid.uuid4())
            total_ms = (time.perf_counter() - total_task_start) * 1000.0
            logger.debug("perf phase=total_task ms=%.1f", total_ms)

            # MT-111 diagnostic: log final page shape before handoff to the
            # frontend. If a Superhero/age-band-locked story renders with a
            # different page count than expected, this is the boundary log
            # to compare against the rendered output.
            try:
                _page_word_counts = [len(p.split()) for p in (pages or [])]
                logger.info(
                    "story_handoff: theme=%s age=%s pages=%d page_word_counts=%s total_words=%s",
                    theme,
                    age,
                    len(pages or []),
                    _page_word_counts,
                    sum(_page_word_counts),
                )
            except Exception:  # noqa: BLE001 — never break the response on logging
                logger.debug("story_handoff diagnostic log failed", exc_info=True)

            # Metadata may not exist if all generation paths bailed before reaching
            # the extractor (very rare); default to empty shape so downstream is safe.
            try:
                _themes = list(story_metadata.get("themes") or [])
                _characters = list(story_metadata.get("characters_featured") or [])
                _arc = story_metadata.get("emotional_arc")
            except NameError:
                _themes, _characters, _arc = [], [], None

            # M-7: substitute the real hero name back into every output surface
            # locally — the child sees their own name even though every provider
            # only ever saw the HERO_1 token. Stored Story rows also carry the
            # real name (consistent with the interactive path).
            title = restore_hero_name(title, real_hero_name)
            story_body = restore_hero_name(story_body, real_hero_name)
            pages = [restore_hero_name(p, real_hero_name) for p in pages]
            _characters = [restore_hero_name(c, real_hero_name) for c in _characters]
            try:
                post_story = json.loads(
                    restore_hero_name(json.dumps(post_story), real_hero_name)
                )
            except (TypeError, ValueError):
                pass

            story_payload = {
                "id": story_id,
                "title": title,
                "story_text": story_body,
                "theme": theme,
                "themes": _themes,
                "characters_featured": _characters,
                "emotional_arc": _arc,
                "wisdom_gem": None,  # Removed: no longer generated
                "include_illustrations": include_illustrations,
                "illustrations": illustrations,
                "rhyme_time_mode": rhyme_time_mode,
                "learning_to_read_mode": learning_to_read_mode,
                "pages": pages,
                "adventure_steps": adventure_steps,
                "total_words": total_words,
                "total_pages": len(pages),
                "validation_issues": validation_issues,
                "story_duration": story_duration,
                "adventure_report": post_story.get("adventure_report", {}),
            }
            if superhero_meta is not None:
                # Frontend uses these IDs to track recent_villains/recent_problems
                # and avoid back-to-back duplicates on the next /generate-story call.
                story_payload["superhero_meta"] = superhero_meta

            # Persist Story row (skipped for anonymous — Story.user_id is NOT NULL
            # and references user.id). Failure must not break the response — the
            # story is already generated and the client expects it.
            if user_id and user_id != "anonymous":
                try:
                    db.session.add(
                        Story(
                            id=story_id,
                            user_id=str(user_id),
                            character_id=character_id if character_id else None,
                            title=title[:200] if title else None,
                            theme=theme[:100] if theme else None,
                            themes=_themes,
                            characters_featured=_characters,
                            emotional_arc=_arc,
                            # R2: persist the Celery task id and the full story
                            # payload so /task-status can recover a finished story
                            # from the DB once the Celery result expires (1h).
                            task_id=self.request.id,
                            content=story_payload,
                            # F-01 (MT-187): tag the row with which prompt template
                            # produced it (sha256[:16] of the builder's live source).
                            prompt_template_id=prompt_template_id,
                            prompt_revision_hash=prompt_revision_hash,
                        )
                    )
                    db.session.commit()
                    logger.info(
                        "story_persisted id=%s character_id=%s themes=%s chars=%s arc=%s",
                        story_id,
                        character_id,
                        _themes,
                        _characters,
                        _arc,
                    )
                except Exception:  # noqa: BLE001
                    db.session.rollback()
                    logger.exception(
                        "Failed to persist Story row (story still returned to caller)."
                    )

            # PERF-04 hardening: clear the cancel flag on normal completion too,
            # so a cancel that lost the race against the worker finishing never
            # lingers in Redis past task end. Best-effort (helper swallows errors;
            # the 10-min TTL is the backstop).
            clear_cancellation(self.request.id)

            return {
                "status": "complete",
                "story": {
                    **story_payload,
                    "_perf": {
                        "prompt_build_ms": round(prompt_build_ms, 1),
                        "ai_call_ms": round(ai_call_ms, 1),
                        "validation_ms": round(validation_ms, 1),
                        "total_ms": round(total_ms, 1),
                        "provider": provider_name,
                        "provider_sequence": provider_sequence,
                        "validation_attempts": validation_attempts,
                    },
                },
                "user_id": str(user_id),
            }

        except Exception as exc:
            db.session.rollback()
            error_msg = str(exc)
            total_ms = (time.perf_counter() - total_task_start) * 1000.0
            logger.debug("perf phase=total_task ms=%.1f", total_ms)
            logger.error("generate_story_task failed: %s", error_msg, exc_info=True)
            try:
                self.update_state(
                    state="FAILURE",
                    meta={"error": error_msg, "traceback": traceback.format_exc()},
                )
            except Exception as e:
                logger.warning(
                    f"Failed to update task state (Redis likely unavailable): {e}"
                )
            raise
