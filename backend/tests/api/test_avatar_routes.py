import io
from datetime import datetime, timedelta, timezone

import jwt

from backend.database import db
from backend.models import User
from backend.models.consent_record import ConsentRecord
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


def _grant_photo_avatar_consent(
    user_id: str, allow_photo_avatar: bool = True, withdrawn: bool = False
) -> ConsentRecord:
    """Create a non-withdrawn ConsentRecord for user_id (MT-363 test helper).

    Mirrors the shape written by POST /api/user/<id>/consent in
    backend/routes/user_routes.py.
    """
    record = ConsentRecord(
        user_id=user_id,
        child_age=9,
        consent_method="parent",
        allow_photo_avatar=allow_photo_avatar,
        withdrawn=withdrawn,
    )
    db.session.add(record)
    db.session.commit()
    return record


def test_generate_custom_avatar_accepts_age_99(client, app, monkeypatch):
    """Custom avatar endpoint should accept upper bound age 99."""
    with app.app_context():
        token = _create_user("custom-avatar-user-99", "free")
        _grant_photo_avatar_consent("custom-avatar-user-99")

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
        # MT-363: transform-superhero re-renders a real uploaded photo, so it is
        # now gated on the parental allow_photo_avatar opt-in.
        _grant_photo_avatar_consent("superhero-premium-user")

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
        # MT-363: grant photo consent so the request passes the consent gate and
        # reaches the missing-photo (400) check under test here.
        _grant_photo_avatar_consent("superhero-nophoto-user")

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


def test_transform_superhero_blocked_when_photo_consent_false(client, app):
    """MT-363: the allow_photo_avatar gate now covers transform-superhero. A
    premium user whose parent declined photo-avatar consent is fail-closed (403)
    before the uploaded photo is read."""
    with app.app_context():
        token = _create_user("superhero-noconsent-user", "premium")
        _grant_photo_avatar_consent(
            "superhero-noconsent-user", allow_photo_avatar=False
        )

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
    assert resp.get_json()["code"] == "PHOTO_AVATAR_CONSENT_REQUIRED"


def test_generate_pet_avatar_blocked_when_photo_consent_false(client, app):
    """MT-363: generate-pet-avatar ingests a real uploaded photo (the
    companion_type='human' path sends a real face), so it is fail-closed on the
    allow_photo_avatar opt-in like the other photo routes."""
    with app.app_context():
        token = _create_user("pet-avatar-noconsent-user", "premium")
        _grant_photo_avatar_consent(
            "pet-avatar-noconsent-user", allow_photo_avatar=False
        )

    resp = client.post(
        "/avatar/generate-pet-avatar",
        data={
            "photo": (io.BytesIO(_VALID_PNG_BYTES), "pet.png"),
            "pet_name": "Buddy",
            "species": "Dog",
            "breed_description": "Golden Retriever",
            "owner_favorite_color": "Blue",
        },
        headers={"Authorization": f"Bearer {token}"},
        content_type="multipart/form-data",
    )

    assert resp.status_code == 403
    assert resp.get_json()["code"] == "PHOTO_AVATAR_CONSENT_REQUIRED"


def test_generate_custom_avatar_returns_400_for_out_of_range_age(
    client, app, monkeypatch
):
    """Out-of-range custom avatar ages should return validation error with 400."""
    with app.app_context():
        token = _create_user("custom-avatar-user-err", "free")
        _grant_photo_avatar_consent("custom-avatar-user-err")

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


# ---------------------------------------------------------------------------
# MT-363 — /generate-custom-avatar must fail-closed on the parental
# allow_photo_avatar opt-in before reading/sending the uploaded child photo.
# ---------------------------------------------------------------------------


def _custom_avatar_request(client, headers):
    return client.post(
        "/avatar/generate-custom-avatar",
        data={
            "photo": (io.BytesIO(_VALID_PNG_BYTES), "photo.png"),
            "character_name": "Luna",
            "age": "7",
            "gender": "girl",
            "eye_color": "Brown",
            "favorite_color": "Blue",
        },
        headers=headers,
        content_type="multipart/form-data",
    )


class _SpyAvatarService:
    """Stub avatar service that records whether it was ever invoked, so a
    rejected request can be asserted to never have reached the image
    provider."""

    def __init__(self):
        self.called = False

    def generate_custom_avatar(self, **kwargs):
        self.called = True
        return {
            "id": "avatar-should-not-be-reached",
            "image_base64": "data:image/png;base64,ZmFrZQ==",
        }


def test_generate_custom_avatar_allowed_when_consent_granted(client, app, monkeypatch):
    """allow_photo_avatar=True on the latest consent record permits generation."""
    with app.app_context():
        token = _create_user("photo-consent-granted-user", "free")
        _grant_photo_avatar_consent(
            "photo-consent-granted-user", allow_photo_avatar=True
        )

    spy = _SpyAvatarService()
    monkeypatch.setattr(avatar_routes, "_avatar_service", spy)

    resp = _custom_avatar_request(client, {"Authorization": f"Bearer {token}"})

    assert resp.status_code == 200
    assert resp.get_json()["status"] == "success"
    assert spy.called is True


def test_generate_custom_avatar_blocked_when_no_consent_record(
    client, app, monkeypatch
):
    """No ConsentRecord at all → fail closed with 403, image provider never called."""
    with app.app_context():
        token = _create_user("photo-consent-missing-user", "free")
        # Deliberately: no ConsentRecord created for this user at all.

    spy = _SpyAvatarService()
    monkeypatch.setattr(avatar_routes, "_avatar_service", spy)

    resp = _custom_avatar_request(client, {"Authorization": f"Bearer {token}"})

    assert resp.status_code == 403
    body = resp.get_json()
    assert body["code"] == "PHOTO_AVATAR_CONSENT_REQUIRED"
    assert spy.called is False


def test_generate_custom_avatar_blocked_when_consent_explicitly_false(
    client, app, monkeypatch
):
    """A consent record exists but allow_photo_avatar=False → still rejected."""
    with app.app_context():
        token = _create_user("photo-consent-false-user", "free")
        _grant_photo_avatar_consent(
            "photo-consent-false-user", allow_photo_avatar=False
        )

    spy = _SpyAvatarService()
    monkeypatch.setattr(avatar_routes, "_avatar_service", spy)

    resp = _custom_avatar_request(client, {"Authorization": f"Bearer {token}"})

    assert resp.status_code == 403
    body = resp.get_json()
    assert body["code"] == "PHOTO_AVATAR_CONSENT_REQUIRED"
    assert spy.called is False


def test_generate_custom_avatar_blocked_when_consent_withdrawn(
    client, app, monkeypatch
):
    """A withdrawn consent record must not satisfy the gate, even if it once
    had allow_photo_avatar=True — fail closed (CMP-8 pattern)."""
    with app.app_context():
        token = _create_user("photo-consent-withdrawn-user", "free")
        _grant_photo_avatar_consent(
            "photo-consent-withdrawn-user", allow_photo_avatar=True, withdrawn=True
        )

    spy = _SpyAvatarService()
    monkeypatch.setattr(avatar_routes, "_avatar_service", spy)

    resp = _custom_avatar_request(client, {"Authorization": f"Bearer {token}"})

    assert resp.status_code == 403
    body = resp.get_json()
    assert body["code"] == "PHOTO_AVATAR_CONSENT_REQUIRED"
    assert spy.called is False


def test_generate_custom_avatar_uses_most_recent_consent_record(
    client, app, monkeypatch
):
    """When multiple consent records exist, the gate must honor the most
    recent one (matches require_parental_consent's own ordering), not just
    whether ANY prior record ever granted the opt-in."""
    with app.app_context():
        token = _create_user("photo-consent-latest-user", "free")
        older = _grant_photo_avatar_consent(
            "photo-consent-latest-user", allow_photo_avatar=True
        )
        # Force the older record's timestamp earlier so ordering is deterministic.
        older.consent_given_at = datetime.now(timezone.utc) - timedelta(days=1)
        db.session.commit()
        # A newer record revokes the opt-in (e.g. parent changed their mind).
        _grant_photo_avatar_consent(
            "photo-consent-latest-user", allow_photo_avatar=False
        )

    spy = _SpyAvatarService()
    monkeypatch.setattr(avatar_routes, "_avatar_service", spy)

    resp = _custom_avatar_request(client, {"Authorization": f"Bearer {token}"})

    assert resp.status_code == 403
    assert spy.called is False
