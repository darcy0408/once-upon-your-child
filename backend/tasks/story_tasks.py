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

from backend.celery_config import celery
from backend.database import db
from backend.models.character import Character
from backend.models.story import Story
from backend.models.user import User
from backend.services.story_generation_service import StoryGenerationService
from backend.services.openrouter_story_generator import OpenRouterStoryGenerator
from google.api_core import exceptions as google_exceptions
from backend.services.story_service import AdvancedStoryEngine, _safe_extract_title_and_gem, _build_learning_to_read_prompt, _build_rhyme_time_prompt, _build_bedtime_prompt, AGE_CONSTRAINTS, _get_age_band

logger = get_task_logger(__name__)
MAX_CUSTOM_ELEMENTS = 5
MAX_CUSTOM_ELEMENT_LENGTH = 80

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


def _fallback_story(theme: str, character_name: str | dict, companion: str = None) -> str:
    """Local fallback when all AI providers fail — returns valid JSON so tags never leak to the UI."""
    if isinstance(character_name, dict):
        name = character_name.get("name", "Hero")
    else:
        name = character_name

    theme_plain = theme.rstrip("! ").lower()
    theme_title = theme.rstrip("! ").title()
    comp = f" with their friend {companion}" if companion else ""

    return json.dumps({
        "title": f"The {theme_title} Adventure",
        "pages": [
            {"text": f"One bright morning, {name}{comp} set off on a wonderful {theme_plain} adventure. The sun was warm and anything felt possible."},
            {"text": f"{name} took a deep breath and walked forward with a brave and curious heart. Every step brought something new and exciting to discover."},
            {"text": f"Along the way{comp}, {name} found that the best adventures happen when you are kind and brave. Challenges became fun puzzles to solve together."},
            {"text": f"When the adventure was done, {name} came home with a happy heart. Tomorrow there would be a whole new adventure waiting — and {name} could not wait!"},
        ],
    })


def _classify_provider_failure(exc: Exception | None = None, message: str | None = None) -> str:
    raw_text = ""
    if exc is not None:
        raw_text = str(exc).strip()
    elif message:
        raw_text = str(message).strip()

    lowered = raw_text.lower()
    if isinstance(exc, google_exceptions.ResourceExhausted) or "quota" in lowered or "resourceexhausted" in lowered:
        return "429"
    if "401" in lowered or "unauthorized" in lowered or "invalid api key" in lowered or "api key not valid" in lowered:
        return "401"
    if "openrouter_api_key not set" in lowered:
        return "no_key"
    if "timeout" in lowered:
        return "timeout"
    if not raw_text:
        return "unknown"
    return raw_text.splitlines()[0][:80]


def _generate_story_text_with_metadata(
    prompt: str,
    theme: str,
    character_name: str,
    companion: str = None,
) -> tuple[str, str, list[str]]:
    provider_sequence: list[str] = []

    try:
        logger.info("Attempting story generation with primary service (Gemini)...")
        gemini_generator = StoryGenerationService()
        story_text = gemini_generator.generate_story(prompt)
        if story_text and not story_text.startswith("Sorry"):
            logger.info("Successfully generated story with primary service.")
            provider_sequence.append("gemini(success)")
            return story_text, "gemini", provider_sequence

        logger.warning("Primary service returned a 'Sorry' message.")
        provider_sequence.append(
            f"gemini(fail:{_classify_provider_failure(message=story_text)})"
        )
    except google_exceptions.ResourceExhausted as exc:
        logger.warning("Primary service (Gemini) is rate-limited. Falling back to OpenRouter.")
        provider_sequence.append(f"gemini(fail:{_classify_provider_failure(exc=exc)})")
    except Exception as exc:
        logger.exception("Primary service (Gemini) failed with an unexpected error.")
        provider_sequence.append(f"gemini(fail:{_classify_provider_failure(exc=exc)})")

    if os.getenv("OPENROUTER_API_KEY"):
        try:
            logger.info("Attempting story generation with fallback service (OpenRouter)...")
            openrouter_generator = OpenRouterStoryGenerator()
            story_text = openrouter_generator.generate_story(prompt)
            if story_text and not story_text.startswith("Sorry"):
                logger.info("Successfully generated story with fallback service.")
                provider_sequence.append("openrouter(success)")
                return story_text, "openrouter", provider_sequence

            logger.warning("Fallback service returned a 'Sorry' message.")
            provider_sequence.append(
                f"openrouter(fail:{_classify_provider_failure(message=story_text)})"
            )
        except Exception as exc:
            logger.exception("Fallback service (OpenRouter) also failed.")
            provider_sequence.append(f"openrouter(fail:{_classify_provider_failure(exc=exc)})")
    else:
        logger.warning("OPENROUTER_API_KEY not set. Cannot use fallback service.")
        provider_sequence.append("openrouter(fail:no_key)")

    logger.warning("All story generation providers failed. Returning local static fallback.")
    provider_sequence.append("static")
    return _fallback_story(theme, character_name, companion), "static", provider_sequence



def _generate_story_text(prompt: str, theme: str, character_name: str, companion: str = None) -> str:
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
    )
    return story_text

def _normalize_text_for_match(text: str) -> str:
    text = text.lower()
    text = re.sub(r"\s+", " ", text).strip()
    return text

def _normalize_phrase(phrase: str) -> str:
    phrase = phrase.strip().strip(".,;:!?")
    phrase = re.sub(r"\s+", " ", phrase)
    return phrase.lower()

def _parse_custom_elements(raw: str | None) -> list[str]:
    if not raw:
        return []
    raw = str(raw).strip()
    if not raw:
        return []

    # Preserve order while honoring quoted phrases
    elements: list[str] = []
    for match in re.finditer(r"\"([^\"]+)\"|'([^']+)'|[^,\n;]+", raw):
        token = match.group(1) or match.group(2) or match.group(0)
        token = token.strip()
        if (token.startswith('"') and token.endswith('"')) or (token.startswith("'") and token.endswith("'")):
            token = token[1:-1].strip()
        if token:
            elements.append(token)

    # Normalize, dedupe, and cap
    normalized = []
    seen = set()
    for element in elements:
        element = element.strip()
        if not element:
            continue
        if len(element) > MAX_CUSTOM_ELEMENT_LENGTH:
            element = element[:MAX_CUSTOM_ELEMENT_LENGTH].rstrip()
        key = element.lower()
        if key in seen:
            continue
        seen.add(key)
        normalized.append(element)
        if len(normalized) >= MAX_CUSTOM_ELEMENTS:
            break

    return normalized

def _find_missing_custom_elements(required: list[str], story_text: str) -> list[str]:
    if not required:
        return []
    normalized_story = _normalize_text_for_match(story_text)
    missing = []
    for phrase in required:
        normalized_phrase = _normalize_phrase(phrase)
        if not normalized_phrase:
            continue
        if normalized_phrase not in normalized_story:
            missing.append(phrase)
    return missing


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
    clean = clean.replace("y", "i") # Normalize y to i for phonetic matching
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
    end_words = [_extract_page_end_word(page) for page in pages if page and page.strip()]
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

    in_page_ok = in_page_checks > 0 and (in_page_hits / in_page_checks) >= min_pair_ratio
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

    sentence_parts = re.split(
        r"(?<=[.!?])(?=\s)|(?<=[.!?][\"')\]])(?=\s)", body
    )
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
        if (
            len(grouped) >= target_pages
            and all(len(g.split()) <= max_words for g in grouped)
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


@celery.task(bind=True, name="tasks.generate_story")
def generate_story_task(self, **kwargs: Dict[str, Any]) -> Dict[str, Any]:
    """
    Async story generation task.

    Expected kwargs:
        character_id: ID of character to personalize the story
        theme: Story theme
        user_id: Requesting user
        include_illustrations, rhyme_time_mode, learning_to_read_mode: Feature flags
        companion, therapeutic_prompt, feelings_prompt: Additional context
        character: Optional character name fallback when no ID is provided
    """
    with get_flask_app().app_context():
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
        include_illustrations = kwargs.get("include_illustrations", False)
        rhyme_time_mode = kwargs.get("rhyme_time_mode", False)
        learning_to_read_mode = kwargs.get("learning_to_read_mode", False)
        bedtime_mode = kwargs.get("bedtime_mode", False)
        story_length = kwargs.get("story_length", "standard")  # 'quick', 'standard', or 'epic' (legacy)
        story_duration = kwargs.get("story_duration")  # NEW: '5_minutes' or '10_minutes'
        age = kwargs.get("age", 5)  # User's age
        companion = kwargs.get("companion")  # Legacy support
        character_name_raw = kwargs.get("character") or "a brave adventurer"
        if isinstance(character_name_raw, dict):
            character_name = character_name_raw.get("name", "Hero")
        else:
            character_name = str(character_name_raw)
            
        char_details = kwargs.get("character_details") or {}
        custom_elements = kwargs.get("custom_elements", "")  # Free-form custom story requests
        required_custom_elements = _parse_custom_elements(custom_elements)

        # NEW: Extract structured companion data
        companion_pets = kwargs.get("companion_pets", [])  # List of pet dicts
        companion_characters = kwargs.get("companion_characters", [])  # List of character names

        try:
            character = db.session.get(Character, character_id) if character_id else None
            if character:
                character_name = character.name
            elif character_id:
                raise ValueError(f"Character {character_id} not found")

            try:
                self.update_state(state="PROCESSING", meta={"status": "Generating story..."})
            except Exception as e:
                logger.warning(f"Failed to update task state (Redis likely unavailable): {e}")

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
                            companion_character_details.append({
                                'name': char_record.name,
                                'age': char_record.age,
                                'role': char_record.role,
                                'gender': char_record.gender,
                            })
                            logger.info(f"Found companion character: {char_name} (age {char_record.age}, {char_record.role})")
                        else:
                            # Character not found in database, just pass the name
                            logger.warning(f"Companion character '{char_name}' not found in database")
                            companion_character_details.append({'name': char_name})

            engine = AdvancedStoryEngine()

            prompt_build_start = time.perf_counter()

            # Use specialized prompts based on story mode flags
            if bedtime_mode:
                logger.info(f"Using Bedtime prompt (length: {story_length})")
                extra_chars = kwargs.get("additional_characters") or char_details.get("additionalCharacters")
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
                    extra_characters=kwargs.get("additional_characters") or char_details.get("additionalCharacters"),
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
                    extra_characters=kwargs.get("additional_characters") or char_details.get("additionalCharacters"),
                    story_length=story_length,
                    custom_elements=custom_elements,
                    world_bible=kwargs.get("world_bible", ""),
                    conflict_hook=kwargs.get("conflict_hook", ""),
                    sensory_palette=kwargs.get("sensory_palette", ""),
                )
                logger.info(f"Full prompt for rhyme time mode: {prompt}")
            else:
                # Standard enhanced prompt
                logger.info(f"Using standard enhanced prompt (length: {story_length}, duration: {story_duration})")
                prompt = engine.generate_enhanced_prompt(
                    character=character_name,
                    theme=theme,
                    companion=companion,  # Legacy: keep for backward compatibility
                    companion_pets=companion_pets,  # NEW: List of pet companions
                    companion_characters=companion_character_details,  # NEW: List of character companion DETAILS
                    spark_tool=kwargs.get("spark_tool"), # NEW
                    mood_physics=kwargs.get("mood_physics"), # NEW
                    conflict_hook=kwargs.get("conflict_hook"), # NEW
                    sensory_palette=kwargs.get("sensory_palette"), # NEW
                    custom_elements=custom_elements,  # NEW: Free-form custom story requests
                    additional_characters=kwargs.get("additional_characters") or char_details.get("additionalCharacters"),
                    therapeutic_prompt=kwargs.get("therapeutic_prompt", ""),
                    feelings_prompt=kwargs.get("feelings_prompt"),
                    character_details=char_details,
                    story_length=story_length,  # Legacy: Story length option
                    story_duration=story_duration,  # NEW: Duration-based generation
                    age=age,   # NEW: Pass age for calibration
                )
            prompt_build_ms = (time.perf_counter() - prompt_build_start) * 1000.0
            logger.debug("perf phase=prompt_build ms=%.1f", prompt_build_ms)

            logger.info(f"Companion Pets: {companion_pets}")
            logger.info(f"Companion Character Details: {companion_character_details}")
            logger.info(f"Generated Prompt Snippet: {prompt[:500]}...")

            # Collect mandatory names for validation
            mandatory_names = [character_name]
            for p in companion_pets:
                if isinstance(p, dict) and p.get('name'):
                    mandatory_names.append(p['name'])
            for c in companion_character_details:
                if isinstance(c, dict) and c.get('name'):
                    mandatory_names.append(c['name'])
            
            extra_chars = kwargs.get("additional_characters") or char_details.get("additionalCharacters")
            if extra_chars:
                for ec in extra_chars:
                    name = ec.get('name') if isinstance(ec, dict) else str(ec)
                    if name:
                        mandatory_names.append(name)
            
            logger.info(f"Mandatory names for validation: {mandatory_names}")

            # Tier-aware retry cap: free tier gets 2 attempts (not 3) to bound
            # Gemini cost on validation failures. Premium/Family/BYOK keep 3.
            user_tier = 'free'
            if user_id and user_id != 'anonymous':
                try:
                    _u = User.query.filter_by(id=user_id).first()
                    if _u and _u.subscription_tier:
                        user_tier = _u.subscription_tier.lower()
                except Exception:
                    logger.debug("could not resolve user tier", exc_info=True)
            max_attempts = 2 if user_tier == 'free' else 3
            attempt = 0
            validation_loop_start = time.perf_counter()
            while attempt < max_attempts:
                attempt += 1
                validation_attempts = attempt
                logger.info(f"Generation attempt {attempt}/{max_attempts} (tier={user_tier})")

                ai_call_start = time.perf_counter()
                story_text, provider_name, provider_sequence = _generate_story_text_with_metadata(
                    prompt,
                    theme,
                    character_name,
                    companion,
                )
                attempt_ai_call_ms = (time.perf_counter() - ai_call_start) * 1000.0
                ai_call_ms += attempt_ai_call_ms
                logger.debug(
                    "perf phase=ai_call provider=%s ms=%.1f",
                    provider_name,
                    attempt_ai_call_ms,
                )
                title, _, story_body, pages, post_story = _safe_extract_title_and_gem(story_text, theme)
                
                # Validation Logic (Content Sanitizer)
                is_clean = True
                validation_error = None
                forbidden_patterns = ["REQUEST SUMMARY", "SIGNATURE POWER", "CRITICAL:"]
                page_pattern = re.compile(r"\bPAGE\s+\d+\b", re.IGNORECASE)
                
                for page in pages:
                    if any(p in page for p in forbidden_patterns) or page_pattern.search(page):
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
                if learning_to_read_mode:
                    is_rhyme_quality_ok = _is_ltr_rhyme_quality_ok(pages)
                    if not is_rhyme_quality_ok:
                        validation_error = "Learning-to-read story did not meet rhyme quality checks"

                    # Compute expected page count for this age/length to match prompt floor.
                    try:
                        _ltr_band = _get_age_band(age)
                        _ltr_cfg = AGE_CONSTRAINTS[_ltr_band]['ltr']
                        if story_length in ('short', 'quick'):
                            _ltr_len_key = 'short'
                        elif story_length in ('long', 'epic'):
                            _ltr_len_key = 'long'
                        else:
                            _ltr_len_key = 'medium'
                        ltr_expected_pages = max(5, _ltr_cfg[_ltr_len_key])
                    except Exception:  # noqa: BLE001 — defensive, never break generation
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
                    is_long_mode = (story_duration == '10_minutes' or story_length == 'epic')
                    is_standard_mode = (story_length == 'standard')

                    if age <= 5:
                        min_words_threshold = 250 if is_standard_mode else 100
                    elif age <= 7:
                        min_words_threshold = 500 if is_standard_mode else 300
                    elif age == 8:
                        min_words_threshold = 1300 if is_long_mode else 700
                    elif age <= 12:
                        min_words_threshold = 1700 if is_long_mode else 1100
                    else: # 13+
                        min_words_threshold = 2400 if is_long_mode else 1700

                    if total_words < min_words_threshold:
                        is_long_enough = False
                        validation_error = f"Story too short ({total_words} words, needed {min_words_threshold})"
                
                if is_clean and is_long_enough and is_rhyme_quality_ok and is_ltr_format_ok:
                    logger.info("Story passed validation.")
                    break
                else:
                    logger.warning(f"Validation failed on attempt {attempt}: {validation_error}")
                    if attempt < max_attempts:
                        # Append feedback to prompt for next attempt
                        if not is_clean:
                            prompt += "\n\nRETRY INSTRUCTION: Never output internal meta or 'PAGE X' markers. Return ONLY story text in the pages array."
                            if missing_names:
                                prompt += "\n\nRETRY INSTRUCTION: The story MUST include these characters by name: " + ", ".join(missing_names)
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
                    else:
                        logger.error("Max attempts reached. Returning best effort.")
            validation_loop_ms = (time.perf_counter() - validation_loop_start) * 1000.0
            validation_ms = max(validation_loop_ms - ai_call_ms, 0.0)
            logger.debug("perf phase=validation ms=%.1f", validation_ms)

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

            # --- Output content moderation ---
            # Two-layer safety check on the generated story before it reaches the child.
            # Layer 1: fast age-band-aware keyword filter.
            # Layer 2: LLM-based contextual classifier (skipped if Layer 1 already flagged).
            # Both layers fail open — story is delivered and logged rather than crashed.
            from backend.utils.app_helpers import make_filter_story_content
            from backend.utils.content_moderator import moderate_story_content

            _filter_fn = make_filter_story_content(logger)
            _, keyword_flagged = _filter_fn(story_body, age)

            llm_flagged = False
            llm_flag_reason = ""
            if not keyword_flagged:
                llm_safe, llm_flag_reason = moderate_story_content(story_body, age)
                llm_flagged = not llm_safe

            if keyword_flagged or llm_flagged:
                flag_source = "keyword filter" if keyword_flagged else f"LLM classifier ({llm_flag_reason})"
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
                    additional_characters=kwargs.get("additional_characters") or char_details.get("additionalCharacters"),
                    therapeutic_prompt=kwargs.get("therapeutic_prompt", ""),
                    feelings_prompt=kwargs.get("feelings_prompt"),
                    character_details=char_details,
                    story_length=story_length,
                    story_duration=story_duration,
                    age=age,
                )
                fallback_text = _generate_story_text(fallback_prompt, theme, character_name, companion)
                fallback_title, _, fallback_body, fallback_pages, fallback_post = _safe_extract_title_and_gem(
                    fallback_text, theme
                )
                if fallback_body:
                    title = fallback_title
                    story_body = fallback_body
                    pages = fallback_pages
                    post_story = fallback_post

            # --- End output content moderation ---

            # NEW: Page-based story structure for duration-based generation
            adventure_steps = []
            validation_issues = []

            if story_duration and not rhyme_time_mode and not learning_to_read_mode:
                # Use page-based system for regular duration stories
                try:
                    from backend.services.story_duration_service import (
                        AdventureStepGenerator,
                        DurationConfig
                    )

                    # Get configuration
                    config = DurationConfig.get_config(story_duration, age)

                    # Use pages from LLM if it returned at least min_pages; otherwise re-split.
                    # Models routinely under-paginate (3 dense pages instead of 5-8), leaving a
                    # tiny tail page or unbalanced pacing — PageSplitter rebalances on word counts.
                    _min_pages = max(2, int(config.get('min_pages', 2)))
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
                            target_words_per_page=config['words_per_page'],
                            min_pages=config['min_pages'],
                            max_pages=config['max_pages']
                        )

                    # Generate adventure step labels
                    adventure_steps = AdventureStepGenerator.generate_steps(
                        story_duration,
                        age,
                        len(pages)
                    )

                    # Validate story
                    from backend.services.story_duration_service import StoryValidator
                    is_valid, issues = StoryValidator.validate_story(
                        story_body,
                        pages,
                        story_duration,
                        age
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

            return {
                "status": "complete",
                "story": {
                    "id": story_id,
                    "title": title,
                    "story_text": story_body,
                    "theme": theme,
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
                logger.warning(f"Failed to update task state (Redis likely unavailable): {e}")
            raise
