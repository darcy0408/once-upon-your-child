import base64
import io
import re
import requests
from flask import Blueprint, jsonify, request
from PIL import Image

from ..celery_config import celery
from ..gemini_image_generator import GeminiImageGenerator
from ..tasks.story_tasks import generate_story_task
from ..models.user import User
from ..models import Character
from ..database import db
from ..services.interactive_adventure_service import InteractiveAdventureService
from ..utils.validators import (
    validate_age,
    validate_num_images,
    validate_image_size,
    validate_story_modes,
    sanitize_text,
)

def _looks_like_base64_image(value: str) -> bool:
    if not isinstance(value, str):
        return False
    stripped = value.strip()
    if stripped.startswith("data:image") or stripped.startswith("http"):
        return False
    if len(stripped) < 200:
        return False
    return re.fullmatch(r"[A-Za-z0-9+/=\s]+", stripped) is not None


def create_story_blueprint(
    limiter,
    cache,
    story_engine_instance,
    model,
    image_generator,
    api_key: str,
    gemini_model: str,
    log_error,
    filter_story_content,
    get_tier_limits,
    track_cost,
    is_production_fn,
    logger,
):
    story_bp = Blueprint("story", __name__)

    @story_bp.route("/get-story-themes", methods=["GET"])
    @cache.cached(timeout=3600)  # Cache for 1 hour
    def get_story_themes():
        return jsonify(
            [
                "Adventure",
                "Friendship",
                "Magic",
                "Dragons",
                "Castles",
                "Unicorns",
                "Space",
                "Ocean",
            ]
        )

    @limiter.limit(lambda: get_tier_limits() or "1000/minute")  # BYOK users get high limit
    @story_bp.route("/generate-story", methods=["POST"])
    def generate_story_endpoint():
        payload = request.get_json(silent=True) or {}

        # Validate mode combinations before processing
        is_valid, mode_error = validate_story_modes(payload)
        if not is_valid:
            return jsonify(mode_error), 400

        theme = payload.get("theme") or "Adventure"
        user_id = payload.get("user_id") or "anonymous"
        # Sanitize user_id to match database schema (36 chars)
        if user_id and user_id.startswith("user_"):
            user_id = user_id.replace("user_", "")

        # Ensure user exists (Lazy creation for anonymous/new users)
        if user_id and user_id != "anonymous":
            try:
                user = db.session.get(User, user_id)
                if not user:
                    logger.info(f"Creating lazy user account for ID: {user_id}")
                    # Create placeholder user
                    new_user = User(
                        id=user_id,
                        username=f"user_{user_id[:8]}",
                        email=f"{user_id}@storyweaver.app"
                    )
                    new_user.set_password("anonymous_guest")
                    db.session.add(new_user)
                    db.session.commit()
            except Exception as e:
                logger.error(f"Failed to ensure user existence: {e}")
                db.session.rollback()

        if not payload.get("character_id") and not payload.get("character"):
            return jsonify({"error": "character_id or character is required"}), 400

        # Extract current_feeling and convert to feelings_prompt if provided
        current_feeling = payload.get("current_feeling")
        feelings_prompt_text = None
        if current_feeling and isinstance(current_feeling, dict):
            emotion_name = current_feeling.get("emotion_name", "")
            emotion_description = current_feeling.get("emotion_description", "")
            coping_strategies = current_feeling.get("coping_strategies", [])
            if emotion_name:
                feelings_prompt_text = f"The child is feeling {emotion_name}. {emotion_description}"
                if coping_strategies:
                    feelings_prompt_text += f" Coping strategies: {', '.join(coping_strategies)}"

        # Extract character_details to get additional_characters if available
        character_details = payload.get("character_details") or {}
        additional_chars = payload.get("additional_characters") or character_details.get("additionalCharacters")

        # Extract companion data (new structured format)
        companion_pets = payload.get("companion_pets", [])
        companion_characters = payload.get("companion_characters", [])

        task_kwargs = {
            "character_id": payload.get("character_id"),
            "character": payload.get("character"),
            "character_details": character_details,
            "theme": theme,
            "user_id": user_id,
            "include_illustrations": payload.get("include_illustrations", False),
            "async_illustrations": payload.get("async_illustrations", False),
            "rhyme_time_mode": payload.get("rhyme_time_mode", False),
            "learning_to_read_mode": payload.get("learning_to_read_mode", False),
            "companion": payload.get("companion") or payload.get("companion_name"),  # Legacy support
            "companion_pets": companion_pets,  # NEW: List of pet companions with species
            "companion_characters": companion_characters,  # NEW: List of character companions
            "spark_tool": payload.get("sparkTool"), # NEW: Spark Tool
            "mood_physics": payload.get("moodPhysics"), # NEW: Mood Physics
            "conflict_hook": payload.get("conflictHook"), # NEW: Plot Driver
            "sensory_palette": payload.get("sensoryPalette"), # NEW: Atmosphere
            "custom_elements": payload.get("customElements", ""), # NEW: Free-form custom story requests
            "therapeutic_prompt": payload.get("therapeutic_prompt", ""),
            "feelings_prompt": feelings_prompt_text or payload.get("feelings_prompt"),
            "story_length": payload.get("story_length", "standard"),
            "age": payload.get("age", 5),
        }

        # If async mode is requested, disable inline illustrations but pass the flag
        if task_kwargs.get("async_illustrations"):
            task_kwargs["include_illustrations"] = False
            logger.info("Async illustrations enabled - skipping inline generation")

        # Try synchronous execution first (to bypass polling issues on Railway)
        try:
            # Use .apply() to run synchronously in the same thread/process
            sync_result = generate_story_task.apply(kwargs=task_kwargs).get()
            
            # Debugging: Log the result type
            logger.info(f"Sync task result type: {type(sync_result)}")
            if isinstance(sync_result, str):
                logger.error(f"Sync task returned string instead of dict: {sync_result[:200]}...")
                raise Exception(f"Task returned invalid format (str): {sync_result}")

            # Extract story payload from the task result
            story_payload = (sync_result or {}).get("story", {})
            if not story_payload:
                 story_payload = (sync_result or {}).get("story_text", {})

            response_payload = {
                "status": sync_result.get("status", "complete"),
                "story": story_payload,
                "task_id": "sync_task", # No task ID needed
                "async_illustrations": payload.get("async_illustrations", False),
            }
            return jsonify(response_payload), 200

        except Exception as exc:
            import traceback
            error_trace = traceback.format_exc()
            logger.exception("Synchronous story generation failed, attempting async fallback: %s", exc)
            
            # Write error to file for debugging
            try:
                with open("backend_last_error.log", "w") as f:
                    f.write(error_trace)
            except Exception:
                pass

            if "429" in str(exc) or "ResourceExhausted" in str(exc) or "Quota exceeded" in str(exc):
                logger.warning(f"Quota exceeded in sync generation: {exc}")
                return jsonify({"error": "QUOTA_EXCEEDED", "message": "Google Geminin API quota exceeded. Please try again later.", "details": str(exc)}), 429
            
            logger.error(f"Full task_kwargs that failed: {task_kwargs}")
            try:
                task = generate_story_task.delay(**task_kwargs)
                return (
                    jsonify(
                        {
                            "task_id": task.id,
                            "status": "processing",
                            "message": "Story generation started (Async fallback)",
                            "poll_url": f"/task-status/{task.id}",
                        }
                    ),
                    202,
                )
            except Exception as async_exc:
                if "429" in str(async_exc) or "ResourceExhausted" in str(async_exc) or "Quota exceeded" in str(async_exc):
                     logger.warning(f"Quota exceeded in async generation: {async_exc}")
                     return jsonify({"error": "QUOTA_EXCEEDED", "message": "Google Gemini API quota exceeded. Please try again later.", "details": str(async_exc)}), 429
                
                logger.exception("Async fallback also failed: %s", async_exc)
                logger.error(f"Full error response: {str(async_exc)}")
                return jsonify({"error": "Story generation failed completely", "details": str(async_exc)}), 500
            logger.exception("Falling back to synchronous story generation: %s", exc)
            try:
                sync_result = generate_story_task.apply(kwargs=task_kwargs).get()
                story_payload = (sync_result or {}).get("story", {})
                response_payload = {
                    "status": sync_result.get("status", "complete"),
                    "title": story_payload.get("title"),
                    "story": story_payload.get("story_text"),
                    "story_text": story_payload.get("story_text"),
                    "task_id": None,
                    "theme": story_payload.get("theme"),
                    "wisdom_gem": story_payload.get("wisdom_gem"),
                    "async_illustrations": payload.get("async_illustrations", False),
                }
                return jsonify(response_payload), 200
            except Exception as fallback_exc:
                logger.exception("Synchronous story generation failed: %s", fallback_exc)
                return jsonify({"error": "Story generation failed"}), 500

    @story_bp.route("/generate-story-mock", methods=["POST"])
    def generate_story_mock_endpoint():
        """
        A mock endpoint for development and UI testing.
        Returns a static story instantly without calling any AI model.
        """
        logger.info("Serving mock story for testing.")
        payload = request.get_json(silent=True) or {}
        character = payload.get("character", {})
        
        # Handle character being either a dict or a string
        if isinstance(character, dict):
            character_name = character.get("name", "a brave hero")
        else:
            character_name = str(character) if character else "a brave hero"
            
        theme = payload.get("theme", "Friendship")

        mock_story = {
            "status": "complete",
            "result": {
                "status": "complete",
                "story": {
                    "id": "mock-story-12345",
                    "title": f"The Mock Adventure of {character_name}",
                    "story_text": f"This is a sample story about {character_name} and a grand adventure about {theme.lower()}. In a land of pixels and placeholders, our hero discovered that the best treasure is a good friend. They met a friendly dragon who, instead of breathing fire, brewed the best tea in the kingdom. Together, they shared stories and laughed until the sun set, painting the sky in shades of orange and purple.",
                    "theme": theme,
                    "wisdom_gem": "A shared cup of tea is better than a lonely treasure.",
                    "include_illustrations": payload.get("include_illustrations", False),
                    "rhyme_time_mode": payload.get("rhyme_time_mode", False),
                    "learning_to_read_mode": payload.get("learning_to_read_mode", False),
                }
            }
        }
        # The frontend expects the result of the task, not the task object itself
        return jsonify(mock_story), 200


    @story_bp.route("/task-status/<task_id>", methods=["GET"])
    def get_task_status(task_id):
        task = celery.AsyncResult(task_id)

        if task.state == "PENDING":
            response = {
                "status": "pending",
                "message": "Task is waiting to start",
            }
        elif task.state == "PROCESSING":
            meta = task.info or {}
            status_message = meta.get("status") if isinstance(meta, dict) else str(meta)
            response = {
                "status": "processing",
                "message": status_message or "Generating story...",
            }
        elif task.state == "SUCCESS":
            response = {
                "status": "complete",
                "result": task.result,
            }
        elif task.state == "FAILURE":
            response = {
                "status": "failed",
                "error": str(task.info),
            }
        else:
            response = {
                "status": (task.state or "unknown").lower(),
                "message": f"Task state: {task.state}",
            }

        return jsonify(response), 200

    @limiter.limit("5 per minute")  # Rate limit for interactive story start
    @story_bp.route("/generate-interactive-story", methods=["POST"])
    def generate_interactive_story_endpoint():
        """
        Create new interactive adventure story with first segment.
        Request body:
            - character_id: str (optional)
            - user_id: str (required)
            - theme: str (Adventure, Magic, Dragons, etc.)
            - tone: str (whimsical, mystery, sci-fi, fantasy, cozy-adventure)
            - length: str (short, medium, long)
            - age: int (optional, overrides character age)
            - interests: list[str] (optional)
            - must_include: list[str] (optional)
            - avoid: list[str] (optional)
        """
        logger.info("POST /generate-interactive-story called")
        payload = request.get_json(silent=True) or {}

        # Mark as interactive for validation
        payload["interactive"] = True

        # Validate mode combinations (interactive + rhymes = invalid)
        is_valid, mode_error = validate_story_modes(payload)
        if not is_valid:
            return jsonify(mode_error), 400

        user_id = payload.get("user_id")
        character_id = payload.get("character_id")
        theme = payload.get("theme", "Adventure")
        tone = payload.get("tone", "whimsical")
        length = payload.get("length", "medium")
        age = payload.get("age")
        interests = payload.get("interests")
        must_include = payload.get("must_include")
        avoid = payload.get("avoid")
        life_challenge = payload.get("life_challenge")
        personality_sliders = payload.get("personality_sliders")

        # Validate required fields
        if not user_id:
            return jsonify({"error": "user_id is required"}), 400

        try:
            # Initialize service
            service = InteractiveAdventureService(gemini_api_key=api_key)

            # Create story
            result = service.create_story(
                user_id=user_id,
                character_id=character_id,
                theme=theme,
                tone=tone,
                length=length,
                age=age,
                interests=interests,
                must_include=must_include,
                avoid=avoid,
                life_challenge=life_challenge,
                personality_sliders=personality_sliders
            )

            # Filter content
            segment_content = result['segment']['content']
            filtered_content, flagged = filter_story_content(segment_content)
            result['segment']['content'] = filtered_content

            if flagged:
                logger.warning("Interactive story opening flagged by content filter")

            logger.info(f"Interactive story created: {result['story_id']}")
            return jsonify(result), 200

        except Exception as e:
            log_error(
                error_type="interactive_story_generation_failed",
                message=str(e),
                details={
                    "user_id": user_id,
                    "character_id": character_id,
                    "theme": theme,
                    "error_class": e.__class__.__name__,
                },
            )
            logger.exception("Interactive story generation failed")
            return jsonify(
                {
                    "error": str(e),
                    "hint": "Interactive story generation failed on the backend.",
                }
            ), 500

    @limiter.limit("5 per minute")  # Rate limit for continuing interactive stories
    @story_bp.route("/continue-interactive-story", methods=["POST"])
    def continue_interactive_story_endpoint():
        """
        Continue interactive story based on choice selection.
        Request body:
            - story_id: str (required)
            - choice_id: str (required)
        """
        logger.info("POST /continue-interactive-story called")
        payload = request.get_json(silent=True) or {}

        story_id = payload.get("story_id")
        choice_id = payload.get("choice_id")

        # Validate required fields
        if not story_id or not choice_id:
            return jsonify({"error": "story_id and choice_id are required"}), 400

        try:
            # Initialize service
            service = InteractiveAdventureService(gemini_api_key=api_key)

            # Continue story
            result = service.continue_story(
                story_id=story_id,
                choice_id=choice_id
            )

            # Filter content
            segment_content = result['segment']['content']
            filtered_content, flagged = filter_story_content(segment_content)
            result['segment']['content'] = filtered_content

            if flagged:
                logger.warning("Interactive continuation flagged by content filter")

            logger.info(f"Story {story_id} continued to segment {result['segment']['segment_number']}")
            return jsonify(result), 200

        except ValueError as e:
            logger.warning(f"Invalid request: {e}")
            return jsonify({"error": str(e)}), 404

        except Exception as e:
            logger.exception("Continuing interactive story failed")
            log_error(
                error_type="interactive_story_continuation_failed",
                message=str(e),
                details={
                    "story_id": story_id,
                    "choice_id": choice_id,
                    "error_class": e.__class__.__name__,
                },
            )
            return jsonify(
                {
                    "error": str(e),
                    "hint": "Continuing interactive story failed on the backend.",
                }
            ), 500

    @story_bp.route("/interactive-story/<story_id>", methods=["GET"])
    def get_interactive_story(story_id):
        """
        Get full interactive story with all segments and current state.
        """
        logger.info(f"GET /interactive-story/{story_id} called")

        try:
            # Initialize service
            service = InteractiveAdventureService(gemini_api_key=api_key)

            # Get story
            result = service.get_story(story_id)

            return jsonify(result), 200

        except ValueError as e:
            logger.warning(f"Story not found: {e}")
            return jsonify({"error": str(e)}), 404

        except Exception as e:
            logger.exception("Getting interactive story failed")
            return jsonify({"error": str(e)}), 500

    @story_bp.route("/interactive-story/<story_id>/resume", methods=["GET"])
    def resume_interactive_story(story_id):
        """
        Resume an in-progress story from current segment.
        Returns current segment, inventory, and state.
        """
        logger.info(f"GET /interactive-story/{story_id}/resume called")

        try:
            from backend.models import InteractiveStory

            # Load story
            story = InteractiveStory.query.filter_by(id=story_id).first()
            if not story:
                return jsonify({"error": f"Story {story_id} not found"}), 404

            if story.is_completed:
                return jsonify({"error": "Story is already completed"}), 400

            # Get current segment
            current_segment = story.segments.filter_by(
                id=story.current_segment_id
            ).first()

            if not current_segment:
                return jsonify({"error": "Current segment not found"}), 404

            result = {
                'story_id': story.id,
                'title': story.title,
                'current_segment_number': story.current_segment_number,
                'segment': current_segment.to_dict(),
                'inventory': [item.to_dict() for item in story.inventory.filter_by(is_active=True).all()],
                'state': story.state.to_dict() if story.state else None,
                'is_completed': story.is_completed
            }

            return jsonify(result), 200

        except Exception as e:
            logger.exception("Resuming interactive story failed")
            return jsonify({"error": str(e)}), 500

    @story_bp.route("/report-story", methods=["POST"])
    def report_story():
        """Allow users to report inappropriate content."""
        data = request.get_json(silent=True) or {}
        story_id = data.get("story_id") or data.get("id") or "unknown"
        reason = (data.get("reason") or "").strip() or "No reason provided"
        snippet = (data.get("story_preview") or "")[:200]

        logger.warning(f"⚠️ CONTENT REPORT - Story ID: {story_id}, Reason: {reason}, Preview: {snippet}")

        return jsonify({"status": "reported", "message": "Thank you for your report"}), 200

    @limiter.limit(lambda: get_tier_limits("expensive") or "100/hour")  # BYOK users get high limit
    @story_bp.route("/generate-illustrations", methods=["POST"])
    def generate_illustrations_endpoint():
        """Generate illustrations for a story scene"""
        try:
            data = request.get_json(silent=True) or {}
            scene_description = sanitize_text(data.get("scene_description", ""), max_length=2000, allow_newlines=True)
            character_name = sanitize_text(data.get("character_name", "the hero"), max_length=100)
            style = sanitize_text(data.get("style", "children's book illustration"), max_length=200)
            num_images = validate_num_images(data.get("num_images", 1), max_allowed=4)
            try:
                age = validate_age(data.get("age", 7))
            except ValueError:
                age = 7  # Default to 7 if invalid
            therapeutic_focus = sanitize_text(data.get("therapeutic_focus", ""), max_length=500) or None
            user_api_key = data.get("user_api_key")  # BYOK support

            # Get character appearance/avatar details
            character_appearance = data.get("character_appearance") or data.get("appearance")

            # Get companions (could be magical companions, pets, or friends)
            companions = data.get("companions") or data.get("companion_pets") or []

            if not scene_description.strip():
                return jsonify({"error": "Scene description is required"}), 400

            # Use user's API key if provided, otherwise use server's
            generator = None
            using_user_key = False

            if user_api_key:
                generator = GeminiImageGenerator(api_key=user_api_key)
                using_user_key = True
            elif image_generator is not None:
                generator = image_generator
            else:
                return (
                    jsonify(
                        {
                            "error": "Image generation temporarily unavailable",
                            "hint": "OpenRouter image service is currently unavailable. Please try again later.",
                            "illustrations": [],
                            "count": 0,
                        }
                    ),
                    200,
                )

            illustrations = generator.generate_story_illustration(
                scene_description=scene_description,
                character_name=character_name,
                style=style,
                num_images=num_images,
                age=age,
                therapeutic_focus=therapeutic_focus,
                character_appearance=character_appearance,
                companions=companions,
            )

            if not illustrations:
                logger.warning(f"No illustrations generated for scene: {scene_description[:50]}...")
                # Return success with empty illustrations instead of error
                return (
                    jsonify(
                        {
                            "illustrations": [],
                            "count": 0,
                            "used_user_key": using_user_key,
                            "message": "Illustration generation is temporarily unavailable due to API quota limits. Your story is ready, but illustrations couldn't be generated at this time.",
                            "hint": "Try again later or contact support to increase your quota.",
                        }
                    ),
                    200,
                )

            transformed_illustrations = []
            try:
                for img in illustrations:
                    new_img = img.copy()
                    image_url = img.get("image_url", "")

                    if "image_data" in img and isinstance(img.get("image_data"), str):
                        image_data = img.get("image_data", "").strip()
                        if image_data.startswith("data:image"):
                            try:
                                new_img["image_data"] = image_data.split(",", 1)[1]
                            except IndexError:
                                new_img["image_data"] = image_data
                        else:
                            new_img["image_data"] = image_data

                    # If it's a data URI, extract the raw base64 for 'image_data'
                    if not new_img.get("image_data") and image_url.startswith("data:image"):
                        try:
                            # Split 'data:image/png;base64,.....'
                            base64_part = image_url.split(",", 1)[1]
                            new_img["image_data"] = base64_part
                        except IndexError:
                            pass
                    elif not new_img.get("image_data") and image_url.startswith("http"):
                        # Download image and convert to base64
                        # Download image with size limit protection
                        try:
                            logger.info(f"Downloading illustration from {image_url[:50]}...")
                            # Stream the response to check size before loading into memory
                            img_resp = requests.get(image_url, stream=True, timeout=10)
                            img_resp.raise_for_status()

                            # Enforce 5MB limit via Content-Length header if available
                            content_length = img_resp.headers.get('Content-Length')
                            MAX_SIZE = 5 * 1024 * 1024  # 5MB
                            
                            if content_length and int(content_length) > MAX_SIZE:
                                logger.warning(f"Image too large directly from headers: {content_length}")
                                continue

                            # Stream content to enforce limit physically
                            image_bytes = bytearray()
                            for chunk in img_resp.iter_content(chunk_size=8192):
                                image_bytes.extend(chunk)
                                if len(image_bytes) > MAX_SIZE:
                                    logger.warning("Image exceeded 5MB limit during download")
                                    break
                            
                            if len(image_bytes) > MAX_SIZE:
                                continue

                            # Validate image structure
                            try:
                                validate_image_size(image_bytes)
                            except ValueError as size_err:
                                logger.warning(f"Image validation failed: {size_err}")
                                continue

                            # Resize downloaded image to max 1024x1024
                            try:
                                with Image.open(io.BytesIO(image_bytes)) as img:
                                    img.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
                                    buffer = io.BytesIO()
                                    img.save(buffer, format="PNG")
                                    image_bytes = buffer.getvalue()
                            except Exception as resize_err:
                                logger.warning(f"Failed to resize downloaded image: {resize_err}")

                            b64_data = base64.b64encode(image_bytes).decode("utf-8")
                            new_img["image_data"] = b64_data
                            logger.info("Successfully converted image URL to base64 data")
                        except Exception as e:
                            logger.error(f"Error processing illustration image data: {str(e)}")
                    elif not new_img.get("image_data") and _looks_like_base64_image(image_url):
                        new_img["image_data"] = re.sub(r"\s+", "", image_url)

                    # Ensure image_id is present (frontend expects it)
                    if "id" in img:
                        new_img["image_id"] = img["id"]

                    # Ensure scene_description is present (frontend expects it)
                    if "prompt" in img:
                        new_img["scene_description"] = img["prompt"]

                    if not new_img.get("image_data"):
                        logger.warning("Illustration missing image_data after normalization; skipping entry")
                        continue

                    transformed_illustrations.append(new_img)
            except Exception as e:
                logger.error(f"Error in illustration transformation: {str(e)}")
                transformed_illustrations = illustrations  # Fallback to original

            return (
                jsonify(
                    {
                        "illustrations": transformed_illustrations,
                        "count": len(transformed_illustrations),
                        "used_user_key": using_user_key,
                        "debug_info": {
                        },
                    }
                ),
                200,
            )

        except Exception as exc:
            import traceback
            error_trace = traceback.format_exc()
            logger.exception("Illustration generation failed")
            
            # Write error to file for debugging
            try:
                with open("backend_last_error.log", "w") as f:
                    f.write(error_trace)
            except Exception:
                pass

            return jsonify({"error": str(exc), "hint": "Image generation failed. Check your API key quota or try again later."}), 500

    @limiter.limit("10 per hour")
    @story_bp.route("/generate-coloring-pages", methods=["POST"])
    def generate_coloring_pages_endpoint():
        """Generate coloring book pages for story scene(s)"""
        try:
            data = request.get_json(silent=True) or {}

            # Support both singular 'scene_description' and plural 'scenes'
            scene_description = sanitize_text(data.get("scene_description", ""), max_length=2000, allow_newlines=True)
            scenes = data.get("scenes", [])

            # If scenes list is provided, use it, otherwise fall back to scene_description
            if not scenes and scene_description:
                scenes = [{"description": scene_description}]

            if not scenes:
                return jsonify({"error": "Scene description or scenes list is required"}), 400

            character_name = sanitize_text(data.get("character_name", "the hero"), max_length=100)
            num_images_per_scene = validate_num_images(data.get("num_images", 1), max_allowed=3)
            try:
                age = validate_age(data.get("age", 7))
            except ValueError:
                age = 7  # Default to 7 if invalid
            therapeutic_focus = sanitize_text(data.get("therapeutic_focus", ""), max_length=500) or None
            user_api_key = data.get("user_api_key")

            # Get character appearance/avatar details
            character_appearance = data.get("character_appearance") or data.get("appearance")

            # Get companions (could be magical companions, pets, or friends)
            companions = data.get("companions") or data.get("companion_pets") or []

            generator = None
            if user_api_key:
                try:
                    generator = GeminiImageGenerator(api_key=user_api_key)
                except Exception as e:
                    logger.exception("Failed to init user-provided image generator")
                    return (
                        jsonify({"error": "Invalid or unavailable image API key", "hint": str(e)}),
                        400,
                    )
            elif image_generator is not None:
                generator = image_generator
            else:
                return (
                    jsonify(
                        {
                            "coloring_pages": [],
                            "count": 0,
                            "warning": "Image generation unavailable",
                        }
                    ),
                    200,
                )

            all_coloring_pages = []
            for scene_item in scenes:
                # Handle both string and dict in scenes list
                if isinstance(scene_item, str):
                    current_desc = sanitize_text(scene_item, max_length=2000, allow_newlines=True)
                    scene_title = "Coloring Page"
                else:
                    current_desc = sanitize_text(scene_item.get("description", ""), max_length=2000, allow_newlines=True)
                    scene_title = sanitize_text(scene_item.get("title", "Coloring Page"), max_length=100)

                if not current_desc:
                    continue

                pages = generator.generate_coloring_page(
                    scene_description=current_desc,
                    character_name=character_name,
                    num_images=num_images_per_scene,
                    age=age,
                    therapeutic_focus=therapeutic_focus,
                    character_appearance=character_appearance,
                    companions=companions,
                )

                # Add metadata + normalize image_data
                for p in pages:
                    page = p.copy() if isinstance(p, dict) else {"image_url": p}
                    page["scene_title"] = scene_title

                    image_url = page.get("image_url", "")
                    if "image_data" in page and isinstance(page.get("image_data"), str):
                        image_data = page.get("image_data", "").strip()
                        if image_data.startswith("data:image"):
                            try:
                                page["image_data"] = image_data.split(",", 1)[1]
                            except IndexError:
                                page["image_data"] = image_data
                        else:
                            page["image_data"] = image_data
                    if not page.get("image_data") and isinstance(image_url, str):
                        if image_url.startswith("data:image"):
                            try:
                                page["image_data"] = image_url.split(",", 1)[1]
                            except IndexError:
                                pass
                        elif image_url.startswith("http"):
                            try:
                                logger.info(f"Downloading coloring page from {image_url[:50]}...")
                                img_resp = requests.get(image_url, stream=True, timeout=10)
                                img_resp.raise_for_status()

                                content_length = img_resp.headers.get('Content-Length')
                                MAX_SIZE = 5 * 1024 * 1024  # 5MB
                                if content_length and int(content_length) > MAX_SIZE:
                                    logger.warning(f"Coloring page too large from headers: {content_length}")
                                    continue

                                image_bytes = bytearray()
                                for chunk in img_resp.iter_content(chunk_size=8192):
                                    image_bytes.extend(chunk)
                                    if len(image_bytes) > MAX_SIZE:
                                        logger.warning("Coloring page exceeded 5MB limit during download")
                                        break
                                if len(image_bytes) > MAX_SIZE:
                                    continue

                                try:
                                    validate_image_size(image_bytes)
                                except ValueError as size_err:
                                    logger.warning(f"Coloring page validation failed: {size_err}")
                                    continue

                                # Resize to max 1024x1024 for consistency
                                try:
                                    with Image.open(io.BytesIO(image_bytes)) as img:
                                        img.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
                                        buffer = io.BytesIO()
                                        img.save(buffer, format="PNG")
                                        image_bytes = buffer.getvalue()
                                except Exception as resize_err:
                                    logger.warning(f"Failed to resize coloring page: {resize_err}")

                                page["image_data"] = base64.b64encode(image_bytes).decode("utf-8")
                                logger.info("Successfully converted coloring page URL to base64 data")
                            except Exception as e:
                                logger.error(f"Error processing coloring page image data: {str(e)}")
                        elif _looks_like_base64_image(image_url):
                            page["image_data"] = re.sub(r"\s+", "", image_url)

                    if not page.get("image_data"):
                        logger.warning("Coloring page missing image_data after normalization; skipping entry")
                        continue

                    all_coloring_pages.append(page)

            return jsonify({
                "coloring_pages": all_coloring_pages, 
                "count": len(all_coloring_pages)
            }), 200

        except Exception as e:
            logger.exception("Coloring page generation failed")
            return jsonify({"error": "Failed to generate coloring pages", "hint": str(e)}), 500

    @story_bp.route("/generate-illustrations-mock", methods=["POST"])
    def generate_illustrations_mock_endpoint():
        """
        Mock illustrations endpoint for testing and development.
        Returns placeholder images instantly without calling any AI model.
        """
        import uuid
        import base64
        from datetime import datetime
        from PIL import Image, ImageDraw, ImageFont
        import io

        try:
            data = request.get_json(silent=True) or {}
            scene_description = data.get("scene_description", "A magical scene")
            character_name = data.get("character_name", "Hero")
            num_images = min(int(data.get("num_images", 1)), 4)

            logger.info(f"[MOCK] Generating {num_images} illustration(s) for: {scene_description[:50]}...")

            illustrations = []
            for i in range(num_images):
                # Create simple placeholder image
                img = Image.new('RGB', (1024, 768), color='#FFE4B5')  # Moccasin color
                draw = ImageDraw.Draw(img)

                # Try to load font
                try:
                    font_title = ImageFont.truetype("arial.ttf", 60)
                    font_desc = ImageFont.truetype("arial.ttf", 30)
                except:
                    font_title = ImageFont.load_default()
                    font_desc = font_title

                # Draw title
                title = f"Illustration {i+1}"
                bbox = draw.textbbox((0, 0), title, font=font_title)
                x = (1024 - (bbox[2] - bbox[0])) // 2
                draw.text((x, 100), title, fill='#8B4513', font=font_title)

                # Draw scene description (truncated)
                desc = scene_description[:60] + "..." if len(scene_description) > 60 else scene_description
                bbox_desc = draw.textbbox((0, 0), desc, font=font_desc)
                x_desc = (1024 - (bbox_desc[2] - bbox_desc[0])) // 2
                draw.text((x_desc, 200), desc, fill='#654321', font=font_desc)

                # Draw character name
                char_text = f"Starring: {character_name}"
                bbox_char = draw.textbbox((0, 0), char_text, font=font_desc)
                x_char = (1024 - (bbox_char[2] - bbox_char[0])) // 2
                draw.text((x_char, 300), char_text, fill='#654321', font=font_desc)

                # Draw MOCK watermark
                bbox_mock = draw.textbbox((0, 0), "MOCK ILLUSTRATION", font=font_desc)
                x_mock = (1024 - (bbox_mock[2] - bbox_mock[0])) // 2
                draw.text((x_mock, 700), "MOCK ILLUSTRATION", fill='#A0522D', font=font_desc)

                # Convert to base64
                buffer = io.BytesIO()
                img.save(buffer, format='PNG')
                img_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')

                illustrations.append({
                    'id': f"mock-illust-{uuid.uuid4()}",
                    'image_data': img_base64,
                    'format': 'png',
                    'prompt': scene_description,
                    'generated_at': datetime.now().isoformat(),
                    'is_mock': True,
                    'cost': 0.0
                })

            return jsonify({
                'illustrations': illustrations,
                'count': len(illustrations)
            }), 200

        except Exception as e:
            logger.exception(f"Error in mock illustration generation: {e}")
            return jsonify({"error": str(e)}), 500

    @story_bp.route("/generate-coloring-pages-mock", methods=["POST"])
    def generate_coloring_pages_mock_endpoint():
        """
        Mock coloring pages endpoint for testing and development.
        Returns placeholder black & white images instantly without calling any AI model.
        """
        import uuid
        import base64
        from datetime import datetime
        from PIL import Image, ImageDraw, ImageFont
        import io

        try:
            data = request.get_json(silent=True) or {}
            scene_description = data.get("scene_description", "")
            scenes = data.get("scenes", [])

            if not scenes and scene_description:
                scenes = [{"description": scene_description, "title": "Coloring Page"}]

            if not scenes:
                return jsonify({"error": "Scene description or scenes list is required"}), 400

            character_name = data.get("character_name", "Hero")
            num_images_per_scene = min(int(data.get("num_images", 1)), 3)

            logger.info(f"[MOCK] Generating {num_images_per_scene} coloring page(s) per scene, {len(scenes)} scene(s)")

            all_coloring_pages = []
            for scene_item in scenes:
                # Handle both string and dict
                if isinstance(scene_item, str):
                    current_desc = scene_item
                    scene_title = "Coloring Page"
                else:
                    current_desc = scene_item.get("description", "")
                    scene_title = scene_item.get("title", "Coloring Page")

                if not current_desc:
                    continue

                for i in range(num_images_per_scene):
                    # Create black & white coloring page style
                    img = Image.new('RGB', (1024, 1024), color='white')
                    draw = ImageDraw.Draw(img)

                    # Try to load font
                    try:
                        font_title = ImageFont.truetype("arial.ttf", 50)
                        font_small = ImageFont.truetype("arial.ttf", 30)
                    except:
                        font_title = ImageFont.load_default()
                        font_small = font_title

                    # Draw simple shapes (outlines only - coloring page style)
                    # Circle
                    draw.ellipse([200, 200, 400, 400], outline='black', width=5)
                    # Star shape (simplified)
                    draw.polygon([(512, 100), (550, 200), (650, 200), (570, 270),
                                  (600, 370), (512, 310), (424, 370), (454, 270),
                                  (374, 200), (474, 200)], outline='black', width=4)
                    # Rectangle with character name
                    draw.rectangle([100, 500, 924, 650], outline='black', width=5)

                    # Draw title
                    title = f"{scene_title} {i+1}"
                    bbox = draw.textbbox((0, 0), title, font=font_title)
                    x = (1024 - (bbox[2] - bbox[0])) // 2
                    draw.text((x, 700), title, fill='black', font=font_title)

                    # Draw character name
                    char_text = f"{character_name}"
                    bbox_char = draw.textbbox((0, 0), char_text, font=font_small)
                    x_char = (1024 - (bbox_char[2] - bbox_char[0])) // 2
                    draw.text((x_char, 560), char_text, fill='black', font=font_small)

                    # Draw MOCK label
                    draw.text((850, 20), "MOCK", fill='black', font=font_small)

                    # Convert to base64
                    buffer = io.BytesIO()
                    img.save(buffer, format='PNG')
                    img_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')

                    all_coloring_pages.append({
                        'id': f"mock-color-{uuid.uuid4()}",
                        'image_data': img_base64,
                        'format': 'png',
                        'prompt': current_desc,
                        'scene_title': scene_title,
                        'generated_at': datetime.now().isoformat(),
                        'is_mock': True,
                        'cost': 0.0
                    })

            return jsonify({
                'coloring_pages': all_coloring_pages,
                'count': len(all_coloring_pages)
            }), 200

        except Exception as e:
            logger.exception(f"Error in mock coloring page generation: {e}")
            return jsonify({"error": str(e)}), 500

    return story_bp
