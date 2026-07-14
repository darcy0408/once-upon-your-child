import uuid
from datetime import datetime, timedelta, timezone

import pytest
import stripe

from backend.database import db
from backend.models.gift_code import GiftCode
from backend.models.user import User

stripe.api_key = "sk_test_key"


@pytest.fixture(autouse=True)
def _stripe_secret(monkeypatch):
    monkeypatch.setenv("STRIPE_WEBHOOK_SECRET", "whsec_test")


@pytest.fixture(autouse=True)
def _clear_users(app):
    with app.app_context():
        db.session.query(User).delete()
        db.session.commit()


def _create_user(**overrides):
    token = uuid.uuid4().hex
    payload = {
        "id": overrides.pop("id", str(uuid.uuid4())),
        "username": overrides.pop("username", f"user-{token}"),
        "email": overrides.pop("email", f"{token}@example.com"),
        "password_hash": overrides.pop("password_hash", "hashed"),
        "subscription_tier": overrides.pop("subscription_tier", "free"),
        "subscription_status": overrides.pop("subscription_status", "inactive"),
        "current_period_end": overrides.pop("current_period_end", None),
        "cancel_at_period_end": overrides.pop("cancel_at_period_end", False),
    }
    payload.update(overrides)
    user = User(**payload)
    db.session.add(user)
    db.session.commit()
    return user


def _mock_construct_event(monkeypatch, event):
    def _constructor(payload, sig_header, secret):
        return event

    monkeypatch.setattr(stripe.Webhook, "construct_event", _constructor)


def _build_event(event_type, obj):
    return stripe.Event.construct_from(
        {
            "id": f"evt_{event_type}",
            "type": event_type,
            "data": {"object": obj},
        },
        stripe.api_key,
    )


def _build_event_with_id(event_id, event_type, obj):
    """Like _build_event but with a caller-chosen event id.

    Needed for the gift-checkout idempotency test: _build_event derives the
    event id purely from event_type, so two calls with that helper would
    collide with the top-level Stripe event-id dedup before ever reaching the
    gift-purchase handler. This lets a test send two DISTINCT Stripe events
    for the SAME checkout session to exercise the inner
    stripe_session_id idempotency guard instead.
    """
    return stripe.Event.construct_from(
        {
            "id": event_id,
            "type": event_type,
            "data": {"object": obj},
        },
        stripe.api_key,
    )


def _timestamp(value):
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return int(value.timestamp())


def test_checkout_completed_creates_subscription(client, monkeypatch):
    with client.application.app_context():
        user = _create_user()
        user_id = user.id

    period_end = datetime.now(timezone.utc).replace(microsecond=0) + timedelta(days=30)
    event = _build_event(
        "checkout.session.completed",
        {
            "client_reference_id": user_id,
            "metadata": {"subscription_tier": "premium"},
            "subscription": {
                "status": "active",
                "current_period_end": int(period_end.timestamp()),
                "cancel_at_period_end": False,
            },
        },
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        updated = db.session.get(User, user_id)
        assert updated.subscription_tier == "premium"
        assert updated.subscription_status == "active"
        assert updated.cancel_at_period_end is False
        assert _timestamp(updated.current_period_end) == _timestamp(period_end)


def test_subscription_updated_changes_status(client, monkeypatch):
    with client.application.app_context():
        user = _create_user(subscription_tier="free", subscription_status="inactive")
        user_id = user.id

    new_period_end = datetime.now(timezone.utc).replace(microsecond=0) + timedelta(
        days=60
    )
    event = _build_event(
        "customer.subscription.updated",
        {
            "metadata": {"user_id": user_id, "subscription_tier": "family"},
            "status": "trialing",
            "current_period_end": int(new_period_end.timestamp()),
            "cancel_at_period_end": True,
        },
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        updated = db.session.get(User, user_id)
        assert updated.subscription_tier == "family"
        assert updated.subscription_status == "trialing"
        assert updated.cancel_at_period_end is True
        assert _timestamp(updated.current_period_end) == _timestamp(new_period_end)


def test_subscription_deleted_cancels(client, monkeypatch):
    with client.application.app_context():
        user = _create_user(subscription_status="active", cancel_at_period_end=False)
        user_id = user.id

    event = _build_event(
        "customer.subscription.deleted",
        {
            "metadata": {"user_id": user_id},
            "current_period_end": int(datetime.now(timezone.utc).timestamp()),
        },
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        updated = db.session.get(User, user_id)
        assert updated.subscription_status == "canceled"
        assert updated.cancel_at_period_end is True


def test_payment_failed_marks_past_due(client, monkeypatch):
    with client.application.app_context():
        user = _create_user(subscription_status="active")
        user_id = user.id

    event = _build_event(
        "invoice.payment_failed",
        {
            "metadata": {"user_id": user_id},
        },
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        updated = db.session.get(User, user_id)
        assert updated.subscription_status == "past_due"


def test_payment_failed_keeps_tier_and_period_end(client, monkeypatch):
    # STORE-1 phase 2 pin: invoice.payment_failed is a status-only update.
    # Routing it through the shared apply_entitlement() must not touch the
    # tier or the paid-through date.
    period_end = datetime.now(timezone.utc).replace(microsecond=0) + timedelta(days=30)
    with client.application.app_context():
        user = _create_user(
            subscription_tier="premium",
            subscription_status="active",
            current_period_end=period_end.replace(tzinfo=None),
        )
        user_id = user.id

    event = _build_event(
        "invoice.payment_failed",
        {
            "metadata": {"user_id": user_id},
        },
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        updated = db.session.get(User, user_id)
        assert updated.subscription_status == "past_due"
        assert updated.subscription_tier == "premium"
        assert _timestamp(updated.current_period_end) == _timestamp(period_end)


def test_unknown_metadata_tier_hint_fails_closed_to_free(client, monkeypatch):
    # The metadata tier hint is client-supplied. When the price ID is
    # unresolvable AND the hint is not a known tier, the shared
    # apply_entitlement() fails closed to 'free' instead of writing the raw
    # client string (pre-phase-2 the webhook wrote it verbatim).
    with client.application.app_context():
        user = _create_user(subscription_tier="free", subscription_status="inactive")
        user_id = user.id

    event = _build_event(
        "customer.subscription.updated",
        {
            "metadata": {"user_id": user_id, "subscription_tier": "gold"},
            "status": "active",
            "current_period_end": int(datetime.now(timezone.utc).timestamp()),
            "cancel_at_period_end": False,
        },
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        updated = db.session.get(User, user_id)
        assert updated.subscription_tier == "free"
        assert updated.subscription_status == "active"


def test_unexpanded_checkout_clears_period_end(client, monkeypatch):
    # Stripe delivers checkout.session.completed with `subscription` as a bare
    # ID (or absent) unless expansion was requested. The webhook's historical
    # contract clears current_period_end in that case — the follow-up
    # customer.subscription.updated event supplies the real date. Pin that the
    # phase-2 delegation preserved the explicit clear.
    stale_period_end = datetime.now(timezone.utc).replace(
        microsecond=0, tzinfo=None
    ) - timedelta(days=3)
    with client.application.app_context():
        user = _create_user(
            subscription_tier="premium",
            subscription_status="canceled",
            current_period_end=stale_period_end,
        )
        user_id = user.id

    event = _build_event(
        "checkout.session.completed",
        {
            "client_reference_id": user_id,
            "metadata": {"subscription_tier": "premium"},
            # no "subscription" key — unexpanded payload
        },
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        updated = db.session.get(User, user_id)
        assert updated.subscription_tier == "premium"
        assert updated.subscription_status == "active"
        assert updated.current_period_end is None


def test_invalid_signature_returns_401(client, monkeypatch):
    def _raise_signature_error(payload, sig_header, secret):
        raise stripe.SignatureVerificationError("bad signature", sig_header)

    monkeypatch.setattr(stripe.Webhook, "construct_event", _raise_signature_error)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 401


def test_invalid_payload_returns_400(client, monkeypatch):
    def _raise_value_error(payload, sig_header, secret):
        raise ValueError("bad payload")

    monkeypatch.setattr(stripe.Webhook, "construct_event", _raise_value_error)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 400
    assert response.get_json()["error"] == "Invalid payload"


def test_missing_webhook_secret_returns_500(client, monkeypatch):
    monkeypatch.delenv("STRIPE_WEBHOOK_SECRET", raising=False)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 500
    assert response.get_json()["error"] == "Webhook not configured"


def test_unknown_event_returns_200(client, monkeypatch):
    with client.application.app_context():
        user = _create_user(subscription_status="active")
        user_id = user.id

    event = _build_event(
        "product.created",
        {"metadata": {"user_id": user_id}},
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        unchanged = db.session.get(User, user_id)
        assert unchanged.subscription_status == "active"


# ---------------------------------------------------------------------------
# Gift-subscription purchases (one-time mode=="payment" Checkout Session).
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def _no_gift_price_env(monkeypatch):
    # Keep the price-id fallback branch of _is_gift_checkout() inert unless a
    # test explicitly opts in — otherwise a real STRIPE_PRICE_ID_GIFT_YEAR
    # picked up from a local .env could make _is_gift_checkout() reach the
    # stripe.checkout.Session.list_line_items() network call.
    monkeypatch.delenv("STRIPE_PRICE_ID_GIFT_YEAR", raising=False)


def _gift_session(session_id, **overrides):
    session = {
        "id": session_id,
        "mode": "payment",
        "metadata": {"gift": "true"},
        "customer_details": {"email": "grandma@example.com"},
    }
    session.update(overrides)
    return session


def test_gift_checkout_completed_creates_code_and_emails_purchaser(client, monkeypatch):
    sent_calls = []

    def _fake_send(email, formatted_code, tier, duration_days):
        sent_calls.append((email, formatted_code, tier, duration_days))
        return True

    monkeypatch.setattr(
        "backend.routes.webhook_handler.send_gift_code_email", _fake_send
    )

    event = _build_event_with_id(
        "evt_gift_1", "checkout.session.completed", _gift_session("cs_test_gift_1")
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        gift = (
            db.session.query(GiftCode)
            .filter_by(stripe_session_id="cs_test_gift_1")
            .first()
        )
        assert gift is not None
        assert gift.status == "created"
        assert gift.tier == "premium"
        assert gift.duration_days == 365
        assert gift.purchaser_email == "grandma@example.com"
        assert gift.redeemed_by_user_id is None

    assert len(sent_calls) == 1
    email, formatted_code, tier, duration_days = sent_calls[0]
    assert email == "grandma@example.com"
    assert tier == "premium"
    assert duration_days == 365
    # Dash-grouped display format (XXXX-XXXX-XXXX), never the raw code alone.
    assert "-" in formatted_code
    assert len(formatted_code.replace("-", "")) == 12


def test_gift_checkout_completed_idempotent_on_replayed_session(client, monkeypatch):
    monkeypatch.setattr(
        "backend.routes.webhook_handler.send_gift_code_email",
        lambda *a, **k: True,
    )

    session = _gift_session(
        "cs_test_gift_dup", customer_details={"email": "grandpa@example.com"}
    )

    for event_id in ("evt_gift_dup_1", "evt_gift_dup_2"):
        event = _build_event_with_id(event_id, "checkout.session.completed", session)
        _mock_construct_event(monkeypatch, event)
        response = client.post(
            "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
        )
        assert response.status_code == 200

    with client.application.app_context():
        count = (
            db.session.query(GiftCode)
            .filter_by(stripe_session_id="cs_test_gift_dup")
            .count()
        )
        assert count == 1


def test_gift_checkout_completed_email_failure_keeps_code(client, monkeypatch):
    monkeypatch.setattr(
        "backend.routes.webhook_handler.send_gift_code_email",
        lambda *a, **k: False,
    )

    event = _build_event_with_id(
        "evt_gift_fail",
        "checkout.session.completed",
        _gift_session(
            "cs_test_gift_email_fail", customer_details={"email": "auntie@example.com"}
        ),
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        gift = (
            db.session.query(GiftCode)
            .filter_by(stripe_session_id="cs_test_gift_email_fail")
            .first()
        )
        # Persisted despite the "failed" send — a paying purchaser must never
        # lose their code to a transient email-provider outage.
        assert gift is not None
        assert gift.status == "created"


def test_non_gift_payment_checkout_does_not_create_gift_code(client, monkeypatch):
    event = _build_event_with_id(
        "evt_not_gift",
        "checkout.session.completed",
        {"id": "cs_test_not_gift", "mode": "payment", "metadata": {}},
    )
    _mock_construct_event(monkeypatch, event)

    response = client.post(
        "/api/stripe/webhook", data="{}", headers={"Stripe-Signature": "sig"}
    )
    assert response.status_code == 200

    with client.application.app_context():
        assert db.session.query(GiftCode).count() == 0
