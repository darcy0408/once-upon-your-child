import os
import time
from datetime import datetime, timezone

from flask import Blueprint, jsonify, request
from flask_jwt_extended import (
    create_access_token,
    create_refresh_token,
    get_jwt,
    get_jwt_identity,
    jwt_required,
)
from sqlalchemy.exc import IntegrityError

from ..database import db
from ..models.user import User
from ..openrouter_image_generator import OpenRouterImageGenerator
from ..quality_service import StoryQualityService
from ..middleware.auth import require_auth, require_admin, require_owner
from ..utils.audit import audit_log


def _blocklist_jti(jti: str, exp: int, logger) -> None:
    """Write a consumed JWT ID to Redis so it cannot be replayed.

    The key expires automatically at the token's original expiry time so no
    cleanup job is needed.  A Redis outage is logged but never raises — losing
    the ability to blocklist one token is far less harmful than breaking auth.
    """
    from datetime import datetime, timezone

    redis_url = os.getenv('REDIS_URL') or os.getenv('REDIS_PRIVATE_URL')
    if not redis_url:
        return
    try:
        import redis as _redis_lib
        r = _redis_lib.from_url(redis_url, socket_connect_timeout=1)
        remaining = max(1, exp - int(datetime.now(timezone.utc).timestamp()))
        r.setex(f'jwt:blocklist:{jti}', remaining, '1')
    except Exception as exc:
        logger.warning('jwt refresh: failed to blocklist old JTI %s (%s)', jti, exc)


def create_utility_blueprint(logger, log_error, limiter=None):
    utility_bp = Blueprint("utility", __name__)

    def rate_limit(limit_value):
        def decorator(func):
            if limiter is None:
                return func
            return limiter.limit(limit_value)(func)

        return decorator

    @utility_bp.route('/quality/score-story', methods=['POST'])
    @require_auth
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
    @require_auth
    @require_admin
    def debug_gemini():
        """Debug endpoint to test Gemini text generation"""
        api_key = os.getenv("GEMINI_API_KEY")
        model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
        
        status = {
            "api_key_configured": bool(api_key),
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
            # Log the detail server-side; return only a generic message so the
            # response never leaks driver/connection internals.
            logger.exception("Debug Gemini failed")
            status["success"] = False
            status["error"] = "Gemini generation failed — see server logs for detail"
            status["error_type"] = type(e).__name__
            status["steps"].append("❌ Error: generation failed")

            # Try to list available models to help debug
            try:
                from google import genai as genai_sdk
                client = genai_sdk.Client(api_key=api_key)
                available_models = []
                for m in client.models.list():
                    available_models.append(m.name)
                status["available_models"] = available_models[:20]  # Limit to first 20
                status["steps"].append(f"ℹ️ Listed {len(available_models)} available models")
            except Exception:
                logger.exception("Debug Gemini: failed to list models")
                status["steps"].append("❌ Failed to list models — see server logs")

        return jsonify(status)

    @utility_bp.route('/debug-openrouter', methods=['GET'])
    @require_auth
    @require_admin
    def debug_openrouter():
        """Debug endpoint to test OpenRouter configuration and generation."""
        try:
            api_key = os.getenv("OPENROUTER_API_KEY")
            if not api_key:
                # SECURITY: never echo the environment variable names — that
                # leaks the full server config surface to the caller.
                return jsonify({
                    "status": "error",
                    "message": "OPENROUTER_API_KEY is not configured",
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
                })
            except Exception:
                # Log detail server-side; return a generic message only.
                logger.exception("Debug OpenRouter: image generation failed")
                return jsonify({
                    "status": "error",
                    "message": "Image generation failed — see server logs for detail",
                }), 500

        except Exception:
            logger.exception("Debug OpenRouter endpoint failed")
            return jsonify({
                "status": "error",
                "message": "Debug endpoint failed — see server logs for detail",
            }), 500

    @utility_bp.route("/setup-test-account", methods=["POST"])
    def setup_test_account():
        """Create or update a test account for E2E tests.

        Test scaffolding only — never available in production.  Returns 404
        when running in production so the endpoint's existence is not even
        confirmed to an unauthenticated caller.  The account password is
        randomly generated per call (no hardcoded credentials); callers that
        need to log in must capture the returned ``password`` value.
        """
        import uuid

        from ..utils.app_helpers import is_production

        if is_production():
            return jsonify({"error": "Not found"}), 404

        username = "testuser"
        email = "testuser@test.com"
        password = uuid.uuid4().hex
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
        return jsonify({
            "status": status,
            "username": username,
            "password": password,
        }), 201 if status == "created" else 200

    @utility_bp.route("/auth/anonymous", methods=["POST"])
    @rate_limit("20 per minute")
    def get_anonymous_token():
        """Get or create an anonymous user and return a JWT token.

        The server always generates the anonymous user ID.  A client may
        send a previously issued `client_id` to reclaim an existing
        anonymous session, but only if that ID maps to a confirmed
        anonymous account (email domain @anonymous.storyweaver.app).
        Client-supplied IDs that map to registered accounts are silently
        ignored and a fresh anonymous account is created instead — this
        prevents the endpoint from being used as an auth-bypass to obtain
        JWTs for arbitrary user IDs.
        """
        import uuid
        data = request.get_json(silent=True) or {}
        client_id = data.get('client_id')
        user = None

        # Only honour client-supplied IDs that belong to per-session anonymous
        # accounts. The bootstrap singleton 'anonymous' user must never be
        # reclaimed — issuing a JWT for it would collapse all anonymous traffic
        # onto one identity / rate-limit bucket (M-16).
        if client_id == 'anonymous':
            logger.warning(
                "auth/anonymous: client_id 'anonymous' (singleton) rejected; "
                "creating new per-session anonymous account."
            )
            client_id = None

        # Only honour client-supplied IDs that belong to anonymous accounts.
        if client_id:
            candidate = User.query.filter_by(id=client_id).first()
            if (
                candidate
                and candidate.id != 'anonymous'
                and candidate.email.endswith('@anonymous.storyweaver.app')
            ):
                user = candidate
                logger.info("Anonymous session reclaimed: %s", client_id)
            elif candidate:
                # ID exists but belongs to a registered user — reject silently.
                logger.warning(
                    "auth/anonymous: client_id %s matches a non-anonymous account; "
                    "ignoring and creating new anonymous session.",
                    client_id,
                )

        if not user:
            # Always generate the ID server-side for new anonymous accounts.
            new_id = f"anon_{uuid.uuid4().hex[:16]}"
            anonymous_email = f"{new_id}@anonymous.storyweaver.app"
            user = User(
                id=new_id,
                username=f"guest_{new_id[-8:]}",
                email=anonymous_email,
            )
            user.set_password(uuid.uuid4().hex)
            db.session.add(user)
            try:
                db.session.commit()
                logger.info("Created anonymous user: %s", new_id)
            except IntegrityError:
                db.session.rollback()
                user = User.query.filter_by(id=new_id).first()
                if not user:
                    user = User.query.filter_by(email=anonymous_email).first()
                if not user:
                    raise
                logger.info("Anonymous user already exists after race: %s", new_id)

        token = create_access_token(
            identity=user.id,
            additional_claims={'tv': getattr(user, 'token_version', 0) or 0},
        )
        refresh_token = create_refresh_token(identity=user.id)
        # CMP-5 / PP-13: stamp activity so the retention purge job does not
        # treat a freshly-issued anonymous session as inactive.
        try:
            user.last_active_at = datetime.now(timezone.utc)
            db.session.commit()
        except Exception:
            db.session.rollback()
        audit_log('anonymous_session', user_id=user.id)
        return jsonify({
            'token': token,
            'refresh_token': refresh_token,
            'user_id': user.id,
            'is_anonymous': True,
        }), 200

    @utility_bp.route("/auth/login", methods=["POST"])
    @rate_limit("10 per minute")
    def login():
        """Simple login endpoint for testing."""
        data = request.get_json(silent=True) or {}
        username = data.get('username')
        password = data.get('password')

        user = User.query.filter_by(username=username).first()
        if user and user.check_password(password):
            token = create_access_token(
                identity=user.id,
                additional_claims={'tv': getattr(user, 'token_version', 0) or 0},
            )
            refresh_token = create_refresh_token(identity=user.id)
            # CMP-5 / PP-13: stamp activity so the data-retention purge job
            # does not treat a still-active account as inactive.
            try:
                user.last_active_at = datetime.now(timezone.utc)
                db.session.commit()
            except Exception:
                db.session.rollback()
            audit_log('user_login', user_id=user.id)
            return jsonify({'token': token, 'refresh_token': refresh_token}), 200

        return jsonify({'message': 'Invalid credentials'}), 401

    @utility_bp.route("/auth/refresh", methods=["POST"])
    @rate_limit("30 per minute")
    @jwt_required(refresh=True)
    def refresh_auth_token():
        """Issue a new access + refresh token pair and revoke the old refresh token."""
        user_id = get_jwt_identity()
        if not user_id:
            return jsonify({'error': 'Invalid refresh token'}), 401

        user = User.query.filter_by(id=user_id).first()
        if not user:
            return jsonify({'error': 'User not found'}), 401

        # Blocklist the consumed refresh token so it cannot be reused even within
        # its remaining TTL (refresh token rotation / family invalidation).
        old_claims = get_jwt()
        old_jti = old_claims.get('jti')
        old_exp = old_claims.get('exp')
        if old_jti and old_exp:
            _blocklist_jti(old_jti, old_exp, logger)

        token = create_access_token(
            identity=user.id,
            additional_claims={'tv': getattr(user, 'token_version', 0) or 0},
        )
        new_refresh = create_refresh_token(identity=user.id)
        # CMP-5 / PP-13: a token refresh means the app is in active use —
        # stamp activity so the retention purge job leaves this account alone.
        try:
            user.last_active_at = datetime.now(timezone.utc)
            db.session.commit()
        except Exception:
            db.session.rollback()
        audit_log('token_refreshed', user_id=user.id)
        return jsonify({
            'token': token,
            'refresh_token': new_refresh,
            'user_id': user.id,
        }), 200

    @utility_bp.route("/users/<string:user_id>/feature-unlocks", methods=["GET"])
    @require_auth
    @require_owner('user_id')
    def get_feature_unlocks(user_id: str):
        """Get feature unlock status for a user."""
        try:
            user = User.query.filter_by(id=user_id).first()
            if not user:
                return jsonify({'error': 'User not found'}), 404

            stories_created = user.stories_created_count

            # 1-free-avatar gate (MT-151): surface the lifetime custom-avatar
            # count and the authoritative premium flag so the client can gate
            # the photo-avatar card UPFRONT instead of letting a non-premium
            # user who already used their free one waste a selfie.
            try:
                from backend.routes.subscription_routes import _user_is_premium
            except ImportError:
                from routes.subscription_routes import _user_is_premium

            unlock_status = {
                'stories_created_count': stories_created,
                'character_creation_unlocked': stories_created >= 1,
                'interactive_stories_unlocked': stories_created >= 2,
                'coloring_pages_unlocked': stories_created >= 3,
                'advanced_settings_unlocked': stories_created >= 5,
                'custom_avatars_generated': user.custom_avatars_generated or 0,
                'is_premium': _user_is_premium(user),
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
    @require_auth
    @require_owner('user_id')
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
    @require_auth
    @require_admin
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
    @require_auth
    @require_admin
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
    @require_auth
    @require_admin
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
