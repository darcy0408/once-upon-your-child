"""
Tests for achievement backend functionality
"""
import pytest
import json
from unittest.mock import patch

def test_sync_achievement_progress(client):
    """Test syncing achievement progress from frontend to backend."""
    # First create a test user and get token
    client.post('/setup-test-account')
    login_response = client.post('/auth/login', json={
        'username': 'testuser',
        'password': 'password'
    })
    token = login_response.get_json()['token']

    # Prepare achievement sync data
    sync_data = {
        'achievements': [
            {
                'type': 'firstStory',
                'current_value': 1,
                'target_value': 1,
                'is_unlocked': True,
                'unlocked_at': '2024-01-01T10:00:00.000Z',
                'is_new': False
            }
        ],
        'stats': {
            'total_stories': 5,
            'theme_counts': {'Adventure': 3, 'Friendship': 2},
            'characters_created': 2,
            'current_streak': 2,
            'longest_streak': 3,
            'last_story_date_iso': '2024-01-01',
            'earned_early_bird': False,
            'earned_night_owl': True,
            'unique_emotions_logged': 8
        }
    }

    # Sync achievements
    response = client.post('/achievement/sync',
                          json=sync_data,
                          headers={'Authorization': f'Bearer {token}'})

    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'success'

def test_get_achievement_data(client):
    """Test getting achievement data for a user."""
    # Setup test account
    client.post('/setup-test-account')
    login_response = client.post('/auth/login', json={
        'username': 'testuser',
        'password': 'password'
    })
    token = login_response.get_json()['token']

    # Get achievement data
    response = client.get('/achievement/data',
                         headers={'Authorization': f'Bearer {token}'})

    assert response.status_code == 200
    data = response.get_json()
    assert 'achievements' in data
    assert 'stats' in data
    assert isinstance(data['achievements'], list)
    assert isinstance(data['stats'], dict)

def test_record_story_creation(client):
    """Test recording story creation."""
    # Setup test account
    client.post('/setup-test-account')
    login_response = client.post('/auth/login', json={
        'username': 'testuser',
        'password': 'password'
    })
    token = login_response.get_json()['token']

    # Record story creation
    response = client.post('/achievement/record/story',
                          json={'theme': 'Adventure'},
                          headers={'Authorization': f'Bearer {token}'})

    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'success'
    assert 'new_unlocks' in data

def test_record_character_creation(client):
    """Test recording character creation."""
    # Setup test account
    client.post('/setup-test-account')
    login_response = client.post('/auth/login', json={
        'username': 'testuser',
        'password': 'password'
    })
    token = login_response.get_json()['token']

    # Record character creation
    response = client.post('/achievement/record/character',
                          headers={'Authorization': f'Bearer {token}'})

    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'success'
    assert 'new_unlocks' in data

def test_get_achievement_stats(client):
    """Test getting achievement statistics."""
    # Setup test account
    client.post('/setup-test-account')
    login_response = client.post('/auth/login', json={
        'username': 'testuser',
        'password': 'password'
    })
    token = login_response.get_json()['token']

    # Get achievement stats
    response = client.get('/achievement/stats',
                         headers={'Authorization': f'Bearer {token}'})

    assert response.status_code == 200
    data = response.get_json()
    assert 'total_stories' in data
    assert 'characters_created' in data
    assert 'current_streak' in data
    assert 'longest_streak' in data