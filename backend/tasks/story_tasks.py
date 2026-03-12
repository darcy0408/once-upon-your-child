import os
import re
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
from backend.services.story_service import AdvancedStoryEngine, _safe_extract_title_and_gem, _build_learning_to_read_prompt, _build_rhyme_time_prompt

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
    """Local fallback story used when the AI generator fails."""
    if isinstance(character_name, dict):
        name = character_name.get("name", "Hero")
    else:
        name = character_name
        
    story = f"[TITLE: A {theme.title()} Adventure]\n"
    story += f"{name} embarks on a quick quest about {theme.lower()}"
    if companion:
        story += f" with their friend {companion}"
    story += " and discovers that courage grows with every kind choice.\n"
    story += "[WISDOM GEM: Always be kind.]\n"
    return story



def _generate_story_text(prompt: str, theme: str, character_name: str, companion: str = None) -> str:
    """
    Generate story text with a tiered fallback system.
    1. Try Gemini via StoryGenerationService.
    2. On rate limit error, fall back to a free OpenRouter model.
    3. If all else fails, use a local static story.
    """
    try:
        # 1. Try primary service (Gemini)
        logger.info("Attempting story generation with primary service (Gemini)...")
        gemini_generator = StoryGenerationService()
        story_text = gemini_generator.generate_story(prompt)
        # The retry logic is now inside the service, but we still check the output
        if story_text and not story_text.startswith("Sorry"):
            logger.info("Successfully generated story with primary service.")
            return story_text
        logger.warning("Primary service returned a 'Sorry' message.")
        # Fall back to OpenRouter if available, even when Gemini fails unexpectedly.
        if os.getenv("OPENROUTER_API_KEY"):
            try:
                logger.info("Attempting story generation with fallback service (OpenRouter)...")
                openrouter_generator = OpenRouterStoryGenerator()
                story_text = openrouter_generator.generate_story(prompt)
                if story_text and not story_text.startswith("Sorry"):
                    logger.info("Successfully generated story with fallback service.")
                    return story_text
                logger.warning("Fallback service returned a 'Sorry' message.")
            except Exception:
                logger.exception("Fallback service (OpenRouter) also failed.")
    except google_exceptions.ResourceExhausted:
        # 2. On rate limit, fall back to secondary service (OpenRouter)
        logger.warning("Primary service (Gemini) is rate-limited. Falling back to OpenRouter.")
        try:
            if os.getenv("OPENROUTER_API_KEY"):
                logger.info("Attempting story generation with fallback service (OpenRouter)...")
                openrouter_generator = OpenRouterStoryGenerator()
                story_text = openrouter_generator.generate_story(prompt)
                if story_text and not story_text.startswith("Sorry"):
                    logger.info("Successfully generated story with fallback service.")
                    return story_text
                logger.warning("Fallback service returned a 'Sorry' message.")
            else:
                logger.warning("OPENROUTER_API_KEY not set. Cannot use fallback service.")
        except Exception:
            logger.exception("Fallback service (OpenRouter) also failed.")
    except Exception:
        logger.exception("Primary service (Gemini) failed with an unexpected error.")

    # 3. If all services fail, raise an exception to notify frontend
    logger.error("All story generation services failed.")
    raise Exception("Story generation failed. Please check backend logs or API keys.")

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
    if len(clean) < 2:
        return clean
    if clean.endswith("e") and len(clean) > 3:
        clean = clean[:-1]
    # Use substring from last vowel to end (e.g., "cat" -> "at", "sun" -> "un")
    match = re.search(r"[aeiouy][a-z]*$", clean)
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
        character_id = kwargs.get("character_id")
        theme = kwargs.get("theme") or "Adventure"
        user_id = kwargs.get("user_id") or "anonymous"
        include_illustrations = kwargs.get("include_illustrations", False)
        rhyme_time_mode = kwargs.get("rhyme_time_mode", False)
        learning_to_read_mode = kwargs.get("learning_to_read_mode", False)
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

            # Use specialized prompts based on story mode flags
            if learning_to_read_mode and age < 9:

                logger.info(f"Using Learning to Read prompt (length: {story_length})")
                age = kwargs.get("age", 5)
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
                    companion_characters=companion_characters,
                    extra_characters=kwargs.get("additional_characters") or char_details.get("additionalCharacters"),
                    story_length=story_length,
                    custom_elements=custom_elements,
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

            # Story generation with validation and retry logic
            max_attempts = 3
            attempt = 0
            while attempt < max_attempts:
                attempt += 1
                logger.info(f"Generation attempt {attempt}/{max_attempts}")
                
                story_text = _generate_story_text(prompt, theme, character_name, companion)
                title, wisdom_gem, story_body, pages, post_story = _safe_extract_title_and_gem(story_text, theme)
                
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

                missing_custom_elements = _find_missing_custom_elements(required_custom_elements, story_body)
                if missing_custom_elements:
                    is_clean = False
                    validation_error = f"Missing custom elements: {', '.join(missing_custom_elements)}"
                
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
                if learning_to_read_mode:
                    is_rhyme_quality_ok = _is_ltr_rhyme_quality_ok(pages)
                    if not is_rhyme_quality_ok:
                        validation_error = "Learning-to-read story did not meet rhyme quality checks"

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
                
                if is_clean and is_long_enough and is_rhyme_quality_ok:
                    logger.info("Story passed validation.")
                    break
                else:
                    logger.warning(f"Validation failed on attempt {attempt}: {validation_error}")
                    if attempt < max_attempts:
                        # Append feedback to prompt for next attempt
                        if not is_clean:
                            prompt += "\n\nRETRY INSTRUCTION: Never output internal meta or 'PAGE X' markers. Return ONLY story text in the pages array."
                            if missing_custom_elements:
                                prompt += "\n\nRETRY INSTRUCTION: The story must include these exact phrases at least once each: " + ", ".join(missing_custom_elements)
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
                    else:
                        logger.error("Max attempts reached. Returning best effort.")

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

                    # Use pages from LLM if valid, otherwise split legacy style
                    if not pages or len(pages) < 2:
                        from backend.services.story_duration_service import PageSplitter
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

            return {
                "status": "complete",
                "story": {
                    "id": story_id,
                    "title": title,
                    "story_text": story_body,
                    "theme": theme,
                    "wisdom_gem": wisdom_gem,
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
                },
                "user_id": str(user_id),
            }

        except Exception as exc:
            db.session.rollback()
            error_msg = str(exc)
            logger.error("generate_story_task failed: %s", error_msg, exc_info=True)
            try:
                self.update_state(
                    state="FAILURE",
                    meta={"error": error_msg, "traceback": traceback.format_exc()},
                )
            except Exception as e:
                logger.warning(f"Failed to update task state (Redis likely unavailable): {e}")
            raise
