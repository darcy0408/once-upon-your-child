import os
import traceback
from typing import Any, Dict

from celery.utils.log import get_task_logger

# Prevent default app initialization during import so we can control app context here.
os.environ.setdefault("SKIP_DEFAULT_APP_INIT", "1")

from backend.celery_config import celery
from backend.app import create_app
from backend.database import db
from backend.models.character import Character
from backend.models.character import Character
from backend.models.story import Story
from backend.models.user import User
from backend.services.story_generation_service import StoryGenerationService
from backend.services.openrouter_story_generator import OpenRouterStoryGenerator
from google.api_core import exceptions as google_exceptions
from backend.services.story_service import AdvancedStoryEngine, _safe_extract_title_and_gem

logger = get_task_logger(__name__)

# Lazy app initialization to avoid circular imports
_flask_app = None

def get_flask_app():
    """Lazy initialization of Flask app to avoid circular imports."""
    global _flask_app
    if _flask_app is None:
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
        companion = kwargs.get("companion")
        character_name = kwargs.get("character") or "a brave adventurer"
        char_details = kwargs.get("character_details") or {}

        try:
            character = Character.query.get(character_id) if character_id else None
            custom_pet = None
            if character:
                character_name = character.name
                if companion:
                    # Check if the chosen companion is one of the character's custom pets
                    pets = character.pets or []
                    # Handle if pets is stored as JSON string or list
                    if isinstance(pets, str):
                        try:
                             import json
                             pets = json.loads(pets)
                        except:
                             pets = []
                    
                    for pet in pets:
                         if isinstance(pet, dict) and pet.get("name") == companion:
                             custom_pet = pet
                             break

            elif character_id:
                raise ValueError(f"Character {character_id} not found")

            # Fallback: Check character_details from payload (for Wizard flow)
            if not custom_pet:

                # pets might be a list of dicts directly
                pets = char_details.get("pets") or []
                for pet in pets:
                     if isinstance(pet, dict) and pet.get("name") == companion:
                         custom_pet = pet
                         break

            self.update_state(state="PROCESSING", meta={"status": "Generating story..."})

            engine = AdvancedStoryEngine()
            prompt = engine.generate_enhanced_prompt(
                character=character_name,
                theme=theme,
                companion=companion,
                custom_pet=custom_pet,
                additional_characters=char_details.get("additionalCharacters"),
                therapeutic_prompt=kwargs.get("therapeutic_prompt", ""),
                feelings_prompt=kwargs.get("feelings_prompt"),
            )
            logger.info(f"Custom Pet Found: {custom_pet}")
            logger.info(f"Generated Prompt Snippet: {prompt[:500]}...")

            story_text = _generate_story_text(prompt, theme, character_name, companion)
            title, wisdom_gem, story_body = _safe_extract_title_and_gem(story_text, theme)

            # Ensure user exists before inserting story (Prevent ForeignKeyViolation)
            if user_id and user_id != "anonymous":
                try:
                    user_record = User.query.get(user_id)
                    if not user_record:
                        logger.info(f"Task creating lazy user account for ID: {user_id}")
                        new_user = User(
                            id=user_id,
                            username=f"user_{user_id[:8]}",
                            email=f"{user_id}@storyweaver.app"
                        )
                        new_user.set_password("anonymous_guest")
                        db.session.add(new_user)
                        db.session.commit()
                except Exception as e:
                    logger.error(f"Task failed to ensure user existence: {e}")
                    db.session.rollback()

            story_record = Story(user_id=user_id, title=title)
            db.session.add(story_record)
            db.session.commit()

            return {
                "status": "complete",
                "story": {
                    "id": story_record.id,
                    "title": title,
                    "story_text": story_body,
                    "theme": theme,
                    "wisdom_gem": wisdom_gem,
                    "include_illustrations": include_illustrations,
                    "rhyme_time_mode": rhyme_time_mode,
                    "learning_to_read_mode": learning_to_read_mode,
                },
            }

        except Exception as exc:
            db.session.rollback()
            error_msg = str(exc)
            logger.error("generate_story_task failed: %s", error_msg, exc_info=True)
            self.update_state(
                state="FAILURE",
                meta={"error": error_msg, "traceback": traceback.format_exc()},
            )
            raise
