import os
import re
from dotenv import load_dotenv

# Load environment variables from .env file ONLY if it exists
# In Railway/production, environment variables are set directly in the platform
dotenv_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
if os.path.exists(dotenv_path):
    print(f"Loading .env from: {dotenv_path}")
    load_dotenv(dotenv_path=dotenv_path, override=True)
    loaded_key = os.environ.get('GEMINI_API_KEY')
    print(f"GEMINI_API_KEY loaded: {bool(loaded_key)}")
    if loaded_key:
        print(f"Masked GEMINI_API_KEY: {loaded_key[:4]}...{loaded_key[-4:]}")
else:
    print(f"No .env file found at {dotenv_path}, using system environment variables")
    system_key = os.environ.get('GEMINI_API_KEY')
    print(f"GEMINI_API_KEY present: {bool(system_key)}")
    if system_key:
        print(f"Masked GEMINI_API_KEY: {system_key[:4]}...{system_key[-4:]}")

# FORCE gemini-2.0-flash-exp to fix persistent reversion issue
os.environ['GEMINI_MODEL'] = 'gemini-2.0-flash-exp'
print(f"FORCED GEMINI_MODEL = {os.environ.get('GEMINI_MODEL')}")

class Config:
    """Base configuration."""
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key'

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
    # If REDIS_URL is present (Production with Redis), use it.
    # Otherwise fallback to in-memory (Dev/Prod without Redis) to avoid connection errors.
    if os.environ.get('REDIS_URL'):
        broker_url = os.environ.get('REDIS_URL')
        result_backend = os.environ.get('REDIS_URL')
    else:
        broker_url = 'memory://'
        result_backend = 'cache+memory://'

    # Run tasks synchronously for now (simplifies deployment without separate worker)
    task_always_eager = True
    task_eager_propagates = True
    task_store_eager_result = True  # Required for polling to work in eager mode

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
        if os.environ.get('FLASK_ENV', 'development') in ['dev', 'development']:
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
                "http://127.0.0.1:5000",
                "http://10.0.2.2:8080",
                "http://10.0.2.2:5000",
                "*"  # Allow all origins in dev to support random Flutter web ports
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
