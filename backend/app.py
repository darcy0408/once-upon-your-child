import os
import logging
import google.generativeai as genai
from flask import Flask, request, jsonify
from flask_cors import CORS

from .config import config, config_by_name
from .database import db
# Import models in dependency order (Story and Character first, then User which references them)
from .models.story import Story
from .models.character import Character
from .models.achievement import UserAchievement, AchievementStats
from .models.user import User

from .services import character_service, story_service
# from .repositories import character_repository
from .gemini_image_generator import GeminiImageGenerator
# Route imports removed - routes defined directly in app.py

# Global image generator instance
image_generator = None
from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

def create_app(config_name):
    print(f"=== Creating Flask app with config: {config_name} ===")
    app = Flask(__name__)
    app.config.from_object(config_by_name[config_name])
    print(f"=== Config loaded, initializing database ===")
    db.init_app(app)
    print(f"=== Database initialized ===")

    # CORS setup
    CORS(app, resources={
        r"/*": {
            "origins": app.config["ALLOWED_ORIGINS"],
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"],
        }
    })

    # Rate limiting setup
    limiter = Limiter(
        app=app,
        key_func=get_remote_address,
        default_limits=["200 per day", "50 per hour"],
        storage_uri="memory://"
    )

    # Logging setup
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger("story_engine")

    # Gemini setup
    api_key = app.config["GEMINI_API_KEY"]
    print(f"DEBUG: api_key from config = {api_key}")
    print(f"DEBUG: bool(api_key) = {bool(api_key)}")
    if not api_key:
        logger.warning("GEMINI_API_KEY not set. Generation endpoints will use fallbacks.")
    else:
        genai.configure(api_key=api_key)
        print(f"DEBUG: Gemini configured with API key")

    GEMINI_MODEL = "gemini-1.5-flash"
    try:
        model = genai.GenerativeModel(GEMINI_MODEL) if api_key else None
    except Exception as e:
        logger.exception("Failed to initialize Gemini model: %s", e)
        model = None

    # Initialize image generator
    try:
        image_generator = GeminiImageGenerator() if api_key else None
    except Exception as e:
        logger.exception("Failed to initialize image generator: %s", e)
        image_generator = None

    print(f"=== Creating database tables ===")
    with app.app_context():
        db.create_all()
    print(f"=== Database tables created ===")

    # JWT setup
    jwt = JWTManager(app)
    app.config['JWT_SECRET_KEY'] = app.config.get('JWT_SECRET_KEY', 'dev-secret-key')

    # Blueprints removed - routes defined directly in app.py

    # API Routes
    print(f"=== Registering routes ===")
    @app.route("/health", methods=["GET"])
    def health():
        print(f"=== Health endpoint called ===")

        # Add database check
        db_status = "ok"
        try:
            # Simple query to verify database connection
            from .models.user import User
            User.query.limit(1).all()
        except Exception as e:
            db_status = f"error: {str(e)}"

        return {
            "status": "ok",
            "model": GEMINI_MODEL,
            "has_api_key": bool(api_key),
            "database": db_status,
            "environment": app.config.get("ENV", "unknown")
        }, 200
    
    @app.route("/get-story-themes", methods=["GET"])
    def get_story_themes():
        return jsonify(["Adventure", "Friendship", "Magic", "Dragons", "Castles", "Unicorns", "Space", "Ocean"])

    @limiter.limit("10 per minute")
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
            error_type = type(e).__name__
            error_msg = str(e)
            print(f"!!! API ERROR: {error_type}: {error_msg}")
            print(f"!!! Prompt length: {len(prompt)} characters")

            # Add helpful hints for common errors
            if "404" in error_msg and "model" in error_msg.lower():
                print("!!! HINT: The Gemini model name may be incorrect. Check GEMINI_MODEL in config.")
            elif "quota" in error_msg.lower():
                print("!!! HINT: API quota exceeded. Check your Gemini API usage limits.")
            elif "api key" in error_msg.lower():
                print("!!! HINT: API key may be invalid. Check GEMINI_API_KEY in .env file.")

            print(f"!!! Learning to read mode: {learning_to_read_mode}, Rhyme time mode: {rhyme_time_mode}")
            print(f"!!! Character age: {character_age}, Theme: {theme}")
            logger.exception("Story generation failed")

            environment = os.getenv("ENV", "").lower()
            if environment in ("dev", "development", "local"):
                raw_text = (
                    "[TITLE: An Unexpected Adventure]\n"
                    "Once upon a time, a brave hero discovered that the greatest adventures come from "
                    "facing our fears with courage and kindness.\n"
                    f"[WISDOM GEM: {story_service.WisdomGems.get_wisdom(theme)}]")
            else:
                return jsonify({
                    "error": str(e),
                    "hint": "Generation failed. Check GEMINI_API_KEY / GEMINI_MODEL / quota in Railway logs."
                }), 500
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

    @limiter.limit("10 per hour")
    @app.route("/generate-illustrations", methods=["POST"])
    def generate_illustrations_endpoint():
        """Generate illustrations for a story scene"""
        if image_generator is None:
            return jsonify({"error": "Image generation not available"}), 503

        try:
            data = request.get_json(silent=True) or {}
            scene_description = data.get("scene_description", "")
            character_name = data.get("character_name", "the hero")
            style = data.get("style", "children's book illustration")
            num_images = min(int(data.get("num_images", 1)), 4)  # Max 4 images
            age = int(data.get("age", 7))
            therapeutic_focus = data.get("therapeutic_focus")

            if not scene_description.strip():
                return jsonify({"error": "Scene description is required"}), 400

            illustrations = image_generator.generate_story_illustration(
                scene_description=scene_description,
                character_name=character_name,
                style=style,
                num_images=num_images,
                age=age,
                therapeutic_focus=therapeutic_focus
            )

            return jsonify({
                "illustrations": illustrations,
                "count": len(illustrations)
            }), 200

        except Exception as e:
            print(f"!!! Illustration generation failed: {e}")
            return jsonify({"error": "Failed to generate illustrations"}), 500

    @limiter.limit("10 per hour")
    @app.route("/generate-coloring-pages", methods=["POST"])
    def generate_coloring_pages_endpoint():
        """Generate coloring book pages for a story scene"""
        if image_generator is None:
            return jsonify({"error": "Image generation not available"}), 503

        try:
            data = request.get_json(silent=True) or {}
            scene_description = data.get("scene_description", "")
            character_name = data.get("character_name", "the hero")
            num_images = min(int(data.get("num_images", 1)), 3)  # Max 3 pages
            age = int(data.get("age", 7))
            therapeutic_focus = data.get("therapeutic_focus")

            if not scene_description.strip():
                return jsonify({"error": "Scene description is required"}), 400

            coloring_pages = image_generator.generate_coloring_page(
                scene_description=scene_description,
                character_name=character_name,
                num_images=num_images,
                age=age,
                therapeutic_focus=therapeutic_focus
            )

            return jsonify({
                "coloring_pages": coloring_pages,
                "count": len(coloring_pages)
            }), 200

        except Exception as e:
            print(f"!!! Coloring page generation failed: {e}")
            return jsonify({"error": "Failed to generate coloring pages"}), 500

    @limiter.limit("20 per hour")
    @app.route("/create-character", methods=["POST"])
    def create_character_endpoint():
        logger.info(f"POST /create-character called")
        data = request.get_json(silent=True) or {}
        response, status_code = character_service.create_character(data)
        logger.info(f"Character creation result: {status_code}")
        return jsonify(response), status_code

    @app.route("/characters/<string:char_id>", methods=["PATCH", "PUT"])
    def update_character_endpoint(char_id: str):
        logger.info(f"PATCH/PUT /characters/{char_id} called")
        data = request.get_json(silent=True) or {}
        response, status_code = character_service.update_character(char_id, data)
        logger.info(f"Character update result: {status_code}")
        return jsonify(response), status_code

    @app.route("/characters/<string:char_id>", methods=["DELETE"])
    def delete_character_endpoint(char_id: str):
        logger.info(f"DELETE /characters/{char_id} called")
        response, status_code = character_service.delete_character(char_id)
        logger.info(f"Character deletion result: {status_code}")
        return jsonify(response), status_code

    @app.route("/get-characters", methods=["GET"])
    def get_characters_endpoint():
        logger.info(f"GET /get-characters called")
        response, status_code = character_service.get_characters()
        logger.info(f"Get characters result: {status_code}")
        return jsonify(response), status_code

    @app.route("/characters/<string:char_id>", methods=["GET"])
    def get_character_endpoint(char_id: str):
        logger.info(f"GET /characters/{char_id} called")
        response, status_code = character_service.get_character(char_id)
        logger.info(f"Get character result: {status_code}")
        return jsonify(response), status_code

    @app.route("/setup-test-account", methods=["POST"])
    def setup_test_account():
        """Create or update a test account for E2E tests."""
        username = "testuser"
        email = "testuser@test.com"
        password = "password"
        user = User.query.filter_by(username=username).first()
        if user:
            user.set_password(password)
            status = "updated"
        else:
            user = User(username=username, email=email)
            user.set_password(password)
            db.session.add(user)
            status = "created"
        db.session.commit()
        return jsonify({"status": status, "username": username}), 201 if status == "created" else 200

    @app.route("/auth/login", methods=["POST"])
    def login():
        """Simple login endpoint for testing."""
        data = request.get_json(silent=True) or {}
        username = data.get('username')
        password = a.get('password')

        user = User.query.filter_by(username=username).first()
        if user and user.check_password(password):
            from flask_jwt_extended import create_access_token
            token = create_access_token(identity=user.id)
            return jsonify({'token': token}), 200

        return jsonify({'message': 'Invalid credentials'}), 401

    print(f"=== All routes registered successfully ===")
    print(f"=== Registered routes: {[rule.rule for rule in app.url_map.iter_rules()]} ===")
    return app

# A cosmetic change to force a Railway redeploy.

