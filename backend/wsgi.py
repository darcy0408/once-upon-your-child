"""
WSGI entry point for Railway deployment.
"""

import os
import sys

# Add the project root to the Python path
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, PROJECT_ROOT)

from backend.app import create_app

# Create the application instance
config_name = os.getenv("FLASK_ENV", "production")
app = create_app(config_name)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
