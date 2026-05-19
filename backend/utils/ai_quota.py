"""
Per-user daily quota enforcement via Redis, with a fail-CLOSED cost breaker.

Two resources are tracked:

  ai   — Gemini story generation (ai:quota:{user_id}:{date})
  tts  — ElevenLabs TTS synthesis (tts:quota:{user_id}:{date})

Limits are checked BEFORE the API call and incremented AFTER a successful
response so failed/error responses don't count against the user's quota.

TTL on all Redis keys: 2 days (auto-expiry, no cleanup job needed).

Quota subsystem split (security finding M-2; MT-169)
----------------------------------------------------
The quota system serves two distinct purposes that need OPPOSITE failure
modes when Redis is unreachable:

  * AVAILABILITY limits (TTS daily-call cap) — these protect user experience
    / burst abuse. They keep failing OPEN on a Redis outage so an infra blip
    never blocks a child mid-story.

  * COST circuit breakers — anything that maps directly to per-call provider
    spend (Gemini/LLM tokens, Flux/Replicate/OpenRouter image generation).
    Failing those OPEN on a Redis outage silently UNCAPS spend for every user
    at once. When Redis is down they fall back to a conservative per-user DB
    counter enforced against a global EMERGENCY cap:

      - `check_daily_quota`          → `User.stories_generated_this_month`
      - `check_illustration_quota`   → `User.illustrations_generated_this_month`

    The DB counters are kept up to date while Redis is healthy, so they are
    always usable conservative baselines (and they double as the single source
    of truth for usage read-outs — finding M-17).

Graceful degradation otherwise: if Redis is unreachable a pure-availability
check is skipped with a WARNING so a Redis outage never blocks user-facing
features.
"""

import logging
import os
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

# Daily generation limits per subscription tier.
# BYOK users are exempt — they pay for their own API key.
_DAILY_LIMITS: dict[str, int] = {
    "free": 10,
    "premium": 50,
    "family": 75,
}
_BYOK_TIERS = frozenset({"byok"})

# Allow override via env var for easy tuning without a code deploy.
_ENV_OVERRIDES = {
    "free": "AI_QUOTA_FREE",
    "premium": "AI_QUOTA_PREMIUM",
    "family": "AI_QUOTA_FAMILY",
}

# M-2 — fail-CLOSED cost breaker.
#
# When Redis is unreachable the story-generation quota can no longer be
# enforced per-day. Rather than fail open (uncapped LLM spend), fall back to
# the monthly DB counter `User.stories_generated_this_month` enforced against
# a deliberately conservative EMERGENCY monthly cap. The cap is intentionally
# low — the goal is cost containment during an outage, not normal service.
#
# AI_QUOTA_EMERGENCY_MULTIPLIER * tier-daily-limit = the monthly emergency cap.
# Default 3 → a free user (10/day) gets at most ~30 stories total while Redis
# is down, vs. an unbounded number under the old fail-open behaviour.
_EMERGENCY_MULTIPLIER_ENV = "AI_QUOTA_EMERGENCY_MULTIPLIER"
_EMERGENCY_MULTIPLIER_DEFAULT = 3


def _get_emergency_cap(tier: str) -> int | None:
    """Conservative monthly story cap used while Redis is unavailable.

    Returns None for BYOK / unlimited tiers (no server-side LLM cost to cap).
    """
    daily = _get_limit(tier)
    if daily is None:
        return None
    raw = os.getenv(_EMERGENCY_MULTIPLIER_ENV)
    multiplier = _EMERGENCY_MULTIPLIER_DEFAULT
    if raw:
        try:
            multiplier = max(1, int(raw))
        except ValueError:
            pass
    return daily * multiplier


def _get_limit(tier: str) -> int | None:
    """Return the daily story limit for *tier*, or None if unlimited."""
    if tier in _BYOK_TIERS:
        return None
    env_key = _ENV_OVERRIDES.get(tier)
    if env_key and os.getenv(env_key):
        try:
            return int(os.getenv(env_key))
        except ValueError:
            pass
    return _DAILY_LIMITS.get(tier, _DAILY_LIMITS["free"])


def _redis_key(user_id: str) -> str:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return f"ai:quota:{user_id}:{today}"


def _get_redis():
    """Return a Redis client or None if Redis is not configured/reachable."""
    redis_url = os.getenv("REDIS_URL") or os.getenv("REDIS_PRIVATE_URL")
    if not redis_url:
        return None
    try:
        import redis as redis_lib
        client = redis_lib.from_url(redis_url, socket_connect_timeout=1)
        client.ping()
        return client
    except Exception as exc:
        logger.warning("ai_quota: Redis unavailable (%s) — quota check skipped", exc)
        return None


# ---------------------------------------------------------------------------
# M-2 / M-17 — DB-backed story cost counter.
#
# `User.stories_generated_this_month` is the conservative monthly counter that:
#   * backs the cost breaker when Redis is down (fail-closed), and
#   * is the single source of truth for usage read-outs (M-17 — previously it
#     was declared but never incremented; the real limit lived only in Redis).
#
# All DB access is best-effort and lazy-imported so this module stays usable
# outside an app context (e.g. unit tests of the Redis path).
# ---------------------------------------------------------------------------

def _load_user(user_id: str):
    """Best-effort fetch of the User row. Returns (db, user) or (None, None)."""
    try:
        from backend.database import db  # lazy — avoid import cycle / app-ctx need
        from backend.models.user import User
    except Exception:  # pragma: no cover - import shape varies in some entrypoints
        try:
            from database import db  # type: ignore
            from models.user import User  # type: ignore
        except Exception:
            return None, None
    try:
        user = db.session.get(User, user_id)
    except Exception as exc:
        logger.warning("ai_quota: DB lookup failed for user=%s (%s)", user_id, exc)
        return None, None
    return db, user


def _maybe_reset_monthly(db, user) -> None:
    """Roll the monthly DB story counter over when past its reset date."""
    try:
        now = datetime.now(timezone.utc)
        reset_date = user.usage_reset_date
        if reset_date is not None and reset_date.tzinfo is None:
            reset_date = reset_date.replace(tzinfo=timezone.utc)
        if reset_date is None or now >= reset_date:
            user.stories_generated_this_month = 0
            # MT-169: roll the illustration counter on the same schedule so the
            # cost-breaker baseline doesn't drift forever after Redis is down.
            user.illustrations_generated_this_month = 0
            # Reset on the 1st of next month.
            from datetime import timedelta
            next_month = (now.replace(day=1) + timedelta(days=32)).replace(day=1)
            user.usage_reset_date = next_month.replace(
                hour=0, minute=0, second=0, microsecond=0, tzinfo=None
            )
    except Exception as exc:
        logger.warning("ai_quota: monthly counter reset check failed (%s)", exc)


def _db_story_count(user_id: str) -> int | None:
    """Return the monthly DB story count for *user_id*, or None if unavailable."""
    db, user = _load_user(user_id)
    if user is None:
        return None
    _maybe_reset_monthly(db, user)
    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
    return int(getattr(user, "stories_generated_this_month", 0) or 0)


def check_daily_quota(user_id: str, user_tier: str) -> tuple[bool, int, int | None]:
    """
    Check whether *user_id* is within their story-generation quota.

    Returns (allowed, current_count, limit).
    - allowed=True  → generation may proceed
    - allowed=False → quota exceeded; caller should return 429
    - limit=None    → unlimited (BYOK)

    Never raises. This is the COST circuit breaker, so on a Redis outage it
    does NOT fail open — it falls back to the conservative DB counter enforced
    against a global emergency cap (M-2).
    """
    limit = _get_limit(user_tier)
    if limit is None:
        return True, 0, None

    r = _get_redis()
    if r is None:
        # --- Redis DOWN: fail-CLOSED to the conservative DB counter (M-2) ----
        emergency_cap = _get_emergency_cap(user_tier)
        db_count = _db_story_count(user_id)
        if db_count is None or emergency_cap is None:
            # DB also unreachable, or unlimited tier. We cannot meter spend at
            # all — alert loudly. Still allow (a hard block here would take the
            # whole product down), but this is the one path that stays open.
            logger.error(
                "ALERT ai_quota: Redis DOWN and DB counter unavailable for "
                "user=%s tier=%s — story cost is UNMETERED this request",
                user_id, user_tier,
            )
            return True, 0, limit
        logger.error(
            "ALERT ai_quota: Redis DOWN — cost breaker on DB fallback for "
            "user=%s tier=%s count=%d emergency_cap=%d",
            user_id, user_tier, db_count, emergency_cap,
        )
        if db_count >= emergency_cap:
            logger.warning(
                "ai_quota: user=%s tier=%s DB count=%d >= emergency_cap=%d "
                "— blocked while Redis down",
                user_id, user_tier, db_count, emergency_cap,
            )
            return False, db_count, emergency_cap
        return True, db_count, emergency_cap

    key = _redis_key(user_id)
    try:
        current = int(r.get(key) or 0)
        if current >= limit:
            logger.warning(
                "ai_quota: user=%s tier=%s count=%d limit=%d — quota exceeded",
                user_id, user_tier, current, limit,
            )
            return False, current, limit
        return True, current, limit
    except Exception as exc:
        # Redis reachable for ping but erroring on GET — treat like an outage
        # and fall back to the fail-closed DB path rather than allowing blindly.
        logger.warning(
            "ai_quota: Redis error during check (%s) — falling back to DB cost breaker",
            exc,
        )
        emergency_cap = _get_emergency_cap(user_tier)
        db_count = _db_story_count(user_id)
        if db_count is None or emergency_cap is None:
            logger.error(
                "ALERT ai_quota: Redis errored and DB counter unavailable for "
                "user=%s — story cost is UNMETERED this request", user_id,
            )
            return True, 0, limit
        if db_count >= emergency_cap:
            return False, db_count, emergency_cap
        return True, db_count, emergency_cap


def increment_daily_quota(user_id: str, user_tier: str) -> None:
    """
    Increment the story-generation counters after a successful generation.

    Bumps BOTH:
      * the Redis daily counter (primary enforced limit, 2-day TTL), and
      * the monthly DB counter `User.stories_generated_this_month` — kept
        current so it is a usable conservative baseline for the M-2 cost
        breaker and the single source of truth for usage read-outs (M-17).

    No-op for BYOK / unlimited tiers. Never raises.
    """
    if user_tier in _BYOK_TIERS or _get_limit(user_tier) is None:
        return

    # Always maintain the DB counter (cheap UPDATE) so the cost breaker has a
    # truthful baseline if Redis later goes down mid-month.
    db, user = _load_user(user_id)
    if user is not None:
        try:
            _maybe_reset_monthly(db, user)
            user.stories_generated_this_month = int(
                getattr(user, "stories_generated_this_month", 0) or 0
            ) + 1
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            logger.warning("ai_quota: DB counter increment failed for %s (%s)", user_id, exc)

    r = _get_redis()
    if r is None:
        return

    key = _redis_key(user_id)
    try:
        pipe = r.pipeline()
        pipe.incr(key)
        pipe.expire(key, 60 * 60 * 48)  # 2-day TTL
        pipe.execute()
    except Exception as exc:
        logger.warning("ai_quota: Redis error during increment (%s)", exc)


def get_story_usage(user_id: str, user_tier: str) -> dict:
    """Single source of truth for story-usage read-outs (M-17).

    Returns a dict suitable for a `/usage`-style endpoint:
        {
          'tier': str,
          'daily_used': int,        # today's count from the enforced Redis counter
          'daily_limit': int|None,  # None = unlimited (BYOK)
          'month_used': int,        # conservative monthly DB counter
          'source': 'redis' | 'db', # which counter `daily_used` came from
        }

    Previously two counters disagreed: `/api/.../usage` read the DB
    `*_this_month` column (never incremented) while enforcement used Redis.
    Both are now kept consistent; this helper exposes the enforced view.
    """
    limit = _get_limit(user_tier)
    month_used = _db_story_count(user_id) or 0
    if limit is None:
        return {
            'tier': user_tier,
            'daily_used': 0,
            'daily_limit': None,
            'month_used': month_used,
            'source': 'unlimited',
        }
    r = _get_redis()
    if r is not None:
        try:
            daily_used = int(r.get(_redis_key(user_id)) or 0)
            return {
                'tier': user_tier,
                'daily_used': daily_used,
                'daily_limit': limit,
                'month_used': month_used,
                'source': 'redis',
            }
        except Exception:
            pass
    # Redis unavailable — report the DB fallback view.
    return {
        'tier': user_tier,
        'daily_used': month_used,
        'daily_limit': _get_emergency_cap(user_tier),
        'month_used': month_used,
        'source': 'db',
    }


# ---------------------------------------------------------------------------
# TTS (ElevenLabs) daily quota
# ---------------------------------------------------------------------------

# Daily TTS synthesis limits per subscription tier.
# BYOK users have their own Gemini key but share ElevenLabs — they are NOT exempt.
_TTS_DAILY_LIMITS: dict[str, int] = {
    "free": 20,
    "premium": 100,
    "family": 150,
    "byok": 50,
}

_ENV_TTS_OVERRIDES = {
    "free": "TTS_QUOTA_FREE",
    "premium": "TTS_QUOTA_PREMIUM",
    "family": "TTS_QUOTA_FAMILY",
    "byok": "TTS_QUOTA_BYOK",
}


def _get_tts_limit(tier: str) -> int:
    env_key = _ENV_TTS_OVERRIDES.get(tier)
    if env_key and os.getenv(env_key):
        try:
            return int(os.getenv(env_key))
        except ValueError:
            pass
    return _TTS_DAILY_LIMITS.get(tier, _TTS_DAILY_LIMITS["free"])


def _tts_redis_key(user_id: str) -> str:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return f"tts:quota:{user_id}:{today}"


def check_tts_quota(user_id: str, user_tier: str) -> tuple[bool, int, int]:
    """
    Check whether *user_id* is within their daily TTS synthesis quota.

    Returns (allowed, current_count, limit).
    Never raises; falls back to allowed=True on Redis errors.
    """
    limit = _get_tts_limit(user_tier)

    r = _get_redis()
    if r is None:
        return True, 0, limit

    key = _tts_redis_key(user_id)
    try:
        current = int(r.get(key) or 0)
        if current >= limit:
            logger.warning(
                "tts_quota: user=%s tier=%s count=%d limit=%d — quota exceeded",
                user_id, user_tier, current, limit,
            )
            return False, current, limit
        return True, current, limit
    except Exception as exc:
        logger.warning("tts_quota: Redis error during check (%s) — allowing request", exc)
        return True, 0, limit


def increment_tts_quota(user_id: str, user_tier: str) -> None:
    """
    Increment the daily TTS counter after a successful synthesis.
    Sets a 2-day TTL. No-op if Redis is unavailable.
    """
    r = _get_redis()
    if r is None:
        return

    key = _tts_redis_key(user_id)
    try:
        pipe = r.pipeline()
        pipe.incr(key)
        pipe.expire(key, 60 * 60 * 48)  # 2-day TTL
        pipe.execute()
    except Exception as exc:
        logger.warning("tts_quota: Redis error during increment (%s)", exc)


# ---------------------------------------------------------------------------
# TTS monthly character quota (per-user + global budget protection)
#
# The daily call quota above protects against burst abuse. The monthly char
# quota below maps directly to ElevenLabs spend (Creator-tier billed per
# character) so the team can budget against the 100k/mo free Year-1 credits
# without surprise overages.
# ---------------------------------------------------------------------------

# Monthly TTS character limits per tier. 0 = TTS locked, fall back to flutter_tts.
_TTS_MONTHLY_CHAR_LIMITS: dict[str, int] = {
    "free": 0,        # flutter_tts only
    "premium": 15_000,  # bumped from 10k 2026-05-11 after #5 char-baseline verification
    "family": 35_000,   # bumped from 25k 2026-05-11
    "byok": 0,        # BYOK doesn't unlock TTS (no per-user ElevenLabs voice rights)
}

_ENV_TTS_CHAR_OVERRIDES = {
    "free": "TTS_CHARS_FREE",
    "premium": "TTS_CHARS_PREMIUM",
    "family": "TTS_CHARS_FAMILY",
    "byok": "TTS_CHARS_BYOK",
}

# Global monthly cap protecting the ElevenLabs free-credit budget.
_GLOBAL_TTS_BUDGET_ENV = "ELEVENLABS_GLOBAL_BUDGET_CHARS"
_GLOBAL_TTS_BUDGET_DEFAULT = 100_000


def _get_tts_char_limit(tier: str) -> int:
    env_key = _ENV_TTS_CHAR_OVERRIDES.get(tier)
    if env_key and os.getenv(env_key):
        try:
            return int(os.getenv(env_key))
        except ValueError:
            pass
    return _TTS_MONTHLY_CHAR_LIMITS.get(tier, _TTS_MONTHLY_CHAR_LIMITS["free"])


def _get_global_tts_budget() -> int:
    raw = os.getenv(_GLOBAL_TTS_BUDGET_ENV)
    if raw:
        try:
            return int(raw)
        except ValueError:
            pass
    return _GLOBAL_TTS_BUDGET_DEFAULT


def _tts_chars_user_key(user_id: str) -> str:
    month = datetime.now(timezone.utc).strftime("%Y-%m")
    return f"tts:chars:{user_id}:{month}"


def _tts_chars_global_key() -> str:
    month = datetime.now(timezone.utc).strftime("%Y-%m")
    return f"tts:chars:global:{month}"


def check_tts_chars_quota(
    user_id: str, user_tier: str, chars_requested: int
) -> tuple[bool, str | None, int, int]:
    """
    Check whether a TTS request of *chars_requested* characters is allowed.

    Returns (allowed, reason, current_chars, limit) where reason is one of:
      None                 — allowed
      'user_cap_exceeded'  — this user has used their monthly char budget
      'global_cap_exceeded' — overall ElevenLabs budget for the month is spent
      'tier_locked'        — tier doesn't include TTS (limit=0); use flutter_tts

    Never raises; degrades open on Redis errors except the tier=0 path which
    is a code-only check (no Redis needed).
    """
    user_limit = _get_tts_char_limit(user_tier)
    if user_limit <= 0:
        return False, 'tier_locked', 0, 0

    r = _get_redis()
    if r is None:
        # Redis missing — allow the call so a Redis outage doesn't break TTS
        return True, None, 0, user_limit

    try:
        user_key = _tts_chars_user_key(user_id)
        user_used = int(r.get(user_key) or 0)
        if user_used + chars_requested > user_limit:
            logger.warning(
                "tts_chars: user=%s tier=%s used=%d req=%d limit=%d — user cap",
                user_id, user_tier, user_used, chars_requested, user_limit,
            )
            return False, 'user_cap_exceeded', user_used, user_limit

        global_budget = _get_global_tts_budget()
        global_key = _tts_chars_global_key()
        global_used = int(r.get(global_key) or 0)
        if global_used + chars_requested > global_budget:
            logger.warning(
                "tts_chars: GLOBAL used=%d req=%d budget=%d — global cap",
                global_used, chars_requested, global_budget,
            )
            return False, 'global_cap_exceeded', global_used, global_budget

        return True, None, user_used, user_limit
    except Exception as exc:
        logger.warning("tts_chars: Redis error during check (%s) — allowing", exc)
        return True, None, 0, user_limit


def increment_tts_chars(user_id: str, user_tier: str, chars: int) -> None:
    """Increment per-user and global monthly char counters after success.

    35-day TTL covers month boundaries without orphan keys. No-op on Redis error.
    """
    if chars <= 0:
        return
    r = _get_redis()
    if r is None:
        return
    try:
        pipe = r.pipeline()
        pipe.incrby(_tts_chars_user_key(user_id), chars)
        pipe.expire(_tts_chars_user_key(user_id), 60 * 60 * 24 * 35)
        pipe.incrby(_tts_chars_global_key(), chars)
        pipe.expire(_tts_chars_global_key(), 60 * 60 * 24 * 35)
        pipe.execute()
    except Exception as exc:
        logger.warning("tts_chars: Redis error during increment (%s)", exc)


# ---------------------------------------------------------------------------
# Illustration monthly quota (per-image, used by ALL non-BYOK paths)
#
# Flux Schnell ($0.003/image) makes per-page illustrations economical even at
# generous caps. As of 2026-05-17 the Sprout (age <=5) band ALSO routes to
# Flux Schnell as its primary provider and is metered here — it is no longer
# unmetered. Sprout uses a SEPARATE, much more generous cap because a Sprout
# picture book is ~10 images per story (vs ~5 for the 6+ bands) and per-page
# art is essential to that band's experience.
#
# Two cap families, selected by the `is_sprout` parameter on the quota
# functions (the route passes is_sprout=(age <= 5)):
#   - is_sprout=False → ages-6+ caps  (free 10 / premium 100 / family 200)
#   - is_sprout=True  → Sprout caps   (free 60 / premium 250 / family 500)
# Both families share ONE Redis counter per user/month (`illust:{uid}:{month}`)
# — a user is either in the Sprout band or not for a given request, and the
# cap simply differs; this avoids a second counter and keeps TTLs simple.
#
# BYOK still bypasses entirely: BYOK users pay Google directly, no server-side
# cost to meter (byok tier resolves to the 0 sentinel; route skips the check).
# ---------------------------------------------------------------------------

_ILLUSTRATION_MONTHLY_LIMITS: dict[str, int] = {
    "free": 10,       # ~2 illustrated stories at 5 pages each
    "premium": 100,   # ~20 illustrated stories at 5 pages each
    "family": 200,    # ~40 illustrated stories at 5 pages each
    "byok": 0,        # BYOK uses user's Google key (Sentinel; route should
                      # bypass the quota check entirely for BYOK)
}

# Sprout (age <=5) caps — generous because a Sprout picture book is ~10
# images each and per-page art is core to the 3-5 experience.
_ILLUSTRATION_SPROUT_MONTHLY_LIMITS: dict[str, int] = {
    "free": 60,       # ~6 Sprout picture books at 10 pages each
    "premium": 250,   # ~25 Sprout picture books at 10 pages each
    "family": 500,    # ~50 Sprout picture books at 10 pages each
    "byok": 0,        # BYOK sentinel — route bypasses the check entirely
}

_ENV_ILLUSTRATION_OVERRIDES = {
    "free": "ILLUSTRATIONS_FREE",
    "premium": "ILLUSTRATIONS_PREMIUM",
    "family": "ILLUSTRATIONS_FAMILY",
}

_ENV_ILLUSTRATION_SPROUT_OVERRIDES = {
    "free": "ILLUSTRATIONS_SPROUT_FREE",
    "premium": "ILLUSTRATIONS_SPROUT_PREMIUM",
    "family": "ILLUSTRATIONS_SPROUT_FAMILY",
}


def _get_illustration_limit(tier: str, is_sprout: bool = False) -> int:
    """Resolve the monthly illustration cap for *tier*.

    When *is_sprout* is True the (more generous) Sprout cap family and its
    `ILLUSTRATIONS_SPROUT_*` env overrides are used; otherwise the ages-6+
    caps and `ILLUSTRATIONS_*` overrides apply.
    """
    if is_sprout:
        env_key = _ENV_ILLUSTRATION_SPROUT_OVERRIDES.get(tier)
        limits = _ILLUSTRATION_SPROUT_MONTHLY_LIMITS
    else:
        env_key = _ENV_ILLUSTRATION_OVERRIDES.get(tier)
        limits = _ILLUSTRATION_MONTHLY_LIMITS
    if env_key and os.getenv(env_key):
        try:
            return int(os.getenv(env_key))
        except ValueError:
            pass
    return limits.get(tier, limits["free"])


def _illustration_user_key(user_id: str) -> str:
    month = datetime.now(timezone.utc).strftime("%Y-%m")
    return f"illust:{user_id}:{month}"


# MT-169 — fail-CLOSED cost breaker for illustration generation.
#
# Image generation is real provider spend (~$0.0375/image on OpenRouter, plus
# Flux Schnell on Cloudflare/Replicate). On a Redis outage we cannot meter the
# monthly cap and must NOT fail open. ILLUSTRATIONS_EMERGENCY_MULTIPLIER * the
# tier's monthly cap = the conservative monthly cap enforced against the DB
# counter `User.illustrations_generated_this_month`. Default 3 keeps a short
# Redis blip invisible to users while strictly bounding spend during a longer
# outage. Mirrors the AI_QUOTA_EMERGENCY_MULTIPLIER design for `check_daily_quota`.
_ILLUSTRATION_EMERGENCY_MULTIPLIER_ENV = "ILLUSTRATIONS_EMERGENCY_MULTIPLIER"
_ILLUSTRATION_EMERGENCY_MULTIPLIER_DEFAULT = 3


def _get_illustration_emergency_cap(tier: str, is_sprout: bool = False) -> int | None:
    """Conservative monthly illustration cap used while Redis is unavailable.

    Returns None for BYOK / sentinel-0 tiers (no server-side cost to cap; the
    route is expected to bypass the call entirely for BYOK users).
    """
    base = _get_illustration_limit(tier, is_sprout=is_sprout)
    if base <= 0:
        return None
    raw = os.getenv(_ILLUSTRATION_EMERGENCY_MULTIPLIER_ENV)
    multiplier = _ILLUSTRATION_EMERGENCY_MULTIPLIER_DEFAULT
    if raw:
        try:
            multiplier = max(1, int(raw))
        except ValueError:
            pass
    return base * multiplier


def _db_illustration_count(user_id: str) -> int | None:
    """Return the monthly DB illustration count for *user_id*, or None.

    Best-effort, lazy-imported — returns None outside an app context or when
    the User row cannot be loaded (e.g. anon sessions, DB outage). Triggers a
    monthly rollover if `usage_reset_date` has passed (cheap UPDATE).
    """
    db, user = _load_user(user_id)
    if user is None:
        return None
    _maybe_reset_monthly(db, user)
    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
    return int(getattr(user, "illustrations_generated_this_month", 0) or 0)


def _illustration_db_fallback(
    user_id: str, user_tier: str, num_images: int, is_sprout: bool, redis_limit: int,
    reason: str,
) -> tuple[bool, int, int]:
    """Shared fail-CLOSED path for `check_illustration_quota` (MT-169).

    Called when Redis is unreachable OR errors mid-call. Enforces the DB-backed
    `User.illustrations_generated_this_month` counter against the emergency
    cap. If the DB counter is also unavailable (degenerate case — outside app
    context, anon user, DB outage) we ALERT and allow, matching M-2's escape
    hatch: hard-blocking on double-outage takes the whole product down and is
    worse than briefly unmetered cost.
    """
    emergency_cap = _get_illustration_emergency_cap(user_tier, is_sprout=is_sprout)
    db_count = _db_illustration_count(user_id)
    if db_count is None or emergency_cap is None:
        logger.error(
            "ALERT illustration_quota: %s and DB counter unavailable for "
            "user=%s tier=%s sprout=%s — image cost is UNMETERED this request",
            reason, user_id, user_tier, is_sprout,
        )
        return True, 0, redis_limit
    logger.error(
        "ALERT illustration_quota: %s — cost breaker on DB fallback for "
        "user=%s tier=%s sprout=%s count=%d emergency_cap=%d req=%d",
        reason, user_id, user_tier, is_sprout, db_count, emergency_cap, num_images,
    )
    if db_count + max(1, num_images) > emergency_cap:
        logger.warning(
            "illustration_quota: user=%s tier=%s sprout=%s DB count=%d req=%d "
            "> emergency_cap=%d — blocked while Redis down",
            user_id, user_tier, is_sprout, db_count, num_images, emergency_cap,
        )
        return False, db_count, emergency_cap
    return True, db_count, emergency_cap


def check_illustration_quota(
    user_id: str, user_tier: str, num_images: int = 1, is_sprout: bool = False
) -> tuple[bool, int, int]:
    """Check whether *user_id* is within their monthly illustration quota.

    Returns (allowed, current_used, limit).
    - allowed=True  → the requested num_images all fit under the cap
    - allowed=False → at least one would push over; caller should return [] /
                      surface the upgrade CTA
    - *is_sprout* selects the generous Sprout cap family (see module comment).

    MT-169: on Redis outage this now fails CLOSED to the DB counter
    `User.illustrations_generated_this_month` enforced against the
    `ILLUSTRATIONS_EMERGENCY_MULTIPLIER`-scaled cap (default 3x). Previously
    returned `allowed=True` on Redis errors, which uncapped image-gen spend
    during a Redis blip. The DB counter is maintained by
    `increment_illustration_quota` even while Redis is healthy so it's always
    a usable baseline.
    """
    limit = _get_illustration_limit(user_tier, is_sprout=is_sprout)
    if limit <= 0:
        return False, 0, 0

    r = _get_redis()
    if r is None:
        return _illustration_db_fallback(
            user_id, user_tier, num_images, is_sprout, limit,
            reason="Redis DOWN",
        )

    try:
        used = int(r.get(_illustration_user_key(user_id)) or 0)
        if used + max(1, num_images) > limit:
            logger.warning(
                "illustration_quota: user=%s tier=%s sprout=%s used=%d req=%d limit=%d — capped",
                user_id, user_tier, is_sprout, used, num_images, limit,
            )
            return False, used, limit
        return True, used, limit
    except Exception as exc:
        # Redis pinged OK but GET errored — treat like an outage and fall back
        # to the DB cost breaker rather than allowing blindly.
        return _illustration_db_fallback(
            user_id, user_tier, num_images, is_sprout, limit,
            reason=f"Redis error during check ({exc})",
        )


def increment_illustration_quota(user_id: str, user_tier: str, num_images: int = 1) -> None:
    """Bump per-user monthly illustration counter after success.

    Dual-writes (MT-169):
      * Redis monthly counter (primary enforced limit, 35-day TTL)
      * DB counter `User.illustrations_generated_this_month` — kept current so
        the cost breaker in `check_illustration_quota` has a truthful baseline
        when Redis is down.

    Sprout and ages-6+ share this single counter — only the cap (checked above)
    differs by band. No-op when num_images <= 0. Never raises.
    """
    if num_images <= 0:
        return

    # Always maintain the DB counter (cheap UPDATE) so the cost breaker has a
    # truthful baseline if Redis later goes down mid-month.
    db, user = _load_user(user_id)
    if user is not None:
        try:
            _maybe_reset_monthly(db, user)
            user.illustrations_generated_this_month = int(
                getattr(user, "illustrations_generated_this_month", 0) or 0
            ) + num_images
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            logger.warning(
                "illustration_quota: DB counter increment failed for %s (%s)",
                user_id, exc,
            )

    r = _get_redis()
    if r is None:
        return
    try:
        pipe = r.pipeline()
        pipe.incrby(_illustration_user_key(user_id), num_images)
        pipe.expire(_illustration_user_key(user_id), 60 * 60 * 24 * 35)
        pipe.execute()
    except Exception as exc:
        logger.warning("illustration_quota: Redis error during increment (%s)", exc)
