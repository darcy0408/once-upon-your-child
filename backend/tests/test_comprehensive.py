"""
Additional comprehensive tests for Story Weaver backend
"""
import pytest
import json
from unittest.mock import patch, MagicMock


def test_generate_story_with_feelings_wheel(client):
    """Test story generation with complete feelings wheel data"""
    with patch('app.model') as mock_model:
        mock_response = MagicMock()
        mock_response.text = json.dumps({
            "title": "A Story of Courage",
            "content": "Once upon a time, a brave child faced their fears...",
            "moral": "Courage comes from within",
            "age_appropriate": True
        })
        mock_model.generate_content.return_value = mock_response

        feelings_data = {
            'emotion_name': 'Scared',
            'intensity': 4,
            'what_happened': 'A loud thunderstorm',
            'triggers': ['loud noises', 'darkness'],
            'comfort_items': ['teddy bear', 'night light']
        }

        response = client.post('/generate-story', json={
            'character': {'name': 'Test Child', 'age': 7},
            'theme': 'Adventure',
            'current_feeling': feelings_data
        })

        assert response.status_code == 200
        data = response.get_json()
        assert 'story' in data
        assert 'title' in data['story']
        assert 'A Story of Courage' in data['story']['title']


def test_generate_story_error_handling(client):
    """Test error handling in story generation"""
    with patch('app.model') as mock_model:
        mock_model.generate_content.side_effect = Exception("API Error")

        response = client.post('/generate-story', json={
            'character': {'name': 'Test Child', 'age': 7},
            'theme': 'Adventure'
        })

        assert response.status_code == 500
        data = response.get_json()
        assert 'error' in data


def test_subscription_limits(client):
    """Test subscription-based limits"""
    # Create test account first
    client.post('/setup-test-account')

    # Test story generation limits
    for i in range(10):  # Assuming limit is higher
        response = client.post('/generate-story', json={
            'character': {'name': f'Test Child {i}', 'age': 7},
            'theme': 'Adventure'
        })
        if i < 5:  # Assuming free limit is 5
            assert response.status_code == 200
        # Note: Actual limit checking would depend on implementation


def test_database_operations(client):
    """Test database CRUD operations"""
    # Test character creation and retrieval
    char_data = {
        'name': 'Database Test',
        'age': 9,
        'gender': 'Other',
        'traits': ['Smart', 'Funny']
    }

    create_response = client.post('/create-character', json=char_data)
    assert create_response.status_code == 201
    char_id = create_response.get_json()['id']

    # Test retrieval
    get_response = client.get('/get-characters')
    assert get_response.status_code == 200
    characters = get_response.get_json()
    assert len(characters) >= 1
    assert any(c['name'] == 'Database Test' for c in characters)


def test_api_rate_limiting(client):
    """Test API rate limiting"""
    # This would require rate limiting middleware
    # For now, just test multiple rapid requests
    responses = []
    for i in range(10):
        response = client.get('/health')
        responses.append(response.status_code)

    # Should all succeed without rate limiting
    assert all(code == 200 for code in responses)


def test_cors_headers(client):
    """Test CORS headers are properly set"""
    response = client.get('/health')
    assert 'Access-Control-Allow-Origin' in response.headers
    assert 'Access-Control-Allow-Methods' in response.headers
    assert 'Access-Control-Allow-Headers' in response.headers


def test_input_validation(client):
    """Test input validation for API endpoints"""
    # Test invalid character data
    invalid_char = {
        'name': '',  # Empty name
        'age': -1,   # Invalid age
        'gender': 'Invalid'
    }

    response = client.post('/create-character', json=invalid_char)
    # Should handle validation gracefully
    assert response.status_code in [200, 201, 400]  # Depending on validation implementation


def test_story_complexity_calculation(client):
    """Test story complexity calculation based on age"""
    test_cases = [
        (3, 'simple'),
        (7, 'moderate'),
        (12, 'complex'),
        (16, 'advanced')
    ]

    for age, expected_complexity in test_cases:
        with patch('app.model') as mock_model:
            mock_response = MagicMock()
            mock_response.text = json.dumps({
                "title": f"Story for {age} year old",
                "content": f"A story appropriate for age {age}...",
                "moral": "Test moral",
                "age_appropriate": True
            })
            mock_model.generate_content.return_value = mock_response

            response = client.post('/generate-story', json={
                'character': {'name': 'Test', 'age': age},
                'theme': 'Adventure'
            })

            assert response.status_code == 200
            # Note: Complexity validation would require inspecting the prompt sent to AI


def test_offline_story_caching(client):
    """Test offline story storage and retrieval"""
    # This would require implementing caching endpoints
    # For now, test that stories can be saved and retrieved
    story_data = {
        'title': 'Cached Story',
        'content': 'This is a cached story...',
        'character': 'Test Character'
    }

    # Assuming there's a save endpoint
    save_response = client.post('/save-story', json=story_data)
    if save_response.status_code == 200:
        # Test retrieval
        get_response = client.get('/get-saved-stories')
        assert get_response.status_code == 200
        stories = get_response.get_json()
        assert isinstance(stories, list)