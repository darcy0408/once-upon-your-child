```python
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

def test_generate_interactive_story(client):
    """Test basic interactive story generation"""
    payload = {
        "character": "Luna",
        "theme": "Mystery",
        "companion": "Sparky the dog"
    }
    response = client.post('/generate-interactive-story',
                           data=json.dumps(payload),
                           content_type='application/json')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'text' in data
    assert 'choices' in data
    assert isinstance(data['choices'], list)
    assert len(data['choices']) > 0
    assert 'is_ending' in data
    assert data['is_ending'] is False

def test_generate_interactive_story_with_feelings(client):
    """Test interactive story generation with feelings integration"""
    payload = {
        "character": "Leo",
        "theme": "Courage",
        "current_feeling": {
            "emotion_name": "nervous",
            "intensity": 3,
            "what_happened": "He has a big presentation tomorrow.",
            "coping_strategies": ["deep breaths", "talking to a friend"]
        }
    }
    response = client.post('/generate-interactive-story',
                           data=json.dumps(payload),
                           content_type='application/json')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'text' in data
    assert 'choices' in data
    assert isinstance(data['choices'], list)
    assert len(data['choices']) > 0
    assert 'is_ending' in data
    assert data['is_ending'] is False
    # Optional: More advanced assertion to check if feelings are mentioned in text
    # assert "nervous" in data['text'].lower() or "deep breaths" in data['text'].lower()


def test_continue_interactive_story(client):
    """Test interactive story continuation logic"""
    # 1. Generate initial interactive story
    initial_payload = {
        "character": "Mia",
        "theme": "Discovery",
        "companion": "Pip the squirrel"
    }
    initial_response = client.post('/generate-interactive-story',
                                   data=json.dumps(initial_payload),
                                   content_type='application/json')
    assert initial_response.status_code == 200
    initial_data = json.loads(initial_response.data)
    assert 'text' in initial_data
    assert 'choices' in initial_data
    assert len(initial_data['choices']) > 0

    story_so_far = initial_data['text']
    first_choice = initial_data['choices'][0]['text']
    choices_made = ["initial_choice_id"] # Simulate a choice ID

    # 2. Continue story with a choice
    continue_payload = {
        "character": "Mia",
        "theme": "Discovery",
        "companion": "Pip the squirrel",
        "story_so_far": story_so_far,
        "choice": first_choice,
        "choices_made": choices_made,
        "current_feeling": {
            "emotion_name": "curious",
            "intensity": 2,
            "what_happened": "Found a mysterious map.",
            "coping_strategies": []
        }
    }
    continue_response = client.post('/continue-interactive-story',
                                    data=json.dumps(continue_payload),
                                    content_type='application/json')
    assert continue_response.status_code == 200
    continue_data = json.loads(continue_response.data)
    assert 'text' in continue_data
    assert 'choices' in continue_data
    assert isinstance(continue_data['choices'], list)
    assert len(continue_data['choices']) > 0
    assert 'is_ending' in continue_data
    assert continue_data['is_ending'] is False

    # 3. Continue story to an ending (simulate more choices made)
    story_so_far_2 = story_so_far + "\n" + continue_data['text']
    second_choice = continue_data['choices'][0]['text']
    choices_made_2 = choices_made + ["second_choice_id", "third_choice_id"] # Simulate 3 choices made

    ending_payload = {
        "character": "Mia",
        "theme": "Discovery",
        "companion": "Pip the squirrel",
        "story_so_far": story_so_far_2,
        "choice": second_choice,
        "choices_made": choices_made_2, # This should trigger the ending
    }
    ending_response = client.post('/continue-interactive-story',
                                  data=json.dumps(ending_payload),
                                  content_type='application/json')
    assert ending_response.status_code == 200
    ending_data = json.loads(ending_response.data)
    assert 'text' in ending_data
    assert 'choices' in ending_data
    assert ending_data['choices'] is None # Should be null for ending
    assert 'is_ending' in ending_data
    assert ending_data['is_ending'] is True
```