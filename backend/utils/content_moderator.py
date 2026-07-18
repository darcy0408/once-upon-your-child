"""LLM-based post-generation content safety classifier.

This is the second layer of output moderation, used after the fast keyword
filter in app_helpers.py. It catches contextual and subtle safety violations
that keyword matching cannot reliably detect.

Provider (MT-137 launch-gate): this classifier runs on the SAME OpenAI client
and model family already used for children's story TEXT
(``services/openai_story_generator.py``), via ``OPENAI_API_KEY``. It was
previously on ``gemini-2.5-flash-lite``, but sending a minor's story text to
Gemini *for moderation* trips the very Gemini Additional Terms (no child-
directed apps) that drove story text off Gemini in the first place. Routing
moderation through OpenAI also removes a resilience trap: the moderator no
longer depends on ``GEMINI_API_KEY``, so a missing/rotated Gemini key can no
longer silently degrade moderation and push every minor's story into the safe
fallback. The safety posture (fail-open by default, fail-closed for minors via
``fail_closed=True``) is UNCHANGED — only the provider moved.

Design principles:
- Fail open by default: if the classifier errors, the story passes (the keyword
  filter already ran as the first layer). Callers protecting minors pass
  ``fail_closed=True`` to invert this to fail-CLOSED.
- Age-band-aware: the classifier prompt is tailored to the child's age.
- Fast and cheap: uses a small OpenAI model (gpt-5-mini by default), classified
  at low reasoning effort. Overridable via OPENAI_MODERATION_MODEL.
- Classifies only; never modifies story text.
"""

import json
import logging
import os
from concurrent.futures import ThreadPoolExecutor

logger = logging.getLogger(__name__)

# Moderation runs on the same OpenAI model family as story text (gpt-5-mini).
# Overridable via OPENAI_MODERATION_MODEL so a deployment can point moderation
# at a different OpenAI model without touching story-text generation. Model IDs
# are bare OpenAI slugs (e.g. "gpt-5-mini", "gpt-4.1-mini").
_DEFAULT_MODERATION_MODEL = "gpt-5-mini"

# Output-token budget for one classification call. The visible output is a
# one-line JSON verdict, but gpt-5 is a reasoning family: the budget must also
# cover hidden reasoning tokens or the response comes back empty (finish_reason
# =length), which the moderator treats as "unverified" and — for a minor on the
# fail-closed path — would needlessly route a good story into the safe fallback.
# A generous default avoids that; overridable via OPENAI_MODERATION_MAX_TOKENS.
_DEFAULT_MODERATION_MAX_TOKENS = 2048

# Reasoning effort for the classification call. "low" keeps latency/cost down
# while leaving enough budget to emit the JSON verdict (mirrors the story
# generator's taste-test config). Set OPENAI_MODERATION_REASONING_EFFORT to
# none/off/"" to omit the param entirely — required when overriding to a
# non-reasoning model (e.g. gpt-4.1-mini) that rejects ``reasoning_effort``.
_DEFAULT_MODERATION_REASONING_EFFORT = "low"

# Sentinels that mean "send no reasoning_effort param" (mirrors
# openai_story_generator._NO_REASONING_SENTINELS).
_NO_REASONING_SENTINELS = frozenset({"", "none", "off", "default"})

# Short system framing; the detailed rubric is built per-chunk as the user
# message. Reinforces JSON-only output at the system level.
_MODERATION_SYSTEM_PROMPT = (
    "You are a strict child-content safety classifier. You never write or "
    "modify stories — you only judge the text you are given and reply with the "
    "exact JSON object requested, and nothing else."
)

# Upper age bound of the Sprout band (ages 3-5). The interactive story path
# fails CLOSED for this band: if the LLM classifier errors, the segment is
# replaced with SAFE_FALLBACK_SEGMENT rather than served unmoderated. Older
# bands keep the deliberate fail-open behaviour (the keyword filter ran first).
SPROUT_MAX_AGE = 5

# Upper age bound of "still a minor". The interactive story path fails CLOSED
# for every minor band (matching the main /generate-story path in
# story_tasks.py, where ``_mod_age <= 17`` fails closed): a classifier outage
# routes the segment to SAFE_FALLBACK_SEGMENT rather than serving unvetted text
# to a child. Only true adults (18+) keep the fail-open behaviour.
MINOR_MAX_AGE = 17

# Generic, always-safe interactive segment served when moderation fails closed
# for the Sprout band, or when a generated segment is flagged. Deliberately
# gentle, choice-bearing, and free of any custom/free-text input so it cannot
# itself carry whatever made the original segment unsafe.
SAFE_FALLBACK_SEGMENT = {
    "title": "A Gentle Pause",
    "content": (
        "The little hero takes a slow, deep breath. The sun is warm and the "
        "garden is calm and safe. A friendly butterfly lands softly nearby and "
        "waits, ready for the next part of the adventure."
    ),
    "image_description": (
        "a warm, gentle children's book illustration of a sunny garden with a "
        "friendly butterfly, soft and calm"
    ),
    "output_type": "CHOICE",
    "choices": [
        {"id": "choice_1", "text": "Follow the friendly butterfly"},
        {"id": "choice_2", "text": "Rest in the warm sunshine"},
    ],
    "inventory": [],
    "story_state": {},
    "is_ending": False,
}


def is_sprout_band(age) -> bool:
    """True if *age* falls in the Sprout band (3-5), which fails closed."""
    try:
        return int(age) <= SPROUT_MAX_AGE
    except (TypeError, ValueError):
        # Unknown age — treat as the most protected band.
        return True


def is_minor_band(age) -> bool:
    """True if *age* is a minor (<=17) and so should fail CLOSED on moderation.

    Mirrors the main story path (``story_tasks.py`` ``_mod_age <= 17``): any
    child, not just Sprout, gets a safe fallback rather than unvetted text when
    the LLM classifier is unavailable. An unknown/unparseable age is treated as
    a minor (most protected).
    """
    try:
        return int(age) <= MINOR_MAX_AGE
    except (TypeError, ValueError):
        # Unknown age — treat as the most protected (fail closed).
        return True


def build_safe_fallback_segment(
    segment_number: int = 1, is_opening: bool = True, is_ending: bool = False
) -> dict:
    """Return a fresh copy of SAFE_FALLBACK_SEGMENT shaped for the caller.

    A copy is returned each call so callers can mutate it freely (e.g. when
    persisting a StorySegment record) without corrupting the module template.

    When *is_ending* is True the fallback is shaped as a story ENDING: gentle
    safe content but with NO choices and flagged terminal. This matters when
    substituting for a flagged/unverifiable FINAL segment — without it, the
    choice-bearing default fallback would resurrect a completed story into one
    that appears to keep going.
    """
    segment = json.loads(json.dumps(SAFE_FALLBACK_SEGMENT))
    segment["segment_number"] = segment_number
    if is_ending:
        segment["title"] = "A Gentle Ending"
        segment["content"] = (
            "The little hero takes a slow, deep breath. The sun is warm and the "
            "garden is calm and safe. It has been a good adventure — and now it "
            "is time to rest. The end."
        )
        segment["output_type"] = "ENDING"
        segment["choices"] = []
        segment["is_ending"] = True
    return segment


# Module-level client — initialised lazily so tests can patch os.getenv.
_client = None


def _make_moderation_client(api_key: str):
    """Lazily import the OpenAI SDK and build a client. Patched in tests.

    Mirrors ``openai_story_generator._make_openai_client`` so the moderator uses
    the exact same SDK/client construction as story-text generation. Kept as a
    module function (not an inline import) so unit tests can stub the SDK without
    the ``openai`` package being installed.
    """
    import openai  # lazy: see module docstring

    # Bound every HTTP call: the SDK defaults (600s per-attempt timeout,
    # 2 retries) would let one hung moderation call pin the Celery worker far
    # longer than the story generation it is checking. A verdict is a small
    # completion — 30s is generous.
    return openai.OpenAI(api_key=api_key, timeout=30.0, max_retries=1)


def _get_client():
    global _client
    if _client is None:
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY not set")
        _client = _make_moderation_client(api_key)
    return _client


def _resolve_moderation_model() -> str:
    """OpenAI model slug for the classifier, overridable via env."""
    return os.getenv("OPENAI_MODERATION_MODEL") or _DEFAULT_MODERATION_MODEL


def _resolve_moderation_max_tokens() -> int:
    """Output-token budget for one call, overridable via env."""
    raw = os.getenv("OPENAI_MODERATION_MAX_TOKENS")
    if not raw:
        return _DEFAULT_MODERATION_MAX_TOKENS
    try:
        value = int(raw)
        return value if value > 0 else _DEFAULT_MODERATION_MAX_TOKENS
    except (TypeError, ValueError):
        logger.warning(
            "OPENAI_MODERATION_MAX_TOKENS=%r is not a valid int; using %s.",
            raw,
            _DEFAULT_MODERATION_MAX_TOKENS,
        )
        return _DEFAULT_MODERATION_MAX_TOKENS


def _resolve_moderation_reasoning_effort() -> str | None:
    """Reasoning effort for the call, or None to omit the param entirely.

    Returns None when OPENAI_MODERATION_REASONING_EFFORT is a no-reasoning
    sentinel so a non-reasoning override model doesn't 400 on the unsupported
    ``reasoning_effort`` argument.
    """
    raw = os.getenv("OPENAI_MODERATION_REASONING_EFFORT")
    if raw is None:
        return _DEFAULT_MODERATION_REASONING_EFFORT
    effort = raw.strip().lower()
    if effort in _NO_REASONING_SENTINELS:
        return None
    return effort


def _extract_classification_text(choice) -> str:
    """Pull the classifier's raw text out of an OpenAI Chat Completions choice.

    Returns "" when the response was refused / content-filtered / empty so the
    caller treats it as unverified (fail-open or fail-closed per the flag) —
    matching the prior Gemini behaviour of an empty response.
    """
    if choice is None:
        return ""
    if getattr(choice, "finish_reason", None) == "content_filter":
        # The moderation model itself blocked the text. Treat as unverified
        # (not an auto-pass): under fail_closed this correctly blocks; on the
        # legacy fail-open path it preserves the prior "empty -> pass" posture.
        logger.warning(
            "content_moderator: classifier response content-filtered; "
            "treating as unverified."
        )
        return ""
    message = getattr(choice, "message", None)
    if getattr(message, "refusal", None):
        logger.warning(
            "content_moderator: classifier returned a structured refusal; "
            "treating as unverified."
        )
        return ""
    content = getattr(message, "content", None) or ""
    return content.strip()


def _age_band_label(age: int) -> str:
    if age <= 5:
        return "a young child aged 3-5"
    if age <= 8:
        return "a child aged 6-8"
    if age <= 12:
        return "a child aged 9-12"
    if age <= 17:
        return "a teenager aged 13-17"
    return "an adult"


def _age_allowance(age: int) -> str:
    """Age-band-aware allowance clause for the moderation prompt.

    The hard UNSAFE list always applies. This clause tells the classifier what
    is *developmentally appropriate* for the band so it doesn't over-flag the
    very content these age groups need — e.g. an Adventurer (9-12) social-
    emotional story that honestly (non-graphically) depicts peer pressure or an
    unsafe adult so the child can recognize it, make a safe choice, and reach a
    trusted adult. Without this, the classifier strips exactly the SEL content
    that helps. (Adventurer audit A-005.)
    """
    if age <= 8:
        return (
            "Keep peril very mild and brief; no scary, dark, or threatening "
            "themes. Anything beyond gentle, quickly-resolved trouble is unsafe."
        )
    if age <= 12:
        return (
            "The following ARE developmentally appropriate for this age and "
            "must NOT be flagged on their own: mild peril or suspense, spooky "
            "atmosphere, and honest, NON-graphic depiction of peer pressure or "
            "of an adult behaving unsafely (e.g. a grown-up who has been "
            "drinking, or a peer offering something dangerous) WHEN the story is "
            "helping the child recognize it, make a safe choice, and reach a "
            "trusted adult. Flag such content only if it is graphic, glamorizing, "
            "instructional, or frightening beyond what serves the lesson."
        )
    return (
        "Mature but non-graphic treatment of real social, emotional, and safety "
        "topics is appropriate for this age; apply the UNSAFE list, not a "
        "younger-child standard."
    )


# F-03: the classifier previously inspected only story_text[:3000] — roughly
# the first ~500 words. A teen-band "long" story runs 3400-4500 words, so the
# climax and ending went unmoderated. Stories are now split into chunks and
# every chunk is classified.
#
# _CHUNK_SIZE: characters sent to the classifier in one call. flash-lite
# handles far more, but bounded chunks keep latency and cost predictable.
# _MAX_CHUNKS: hard ceiling so a pathologically long input cannot fan out into
# unbounded classifier calls. 5 * 12000 = 60000 chars (~10k words) comfortably
# exceeds the longest age-band target (adult 'long').
_CHUNK_SIZE = 12000
_MAX_CHUNKS = 5


def _split_into_chunks(
    text: str, chunk_size: int = _CHUNK_SIZE, max_chunks: int = _MAX_CHUNKS
) -> list[str]:
    """Split *text* into at most *max_chunks* pieces of roughly *chunk_size*.

    Breaks on a paragraph boundary where possible, then a sentence end, then a
    space, so the classifier always sees coherent prose rather than a word cut
    in half. A story longer than chunk_size * max_chunks is truncated at that
    bound — the leading 60k characters are still fully classified.
    """
    text = (text or "").strip()
    if not text:
        return []
    if len(text) <= chunk_size:
        return [text]

    chunks: list[str] = []
    remaining = text
    while remaining and len(chunks) < max_chunks:
        if len(remaining) <= chunk_size:
            chunks.append(remaining)
            break
        window = remaining[:chunk_size]
        # Prefer a paragraph break; fall back to a sentence end, then a space.
        split_at = window.rfind("\n\n")
        if split_at < chunk_size // 2:
            split_at = max(window.rfind(". "), window.rfind("! "), window.rfind("? "))
        if split_at < chunk_size // 2:
            split_at = window.rfind(" ")
        if split_at <= 0:
            split_at = chunk_size
        chunks.append(remaining[: split_at + 1].strip())
        remaining = remaining[split_at + 1 :].strip()
    return [c for c in chunks if c]


def moderate_story_content(
    story_text: str, age: int, client=None, fail_closed: bool = False
) -> tuple[bool, str]:
    """Check a generated story for age-inappropriate content using an LLM classifier.

    Args:
        story_text: The full generated story text.
        age: The child's age (used to set age-appropriate safety thresholds).
        client: Optional OpenAI client instance (openai.OpenAI). If None, uses
            the module-level client initialised from OPENAI_API_KEY.
        fail_closed: When True, a classifier error returns (False, <reason>)
            instead of (True, "") — i.e. the content is treated as UNSAFE
            when the classifier could not vet it. The interactive Sprout-band
            path (ages 3-5) and the standard pre-teen path set this so
            unmoderated content is never served to the youngest children.
            Defaults to False (fail open).

    Returns:
        (is_safe, reason) — is_safe=True means content passed, reason is
        empty string when safe or a brief explanation when flagged.

    The full story is classified in chunks (F-03); the first chunk that is
    flagged or that cannot be verified determines the result. On a classifier
    error the function fails open by default, or closed when fail_closed=True.
    """
    if not story_text or not story_text.strip():
        return True, ""

    # Result returned when the classifier cannot run / cannot be trusted.
    _unverified = (False, "moderation unavailable") if fail_closed else (True, "")

    if client is None:
        try:
            client = _get_client()
        except Exception as exc:
            logger.warning(
                f"content_moderator: could not initialise client ({exc!r}), "
                f"{'failing closed' if fail_closed else 'failing open'}"
            )
            return _unverified

    age_label = _age_band_label(age)

    chunks = _split_into_chunks(story_text)
    if len(chunks) == 1:
        return _classify_chunk(
            chunks[0], age, age_label, client, fail_closed, _unverified
        )

    # Chunks are judged independently ("judge it on its own content"), so
    # classify them concurrently: a multi-chunk (teen "long") story pays one
    # call's latency instead of N serial calls. The OpenAI client is
    # thread-safe, and _MAX_CHUNKS bounds the fan-out at 5 threads.
    with ThreadPoolExecutor(max_workers=len(chunks)) as pool:
        results = list(
            pool.map(
                lambda chunk: _classify_chunk(
                    chunk, age, age_label, client, fail_closed, _unverified
                ),
                chunks,
            )
        )
    for index, (is_safe, reason) in enumerate(results):
        if not is_safe:
            if reason and reason != "moderation unavailable":
                logger.warning(
                    f"content_moderator: chunk {index + 1}/{len(chunks)} "
                    f"flagged for age {age} — {reason!r}"
                )
            return False, reason
    return True, ""


def _classify_chunk(
    story_text: str,
    age: int,
    age_label: str,
    client,
    fail_closed: bool,
    _unverified: tuple[bool, str],
) -> tuple[bool, str]:
    """Classify a single chunk of story text. See moderate_story_content."""
    if not story_text or not story_text.strip():
        return True, ""

    prompt = (
        f"You are a child content safety reviewer. Read the following story written for "
        f"{age_label} and determine whether it is safe and appropriate.\n\n"
        f"Flag the story as UNSAFE if it contains ANY of the following:\n"
        f"- Sexual content or innuendo\n"
        f"- Graphic violence, gore, or torture\n"
        f"- Self-harm or suicide themes\n"
        f"- Graphic, instructional, or glamorizing depiction of drug, alcohol, or weapon use\n"
        f"- Real personal information (e.g. real school names, home addresses, phone numbers)\n"
        f"- Any URL, web address, email address, or instruction to leave the app "
        f"or contact someone outside it (e.g. 'visit ...', 'go to ...com', "
        f"'message me at ...', or a username/handle to add or message)\n"
        f"- Content that would be frightening or harmful for {age_label}\n\n"
        f"AGE-APPROPRIATENESS NOTE: {_age_allowance(age)}\n\n"
        f"Respond ONLY with a JSON object — no other text:\n"
        f'  {{"safe": true}} if the story is appropriate\n'
        f'  {{"safe": false, "reason": "brief explanation"}} if it is not\n\n'
        f"This is one section of a longer story; judge it on its own content.\n"
        f"Story section:\n{story_text}"
    )

    try:
        kwargs = {
            "model": _resolve_moderation_model(),
            "max_completion_tokens": _resolve_moderation_max_tokens(),
            "messages": [
                {"role": "system", "content": _MODERATION_SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
        }
        reasoning_effort = _resolve_moderation_reasoning_effort()
        if reasoning_effort is not None:
            kwargs["reasoning_effort"] = reasoning_effort

        response = client.chat.completions.create(**kwargs)
        choice = (getattr(response, "choices", None) or [None])[0]
        raw = _extract_classification_text(choice)

        if not raw:
            logger.warning(
                "content_moderator: empty response from classifier, "
                f"{'failing closed' if fail_closed else 'failing open'}"
            )
            return _unverified

        # Strip markdown code fences if the model wrapped its JSON
        if raw.startswith("```"):
            lines = raw.splitlines()
            raw = "\n".join(
                line for line in lines if not line.startswith("```")
            ).strip()

        result = json.loads(raw)
        is_safe = bool(result.get("safe", True))
        reason = result.get("reason", "") if not is_safe else ""

        if not is_safe:
            logger.warning(
                f"content_moderator: story flagged for age {age} — {reason!r} "
                f"(first 200 chars): {story_text[:200]!r}"
            )

        return is_safe, reason

    except json.JSONDecodeError:
        logger.warning(
            f"content_moderator: could not parse classifier response {raw[:200]!r}, "
            f"{'failing closed' if fail_closed else 'failing open'}"
        )
        return _unverified
    except Exception as exc:
        logger.warning(
            f"content_moderator: classifier error ({exc!r}), "
            f"{'failing closed' if fail_closed else 'failing open'}"
        )
        return _unverified
