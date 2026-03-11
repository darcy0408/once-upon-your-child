"""Server-side parental consent record for COPPA compliance."""
import uuid
from datetime import datetime, timezone
from ..database import db


class ConsentRecord(db.Model):
    """
    Stores a verifiable record of parental consent for COPPA compliance.
    One record per consent event (new consent, withdrawal, re-consent).
    """
    __tablename__ = 'consent_record'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=False, index=True)
    child_age = db.Column(db.Integer, nullable=False)
    parent_email = db.Column(db.String(120), nullable=True)
    consent_method = db.Column(db.String(50), nullable=False)  # 'parent', 'self_attested', 'email_verified'
    consent_given_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    ip_address = db.Column(db.String(45), nullable=True)  # IPv4 or IPv6
    allow_photo_avatar = db.Column(db.Boolean, default=True, nullable=False)
    withdrawn = db.Column(db.Boolean, default=False, nullable=False)
    withdrawn_at = db.Column(db.DateTime, nullable=True)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'child_age': self.child_age,
            'parent_email': self.parent_email,
            'consent_method': self.consent_method,
            'consent_given_at': self.consent_given_at.isoformat() if self.consent_given_at else None,
            'allow_photo_avatar': self.allow_photo_avatar,
            'withdrawn': self.withdrawn,
            'withdrawn_at': self.withdrawn_at.isoformat() if self.withdrawn_at else None,
        }
