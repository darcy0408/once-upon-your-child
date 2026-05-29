"""Simple Flask run script for development"""

import os
import sys

# Add the project root to the sys.path
# Assumes run.py is in 'backend/' and project root is its parent
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from backend.app import create_app

env = os.environ.get("FLASK_ENV", "dev")
app = create_app(env)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True)
