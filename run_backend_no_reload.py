import os
import sys

# Add the project root to the path
sys.path.insert(0, os.path.abspath(os.getcwd()))

from backend.app import create_app

if __name__ == '__main__':
    os.environ['RATELIMIT_ENABLED'] = 'False'
    app = create_app('development')
    app.run(host='0.0.0.0', port=5000, use_reloader=False)
