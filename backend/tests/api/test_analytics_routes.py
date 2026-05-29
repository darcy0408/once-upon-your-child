import uuid

from backend.database import db
from backend.models import Story, User


def test_get_overview_unauthorized(client):
    """Test overview stats without auth"""
    response = client.get("/admin/analytics/overview")
    assert response.status_code == 401


def test_get_overview_not_admin(client, auth_headers, test_user, app):
    """Test overview stats with regular user auth"""
    with app.app_context():
        db.session.merge(test_user)
        db.session.commit()
    response = client.get("/admin/analytics/overview", headers=auth_headers)
    assert response.status_code == 403


def test_get_overview_success(client, admin_headers, app):
    """Test successful overview stats retrieval"""
    with app.app_context():
        # Add some data
        user = User(
            id=str(uuid.uuid4()),
            username="u1",
            email="u1@e.com",
            role="user",
            password_hash="hash",
        )
        db.session.add(user)
        db.session.commit()

        story = Story(
            id=str(uuid.uuid4()), user_id=user.id, title="T1", theme="Adventure"
        )
        db.session.add(story)
        db.session.commit()

    response = client.get("/admin/analytics/overview", headers=admin_headers)
    assert response.status_code == 200
    data = response.get_json()
    assert "today" in data
    assert "this_week" in data
    assert "this_month" in data


def test_get_story_stats_success(client, admin_headers):
    """Test successful story stats retrieval"""
    response = client.get("/admin/analytics/story-stats", headers=admin_headers)
    assert response.status_code == 200
    data = response.get_json()
    assert "by_theme" in data
    assert "interactive_vs_standard" in data


def test_get_user_activity_success(client, admin_headers):
    """Test successful user activity retrieval"""
    response = client.get("/admin/analytics/user-activity", headers=admin_headers)
    assert response.status_code == 200
    data = response.get_json()
    assert "total_users" in data
    assert "premium_users" in data


def test_get_feature_usage_success(client, admin_headers):
    """Test successful feature usage retrieval"""
    response = client.get("/admin/analytics/feature-usage", headers=admin_headers)
    assert response.status_code == 200
    data = response.get_json()
    assert "illustrations_generated" in data
    assert "feature_unlock_progress" in data


def test_get_stories_paginated_success(client, admin_headers, app):
    """Test successful paginated stories retrieval"""
    with app.app_context():
        user = User(
            id=str(uuid.uuid4()), username="u2", email="u2@e.com", password_hash="hash"
        )
        db.session.add(user)
        db.session.commit()
        story = Story(
            id=str(uuid.uuid4()), user_id=user.id, title="P1", theme="Fantasy"
        )
        db.session.add(story)
        db.session.commit()

    response = client.get(
        "/admin/analytics/stories?page=1&per_page=10", headers=admin_headers
    )
    assert response.status_code == 200
    data = response.get_json()
    assert "items" in data
    assert len(data["items"]) >= 1
    assert data["total"] >= 1


def test_get_users_paginated_success(client, admin_headers):
    """Test successful paginated users retrieval"""
    response = client.get("/admin/analytics/users?tier=free", headers=admin_headers)
    assert response.status_code == 200
    data = response.get_json()
    assert "items" in data
    assert "total" in data


def test_get_cost_report_success(client, admin_headers, mocker):
    """Test successful cost report retrieval"""
    # Mock the get_cost_report function as it might involve complex calculation or external calls
    mock_report = {"total_cost": 1.23, "breakdown": {}}
    mocker.patch("backend.analytics_routes.get_cost_report", return_value=mock_report)

    response = client.get("/admin/cost-report?days=7", headers=admin_headers)
    assert response.status_code == 200
    data = response.get_json()
    assert data["total_cost"] == 1.23


def test_get_cost_report_failure_returns_500(client, admin_headers, mocker):
    """Route should return a safe 500 payload on report generation failure."""
    mocker.patch(
        "backend.analytics_routes.get_cost_report", side_effect=RuntimeError("boom")
    )

    response = client.get("/admin/cost-report?days=7", headers=admin_headers)

    assert response.status_code == 500
    data = response.get_json()
    assert "error" in data
    assert "Failed to generate cost report" in data["error"]
