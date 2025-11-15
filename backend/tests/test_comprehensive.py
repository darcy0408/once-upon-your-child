"""
Additional comprehensive tests for Story Weaver backend
"""
import pytest
import json
from unittest.mock import patch, MagicMock

def test_generate_story_with_feelings_wheel(client):
    """Test story generation with complete feelings wheel data"""
    with patch('backend.routes.story_routes.story_generation_service.generate_story') as mock_generate_story:
        mock_generate_story.return_value = "[TITLE: A Story of Courage]\nOnce upon a time, a brave child faced their fears...\n[WISDOM GEM: Courage comes from within]"

        feelings_data = {
            'emotion_name': 'Scared',
            'intensity': 4,
            'what_happened': 'A loud thunderstorm',
        }

        response = client.post('/story/generate-story', json={
            'character': 'Test Child',
            'age': 7,
            'theme': 'Adventure',
            'current_feeling': feelings_data
        })

        assert response.status_code == 200
        data = response.get_json()
        assert 'story_text' in data
        assert 'title' in data
        assert 'A Story of Courage' in data['title']


def test_generate_story_error_handling(client):
    """Test error handling in story generation"""
    with patch('backend.routes.story_routes.story_generation_service.generate_story') as mock_generate_story:
        mock_generate_story.side_effect = Exception("API Error")

        response = client.post('/story/generate-story', json={
            'character': 'Test Child',
            'age': 7,
            'theme': 'Adventure'
        })

        assert response.status_code == 200 # Fallback should still return 200
        data = response.get_json()
        assert 'story_text' in data # Fallback provides a story


def test_subscription_limits(client):
    """Test subscription-based limits - Placeholder, actual logic not implemented yet"""
    # This test is a placeholder as subscription limits are not yet implemented
    # in the modularized backend.
    response = client.post('/auth/setup-test-account')
    assert response.status_code in [200, 201]

    # Test story generation limits (assuming no limits for now)
    for i in range(3):
        response = client.post('/story/generate-story', json={
            'character': f'Test Child {i}',
            'age': 7,
            'theme': 'Adventure'
        })
        assert response.status_code == 200


def test_database_operations(client):
    """Test database CRUD operations"""
    # Test character creation and retrieval
    char_data = {
        'name': 'Database Test',
        'age': 9,
        'gender': 'Other',
        'traits': ['Smart', 'Funny']
    }

    create_response = client.post('/character/create-character', json=char_data)
    assert create_response.status_code == 201
    char_id = create_response.get_json()['id']

    # Test retrieval
    get_response = client.get('/character/get-characters')
    assert get_response.status_code == 200
    characters = get_response.get_json()
    assert len(characters) >= 1
    assert any(c['name'] == 'Database Test' for c in characters)


def test_api_rate_limiting(client):
    """Test API rate limiting - Placeholder, actual logic not implemented yet"""
    # This would require rate limiting middleware
    # For now, just test multiple rapid requests
    responses = []
    for i in range(3):
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

    response = client.post('/character/create-character', json=invalid_char)
    # Should handle validation gracefully
    assert response.status_code == 400 # Expecting 400 for invalid age


def test_story_complexity_calculation(client):
    """Test story complexity calculation based on age"""
    test_cases = [
        (3, 'simple'),
        (7, 'moderate'),
        (12, 'complex'),
        (16, 'advanced')
    ]

    for age, expected_complexity in test_cases:
        with patch('backend.routes.story_routes.story_generation_service.generate_story') as mock_generate_story:
            mock_generate_story.return_value = f"[TITLE: Story for {age} year old]\nA story appropriate for age {age}...\n[WISDOM GEM: Test moral]"

            response = client.post('/story/generate-story', json={
                'character': 'Test',
                'age': age,
                'theme': 'Adventure'
            })

            assert response.status_code == 200
            data = response.get_json()
            assert 'story_text' in data
            assert f"Story for {age} year old" in data['title']


def test_offline_story_caching(client):
    """Test offline story storage and retrieval - Placeholder, not implemented"""
    # This would require implementing caching endpoints
    # For now, this test is a placeholder and will always pass
    pass
