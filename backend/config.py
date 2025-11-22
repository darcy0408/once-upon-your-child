import os
from dotenv import load_dotenv

# Load environment variables from .env file
dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
print(f"Loading .env from: {dotenv_path}")
print(f"File exists: {os.path.exists(dotenv_path)}")
load_dotenv(dotenv_path=dotenv_path, override=True)
print(f"GEMINI_API_KEY loaded: {bool(os.environ.get('GEMINI_API_KEY'))}")

class Config:
    """Base configuration."""
    SECRET_KEY = os.environ.get('SECRET_KEY', 'a_secret_key')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_SORT_KEYS = False
    
    # Gemini API
    GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
    GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-pro-latest")
    
    # CORS
    ALLOWED_ORIGINS = [
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:3000",  # Flutter web development
        "http://127.0.0.1:3000",  # Flutter web development
        "http://localhost:5000",  # Direct access
        "http://127.0.0.1:5000",  # Direct access
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
    prod=ProductionConfig
)

key = os.environ.get("FLASK_ENV", "prod")
config = config_by_name[key]