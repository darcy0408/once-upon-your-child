"""In-app-purchase entitlement state — STORE-1 (MT-143).

The mobile equivalent of `stripe_event.py`. Apple App Store Server
Notifications V2 and Google Real-Time Developer Notifications are delivered
*at least once* and can arrive out of order, exactly like Stripe webhooks, so
the IAP path needs the same dedup + ordering guards.

Three models, all auto-created at boot by `db.create_all()` (no ALTER TABLE):

  IapNotificationEvent — one row per processed Apple/Google notification ID.
                         The S2S notification endpoint short-circuits on a
                         duplicate.
  IapPurchase          — the latest known state of a store subscription,
                         keyed by the store transaction / purchase token. This
                         is the per-user store-subscription record (the IAP
                         analogue of a Stripe subscription object).

NOTE (Phase 1): these models define the schema and are imported so SQLAlchemy
registers them. The S2S notification handlers that WRITE renewal/cancel/refund
state into them are scaffolded with TODOs in `routes/iap_routes.py` — wiring
the actual Apple/Google notification parsing is a later phase and needs
owner-provided credentials.
"""

import uuid
from datetime import datetime, timezone

try:  # Package vs. flat-module import (mirrors the rest of backend/).
    from ..database import db
except ImportError:  # pragma: no cover
    from database import db


# Store identifiers — kept as plain strings so a row is human-readable.
STORE_APPLE = "apple"
STORE_GOOGLE = "google"


class IapNotificationEvent(db.Model):
    """One row per processed Apple/Google server-to-server notification.

    The S2S notification endpoint records the store-provided notification UUID
    here and short-circuits (200, no-op) when it sees a duplicate — the IAP
    equivalent of `StripeWebhookEvent`.
    """

    __tablename__ = "iap_notification_event"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    # 'apple' | 'google'.
    store = db.Column(db.String(16), nullable=False)
    # Store-provided notification identifier — the dedup key.
    #   Apple:  `notificationUUID` from the V2 signed payload.
    #   Google: the `messageId` of the Pub/Sub envelope.
    notification_id = db.Column(db.String(255), unique=True, nullable=False, index=True)
    notification_type = db.Column(db.String(100), nullable=True)
    # Store-side timestamp of the notification, when available (UTC).
    notification_time = db.Column(db.DateTime, nullable=True)
    received_at = db.Column(
        db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )

    def to_dict(self):
        return {
            "id": self.id,
            "store": self.store,
            "notification_id": self.notification_id,
            "notification_type": self.notification_type,
            "notification_time": (
                self.notification_time.isoformat() if self.notification_time else None
            ),
            "received_at": self.received_at.isoformat() if self.received_at else None,
        }


class IapPurchase(db.Model):
    """The latest known state of a store subscription for a user.

    Written by the receipt-verify endpoints and updated by the S2S notification
    handlers (renewal / cancel / refund). One user may, in edge cases, have
    rows for more than one store — entitlement reconciliation (STORE-1 step 7)
    resolves precedence; this table just records the raw store facts.
    """

    __tablename__ = "iap_purchase"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), nullable=False, index=True)
    store = db.Column(db.String(16), nullable=False)  # 'apple' | 'google'
    # Store product ID — 'premium_monthly' | 'family_monthly'.
    product_id = db.Column(db.String(255), nullable=False)
    # The resolved Story Weaver tier ('premium' | 'family').
    tier = db.Column(db.String(50), nullable=False)
    # Stable per-subscription identifier from the store:
    #   Apple:  `originalTransactionId`.
    #   Google: the purchase token.
    # Unique so a re-verification of the same subscription updates in place.
    store_transaction_id = db.Column(
        db.String(512), unique=True, nullable=False, index=True
    )
    # Store-reported status: 'active' | 'expired' | 'canceled' | 'refunded' |
    # 'grace_period' | 'on_hold'. Resolved to a Story Weaver subscription_status
    # by the entitlement service.
    status = db.Column(db.String(50), nullable=False, default="active")
    # Current paid-through date (UTC). Drives whether access is still valid.
    expires_at = db.Column(db.DateTime, nullable=True)
    # Ordering guard: store event time of the last applied state change. An
    # incoming notification older than this is a stale/out-of-order delivery.
    last_event_time = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(
        db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    updated_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "store": self.store,
            "product_id": self.product_id,
            "tier": self.tier,
            "store_transaction_id": self.store_transaction_id,
            "status": self.status,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "last_event_time": (
                self.last_event_time.isoformat() if self.last_event_time else None
            ),
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
