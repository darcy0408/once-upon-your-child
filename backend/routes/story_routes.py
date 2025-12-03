import base64
import requests
import google.generativeai as genai
from flask import Blueprint, jsonify, request

from ..models.user import User
from ..services import character_service, story_service
from ..gemini_image_generator import GeminiImageGenerator


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
        rhyme_time_mode = payload.get("rhyme_time_mode", False)
        learning_to_read_mode = payload.get("learning_to_read_mode", False)
        include_illustrations = payload.get("include_illustrations", False)
        user_id = payload.get("user_id")
        requested_tier = (payload.get("subscription_tier") or "").lower()
        allowed_tiers = {"free", "premium", "family"}
        if requested_tier not in allowed_tiers:
            requested_tier = None

        if not requested_tier and user_id:
            try:
                user_record = User.query.filter_by(id=user_id).first()
                if user_record and user_record.subscription_tier:
                    normalized = user_record.subscription_tier.lower()
                    if normalized in allowed_tiers:
                        requested_tier = normalized
            except Exception:
                logger.exception("Failed to load user for subscription tier lookup")

        subscription_tier = requested_tier or "free"
        character = payload.get("character", "a brave adventurer")
        theme = payload.get("theme", "Adventure")
        companion = payload.get("companion")
        therapeutic_prompt = payload.get("therapeutic_prompt", "")
        user_api_key = payload.get("user_api_key")  # Optional user-provided API key
        character_age = payload.get("character_age", 7)  # For age-appropriate content
        current_feeling = story_service._extract_current_feeling(payload)
        feelings_prompt = story_service._build_feelings_prompt(character, current_feeling)
        supporting_characters = (
            payload.get("characters") if isinstance(payload.get("characters"), list) else None
        )

        if learning_to_read_mode:
            rhyme_time_mode = False  # learning mode already enforces rhyme/length
            include_illustrations = True

        # Deep character integration - get full character details
        character_details = payload.get("character_details") or {}
        if not isinstance(character_details, dict):
            character_details = {}
        fears = character_details.get("fears", [])
        strengths = character_details.get("strengths", [])
        likes = character_details.get("likes", [])
        dislikes = character_details.get("dislikes", [])
        comfort_item = character_details.get("comfort_item", "")
        personality_traits = character_details.get("personality_traits", [])
        personality_sliders = character_service._sanitize_personality_sliders(
            character_details.get("personality_sliders", {})
        )

        age_instruction_block = story_service._build_age_instruction_block(character_age)

        if learning_to_read_mode:
            prompt = story_service._build_learning_to_read_prompt(
                character,
                theme,
                character_age,
                character_details,
                companion=companion,
                extra_characters=supporting_characters,
            )
        else:
            prompt = story_engine_instance.generate_enhanced_prompt(
                character,
                theme,
                companion,
                therapeutic_prompt,
                feelings_prompt if feelings_prompt else None,
            )

            character_integration = story_service._build_character_integration(
                character,
                fears,
                strengths,
                likes,
                dislikes,
                comfort_item,
                personality_traits,
                personality_sliders,
            )

            sections = [prompt, character_integration]
            sections.append(f"\n{age_instruction_block}")
            if rhyme_time_mode:
                rhyme_instruction = (
                    "\nSTORY STYLE:\n"
                    "**This is extremely important:** Write the entire story in a playful, silly, rhyming verse, like a Dr. Seuss or Julia Donaldson book. "
                    "Use AABB or ABAB rhyme schemes. The story must rhyme."
                )
                sections.append(rhyme_instruction)
            prompt = "\n\n".join(sections)

        # Decide which model to use
        using_user_key = False
        fallback_used = False
        try:
            if user_api_key:
                # User provided their own API key - use it for unlimited generation
                genai.configure(api_key=user_api_key)
                user_model = genai.GenerativeModel(gemini_model)
                response = user_model.generate_content(prompt)
                using_user_key = True
            else:
                # Use server's API key (free tier)
                if model is None:
                    raise RuntimeError("Model unavailable")
                response = model.generate_content(prompt)
                using_user_key = False

            raw_text = getattr(response, "text", "")
            if not raw_text:
                raise ValueError("Empty model response")

        except Exception as e:
            error_type = type(e).__name__
            error_msg = str(e)
            print(f"!!! API ERROR: {error_type}: {error_msg}")
            print(f"!!! Prompt length: {len(prompt)} characters")
            print(f"!!! Using user key: {using_user_key}")

            # Structured error logging
            log_error(
                error_type="story_generation_failed",
                message=str(e),
                details={
                    "character_name": character,
                    "theme": theme,
                    "age": character_age,
                    "prompt_length": len(prompt),
                    "using_user_key": using_user_key,
                    "error_class": error_type,
                    "learning_to_read_mode": learning_to_read_mode,
                    "rhyme_time_mode": rhyme_time_mode,
                },
            )

            # Add helpful hints for common errors
            if "404" in error_msg and "model" in error_msg.lower():
                print("!!! HINT: The Gemini model name may be incorrect. Check GEMINI_MODEL in config.")
                hint = "Model not found. Check GEMINI_MODEL configuration."
            elif "quota" in error_msg.lower() or "429" in error_msg:
                print("!!! HINT: API quota exceeded. Check your Gemini API usage limits.")
                hint = "API quota exceeded. Try again later or use your own API key."
            elif "api key" in error_msg.lower() or "403" in error_msg:
                print("!!! HINT: API key may be invalid. Check GEMINI_API_KEY in environment.")
                hint = "API key invalid. Check GEMINI_API_KEY configuration."
            elif "500" in error_msg or "internal" in error_msg.lower():
                print("!!! HINT: Gemini API internal error. Try again.")
                hint = "Gemini API temporarily unavailable. Please try again."
            else:
                hint = "Story generation failed. Check Railway logs for details."

            print(f"!!! Learning to read mode: {learning_to_read_mode}, Rhyme time mode: {rhyme_time_mode}")
            print(f"!!! Character age: {character_age}, Theme: {theme}")
            logger.exception("Story generation failed")

            if not is_production_fn():
                raw_text = (
                    "[TITLE: An Unexpected Adventure]\n"
                    "Once upon a time, a brave hero discovered that the greatest adventures come from "
                    "facing our fears with courage and kindness.\n"
                    f"[WISDOM GEM: {story_service.WisdomGems.get_wisdom(theme)}]"
                )
            else:
                # In production, fall back to a simple offline-safe story instead of 500 to avoid UI hangs.
                fallback_used = True
                include_illustrations = False  # Skip illustrations if the model is unavailable.
                if learning_to_read_mode or rhyme_time_mode:
                    raw_text = (
                        "[TITLE: A Quick Rhyming Adventure]\n"
                        "Tap your shoes, tap-tap-tap,\n"
                        f"{character} checks a treasure map.\n"
                        "Sun is bright, breeze is light,\n"
                        "Friends team up to make things right.\n"
                        "Kindness shared and worries small,\n"
                        "Brave hearts grow the most of all.\n"
                        f"[WISDOM GEM: {story_service.WisdomGems.get_wisdom(theme)}]"
                    )
                else:
                    raw_text = (
                        "[TITLE: A Quick Adventure]\n"
                        f"{character} starts a small quest about {theme.lower()}.\n"
                        "A tiny problem pops up, friends lend a hand, and courage grows.\n"
                        "Teamwork, a deep breath, and a kind choice solve the trouble.\n"
                        f"[WISDOM GEM: {story_service.WisdomGems.get_wisdom(theme)}]"
                    )
        finally:
            # Reset to server API key after user's request
            if user_api_key and api_key:
                genai.configure(api_key=api_key)

        illustrations = []
        should_generate_illustrations = False
        requested_illustration_count = 0

        def enable_illustrations(min_count: int, reason: str | None = None):
            nonlocal should_generate_illustrations, requested_illustration_count
            should_generate_illustrations = True
            if min_count > requested_illustration_count:
                requested_illustration_count = min_count
            if reason:
                logger.info(reason)

        # Skip illustration generation entirely if we fell back to an offline story.
        if not fallback_used and learning_to_read_mode:
            enable_illustrations(1, f"Learning-to-read mode auto-illustration for tier {subscription_tier}")

        if not fallback_used and subscription_tier == "family":
            enable_illustrations(3, "Family tier bonus: 3 auto-illustrations")
        elif not fallback_used and subscription_tier == "premium":
            enable_illustrations(2, "Premium tier bonus: 2 auto-illustrations")

        if not fallback_used and include_illustrations and not should_generate_illustrations:
            if subscription_tier in {"premium", "family"}:
                enable_illustrations(
                    3 if subscription_tier == "family" else 2, "User requested illustrations (paid tier)"
                )
            elif user_api_key:
                enable_illustrations(1, "User requested illustrations via BYOK")
            elif image_generator is not None:
                # Allow free tier to use the server's image generator (e.g. OpenRouter Nano)
                enable_illustrations(1, "Free tier requested illustrations (server-funded)")
            else:
                logger.info("Free tier requested illustrations but no generator available - skipping")

        if not fallback_used and not should_generate_illustrations and user_api_key and not learning_to_read_mode:
            enable_illustrations(1, "BYOK enabled illustration for free tier")

        if not fallback_used and should_generate_illustrations:
            num_illustrations = max(1, requested_illustration_count)
            try:
                generator = None
                if user_api_key:
                    generator = GeminiImageGenerator(api_key=user_api_key)
                elif image_generator is not None:
                    generator = image_generator

                if generator:
                    scene_preview = (raw_text or "")[:200].replace("\n", " ").strip()
                    if not scene_preview:
                        scene_preview = "A young reader discovering confidence"

                    if subscription_tier == "family":
                        style = "vibrant, detailed children's book illustration with rich colors and multiple focal points"
                    elif subscription_tier == "premium":
                        style = "colorful, painterly children's book illustration"
                    else:
                        style = "simple, colorful children's book illustration for early readers"

                    illustrations = generator.generate_story_illustration(
                        scene_description=f"{character} in a {theme} story. {scene_preview}",
                        character_name=character,
                        style=style,
                        num_images=num_illustrations,
                        age=character_age,
                        therapeutic_focus="reading confidence and engagement",
                    )
                    logger.info(f"Generated {len(illustrations)} illustration(s) for tier {subscription_tier}")
                else:
                    logger.warning("Image generator unavailable for requested illustrations")
            except Exception as e:
                logger.exception(f"Failed to generate illustrations for story response: {str(e)}")
                # Log the specific error for debugging
                logger.error(
                    f"Image generation error details: generator={type(generator).__name__ if generator else 'None'}, error={str(e)}"
                )
                illustrations = []

        title, wisdom_gem, story_text = story_service._safe_extract_title_and_gem(raw_text, theme)
        story_text, story_flagged = filter_story_content(story_text)
        response_payload = {
            "title": title,
            "story": story_text,
            "story_text": story_text,
            "wisdom_gem": wisdom_gem,
            "used_user_key": using_user_key,
        }
        if story_flagged:
            response_payload["content_flagged"] = True
        if illustrations:
            # Ensure illustrations are in the correct format for the frontend (base64 image_data)
            for img in illustrations:
                if "image_url" in img and "image_data" not in img:
                    img_url = img["image_url"]
                    try:
                        if img_url.startswith("data:image/"):
                            # Extract base64 from data URI
                            if ";base64," in img_url:
                                img["image_data"] = img_url.split(";base64,", 1)[1]
                        elif img_url.startswith("http"):
                            # Download image and convert to base64
                            logger.info(f"Downloading illustration from {img_url[:50]}...")
                            img_resp = requests.get(img_url, timeout=10)
                            if img_resp.status_code == 200:
                                b64_data = base64.b64encode(img_resp.content).decode("utf-8")
                                img["image_data"] = b64_data
                                logger.info("Successfully converted image URL to base64 data")
                            else:
                                logger.error(f"Failed to download image: {img_resp.status_code}")
                    except Exception as e:
                        logger.error(f"Error processing illustration image data: {str(e)}")

            response_payload["illustrations"] = illustrations
            response_payload["illustration_count"] = len(illustrations)

        if fallback_used:
            response_payload[
                "warning"
            ] = "Story generation fell back to offline mode. Please check server logs or API key configuration."

        # Track API costs
        user_tier = subscription_tier
        if user_api_key:
            user_tier = "byok"

        # Track story generation cost
        track_cost("story_generation", user_id or "anonymous", user_tier)

        # Track illustration costs if any were generated
        if illustrations:
            illustration_cost = track_cost("image_generation", user_id or "anonymous", user_tier)
            # Scale cost by number of illustrations
            total_illustration_cost = illustration_cost * len(illustrations)
            # Note: The track_cost function already handles the base cost, we just log the scaling
            if len(illustrations) > 1:
                logger.info(
                    f"Additional illustration cost: ${(total_illustration_cost - illustration_cost):.6f} for {len(illustrations)-1} extra images"
                )

        return jsonify(response_payload), 200

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
