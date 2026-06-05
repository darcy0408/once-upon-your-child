"""PERF-04 hardening: unit tests for the cooperative cancellation gates in
``generate_story_task`` and the ``task_cancellation`` Redis helpers.

Covers:
  * The first cancel gate (before any work) returns ``{"status": "cancelled"}``
    and the cancel flag is cleared (``clear_cancellation`` invoked).
  * A later cancel gate (before each generation attempt) is exercised too, so
    cancellation works after prompt-build has started.
  * ``is_cancelled`` fails OPEN (returns False) when the Redis client raises —
    a Redis hiccup must never abort an in-progress generation.
  * ``clear_cancellation`` deletes the flag and swallows Redis errors.

These tests never touch the LLM layer: the cancel gates short-circuit before
generation, and the helper tests mock the Redis client directly.
"""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest

from backend.tasks.story_tasks import generate_story_task


# Disable the autouse Gemini mock from the parent conftest — the cancel gates
# return before any generation, so the LLM layer is never reached.
@pytest.fixture(autouse=True)
def _no_gemini():
    yield


# ---------------------------------------------------------------------------
# Gate (a): cancel flag set -> task returns {"status": "cancelled"}
# ---------------------------------------------------------------------------
class TestGenerateStoryTaskCancelGates:
    def test_first_gate_returns_cancelled_and_clears_flag(self, app, mocker):
        """When the cancel flag is set before work begins, the task bails on
        the FIRST gate, returns status=cancelled, and clears the flag."""
        mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)
        # Flag is set for every check.
        mocker.patch("backend.utils.task_cancellation.is_cancelled", return_value=True)
        clear_mock = mocker.patch("backend.utils.task_cancellation.clear_cancellation")
        # If generation were ever reached, this would explode — proves the
        # first gate short-circuits before any model call.
        gen_mock = mocker.patch(
            "backend.tasks.story_tasks._generate_story_text_with_metadata",
            side_effect=AssertionError("generation must NOT run when cancelled"),
        )

        result = generate_story_task.apply(
            kwargs={
                "character": "Avery",
                "theme": "Adventure",
                "user_id": "test-user",
                "age": 7,
            }
        ).get()

        assert result["status"] == "cancelled"
        assert result["user_id"] == "test-user"
        gen_mock.assert_not_called()
        # Flag cleared on the cancelled path (best-effort cleanup).
        clear_mock.assert_called()

    def test_anonymous_first_gate_reports_anonymous_user(self, app, mocker):
        """The first gate runs before user_id is normalized; a missing user_id
        falls back to the 'anonymous' sentinel in the cancelled payload."""
        mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)
        mocker.patch("backend.utils.task_cancellation.is_cancelled", return_value=True)
        mocker.patch("backend.utils.task_cancellation.clear_cancellation")

        result = generate_story_task.apply(
            kwargs={"character": "Avery", "theme": "Adventure", "age": 7}
        ).get()

        assert result["status"] == "cancelled"
        assert result["user_id"] == "anonymous"

    def test_second_gate_cancels_after_prompt_build(self, app, mocker):
        """If the flag flips AFTER the first gate (e.g. during prompt build),
        the pre-generation gate inside the validation loop still aborts before
        any model call. Exercised by letting the first check pass and the
        second return True."""
        mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)
        # M-7: keep the hero name stable so prompt build doesn't depend on the
        # pseudonymizer's runtime token (irrelevant to this gate).
        mocker.patch(
            "backend.tasks.story_tasks.pseudonymize_hero_name",
            side_effect=lambda real_name, *a, **k: real_name or "Hero",
        )
        # First is_cancelled() -> False (pass the pre-work gate), every
        # subsequent call -> True (trip the per-attempt gate).
        mocker.patch(
            "backend.utils.task_cancellation.is_cancelled",
            side_effect=[False, True, True, True, True],
        )
        clear_mock = mocker.patch("backend.utils.task_cancellation.clear_cancellation")
        gen_mock = mocker.patch(
            "backend.tasks.story_tasks._generate_story_text_with_metadata",
            side_effect=AssertionError("generation must NOT run when cancelled"),
        )

        result = generate_story_task.apply(
            kwargs={
                "character": "Avery",
                "theme": "Adventure",
                "user_id": "test-user",
                "age": 7,
            }
        ).get()

        assert result["status"] == "cancelled"
        assert result["user_id"] == "test-user"
        gen_mock.assert_not_called()
        clear_mock.assert_called()


# ---------------------------------------------------------------------------
# Helper: is_cancelled fail-open + clear_cancellation behavior
# ---------------------------------------------------------------------------
class TestTaskCancellationHelpers:
    def test_is_cancelled_fails_open_when_redis_raises(self, mocker):
        """A Redis error inside is_cancelled must return False (fail open) so a
        broker hiccup never aborts an in-progress generation."""
        from backend.utils import task_cancellation

        broken = MagicMock()
        broken.get.side_effect = RuntimeError("redis down")
        mocker.patch.object(task_cancellation, "_get_redis", return_value=broken)

        assert task_cancellation.is_cancelled("task-abc") is False

    def test_is_cancelled_false_when_no_redis(self, mocker):
        from backend.utils import task_cancellation

        mocker.patch.object(task_cancellation, "_get_redis", return_value=None)
        assert task_cancellation.is_cancelled("task-abc") is False

    def test_is_cancelled_true_when_flag_present(self, mocker):
        from backend.utils import task_cancellation

        client = MagicMock()
        client.get.return_value = b"1"
        mocker.patch.object(task_cancellation, "_get_redis", return_value=client)

        assert task_cancellation.is_cancelled("task-abc") is True
        client.get.assert_called_once_with("cancel:task:task-abc")

    def test_is_cancelled_none_task_id_returns_false(self):
        from backend.utils import task_cancellation

        assert task_cancellation.is_cancelled(None) is False

    def test_clear_cancellation_deletes_flag(self, mocker):
        from backend.utils import task_cancellation

        client = MagicMock()
        mocker.patch.object(task_cancellation, "_get_redis", return_value=client)

        task_cancellation.clear_cancellation("task-abc")
        client.delete.assert_called_once_with("cancel:task:task-abc")

    def test_clear_cancellation_swallows_redis_error(self, mocker):
        """clear_cancellation is best-effort — a Redis error must not raise."""
        from backend.utils import task_cancellation

        client = MagicMock()
        client.delete.side_effect = RuntimeError("redis down")
        mocker.patch.object(task_cancellation, "_get_redis", return_value=client)

        # Must not raise.
        task_cancellation.clear_cancellation("task-abc")

    def test_clear_cancellation_none_task_id_is_noop(self, mocker):
        from backend.utils import task_cancellation

        get_redis = mocker.patch.object(task_cancellation, "_get_redis")
        task_cancellation.clear_cancellation(None)
        get_redis.assert_not_called()
