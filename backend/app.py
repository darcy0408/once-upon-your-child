import os
import uuid
import logging
import traceback
import json
from datetime import datetime
import time
import os
import requests
import base64
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

from .services import character_service, story_service
from .services.story_service import AdvancedStoryEngine
from .routes.stripe_routes import stripe_routes, init_stripe_api
from .routes.webhook_handler import webhook_routes
from .analytics_routes import analytics_bp
from .quality_service import StoryQualityService
from .cost_tracking import track_cost, get_cost_report
# from .repositories import character_repository
from .gemini_image_generator import GeminiImageGenerator
from .openrouter_image_generator import OpenRouterImageGenerator
# Route imports removed - routes defined directly in app.py

# Global image generator instance
image_generator = None
from flask_jwt_extended import JWTManager
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_caching import Cache

def is_production():
    return os.getenv('RAILWAY_ENVIRONMENT') == 'production'

def get_user_identifier():
    """Get user ID from request or fall back to IP address"""
    # Try to get user ID from various sources
    user_id = None

    # Check for user ID in headers (from frontend)
    user_id = request.headers.get('X-User-ID')

    # Check for user ID in session (if using sessions)
    if not user_id and hasattr(g, 'user_id'):
        user_id = g.user_id

    # Check for user ID in JWT token (if authenticated)
    if not user_id:
        try:
            from flask_jwt_extended import get_jwt_identity
            user_id = get_jwt_identity()
        except:
            pass

    # Fall back to IP address if no user ID found
    if user_id:
        return f"user:{user_id}"
    else:
        return f"ip:{get_remote_address()}"

def get_user_tier():
    """Get user subscription tier for rate limiting"""
    user_id = request.headers.get('X-User-ID') or getattr(g, 'user_id', None)

    if user_id:
        try:
            user = User.query.filter_by(id=user_id).first()
            if user:
                return user.subscription_tier or 'free'
        except:
            pass

    return 'free'  # Default to free tier

def get_tier_limits(operation='default'):
    """Get rate limits based on user tier"""
    tier = get_user_tier()

    # Base limits for different operations
    limits = {
        'default': {
            'free': "3/minute; 10/hour; 50/day",
            'premium': "10/minute; 100/hour",
            'family': "15/minute; 200/hour",
            'byok': None  # No limits for BYOK users
        },
        'expensive': {  # For image generation, etc.
            'free': "1/minute; 5/hour; 10/day",
            'premium': "3/minute; 20/hour",
            'family': "5/minute; 30/hour",
            'byok': None  # No limits for BYOK users
        }
    }

    limit = limits.get(operation, limits['default']).get(tier, limits['default']['free'])
    return limit

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

    INAPPROPRIATE_KEYWORDS = [
        'violence', 'weapon', 'death', 'kill', 'hurt', 'blood',
        'scary', 'monster', 'nightmare', 'attack', 'fight', 'gun',
        'knife', 'suicide', 'self-harm'
    ]

    def filter_story_content(story_text: str) -> tuple[str, bool]:
        """Detect potentially inappropriate keywords in story content."""
        if not story_text:
            return story_text, False

        lower_text = story_text.lower()
        had_issues = False
        for keyword in INAPPROPRIATE_KEYWORDS:
            if keyword in lower_text:
                had_issues = True
                logger.warning(f"Content filter triggered: {keyword} in story text")
        if had_issues:
            logger.warning(f"Flagged story content (first 200 chars): {story_text[:200]!r}")
        return story_text, had_issues

    # Structured logging helper
    def log_error(error_type, message, details=None):
        log_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'type': error_type,
            'message': message,
            'details': details or {}
        }
        logger.error(json.dumps(log_entry))

    @app.before_request
    def add_request_id():
        g.request_id = str(uuid.uuid4())[:8]
        g.start_time = time.time()
        logger.info(f"[{g.request_id}] {request.method} {request.path}")

    @app.after_request
    def log_response(response):
        # Ensure g.request_id exists even if an error occurred before before_request completed
        request_id = getattr(g, 'request_id', 'unknown')
        if hasattr(g, 'start_time'):
            duration = time.time() - g.start_time
            # Log slow requests (>5 seconds)
            if duration > 5.0:
                log_error(
                    error_type='slow_request',
                    message=f'Request took {duration:.2f}s',
                    details={
                        'method': request.method,
                        'path': request.path,
                        'duration': duration,
                        'status_code': response.status_code
                    }
                )
        # Log all requests with structured format
        log_entry = {
            'method': request.method,
            'path': request.path,
            'status': response.status_code,
            'duration_ms': round(duration * 1000, 2) if hasattr(g, 'start_time') else 0,
            'ip': request.remote_addr,
            'request_id': request_id
        }
        logger.info(json.dumps(log_entry))
        return response

    @app.errorhandler(Exception)
    def handle_error(error):
        request_id = getattr(g, 'request_id', 'unknown')
        log_error(
            error_type='unhandled_error',
            message=str(error),
            details={
                'request_id': request_id,
                'method': request.method,
                'path': request.path,
                'error_class': error.__class__.__name__
            }
        )
        logger.exception(f"[{request_id}] Unhandled error: {error}")

        if is_production():
            return jsonify({
                'error': 'Internal server error',
                'request_id': request_id
            }), 500
        return jsonify({
            'error': str(error),
            'request_id': request_id
        }), 500

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

    # Blueprints removed - routes defined directly in app.py
    app.register_blueprint(stripe_routes, url_prefix='/api/stripe')
    app.register_blueprint(webhook_routes, url_prefix='/api/webhooks')
    app.register_blueprint(analytics_bp)

    # Quality scoring endpoint
    @app.route('/quality/score-story', methods=['POST'])
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

        except ValueError as e:
            return jsonify({'error': 'Invalid age parameter'}), 400
        except Exception as e:
            log_error(
                error_type='quality_scoring_failed',
                message=str(e),
                details={'error_class': e.__class__.__name__}
            )
            return jsonify({'error': 'Quality scoring failed'}), 500

    # API Routes
    print(f"=== Registering routes ===")
    @app.route('/health', methods=['GET'])
    def health_check():
        health_status = {
            'status': 'ok',
            'timestamp': datetime.now().isoformat(),
            'version': '1.0.2',  # Add versioning
        }

        # Database check
        try:
            from sqlalchemy import text
            db.session.execute(text('SELECT 1'))
            health_status['database'] = 'ok'
        except Exception as e:
            health_status['database'] = 'error'
            health_status['database_error'] = str(e)
            health_status['status'] = 'degraded'

        # Gemini API check
        health_status['has_api_key'] = bool(os.getenv('GEMINI_API_KEY'))
        health_status['model'] = os.getenv('GEMINI_MODEL', 'not-set')

        # Stripe check
        health_status['stripe_configured'] = bool(os.getenv('STRIPE_API_KEY'))
        health_status['stripe_premium_price'] = bool(os.getenv('STRIPE_PRICE_ID_PREMIUM'))
        health_status['stripe_family_price'] = bool(os.getenv('STRIPE_PRICE_ID_FAMILY'))

        # Environment
        health_status['environment'] = os.getenv('RAILWAY_ENVIRONMENT', 'unknown')

        if health_status['status'] != 'ok':
            logger.warning(f"Health degraded: {health_status}")

        return jsonify(health_status), 200

    @app.route('/admin/run-db-optimization', methods=['POST'])
    def run_db_optimization():
        """Run database optimization indexes (one-time setup)"""
        try:
            from sqlalchemy import text

            # SQL statements from database_optimization.sql
            sql_statements = [
                "CREATE INDEX IF NOT EXISTS idx_stories_created_at ON stories(created_at DESC)",
                "CREATE INDEX IF NOT EXISTS idx_stories_user_id ON stories(user_id)",
                "CREATE INDEX IF NOT EXISTS idx_stories_theme ON stories(theme)",
                "CREATE INDEX IF NOT EXISTS idx_stories_user_created ON stories(user_id, created_at DESC)",
                "CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at)",
                "CREATE INDEX IF NOT EXISTS idx_users_subscription_tier ON users(subscription_tier)",
                "CREATE INDEX IF NOT EXISTS idx_users_tier_created ON users(subscription_tier, created_at)",
                "CREATE INDEX IF NOT EXISTS idx_stories_user_theme ON stories(user_id, theme)",
            ]

            created_indexes = []
            with db.engine.connect() as conn:
                for sql in sql_statements:
                    try:
                        conn.execute(text(sql))
                        conn.commit()
                        index_name = sql.split('idx_')[1].split(' ')[0] if 'idx_' in sql else 'unknown'
                        created_indexes.append(f"idx_{index_name}")
                        logger.info(f"✓ Created index: idx_{index_name}")
                    except Exception as e:
                        # Index might already exist - that's ok
                        logger.warning(f"Index creation warning: {str(e)}")

            return jsonify({
                'status': 'success',
                'message': 'Database optimization complete',
                'indexes_processed': len(sql_statements),
                'indexes': created_indexes
            }), 200

        except Exception as e:
            logger.exception("Failed to run database optimization")
            return jsonify({'error': str(e)}), 500

    @app.route('/admin/add-missing-columns', methods=['POST'])
    def add_missing_columns():
        """Add missing columns to database (migration fix)"""
        try:
            from sqlalchemy import text

            # Add missing columns
            sql_statements = [
                # Add stories_created_count column if it doesn't exist
                """
                DO $$
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                   WHERE table_name='user' AND column_name='stories_created_count') THEN
                        ALTER TABLE "user" ADD COLUMN stories_created_count INTEGER DEFAULT 0 NOT NULL;
                    END IF;
                END $$;
                """,
            ]

            applied_migrations = []
            with db.engine.connect() as conn:
                for sql in sql_statements:
                    try:
                        conn.execute(text(sql))
                        conn.commit()
                        applied_migrations.append("stories_created_count column")
                        logger.info(f"✓ Applied migration: stories_created_count")
                    except Exception as e:
                        logger.warning(f"Migration warning: {str(e)}")

            return jsonify({
                'status': 'success',
                'message': 'Database migrations complete',
                'migrations_applied': applied_migrations
            }), 200

        except Exception as e:
            logger.exception("Failed to run database migrations")
            return jsonify({'error': str(e)}), 500

    @app.route('/health/detailed', methods=['GET'])
    def detailed_health():
        health_status = {
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'checks': {}
        }

        # Database check
        try:
            from sqlalchemy import text
            db.session.execute(text('SELECT 1'))
            health_status['checks']['database'] = {
                'status': 'healthy'
            }
        except Exception as e:
            health_status['status'] = 'unhealthy'
            health_status['checks']['database'] = {
                'status': 'unhealthy',
                'error': str(e)
            }

        # Gemini API check
        try:
            # Test with minimal request - just check if configured
            health_status['checks']['gemini_api'] = {
                'status': 'healthy' if api_key else 'unhealthy',
                'configured': bool(api_key)
            }
        except Exception as e:
            health_status['status'] = 'degraded'
            health_status['checks']['gemini_api'] = {
                'status': 'unhealthy',
                'error': str(e)
            }

        # Memory check
        try:
            import psutil
            memory = psutil.virtual_memory()
            health_status['checks']['memory'] = {
                'status': 'healthy' if memory.percent < 90 else 'warning',
                'percent_used': memory.percent
            }
        except ImportError:
            # psutil not available
            health_status['checks']['memory'] = {
                'status': 'unknown',
                'note': 'psutil not installed'
            }

        status_code = 200 if health_status['status'] == 'healthy' else 503
        return jsonify(health_status), status_code

    @app.route('/health/database', methods=['GET'])
    def database_health():
        """Detailed database health check"""
        try:
            # Check connection pool
            pool = db.engine.pool
            return jsonify({
                'status': 'ok',
                'pool_size': pool.size(),
                'checked_in': pool.checkedin(),
                'checked_out': pool.checkedout(),
                'overflow': pool.overflow()
            })
        except Exception as e:
            return jsonify({
                'status': 'error',
                'error': str(e)
            }), 500
    


    @app.route('/debug-gemini', methods=['GET'])
    def debug_gemini():
        """Debug endpoint to test Gemini text generation"""
        api_key = os.getenv("GEMINI_API_KEY")
        model_name = os.getenv("GEMINI_MODEL", "models/gemini-2.5-flash")
        
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
                
            genai.configure(api_key=api_key)
            status["steps"].append("✅ GenAI Configured")
            
            # Step 2: Initialize Model
            model = genai.GenerativeModel(model_name)
            status["steps"].append(f"✅ Model initialized: {model_name}")
            
            # Step 3: Generate Content
            start_time = time.time()
            response = model.generate_content("Say 'Hello from Gemini!' if you can hear me.")
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
                available_models = []
                for m in genai.list_models():
                    if 'generateContent' in m.supported_generation_methods:
                        available_models.append(m.name)
                status["available_models"] = available_models
                status["steps"].append(f"ℹ️ Listed {len(available_models)} available models")
            except Exception as list_err:
                status["steps"].append(f"❌ Failed to list models: {str(list_err)}")

        return jsonify(status)

    @app.route('/debug-openrouter', methods=['GET'])
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

    @app.route("/get-story-themes", methods=["GET"])
    @cache.cached(timeout=3600)  # Cache for 1 hour
    def get_story_themes():
        return jsonify(["Adventure", "Friendship", "Magic", "Dragons", "Castles", "Unicorns", "Space", "Ocean"])

    @limiter.limit(lambda: get_tier_limits() or "1000/minute")  # BYOK users get high limit
    @app.route("/generate-story", methods=["POST"])
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
            print(f"!!! Using user key: {using_user_key}")

            # Structured error logging
            log_error(
                error_type='story_generation_failed',
                message=str(e),
                details={
                    'character_name': character,
                    'theme': theme,
                    'age': character_age,
                    'prompt_length': len(prompt),
                    'using_user_key': using_user_key,
                    'error_class': error_type,
                    'learning_to_read_mode': learning_to_read_mode,
                    'rhyme_time_mode': rhyme_time_mode
                }
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

            if not is_production():
                raw_text = (
                    "[TITLE: An Unexpected Adventure]\n"
                    "Once upon a time, a brave hero discovered that the greatest adventures come from "
                    "facing our fears with courage and kindness.\n"
                    f"[WISDOM GEM: {story_service.WisdomGems.get_wisdom(theme)}]")
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
            enable_illustrations(2, "Family tier bonus: 2 auto-illustrations")
        elif not fallback_used and subscription_tier == "premium":
            enable_illustrations(1, "Premium tier bonus: 1 auto-illustration")

        if not fallback_used and include_illustrations and not should_generate_illustrations:
            if subscription_tier in {"premium", "family"}:
                enable_illustrations(2 if subscription_tier == "family" else 1,
                                     "User requested illustrations (paid tier)")
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
                logger.error(f"Image generation error details: generator={type(generator).__name__}, error={str(e)}")
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
            try:
                for img in illustrations:
                    if 'image_url' in img and 'image_data' not in img:
                        img_url = img['image_url']
                        try:
                            if img_url.startswith('data:image/'):
                                # Extract base64 from data URI
                                if ';base64,' in img_url:
                                    img['image_data'] = img_url.split(';base64,')[1]
                            elif img_url.startswith('http'):
                                # Download image and convert to base64
                                logger.info(f"Downloading illustration from {img_url[:50]}...")
                                img_resp = requests.get(img_url, timeout=10)
                                if img_resp.status_code == 200:
                                    b64_data = base64.b64encode(img_resp.content).decode('utf-8')
                                    img['image_data'] = b64_data
                                    logger.info("Successfully converted image URL to base64 data")
                                else:
                                    logger.error(f"Failed to download image: {img_resp.status_code}")
                        except Exception as e:
                            logger.error(f"Error processing single illustration: {str(e)}")
            except Exception as e:
                logger.error(f"Error processing illustrations batch: {str(e)}")

            response_payload["illustrations"] = illustrations
            response_payload["illustration_count"] = len(illustrations)

        if fallback_used:
            response_payload["warning"] = "Story generation fell back to offline mode. Please check server logs or API key configuration."

        # Track API costs
        user_tier = subscription_tier
        if user_api_key:
            user_tier = 'byok'

        # Track story generation cost
        track_cost('story_generation', user_id or 'anonymous', user_tier)

        # Track illustration costs if any were generated
        if illustrations:
            illustration_cost = track_cost('image_generation', user_id or 'anonymous', user_tier)
            # Scale cost by number of illustrations
            total_illustration_cost = illustration_cost * len(illustrations)
            # Note: The track_cost function already handles the base cost, we just log the scaling
            if len(illustrations) > 1:
                logger.info(f"Additional illustration cost: ${(total_illustration_cost - illustration_cost):.6f} for {len(illustrations)-1} extra images")

        return jsonify(response_payload), 200

    @limiter.limit("5 per minute") # Rate limit for interactive story start
    @app.route("/generate-interactive-story", methods=["POST"])
    def generate_interactive_story_endpoint():
        logger.info(f"POST /generate-interactive-story called")
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
                model=model, # Pass the initialized model
                user_api_key=user_api_key # Allow BYOK
            )
            text, flagged = filter_story_content(interactive_story_segment.get("text", ""))
            interactive_story_segment["text"] = text
            if flagged:
                logger.warning("Interactive story opening flagged by content filter")

            return jsonify(interactive_story_segment), 200
        except Exception as e:
            log_error(
                error_type='interactive_story_generation_failed',
                message=str(e),
                details={
                    'character_name': character_name,
                    'theme': theme,
                    'age': character_age,
                    'error_class': e.__class__.__name__
                }
            )
            logger.exception("Interactive story generation failed")
            return jsonify({
                "error": str(e),
                "hint": "Interactive story generation failed on the backend."
            }), 500

    @limiter.limit("5 per minute") # Rate limit for continuing interactive stories
    @app.route("/continue-interactive-story", methods=["POST"])
    def continue_interactive_story_endpoint():
        logger.info(f"POST /continue-interactive-story called")
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
            # Assume story_service has a method for continuing interactive stories
            # You'll need to implement story_service.continue_interactive_story in services/story_service.py
            interactive_story_segment = story_engine_instance.continue_interactive_story(
                character_name=character_name,
                theme=theme,
                companion=companion,
                choice_text=choice_text,
                story_so_far=story_so_far,
                choices_made=choices_made,
                character_age=character_age,
                model=model, # Pass the initialized model
                user_api_key=user_api_key # Allow BYOK
            )
            text, flagged = filter_story_content(interactive_story_segment.get("text", ""))
            interactive_story_segment["text"] = text
            if flagged:
                logger.warning("Interactive continuation flagged by content filter")

            return jsonify(interactive_story_segment), 200
        except Exception as e:
            logger.exception("Continuing interactive story failed")
            return jsonify({
                "error": str(e),
                "hint": "Continuing interactive story failed on the backend."
            }), 500

    @app.route("/report-story", methods=["POST"])
    def report_story():
        """Allow users to report inappropriate content."""
        data = request.get_json(silent=True) or {}
        story_id = data.get("story_id") or data.get("id") or "unknown"
        reason = (data.get("reason") or "").strip() or "No reason provided"
        snippet = (data.get("story_preview") or "")[:200]

        logger.warning(
            f"⚠️ CONTENT REPORT - Story ID: {story_id}, Reason: {reason}, Preview: {snippet}"
        )

        return jsonify({
            "status": "reported",
            "message": "Thank you for your report"
        }), 200

    @limiter.limit(lambda: get_tier_limits('expensive') or "100/hour")  # BYOK users get high limit
    @app.route("/generate-illustrations", methods=["POST"])
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
                return jsonify({
                    "error": "Image generation temporarily unavailable",
                    "hint": "OpenRouter image service is currently unavailable. Please try again later.",
                    "illustrations": [],
                    "count": 0
                }), 200

            illustrations = generator.generate_story_illustration(
                scene_description=scene_description,
                character_name=character_name,
                style=style,
                num_images=num_images,
                age=age,
                therapeutic_focus=therapeutic_focus
            )

            if not illustrations:
                logger.warning(f"No illustrations generated for scene: {scene_description[:50]}...")
                
            # Transform illustrations to match frontend expectations (GeminiIllustrationService)
            # Frontend expects 'image_data' (raw base64) or 'image_url'.
            # OpenRouter generator returns 'image_url' which might be a full data URI.
            
            transformed_illustrations = []
            for img in illustrations:
                new_img = img.copy()
                image_url = img.get('image_url', '')
                
                # If it's a data URI, extract the raw base64 for 'image_data'
                if image_url.startswith('data:image'):
                    try:
                        # Split 'data:image/png;base64,.....'
                        base64_part = image_url.split(',', 1)[1]
                        new_img['image_data'] = base64_part
                    except IndexError:
                        pass
                elif image_url.startswith('http'):
                    # Download image and convert to base64
                    try:
                        logger.info(f"Downloading illustration from {image_url[:50]}...")
                        img_resp = requests.get(image_url, timeout=10)
                        if img_resp.status_code == 200:
                            b64_data = base64.b64encode(img_resp.content).decode('utf-8')
                            new_img['image_data'] = b64_data
                            logger.info("Successfully converted image URL to base64 data")
                        else:
                            logger.error(f"Failed to download image: {img_resp.status_code}")
                    except Exception as e:
                        logger.error(f"Error processing illustration image data: {str(e)}")
                
                # Ensure image_id is present (frontend expects it)
                if 'id' in img:
                    new_img['image_id'] = img['id']
                    
                # Ensure scene_description is present (frontend expects it)
                if 'prompt' in img:
                    new_img['scene_description'] = img['prompt']
                    
                transformed_illustrations.append(new_img)

            return jsonify({
                "illustrations": transformed_illustrations,
                "count": len(transformed_illustrations),
                "used_user_key": using_user_key,
                "debug_info": {
                    "generator_type": type(generator).__name__ if generator else "None",
                    "scene_length": len(scene_description)
                }
            }), 200

        except Exception as e:
            logger.exception("Illustration generation failed")
            return jsonify({
                "error": str(e),
                "hint": "Image generation failed. Check your API key quota or try again later."
            }), 500

    @limiter.limit("10 per hour")
    @app.route("/generate-coloring-pages", methods=["POST"])
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
                    return jsonify({
                        "error": "Invalid or unavailable image API key",
                        "hint": str(e)
                    }), 400
            elif image_generator is not None:
                generator = image_generator
            else:
                # Graceful fallback when image generation is unavailable (no key/model).
                return jsonify({
                    "coloring_pages": [],
                    "count": 0,
                    "warning": "Image generation unavailable; configure GEMINI_API_KEY or provide user_api_key."
                }), 200

            coloring_pages = generator.generate_coloring_page(
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
            logger.exception("Coloring page generation failed")
            return jsonify({
                "error": "Failed to generate coloring pages",
                "hint": str(e)
            }), 500

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
        password = data.get('password')

        user = User.query.filter_by(username=username).first()
        if user and user.check_password(password):
            from flask_jwt_extended import create_access_token
            token = create_access_token(identity=user.id)
            return jsonify({'token': token}), 200

        return jsonify({'message': 'Invalid credentials'}), 401

    @app.route("/users/<string:user_id>/feature-unlocks", methods=["GET"])
    def get_feature_unlocks(user_id: str):
        """Get feature unlock status for a user."""
        try:
            user = User.query.filter_by(id=user_id).first()
            if not user:
                return jsonify({'error': 'User not found'}), 404

            stories_created = user.stories_created_count

            # Calculate unlock status
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

    @app.route("/users/<string:user_id>/story-created", methods=["POST"])
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



    print(f"=== All routes registered successfully ===")
    print(f"=== Registered routes: {[rule.rule for rule in app.url_map.iter_rules()]} ===")
    return app

# Create the app instance for Gunicorn
app = create_app(os.getenv('FLASK_CONFIG') or 'default')
