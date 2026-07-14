"""Unit tests for services/entitlement_service.apply_entitlement (STORE-1).

The webhook / IAP / gift suites exercise apply_entitlement through their
routes; these pin the function's own contract — especially the
None = leave-unchanged semantics the Stripe webhook's partial updates
(STORE-1 phase 2) rely on.
"""

import uuid
from datetime import datetime, timezone

from backend.database import db
from backend.models.user import User
from backend.services.entitlement_service import apply_entitlement


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


def test_none_tier_leaves_tier_unchanged(app):
    with app.app_context():
        user = _create_user(subscription_tier="premium", subscription_status="active")
        apply_entitlement(user, tier=None, status="past_due", source="test")
        assert user.subscription_tier == "premium"
        assert user.subscription_status == "past_due"


def test_none_tier_does_not_clobber_non_store_tier(app):
    # A legacy / server-side tier value (e.g. 'byok') must survive a
    # status-only event — tier=None must NOT route through the fail-closed
    # unknown-tier path.
    with app.app_context():
        user = _create_user(subscription_tier="byok", subscription_status="active")
        apply_entitlement(user, tier=None, status="past_due", source="test")
        assert user.subscription_tier == "byok"


def test_unknown_tier_fails_closed_to_free(app):
    with app.app_context():
        user = _create_user(subscription_tier="premium")
        apply_entitlement(user, tier="gold", status="active", source="test")
        assert user.subscription_tier == "free"


def test_none_status_period_end_and_cancel_left_unchanged(app):
    with app.app_context():
        period_end = datetime(2027, 1, 1)
        user = _create_user(
            subscription_tier="premium",
            subscription_status="active",
            current_period_end=period_end,
            cancel_at_period_end=True,
        )
        apply_entitlement(user, tier="premium", status=None, source="test")
        assert user.subscription_status == "active"
        assert user.current_period_end == period_end
        assert user.cancel_at_period_end is True


def test_aware_period_end_stored_naive_utc(app):
    with app.app_context():
        user = _create_user()
        aware = datetime(2027, 1, 1, 12, 0, tzinfo=timezone.utc)
        apply_entitlement(
            user, tier="premium", status="active", period_end=aware, source="test"
        )
        assert user.current_period_end == datetime(2027, 1, 1, 12, 0)
        assert user.current_period_end.tzinfo is None
