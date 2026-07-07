"""Gift-subscription redemption codes.

Purchase flow: a grandparent buys "a year of Premium" through a Stripe
Payment Link (a one-time `mode=="payment"` Checkout Session, not a
subscription). `routes/webhook_handler.py` recognizes the gift purchase on
`checkout.session.completed`, creates a `GiftCode` row, and emails the
plaintext code to the purchaser via `utils/email_service.send_gift_code_email`.
The recipient later redeems it in-app via `POST /api/gift/redeem`
(`routes/gift_routes.py`), which applies the entitlement through the SAME
`services.entitlement_service.apply_entitlement()` single-writer path IAP
uses.

SECURITY: the redemption code is stored ONLY as a SHA-256 hash
(`code_hash`), mirroring `models/consent_record.ConsentVerificationCode`'s
`code_hash` discipline. The plaintext code exists transiently — generated in
`gift_routes`/`webhook_handler`, used once to build the email body — and is
never persisted or logged in plaintext. This protects against a database-read
compromise (backup leak, SQL injection read, etc.) turning into free
redeemable subscriptions for whoever obtained the dump.

EXPIRY DESIGN (see the gift-subs PR description for the full writeup):
nothing else in this codebase actively re-checks `User.current_period_end` —
`require_premium` (routes/subscription_routes.py) gates purely on
`subscription_tier`. That's fine for Stripe/IAP because the store itself
pushes a webhook/notification at the real period end. A gift code has no
recurring store object to do that, so
`backend.tasks.subscription_tasks.expire_gift_entitlements_task` (Celery
beat, daily) sweeps users reachable through a `redeemed` GiftCode row whose
`current_period_end` has passed, and downgrades them back to free. Scoping the
query through this table (rather than "any paid user past current_period_end")
means a user who later buys or upgrades to a real Stripe/IAP subscription is
never touched: apply_entitlement overwrites current_period_end with the new
(future) date, so the sweep's `< now` filter stops matching them.
"""

import hashlib
import secrets
import uuid
from datetime import datetime, timezone
from typing import Optional

try:  # Package vs. flat-module import (mirrors the rest of backend/).
    from ..database import db
except ImportError:  # pragma: no cover
    from database import db

# Crockford base32 — 32 symbols, deliberately excludes I, L, O, U to avoid
# visual ambiguity (I/L/1, O/0) and accidental profanity. 12 symbols at 5 bits
# each = 60 bits of entropy — brute-force infeasible even before the
# redemption endpoint's rate limit is factored in.
_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
_CODE_LENGTH = 12
_GROUP_SIZE = 4

# GiftCode.status values.
STATUS_CREATED = "created"
STATUS_REDEEMED = "redeemed"
STATUS_REVOKED = "revoked"

DEFAULT_TIER = "premium"
DEFAULT_DURATION_DAYS = 365

_LOOKALIKE_TRANSLATION = str.maketrans({"O": "0", "I": "1", "L": "1"})


def generate_code() -> str:
    """Generate a random 12-character Crockford base32 code (no dashes)."""
    return "".join(secrets.choice(_ALPHABET) for _ in range(_CODE_LENGTH))


def format_code(code: str) -> str:
    """Insert display dashes: 'ABCD1234WXYZ' -> 'ABCD-1234-WXYZ'."""
    return "-".join(code[i : i + _GROUP_SIZE] for i in range(0, len(code), _GROUP_SIZE))


def normalize_code(raw: Optional[str]) -> Optional[str]:
    """Normalize user-typed input to the canonical stored form.

    Uppercases, strips whitespace/dashes, and applies the standard Crockford
    look-alike corrections (O->0, I/L->1). Returns None if the result isn't a
    well-formed 12-character code (wrong length, or a character outside the
    Crockford alphabet) — callers should treat that identically to "not
    found" so the redemption endpoint never leaks format hints.
    """
    if not raw or not isinstance(raw, str):
        return None
    cleaned = "".join(ch for ch in raw.strip().upper() if ch not in ("-", " "))
    cleaned = cleaned.translate(_LOOKALIKE_TRANSLATION)
    if len(cleaned) != _CODE_LENGTH:
        return None
    if any(ch not in _ALPHABET for ch in cleaned):
        return None
    return cleaned


def hash_code(normalized_code: str) -> str:
    """SHA-256 hex digest of a normalized (no-dash, uppercase) gift code."""
    return hashlib.sha256(normalized_code.encode("utf-8")).hexdigest()


class GiftCode(db.Model):
    """A prepaid gift-subscription redemption code.

    Lifecycle: created (Stripe gift-purchase webhook) -> redeemed (POST
    /api/gift/redeem) — or revoked (no route exercises this yet; the column
    exists so a future admin/support action can flip it without a schema
    change, e.g. a refunded gift).
    """

    __tablename__ = "gift_code"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    # SHA-256 hex digest of the normalized code. See module docstring —
    # plaintext is never stored.
    code_hash = db.Column(db.String(64), unique=True, nullable=False, index=True)
    tier = db.Column(db.String(50), nullable=False, default=DEFAULT_TIER)
    duration_days = db.Column(db.Integer, nullable=False, default=DEFAULT_DURATION_DAYS)
    purchaser_email = db.Column(db.String(255), nullable=True)
    stripe_session_id = db.Column(
        db.String(255), unique=True, nullable=True, index=True
    )
    status = db.Column(db.String(20), nullable=False, default=STATUS_CREATED)
    redeemed_by_user_id = db.Column(db.String(36), nullable=True, index=True)
    created_at = db.Column(
        db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    redeemed_at = db.Column(db.DateTime, nullable=True)

    def to_dict(self):
        # SECURITY: deliberately does not include code_hash — this dict is
        # safe for admin/log display, but even the hash serves no purpose
        # outside the DB layer.
        return {
            "id": self.id,
            "tier": self.tier,
            "duration_days": self.duration_days,
            "status": self.status,
            "redeemed_by_user_id": self.redeemed_by_user_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "redeemed_at": self.redeemed_at.isoformat() if self.redeemed_at else None,
        }
