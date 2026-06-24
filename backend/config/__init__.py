import logging
import os
import re
from datetime import timedelta

from dotenv import load_dotenv

logger = logging.getLogger(__name__)

# Load environment variables from .env file ONLY if it exists
# In Railway/production, environment variables are set directly in the platform
dotenv_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
if os.path.exists(dotenv_path):
    logger.debug(f"Loading .env from: {dotenv_path}")
    # Preserve FLASK_ENV if already set (e.g., by pytest conftest)
    preserved_flask_env = os.environ.get("FLASK_ENV")
    load_dotenv(dotenv_path=dotenv_path, override=True)
    if preserved_flask_env:
        os.environ["FLASK_ENV"] = preserved_flask_env
    # SECURITY: Don't log API keys, even partially masked
    logger.debug(f"GEMINI_API_KEY loaded: {bool(os.environ.get('GEMINI_API_KEY'))}")
else:
    logger.info(
        f"No .env file found at {dotenv_path}, using system environment variables"
    )
    # SECURITY: Don't log API keys, even partially masked
    logger.debug(f"GEMINI_API_KEY present: {bool(os.environ.get('GEMINI_API_KEY'))}")

# Use gemini-2.5-flash as default if not set in environment.
if not os.environ.get("GEMINI_MODEL"):
    os.environ["GEMINI_MODEL"] = "gemini-2.5-flash"
logger.debug(f"DEFAULT GEMINI_MODEL = {os.environ.get('GEMINI_MODEL')}")

# Free-tier text generation uses the cheaper flash-lite model (~6x cheaper on
# input). Paid/BYOK tiers stay on the full GEMINI_MODEL. Overridable via env.
if not os.environ.get("GEMINI_MODEL_FREE"):
    os.environ["GEMINI_MODEL_FREE"] = "gemini-2.5-flash-lite"
logger.debug(f"DEFAULT GEMINI_MODEL_FREE = {os.environ.get('GEMINI_MODEL_FREE')}")


def _get_required_secret(key_name, allow_dev_fallback=True):
    """
    Get a required secret from environment variables.
    In production, raises error if not set. In dev, allows fallback with warning.
    """
    value = os.environ.get(key_name)
    if value:
        return value

    env = os.environ.get("FLASK_ENV", "development")
    is_production = env in ("prod", "production")

    if is_production:
        raise ValueError(
            f"SECURITY ERROR: {key_name} must be set in production environment!"
        )

    if allow_dev_fallback:
        logger.warning(
            f"{key_name} not set - using dev fallback. NOT SAFE FOR PRODUCTION!"
        )
        return f"dev-{key_name.lower()}-fallback"

    raise ValueError(f"{key_name} is required but not set")


def _as_bool(name: str, default: bool = False) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return str(value).strip().lower() in ("1", "true", "yes", "on")


class Config:
    """Base configuration."""

    # SECRET_KEY is required in production - no silent fallback
    SECRET_KEY = _get_required_secret("SECRET_KEY")
    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "")

    # JWT token lifetimes (S-07). Set on the config class so they are applied
    # by app.config.from_object() BEFORE JWTManager() is constructed — the
    # prior post-init app.config.setdefault() was order-fragile. Access tokens
    # are short-lived (1h) so a stolen token has a small window; clients
    # refresh via /auth/refresh. Refresh tokens stay long-lived (30d).
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)

    # Mock Testing Mode - Use mock endpoints instead of real API calls
    MOCK_TESTING_MODE = os.environ.get("MOCK_TESTING_MODE", "false").lower() in [
        "true",
        "1",
        "yes",
    ]

    # Fix Railway's postgres:// to postgresql:// for SQLAlchemy 2.0+
    database_url = os.environ.get("DATABASE_URL")

    # If no DATABASE_URL, use SQLite (works for Railway deployment without Postgres)
    if not database_url or database_url.strip() == "":
        database_url = "sqlite:///app.db"
        SQLALCHEMY_ENGINE_OPTIONS = {}  # SQLite doesn't need pooling
        logger.info("Using SQLite database (no DATABASE_URL provided)")
    else:
        if database_url.startswith("postgres://"):
            database_url = database_url.replace("postgres://", "postgresql://", 1)
        # Database connection pooling for PostgreSQL.
        # Each process opens up to pool_size + max_overflow connections (15
        # here). Multiple processes share the database — 2 gunicorn workers
        # plus the Celery worker and celery-beat — so the per-process total
        # must stay well under Postgres's ~100-connection default limit.
        SQLALCHEMY_ENGINE_OPTIONS = {
            "pool_size": 5,
            "pool_recycle": 3600,
            "pool_pre_ping": True,
            "max_overflow": 10,
            "pool_timeout": 30,
        }
        logger.info(f"Using PostgreSQL database: {database_url[:30]}...")

    SQLALCHEMY_DATABASE_URI = database_url
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_SORT_KEYS = False

    # Caching
    CACHE_TYPE = "simple"

    # API Configuration
    GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
    GEMINI_MODEL = os.environ.get("GEMINI_MODEL") or "gemini-2.5-flash"
    # Free-tier model: cheaper flash-lite. Paid/BYOK tiers use GEMINI_MODEL.
    GEMINI_MODEL_FREE = os.environ.get("GEMINI_MODEL_FREE") or "gemini-2.5-flash-lite"

    # MT-171 Phase 1: provider switch for story-text generation.
    # Values:
    #   'gemini'     — legacy behavior: Gemini -> OpenRouter -> static fallback.
    #   'openrouter' — target:          OpenRouter -> static fallback (skip Gemini entirely).
    #   'claude'     — MT-248 launch-gate: Claude (direct Anthropic) -> static (skip Gemini).
    #   'openai'     — MT-248 launch-gate: OpenAI (direct, GPT-5 mini) -> static (skip Gemini).
    #   'tiered'     — MT-248 split: free -> OpenAI, paid -> Claude, cross-fallback -> static.
    #   'auto'       — rollback-safe:   OpenRouter -> Gemini -> static fallback.
    # Defaults to 'openai' (the live production provider). Gemini's API terms
    # forbid serving under-18 apps, so a missing/cleared env var must NOT silently
    # route children's story text to Gemini. Set STORY_GEN_PROVIDER explicitly to
    # override (see audit/MT-171-OPENROUTER-MIGRATION-BRIEF.md, MT-248, MT-137).
    STORY_GEN_PROVIDER = (
        (os.environ.get("STORY_GEN_PROVIDER") or "openai").strip().lower()
    )

    # Stripe
    STRIPE_API_KEY = os.environ.get("STRIPE_SECRET_KEY") or os.environ.get(
        "STRIPE_API_KEY"
    )
    STRIPE_WEBHOOK_SECRET = os.environ.get("STRIPE_WEBHOOK_SECRET")

    # Celery Configuration (Celery 5.x+)
    # Prefer explicit CELERY_* vars, then REDIS_URL, then local in-memory fallback.
    CELERY_BROKER_URL = (
        os.environ.get("CELERY_BROKER_URL")
        or os.environ.get("REDIS_URL")
        or "memory://"
    )
    CELERY_RESULT_BACKEND = (
        os.environ.get("CELERY_RESULT_BACKEND")
        or os.environ.get("REDIS_URL")
        or "cache+memory://"
    )
    CELERY_TASK_ALWAYS_EAGER = _as_bool("CELERY_TASK_ALWAYS_EAGER", False)
    CELERY_TASK_EAGER_PROPAGATES = _as_bool(
        "CELERY_TASK_EAGER_PROPAGATES",
        CELERY_TASK_ALWAYS_EAGER,
    )
    CELERY_TASK_STORE_EAGER_RESULT = _as_bool(
        "CELERY_TASK_STORE_EAGER_RESULT",
        CELERY_TASK_ALWAYS_EAGER,
    )

    # CORS - Build allowed origins dynamically
    @staticmethod
    def get_allowed_origins():
        """Get allowed CORS origins based on environment"""
        base_origins = [
            # SECURITY: Do NOT use "https://*.netlify.app" — it allows any
            # Netlify project to make authenticated cross-origin requests.
            # For preview deploys, set PREVIEW_DEPLOY_URL in the environment.
            # Customer-facing custom domain (the canonical production frontend,
            # served by Cloudflare Pages).
            "https://onceuponyourchild.app",
            "https://www.onceuponyourchild.app",
            # Cloudflare Pages production deploy (the custom domain points here).
            "https://once-upon-your-child.pages.dev",
        ]

        # Allow a specific preview or alternate deploy URL via env var.
        # Accepts Netlify (https://*.netlify.app), Railway
        # (https://*.up.railway.app), and Cloudflare Pages
        # (https://*.pages.dev) origins so future re-deploys / preview builds
        # only need an env-var update rather than a code change.
        preview_url = os.environ.get("PREVIEW_DEPLOY_URL")
        if (
            preview_url
            and preview_url.startswith("https://")
            and (
                "netlify.app" in preview_url
                or "up.railway.app" in preview_url
                or "pages.dev" in preview_url
            )
        ):
            base_origins.append(preview_url)

        # Add Railway frontend URL if available (takes precedence / replaces hardcoded URL
        # when the Railway service URL changes without requiring a new deploy).
        railway_frontend = os.environ.get("RAILWAY_FRONTEND_URL")
        is_development = os.environ.get("FLASK_ENV", "production") in [
            "dev",
            "development",
        ]
        if railway_frontend:
            base_origins.append(railway_frontend)
            # SECURITY: Only allow the insecure http:// downgrade of the frontend
            # origin in development. In production it would let a network attacker
            # serve an http:// page that passes the CORS allowlist.
            if is_development:
                base_origins.append(railway_frontend.replace("https://", "http://"))

        # Add Railway static outbound URL if available
        railway_static_url = os.environ.get("RAILWAY_STATIC_URL")
        if railway_static_url:
            base_origins.append(f"https://{railway_static_url}")

        # Add localhost origins only in development
        # SECURITY: Never use "*" wildcard - use regex patterns instead
        # SECURITY: Localhost regex patterns ONLY in dev to prevent production CORS bypass
        if os.environ.get("FLASK_ENV", "production") in ["dev", "development"]:
            # Allow any port on localhost/127.0.0.1 (Flutter run -d chrome uses random ports)
            base_origins.append(re.compile(r"^http://localhost:\d+$"))
            base_origins.append(re.compile(r"^http://127\.0\.0\.1:\d+$"))
            base_origins.extend(
                [
                    "http://localhost:8080",
                    "http://127.0.0.1:8080",
                    "http://localhost:3000",
                    "http://127.0.0.1:3000",
                    "http://localhost:3001",
                    "http://127.0.0.1:3001",
                    "http://localhost:3002",
                    "http://127.0.0.1:3002",
                    "http://localhost:3003",
                    "http://127.0.0.1:3003",
                    "http://localhost:5000",
                    "http://127.0.0.1:5000",
                    "http://10.0.2.2:8080",
                    "http://10.0.2.2:5000",
                ]
            )

        return base_origins

    ALLOWED_ORIGINS = get_allowed_origins.__func__()


class DevelopmentConfig(Config):
    """Development configuration."""

    DEBUG = True
    basedir = os.path.abspath(os.path.dirname(__file__))
    SQLALCHEMY_DATABASE_URI = f"sqlite:///{os.path.join(basedir, 'characters.db')}"
    GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    # Rate limiting should be enabled outside tests by default.
    RATELIMIT_ENABLED = _as_bool("RATELIMIT_ENABLED", False)


class ProductionConfig(Config):
    """Production configuration."""

    DEBUG = False
    # Explicitly enable rate limiting in production.
    RATELIMIT_ENABLED = True


class TestingConfig(Config):
    """Testing configuration."""

    TESTING = True
    DEBUG = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    # Disable rate limiting in tests
    RATELIMIT_ENABLED = False
    # Match conftest.py
    JWT_SECRET_KEY = "dev-secret-key"
    # Use NullCache in tests to avoid Flask-Caching/cachelib serialization bugs
    # (SimpleCache calls cachelib.serializers which fails on Flask Response objects)
    CACHE_TYPE = "NullCache"
    # Ensure Celery is eager in tests
    CELERY_TASK_ALWAYS_EAGER = True
    CELERY_TASK_EAGER_PROPAGATES = True
    CELERY_TASK_STORE_EAGER_RESULT = True
    # Tests run in eager mode unless explicitly overridden.
    CELERY_TASK_ALWAYS_EAGER = _as_bool("CELERY_TASK_ALWAYS_EAGER", True)
    CELERY_TASK_EAGER_PROPAGATES = _as_bool("CELERY_TASK_EAGER_PROPAGATES", True)
    CELERY_TASK_STORE_EAGER_RESULT = _as_bool("CELERY_TASK_STORE_EAGER_RESULT", True)


config_by_name = {
    "dev": DevelopmentConfig,
    "development": DevelopmentConfig,
    "prod": ProductionConfig,
    "production": ProductionConfig,
    "testing": TestingConfig,
    "default": ProductionConfig,
}

# Get config key from environment
key = os.environ.get("FLASK_ENV", "prod")
config = config_by_name[key]
