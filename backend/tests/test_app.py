"""
Basic tests for Story Weaver backend API
"""
import pytest
import json
from app import app, db


@pytest.fixture
def client():
    """Test client fixture"""
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    with app.test_client() as client:
        with app.app_context():
            db.create_all()
        yield client


def test_health_endpoint(client):
    """Test the health endpoint"""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'status' in data
    assert data['status'] == 'ok'


def test_get_story_themes(client):
    """Test getting story themes"""
    response = client.get('/get-story-themes')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert isinstance(data, list)
    assert len(data) > 0
    assert 'Adventure' in data


def test_create_character(client):
    """Test character creation"""
    character_data = {
        'name': 'Test Character',
        'age': 8,
        'gender': 'Other',
        'traits': ['Brave', 'Curious']
    }

    response = client.post('/create-character',
                          data=json.dumps(character_data),
                          content_type='application/json')
    assert response.status_code == 201
    data = json.loads(response.data)
    assert 'id' in data
    assert data['name'] == 'Test Character'
    assert data['age'] == 8


def test_get_characters_empty(client):
    """Test getting characters when none exist"""
    response = client.get('/get-characters')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert isinstance(data, list)


def test_generate_story_missing_data(client):
    """Test story generation with missing data"""
    response = client.post('/generate-story',
                          data=json.dumps({}),
                          content_type='application/json')
    # Should still work with defaults
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'story' in data
    assert 'title' in data


def test_setup_test_account(client):
    """Test setting up test account"""
    response = client.post('/setup-test-account')
    assert response.status_code in [200, 201]
    data = json.loads(response.data)
    assert 'status' in data
    assert data['status'] in ['created', 'updated']