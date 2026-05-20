"""Server-side parental consent record for COPPA compliance."""
import uuid
from datetime import datetime, timezone
from ..database import db

# CMP-10: monotonically increasing version of the privacy policy / consent
# terms. Bump this integer whenever the privacy policy or Notice to Parents
# materially changes. Any ConsentRecord stamped with an older value (or null,
# for rows created before this column existed) is considered STALE and — when
# stale-version enforcement is enabled — no longer satisfies the COPPA gate,
# forcing the parent to re-consent against the new policy.
#
# Keep this in sync with the client-side policy cutoff (lib/main_story.dart).
CURRENT_POLICY_VERSION = 2


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
    # 'parent', 'self_attested', 'email_verified', 'email_pending', 'debug_bypass'
    consent_method = db.Column(db.String(50), nullable=False)
    consent_given_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    ip_address = db.Column(db.String(45), nullable=True)  # IPv4 or IPv6
    # Photo-avatar opt-in. Defaults False so the consent record fails safe:
    # an omitted field must never record the child as opted in (CMP-8).
    allow_photo_avatar = db.Column(db.Boolean, default=False, nullable=False)
    withdrawn = db.Column(db.Boolean, default=False, nullable=False)
    withdrawn_at = db.Column(db.DateTime, nullable=True)
    # COPPA email round-trip: True only once a parent submitted a valid code.
    # A 'email_pending' record carries verified=False until the round trip
    # completes; the COPPA gate must treat verified=False as not-yet-consented.
    verified = db.Column(db.Boolean, default=False, nullable=False)
    # CMP-10: the CURRENT_POLICY_VERSION in effect when this consent was given.
    # Nullable so rows created before this column existed (legacy) parse as
    # NULL — those are treated as stale by the gate. New records are stamped
    # with CURRENT_POLICY_VERSION at creation time.
    policy_version = db.Column(db.Integer, nullable=True, default=CURRENT_POLICY_VERSION)

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
            'verified': self.verified,
            'policy_version': self.policy_version,
        }


class ConsentVerificationCode(db.Model):
    """
    Transient email-verification code for the COPPA parental-consent round trip.

    A separate table (rather than columns on ConsentRecord) because:
      - A parent may trigger multiple "send code" attempts (resend); each
        produces a fresh code row while a single canonical pending
        ConsentRecord remains.
      - Code lifecycle data (hash, expiry, attempt counter, consumed flag) is
        operational/transient and should not bloat the permanent compliance
        audit record.
      - Brute-force / attempt state is isolated from the consent record.

    The code is stored only as a SHA-256 hex digest — never in plaintext.
    """
    __tablename__ = 'consent_verification_code'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=False, index=True)
    # The ConsentRecord this code, once verified, promotes to email_verified.
    consent_record_id = db.Column(
        db.String(36), db.ForeignKey('consent_record.id'), nullable=True
    )
    # SHA-256 hex digest of the verification code. Never store plaintext.
    code_hash = db.Column(db.String(64), nullable=False)
    created_at = db.Column(
        db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    expires_at = db.Column(db.DateTime, nullable=False)
    # Set True once the code has been successfully used (single-use) OR
    # invalidated by exceeding the failed-attempt cap.
    consumed = db.Column(db.Boolean, default=False, nullable=False)
    consumed_at = db.Column(db.DateTime, nullable=True)
    # Count of failed verification attempts against this code.
    attempts = db.Column(db.Integer, default=0, nullable=False)

    def is_expired(self):
        exp = self.expires_at
        if exp is None:
            return True
        # Stored as naive UTC; compare against naive UTC now.
        if exp.tzinfo is not None:
            exp = exp.astimezone(timezone.utc).replace(tzinfo=None)
        return datetime.now(timezone.utc).replace(tzinfo=None) >= exp

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'consent_record_id': self.consent_record_id,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'expires_at': self.expires_at.isoformat() if self.expires_at else None,
            'consumed': self.consumed,
            'attempts': self.attempts,
        }
