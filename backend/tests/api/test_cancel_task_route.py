"""PERF-04: route tests for ``POST /cancel-task/<task_id>``.

The route signals an in-flight generation to abandon further work by setting a
best-effort Redis cancel flag. Contract (see story_routes.cancel_task):
  * Requires auth (401 without a token).
  * 403 on ownership mismatch (IDOR — a user cancelling another user's task).
  * 202 ``status='accepted'`` for an unknown/unowned task id (anti-probing:
    UUIDs make cross-task interference impossible and a 404 would leak ids).
  * 202 ``status='accepted'`` on success, AND the flag is written to Redis.
  * 503 ``status='redis_unavailable'`` when Redis is unreachable.
"""

from __future__ import annotations

import pytest

from backend.routes import story_routes


class _FakeAsyncResult:
    def __init__(self, user_id=None):
        self.info = {"user_id": user_id} if user_id else None
        self.result = self.info


class _FakeCelery:
    def __init__(self, result):
        self._result = result

    def AsyncResult(self, task_id):  # noqa: N802
        return self._result


@pytest.fixture
def patch_celery(monkeypatch):
    """Install a fake celery whose AsyncResult carries a configurable owner."""

    def _install(owner_user_id=None):
        monkeypatch.setattr(
            story_routes, "celery", _FakeCelery(_FakeAsyncResult(owner_user_id))
        )

    return _install


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------
def test_cancel_task_requires_auth(client):
    """No token -> 401 (require_auth)."""
    resp = client.post("/cancel-task/some-task-id")
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# Success: flag written, 202 accepted
# ---------------------------------------------------------------------------
def test_cancel_task_success_sets_flag_returns_202(
    client, auth_headers, test_user, monkeypatch, mocker
):
    # Owner matches the authenticated user (test_user_123).
    monkeypatch.setattr(
        story_routes,
        "_resolve_task_owner",
        lambda cache, task_id, task: test_user.id,
    )
    req_cancel = mocker.patch(
        "backend.utils.task_cancellation.request_cancellation", return_value=True
    )

    resp = client.post("/cancel-task/task-123", headers=auth_headers)

    assert resp.status_code == 202
    assert resp.get_json()["status"] == "accepted"
    # The cancel flag was actually requested for this task id.
    req_cancel.assert_called_once_with("task-123")


# ---------------------------------------------------------------------------
# IDOR: cancelling another user's task -> 403
# ---------------------------------------------------------------------------
def test_cancel_task_idor_returns_403(
    client, auth_headers, test_user, monkeypatch, mocker
):
    # Task is owned by a DIFFERENT user.
    monkeypatch.setattr(
        story_routes,
        "_resolve_task_owner",
        lambda cache, task_id, task: "someone-else-999",
    )
    req_cancel = mocker.patch(
        "backend.utils.task_cancellation.request_cancellation", return_value=True
    )

    resp = client.post("/cancel-task/task-of-another", headers=auth_headers)

    assert resp.status_code == 403
    assert resp.get_json()["error"] == "Access denied"
    # No cancel flag must be written for a task you don't own.
    req_cancel.assert_not_called()


# ---------------------------------------------------------------------------
# Unknown task id: silent 202 (anti-probing), no flag written
# ---------------------------------------------------------------------------
def test_cancel_task_unknown_id_accepts_silently(
    client, auth_headers, test_user, monkeypatch, mocker
):
    # Owner cannot be resolved (unknown task / expired result).
    monkeypatch.setattr(
        story_routes,
        "_resolve_task_owner",
        lambda cache, task_id, task: None,
    )
    req_cancel = mocker.patch(
        "backend.utils.task_cancellation.request_cancellation", return_value=True
    )

    resp = client.post("/cancel-task/unknown-task", headers=auth_headers)

    assert resp.status_code == 202
    assert resp.get_json()["status"] == "accepted"
    # Anti-probing: we don't even attempt to set the flag for an unknown id.
    req_cancel.assert_not_called()


# ---------------------------------------------------------------------------
# Redis down: owner known but request_cancellation fails -> 503
# ---------------------------------------------------------------------------
def test_cancel_task_redis_unavailable_returns_503(
    client, auth_headers, test_user, monkeypatch, mocker
):
    monkeypatch.setattr(
        story_routes,
        "_resolve_task_owner",
        lambda cache, task_id, task: test_user.id,
    )
    # Redis unreachable -> request_cancellation returns False.
    mocker.patch(
        "backend.utils.task_cancellation.request_cancellation", return_value=False
    )

    resp = client.post("/cancel-task/task-123", headers=auth_headers)

    assert resp.status_code == 503
    assert resp.get_json()["status"] == "redis_unavailable"
