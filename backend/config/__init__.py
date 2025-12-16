import os
from dotenv import load_dotenv
load_dotenv(override=True)

# FORCE gemini-2.0-flash-exp to fix persistent reversion issue
os.environ['GEMINI_MODEL'] = 'gemini-2.0-flash-exp'
print(f"🔧 FORCED GEMINI_MODEL = {os.environ.get('GEMINI_MODEL')}")

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key'

    # Fix Railway's postgres:// to postgresql:// for SQLAlchemy 2.0+
    database_url = os.environ.get('DATABASE_URL') or 'sqlite:///app.db'
    if database_url.startswith('postgres://'):
        database_url = database_url.replace('postgres://', 'postgresql://', 1)
    SQLALCHEMY_DATABASE_URI = database_url

    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Database connection pooling for better performance
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_size': 10,              # Number of connections to keep open
        'pool_recycle': 3600,          # Recycle connections after 1 hour
        'pool_pre_ping': True,         # Check connection health before use
        'max_overflow': 20,            # Allow 20 extra connections if needed
        'pool_timeout': 30,            # Timeout for getting connection from pool
    }

    # API Configuration
    GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
    GEMINI_MODEL = os.environ.get('GEMINI_MODEL') or 'gemini-2.0-flash-exp'

    # CORS Configuration
    ALLOWED_ORIGINS = os.environ.get('ALLOWED_ORIGINS', '*').split(',')

class DevelopmentConfig(Config):
    DEBUG = True
    # Explicitly force latest free experimental model
    GEMINI_MODEL = 'gemini-2.0-flash-exp'

class ProductionConfig(Config):
    DEBUG = False

class TestingConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'

config_by_name = {
    'dev': DevelopmentConfig,
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}

# For backward compatibility
config = Config
