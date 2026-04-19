"""Audit log for security-sensitive and compliance-relevant events.

Recorded events
---------------
story_generated      — successful story generation
tts_quota_exceeded   — user hit daily TTS limit
ai_quota_exceeded    — user hit daily AI generation limit
user_login           — successful password login
token_refreshed      — refresh token used to issue new access token
anonymous_session    — new anonymous account created
data_exported        — GDPR data export downloaded
data_deleted         — GDPR right-to-erasure executed

Retention: rows older than 90 days can be purged by a scheduled job.
The table is append-only — rows are never updated.
"""
from datetime import datetime, timezone

from ..database import db


class AuditLog(db.Model):
    __tablename__ = 'audit_log'

    id = db.Column(db.Integer, primary_key=True)
    # user_id is nullable — some events (e.g. failed auth) have no authenticated user
    user_id = db.Column(db.String(100), nullable=True, index=True)
    event_type = db.Column(db.String(50), nullable=False, index=True)
    # Structured metadata: keep small, no PII, no story content
    event_data = db.Column(db.JSON, nullable=True)
    ip_address = db.Column(db.String(45), nullable=True)   # IPv4 or IPv6
    created_at = db.Column(
        db.DateTime,
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'event_type': self.event_type,
            'event_data': self.event_data,
            'ip_address': self.ip_address,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
