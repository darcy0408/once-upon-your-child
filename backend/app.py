import os
import uuid
import logging
import traceback
from datetime import datetime
import time
import google.generativeai as genai
from flask import Flask, request, jsonify, g
from flask_cors import CORS

from .config import config, config_by_name
from .database import db
# Import models in dependency order (Story and Character first, then User which references them)
from .models.story import Story
from .models.character import Character
from .models.achievement import UserAchievement, AchievementStats
from .models.user import User

from .services.story_service import AdvancedStoryEngine
from .routes.stripe_routes import stripe_routes, init_stripe_api
from .routes.webhook_handler import webhook_routes
from .analytics_routes import analytics_bp
from .quality_service import StoryQualityService
from .cost_tracking import track_cost
# from .repositories import character_repository
from .gemini_image_generator import GeminiImageGenerator
from .openrouter_image_generator import OpenRouterImageGenerator
from .utils.app_helpers import (
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

from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_caching import Cache

# Global image generator instance
image_generator = None

def create_app(config_name):
    print(f"=== Creating Flask app with config: {config_name} ===")
    # Image generation fix deployed - 2024-12-01
    app = Flask(__name__)
    
    if config_name == 'testing':
        app.config.from_object(config_by_name['dev'])
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        app.config.pop('SQLALCHEMY_ENGINE_OPTIONS', None)
    else:
        app.config.from_object(config_by_name[config_name])

    print(f"=== Config loaded, initializing database ===")
    db.init_app(app)
    print(f"=== Database initialized ===")

    # Initialize AdvancedStoryEngine
    story_engine_instance = AdvancedStoryEngine()

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
        key_func=get_user_identifier,
        default_limits=["200 per day", "50 per hour"],
        storage_uri="memory://"
    )

    # Caching setup
    cache = Cache(app, config={'CACHE_TYPE': 'simple'})

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
            'retry_after': e.description,
            'user_tier': user_tier
        }

        if upgrade_url:
            response_data['upgrade_url'] = upgrade_url

        return jsonify(response_data), 429

    # Logging setup
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger("story_engine")

    log_error = make_log_error(logger)
    filter_story_content = make_filter_story_content(logger)

    add_request_id = make_add_request_id(logger)
    log_response = make_log_response(logger, log_error)
    handle_error = make_handle_error(logger, is_production, log_error)

    app.before_request(add_request_id)
    app.after_request(log_response)
    app.register_error_handler(Exception, handle_error)

    # Gemini setup
    api_key = app.config["GEMINI_API_KEY"]
    print(f"DEBUG: api_key from config = {api_key}")
    print(f"DEBUG: bool(api_key) = {bool(api_key)}")
    if not api_key:
        logger.warning("GEMINI_API_KEY not set. Generation endpoints will use fallbacks.")
    else:
        genai.configure(api_key=api_key)
        print("DEBUG: Gemini configured with API key")

    GEMINI_MODEL = "models/gemini-2.5-flash"
    try:
        model = genai.GenerativeModel(GEMINI_MODEL) if api_key else None
    except Exception as e:
        logger.exception("Failed to initialize Gemini model: %s", e)
        model = None

    # Initialize Stripe (configured via blueprint setup now)
    init_stripe_api(app)
    logger.info(f"✓ Stripe Premium Price ID: {os.getenv('STRIPE_PRICE_ID_PREMIUM', 'NOT SET')}")
    logger.info(f"✓ Stripe Family Price ID: {os.getenv('STRIPE_PRICE_ID_FAMILY', 'NOT SET')}")

    # Initialize image generator (prefer low-cost OpenRouter SDXL if available)
    global image_generator
    try:
        openrouter_key = os.getenv("OPENROUTER_API_KEY")
        if openrouter_key:
            image_generator = OpenRouterImageGenerator(api_key=openrouter_key)
            logger.info("Image generator initialized with OpenRouter (cost-optimized)")
        elif api_key:
            image_generator = GeminiImageGenerator()
            logger.info("Image generator initialized with Gemini")
        else:
            image_generator = None
            logger.warning("No image generator initialized (no OPENROUTER_API_KEY or GEMINI_API_KEY)")
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

    print(f"=== Registering routes ===")
    app.register_blueprint(stripe_routes, url_prefix='/api/stripe')
    app.register_blueprint(webhook_routes, url_prefix='/api/webhooks')
    app.register_blueprint(analytics_bp)

    from .routes.story_routes import create_story_blueprint
    from .routes.character_routes import create_character_blueprint
    from .routes.admin_routes import create_admin_blueprint
    from .routes.health_routes import create_health_blueprint
    from .routes.utility_routes import create_utility_blueprint

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
    admin_bp = create_admin_blueprint(logger=logger)
    health_bp = create_health_blueprint(logger=logger, api_key=api_key, app_version="1.0.2", gemini_model=GEMINI_MODEL)
    utility_bp = create_utility_blueprint(logger=logger, log_error=log_error)

    app.register_blueprint(story_bp)
    app.register_blueprint(character_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(health_bp)
    app.register_blueprint(utility_bp)

    print(f"=== All routes registered successfully ===")
    print(f"=== Registered routes: {[rule.rule for rule in app.url_map.iter_rules()]} ===")
    return app

# Create the app instance for Gunicorn
app = create_app(os.getenv('FLASK_CONFIG') or 'default')
