from datetime import datetime, timedelta, timezone
import uuid

import pytest
import stripe

from backend.database import db
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
