import pytest
import os
import sys
from unittest.mock import MagicMock

# Ensure backend path is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from backend.app import create_app
from backend.database import db

@pytest.fixture
def app():
    """Create and configure a new app instance for each test."""
    app = create_app('testing')
    
    # Create tables
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()

@pytest.fixture
def client(app):
    """A test client for the app."""
    return app.test_client()

@pytest.fixture
def runner(app):
    """A test runner for the app's CLI commands."""
    return app.test_cli_runner()

@pytest.fixture(autouse=True)
def mock_gemini(mocker):
    """Mock Gemini API to prevent real calls during tests."""
    # Mock the google.generativeai module
    mock_genai = mocker.patch('backend.services.story_service.genai')
    
    # Mock the GenerativeModel
    mock_model = MagicMock()
    mock_genai.GenerativeModel.return_value = mock_model
    
    # Mock generate_content response
    mock_response = MagicMock()
    mock_response.text = '{"story_text": "Once upon a time...", "title": "Test Story"}'
    mock_model.generate_content.return_value = mock_response
    mock_model.generate_content_async.return_value = mock_response
    
    return mock_genai