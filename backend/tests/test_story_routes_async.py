from unittest.mock import MagicMock

import pytest

from backend.routes import story_routes


def test_generate_story_returns_poll_url_on_sync_timeout(
    client, auth_headers, monkeypatch
):
    # A3: when synchronous generation overruns the timeout, the route returns a
    # server-generated recovery task id for polling. The in-flight generation
    # keeps running (now on the real Celery worker, dispatched via
    # apply_async — see MT-async-task-delivery) and persists its Story row
    # under that id; the route does NOT dispatch a SECOND task on top of it
    # (the old behaviour double-generated).
    delay_called = []
    apply_async_called = []

    class _FakeAsyncResult:
        def get(self, *args, **kwargs):
            # Force timeout to trigger the A3 recovery path
            from celery.exceptions import TimeoutError

            raise TimeoutError("Simulated timeout")

    class _FakeTask:
        def __init__(self):
            self.id = "task-123"

        def delay(self, **kwargs):
            delay_called.append(kwargs)
            return self

        def apply_async(self, kwargs=None, task_id=None):
            apply_async_called.append({"kwargs": kwargs, "task_id": task_id})
            return _FakeAsyncResult()

    monkeypatch.setattr(story_routes, "generate_story_task", _FakeTask())
    monkeypatch.setattr(story_routes, "_celery_runs_eagerly", lambda: False)

    response = client.post(
        "/generate-story",
        json={"character": "Luna", "age": 7, "theme": "Courage"},
        headers=auth_headers,
    )

    assert response.status_code == 202
    payload = response.get_json()
    assert payload["status"] == "processing"
    # task_id is a server-generated recovery id, and the poll URL points at it.
    assert payload["task_id"]
    assert payload["poll_url"].endswith(payload["task_id"])
    # The recovery attempt was dispatched via the real async mechanism
    # (apply_async), under the SAME task_id that was returned for polling.
    assert len(apply_async_called) == 1
    assert apply_async_called[0]["task_id"] == payload["task_id"]
    # A3: no SECOND task is dispatched on top of the recovery attempt.
    assert delay_called == []


def test_generate_story_falls_back_when_queue_fails(client, auth_headers, monkeypatch):
    class _FakeResult:
        def __init__(self, data):
            self._data = data

        def get(self, *args, **kwargs):
            return self._data

    class _FailingTask:
        def __init__(self):
            self.id = "task-fail"

        def delay(self, **kwargs):
            raise RuntimeError("queue unavailable")

        def apply_async(self, kwargs=None, task_id=None):
            return _FakeResult(
                {
                    "status": "complete",
                    "story": {
                        "title": "Fallback Adventure",
                        "story_text": "Once upon a time...",
                        "theme": kwargs.get("theme") if kwargs else None,
                        "wisdom_gem": "Be kind",
                    },
                }
            )

    monkeypatch.setattr(story_routes, "generate_story_task", _FailingTask())

    response = client.post(
        "/generate-story", json={"character": {"name": "Sam"}}, headers=auth_headers
    )

    assert response.status_code == 200
    payload = response.get_json()
    assert payload["status"] == "complete"
    assert payload["story"]["title"] == "Fallback Adventure"
    assert payload["story"]["story_text"].startswith("Once upon a time")
    assert payload["story"]["wisdom_gem"] == "Be kind"


@pytest.mark.parametrize(
    "state,info,expected",
    [
        ("PENDING", None, {"status": "pending"}),
        (
            "PROCESSING",
            {"status": "Working"},
            {"status": "processing", "message": "Working"},
        ),
        (
            "SUCCESS",
            {"story": "done"},
            {"status": "complete", "result": {"story": "done"}},
        ),
        ("FAILURE", RuntimeError("boom"), {"status": "failed", "error": "boom"}),
    ],
)
def test_task_status_maps_celery_states(
    client, auth_headers, monkeypatch, state, info, expected
):
    class _FakeAsyncResult:
        def __init__(self, state, info):
            self.state = state
            self.info = info
            self.result = info

    class _FakeCelery:
        def __init__(self, result):
            self._result = result

        def AsyncResult(self, task_id):  # noqa: N802
            return self._result

    result = _FakeAsyncResult(state, info)
    monkeypatch.setattr(story_routes, "celery", _FakeCelery(result))
    # Stub owner resolution so PENDING/PROCESSING states aren't rejected as unknown tasks
    monkeypatch.setattr(
        story_routes,
        "_resolve_task_owner",
        lambda task_id, task: "test_user_123",
    )

    response = client.get("/task-status/demo-task", headers=auth_headers)
    assert response.status_code == 200

    payload = response.get_json()
    for key, value in expected.items():
        assert payload[key] == value


# --- Cross-worker task ownership (async-task-delivery fix, 2026-07-07) ------
# /task-status is polled repeatedly and can land on any gunicorn worker
# process. Ownership used to be cached via Flask-Caching's in-process
# "simple" cache, so a poll answered by a DIFFERENT worker than the one that
# cached the owner saw a miss and the route returned 404 "Task not found" for
# a task that was genuinely in flight — consecutive polls of the SAME task_id
# would flip between 200 and 404 depending on which worker answered. These
# tests exercise the real (unmocked) `_resolve_task_owner`/`_cache_task_owner`
# through the route, backed by a fake Redis client standing in for the shared
# store every worker sees.


def _install_fake_celery_state(monkeypatch, state, info):
    class _FakeAsyncResult:
        def __init__(self):
            self.state = state
            self.info = info
            self.result = info

    class _FakeCelery:
        def AsyncResult(self, task_id):  # noqa: N802
            return _FakeAsyncResult()

    monkeypatch.setattr(story_routes, "celery", _FakeCelery())


def test_task_status_survives_lookup_from_a_different_worker(
    client, auth_headers, test_user, monkeypatch
):
    """Simulates the exact split-brain: the owner record is written via one
    Redis client instance (standing in for gunicorn worker A, which handled
    the original POST) and read back via a SEPARATE, freshly-constructed
    client instance (standing in for worker B, which answers the poll). Since
    both share the same backing keyspace (real Redis in production), the poll
    must still resolve ownership and return the in-flight status — NOT 404.
    """
    from backend.utils import task_owner

    shared_store: dict[str, bytes] = {}

    def _write_client():
        client_mock = MagicMock()
        client_mock.setex.side_effect = (
            lambda key, ttl, value: shared_store.__setitem__(key, value.encode())
        )
        return client_mock

    def _read_client():
        client_mock = MagicMock()
        client_mock.get.side_effect = lambda key: shared_store.get(key)
        return client_mock

    # "Worker A" caches the owner (as the /generate-story timeout/async-fallback
    # branches do via _cache_task_owner).
    monkeypatch.setattr(task_owner, "_get_redis", lambda: _write_client())
    task_owner.cache_task_owner("shared-task-id", test_user.id)

    # "Worker B" (a distinct Redis connection object) answers the poll. Celery
    # state metadata deliberately carries NO user_id, so the only way
    # ownership resolves is via the shared Redis record.
    monkeypatch.setattr(task_owner, "_get_redis", lambda: _read_client())
    _install_fake_celery_state(
        monkeypatch, "PROCESSING", {"status": "Generating story..."}
    )

    response = client.get("/task-status/shared-task-id", headers=auth_headers)

    assert response.status_code == 200
    assert response.get_json()["status"] == "processing"


def test_task_status_404_when_no_owner_metadata_exists_anywhere(
    client, auth_headers, monkeypatch
):
    """When Redis has no owner record AND the Celery result carries no
    user_id (e.g. the record was never written, or Redis was unreachable at
    write time), the route must refuse to disclose task state rather than
    guess — this is the P2#13 symmetric ownership guard, not a bug. It's
    covered here for contrast with the "genuinely in flight" case above.
    """
    from backend.utils import task_owner

    monkeypatch.setattr(task_owner, "_get_redis", lambda: None)
    _install_fake_celery_state(
        monkeypatch, "PROCESSING", {"status": "Generating story..."}
    )

    response = client.get("/task-status/nobody-owns-this", headers=auth_headers)

    assert response.status_code == 404
    assert response.get_json()["error"] == "Task not found"


def test_generate_story_requires_character_payload(client, auth_headers):
    response = client.post(
        "/generate-story", json={"theme": "Adventure"}, headers=auth_headers
    )
    assert response.status_code == 400
    assert "error" in response.get_json()


# --- Companion-aware sync timeout (MT-147) -----------------------------------
# Companion payloads add mandatory validation names and a larger prompt, which
# routinely forces an extra full-story regeneration and pushes wall time past
# the base sync budget. The route grants extra sync head-room per companion so
# these legitimately-slower requests finish synchronously instead of restarting
# from scratch on the async worker (which makes the client fall back to a
# canned scaffold story).


def test_companion_count_sums_pets_characters_and_legacy():
    assert story_routes._companion_count({}) == 0
    assert story_routes._companion_count({"companion_pets": [{"name": "Rex"}]}) == 1
    assert (
        story_routes._companion_count(
            {
                "companion_pets": [{"name": "Rex"}, {"name": "Spot"}],
                "companion_characters": [{"name": "Mia"}],
                "companion": "Buddy",
            }
        )
        == 4
    )


def test_sync_timeout_unchanged_with_no_companions():
    # Base below the 100s default ceiling passes through untouched.
    assert story_routes._sync_timeout_for({}, 75) == 75


def test_sync_timeout_extends_per_companion(monkeypatch):
    monkeypatch.delenv("SYNC_STORY_TIMEOUT_PER_COMPANION_SECONDS", raising=False)
    monkeypatch.delenv("SYNC_STORY_TIMEOUT_MAX_EXTRA_SECONDS", raising=False)
    monkeypatch.setenv("SYNC_STORY_TIMEOUT_CEILING_SECONDS", "600")
    # Two companions -> base 120 + 2*30 = 180 (ceiling lifted out of the way).
    kwargs = {
        "companion_pets": [{"name": "Rex"}],
        "companion_characters": [{"name": "Mia"}],
    }
    assert story_routes._sync_timeout_for(kwargs, 120) == 180


def test_sync_timeout_extension_is_capped(monkeypatch):
    monkeypatch.delenv("SYNC_STORY_TIMEOUT_PER_COMPANION_SECONDS", raising=False)
    monkeypatch.delenv("SYNC_STORY_TIMEOUT_MAX_EXTRA_SECONDS", raising=False)
    monkeypatch.setenv("SYNC_STORY_TIMEOUT_CEILING_SECONDS", "600")
    # Ten companions would add 300s uncapped; the cap holds it to +120 -> 240.
    kwargs = {"companion_pets": [{"name": f"P{i}"} for i in range(10)]}
    assert story_routes._sync_timeout_for(kwargs, 120) == 240


def test_sync_timeout_ceiling_keeps_wait_under_gunicorn_kill(monkeypatch):
    """base+extra must never exceed the ceiling — gunicorn (--timeout 120)
    would SIGKILL the web worker mid-wait and the client retry would launch a
    duplicate generation."""
    monkeypatch.delenv("SYNC_STORY_TIMEOUT_PER_COMPANION_SECONDS", raising=False)
    monkeypatch.delenv("SYNC_STORY_TIMEOUT_MAX_EXTRA_SECONDS", raising=False)
    monkeypatch.delenv("SYNC_STORY_TIMEOUT_CEILING_SECONDS", raising=False)
    kwargs = {"companion_pets": [{"name": f"P{i}"} for i in range(10)]}
    # 75 + 120 capped extra = 195 uncapped -> ceiling 100.
    assert story_routes._sync_timeout_for(kwargs, 75) == 100
    # An oversized base is capped too.
    assert story_routes._sync_timeout_for({}, 300) == 100
