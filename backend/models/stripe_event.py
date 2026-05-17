"""Stripe webhook event dedup + ordering state (M-3 — webhook idempotency).

Stripe delivers webhooks *at least once*: its own retry logic re-sends an event
until it gets a 2xx, and within the 5-minute signature-tolerance window a
captured payload can be replayed. Without recording which `event.id` values
have already been processed, a replayed stale `invoice.payment_succeeded`
arriving after a real `invoice.payment_failed` would flip a delinquent account
back to `active`.

Two models, both auto-created at boot by `db.create_all()` (no ALTER TABLE):

  StripeWebhookEvent  — one row per accepted `event.id`. The webhook
                        short-circuits (200, no-op) on a duplicate event_id.
  StripeSubscriptionCursor — per-user high-water mark of the most recent
                        Stripe event timestamp that actually changed
                        subscription state. Used to drop out-of-order /
                        replayed events that would regress state.
"""
import uuid
from datetime import datetime, timezone

from ..database import db


class StripeWebhookEvent(db.Model):
    """One row per Stripe `event.id` we have accepted and processed."""

    __tablename__ = 'stripe_webhook_event'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    # Stripe's `event.id` (e.g. "evt_..."). Unique — this is the dedup key.
    event_id = db.Column(db.String(255), unique=True, nullable=False, index=True)
    event_type = db.Column(db.String(100), nullable=True)
    # Stripe's `event.created` (unix seconds -> UTC datetime).
    event_created = db.Column(db.DateTime, nullable=True)
    # When this server first recorded the event.
    received_at = db.Column(
        db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )

    def to_dict(self):
        return {
            'id': self.id,
            'event_id': self.event_id,
            'event_type': self.event_type,
            'event_created': self.event_created.isoformat() if self.event_created else None,
            'received_at': self.received_at.isoformat() if self.received_at else None,
        }


class StripeSubscriptionCursor(db.Model):
    """Per-user high-water mark for Stripe subscription-state events.

    `last_event_created` is the `event.created` timestamp of the most recent
    Stripe event that mutated the user's subscription state. An incoming event
    older than this is a replay / out-of-order delivery and must NOT be allowed
    to regress state (e.g. a stale `payment_succeeded` after a real
    `payment_failed`).
    """

    __tablename__ = 'stripe_subscription_cursor'

    user_id = db.Column(db.String(36), primary_key=True)
    last_event_created = db.Column(db.DateTime, nullable=True)
    last_event_id = db.Column(db.String(255), nullable=True)
    updated_at = db.Column(
        db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
