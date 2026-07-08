"""Tests for the monthly story-generation quota (2026-07-05 pricing decision).

Pricing decision: free = 5 stories/month (2/day client smoothing), premium =
150/month (10/day client smoothing). The DAILY limits in ai_quota are now
deliberately +1 above the client-side smoothing caps so timezone drift never
false-429s a legitimate request — the MONTHLY limit is the real,
authoritative backstop enforced here.

Follows the style of TestIllustrationQuota in test_image_routing.py: pure
unit tests against `backend.utils.ai_quota`, no Flask app context needed
except where a DB-backed fallback is monkeypatched directly.
"""

from __future__ import annotations


class _FakePipeline:
    """Minimal stand-in for a redis-py pipeline (incr/expire/execute)."""

    def __init__(self, store: dict):
        self._store = store
        self._ops = []

    def incr(self, key):
        self._ops.append(("incr", key))
        return self

    def expire(self, key, ttl):
        self._ops.append(("expire", key, ttl))
        return self

    def execute(self):
        for op in self._ops:
            if op[0] == "incr":
                key = op[1]
                self._store[key] = int(self._store.get(key, 0)) + 1
        self._ops = []


class _FakeRedis:
    """Minimal stand-in for a redis-py client backed by an in-memory dict."""

    def __init__(self):
        self.store: dict = {}

    def get(self, key):
        return self.store.get(key)

    def pipeline(self):
        return _FakePipeline(self.store)


class TestMonthlyLimitResolution:
    def test_free_monthly_limit_is_5(self):
        from backend.utils.ai_quota import _get_monthly_limit

        assert _get_monthly_limit("free") == 5

    def test_premium_monthly_limit_is_150(self):
        from backend.utils.ai_quota import _get_monthly_limit

        assert _get_monthly_limit("premium") == 150

    def test_family_monthly_limit_is_unlimited(self):
        """0 in _MONTHLY_STORY_LIMITS means unlimited (None)."""
        from backend.utils.ai_quota import _get_monthly_limit

        assert _get_monthly_limit("family") is None

    def test_byok_monthly_limit_is_unlimited(self):
        from backend.utils.ai_quota import _get_monthly_limit

        assert _get_monthly_limit("byok") is None

    def test_free_daily_limit_is_3(self):
        """Daily cap now +1 headroom over the 2/day client smoothing cap."""
        from backend.utils.ai_quota import _get_limit

        assert _get_limit("free") == 3

    def test_premium_daily_limit_is_15(self):
        """Daily cap now +1 headroom over the 10/day client smoothing cap."""
        from backend.utils.ai_quota import _get_limit

        assert _get_limit("premium") == 15

    def test_monthly_env_override_free(self, monkeypatch):
        monkeypatch.setenv("AI_QUOTA_MONTHLY_FREE", "8")
        from backend.utils.ai_quota import _get_monthly_limit

        assert _get_monthly_limit("free") == 8

    def test_monthly_env_override_zero_means_unlimited(self, monkeypatch):
        monkeypatch.setenv("AI_QUOTA_MONTHLY_PREMIUM", "0")
        from backend.utils.ai_quota import _get_monthly_limit

        assert _get_monthly_limit("premium") is None


class TestCheckDailyQuotaMonthlyEnforcement:
    """check_daily_quota now enforces BOTH a daily and a monthly cap."""

    def test_byok_exempt_returns_unlimited(self):
        from backend.utils.ai_quota import check_daily_quota

        allowed, count, limit, period = check_daily_quota("user-x", "byok")
        assert allowed is True
        assert limit is None
        assert period == ""

    def test_allowed_under_both_caps(self, monkeypatch):
        from backend.utils import ai_quota

        fake = _FakeRedis()
        monkeypatch.setattr(ai_quota, "_get_redis", lambda: fake)
        # free: daily limit 3, monthly limit 5. No usage yet.
        allowed, count, limit, period = ai_quota.check_daily_quota("user-x", "free")
        assert allowed is True
        assert limit == 3  # daily limit reported when under both
        assert period == ""

    def test_blocked_at_daily_limit_before_monthly(self, monkeypatch):
        """Daily limit trips first even if the monthly count is still low."""
        from backend.utils import ai_quota

        fake = _FakeRedis()
        fake.store[ai_quota._redis_key("user-x")] = 3  # at the daily cap
        monkeypatch.setattr(ai_quota, "_get_redis", lambda: fake)
        allowed, count, limit, period = ai_quota.check_daily_quota("user-x", "free")
        assert allowed is False
        assert period == "daily"
        assert limit == 3
        assert count == 3

    def test_blocked_at_monthly_limit_when_under_daily(self, monkeypatch):
        """The real backstop: monthly cap trips even though today's count is
        under the daily cap (e.g. spread across many days this month)."""
        from backend.utils import ai_quota

        fake = _FakeRedis()
        fake.store[ai_quota._redis_key("user-x")] = 1  # under daily cap (3)
        fake.store[ai_quota._monthly_redis_key("user-x")] = 5  # at monthly cap
        monkeypatch.setattr(ai_quota, "_get_redis", lambda: fake)
        allowed, count, limit, period = ai_quota.check_daily_quota("user-x", "free")
        assert allowed is False
        assert period == "monthly"
        assert limit == 5
        assert count == 5

    def test_allowed_under_monthly_limit(self, monkeypatch):
        from backend.utils import ai_quota

        fake = _FakeRedis()
        fake.store[ai_quota._redis_key("user-x")] = 1
        fake.store[ai_quota._monthly_redis_key("user-x")] = 4  # under 5
        monkeypatch.setattr(ai_quota, "_get_redis", lambda: fake)
        allowed, count, limit, period = ai_quota.check_daily_quota("user-x", "free")
        assert allowed is True
        assert period == ""

    def test_family_unlimited_monthly_never_blocks_on_monthly(self, monkeypatch):
        """Family has no monthly cap (0 = unlimited) — only the (generous)
        daily cap of 75 can block."""
        from backend.utils import ai_quota

        fake = _FakeRedis()
        fake.store[ai_quota._monthly_redis_key("user-x")] = 10_000
        monkeypatch.setattr(ai_quota, "_get_redis", lambda: fake)
        allowed, count, limit, period = ai_quota.check_daily_quota("user-x", "family")
        assert allowed is True


class TestCheckDailyQuotaDbFallback:
    """M-2 fail-CLOSED path: Redis down → DB counter vs
    min(emergency_cap, monthly_limit)."""

    def test_redis_down_allows_under_effective_cap(self, monkeypatch):
        from backend.utils import ai_quota

        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        monkeypatch.delenv("AI_QUOTA_EMERGENCY_MULTIPLIER", raising=False)
        # free: daily=3, emergency multiplier default 3 -> emergency_cap=9.
        # monthly_limit=5 -> effective_cap = min(9, 5) = 5.
        monkeypatch.setattr(ai_quota, "_db_story_count", lambda _uid: 4)
        allowed, count, limit, period = ai_quota.check_daily_quota("user-x", "free")
        assert allowed is True
        assert count == 4
        assert limit == 5  # min(emergency=9, monthly=5)

    def test_redis_down_blocks_at_effective_cap_reports_monthly_period(
        self, monkeypatch
    ):
        from backend.utils import ai_quota

        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        monkeypatch.delenv("AI_QUOTA_EMERGENCY_MULTIPLIER", raising=False)
        monkeypatch.setattr(ai_quota, "_db_story_count", lambda _uid: 5)
        allowed, count, limit, period = ai_quota.check_daily_quota("user-x", "free")
        assert allowed is False
        assert limit == 5
        assert period == "monthly"

    def test_redis_down_family_uses_pure_emergency_cap(self, monkeypatch):
        """Family has no monthly limit, so the DB fallback degrades to the
        plain emergency cap (daily 75 x multiplier 3 = 225)."""
        from backend.utils import ai_quota

        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        monkeypatch.delenv("AI_QUOTA_EMERGENCY_MULTIPLIER", raising=False)
        monkeypatch.setattr(ai_quota, "_db_story_count", lambda _uid: 200)
        allowed, count, limit, period = ai_quota.check_daily_quota("user-x", "family")
        assert allowed is True
        assert limit == 225

    def test_redis_down_no_db_falls_through_to_allow(self, monkeypatch):
        """Double-outage escape hatch (M-2): Redis down AND no DB user →
        allow + ALERT log, matching the pre-existing precedent."""
        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        from backend.utils.ai_quota import check_daily_quota

        allowed, count, limit, period = check_daily_quota("user-x", "free")
        assert allowed is True
        assert limit == 3  # daily limit as the reported ceiling
        assert period == ""


class TestIncrementDailyQuotaBumpsMonthlyCounter:
    def test_increment_bumps_both_daily_and_monthly_redis_keys(self, monkeypatch):
        from backend.utils import ai_quota

        fake = _FakeRedis()
        monkeypatch.setattr(ai_quota, "_get_redis", lambda: fake)
        # Avoid touching the DB counter — no Flask app context in this test.
        monkeypatch.setattr(ai_quota, "_load_user", lambda _uid: (None, None))

        ai_quota.increment_daily_quota("user-x", "free")

        assert fake.store[ai_quota._redis_key("user-x")] == 1
        assert fake.store[ai_quota._monthly_redis_key("user-x")] == 1

    def test_increment_noop_for_byok(self, monkeypatch):
        from backend.utils import ai_quota

        fake = _FakeRedis()
        monkeypatch.setattr(ai_quota, "_get_redis", lambda: fake)
        ai_quota.increment_daily_quota("user-x", "byok")
        assert fake.store == {}
