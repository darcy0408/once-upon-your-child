import io
from datetime import datetime, timedelta, timezone

import jwt

from backend.database import db
from backend.models import User
from backend.routes import avatar_routes

# Minimal valid PNG signature + padding so the avatar route's magic-byte
# photo validation (_is_valid_image) accepts the upload. The validator
# inspects only the leading bytes.
_VALID_PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32


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
        "user_id": user_id,
        "sub": user_id,
        "email": f"{user_id}@example.com",
        "subscription_tier": tier,
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    return jwt.encode(payload, "dev-secret-key", algorithm="HS256")


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
            "photo": (io.BytesIO(_VALID_PNG_BYTES), "photo.png"),
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


def test_transform_superhero_premium_returns_portrait(client, app, monkeypatch):
    """Premium user gets a superhero portrait; costume ids reach the service."""
    with app.app_context():
        token = _create_user("superhero-premium-user", "premium")

    headers = {"Authorization": f"Bearer {token}"}

    captured = {}

    class _StubAvatarService:
        def transform_to_superhero(self, photo_bytes, **kwargs):
            captured.update(kwargs)
            captured["photo_len"] = len(photo_bytes)
            return {
                "id": "superhero-test",
                "image_base64": "data:image/png;base64,ZmFrZQ==",
                "style": "pixar-superhero",
            }

    monkeypatch.setattr(avatar_routes, "_avatar_service", _StubAvatarService())

    resp = client.post(
        "/avatar/transform-superhero",
        data={
            "photo": (io.BytesIO(_VALID_PNG_BYTES), "avatar.png"),
            "costume_color": "red",
            "cape_style": "rainbow",
            "emblem": "lightning",
            "power": "flying",
        },
        headers=headers,
        content_type="multipart/form-data",
    )

    assert resp.status_code == 200
    body = resp.get_json()
    assert body["status"] == "success"
    assert body["avatar"]["id"] == "superhero-test"
    assert body["avatar"]["style"] == "pixar-superhero"
    # Costume/power ids were forwarded to the service.
    assert captured["costume_color"] == "red"
    assert captured["cape_style"] == "rainbow"
    assert captured["emblem"] == "lightning"
    assert captured["power"] == "flying"
    assert captured["photo_len"] > 0


def test_transform_superhero_requires_photo(client, app):
    """Missing photo → 400 MISSING_PHOTO (premium user, so not blocked on tier)."""
    with app.app_context():
        token = _create_user("superhero-nophoto-user", "premium")

    resp = client.post(
        "/avatar/transform-superhero",
        data={"power": "flying"},
        headers={"Authorization": f"Bearer {token}"},
        content_type="multipart/form-data",
    )

    assert resp.status_code == 400
    assert resp.get_json()["error_code"] == "MISSING_PHOTO"


def test_transform_superhero_blocks_free_tier(client, app):
    """Free users are upsold — the paid image-gen feature is premium-gated."""
    with app.app_context():
        token = _create_user("superhero-free-user", "free")

    resp = client.post(
        "/avatar/transform-superhero",
        data={
            "photo": (io.BytesIO(_VALID_PNG_BYTES), "avatar.png"),
            "power": "flying",
        },
        headers={"Authorization": f"Bearer {token}"},
        content_type="multipart/form-data",
    )

    assert resp.status_code == 403


def test_generate_custom_avatar_returns_400_for_out_of_range_age(
    client, app, monkeypatch
):
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
            "photo": (io.BytesIO(_VALID_PNG_BYTES), "photo.png"),
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
