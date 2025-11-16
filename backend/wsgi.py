"""
WSGI entry point for production deployment (Railway, Gunicorn, etc.)
"""
import os
from app import create_app

# Determine config based on environment
config_name = os.getenv('FLASK_ENV', 'production')

# Create the Flask app instance
app = create_app(config_name)

if __name__ == "__main__":
    app.run()
