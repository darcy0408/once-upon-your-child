import os
import uuid
import logging
import traceback
from datetime import datetime
from datetime import timedelta
import time
import sys

# Ensure backend package is importable when running as script
if __name__ == '__main__' and __package__ is None:
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from flask import Flask, request, jsonify, g
from flask_cors import CORS
from dotenv import load_dotenv

# Configure logging to file
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("backend_errors.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

try:
    from backend.config import config, config_by_name
    from backend.database import db
    from backend.celery_config import celery
    # Import models in dependency order (Story and Character first, then User which references them)
    from backend.models.story import Story
    from backend.models.character import Character
    from backend.models.achievement import UserAchievement, AchievementStats
    from backend.models.user import User

    from backend.services.story_service import AdvancedStoryEngine
    from backend.cost_tracking import track_cost
    from backend.utils.app_helpers import (
        get_user_identifier,
        get_user_tier,
        get_tier_limits,
        is_production,
        make_filter_story_content,
        make_log_error,
        make_add_request_id,
        make_log_response,
        make_handle_error,
    )
    from backend.utils.request_logger import init_request_logging
except ImportError:
    # Fallback if backend package not found (e.g. running from inside backend dir without path fix)
    from config import config, config_by_name
    from database import db
    from celery_config import celery
    from models.story import Story
    from models.character import Character
    from models.achievement import UserAchievement, AchievementStats
    from models.user import User

    from services.story_service import AdvancedStoryEngine
    from cost_tracking import track_cost
    from utils.app_helpers import (
        get_user_identifier,
        get_user_tier,
        get_tier_limits,
        is_production,
        make_filter_story_content,
        make_log_error,
        make_add_request_id,
        make_log_response,
        make_handle_error,
    )
    from utils.request_logger import init_request_logging

from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_caching import Cache
import sentry_sdk
from sentry_sdk.integrations.flask import FlaskIntegration

# Global image generator instance
image_generator = None

def create_app(config_name):
    print(f"=== Creating Flask app with config: {config_name} ===")
    print(f"=== Available configs: {list(config_by_name.keys())} ===")
    # Image generation fix deployed - 2024-12-01
    # Explicitly set static folder to ensure avatars are served correctly
    static_folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'static')
    app = Flask(__name__, static_folder=static_folder, static_url_path='/static')

    # Normalize config name
    if config_name not in config_by_name:
        print(f"WARNING: Config '{config_name}' not found, using 'production'")
        config_name = 'production'

    # Initialize Sentry (Priority 3)
    sentry_dsn = os.getenv('SENTRY_DSN')
    if sentry_dsn and config_name != 'testing':
        print(f"=== Initializing Sentry (Env: {config_name}) ===")
        try:
            sentry_sdk.init(
                dsn=sentry_dsn,
                integrations=[FlaskIntegration()],
                # sample 10% in prod, 100% in dev
                traces_sample_rate=0.1 if config_name == 'production' else 1.0,
                environment=config_name
            )
        except Exception as e:
            print(f"WARNING: Sentry initialization failed: {e}")

    if config_name == 'testing':
        app.config.from_object(config_by_name['testing'])
        app.config['TESTING'] = True
        app.config.pop('SQLALCHEMY_ENGINE_OPTIONS', None)
    else:
        app.config.from_object(config_by_name[config_name])

    testing_mode = app.config.get('TESTING', False)

    print(f"=== Config loaded, initializing database ===")
    db.init_app(app)
    print(f"=== Database initialized ===")

    # Update Celery configuration
    celery.config_from_object(app.config, namespace='CELERY')

    # Initialize AdvancedStoryEngine
    story_engine_instance = AdvancedStoryEngine()

    # CORS setup
    CORS(app, resources={
        r"/*": {
            "origins": app.config["ALLOWED_ORIGINS"],
            "methods": ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"],
        }
    })

    def _is_allowed_origin(origin_value):
        if not origin_value:
            return True
        for allowed in app.config.get("ALLOWED_ORIGINS", []):
            if hasattr(allowed, "match"):
                if allowed.match(origin_value):
                    return True
            elif origin_value == allowed:
                return True
        return False

    @app.before_request
    def enforce_csrf_origin_policy():
        """
        CSRF hardening for browser-triggered unsafe requests.
        If Origin/Referer is present, require it to match allowed origins.
        """
        if request.method in {"GET", "HEAD", "OPTIONS"}:
            return None

        origin = request.headers.get("Origin")
        referer = request.headers.get("Referer")

        if origin and not _is_allowed_origin(origin):
            return jsonify({"error": "Origin not allowed"}), 403

        if not origin and referer:
            from urllib.parse import urlparse
            referer_origin = f"{urlparse(referer).scheme}://{urlparse(referer).netloc}"
            if not _is_allowed_origin(referer_origin):
                return jsonify({"error": "Referer origin not allowed"}), 403

        return None

    # Rate limiting setup
    # Use Redis in production for distributed rate limiting, fallback to memory for dev
    redis_url = os.getenv('REDIS_URL') or os.getenv('REDIS_PRIVATE_URL')
    if redis_url and not testing_mode:
        rate_limit_storage = redis_url
        logger.info("Rate limiting configured with Redis (distributed)")
    else:
        rate_limit_storage = "memory://"
        if not testing_mode:
            if is_production():
                logger.error(
                    "Rate limiting is using in-memory storage in production. "
                    "This is not safe for multi-instance deployments; set REDIS_URL/REDIS_PRIVATE_URL."
                )
            else:
                logger.warning("Rate limiting using in-memory storage - not suitable for multi-instance deployments")

    limiter = Limiter(
        app=app,
        key_func=get_user_identifier,
        default_limits=["200 per day", "50 per hour"],
        storage_uri=rate_limit_storage
    )
    logger.info("Rate limiting enabled=%s storage=%s", limiter.enabled, rate_limit_storage)
    # Store limiter on app to prevent garbage collection when passed to blueprints
    app.limiter = limiter

    # Caching setup
    cache = Cache(app)

    @app.after_request
    def add_rate_limit_headers(response):
        """Add rate limit headers to API responses"""
        try:
            # Get current request limits
            current_limit = getattr(request, 'rate_limit', None)
            if current_limit:
                response.headers['X-RateLimit-Limit'] = str(current_limit.limit)
                response.headers['X-RateLimit-Remaining'] = str(max(0, current_limit.limit - current_limit.count))
                response.headers['X-RateLimit-Reset'] = str(int(current_limit.reset_time.timestamp()))
        except Exception:
            # Don't fail the request if header addition fails
            pass

        # Baseline transport/security headers
        response.headers.setdefault('X-Content-Type-Options', 'nosniff')
        response.headers.setdefault('X-Frame-Options', 'DENY')
        response.headers.setdefault('Referrer-Policy', 'strict-origin-when-cross-origin')
        response.headers.setdefault(
            'Permissions-Policy',
            'camera=(), microphone=(), geolocation=(), payment=()',
        )

        # Apply a strict CSP for API responses while leaving static HTML assets functional.
        if response.mimetype == 'application/json':
            response.headers.setdefault(
                'Content-Security-Policy',
                "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
            )
        else:
            response.headers.setdefault(
                'Content-Security-Policy',
                "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'; "
                "script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' https: wss:; frame-ancestors 'none'",
            )
        return response

    @app.errorhandler(429)
    def ratelimit_handler(e):
        request_id = getattr(g, 'request_id', 'unknown')
        user_tier = get_user_tier()

        logger.warning(f"[{request_id}] Rate limit exceeded for {user_tier} user: {request.endpoint}")

        # Customize message based on user tier
        if user_tier == 'free':
            message = 'Free tier limit reached. Upgrade to Premium for higher limits!'
            upgrade_url = 'https://storyweaver.com/premium'
        elif user_tier == 'premium':
            message = 'Premium limit reached. Upgrade to Family plan for even higher limits!'
            upgrade_url = 'https://storyweaver.com/family'
        else:
            message = 'Rate limit exceeded. Please try again later.'
            upgrade_url = None

        response_data = {
            'error': 'Rate limit exceeded',
            'message': message,
            'retry_after': getattr(e, 'description', None),
            'retry_after_seconds': int(getattr(e, 'retry_after', 0) or 0),
            'user_tier': user_tier
        }

        if upgrade_url:
            response_data['upgrade_url'] = upgrade_url

        return jsonify(response_data), 429

    # Logging setup for story engine (use different name to avoid shadowing global logger)
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    story_logger = logging.getLogger("story_engine")

    log_error = make_log_error(story_logger)
    filter_story_content = make_filter_story_content(story_logger)

    add_request_id = make_add_request_id(story_logger)
    log_response = make_log_response(story_logger, log_error)
    handle_error = make_handle_error(story_logger, is_production, log_error)

    app.before_request(add_request_id)
    app.after_request(log_response)
    app.register_error_handler(Exception, handle_error)

    # Initialize request logging (payload size, mode flags, latency)
    init_request_logging(app, logger)

    # Gemini setup
    GEMINI_MODEL = app.config.get("GEMINI_MODEL", "gemini-2.0-flash")
    api_key = None if testing_mode else app.config.get("GEMINI_API_KEY")
    gemini_client = None
    print(f"DEBUG: GEMINI_MODEL set to {GEMINI_MODEL}")
    # SECURITY: Don't log API keys, even partially masked
    print(f"DEBUG: GEMINI_API_KEY configured: {bool(api_key)}")
    if not api_key:
        logger.warning("GEMINI_API_KEY not set in Flask app config. Generation endpoints will use fallbacks.")
        model = None

    if api_key:
        try:
            from google import genai as genai_sdk  # Local import to avoid slow startup in tests
            logger.info("google-genai SDK imported successfully.")
        except Exception as e:
            logger.exception("Failed to import google-genai. Please ensure the library is installed: %s", e)
            genai_sdk = None

        if genai_sdk:
            try:
                gemini_client = genai_sdk.Client(api_key=api_key)
                logger.info("Gemini client created with API key.")
                # model variable maintained for API compatibility (unused in story_routes)
                model = gemini_client
                logger.info(f"Gemini client initialized for model '{GEMINI_MODEL}'.")
            except Exception as e:
                logger.exception("Failed to create Gemini client: %s", e)
                model = None
        else:
            model = None
            api_key = None

    # Initialize Stripe (configured via blueprint setup now)
    try:
        from backend.routes.stripe_routes import stripe_routes, init_stripe_api
        from backend.routes.webhook_handler import webhook_routes
    except ImportError:
        from routes.stripe_routes import stripe_routes, init_stripe_api
        from routes.webhook_handler import webhook_routes

    if not testing_mode:
        init_stripe_api(app)
        logger.info(f"Stripe Premium Price ID: {os.getenv('STRIPE_PRICE_ID_PREMIUM', 'NOT SET')}")
        logger.info(f"Stripe Family Price ID: {os.getenv('STRIPE_PRICE_ID_FAMILY', 'NOT SET')}")

    # Initialize image generator (prefer OpenRouter if available, fallback to Gemini)
    global image_generator
    try:
        openrouter_key = os.getenv("OPENROUTER_API_KEY") if not testing_mode else None
        if openrouter_key:
            try:
                from backend.openrouter_image_generator import OpenRouterImageGenerator
            except ImportError:
                from openrouter_image_generator import OpenRouterImageGenerator

            image_generator = OpenRouterImageGenerator(api_key=openrouter_key)
            logger.info("Image generator initialized with OpenRouter")
        elif api_key and not testing_mode:
            try:
                from backend.gemini_image_generator import GeminiImageGenerator
            except ImportError:
                from gemini_image_generator import GeminiImageGenerator

            image_generator = GeminiImageGenerator()
            logger.info("Image generator initialized with Gemini (fallback)")
        else:
            image_generator = None
            logger.warning("No image generator initialized (no OPENROUTER_API_KEY or GEMINI_API_KEY)")
    except Exception as e:
        logger.exception("Failed to initialize image generator: %s", e)
        image_generator = None

    print(f"=== Creating database tables ===")
    with app.app_context():
        db.create_all()
        # Ensure anonymous user exists for story generation
        try:
            anonymous_user = db.session.get(User, 'anonymous')
            if not anonymous_user:
                logger.info("Creating anonymous user for story generation...")
                anon = User(
                    id='anonymous',
                    username='anonymous',
                    email='anonymous@storyweaver.app'
                )
                anon.set_password(uuid.uuid4().hex)
                db.session.add(anon)
                db.session.commit()
                logger.info("Anonymous user created successfully")
            else:
                logger.info("Anonymous user already exists")
        except Exception as e:
            logger.error(f"Failed to create anonymous user: {e}")
            db.session.rollback()
    print(f"=== Database tables created ===")

    # JWT setup - SECURITY: Require proper secret in production
    jwt = JWTManager(app)
    app.config.setdefault('JWT_ACCESS_TOKEN_EXPIRES', timedelta(hours=1))
    app.config.setdefault('JWT_REFRESH_TOKEN_EXPIRES', timedelta(days=30))
    jwt_secret = app.config.get('JWT_SECRET_KEY') or os.getenv('JWT_SECRET_KEY')
    if not jwt_secret or jwt_secret == 'dev-secret-key':
        if os.getenv('FLASK_ENV') in ('prod', 'production'):
            raise ValueError("SECURITY ERROR: JWT_SECRET_KEY must be set in production!")
        logger.warning("Using dev JWT secret - NOT SAFE FOR PRODUCTION")
        jwt_secret = 'dev-secret-key'
    app.config['JWT_SECRET_KEY'] = jwt_secret

    # Database query monitoring
    from sqlalchemy import event
    from sqlalchemy.engine import Engine

    @event.listens_for(Engine, "before_cursor_execute")
    def receive_before_cursor_execute(conn, cursor, statement, params, context, executemany):
        context._query_start_time = time.time()

    @event.listens_for(Engine, "after_cursor_execute")
    def receive_after_cursor_execute(conn, cursor, statement, params, context, executemany):
        total = time.time() - context._query_start_time
        if total > 1.0:  # Log slow queries
            log_error(
                error_type='slow_database_query',
                message=f'Slow query took {total:.2f}s',
                details={
                    'query': statement[:200],  # First 200 chars
                    'duration': total
                }
            )

    try:
        from backend.analytics_routes import create_analytics_blueprint
        from backend.routes.achievement_routes import create_achievement_blueprint
        from backend.routes.subscription_routes import create_subscription_blueprint
        from backend.routes.user_routes import create_user_routes_blueprint
    except ImportError:
        from analytics_routes import create_analytics_blueprint
        from routes.achievement_routes import create_achievement_blueprint
        from routes.subscription_routes import create_subscription_blueprint
        from routes.user_routes import create_user_routes_blueprint

    print(f"=== Registering routes ===")
    if stripe_routes:
        app.register_blueprint(stripe_routes, url_prefix='/api/stripe')
    if webhook_routes:
        app.register_blueprint(webhook_routes, url_prefix='/api')
    analytics_bp = create_analytics_blueprint(limiter=limiter)
    app.register_blueprint(analytics_bp)
    achievement_bp = create_achievement_blueprint(limiter=limiter)
    app.register_blueprint(achievement_bp, url_prefix='/achievement')
    subscription_bp = create_subscription_blueprint(limiter=limiter)
    app.register_blueprint(subscription_bp)
    user_routes = create_user_routes_blueprint(limiter=limiter)
    app.register_blueprint(user_routes)

    try:
        from backend.routes.story_routes import create_story_blueprint
        from backend.routes.character_routes import create_character_blueprint
        from backend.routes.admin_routes import create_admin_blueprint
        from backend.routes.avatar_routes import avatar_bp
        from backend.routes.avatar_gallery_routes import avatar_gallery_bp
        from backend.routes.health_routes import create_health_blueprint
        from backend.routes.utility_routes import create_utility_blueprint
    except ImportError:
        from routes.story_routes import create_story_blueprint
        from routes.character_routes import create_character_blueprint
        from routes.admin_routes import create_admin_blueprint
        from routes.avatar_routes import avatar_bp
        from routes.avatar_gallery_routes import avatar_gallery_bp
        from routes.health_routes import create_health_blueprint
        from routes.utility_routes import create_utility_blueprint

    story_bp = create_story_blueprint(
        limiter=limiter,
        cache=cache,
        story_engine_instance=story_engine_instance,
        model=model,
        image_generator=image_generator,
        api_key=api_key,
        gemini_model=GEMINI_MODEL,
        log_error=log_error,
        filter_story_content=filter_story_content,
        get_tier_limits=get_tier_limits,
        track_cost=track_cost,
        is_production_fn=is_production,
        logger=logger,
    )
    character_bp = create_character_blueprint(limiter=limiter, logger=logger)
    admin_bp = create_admin_blueprint(logger=logger, limiter=limiter)
    health_bp = create_health_blueprint(logger=logger, api_key=api_key, app_version="1.0.2", gemini_model=GEMINI_MODEL)
    utility_bp = create_utility_blueprint(logger=logger, log_error=log_error, limiter=limiter)

    app.register_blueprint(story_bp)
    app.register_blueprint(character_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(health_bp)
    app.register_blueprint(utility_bp)
    app.register_blueprint(avatar_bp, url_prefix='/avatar')
    app.register_blueprint(avatar_gallery_bp, url_prefix='/avatar/gallery')

    @app.errorhandler(500)
    def internal_server_error(e):
        logger.error(f"Internal Server Error: {str(e)}")
        # In production, do not return the exception details
        if is_production():
            return jsonify({
                "error": "Internal Server Error",
                "message": "An unexpected error occurred. Please contact support."
            }), 500
        # In dev/test, typically okay to show more, or sanitize too.
        # Let's sanitize to be safe as per requirement "Ensure no stack traces... in production"
        return jsonify({
            "error": "Internal Server Error", 
            "message": str(e) # Only show message in dev
        }), 500

    print(f"=== All routes registered successfully ===")
    print(
        "=== Registered routes: "
        f"{sorted([{'path': rule.rule, 'methods': sorted(m for m in rule.methods if m not in {'HEAD', 'OPTIONS'})} for rule in app.url_map.iter_rules()], key=lambda r: (r['path'], tuple(r['methods'])))} ==="
    )
    return app

# Trigger reload
if __name__ == '__main__':
    app = create_app(os.getenv('FLASK_ENV') or 'production')
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 5000)))
