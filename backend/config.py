import os
from dotenv import load_dotenv

# Load environment variables from .env file ONLY if it exists
# In Railway/production, environment variables are set directly in the platform
dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
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

class Config:
    """Base configuration."""
    SECRET_KEY = os.environ.get('SECRET_KEY', 'a_secret_key')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_SORT_KEYS = False
    
    # Gemini API
    GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', '')
    GEMINI_MODEL = os.getenv('GEMINI_MODEL', 'gemini-1.5-flash')
    
    # Celery Configuration - Run tasks synchronously in development (no Redis needed)
    CELERY_TASK_ALWAYS_EAGER = True
    CELERY_TASK_EAGER_PROPAGATES = True
    
    # CORS - Build allowed origins dynamically
    @staticmethod
    def get_allowed_origins():
        """Get allowed CORS origins based on environment"""
        base_origins = [
            "https://story-weaver-app.netlify.app",
            "https://*.netlify.app",  # Allow Netlify preview deploys
        ]

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
        if os.environ.get('FLASK_ENV') in ['dev', 'development']:
            base_origins.extend([
                "http://localhost:8080",
                "http://127.0.0.1:8080",
                "http://localhost:3000",
                "http://127.0.0.1:3000",
                "http://localhost:5000",
                "http://127.0.0.1:5000",
                "http://10.0.2.2:8080",
                "http://10.0.2.2:5000",
            ])

        return base_origins

    ALLOWED_ORIGINS = get_allowed_origins.__func__()

class DevelopmentConfig(Config):
    """Development configuration."""
    DEBUG = True
    basedir = os.path.abspath(os.path.dirname(__file__))
    SQLALCHEMY_DATABASE_URI = f"sqlite:///{os.path.join(basedir, 'characters.db')}"

class ProductionConfig(Config):
    """Production configuration."""
    DEBUG = False
    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL")

class TestingConfig(Config):
    """Testing configuration."""
    TESTING = True
    DEBUG = True
    basedir = os.path.abspath(os.path.dirname(__file__))
    SQLALCHEMY_DATABASE_URI = f"sqlite:///:memory:"
    # Disable rate limiting in tests
    RATELIMIT_ENABLED = False

config_by_name = dict(
    dev=DevelopmentConfig,
    development=DevelopmentConfig,
    prod=ProductionConfig,
    production=ProductionConfig,
    default=ProductionConfig,
    testing=TestingConfig
)

key = os.environ.get("FLASK_ENV", "prod")
config = config_by_name[key]
