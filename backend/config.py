
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv(override=True)

class Config:
    """Base configuration."""
    SECRET_KEY = os.environ.get('SECRET_KEY', 'a_secret_key')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_SORT_KEYS = False
    
    # Gemini API
    GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
    GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-1.5-flash")
    
    # CORS
    ALLOWED_ORIGINS = [
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "https://story-weaver-app.netlify.app",
        "https://reliable-sherbet-2352c4.netlify.app",  # Production Netlify domain
        "https://*.netlify.app",  # Allow Netlify preview deploys
    ]

class DevelopmentConfig(Config):
    """Development configuration."""
    DEBUG = True
    basedir = os.path.abspath(os.path.dirname(__file__))
    SQLALCHEMY_DATABASE_URI = f"sqlite:///{os.path.join(basedir, 'characters.db')}"

class ProductionConfig(Config):
    """Production configuration."""
    DEBUG = False
    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL")

config_by_name = dict(
    dev=DevelopmentConfig,
    production=ProductionConfig
)

key = os.environ.get("FLASK_ENV", "prod")
config = config_by_name[key]
