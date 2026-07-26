"""Tests for the global daily generation circuit breaker (DEFCON audit
2026-07-25, Finding #1).

Per-user quotas are keyed to self-mintable anonymous identities, so they
bound per-identity spend only. `check_global_gen_budget` /
`increment_global_gen` add one shared Redis counter per generation kind
('story' | 'image' | 'avatar') per UTC day, mirroring the TTS global char
budget.

Follows the _FakeRedis style of test_ai_quota_monthly.py: pure unit tests
against `backend.utils.ai_quota`, no Flask app context.
"""

from __future__ import annotations

import pytest


class _FakePipeline:
    """Minimal stand-in for a redis-py pipeline (incrby/expire/execute)."""

    def __init__(self, store: dict):
        self._store = store
        self._ops = []

    def incrby(self, key, n):
        self._ops.append(("incrby", key, n))
        return self

    def expire(self, key, ttl):
        self._ops.append(("expire", key, ttl))
        return self

    def execute(self):
        for op in self._ops:
            if op[0] == "incrby":
                _, key, n = op
                self._store[key] = int(self._store.get(key, 0)) + n
        self._ops = []


class _FakeRedis:
    def __init__(self):
        self.store: dict = {}

    def get(self, key):
        return self.store.get(key)

    def pipeline(self):
        return _FakePipeline(self.store)


class _BrokenRedis:
    """Raises on every operation, simulating a mid-request Redis outage."""

    def get(self, key):
        raise ConnectionError("redis down")

    def pipeline(self):
        raise ConnectionError("redis down")


@pytest.fixture()
def fake_redis(monkeypatch):
    from backend.utils import ai_quota

    r = _FakeRedis()
    monkeypatch.setattr(ai_quota, "_get_redis", lambda: r)
    return r


class TestCapResolution:
    def test_defaults(self):
        from backend.utils.ai_quota import _get_global_gen_cap

        assert _get_global_gen_cap("story") == 500
        assert _get_global_gen_cap("image") == 500
        assert _get_global_gen_cap("avatar") == 100

    def test_env_override(self, monkeypatch):
        from backend.utils.ai_quota import _get_global_gen_cap

        monkeypatch.setenv("GLOBAL_STORY_DAILY_CAP", "7")
        assert _get_global_gen_cap("story") == 7

    def test_bad_env_value_falls_back_to_default(self, monkeypatch):
        from backend.utils.ai_quota import _get_global_gen_cap

        monkeypatch.setenv("GLOBAL_AVATAR_DAILY_CAP", "lots")
        assert _get_global_gen_cap("avatar") == 100


class TestCheckGlobalGenBudget:
    def test_allows_under_cap(self, fake_redis):
        from backend.utils.ai_quota import check_global_gen_budget

        allowed, used, cap = check_global_gen_budget("story")
        assert allowed is True
        assert used == 0
        assert cap == 500

    def test_blocks_at_cap(self, fake_redis, monkeypatch):
        from backend.utils import ai_quota

        monkeypatch.setenv("GLOBAL_STORY_DAILY_CAP", "3")
        fake_redis.store[ai_quota._global_gen_key("story")] = 3

        allowed, used, cap = ai_quota.check_global_gen_budget("story")
        assert allowed is False
        assert (used, cap) == (3, 3)

    def test_kinds_are_independent(self, fake_redis, monkeypatch):
        from backend.utils import ai_quota

        monkeypatch.setenv("GLOBAL_IMAGE_DAILY_CAP", "1")
        fake_redis.store[ai_quota._global_gen_key("image")] = 1

        assert ai_quota.check_global_gen_budget("image")[0] is False
        assert ai_quota.check_global_gen_budget("story")[0] is True
        assert ai_quota.check_global_gen_budget("avatar")[0] is True

    def test_zero_cap_is_emergency_stop(self, fake_redis, monkeypatch):
        from backend.utils.ai_quota import check_global_gen_budget

        monkeypatch.setenv("GLOBAL_STORY_DAILY_CAP", "0")
        assert check_global_gen_budget("story")[0] is False

    def test_negative_cap_disables_breaker(self, fake_redis, monkeypatch):
        from backend.utils import ai_quota

        monkeypatch.setenv("GLOBAL_STORY_DAILY_CAP", "-1")
        fake_redis.store[ai_quota._global_gen_key("story")] = 10_000_000
        assert ai_quota.check_global_gen_budget("story")[0] is True

    def test_redis_missing_allows(self, monkeypatch):
        from backend.utils import ai_quota

        monkeypatch.setattr(ai_quota, "_get_redis", lambda: None)
        assert ai_quota.check_global_gen_budget("story")[0] is True

    def test_redis_error_allows(self, monkeypatch):
        from backend.utils import ai_quota

        monkeypatch.setattr(ai_quota, "_get_redis", lambda: _BrokenRedis())
        assert ai_quota.check_global_gen_budget("story")[0] is True

    def test_zero_cap_blocks_even_without_redis(self, monkeypatch):
        """The emergency stop must hold during a Redis outage too — it is a
        code-only check that never touches Redis."""
        from backend.utils import ai_quota

        monkeypatch.setenv("GLOBAL_STORY_DAILY_CAP", "0")
        monkeypatch.setattr(ai_quota, "_get_redis", lambda: None)
        assert ai_quota.check_global_gen_budget("story")[0] is False


class TestIncrementGlobalGen:
    def test_increments_and_expires(self, fake_redis):
        from backend.utils import ai_quota

        ai_quota.increment_global_gen("story")
        ai_quota.increment_global_gen("story", 2)
        assert fake_redis.store[ai_quota._global_gen_key("story")] == 3

    def test_noop_on_zero_or_negative(self, fake_redis):
        from backend.utils import ai_quota

        ai_quota.increment_global_gen("image", 0)
        ai_quota.increment_global_gen("image", -4)
        assert ai_quota._global_gen_key("image") not in fake_redis.store

    def test_never_raises_on_redis_error(self, monkeypatch):
        from backend.utils import ai_quota

        monkeypatch.setattr(ai_quota, "_get_redis", lambda: _BrokenRedis())
        ai_quota.increment_global_gen("avatar")  # must not raise

    def test_check_sees_increments(self, fake_redis, monkeypatch):
        from backend.utils import ai_quota

        monkeypatch.setenv("GLOBAL_AVATAR_DAILY_CAP", "2")
        assert ai_quota.check_global_gen_budget("avatar")[0] is True
        ai_quota.increment_global_gen("avatar")
        assert ai_quota.check_global_gen_budget("avatar")[0] is True
        ai_quota.increment_global_gen("avatar")
        assert ai_quota.check_global_gen_budget("avatar")[0] is False


class TestStoryFunnelIntegration:
    """The Celery-side funnel degrades to the static story on a tripped cap
    and counts successful provider calls."""

    def test_blocked_returns_static_fallback_without_provider_call(self, monkeypatch):
        from backend.tasks import story_tasks

        monkeypatch.setenv("GLOBAL_STORY_DAILY_CAP", "0")

        def _boom(*args, **kwargs):  # any provider attempt is a failure
            raise AssertionError("provider chain must not run on a tripped cap")

        monkeypatch.setattr(story_tasks, "_attempt_story_providers", _boom)

        text, provider, sequence = story_tasks._generate_story_text_with_metadata(
            "prompt", "adventure", "Milo"
        )
        assert provider == "static"
        assert sequence == ["static(global_cap)"]
        assert text  # the child still gets a story

    def test_successful_provider_call_increments(self, monkeypatch):
        from backend.tasks import story_tasks
        from backend.utils import ai_quota

        counted = []
        monkeypatch.setattr(
            ai_quota, "increment_global_gen", lambda kind, n=1: counted.append(kind)
        )
        monkeypatch.setattr(
            story_tasks,
            "_attempt_story_providers",
            lambda *a, **k: ("Once upon a time...", "openai", ["openai"]),
        )

        _text, provider, _seq = story_tasks._generate_story_text_with_metadata(
            "prompt", "adventure", "Milo"
        )
        assert provider == "openai"
        assert counted == ["story"]

    def test_static_fallback_does_not_increment(self, monkeypatch):
        from backend.tasks import story_tasks
        from backend.utils import ai_quota

        counted = []
        monkeypatch.setattr(
            ai_quota, "increment_global_gen", lambda kind, n=1: counted.append(kind)
        )
        monkeypatch.setattr(
            story_tasks,
            "_attempt_story_providers",
            lambda *a, **k: ("A quiet day...", "static", ["static"]),
        )

        story_tasks._generate_story_text_with_metadata("prompt", "adventure", "Milo")
        assert counted == []


class TestInteractiveIntegration:
    def test_generate_text_raises_on_tripped_cap(self, monkeypatch):
        from backend.services.interactive_adventure_service import (
            InteractiveAdventureService,
        )
        from backend.utils.ai_quota import GlobalCapExceeded

        monkeypatch.setenv("GLOBAL_STORY_DAILY_CAP", "0")

        service = InteractiveAdventureService()
        with pytest.raises(GlobalCapExceeded):
            service._generate_text("prompt")
