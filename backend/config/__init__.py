import os
import re
from dotenv import load_dotenv

# Load environment variables from .env file ONLY if it exists
# In Railway/production, environment variables are set directly in the platform
dotenv_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
if os.path.exists(dotenv_path):
    print(f"Loading .env from: {dotenv_path}")
    # Preserve FLASK_ENV if already set (e.g., by pytest conftest)
    preserved_flask_env = os.environ.get('FLASK_ENV')
    load_dotenv(dotenv_path=dotenv_path, override=True)
    if preserved_flask_env:
        os.environ['FLASK_ENV'] = preserved_flask_env
    # SECURITY: Don't log API keys, even partially masked
    print(f"GEMINI_API_KEY loaded: {bool(os.environ.get('GEMINI_API_KEY'))}")
else:
    print(f"No .env file found at {dotenv_path}, using system environment variables")
    # SECURITY: Don't log API keys, even partially masked
    print(f"GEMINI_API_KEY present: {bool(os.environ.get('GEMINI_API_KEY'))}")

# FORCE gemini-2.0-flash to fix persistent reversion issue
os.environ['GEMINI_MODEL'] = 'gemini-2.0-flash'
print(f"FORCED GEMINI_MODEL = {os.environ.get('GEMINI_MODEL')}")

def _get_required_secret(key_name, allow_dev_fallback=True):
    """
    Get a required secret from environment variables.
    In production, raises error if not set. In dev, allows fallback with warning.
    """
    value = os.environ.get(key_name)
    if value:
        return value

    env = os.environ.get('FLASK_ENV', 'development')
    is_production = env in ('prod', 'production')

    if is_production:
        raise ValueError(f"SECURITY ERROR: {key_name} must be set in production environment!")

    if allow_dev_fallback:
        print(f"WARNING: {key_name} not set - using dev fallback. NOT SAFE FOR PRODUCTION!")
        return f'dev-{key_name.lower()}-fallback'

    raise ValueError(f"{key_name} is required but not set")


class Config:
    """Base configuration."""
    # SECRET_KEY is required in production - no silent fallback
    SECRET_KEY = _get_required_secret('SECRET_KEY')

    # Mock Testing Mode - Use mock endpoints instead of real API calls
    MOCK_TESTING_MODE = os.environ.get('MOCK_TESTING_MODE', 'false').lower() in ['true', '1', 'yes']

    # Fix Railway's postgres:// to postgresql:// for SQLAlchemy 2.0+
    database_url = os.environ.get('DATABASE_URL')

    # If no DATABASE_URL, use SQLite (works for Railway deployment without Postgres)
    if not database_url or database_url.strip() == '':
        database_url = 'sqlite:///app.db'
        SQLALCHEMY_ENGINE_OPTIONS = {}  # SQLite doesn't need pooling
        print("Using SQLite database (no DATABASE_URL provided)")
    else:
        if database_url.startswith('postgres://'):
            database_url = database_url.replace('postgres://', 'postgresql://', 1)
        # Database connection pooling for PostgreSQL
        SQLALCHEMY_ENGINE_OPTIONS = {
            'pool_size': 10,
            'pool_recycle': 3600,
            'pool_pre_ping': True,
            'max_overflow': 20,
            'pool_timeout': 30,
        }
        print(f"Using PostgreSQL database: {database_url[:30]}...")

    SQLALCHEMY_DATABASE_URI = database_url
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_SORT_KEYS = False

    # API Configuration
    GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
    GEMINI_MODEL = os.environ.get('GEMINI_MODEL') or 'gemini-2.0-flash-exp'

    # Celery Configuration (NEW FORMAT - Celery 5.x+)
    # Fallback to in-memory (Dev/Prod without Redis) to avoid connection errors.
    CELERY_BROKER_URL = 'memory://'
    CELERY_RESULT_BACKEND = 'cache+memory://'

    # Run tasks synchronously for now (simplifies deployment without separate worker)
    CELERY_TASK_ALWAYS_EAGER = True
    CELERY_TASK_EAGER_PROPAGATES = True
    CELERY_TASK_STORE_EAGER_RESULT = True  # Required for polling to work in eager mode

    # CORS - Build allowed origins dynamically
    @staticmethod
    def get_allowed_origins():
        """Get allowed CORS origins based on environment"""
        base_origins = [
            "https://story-weaver-app.netlify.app",
            "https://*.netlify.app",  # Allow Netlify preview deploys
        ]

        # Always allow localhost dynamic ports (fixes CORS for Flutter run -d chrome random ports)
        # Using regex to match any port on localhost or 127.0.0.1
        base_origins.append(re.compile(r"^http://localhost:\d+$"))
        base_origins.append(re.compile(r"^http://127\.0\.0\.1:\d+$"))

        # Add Railway frontend URL if available
        railway_frontend = os.environ.get('RAILWAY_FRONTEND_URL')
        if railway_frontend:
            base_origins.append(railway_frontend)
            base_origins.append(railway_frontend.replace('https://', 'http://'))

        # Add Railway static outbound URL if available
        railway_static_url = os.environ.get('RAILWAY_STATIC_URL')
        if railway_static_url:
            base_origins.append(f"https://{railway_static_url}")

        # Add localhost origins only in development
        # SECURITY: Never use "*" wildcard - use regex patterns instead
        if os.environ.get('FLASK_ENV', 'production') in ['dev', 'development']:
            base_origins.extend([
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
                # Regex patterns handle random Flutter web ports securely
                # No wildcard "*" - that would allow any origin including malicious sites
            ])

        return base_origins

    ALLOWED_ORIGINS = get_allowed_origins.__func__()

class DevelopmentConfig(Config):
    """Development configuration."""
    DEBUG = True
    basedir = os.path.abspath(os.path.dirname(__file__))
    SQLALCHEMY_DATABASE_URI = f"sqlite:///{os.path.join(basedir, 'characters.db')}"
    # Explicitly force latest free experimental model
    GEMINI_MODEL = 'gemini-2.0-flash-exp'

class ProductionConfig(Config):
    """Production configuration."""
    DEBUG = False

class TestingConfig(Config):
    """Testing configuration."""
    TESTING = True
    DEBUG = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    # Disable rate limiting in tests
    RATELIMIT_ENABLED = False
    # Disable caching in tests to avoid serialization issues
    CACHE_TYPE = 'null'

config_by_name = {
    'dev': DevelopmentConfig,
    'development': DevelopmentConfig,
    'prod': ProductionConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': ProductionConfig
}

# Get config key from environment
key = os.environ.get("FLASK_ENV", "prod")
config = config_by_name[key]
