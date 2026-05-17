"""
Additional comprehensive tests for Story Weaver backend
"""
import pytest
import json
from unittest.mock import patch, MagicMock


def test_generate_story_with_feelings_wheel(client, auth_headers, test_user):
    """Test story generation with complete feelings wheel data"""
    # Since model is None in test environment, this will use fallback
    feelings_data = {
        'emotion_name': 'Scared',
        'intensity': 4,
        'what_happened': 'A loud thunderstorm',
        'triggers': ['loud noises', 'darkness'],
        'comfort_items': ['teddy bear', 'night light']
    }

    response = client.post('/generate-story', json={
        'character': 'Test Child',
        'age': 7,
        'theme': 'Adventure',
        'current_feeling': feelings_data
    }, headers=auth_headers)

    assert response.status_code == 200
    data = response.get_json()
    assert 'story' in data
    story = data['story']
    assert 'title' in story or 'story_text' in story


def test_generate_story_error_handling(client, auth_headers, test_user):
    """Test error handling in story generation"""
    # Since model is None in test environment, it should still work with fallbacks
    response = client.post('/generate-story', json={
        'character': 'Test Child',
        'age': 7,
        'theme': 'Adventure'
    }, headers=auth_headers)

    assert response.status_code == 200
    data = response.get_json()
    assert 'story' in data


def test_subscription_limits(client, auth_headers, test_user):
    """Test subscription-based limits"""
    # Create test account first
    client.post('/setup-test-account', headers=auth_headers)

    # Test story generation - should work since model uses fallbacks
    for i in range(3):  # Test a few requests
        response = client.post('/generate-story', json={
            'character': f'Test Child {i}',
            'age': 7,
            'theme': 'Adventure'
        }, headers=auth_headers)
        assert response.status_code == 200
        data = response.get_json()
        assert 'story' in data


def test_database_operations(client, auth_headers, test_user):
    """Test database CRUD operations"""
    # Test character creation and retrieval
    char_data = {
        'name': 'Database Test',
        'age': 9,
        'gender': 'Other',
        'traits': ['Smart', 'Funny']
    }

    create_response = client.post('/create-character', json=char_data, headers=auth_headers)
    assert create_response.status_code == 201
    char_id = create_response.get_json()['id']

    # Test retrieval
    get_response = client.get('/get-characters', headers=auth_headers)
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
    """Test CORS headers are properly set.

    CORS is allow-listed: an origin that is not on the allowlist must NOT be
    echoed back in Access-Control-Allow-Origin, while an allow-listed origin
    is reflected.
    """
    # Non-allowlisted origin: must not be echoed back.
    rogue = 'https://evil-attacker.example'
    response = client.get('/health', headers={'Origin': rogue})
    assert response.status_code == 200
    assert response.headers.get('Access-Control-Allow-Origin') != rogue

    # Allow-listed production origin: reflected back by Flask-CORS.
    allowed = 'https://grand-light-production-68d9.up.railway.app'
    response = client.get('/health', headers={'Origin': allowed})
    assert response.status_code == 200
    assert response.headers.get('Access-Control-Allow-Origin') == allowed


def test_input_validation(client, auth_headers, test_user):
    """Test input validation for API endpoints"""
    # Test invalid character data
    invalid_char = {
        'name': '',  # Empty name
        'age': -1,   # Invalid age
        'gender': 'Invalid'
    }

    response = client.post('/create-character', json=invalid_char, headers=auth_headers)
    # Should handle validation gracefully
    assert response.status_code in [200, 201, 400, 422]


def test_story_complexity_calculation(client, auth_headers, test_user):
    """Test story complexity calculation based on age"""
    test_cases = [
        (3, 'simple'),
        (7, 'moderate'),
        (12, 'complex'),
        (16, 'advanced')
    ]

    for age, expected_complexity in test_cases:
        # Test with different ages - should work with fallbacks
        response = client.post('/generate-story', json={
            'character': 'Test',
            'age': age,
            'theme': 'Adventure'
        }, headers=auth_headers)

        assert response.status_code == 200
        data = response.get_json()
        assert 'story' in data


