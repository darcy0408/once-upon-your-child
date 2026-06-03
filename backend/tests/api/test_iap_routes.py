"""Route-level tests for the in-app-purchase endpoints (iap_routes.py) — CQ-04.

iap_routes.py was at 25% coverage with no route-level test file. These tests
lock down the Phase-1 **fail-CLOSED** contract:

  * the verify endpoints must NEVER grant entitlement off an unverified receipt
    (verification disabled -> 503; even with the flag flipped on, the Phase-1
    stub raising NotImplementedError must surface as 502, not a silent grant);
  * the server-to-server notification endpoints must reject an unverifiable
    payload (403) or fail closed when verification is unconfigured (503), and
    only ACK (200, handled=False) once the store signature verifies.

A regression flipping any of these to a success/grant is a revenue + security
hole, so they are pinned here.
"""

import uuid
from datetime import UTC, datetime, timedelta

import jwt

from backend.database import db
from backend.models.user import User
from backend.utils.iap_notification_verify import (
    IapVerificationConfigError,
    IapVerificationError,
)


def _auth_headers(user_id):
    token = jwt.encode(
        {
            "user_id": user_id,
            "sub": user_id,
            "exp": int((datetime.now(UTC) + timedelta(hours=1)).timestamp()),
        },
        "dev-secret-key",
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def _create_user(app):
    with app.app_context():
        user = User(
            id=str(uuid.uuid4()),
            username=f"user_{uuid.uuid4().hex[:8]}",
            email=f"{uuid.uuid4().hex[:8]}@example.com",
            password_hash="hashed",
            subscription_tier="free",
            role="user",
        )
        db.session.add(user)
        db.session.commit()
        return user.id


# ---------------------------------------------------------------------------
# Receipt verification — fail-closed
# ---------------------------------------------------------------------------


def test_apple_verify_requires_auth(client):
    resp = client.post(
        "/api/iap/apple/verify",
        json={"product_id": "premium_monthly", "verification_data": "x"},
    )
    assert resp.status_code == 401


def test_apple_verify_missing_verification_data_returns_400(client, app):
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/apple/verify",
        json={"product_id": "premium_monthly"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 400
    assert "verification_data" in resp.get_json()["error"]


def test_apple_verify_unknown_product_returns_400(client, app):
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/apple/verify",
        json={"product_id": "not_a_real_product", "verification_data": "x"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 400
    assert resp.get_json()["error"] == "Unknown subscription product"


def test_apple_verify_disabled_fails_closed_503(client, app, monkeypatch):
    monkeypatch.delenv("IAP_VERIFICATION_ENABLED", raising=False)
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/apple/verify",
        json={"product_id": "premium_monthly", "verification_data": "x"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 503
    assert resp.get_json()["code"] == "iap_not_configured"


def test_apple_verify_enabled_but_unimplemented_returns_502_without_granting(
    client, app, monkeypatch
):
    # Even if someone flips IAP_VERIFICATION_ENABLED on before the Phase-2
    # store calls exist, the stub raises NotImplementedError, which must surface
    # as 502 — and the user must NOT be upgraded.
    monkeypatch.setenv("IAP_VERIFICATION_ENABLED", "true")
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/apple/verify",
        json={"product_id": "premium_monthly", "verification_data": "x"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 502
    with app.app_context():
        user = db.session.get(User, uid)
        # No entitlement granted: tier is unchanged. (subscription_status is not
        # asserted — the User model defaults it to "active" regardless of tier.)
        assert user.subscription_tier == "free"


def test_google_verify_disabled_fails_closed_503(client, app, monkeypatch):
    monkeypatch.delenv("IAP_VERIFICATION_ENABLED", raising=False)
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/google/verify",
        json={"product_id": "family_monthly", "verification_data": "token"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 503
    assert resp.get_json()["code"] == "iap_not_configured"


def test_google_verify_unknown_product_returns_400(client, app):
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/google/verify",
        json={"product_id": "bogus", "verification_data": "token"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 400


# ---------------------------------------------------------------------------
# S2S notifications — signature gate (verify funcs are patched at the module
# they were imported into).
# ---------------------------------------------------------------------------


def test_apple_notifications_unconfigured_fails_closed_503(client, monkeypatch):
    def _raise(*a, **k):
        raise IapVerificationConfigError("Apple root CA not bundled")

    monkeypatch.setattr("backend.routes.iap_routes.verify_apple_jws", _raise)
    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "x"})
    assert resp.status_code == 503


def test_apple_notifications_bad_signature_rejected_403(client, monkeypatch):
    def _raise(*a, **k):
        raise IapVerificationError("signature mismatch")

    monkeypatch.setattr("backend.routes.iap_routes.verify_apple_jws", _raise)
    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "x"})
    assert resp.status_code == 403


def test_apple_notifications_valid_acks_stub_without_applying(client, monkeypatch):
    monkeypatch.setattr(
        "backend.routes.iap_routes.verify_apple_jws", lambda *a, **k: {"ok": True}
    )
    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "x"})
    assert resp.status_code == 200
    assert resp.get_json()["handled"] is False


def test_google_notifications_unconfigured_fails_closed_503(client, monkeypatch):
    def _raise(*a, **k):
        raise IapVerificationConfigError("GOOGLE_PUBSUB_AUDIENCE unset")

    monkeypatch.setattr("backend.routes.iap_routes.verify_google_pubsub_oidc", _raise)
    resp = client.post("/api/iap/google/notifications", json={})
    assert resp.status_code == 503


def test_google_notifications_bad_token_rejected_403(client, monkeypatch):
    def _raise(*a, **k):
        raise IapVerificationError("invalid OIDC token")

    monkeypatch.setattr("backend.routes.iap_routes.verify_google_pubsub_oidc", _raise)
    resp = client.post("/api/iap/google/notifications", json={})
    assert resp.status_code == 403


def test_google_notifications_valid_acks_stub_without_applying(client, monkeypatch):
    monkeypatch.setattr(
        "backend.routes.iap_routes.verify_google_pubsub_oidc",
        lambda *a, **k: {"ok": True},
    )
    resp = client.post("/api/iap/google/notifications", json={})
    assert resp.status_code == 200
    assert resp.get_json()["handled"] is False
