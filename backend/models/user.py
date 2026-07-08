import uuid
from datetime import datetime, timezone

from werkzeug.security import check_password_hash, generate_password_hash

from ..database import db


class User(db.Model):
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    # CMP-5 / PP-13: last time this account showed activity (login or
    # anonymous-session issue). Used by the data-retention purge task to
    # identify inactive accounts. Nullable for rows created before this
    # column existed — the retention job falls back to created_at when NULL.
    last_active_at = db.Column(db.DateTime, nullable=True)

    # Subscription details
    role = db.Column(db.String(20), default="user", nullable=False)
    subscription_tier = db.Column(db.String(50), default="free", nullable=False)
    subscription_status = db.Column(db.String(50), default="active", nullable=False)
    current_period_end = db.Column(db.DateTime)
    cancel_at_period_end = db.Column(db.Boolean, default=False)
    stripe_customer_id = db.Column(db.String(255))

    # Feature unlock tracking
    stories_created_count = db.Column(db.Integer, default=0, nullable=False)
    # Lifetime count of AI photo-avatars generated. The first one is free for
    # every account (the "magic moment"); further ones require a paid tier.
    # Premium/BYOK users are unlimited and not counted here.
    custom_avatars_generated = db.Column(db.Integer, default=0, nullable=False)

    # 2026-07-07 pricing decision: the free tier gets exactly ONE fully-
    # illustrated story (the "wow" story) — every story after that is
    # text-only until the account upgrades. This records the id (or stable
    # proxy identity — see story_routes._resolve_story_identity) of the
    # story that claimed the free slot, so subsequent illustration requests
    # for a DIFFERENT story can be blocked while the SAME story's remaining
    # pages keep illustrating. Null = the free slot hasn't been claimed yet.
    free_illustrated_story_id = db.Column(db.String(64), nullable=True)

    # BYOK (Bring Your Own API Key) support
    gemini_api_key_encrypted = db.Column(db.Text, nullable=True)  # Encrypted API key
    has_byok = db.Column(
        db.Boolean, default=False, nullable=False
    )  # Quick flag for BYOK status

    # Monthly usage tracking.
    # M-2/M-17: `stories_generated_this_month` is the conservative monthly story
    # counter maintained by backend.utils.ai_quota.increment_daily_quota. It is
    # the fail-CLOSED fallback for the LLM-cost circuit breaker when Redis is
    # unavailable, and the single source of truth for story-usage read-outs.
    # Previously it was declared but never incremented (dead state); it is now
    # actively maintained alongside the enforced Redis daily counter.
    stories_generated_this_month = db.Column(db.Integer, default=0, nullable=False)
    illustrations_generated_this_month = db.Column(
        db.Integer, default=0, nullable=False
    )
    usage_reset_date = db.Column(
        db.DateTime, nullable=True
    )  # When to reset monthly counters

    # COPPA compliance
    declared_age = db.Column(
        db.Integer, nullable=True
    )  # Age declared during onboarding
    is_under_13 = db.Column(db.Boolean, default=False, nullable=False)  # COPPA flag

    # JWT revocation: minted into access tokens as the `tv` claim and verified
    # by require_auth. Bumping this value invalidates every outstanding access
    # token for the user (e.g. on logout or data-deletion).
    token_version = db.Column(db.Integer, default=0, nullable=False)

    # Relationships
    characters = db.relationship("Character", backref="user", lazy=True)
    stories = db.relationship("Story", backref="user", lazy=True)
    # progression_data = db.Column(db.JSON, default=dict)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def to_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "role": self.role,
            "created_at": self.created_at.isoformat(),
            "last_active_at": (
                self.last_active_at.isoformat() if self.last_active_at else None
            ),
            "subscription_tier": self.subscription_tier,
            "subscription_status": self.subscription_status,
            "current_period_end": (
                self.current_period_end.isoformat() if self.current_period_end else None
            ),
            "cancel_at_period_end": self.cancel_at_period_end,
            "stripe_customer_id": self.stripe_customer_id,
            "stories_created_count": self.stories_created_count,
            "custom_avatars_generated": self.custom_avatars_generated,
            "free_illustrated_story_id": self.free_illustrated_story_id,
            # BYOK fields
            "has_byok": self.has_byok,
            "stories_generated_this_month": self.stories_generated_this_month,
            "illustrations_generated_this_month": self.illustrations_generated_this_month,
            "usage_reset_date": (
                self.usage_reset_date.isoformat() if self.usage_reset_date else None
            ),
            # COPPA fields
            "declared_age": self.declared_age,
            "is_under_13": self.is_under_13,
            # Note: Never expose gemini_api_key_encrypted in API responses
        }
