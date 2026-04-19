"""Lightweight audit logging helper.

Usage::

    from backend.utils.audit import audit_log

    audit_log('story_generated', user_id=user_id, data={'tier': tier})

Writes are fire-and-forget: any database or import error is swallowed so a
logging failure never breaks a user-facing request.
"""
import logging

logger = logging.getLogger(__name__)


def audit_log(
    event_type: str,
    *,
    user_id: str | None = None,
    data: dict | None = None,
    ip: str | None = None,
) -> None:
    """Append one row to the audit_log table.

    Never raises — errors are logged at WARNING level and suppressed.
    """
    try:
        from flask import request as _request

        # Resolve IP from request context if not provided explicitly.
        if ip is None:
            try:
                ip = _request.remote_addr
            except RuntimeError:
                ip = None

        try:
            from backend.models.audit_log import AuditLog
            from backend.database import db
        except ImportError:
            from models.audit_log import AuditLog
            from database import db

        entry = AuditLog(
            user_id=user_id,
            event_type=event_type,
            event_data=data or {},
            ip_address=ip,
        )
        db.session.add(entry)
        db.session.commit()
    except Exception as exc:
        logger.warning('audit_log: failed to write event %s (%s)', event_type, exc)
