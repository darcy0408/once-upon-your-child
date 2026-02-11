import os
import time
import traceback

from flask import Blueprint, jsonify, request
from flask_jwt_extended import create_access_token
from sqlalchemy.exc import IntegrityError

from ..database import db
from ..models.user import User
from ..openrouter_image_generator import OpenRouterImageGenerator
from ..quality_service import StoryQualityService


def create_utility_blueprint(logger, log_error):
    utility_bp = Blueprint("utility", __name__)

    @utility_bp.route('/quality/score-story', methods=['POST'])
    def score_story_quality():
        """Score a story for quality metrics"""
        try:
            data = request.get_json(silent=True) or {}
            story_text = data.get('story_text', '').strip()
            age = int(data.get('age', 7))

            if not story_text:
                return jsonify({'error': 'Story text is required'}), 400

            quality_score = StoryQualityService.calculate_story_quality(story_text, age)

            return jsonify(quality_score), 200

        except ValueError:
            return jsonify({'error': 'Invalid age parameter'}), 400
        except Exception as e:
            log_error(
                error_type='quality_scoring_failed',
                message=str(e),
                details={'error_class': e.__class__.__name__}
            )
            return jsonify({'error': 'Quality scoring failed'}), 500

    @utility_bp.route('/debug-gemini', methods=['GET'])
    def debug_gemini():
        """Debug endpoint to test Gemini text generation"""
        api_key = os.getenv("GEMINI_API_KEY")
        model_name = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
        
        status = {
            "api_key_configured": bool(api_key),
            "api_key_prefix": api_key[:4] + "..." if api_key else None,
            "model_name": model_name,
            "steps": []
        }
        
        try:
            # Step 1: Configure
            if not api_key:
                status["steps"].append("❌ API Key missing")
                return jsonify(status), 500

            from google import genai

            client = genai.Client(api_key=api_key)
            status["steps"].append("✅ GenAI Client Created")

            # Step 2: Generate Content (model specified per-request in new SDK)
            status["steps"].append(f"✅ Using model: {model_name}")

            # Step 3: Generate Content
            start_time = time.time()
            response = client.models.generate_content(
                model=model_name,
                contents="Say 'Hello from Gemini!' if you can hear me."
            )
            duration = time.time() - start_time

            status["steps"].append(f"✅ Generation successful ({duration:.2f}s)")
            status["response_text"] = response.text
            status["success"] = True

        except Exception as e:
            status["success"] = False
            status["error"] = str(e)
            status["error_type"] = type(e).__name__
            status["steps"].append(f"❌ Error: {str(e)}")
            logger.exception("Debug Gemini failed")

            # Try to list available models to help debug
            try:
                from google import genai as genai_sdk
                client = genai_sdk.Client(api_key=api_key)
                available_models = []
                for m in client.models.list():
                    available_models.append(m.name)
                status["available_models"] = available_models[:20]  # Limit to first 20
                status["steps"].append(f"ℹ️ Listed {len(available_models)} available models")
            except Exception as list_err:
                status["steps"].append(f"❌ Failed to list models: {str(list_err)}")

        return jsonify(status)

    @utility_bp.route('/debug-openrouter', methods=['GET'])
    def debug_openrouter():
        """Debug endpoint to test OpenRouter configuration and generation."""
        try:
            api_key = os.getenv("OPENROUTER_API_KEY")
            if not api_key:
                return jsonify({
                    "status": "error",
                    "message": "OPENROUTER_API_KEY not found in environment variables",
                    "env_keys": list(os.environ.keys())
                }), 500

            # Test generation
            generator = OpenRouterImageGenerator()
            test_prompt = "A cute small blue bird"
            
            try:
                # Returns list of dicts: [{'image_url': '...', ...}]
                images = generator.generate_story_illustration(test_prompt) 
                
                preview = "None"
                if images and len(images) > 0:
                     first_img = images[0]
                     if 'image_url' in first_img:
                         # Handle if image_url is very long (base64)
                         url_str = str(first_img['image_url'])
                         preview = url_str[:50] + "..." if len(url_str) > 50 else url_str
                
                return jsonify({
                    "status": "success",
                    "message": "Image generated successfully",
                    "model": "google/gemini-2.5-flash-image",
                    "image_count": len(images),
                    "image_data_preview": preview,
                    "api_key_preview": f"{api_key[:4]}...{api_key[-4:]}"
                })
            except Exception as e:
                return jsonify({
                    "status": "error",
                    "message": f"Generation failed: {str(e)}",
                    "traceback": traceback.format_exc()
                }), 500

        except Exception as e:
            return jsonify({
                "status": "error",
                "message": f"Debug endpoint failed: {str(e)}",
                "traceback": traceback.format_exc()
            }), 500

    @utility_bp.route("/setup-test-account", methods=["POST"])
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

    @utility_bp.route("/auth/anonymous", methods=["POST"])
    def get_anonymous_token():
        """Get or create an anonymous user and return a JWT token.

        This allows the frontend to make authenticated requests without
        requiring user registration. The anonymous user ID is generated
        client-side and sent to persist data across sessions.
        """
        import uuid
        data = request.get_json(silent=True) or {}
        client_id = data.get('client_id')

        if not client_id:
            # Generate a new anonymous ID if client doesn't have one
            client_id = f"anon_{uuid.uuid4().hex[:16]}"

        # Find or create anonymous user
        anonymous_email = f"{client_id}@anonymous.storyweaver.app"
        user = User.query.filter_by(id=client_id).first()
        if not user:
            user = User(
                id=client_id,
                username=f"guest_{client_id[-8:]}",
                email=anonymous_email
            )
            # Set a random password (user won't need it for anonymous access)
            user.set_password(uuid.uuid4().hex)
            db.session.add(user)
            try:
                db.session.commit()
                logger.info(f"Created anonymous user: {client_id}")
            except IntegrityError:
                # Two concurrent requests can race to create the same anonymous user.
                # Recover by loading the row created by the winning request.
                db.session.rollback()
                user = User.query.filter_by(id=client_id).first()
                if not user:
                    user = User.query.filter_by(email=anonymous_email).first()
                if not user:
                    raise
                logger.info(f"Anonymous user already exists after race: {client_id}")

        token = create_access_token(identity=user.id)
        return jsonify({
            'token': token,
            'user_id': user.id,
            'is_anonymous': True
        }), 200

    @utility_bp.route("/auth/login", methods=["POST"])
    def login():
        """Simple login endpoint for testing."""
        data = request.get_json(silent=True) or {}
        username = data.get('username')
        password = data.get('password')

        user = User.query.filter_by(username=username).first()
        if user and user.check_password(password):
            token = create_access_token(identity=user.id)
            return jsonify({'token': token}), 200

        return jsonify({'message': 'Invalid credentials'}), 401

    @utility_bp.route("/users/<string:user_id>/feature-unlocks", methods=["GET"])
    def get_feature_unlocks(user_id: str):
        """Get feature unlock status for a user."""
        try:
            user = User.query.filter_by(id=user_id).first()
            if not user:
                return jsonify({'error': 'User not found'}), 404

            stories_created = user.stories_created_count

            unlock_status = {
                'stories_created_count': stories_created,
                'character_creation_unlocked': stories_created >= 1,
                'interactive_stories_unlocked': stories_created >= 2,
                'coloring_pages_unlocked': stories_created >= 3,
                'advanced_settings_unlocked': stories_created >= 5,
            }

            return jsonify(unlock_status), 200

        except Exception as e:
            log_error(
                error_type='get_feature_unlocks_failed',
                message=str(e),
                details={
                    'user_id': user_id,
                    'error_class': e.__class__.__name__
                }
            )
            return jsonify({'error': 'Failed to get feature unlocks'}), 500

    @utility_bp.route("/users/<string:user_id>/story-created", methods=["POST"])
    def record_story_created(user_id: str):
        """Increment the stories created count for a user."""
        try:
            user = User.query.filter_by(id=user_id).first()
            if not user:
                return jsonify({'error': 'User not found'}), 404

            user.stories_created_count += 1
            db.session.commit()

            return jsonify({
                'stories_created_count': user.stories_created_count,
                'message': 'Story creation recorded successfully'
            }), 200

        except Exception as e:
            db.session.rollback()
            log_error(
                error_type='record_story_created_failed',
                message=str(e),
                details={
                    'user_id': user_id,
                    'error_class': e.__class__.__name__
                }
            )
            return jsonify({'error': 'Failed to record story creation'}), 500

    @utility_bp.route("/usage/summary", methods=["GET"])
    def get_usage_summary():
        """
        Get API usage summary and cost estimates.

        Query Parameters:
            days: Number of days to include (default: 30)
            include_mock: Include mock calls (default: true)

        Returns:
            JSON with usage statistics and cost breakdown
        """
        try:
            from backend.services.usage_tracking_service import get_usage_tracker
            from datetime import datetime, timedelta

            # Get query parameters
            days = int(request.args.get('days', 30))
            include_mock = request.args.get('include_mock', 'true').lower() in ['true', '1', 'yes']

            tracker = get_usage_tracker()

            # Get summary for date range
            end_date = datetime.now()
            start_date = end_date - timedelta(days=days)

            summary = tracker.get_usage_summary(
                start_date=start_date,
                end_date=end_date,
                include_mock=include_mock
            )

            return jsonify(summary), 200

        except Exception as e:
            logger.exception(f"Failed to get usage summary: {e}")
            return jsonify({'error': 'Failed to get usage summary', 'detail': str(e)}), 500

    @utility_bp.route("/usage/daily", methods=["GET"])
    def get_daily_usage():
        """
        Get daily usage breakdown.

        Query Parameters:
            days: Number of days to include (default: 7)

        Returns:
            JSON with daily usage statistics
        """
        try:
            from backend.services.usage_tracking_service import get_usage_tracker

            days = int(request.args.get('days', 7))

            tracker = get_usage_tracker()
            daily = tracker.get_daily_breakdown(days=days)

            return jsonify(daily), 200

        except Exception as e:
            logger.exception(f"Failed to get daily usage: {e}")
            return jsonify({'error': 'Failed to get daily usage', 'detail': str(e)}), 500

    @utility_bp.route("/usage/mock-mode", methods=["GET"])
    def get_mock_mode_status():
        """
        Check if mock testing mode is enabled.

        Returns:
            JSON with mock mode status and configuration
        """
        try:
            from flask import current_app

            mock_mode = current_app.config.get('MOCK_TESTING_MODE', False)

            return jsonify({
                'mock_testing_mode': mock_mode,
                'environment': os.environ.get('FLASK_ENV', 'unknown'),
                'message': 'Mock mode is ENABLED - using free mock endpoints' if mock_mode
                          else 'Mock mode is DISABLED - using real API (costs apply)'
            }), 200

        except Exception as e:
            logger.exception(f"Failed to get mock mode status: {e}")
            return jsonify({'error': str(e)}), 500

    return utility_bp
