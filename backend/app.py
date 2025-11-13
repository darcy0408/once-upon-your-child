import os
import logging
import google.generativeai as genai
from flask import Flask, request, jsonify
from flask_cors import CORS
from .config import config, config_by_name
from .models import db
from .services import character_service, story_service
from .repositories import character_repository

def create_app(config_name):
    app = Flask(__name__)
    app.config.from_object(config_by_name[config_name])
    db.init_app(app)
    
    # CORS setup
    CORS(app, resources={
        r"/*": {
            "origins": app.config["ALLOWED_ORIGINS"],
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"],
        }
    })

    # Logging setup
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger("story_engine")

    # Gemini setup
    api_key = app.config["GEMINI_API_KEY"]
    if not api_key:
        logger.warning("GEMINI_API_KEY not set. Generation endpoints will use fallbacks.")
    else:
        genai.configure(api_key=api_key)

    GEMINI_MODEL = app.config["GEMINI_MODEL"]
    try:
        model = genai.GenerativeModel(GEMINI_MODEL) if api_key else None
    except Exception as e:
        logger.exception("Failed to initialize Gemini model: %s", e)
        model = None

    with app.app_context():
        db.create_all()

    # API Routes
    @app.route("/health", methods=["GET"])
    def health():
        return {"status": "ok", "model": GEMINI_MODEL, "has_api_key": bool(api_key)}, 200

    @app.route("/get-story-themes", methods=["GET"])
    def get_story_themes():
        return jsonify(["Adventure", "Friendship", "Magic", "Dragons", "Castles", "Unicorns", "Space", "Ocean"])

    @app.route("/generate-story", methods=["POST"])
    def generate_story_endpoint():
        payload = request.get_json(silent=True) or {}
        rhyme_time_mode = payload.get("rhyme_time_mode", False)
        learning_to_read_mode = payload.get("learning_to_read_mode", False)
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
            prompt = story_service.story_engine.generate_enhanced_prompt(
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
        try:
            if user_api_key:
                # User provided their own API key - use it for unlimited generation
                genai.configure(api_key=user_api_key)
                user_model = genai.GenerativeModel(GEMINI_MODEL)
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
            print(f"!!! API ERROR: {type(e).__name__}: {str(e)}")
            print(f"!!! Prompt length: {len(prompt)} characters")
            print(f"!!! Learning to read mode: {learning_to_read_mode}, Rhyme time mode: {rhyme_time_mode}")
            print(f"!!! Character age: {character_age}, Theme: {theme}")
            logger.error("Model error, using fallback story. Error: %s", e, exc_info=True)
            raw_text = (
                "[TITLE: An Unexpected Adventure]\n"
                "Once upon a time, a brave hero discovered that the greatest adventures come from "
                "facing our fears with courage and kindness.\n"
                f"[WISDOM GEM: {story_service.WisdomGems.get_wisdom(theme)}]")
        finally:
            # Reset to server API key after user's request
            if user_api_key and api_key:
                genai.configure(api_key=api_key)

        title, wisdom_gem, story_text = story_service._safe_extract_title_and_gem(raw_text, theme)
        return jsonify({
            "title": title,
            "story": story_text,
            "story_text": story_text,
            "wisdom_gem": wisdom_gem,
            "used_user_key": using_user_key
        }), 200

    @app.route("/create-character", methods=["POST"])
    def create_character_endpoint():
        data = request.get_json(silent=True) or {}
        response, status_code = character_service.create_character(data)
        return jsonify(response), status_code

    @app.route("/characters/<string:char_id>", methods=["PATCH", "PUT"])
    def update_character_endpoint(char_id: str):
        data = request.get_json(silent=True) or {}
        response, status_code = character_service.update_character(char_id, data)
        return jsonify(response), status_code

    @app.route("/characters/<string:char_id>", methods=["DELETE"])
    def delete_character_endpoint(char_id: str):
        response, status_code = character_service.delete_character(char_id)
        return jsonify(response), status_code

    @app.route("/get-characters", methods=["GET"])
    def get_characters_endpoint():
        response, status_code = character_service.get_characters()
        return jsonify(response), status_code

    @app.route("/characters/<string:char_id>", methods=["GET"])
    def get_character_endpoint(char_id: str):
        response, status_code = character_service.get_character(char_id)
        return jsonify(response), status_code
    
    return app

app = create_app(os.getenv('FLASK_ENV') or 'prod')

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)