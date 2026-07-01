"""Analytics event sink — paywall/funnel instrumentation (MT-249).

A lightweight, append-only event table used to measure the freemium funnel
(e.g. ``paywall_viewed`` -> ``avatar_limit_hit`` -> upgrade). It deliberately
mirrors ``audit_log`` in shape and lifecycle:

  * append-only — rows are never updated;
  * best-effort — writes go through ``event_tracking_service.record_event``
    which swallows any failure so telemetry never breaks a user request;
  * no PII, no story content — ``event_metadata`` is small structured JSON.

Auto-created at boot by ``db.create_all()`` (the model is imported by
``backend/models/__init__.py``, so importing any model registers it), exactly
like ``illustration_cache`` / ``stripe_event`` / ``iap_event``. No ALTER TABLE
is needed for a fresh table. The canonical migration record lives at
``backend/migrations/add_analytics_events.py``.
"""

from datetime import datetime, timezone

try:  # Package vs. flat-module import (mirrors the rest of backend/).
    from ..database import db
except ImportError:  # pragma: no cover
    from database import db


class AnalyticsEvent(db.Model):
    __tablename__ = "analytics_events"

    id = db.Column(db.Integer, primary_key=True)
    # The funnel event name (e.g. 'paywall_viewed', 'avatar_limit_hit').
    event_name = db.Column(db.String(100), nullable=False, index=True)
    # Nullable — anonymous / pre-auth events are allowed. Stored as a string to
    # match the User.id type without a hard FK (an event may outlive its user
    # row, and we never want a delete to cascade telemetry away).
    user_id = db.Column(db.String(100), nullable=True, index=True)
    # Subscription tier at the time of the event, when known.
    tier = db.Column(db.String(50), nullable=True)
    # Small structured metadata: no PII, no story content.
    event_metadata = db.Column(db.JSON, nullable=True)
    created_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )

    def to_dict(self):
        return {
            "id": self.id,
            "event_name": self.event_name,
            "user_id": self.user_id,
            "tier": self.tier,
            "event_metadata": self.event_metadata,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
