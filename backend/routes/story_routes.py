import base64
import requests
from flask import Blueprint, jsonify, request

from ..celery_config import celery
from ..gemini_image_generator import GeminiImageGenerator
from ..tasks.story_tasks import generate_story_task


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
        theme = payload.get("theme") or "Adventure"
        user_id = payload.get("user_id") or "anonymous"

        if not payload.get("character_id") and not payload.get("character"):
            return jsonify({"error": "character_id or character is required"}), 400

        task_kwargs = {
            "character_id": payload.get("character_id"),
            "character": payload.get("character"),
            "theme": theme,
            "user_id": user_id,
            "include_illustrations": payload.get("include_illustrations", False),
            "rhyme_time_mode": payload.get("rhyme_time_mode", False),
            "learning_to_read_mode": payload.get("learning_to_read_mode", False),
            "companion": payload.get("companion"),
            "therapeutic_prompt": payload.get("therapeutic_prompt", ""),
            "feelings_prompt": payload.get("feelings_prompt"),
        }

        try:
            task = generate_story_task.delay(**task_kwargs)
            return (
                jsonify(
                    {
                        "task_id": task.id,
                        "status": "processing",
                        "message": "Story generation started",
                        "poll_url": f"/task-status/{task.id}",
                    }
                ),
                202,
            )
        except Exception as exc:
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
        character_name = character.get("name", "a brave hero")
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
        logger.info("POST /generate-interactive-story called")
        payload = request.get_json(silent=True) or {}
        character_name = payload.get("character", "a brave adventurer")
        theme = payload.get("theme", "Adventure")
        companion = payload.get("companion")
        character_age = payload.get("age", 7)
        user_api_key = payload.get("user_api_key")

        try:
            # Use story_engine_instance which has the interactive story methods
            interactive_story_segment = story_engine_instance.generate_interactive_story(
                character_name=character_name,
                theme=theme,
                companion=companion,
                character_age=character_age,
                model=model,  # Pass the initialized model
                user_api_key=user_api_key,  # Allow BYOK
            )
            text, flagged = filter_story_content(interactive_story_segment.get("text", ""))
            interactive_story_segment["text"] = text
            if flagged:
                logger.warning("Interactive story opening flagged by content filter")

            return jsonify(interactive_story_segment), 200
        except Exception as e:
            log_error(
                error_type="interactive_story_generation_failed",
                message=str(e),
                details={
                    "character_name": character_name,
                    "theme": theme,
                    "age": character_age,
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
        logger.info("POST /continue-interactive-story called")
        payload = request.get_json(silent=True) or {}
        character_name = payload.get("character", "a brave adventurer")
        theme = payload.get("theme", "Adventure")
        companion = payload.get("companion")
        choice_text = payload.get("choice", "")
        story_so_far = payload.get("story_so_far", "")
        choices_made = payload.get("choices_made", [])
        character_age = payload.get("age", 7)
        user_api_key = payload.get("user_api_key")

        try:
            interactive_story_segment = story_engine_instance.continue_interactive_story(
                character_name=character_name,
                theme=theme,
                companion=companion,
                choice_text=choice_text,
                story_so_far=story_so_far,
                choices_made=choices_made,
                character_age=character_age,
                model=model,  # Pass the initialized model
                user_api_key=user_api_key,  # Allow BYOK
            )
            text, flagged = filter_story_content(interactive_story_segment.get("text", ""))
            interactive_story_segment["text"] = text
            if flagged:
                logger.warning("Interactive continuation flagged by content filter")

            return jsonify(interactive_story_segment), 200
        except Exception as e:
            logger.exception("Continuing interactive story failed")
            return jsonify(
                {
                    "error": str(e),
                    "hint": "Continuing interactive story failed on the backend.",
                }
            ), 500

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
            scene_description = data.get("scene_description", "")
            character_name = data.get("character_name", "the hero")
            style = data.get("style", "children's book illustration")
            num_images = min(int(data.get("num_images", 1)), 4)  # Max 4 images
            age = int(data.get("age", 7))
            therapeutic_focus = data.get("therapeutic_focus")
            user_api_key = data.get("user_api_key")  # BYOK support

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
            )

            if not illustrations:
                logger.warning(f"No illustrations generated for scene: {scene_description[:50]}...")

            transformed_illustrations = []
            try:
                for img in illustrations:
                    new_img = img.copy()
                    image_url = img.get("image_url", "")

                    # If it's a data URI, extract the raw base64 for 'image_data'
                    if image_url.startswith("data:image"):
                        try:
                            # Split 'data:image/png;base64,.....'
                            base64_part = image_url.split(",", 1)[1]
                            new_img["image_data"] = base64_part
                        except IndexError:
                            pass
                    elif image_url.startswith("http"):
                        # Download image and convert to base64
                        try:
                            logger.info(f"Downloading illustration from {image_url[:50]}...")
                            img_resp = requests.get(image_url, timeout=10)
                            if img_resp.status_code == 200:
                                b64_data = base64.b64encode(img_resp.content).decode("utf-8")
                                new_img["image_data"] = b64_data
                                logger.info("Successfully converted image URL to base64 data")
                            else:
                                logger.error(f"Failed to download image: {img_resp.status_code}")
                        except Exception as e:
                            logger.error(f"Error processing illustration image data: {str(e)}")

                    # Ensure image_id is present (frontend expects it)
                    if "id" in img:
                        new_img["image_id"] = img["id"]

                    # Ensure scene_description is present (frontend expects it)
                    if "prompt" in img:
                        new_img["scene_description"] = img["prompt"]

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
                            "generator_type": type(generator).__name__ if generator else "None",
                            "scene_length": len(scene_description),
                        },
                    }
                ),
                200,
            )

        except Exception as e:
            logger.exception("Illustration generation failed")
            return jsonify({"error": str(e), "hint": "Image generation failed. Check your API key quota or try again later."}), 500

    @limiter.limit("10 per hour")
    @story_bp.route("/generate-coloring-pages", methods=["POST"])
    def generate_coloring_pages_endpoint():
        """Generate coloring book pages for a story scene"""
        try:
            data = request.get_json(silent=True) or {}
            scene_description = data.get("scene_description", "")
            character_name = data.get("character_name", "the hero")
            num_images = min(int(data.get("num_images", 1)), 3)  # Max 3 pages
            age = int(data.get("age", 7))
            therapeutic_focus = data.get("therapeutic_focus")
            user_api_key = data.get("user_api_key")

            if not scene_description.strip():
                return jsonify({"error": "Scene description is required"}), 400

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
                # Graceful fallback when image generation is unavailable (no key/model).
                return (
                    jsonify(
                        {
                            "coloring_pages": [],
                            "count": 0,
                            "warning": "Image generation unavailable; configure GEMINI_API_KEY or provide user_api_key.",
                        }
                    ),
                    200,
                )

            coloring_pages = generator.generate_coloring_page(
                scene_description=scene_description,
                character_name=character_name,
                num_images=num_images,
                age=age,
                therapeutic_focus=therapeutic_focus,
            )

            return jsonify({"coloring_pages": coloring_pages, "count": len(coloring_pages)}), 200

        except Exception as e:
            logger.exception("Coloring page generation failed")
            return jsonify({"error": "Failed to generate coloring pages", "hint": str(e)}), 500

    return story_bp
