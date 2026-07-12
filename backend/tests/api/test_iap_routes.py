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
from backend.models.iap_event import IapPurchase
from backend.models.user import User
from backend.routes.iap_routes import (
    _map_apple_receipt,
    _map_google_subscription,
    _parse_rfc3339,
)
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


def test_apple_verify_enabled_but_unconfigured_fails_closed_503(
    client, app, monkeypatch
):
    # Flag flipped on but APP_STORE_SHARED_SECRET not provisioned -> fail CLOSED
    # with 503 (never a blind grant, never a 502). Reaches no network.
    monkeypatch.setenv("IAP_VERIFICATION_ENABLED", "true")
    monkeypatch.delenv("APP_STORE_SHARED_SECRET", raising=False)
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/apple/verify",
        json={"product_id": "premium_monthly", "verification_data": "x"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 503
    assert resp.get_json()["code"] == "iap_not_configured"
    with app.app_context():
        assert db.session.get(User, uid).subscription_tier == "free"


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


# ---------------------------------------------------------------------------
# Google verify — real Play Developer API mapping (store call patched).
# The verification flag is flipped on and _fetch_google_subscriptionv2 (the
# network/credential boundary) is patched, so these exercise the entitlement
# mapping without hitting Google.
# ---------------------------------------------------------------------------


def _future_iso(days=30):
    return (datetime.now(UTC) + timedelta(days=days)).isoformat()


def test_google_verify_active_grants_premium(client, app, monkeypatch):
    monkeypatch.setenv("IAP_VERIFICATION_ENABLED", "true")
    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_google_subscriptionv2",
        lambda *a, **k: {
            "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
            "latestOrderId": "GPA.1234-5678-9012-34567",
            "lineItems": [
                {"productId": "premium_monthly", "expiryTime": _future_iso()}
            ],
        },
    )
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/google/verify",
        json={"product_id": "premium_monthly", "verification_data": "tok"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 200
    assert resp.get_json()["tier"] == "premium"
    with app.app_context():
        assert db.session.get(User, uid).subscription_tier == "premium"
        # Keyed by the purchase token (stable), not latestOrderId.
        purchase = IapPurchase.query.filter_by(user_id=uid).first()
        assert purchase is not None
        assert purchase.store_transaction_id == "tok"


def test_google_verify_product_mismatch_returns_400(client, app, monkeypatch):
    # Token resolves to a different product than the client claimed -> reject,
    # never grant.
    monkeypatch.setenv("IAP_VERIFICATION_ENABLED", "true")
    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_google_subscriptionv2",
        lambda *a, **k: {
            "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
            "lineItems": [{"productId": "premium_annual", "expiryTime": _future_iso()}],
        },
    )
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/google/verify",
        json={"product_id": "premium_monthly", "verification_data": "tok"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 400
    with app.app_context():
        assert db.session.get(User, uid).subscription_tier == "free"


def test_google_verify_expired_records_without_granting(client, app, monkeypatch):
    monkeypatch.setenv("IAP_VERIFICATION_ENABLED", "true")
    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_google_subscriptionv2",
        lambda *a, **k: {
            "subscriptionState": "SUBSCRIPTION_STATE_EXPIRED",
            "latestOrderId": "GPA.9",
            "lineItems": [
                {"productId": "premium_monthly", "expiryTime": _future_iso(-1)}
            ],
        },
    )
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/google/verify",
        json={"product_id": "premium_monthly", "verification_data": "tok"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 200
    with app.app_context():
        # A real but non-granting state must leave the user on free.
        assert db.session.get(User, uid).subscription_tier == "free"


def test_google_verify_enabled_but_unconfigured_fails_closed_503(
    client, app, monkeypatch
):
    # Flag on but no service-account creds -> 503, not a blind grant or a 502.
    monkeypatch.setenv("IAP_VERIFICATION_ENABLED", "true")
    monkeypatch.delenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", raising=False)
    monkeypatch.delenv("ANDROID_PACKAGE_NAME", raising=False)
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/google/verify",
        json={"product_id": "premium_monthly", "verification_data": "tok"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 503
    assert resp.get_json()["code"] == "iap_not_configured"
    with app.app_context():
        assert db.session.get(User, uid).subscription_tier == "free"


# ---------------------------------------------------------------------------
# Pure mapping unit tests (no Flask app / no network).
# ---------------------------------------------------------------------------


def test_map_google_subscription_active_grants():
    result = _map_google_subscription(
        {
            "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
            "latestOrderId": "GPA.1",
            "lineItems": [
                {"productId": "premium_monthly", "expiryTime": "2099-01-01T00:00:00Z"}
            ],
        },
        "premium_monthly",
    )
    assert result["valid"] is True
    assert result["status"] == "active"
    assert result["expires_at"].year == 2099


def test_map_google_subscription_canceled_still_active():
    # Auto-renew off but access continues until expiry.
    result = _map_google_subscription(
        {
            "subscriptionState": "SUBSCRIPTION_STATE_CANCELED",
            "lineItems": [
                {"productId": "premium_monthly", "expiryTime": "2099-01-01T00:00:00Z"}
            ],
        },
        "premium_monthly",
    )
    assert result["status"] == "active"


def test_map_google_subscription_grace_period():
    result = _map_google_subscription(
        {
            "subscriptionState": "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
            "lineItems": [{"productId": "premium_monthly"}],
        },
        "premium_monthly",
    )
    assert result["status"] == "grace_period"


def test_map_google_subscription_expired_is_inactive():
    result = _map_google_subscription(
        {
            "subscriptionState": "SUBSCRIPTION_STATE_EXPIRED",
            "lineItems": [{"productId": "premium_monthly"}],
        },
        "premium_monthly",
    )
    assert result["valid"] is True
    assert result["status"] == "inactive"


def test_map_google_subscription_product_mismatch_invalid():
    result = _map_google_subscription(
        {
            "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
            "lineItems": [{"productId": "premium_annual"}],
        },
        "premium_monthly",
    )
    assert result["valid"] is False


def test_parse_rfc3339_handles_z_and_nanoseconds():
    # Trailing Z + 9-digit fractional seconds (Google sends nanoseconds).
    parsed = _parse_rfc3339("2026-08-11T12:34:56.123456789Z")
    assert parsed is not None
    assert parsed.year == 2026
    assert parsed.tzinfo is not None
    assert parsed.microsecond == 123456
    assert _parse_rfc3339(None) is None
    assert _parse_rfc3339("garbage") is None


# ---------------------------------------------------------------------------
# Apple verify — verifyReceipt mapping (store call patched).
# ---------------------------------------------------------------------------


def test_apple_verify_active_grants_premium(client, app, monkeypatch):
    monkeypatch.setenv("IAP_VERIFICATION_ENABLED", "true")
    future_ms = str(int((datetime.now(UTC) + timedelta(days=30)).timestamp() * 1000))
    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_apple_verify_receipt",
        lambda *a, **k: {
            "status": 0,
            "latest_receipt_info": [
                {
                    "product_id": "premium_monthly",
                    "expires_date_ms": future_ms,
                    "original_transaction_id": "1000000",
                }
            ],
        },
    )
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/apple/verify",
        json={"product_id": "premium_monthly", "verification_data": "rcpt"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 200
    assert resp.get_json()["tier"] == "premium"
    with app.app_context():
        assert db.session.get(User, uid).subscription_tier == "premium"


def test_apple_verify_expired_records_without_granting(client, app, monkeypatch):
    # status 21006 = valid receipt, subscription expired -> no grant.
    monkeypatch.setenv("IAP_VERIFICATION_ENABLED", "true")
    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_apple_verify_receipt",
        lambda *a, **k: {
            "status": 21006,
            "latest_receipt_info": [
                {
                    "product_id": "premium_monthly",
                    "expires_date_ms": "1000000000000",
                    "original_transaction_id": "1000000",
                }
            ],
        },
    )
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/apple/verify",
        json={"product_id": "premium_monthly", "verification_data": "rcpt"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 200
    with app.app_context():
        assert db.session.get(User, uid).subscription_tier == "free"


def test_apple_verify_bad_receipt_returns_400(client, app, monkeypatch):
    monkeypatch.setenv("IAP_VERIFICATION_ENABLED", "true")
    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_apple_verify_receipt",
        lambda *a, **k: {"status": 21002},  # malformed receipt-data
    )
    uid = _create_user(app)
    resp = client.post(
        "/api/iap/apple/verify",
        json={"product_id": "premium_monthly", "verification_data": "rcpt"},
        headers=_auth_headers(uid),
    )
    assert resp.status_code == 400
    with app.app_context():
        assert db.session.get(User, uid).subscription_tier == "free"


def test_map_apple_receipt_active_grants():
    result = _map_apple_receipt(
        {
            "status": 0,
            "latest_receipt_info": [
                {
                    "product_id": "premium_annual",
                    "expires_date_ms": "4102444800000",  # 2100-01-01
                    "original_transaction_id": "999",
                }
            ],
        },
        "premium_annual",
    )
    assert result["valid"] is True
    assert result["status"] == "active"
    assert result["store_transaction_id"] == "999"
    assert result["expires_at"].year >= 2099


def test_map_apple_receipt_expired_status_is_inactive():
    result = _map_apple_receipt(
        {
            "status": 21006,
            "latest_receipt_info": [
                {"product_id": "premium_monthly", "expires_date_ms": "1000000000000"}
            ],
        },
        "premium_monthly",
    )
    assert result["valid"] is True
    assert result["status"] == "inactive"


def test_map_apple_receipt_status0_past_expiry_is_inactive():
    result = _map_apple_receipt(
        {
            "status": 0,
            "latest_receipt_info": [
                {"product_id": "premium_monthly", "expires_date_ms": "1000000000000"}
            ],
        },
        "premium_monthly",
    )
    assert result["status"] == "inactive"


def test_map_apple_receipt_product_mismatch_invalid():
    result = _map_apple_receipt(
        {
            "status": 0,
            "latest_receipt_info": [
                {"product_id": "premium_annual", "expires_date_ms": "4102444800000"}
            ],
        },
        "premium_monthly",
    )
    assert result["valid"] is False


def test_map_apple_receipt_bad_status_invalid():
    result = _map_apple_receipt({"status": 21003}, "premium_monthly")
    assert result["valid"] is False
