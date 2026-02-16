from datetime import datetime

from backend.database import db
from backend.models.user import User


def _create_user(user_id: str) -> User:
    user = User(id=user_id, username=user_id, email=f"{user_id}@example.com")
    user.set_password("test-password")
    db.session.add(user)
    db.session.commit()
    return user


def test_get_subscription_success_contract(client, app):
    with app.app_context():
        user = _create_user("sub-user-1")
        user.subscription_tier = "premium"
        user.subscription_status = "active"
        user.cancel_at_period_end = False
        db.session.commit()
        user_id = user.id

    response = client.get(f"/api/user/{user_id}/subscription")

    assert response.status_code == 200
    body = response.get_json()
    assert body["user_id"] == user_id
    assert body["tier"] == "premium"
    assert body["status"] == "active"
    assert body["current_period_end"] is None
    assert body["cancel_at_period_end"] is False


def test_get_subscription_user_not_found_returns_404(client):
    response = client.get("/api/user/missing-user-id/subscription")

    assert response.status_code == 404
    assert response.get_json()["error"] == "User not found"


def test_get_subscription_falls_back_to_defaults_when_blank(client, app):
    with app.app_context():
        user = _create_user("sub-user-2")
        user.subscription_tier = ""
        user.subscription_status = ""
        db.session.commit()
        user_id = user.id

    response = client.get(f"/api/user/{user_id}/subscription")

    assert response.status_code == 200
    body = response.get_json()
    assert body["tier"] == "free"
    assert body["status"] == "active"


def test_get_subscription_formats_current_period_end_as_iso_string(client, app):
    with app.app_context():
        user = _create_user("sub-user-3")
        user.current_period_end = datetime(2026, 1, 5, 13, 22, 11, 999999)
        db.session.commit()
        user_id = user.id

    response = client.get(f"/api/user/{user_id}/subscription")

    assert response.status_code == 200
    body = response.get_json()
    assert isinstance(body["current_period_end"], str)
    assert body["current_period_end"].endswith("Z")
    assert "T" in body["current_period_end"]


def test_get_subscription_returns_cancel_flag(client, app):
    with app.app_context():
        user = _create_user("sub-user-4")
        user.cancel_at_period_end = True
        db.session.commit()
        user_id = user.id

    response = client.get(f"/api/user/{user_id}/subscription")

    assert response.status_code == 200
    assert response.get_json()["cancel_at_period_end"] is True


def test_get_subscription_returns_500_on_unexpected_error(client, mocker):
    mocker.patch("backend.routes.subscription_routes.db.session.get", side_effect=RuntimeError("db down"))

    response = client.get("/api/user/any-user/subscription")

    assert response.status_code == 500
    assert response.get_json()["error"] == "Internal server error"


