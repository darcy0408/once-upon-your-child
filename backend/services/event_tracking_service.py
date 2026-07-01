"""Best-effort analytics event recorder — paywall funnel (MT-249).

Usage::

    from backend.services.event_tracking_service import record_event

    record_event(
        "avatar_limit_hit",
        user_id=user_id,
        tier="free",
        metadata={"used": 1, "limit": 1},
    )

Writes are fire-and-forget: any database or import error is swallowed so a
telemetry failure never breaks a user-facing request. Modelled on the audit-log
helper (``backend/utils/audit.py``); the only difference is the target table
(``analytics_events``) and that it also carries the subscription ``tier``.
"""

import logging

logger = logging.getLogger(__name__)


def record_event(
    event_name: str,
    *,
    user_id: str | None = None,
    tier: str | None = None,
    metadata: dict | None = None,
) -> None:
    """Append one row to the ``analytics_events`` table.

    Never raises — any error is logged at WARNING level and suppressed. This is
    a strict invariant: callers on the request hot path (paywall gate, avatar
    limit) rely on it so instrumentation can never turn into a user-visible
    failure.
    """
    try:
        try:
            from backend.database import db
            from backend.models.analytics_event import AnalyticsEvent
        except ImportError:  # pragma: no cover - flat-module execution
            from database import db
            from models.analytics_event import AnalyticsEvent

        entry = AnalyticsEvent(
            event_name=event_name,
            user_id=user_id,
            tier=tier,
            event_metadata=metadata or {},
        )
        db.session.add(entry)
        db.session.commit()
    except Exception as exc:  # noqa: BLE001 - telemetry must never raise
        logger.warning("record_event: failed to write event %s (%s)", event_name, exc)
        # Roll the session back so a poisoned transaction doesn't leak into the
        # caller's next DB operation on this request.
        try:
            from backend.database import db
        except ImportError:  # pragma: no cover
            try:
                from database import db
            except ImportError:
                return
        try:
            db.session.rollback()
        except Exception:  # noqa: BLE001
            pass
