from datetime import datetime, timedelta, timezone
import jwt

from backend.database import db
from backend.models.user import User


def _create_user(user_id: str) -> User:
    user = User(id=user_id, username=user_id, email=f"{user_id}@example.com")
    user.set_password("test-password")
    db.session.add(user)
    db.session.commit()
    return user

def _auth_headers(user_id: str) -> dict[str, str]:
    token = jwt.encode(
        {
            "user_id": user_id,
            "sub": user_id,
            "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
        },
        "dev-secret-key",
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def test_get_subscription_success_contract(client, app):
    with app.app_context():
        user = _create_user("sub-user-1")
        user.subscription_tier = "premium"
        user.subscription_status = "active"
        user.cancel_at_period_end = False
        db.session.commit()
        user_id = user.id

    response = client.get(f"/api/user/{user_id}/subscription", headers=_auth_headers(user_id))

    assert response.status_code == 200
    body = response.get_json()
    assert body["user_id"] == user_id
    assert body["tier"] == "premium"
    assert body["status"] == "active"
    assert body["current_period_end"] is None
    assert body["cancel_at_period_end"] is False


def test_get_subscription_user_not_found_returns_404(client, auth_token):
    # Use valid token but for a user ID that doesn't match the token's user
    response = client.get("/api/user/missing-user-id/subscription", headers={'Authorization': f'Bearer {auth_token}'})

    # The require_owner decorator will return 403 if user_id doesn't match current_user.id
    assert response.status_code == 403


def test_get_subscription_falls_back_to_defaults_when_blank(client, app):
    with app.app_context():
        user = _create_user("sub-user-2")
        user.subscription_tier = ""
        user.subscription_status = ""
        db.session.commit()
        user_id = user.id

    response = client.get(f"/api/user/{user_id}/subscription", headers=_auth_headers(user_id))

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

    response = client.get(f"/api/user/{user_id}/subscription", headers=_auth_headers(user_id))

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

    response = client.get(f"/api/user/{user_id}/subscription", headers=_auth_headers(user_id))

    assert response.status_code == 200
    assert response.get_json()["cancel_at_period_end"] is True


def test_get_subscription_returns_500_on_unexpected_error(client, mocker, app):
    with app.app_context():
        _create_user("sub-user-err")
    
    mocker.patch("backend.routes.subscription_routes.db.session.get", side_effect=RuntimeError("db down"))

    response = client.get("/api/user/sub-user-err/subscription", headers=_auth_headers("sub-user-err"))

    assert response.status_code == 500
    # In testing/dev, the actual error message is returned. In prod, "Internal server error" is returned.
    assert response.get_json()["error"] == "db down"


