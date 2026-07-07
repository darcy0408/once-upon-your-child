"""Unit tests for the Redis-backed shared task-ownership store
(backend/utils/task_owner.py).

Context (async-task-delivery fix, 2026-07-07): /task-status is polled
repeatedly and can land on ANY gunicorn worker process. Ownership used to be
cached via Flask-Caching's `cache` object, whose CACHE_TYPE is "simple" (an
in-process dict) in every environment including production — so a poll that
landed on a worker OTHER than the one that originally cached the owner saw a
cache miss and the route treated the task as unknown, returning 404 even
though it was genuinely in flight. Polling the same task_id repeatedly would
flip between 200 "processing" and 404 depending on which worker answered.

These tests cover the replacement module directly (mocking the Redis client,
matching the existing `task_cancellation.py` test pattern) plus the
route-level 404-vs-processing behavior this was supposed to fix.
"""

from __future__ import annotations

from unittest.mock import MagicMock

from backend.utils import task_owner


# ---------------------------------------------------------------------------
# cache_task_owner
# ---------------------------------------------------------------------------
class TestCacheTaskOwner:
    def test_writes_to_redis_with_ttl(self, mocker):
        client = MagicMock()
        mocker.patch.object(task_owner, "_get_redis", return_value=client)

        task_owner.cache_task_owner("task-abc", "user-1")

        client.setex.assert_called_once_with(
            "task-owner:task-abc", task_owner._OWNER_TTL_SECONDS, "user-1"
        )

    def test_noop_when_task_id_missing(self, mocker):
        get_redis = mocker.patch.object(task_owner, "_get_redis")
        task_owner.cache_task_owner(None, "user-1")
        get_redis.assert_not_called()

    def test_noop_when_user_id_missing(self, mocker):
        get_redis = mocker.patch.object(task_owner, "_get_redis")
        task_owner.cache_task_owner("task-abc", None)
        get_redis.assert_not_called()

    def test_swallows_redis_error(self, mocker):
        """Best-effort: a Redis write failure must not raise."""
        client = MagicMock()
        client.setex.side_effect = RuntimeError("redis down")
        mocker.patch.object(task_owner, "_get_redis", return_value=client)

        # Must not raise.
        task_owner.cache_task_owner("task-abc", "user-1")

    def test_noop_when_redis_unavailable(self, mocker):
        mocker.patch.object(task_owner, "_get_redis", return_value=None)
        # Must not raise even though there is no client to write to.
        task_owner.cache_task_owner("task-abc", "user-1")


# ---------------------------------------------------------------------------
# resolve_task_owner
# ---------------------------------------------------------------------------
class TestResolveTaskOwner:
    def test_none_task_id_returns_none(self):
        assert task_owner.resolve_task_owner(None, task=MagicMock()) is None

    def test_reads_owner_from_shared_redis_store(self, mocker):
        """The whole point of the fix: ownership comes from Redis, which
        every worker process shares — not from anything process-local."""
        client = MagicMock()
        client.get.return_value = b"user-42"
        mocker.patch.object(task_owner, "_get_redis", return_value=client)

        task = MagicMock(info=None, result=None)
        owner = task_owner.resolve_task_owner("task-abc", task)

        assert owner == "user-42"
        client.get.assert_called_once_with("task-owner:task-abc")

    def test_cross_worker_lookup_survives_a_fresh_process(self, mocker):
        """Simulates two different processes (e.g. two gunicorn workers):
        the WRITE happens against one Redis client instance, the READ
        happens against a completely separate client instance/connection
        (a fresh mock standing in for 'a different worker's redis-py
        client'). Because both go through the same shared Redis keyspace,
        the second process still resolves the owner correctly — this is
        the split-brain that the old per-process Flask-Caching cache could
        not provide.
        """
        shared_store: dict[str, bytes] = {}

        write_client = MagicMock()
        write_client.setex.side_effect = (
            lambda key, ttl, value: shared_store.__setitem__(
                key, value.encode() if isinstance(value, str) else value
            )
        )

        read_client = MagicMock()
        read_client.get.side_effect = lambda key: shared_store.get(key)

        # "Worker A" handles the POST and writes ownership.
        mocker.patch.object(task_owner, "_get_redis", return_value=write_client)
        task_owner.cache_task_owner("task-xyz", "user-7")

        # "Worker B" (a different process, fresh Redis connection object)
        # handles the poll.
        mocker.patch.object(task_owner, "_get_redis", return_value=read_client)
        owner = task_owner.resolve_task_owner("task-xyz", task=MagicMock())

        assert owner == "user-7"

    def test_falls_back_to_task_info_user_id_when_redis_has_no_record(self, mocker):
        mocker.patch.object(task_owner, "_get_redis", return_value=None)
        task = MagicMock(info={"user_id": "user-9"}, result=None)

        assert task_owner.resolve_task_owner("task-abc", task) == "user-9"

    def test_falls_back_to_task_result_user_id_when_no_info(self, mocker):
        mocker.patch.object(task_owner, "_get_redis", return_value=None)
        task = MagicMock(info=None, result={"user_id": "user-9"})

        assert task_owner.resolve_task_owner("task-abc", task) == "user-9"

    def test_returns_none_when_no_owner_can_be_determined(self, mocker):
        """This is the case that used to (incorrectly) manifest as an
        intermittent 404 for a task that is genuinely in flight: Redis has
        no record (e.g. a worker crashed before writing it, or it's a
        fresh in-flight task whose Celery meta doesn't carry user_id yet)."""
        mocker.patch.object(task_owner, "_get_redis", return_value=None)
        task = MagicMock(info=None, result=None)

        assert task_owner.resolve_task_owner("task-abc", task) is None

    def test_redis_read_error_falls_back_to_task_metadata(self, mocker):
        """A Redis hiccup on read must not raise — it degrades to the
        Celery-result-based fallback rather than blowing up the request."""
        client = MagicMock()
        client.get.side_effect = RuntimeError("redis down")
        mocker.patch.object(task_owner, "_get_redis", return_value=client)
        task = MagicMock(info={"user_id": "user-9"}, result=None)

        assert task_owner.resolve_task_owner("task-abc", task) == "user-9"
