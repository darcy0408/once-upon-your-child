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
    try:
        import google.genai
    except ImportError:
        # If not installed, we can't patch it easily, but we should verify why it's missing if expected
        pass

    # Mock the google.genai module directly
    # This covers imports like `from google import genai`
    mock_genai_module = mocker.patch('google.genai')

    # Create a mock client
    mock_client = MagicMock()
    mock_genai_module.Client.return_value = mock_client

    # Mock models
    mock_models = MagicMock()
    mock_client.models = mock_models

    # Mock generate_content response
    mock_response = MagicMock()
    mock_response.text = '{"story_text": "Once upon a time...", "title": "Test Story"}'
    mock_models.generate_content.return_value = mock_response

    return mock_genai_module

# ============================================================================
# AUTHENTICATION & AUTHORIZATION FIXTURES
# ============================================================================

@pytest.fixture
def auth_token():
    """Generate a test JWT token."""
    from datetime import datetime, timedelta
    import jwt

    payload = {
        'user_id': 'test_user_123',
        'email': 'test@example.com',
        'exp': datetime.utcnow() + timedelta(hours=1)
    }
    return jwt.encode(payload, 'test_secret', algorithm='HS256')

@pytest.fixture
def auth_headers(auth_token):
    """Headers with valid authentication token."""
    return {
        'Authorization': f'Bearer {auth_token}',
        'Content-Type': 'application/json'
    }

@pytest.fixture
def free_user_headers():
    """Headers for a free tier user (for rate limiting tests)."""
    from datetime import datetime, timedelta
    import jwt

    payload = {
        'user_id': 'free_user_456',
        'email': 'free@example.com',
        'subscription_tier': 'free',
        'exp': datetime.utcnow() + timedelta(hours=1)
    }
    token = jwt.encode(payload, 'test_secret', algorithm='HS256')
    return {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }

@pytest.fixture
def premium_user_headers():
    """Headers for a premium tier user."""
    from datetime import datetime, timedelta
    import jwt

    payload = {
        'user_id': 'premium_user_789',
        'email': 'premium@example.com',
        'subscription_tier': 'premium',
        'exp': datetime.utcnow() + timedelta(hours=1)
    }
    token = jwt.encode(payload, 'test_secret', algorithm='HS256')
    return {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }

# ============================================================================
# STRIPE MOCKING FIXTURES
# ============================================================================

@pytest.fixture
def mock_stripe(mocker):
    """Mock Stripe API to prevent real payment calls."""
    mock_stripe_module = mocker.patch('stripe')

    # Mock checkout session creation
    mock_session = MagicMock()
    mock_session.id = 'cs_test_123'
    mock_session.url = 'https://checkout.stripe.com/pay/cs_test_123'
    mock_stripe_module.checkout.Session.create.return_value = mock_session

    # Mock subscription retrieval
    mock_subscription = MagicMock()
    mock_subscription.id = 'sub_test_123'
    mock_subscription.status = 'active'
    mock_subscription.current_period_end = 1735689600  # Future timestamp
    mock_stripe_module.Subscription.retrieve.return_value = mock_subscription

    # Mock customer creation
    mock_customer = MagicMock()
    mock_customer.id = 'cus_test_123'
    mock_stripe_module.Customer.create.return_value = mock_customer

    return mock_stripe_module

# ============================================================================
# DATABASE & MODEL FIXTURES
# ============================================================================

@pytest.fixture
def sample_character_data():
    """Sample character data for testing."""
    return {
        'name': 'Luna',
        'age': 7,
        'personality': {'brave': 8, 'curious': 9, 'kind': 7},
        'interests': ['astronomy', 'reading', 'adventure'],
        'avatar_seed': 'luna-seed-123'
    }

@pytest.fixture
def sample_story_data():
    """Sample story generation request data."""
    return {
        'character': 'Luna',
        'age': 7,
        'theme': 'Adventure',
        'custom_elements': 'talking owl, rainbow bridge',
        'rhyme_time': False,
        'story_length': 'standard'
    }

@pytest.fixture
def sample_interactive_story_data():
    """Sample interactive story data."""
    return {
        'character': 'Luna',
        'age': 10,
        'scenario': 'Mystery Detective',
        'initial_choice': 'investigate_library'
    }

@pytest.fixture
def mock_story_response():
    """Mock AI-generated story response."""
    return {
        'story_text': 'Once upon a time, Luna the brave astronomer discovered a talking owl...',
        'title': 'Luna and the Starlight Owl',
        'wisdom_gem': 'True friendship knows no boundaries',
        'images': ['image1.jpg', 'image2.jpg']
    }

# ============================================================================
# SERVICE LAYER FIXTURES
# ============================================================================

@pytest.fixture
def mock_celery(mocker):
    """Mock Celery task queue."""
    mock_task = mocker.patch('backend.tasks.story_tasks.generate_story_task.delay')
    mock_result = MagicMock()
    mock_result.id = 'task_123'
    mock_task.return_value = mock_result
    return mock_task

@pytest.fixture
def mock_openrouter(mocker):
    """Mock OpenRouter API for image generation."""
    mock_openrouter = mocker.patch('backend.services.avatar_generation_service.requests')
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        'data': [{'url': 'https://example.com/avatar.png'}]
    }
    mock_openrouter.post.return_value = mock_response
    return mock_openrouter

# ============================================================================
# INTEGRATION TEST FIXTURES
# ============================================================================

@pytest.fixture
def test_user(app):
    """Create a test user in the database."""
    from backend.database import db
    from backend.models import User

    with app.app_context():
        user = User(
            id='test_user_123',
            email='test@example.com',
            subscription_tier='free',
            stories_generated=0
        )
        db.session.add(user)
        db.session.commit()
        yield user
        db.session.delete(user)
        db.session.commit()

@pytest.fixture
def test_character(app, test_user):
    """Create a test character in the database."""
    from backend.database import db
    from backend.models import Character

    with app.app_context():
        character = Character(
            id='char_123',
            user_id=test_user.id,
            name='Luna',
            age=7,
            personality={'brave': 8},
            avatar_seed='luna-seed'
        )
        db.session.add(character)
        db.session.commit()
        yield character
        db.session.delete(character)
        db.session.commit()