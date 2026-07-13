"""Route-level tests for the in-app-purchase endpoints (iap_routes.py) — CQ-04.

These tests lock down the **fail-CLOSED** contract:

  * the verify endpoints must NEVER grant entitlement off an unverified receipt
    (verification disabled or unconfigured -> 503, never a silent grant);
  * the server-to-server notification endpoints must reject an unverifiable
    payload (403) or fail closed when verification is unconfigured (503);
  * the S2S handlers (MT-350 chunk D) must dedup on the store notification ID,
    drop stale out-of-order deliveries, request a retry (404) for purchases the
    /verify path hasn't recorded yet, and apply renewals / cancellations /
    refunds through the shared apply_entitlement() path.

A regression flipping any of these to a success/grant is a revenue + security
hole, so they are pinned here.
"""

import base64
import json
import uuid
from datetime import UTC, datetime, timedelta

import jwt

from backend.database import db
from backend.models.iap_event import IapNotificationEvent, IapPurchase
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


def test_apple_notifications_payload_without_transaction_acks(client, monkeypatch):
    # A verified payload with no data.signedTransactionInfo (e.g. a TEST
    # notification) is acknowledged without touching entitlement.
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


def test_google_notifications_empty_envelope_acks(client, monkeypatch):
    # A verified push with no message data is acknowledged without touching
    # entitlement.
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


# ===========================================================================
# S2S notification handlers (MT-350 chunk D) — renewals / cancels / refunds.
# The signature gates are patched (their own tests are above); these exercise
# dedup, ordering, the unknown-purchase retry contract, and entitlement.
# ===========================================================================


def _naive_utc_now():
    return datetime.now(UTC).replace(tzinfo=None)


def _ms(dt):
    """Millisecond-epoch string, as Apple sends timestamps."""
    return int(dt.timestamp() * 1000)


def _seed_purchase(
    app,
    user_id,
    *,
    store="apple",
    token="txn-1",
    product_id="premium_monthly",
    tier="premium",
    status="active",
    expires_at=None,
    last_event_time=None,
):
    with app.app_context():
        purchase = IapPurchase(
            user_id=user_id,
            store=store,
            product_id=product_id,
            tier=tier,
            store_transaction_id=token,
            status=status,
            expires_at=expires_at,
            last_event_time=last_event_time,
        )
        db.session.add(purchase)
        db.session.commit()
        return purchase.id


def _make_premium(app, user_id):
    with app.app_context():
        user = db.session.get(User, user_id)
        user.subscription_tier = "premium"
        user.subscription_status = "active"
        db.session.commit()


def _get_user(app, user_id):
    with app.app_context():
        user = db.session.get(User, user_id)
        db.session.refresh(user)
        return user.to_dict() if hasattr(user, "to_dict") else user.__dict__.copy()


def _purchase_row(app, token):
    with app.app_context():
        row = IapPurchase.query.filter_by(store_transaction_id=token).first()
        return row.to_dict() if row else None


def _event_count(app):
    with app.app_context():
        return IapNotificationEvent.query.count()


# --- Apple ------------------------------------------------------------------


def _patch_apple_jws(monkeypatch, outer_payload, txn_payload=None):
    """Dispatch fake: 'OUTER' -> outer payload, 'TXN' -> transaction payload."""
    mapping = {"OUTER": outer_payload}
    if txn_payload is not None:
        mapping["TXN"] = txn_payload

    def fake(jws):
        if jws in mapping:
            return mapping[jws]
        raise IapVerificationError("unknown JWS")

    monkeypatch.setattr("backend.routes.iap_routes.verify_apple_jws", fake)


def _apple_payload(
    notification_type,
    *,
    subtype=None,
    notification_uuid="uuid-1",
    signed_date_ms=None,
):
    payload = {
        "notificationType": notification_type,
        "notificationUUID": notification_uuid,
        "signedDate": signed_date_ms or _ms(datetime.now(UTC)),
        "data": {"signedTransactionInfo": "TXN"},
    }
    if subtype:
        payload["subtype"] = subtype
    return payload


def _apple_txn(
    *,
    original_transaction_id="txn-1",
    product_id="premium_monthly",
    expires_ms=None,
    revocation_ms=None,
):
    txn = {
        "originalTransactionId": original_transaction_id,
        "productId": product_id,
        "expiresDate": expires_ms,
    }
    if revocation_ms is not None:
        txn["revocationDate"] = revocation_ms
    return txn


def test_apple_notification_renewal_applies_entitlement(client, app, monkeypatch):
    uid = _create_user(app)
    _seed_purchase(app, uid, status="expired", expires_at=_naive_utc_now())
    future = datetime.now(UTC) + timedelta(days=30)
    _patch_apple_jws(
        monkeypatch,
        _apple_payload("DID_RENEW"),
        _apple_txn(expires_ms=_ms(future)),
    )

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.status_code == 200
    assert resp.get_json()["handled"] is True
    assert _get_user(app, uid)["subscription_tier"] == "premium"
    row = _purchase_row(app, "txn-1")
    assert row["status"] == "active"
    assert row["expires_at"] is not None
    assert _event_count(app) == 1


def test_apple_notification_expired_revokes(client, app, monkeypatch):
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid)
    past = datetime.now(UTC) - timedelta(days=1)
    _patch_apple_jws(
        monkeypatch,
        _apple_payload("EXPIRED"),
        _apple_txn(expires_ms=_ms(past)),
    )

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.status_code == 200
    assert resp.get_json()["handled"] is True
    assert _get_user(app, uid)["subscription_tier"] == "free"
    assert _purchase_row(app, "txn-1")["status"] == "expired"


def test_apple_notification_refund_revokes(client, app, monkeypatch):
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid)
    future = datetime.now(UTC) + timedelta(days=20)
    _patch_apple_jws(
        monkeypatch,
        _apple_payload("REFUND"),
        # Refund revokes NOW even though the paid-through date is in the future.
        _apple_txn(expires_ms=_ms(future), revocation_ms=_ms(datetime.now(UTC))),
    )

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.status_code == 200
    assert _get_user(app, uid)["subscription_tier"] == "free"
    assert _purchase_row(app, "txn-1")["status"] == "refunded"


def test_apple_notification_duplicate_uuid_is_noop(client, app, monkeypatch):
    uid = _create_user(app)
    _seed_purchase(app, uid, status="expired")
    future = datetime.now(UTC) + timedelta(days=30)
    _patch_apple_jws(
        monkeypatch,
        _apple_payload("DID_RENEW", notification_uuid="dup-1"),
        _apple_txn(expires_ms=_ms(future)),
    )

    first = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})
    second = client.post(
        "/api/iap/apple/notifications", json={"signedPayload": "OUTER"}
    )

    assert first.get_json()["handled"] is True
    assert second.status_code == 200
    assert second.get_json()["handled"] is False
    assert second.get_json()["reason"] == "duplicate"
    assert _event_count(app) == 1
    assert _get_user(app, uid)["subscription_tier"] == "premium"


def test_apple_notification_unknown_transaction_requests_retry(
    client, app, monkeypatch
):
    # No IapPurchase row (the /verify call hasn't landed yet) -> 404 so Apple
    # retries; nothing may be committed, or the retry would dedup-skip.
    future = datetime.now(UTC) + timedelta(days=30)
    _patch_apple_jws(
        monkeypatch,
        _apple_payload("SUBSCRIBED"),
        _apple_txn(original_transaction_id="never-seen", expires_ms=_ms(future)),
    )

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.status_code == 404
    assert _event_count(app) == 0


def test_apple_notification_stale_event_dropped(client, app, monkeypatch):
    # An out-of-order OLD notification must not regress newer applied state.
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid, last_event_time=_naive_utc_now())
    stale_date = datetime.now(UTC) - timedelta(days=3)
    _patch_apple_jws(
        monkeypatch,
        _apple_payload("EXPIRED", signed_date_ms=_ms(stale_date)),
        _apple_txn(expires_ms=_ms(stale_date)),
    )

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.status_code == 200
    assert resp.get_json()["handled"] is False
    assert resp.get_json()["reason"] == "stale"
    assert _get_user(app, uid)["subscription_tier"] == "premium"
    assert _purchase_row(app, "txn-1")["status"] == "active"
    # The stale notification ID is still recorded, so a redelivery of the same
    # stale payload short-circuits as a duplicate.
    assert _event_count(app) == 1


def test_apple_notification_grace_period_keeps_access(client, app, monkeypatch):
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid)
    past = datetime.now(UTC) - timedelta(hours=6)
    _patch_apple_jws(
        monkeypatch,
        _apple_payload("DID_FAIL_TO_RENEW", subtype="GRACE_PERIOD"),
        _apple_txn(expires_ms=_ms(past)),
    )

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.get_json()["handled"] is True
    assert _get_user(app, uid)["subscription_tier"] == "premium"
    assert _purchase_row(app, "txn-1")["status"] == "grace_period"


def test_apple_notification_billing_retry_without_grace_revokes(
    client, app, monkeypatch
):
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid)
    past = datetime.now(UTC) - timedelta(hours=6)
    _patch_apple_jws(
        monkeypatch,
        _apple_payload("DID_FAIL_TO_RENEW"),
        _apple_txn(expires_ms=_ms(past)),
    )

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.get_json()["handled"] is True
    assert _get_user(app, uid)["subscription_tier"] == "free"
    assert _purchase_row(app, "txn-1")["status"] == "on_hold"


def test_apple_notification_auto_renew_disabled_keeps_access_until_expiry(
    client, app, monkeypatch
):
    # User turned auto-renew off: access continues to period end (like
    # Google's CANCELED state), with cancel_at_period_end flagged.
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid)
    future = datetime.now(UTC) + timedelta(days=12)
    _patch_apple_jws(
        monkeypatch,
        _apple_payload("DID_CHANGE_RENEWAL_STATUS", subtype="AUTO_RENEW_DISABLED"),
        _apple_txn(expires_ms=_ms(future)),
    )

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.get_json()["handled"] is True
    user = _get_user(app, uid)
    assert user["subscription_tier"] == "premium"
    assert user["cancel_at_period_end"] is True


def test_apple_notification_missing_expiry_fails_closed(client, app, monkeypatch):
    # A renewal-ish payload with no expiresDate must not grant open-ended
    # access.
    uid = _create_user(app)
    _seed_purchase(app, uid, status="expired")
    _patch_apple_jws(
        monkeypatch,
        _apple_payload("DID_RENEW"),
        _apple_txn(expires_ms=None),
    )

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.get_json()["handled"] is True
    assert _get_user(app, uid)["subscription_tier"] == "free"


def test_apple_verify_shared_receipt_rejected_409(client, app, monkeypatch):
    # Review H1: a receipt already registered to user A must not grant user B.
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
                    "original_transaction_id": "shared-txn",
                }
            ],
        },
    )
    owner_uid = _create_user(app)
    _seed_purchase(app, owner_uid, token="shared-txn")
    attacker_uid = _create_user(app)

    resp = client.post(
        "/api/iap/apple/verify",
        json={"product_id": "premium_monthly", "verification_data": "rcpt"},
        headers=_auth_headers(attacker_uid),
    )

    assert resp.status_code == 409
    assert resp.get_json()["code"] == "receipt_owned_elsewhere"
    assert _get_user(app, attacker_uid)["subscription_tier"] == "free"
    assert _purchase_row(app, "shared-txn")["user_id"] == owner_uid


def test_google_verify_shared_token_rejected_409(client, app, monkeypatch):
    monkeypatch.setenv("IAP_VERIFICATION_ENABLED", "true")
    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_google_subscriptionv2",
        lambda *a, **k: {
            "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
            "lineItems": [
                {"productId": "premium_monthly", "expiryTime": _future_iso()}
            ],
        },
    )
    owner_uid = _create_user(app)
    _seed_purchase(app, owner_uid, store="google", token="shared-tok")
    attacker_uid = _create_user(app)

    resp = client.post(
        "/api/iap/google/verify",
        json={"product_id": "premium_monthly", "verification_data": "shared-tok"},
        headers=_auth_headers(attacker_uid),
    )

    assert resp.status_code == 409
    assert _get_user(app, attacker_uid)["subscription_tier"] == "free"
    assert _purchase_row(app, "shared-tok")["user_id"] == owner_uid


def test_apple_notification_foreign_bundle_acks_without_change(
    client, app, monkeypatch
):
    # A genuine Apple payload for a DIFFERENT app must not touch entitlement
    # when IOS_BUNDLE_ID is configured.
    monkeypatch.setenv("IOS_BUNDLE_ID", "app.onceuponyourchild")
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid)
    past = datetime.now(UTC) - timedelta(days=1)
    txn = _apple_txn(expires_ms=_ms(past))
    txn["bundleId"] = "com.someoneelse.app"
    _patch_apple_jws(monkeypatch, _apple_payload("EXPIRED"), txn)

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.status_code == 200
    assert resp.get_json()["handled"] is False
    assert resp.get_json()["reason"] == "bundle mismatch"
    assert _get_user(app, uid)["subscription_tier"] == "premium"
    assert _event_count(app) == 0


def test_apple_notification_bad_inner_jws_rejected_403(client, app, monkeypatch):
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid)
    # Outer verifies; inner signedTransactionInfo does not -> 403, no change.
    _patch_apple_jws(monkeypatch, _apple_payload("DID_RENEW"), txn_payload=None)

    resp = client.post("/api/iap/apple/notifications", json={"signedPayload": "OUTER"})

    assert resp.status_code == 403
    assert _get_user(app, uid)["subscription_tier"] == "premium"


# --- Google -----------------------------------------------------------------


def _patch_google_oidc(monkeypatch):
    monkeypatch.setattr(
        "backend.routes.iap_routes.verify_google_pubsub_oidc",
        lambda *a, **k: {"email": "pubsub@google.iam"},
    )


def _pubsub_envelope(notification, message_id="msg-1"):
    data = base64.b64encode(json.dumps(notification).encode()).decode()
    return {
        "message": {"data": data, "messageId": message_id},
        "subscription": "projects/p/subscriptions/s",
    }


def _rtdn(
    purchase_token="tok-1",
    notification_type=2,
    subscription_id="premium_monthly",
):
    return {
        "version": "1.0",
        "packageName": "app.onceuponyourchild",
        "eventTimeMillis": str(_ms(datetime.now(UTC))),
        "subscriptionNotification": {
            "version": "1.0",
            "notificationType": notification_type,
            "purchaseToken": purchase_token,
            "subscriptionId": subscription_id,
        },
    }


def test_google_notification_renewal_applies_entitlement(client, app, monkeypatch):
    _patch_google_oidc(monkeypatch)
    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_google_subscriptionv2",
        lambda *a, **k: {
            "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
            "lineItems": [
                {"productId": "premium_monthly", "expiryTime": _future_iso()}
            ],
        },
    )
    uid = _create_user(app)
    _seed_purchase(app, uid, store="google", token="tok-1", status="expired")

    resp = client.post("/api/iap/google/notifications", json=_pubsub_envelope(_rtdn()))

    assert resp.status_code == 200
    assert resp.get_json()["handled"] is True
    assert _get_user(app, uid)["subscription_tier"] == "premium"
    row = _purchase_row(app, "tok-1")
    assert row["status"] == "active"
    assert _event_count(app) == 1


def test_google_notification_expired_revokes(client, app, monkeypatch):
    _patch_google_oidc(monkeypatch)
    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_google_subscriptionv2",
        lambda *a, **k: {
            "subscriptionState": "SUBSCRIPTION_STATE_EXPIRED",
            "lineItems": [
                {"productId": "premium_monthly", "expiryTime": _future_iso(-1)}
            ],
        },
    )
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid, store="google", token="tok-1")

    resp = client.post(
        "/api/iap/google/notifications",
        json=_pubsub_envelope(_rtdn(notification_type=13)),
    )

    assert resp.get_json()["handled"] is True
    assert _get_user(app, uid)["subscription_tier"] == "free"
    assert _purchase_row(app, "tok-1")["status"] == "inactive"


def test_google_notification_voided_purchase_refunds(client, app, monkeypatch):
    # Refund via voidedPurchaseNotification: applied directly, no Play API
    # re-query (no _fetch patch — a re-query would 503 on missing creds).
    _patch_google_oidc(monkeypatch)
    monkeypatch.delenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", raising=False)
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid, store="google", token="tok-1")
    notification = {
        "version": "1.0",
        "packageName": "app.onceuponyourchild",
        "eventTimeMillis": str(_ms(datetime.now(UTC))),
        "voidedPurchaseNotification": {
            "purchaseToken": "tok-1",
            "orderId": "GPA.1111",
            "productType": 1,
            "refundType": 1,
        },
    }

    resp = client.post(
        "/api/iap/google/notifications", json=_pubsub_envelope(notification)
    )

    assert resp.status_code == 200
    assert resp.get_json()["handled"] is True
    assert _get_user(app, uid)["subscription_tier"] == "free"
    assert _purchase_row(app, "tok-1")["status"] == "refunded"


def test_google_notification_duplicate_message_id_is_noop(client, app, monkeypatch):
    _patch_google_oidc(monkeypatch)
    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_google_subscriptionv2",
        lambda *a, **k: {
            "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
            "lineItems": [
                {"productId": "premium_monthly", "expiryTime": _future_iso()}
            ],
        },
    )
    uid = _create_user(app)
    _seed_purchase(app, uid, store="google", token="tok-1", status="expired")
    envelope = _pubsub_envelope(_rtdn(), message_id="dup-msg")

    first = client.post("/api/iap/google/notifications", json=envelope)
    second = client.post("/api/iap/google/notifications", json=envelope)

    assert first.get_json()["handled"] is True
    assert second.status_code == 200
    assert second.get_json()["handled"] is False
    assert second.get_json()["reason"] == "duplicate"
    assert _event_count(app) == 1


def test_google_notification_unknown_token_requests_redelivery(
    client, app, monkeypatch
):
    _patch_google_oidc(monkeypatch)
    resp = client.post(
        "/api/iap/google/notifications",
        json=_pubsub_envelope(_rtdn(purchase_token="never-seen")),
    )
    assert resp.status_code == 404
    assert _event_count(app) == 0


def test_google_notification_test_notification_acks(client, app, monkeypatch):
    _patch_google_oidc(monkeypatch)
    notification = {"version": "1.0", "testNotification": {"version": "1.0"}}
    resp = client.post(
        "/api/iap/google/notifications", json=_pubsub_envelope(notification)
    )
    assert resp.status_code == 200
    assert resp.get_json()["handled"] is False


def test_google_notification_requery_unconfigured_fails_closed_503(
    client, app, monkeypatch
):
    # Purchase exists but Play API creds are absent: 503 BEFORE the dedup row
    # is written, so redelivery converges once the operator fixes config.
    _patch_google_oidc(monkeypatch)
    monkeypatch.delenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", raising=False)
    monkeypatch.delenv("ANDROID_PACKAGE_NAME", raising=False)
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid, store="google", token="tok-1")

    resp = client.post("/api/iap/google/notifications", json=_pubsub_envelope(_rtdn()))

    assert resp.status_code == 503
    assert _event_count(app) == 0
    assert _get_user(app, uid)["subscription_tier"] == "premium"


def test_google_notification_requery_invalid_acks_without_change(
    client, app, monkeypatch
):
    # Google no longer recognizes the token: never revoke off a failed lookup.
    _patch_google_oidc(monkeypatch)

    def _raise(*a, **k):
        raise IapVerificationError("Google purchase token not found")

    monkeypatch.setattr(
        "backend.routes.iap_routes._fetch_google_subscriptionv2", _raise
    )
    uid = _create_user(app)
    _make_premium(app, uid)
    _seed_purchase(app, uid, store="google", token="tok-1")

    resp = client.post("/api/iap/google/notifications", json=_pubsub_envelope(_rtdn()))

    assert resp.status_code == 200
    assert resp.get_json()["handled"] is False
    assert _get_user(app, uid)["subscription_tier"] == "premium"
    assert _purchase_row(app, "tok-1")["status"] == "active"


def test_google_notification_undecodable_data_returns_400(client, app, monkeypatch):
    _patch_google_oidc(monkeypatch)
    resp = client.post(
        "/api/iap/google/notifications",
        json={"message": {"data": "!!!not-base64!!!", "messageId": "m-1"}},
    )
    assert resp.status_code == 400
