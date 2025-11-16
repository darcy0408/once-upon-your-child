"""
WSGI entry point for production deployment (Railway, Gunicorn, etc.)

This module must be imported as 'backend.wsgi' from the project root.
Railway configuration: gunicorn backend.wsgi:app --bind 0.0.0.0:$PORT
"""
import os
from backend.app import create_app

# Determine config based on environment
config_name = os.getenv('FLASK_ENV', 'production')

# Create the Flask app instance
app = create_app(config_name)

if __name__ == "__main__":
    app.run()
