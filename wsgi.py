import sys
import os

# Ensure we always add the directory containing this file (project root) to sys.path
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from backend.app import create_app

# Get config name from environment, map 'production' to 'prod'
config_name = os.getenv('FLASK_CONFIG') or os.getenv('FLASK_ENV', 'prod')

# Railway and other platforms often use 'production', map it to 'prod'
if config_name == 'production':
    config_name = 'prod'

# Create the app instance for WSGI server (Gunicorn)
app = create_app(config_name)
