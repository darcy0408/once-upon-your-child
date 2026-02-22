import io
import jwt
from datetime import datetime, timedelta, timezone

from backend.database import db
from backend.models import User
from backend.routes import avatar_routes


def _create_user(user_id: str, tier: str) -> str:
    """Create a user and return a valid JWT token."""
    user = User(
        id=user_id,
        username=user_id,
        email=f"{user_id}@example.com",
        password_hash="hash",
        subscription_tier=tier,
        role="user",
    )
    db.session.add(user)
    db.session.commit()
    
    payload = {
        'user_id': user_id,
        'sub': user_id,
        'email': f"{user_id}@example.com",
        'subscription_tier': tier,
        'exp': int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp())
    }
    return jwt.encode(payload, 'dev-secret-key', algorithm='HS256')


def test_avatar_generate_route_enforces_free_tier_limit(client, app):
    """Free users should hit the configured per-hour avatar route limit."""
    with app.app_context():
        token = _create_user("free-avatar-user", "free")
    
    headers = {"Authorization": f"Bearer {token}"}
    statuses = []
    for _ in range(6):
        resp = client.post(
            "/avatar/generate-avatar",
            json={"character_name": "Luna", "age": 7, "style": "nope"},
            headers=headers
        )
        statuses.append(resp.status_code)

    # Note: 400 is expected because "nope" is an invalid style, but it still counts towards the limit
    assert statuses[:5] == [400, 400, 400, 400, 400]
    assert statuses[5] == 429

    body = resp.get_json()
    assert body["error_code"] == "RATE_LIMIT_EXCEEDED"
    assert body["limit_per_hour"] == 5
    assert "retry_after_seconds" in body
    assert resp.headers.get("X-Avatar-RateLimit-Tier") == "free"


def test_avatar_generate_route_allows_premium_higher_limit(client, app):
    """Premium users should get higher limits than free users."""
    with app.app_context():
        token = _create_user("premium-avatar-user", "premium")

    headers = {"Authorization": f"Bearer {token}"}
    statuses = []
    for _ in range(6):
        resp = client.post(
            "/avatar/generate-avatar",
            json={"character_name": "Luna", "age": 7, "style": "nope"},
            headers=headers,
        )
        statuses.append(resp.status_code)
        assert resp.headers.get("X-Avatar-RateLimit-Limit") == "50"
        assert resp.headers.get("X-Avatar-RateLimit-Tier") == "premium"

    assert statuses == [400, 400, 400, 400, 400, 400]


def test_avatar_generate_route_byok_unlimited_skips_custom_headers(client, app):
    """BYOK users should bypass avatar route limits when byok=None."""
    with app.app_context():
        token = _create_user("byok-avatar-user", "byok")

    headers = {"Authorization": f"Bearer {token}"}
    statuses = []
    for _ in range(6):
        resp = client.post(
            "/avatar/generate-avatar",
            json={"character_name": "Luna", "age": 7, "style": "nope"},
            headers=headers,
        )
        statuses.append(resp.status_code)
        assert resp.headers.get("X-Avatar-RateLimit-Limit") is None

    assert statuses == [400, 400, 400, 400, 400, 400]


def test_generate_custom_avatar_accepts_age_99(client, app, monkeypatch):
    """Custom avatar endpoint should accept upper bound age 99."""
    with app.app_context():
        token = _create_user("custom-avatar-user-99", "free")

    headers = {"Authorization": f"Bearer {token}"}

    class _StubAvatarService:
        def generate_custom_avatar(self, **kwargs):
            assert kwargs["age"] == 99
            return {
                "id": "avatar-test-99",
                "image_base64": "data:image/png;base64,ZmFrZQ==",
            }

    monkeypatch.setattr(avatar_routes, "_avatar_service", _StubAvatarService())

    resp = client.post(
        "/avatar/generate-custom-avatar",
        data={
            "photo": (io.BytesIO(b"fake-image-bytes"), "photo.png"),
            "character_name": "Luna",
            "age": "99",
            "gender": "girl",
            "eye_color": "Brown",
            "favorite_color": "Blue",
        },
        headers=headers,
        content_type="multipart/form-data",
    )

    assert resp.status_code == 200
    body = resp.get_json()
    assert body["status"] == "success"
    assert body["avatar"]["id"] == "avatar-test-99"


def test_generate_custom_avatar_returns_400_for_out_of_range_age(client, app, monkeypatch):
    """Out-of-range custom avatar ages should return validation error with 400."""
    with app.app_context():
        token = _create_user("custom-avatar-user-err", "free")

    headers = {"Authorization": f"Bearer {token}"}

    class _StubAvatarService:
        def generate_custom_avatar(self, **kwargs):
            raise ValueError("Age must be between 3 and 99")

    monkeypatch.setattr(avatar_routes, "_avatar_service", _StubAvatarService())

    resp = client.post(
        "/avatar/generate-custom-avatar",
        data={
            "photo": (io.BytesIO(b"fake-image-bytes"), "photo.png"),
            "character_name": "Luna",
            "age": "100",
            "gender": "girl",
            "eye_color": "Brown",
            "favorite_color": "Blue",
        },
        headers=headers,
        content_type="multipart/form-data",
    )

    assert resp.status_code == 400
    body = resp.get_json()
    assert body["status"] == "error"
    assert body["error_code"] == "VALIDATION_ERROR"
    assert body["message"] == "Age must be between 3 and 99"
