"""
Per-user daily AI generation quota enforced via Redis.

Provides a circuit breaker that prevents a single account from generating
unbounded Gemini calls in a 24-hour window — guarding against both
accidental abuse and deliberate cost attacks.

Limits are checked BEFORE the Gemini call and incremented AFTER a
successful response so failed/safety-blocked generations don't count
against the user's quota.

Redis keys: ai:quota:{user_id}:{YYYY-MM-DD}  (TTL: 2 days)

Graceful degradation: if Redis is unreachable the check is skipped with
a WARNING so a Redis outage never blocks story generation.
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


def check_daily_quota(user_id: str, user_tier: str) -> tuple[bool, int, int | None]:
    """
    Check whether *user_id* is within their daily generation quota.

    Returns (allowed, current_count, limit).
    - allowed=True  → generation may proceed
    - allowed=False → quota exceeded; caller should return 429
    - limit=None    → unlimited (BYOK)

    Never raises; falls back to allowed=True on Redis errors.
    """
    limit = _get_limit(user_tier)
    if limit is None:
        return True, 0, None

    r = _get_redis()
    if r is None:
        return True, 0, limit  # degrade gracefully

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
        logger.warning("ai_quota: Redis error during check (%s) — allowing request", exc)
        return True, 0, limit


def increment_daily_quota(user_id: str, user_tier: str) -> None:
    """
    Increment the daily counter for *user_id* after a successful generation.
    Sets a 2-day TTL so keys expire automatically without a cleanup job.
    No-op if Redis is unavailable or user is BYOK.
    """
    if user_tier in _BYOK_TIERS or _get_limit(user_tier) is None:
        return

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
