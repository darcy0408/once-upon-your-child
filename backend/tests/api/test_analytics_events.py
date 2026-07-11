"""Tests for the analytics event sink (MT-249).

Covers:
  * event_tracking_service.record_event — inserts a row, and the critical
    never-raises invariant when the DB write fails;
  * POST /analytics/event — allowlist validation, anonymous acceptance, and
    server-side tier/user_id resolution from a token;
  * the avatar_limit_hit emission at the 1-free-avatar 403 gate.
"""

import io
from datetime import datetime, timedelta, timezone

import jwt

from backend.database import db
from backend.models import User
from backend.models.analytics_event import AnalyticsEvent
from backend.models.consent_record import ConsentRecord
from backend.routes import avatar_routes
from backend.services.event_tracking_service import record_event

# Minimal valid PNG signature so the avatar route's magic-byte check accepts it.
_VALID_PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32


def _create_user(user_id: str, tier: str, custom_avatars_generated: int = 0) -> str:
    """Create a user (with an optional avatar count) and return a JWT token."""
    user = User(
        id=user_id,
        username=user_id,
        email=f"{user_id}@example.com",
        password_hash="hash",
        subscription_tier=tier,
        role="user",
        custom_avatars_generated=custom_avatars_generated,
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


# ---------------------------------------------------------------------------
# record_event service
# ---------------------------------------------------------------------------


def test_record_event_inserts_row(app):
    with app.app_context():
        record_event(
            "paywall_viewed",
            user_id="u-1",
            tier="free",
            metadata={"required_feature": "unlimited_stories"},
        )

        row = AnalyticsEvent.query.filter_by(event_name="paywall_viewed").one()
        assert row.user_id == "u-1"
        assert row.tier == "free"
        assert row.event_metadata == {"required_feature": "unlimited_stories"}
        assert row.created_at is not None


def test_record_event_allows_anonymous(app):
    with app.app_context():
        record_event("paywall_viewed")
        row = AnalyticsEvent.query.filter_by(event_name="paywall_viewed").one()
        assert row.user_id is None
        assert row.tier is None
        # Metadata defaults to {} rather than NULL.
        assert row.event_metadata == {}


def test_record_event_never_raises_on_db_failure(app, monkeypatch):
    """The core invariant: a DB write failure is swallowed, not propagated."""
    with app.app_context():

        def _boom():
            raise RuntimeError("db exploded")

        monkeypatch.setattr(db.session, "commit", _boom)

        # Must not raise despite the commit blowing up.
        record_event("paywall_viewed", user_id="u-2", tier="free")

        # And nothing was persisted.
        assert AnalyticsEvent.query.count() == 0


def test_record_event_never_raises_on_import_or_model_failure(app, monkeypatch):
    """Even a broken model constructor must not surface to the caller."""
    with app.app_context():

        class _Boom:
            def __init__(self, *a, **k):
                raise ValueError("bad model")

        # record_event imports the model at call time, so patching the class on
        # its module makes construction raise inside the try block.
        monkeypatch.setattr("backend.models.analytics_event.AnalyticsEvent", _Boom)

        # Should swallow the ValueError — must not propagate to the caller.
        record_event("paywall_viewed", user_id="u-3")


# ---------------------------------------------------------------------------
# POST /analytics/event
# ---------------------------------------------------------------------------


def test_analytics_event_accepts_allowlisted_anonymous(client, app):
    resp = client.post("/analytics/event", json={"event_name": "paywall_viewed"})
    assert resp.status_code == 202
    assert resp.get_json()["status"] == "accepted"

    with app.app_context():
        row = AnalyticsEvent.query.filter_by(event_name="paywall_viewed").one()
        assert row.user_id is None
        # Anonymous requests default to the 'free' tier.
        assert row.tier == "free"


def test_analytics_event_rejects_unknown_event(client, app):
    resp = client.post("/analytics/event", json={"event_name": "hacked_event"})
    assert resp.status_code == 400
    assert resp.get_json()["error_code"] == "INVALID_EVENT"

    with app.app_context():
        assert AnalyticsEvent.query.count() == 0


def test_analytics_event_rejects_missing_event_name(client, app):
    resp = client.post("/analytics/event", json={})
    assert resp.status_code == 400
    assert resp.get_json()["error_code"] == "INVALID_EVENT"


def test_analytics_event_resolves_tier_and_user_from_token(client, app):
    with app.app_context():
        token = _create_user("premium-analytics-user", "premium")

    resp = client.post(
        "/analytics/event",
        json={"event_name": "upgrade_clicked", "metadata": {"plan": "premium"}},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 202

    with app.app_context():
        row = AnalyticsEvent.query.filter_by(event_name="upgrade_clicked").one()
        assert row.user_id == "premium-analytics-user"
        assert row.tier == "premium"
        assert row.event_metadata == {"plan": "premium"}


def test_analytics_event_sanitizes_metadata(client, app):
    """Nested/oversized metadata is dropped; scalars are kept and truncated."""
    resp = client.post(
        "/analytics/event",
        json={
            "event_name": "paywall_viewed",
            "metadata": {
                "ok_str": "x" * 500,
                "ok_int": 3,
                "ok_bool": True,
                "nested": {"drop": "me"},
                "list": [1, 2, 3],
            },
        },
    )
    assert resp.status_code == 202

    with app.app_context():
        row = AnalyticsEvent.query.filter_by(event_name="paywall_viewed").one()
        meta = row.event_metadata
        assert meta["ok_int"] == 3
        assert meta["ok_bool"] is True
        assert len(meta["ok_str"]) == 200  # truncated
        assert "nested" not in meta
        assert "list" not in meta


# ---------------------------------------------------------------------------
# avatar_limit_hit emission
# ---------------------------------------------------------------------------


def test_avatar_limit_hit_emitted_at_403_gate(client, app):
    """A free user past the 1-free-avatar gate emits avatar_limit_hit + 403."""
    with app.app_context():
        token = _create_user("avatar-limit-user", "free", custom_avatars_generated=1)
        # MT-363: this test exercises the 1-free-avatar gate, which sits
        # behind the photo-avatar consent gate — grant consent so the request
        # reaches that gate instead of being rejected earlier for a different
        # reason.
        db.session.add(
            ConsentRecord(
                user_id="avatar-limit-user",
                child_age=9,
                consent_method="parent",
                allow_photo_avatar=True,
            )
        )
        db.session.commit()

    resp = client.post(
        "/avatar/generate-custom-avatar",
        data={
            "photo": (io.BytesIO(_VALID_PNG_BYTES), "photo.png"),
            "character_name": "Luna",
            "age": "7",
            "gender": "girl",
            "eye_color": "Brown",
            "favorite_color": "Blue",
        },
        headers={"Authorization": f"Bearer {token}"},
        content_type="multipart/form-data",
    )

    assert resp.status_code == 403
    assert resp.get_json()["error_code"] == "UPGRADE_REQUIRED"

    with app.app_context():
        row = AnalyticsEvent.query.filter_by(event_name="avatar_limit_hit").one()
        assert row.user_id == "avatar-limit-user"
        assert row.tier == "free"
        assert row.event_metadata == {"used": 1, "limit": 1}


def test_avatar_limit_hit_not_emitted_on_success(client, app, monkeypatch):
    """A free user under the gate generates normally with no limit event."""
    with app.app_context():
        token = _create_user("avatar-ok-user", "free", custom_avatars_generated=0)
        # MT-363: grant photo-avatar consent so this success-path test isn't
        # rejected by the (unrelated) photo-avatar consent gate.
        db.session.add(
            ConsentRecord(
                user_id="avatar-ok-user",
                child_age=9,
                consent_method="parent",
                allow_photo_avatar=True,
            )
        )
        db.session.commit()

    class _StubAvatarService:
        def generate_custom_avatar(self, **kwargs):
            return {
                "id": "avatar-ok",
                "image_base64": "data:image/png;base64,ZmFrZQ==",
            }

    monkeypatch.setattr(avatar_routes, "_avatar_service", _StubAvatarService())

    resp = client.post(
        "/avatar/generate-custom-avatar",
        data={
            "photo": (io.BytesIO(_VALID_PNG_BYTES), "photo.png"),
            "character_name": "Luna",
            "age": "7",
            "gender": "girl",
            "eye_color": "Brown",
            "favorite_color": "Blue",
        },
        headers={"Authorization": f"Bearer {token}"},
        content_type="multipart/form-data",
    )

    assert resp.status_code == 200
    with app.app_context():
        assert (
            AnalyticsEvent.query.filter_by(event_name="avatar_limit_hit").count() == 0
        )
