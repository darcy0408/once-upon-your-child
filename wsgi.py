import sys
import os
import logging

# Ensure we always add the directory containing this file (project root) to sys.path
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# Debugging: Print environment variable status
api_key_exists = bool(os.getenv("GEMINI_API_KEY"))
api_key_length = len(os.getenv("GEMINI_API_KEY", ""))
print(f"wsgi.py: GEMINI_API_KEY exists: {api_key_exists}")
print(f"wsgi.py: GEMINI_API_KEY length: {api_key_length}")


from backend.app import create_app
# Import the app instance directly if create_app returns it
# If backend.app defines 'app' directly, then the second import might be redundant or incorrect.
# For now, assuming create_app returns the app instance.
try:
    # Pass config name to create_app, defaulting to 'production'
    config_name = os.getenv('FLASK_ENV', 'production')
    app = create_app(config_name)
except Exception as e:
    print(f"wsgi.py: Error creating app: {e}")
    # Fallback if create_app doesn't work as expected, though this is less likely
    # if backend.app has 'app = Flask(...)'
    if 'app' not in locals():
        try:
            from backend.app import app as backend_app
            app = backend_app
        except Exception as inner_e:
            print(f"wsgi.py: Fallback error creating app: {inner_e}")
            # If even fallback fails, we can't proceed
            sys.exit(1) # Exit if app cannot be created
