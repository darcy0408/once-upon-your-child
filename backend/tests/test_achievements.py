"""
Tests for achievement backend functionality
"""


def _setup_account_and_token(client):
    """Create the test account and log in.

    /setup-test-account generates a RANDOM password per call (H-1 hardening
    removed the hardcoded credential), so the password must be read back from
    the setup response rather than assumed.
    """
    setup_response = client.post("/setup-test-account")
    password = setup_response.get_json()["password"]
    login_response = client.post(
        "/auth/login",
        json={
            "username": "testuser",
            "password": password,
        },
    )
    return login_response.get_json()["token"]


def test_sync_achievement_progress(client):
    """Test syncing achievement progress from frontend to backend."""
    # First create a test user and get token
    token = _setup_account_and_token(client)

    # Prepare achievement sync data
    sync_data = {
        "achievements": [
            {
                "type": "firstStory",
                "current_value": 1,
                "target_value": 1,
                "is_unlocked": True,
                "unlocked_at": "2024-01-01T10:00:00.000Z",
                "is_new": False,
            }
        ],
        "stats": {
            "total_stories": 5,
            "theme_counts": {"Adventure": 3, "Friendship": 2},
            "characters_created": 2,
            "current_streak": 2,
            "longest_streak": 3,
            "last_story_date_iso": "2024-01-01",
            "earned_early_bird": False,
            "earned_night_owl": True,
            "unique_emotions_logged": 8,
        },
    }

    # Sync achievements
    response = client.post(
        "/achievement/sync",
        json=sync_data,
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "success"


def test_get_achievement_data(client):
    """Test getting achievement data for a user."""
    # Setup test account
    token = _setup_account_and_token(client)

    # Get achievement data
    response = client.get(
        "/achievement/data", headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    data = response.get_json()
    assert "achievements" in data
    assert "stats" in data
    assert isinstance(data["achievements"], list)
    assert isinstance(data["stats"], dict)


