import os
import sys

import pytest

os.environ.setdefault("SKIP_DEFAULT_APP_INIT", "1")
os.environ.setdefault("FLASK_CONFIG", "testing")

# Add project root to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))

# Import models to ensure they are registered
from backend.models.user import User
from backend.models.character import Character
from backend.models.achievement import UserAchievement, AchievementStats

from backend.database import db

@pytest.fixture(scope='session')
def app():
    """Instance of Main flask app"""
    from backend.app import create_app
    app = create_app('testing')
    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()

@pytest.fixture(scope='function')
def client(app):
    """Flask test client"""
    with app.test_client() as client:
        yield client
