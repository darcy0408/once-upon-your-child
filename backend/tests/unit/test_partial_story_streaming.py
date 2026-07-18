"""PERF-01 unit tests for the partial-story streaming plumbing.

Covers the pieces that turn a provider's raw streamed output into the
client-renderable `partial_story:<task_id>` Redis key:

* ``_partial_prose_view`` — extracting a readable prose view (title + page
  texts) from the accumulating, usually-incomplete JSON story payload.
* ``_emit_partial_story`` — writing the prose view (not raw JSON) to Redis,
  and skipping the write while no readable text has arrived yet.
* Redis client reuse — both the Celery-side emitter (story_tasks) and the
  web-side reader (story_routes._read_partial_story) now cache one client
  per process instead of dialing per chunk / per poll.
* ``OpenRouterStoryGenerator.generate_story(on_chunk=...)`` — SSE streaming
  with accumulation, finish-reason policy, and the graceful fall-back to a
  plain JSON body when the server (or a test double) doesn't stream.
"""

from __future__ import annotations

import sys
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from backend.services import openrouter_story_generator as ors
from backend.services.openrouter_story_generator import OpenRouterStoryGenerator
from backend.tasks import story_tasks

_FULL_STORY_JSON = (
    '{"title": "The Brave Robin", "pages": ['
    '{"text": "Once upon a time, Aria met a robin."}, '
    '{"text": "They flew over the moonlit hills together."}]}'
)

_FULL_STORY_PROSE = (
    "The Brave Robin\n\n"
    "Once upon a time, Aria met a robin.\n\n"
    "They flew over the moonlit hills together."
)


# ---------------------------------------------------------------------------
# _partial_prose_view
# ---------------------------------------------------------------------------
class TestPartialProseView:
    def test_complete_payload_yields_title_and_pages(self):
        assert story_tasks._partial_prose_view(_FULL_STORY_JSON) == _FULL_STORY_PROSE

    def test_growing_fragment_yields_partial_prose(self):
        fragment = '{"title": "The Brave Robin", "pages": [{"text": "Once upon a ti'
        assert (
            story_tasks._partial_prose_view(fragment)
            == "The Brave Robin\n\nOnce upon a ti"
        )

    def test_partial_title_only(self):
        assert story_tasks._partial_prose_view('{"title": "The Bra') == "The Bra"

    def test_too_short_fragment_yields_empty(self):
        assert story_tasks._partial_prose_view('{"ti') == ""
        assert story_tasks._partial_prose_view("") == ""

    def test_escapes_are_decoded(self):
        raw = '{"title": "T", "pages": [{"text": "She said, \\"hello!\\"'
        assert story_tasks._partial_prose_view(raw) == 'T\n\nShe said, "hello!"'

    def test_dangling_backslash_from_split_escape_is_dropped(self):
        raw = '{"title": "T", "pages": [{"text": "She said, \\'
        assert story_tasks._partial_prose_view(raw) == "T\n\nShe said,"

    def test_markdown_fenced_payload_is_unwrapped(self):
        raw = "```json\n" + _FULL_STORY_JSON
        assert story_tasks._partial_prose_view(raw) == _FULL_STORY_PROSE

    def test_plain_prose_passes_through(self):
        assert (
            story_tasks._partial_prose_view("Once upon a time, plain prose.")
            == "Once upon a time, plain prose."
        )


# ---------------------------------------------------------------------------
# _emit_partial_story — prose written, empty fragments skipped
# ---------------------------------------------------------------------------
class TestEmitPartialStory:
    def test_emits_prose_view_not_raw_json(self, monkeypatch):
        fake_client = MagicMock()
        monkeypatch.setattr(
            story_tasks, "_get_partial_story_redis", lambda: fake_client
        )

        story_tasks._emit_partial_story("task-1", _FULL_STORY_JSON)

        fake_client.setex.assert_called_once_with(
            "partial_story:task-1",
            story_tasks._PARTIAL_STORY_TTL_SECONDS,
            _FULL_STORY_PROSE,
        )

    def test_skips_write_while_no_readable_text_yet(self, monkeypatch):
        fake_client = MagicMock()
        monkeypatch.setattr(
            story_tasks, "_get_partial_story_redis", lambda: fake_client
        )

        story_tasks._emit_partial_story("task-1", '{"ti')

        fake_client.setex.assert_not_called()

    def test_no_task_id_is_a_noop(self, monkeypatch):
        fake_client = MagicMock()
        monkeypatch.setattr(
            story_tasks, "_get_partial_story_redis", lambda: fake_client
        )

        story_tasks._emit_partial_story(None, _FULL_STORY_JSON)

        fake_client.setex.assert_not_called()


# ---------------------------------------------------------------------------
# Redis client reuse (emitter + reader)
# ---------------------------------------------------------------------------
def _fake_redis_module(client):
    module = SimpleNamespace()
    module.from_url = MagicMock(return_value=client)
    return module


class TestPartialStoryRedisReuse:
    @pytest.fixture(autouse=True)
    def _reset_caches(self):
        story_tasks._partial_story_redis_client = None
        yield
        story_tasks._partial_story_redis_client = None

    def test_emitter_reuses_one_client(self, monkeypatch):
        fake_client = MagicMock()
        fake_module = _fake_redis_module(fake_client)
        monkeypatch.setitem(sys.modules, "redis", fake_module)
        monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")

        first = story_tasks._get_partial_story_redis()
        second = story_tasks._get_partial_story_redis()

        assert first is fake_client
        assert second is fake_client
        assert fake_module.from_url.call_count == 1
        assert fake_client.ping.call_count == 1  # health-checked once, not per call

    def test_write_error_resets_cache(self, monkeypatch):
        fake_client = MagicMock()
        fake_client.setex.side_effect = ConnectionError("gone away")
        fake_module = _fake_redis_module(fake_client)
        monkeypatch.setitem(sys.modules, "redis", fake_module)
        monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")

        story_tasks._get_partial_story_redis()
        story_tasks._emit_partial_story("task-1", _FULL_STORY_JSON)  # swallowed

        assert story_tasks._partial_story_redis_client is None  # re-dials next time

    def test_no_url_returns_none(self, monkeypatch):
        monkeypatch.delenv("REDIS_URL", raising=False)
        monkeypatch.delenv("REDIS_PRIVATE_URL", raising=False)
        assert story_tasks._get_partial_story_redis() is None


class TestReadPartialStoryReuse:
    @pytest.fixture(autouse=True)
    def _reset_caches(self):
        from backend.routes import story_routes

        story_routes._partial_story_redis_client = None
        yield
        story_routes._partial_story_redis_client = None

    def test_reader_reuses_one_client(self, monkeypatch):
        from backend.routes import story_routes

        fake_client = MagicMock()
        fake_client.get.return_value = b"Once upon a time"
        fake_module = _fake_redis_module(fake_client)
        monkeypatch.setitem(sys.modules, "redis", fake_module)
        monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")

        assert story_routes._read_partial_story("t1") == "Once upon a time"
        assert story_routes._read_partial_story("t1") == "Once upon a time"
        assert fake_module.from_url.call_count == 1

    def test_read_error_resets_cache_and_returns_none(self, monkeypatch):
        from backend.routes import story_routes

        fake_client = MagicMock()
        fake_client.get.side_effect = ConnectionError("gone away")
        fake_module = _fake_redis_module(fake_client)
        monkeypatch.setitem(sys.modules, "redis", fake_module)
        monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")

        assert story_routes._read_partial_story("t1") is None
        assert story_routes._partial_story_redis_client is None


# ---------------------------------------------------------------------------
# OpenRouter SSE streaming
# ---------------------------------------------------------------------------
class _FakeSSEResponse:
    status_code = 200

    def __init__(self, lines):
        self._lines = lines

    def raise_for_status(self):
        return None

    def iter_lines(self, decode_unicode=False):
        return iter(self._lines)

    def json(self):
        raise ValueError("SSE body is not JSON")


def _sse_line(content=None, finish_reason=None) -> str:
    import json as _json

    delta = {} if content is None else {"content": content}
    event = {"choices": [{"delta": delta, "finish_reason": finish_reason}]}
    return "data: " + _json.dumps(event)


class TestOpenRouterStreaming:
    @pytest.fixture(autouse=True)
    def _env(self, monkeypatch):
        monkeypatch.setenv("OPENROUTER_API_KEY", "test-or-key")
        yield

    def _patch_post(self, monkeypatch, response):
        fake_post = MagicMock(return_value=response)
        monkeypatch.setattr(ors.requests, "post", fake_post)
        return fake_post

    def test_streams_and_accumulates(self, monkeypatch):
        response = _FakeSSEResponse(
            [
                ": OPENROUTER PROCESSING",  # SSE comment / keep-alive
                _sse_line("Once "),
                "",
                _sse_line("upon a time."),
                _sse_line(finish_reason="stop"),
                "data: [DONE]",
            ]
        )
        fake_post = self._patch_post(monkeypatch, response)
        snapshots: list[str] = []

        out = OpenRouterStoryGenerator(user_tier="free").generate_story(
            "hi", on_chunk=snapshots.append
        )

        assert out == "Once upon a time."
        assert snapshots == ["Once ", "Once upon a time."]
        body = fake_post.call_args.kwargs["json"]
        assert body["stream"] is True
        assert fake_post.call_args.kwargs["stream"] is True

    def test_content_filter_returns_safety_fallback(self, monkeypatch):
        response = _FakeSSEResponse(
            [
                _sse_line("Some start"),
                _sse_line(finish_reason="content_filter"),
                "data: [DONE]",
            ]
        )
        self._patch_post(monkeypatch, response)

        out = OpenRouterStoryGenerator(user_tier="free").generate_story(
            "hi", on_chunk=lambda text: None
        )

        assert "different adventure" in out  # _SAFETY_FALLBACK marker

    def test_non_streaming_body_falls_back_to_json_parse(self, monkeypatch):
        # A test double / proxy that ignores the stream flag and returns a
        # plain chat completion — generate_story must parse it the old way.
        response = MagicMock()
        response.status_code = 200
        response.raise_for_status.return_value = None
        response.json.return_value = {
            "choices": [
                {
                    "finish_reason": "stop",
                    "message": {"content": "A full non-streamed story."},
                }
            ]
        }
        self._patch_post(monkeypatch, response)

        out = OpenRouterStoryGenerator(user_tier="free").generate_story(
            "hi", on_chunk=lambda text: None
        )

        assert out == "A full non-streamed story."

    def test_no_on_chunk_keeps_blocking_request(self, monkeypatch):
        response = MagicMock()
        response.status_code = 200
        response.raise_for_status.return_value = None
        response.json.return_value = {
            "choices": [
                {"finish_reason": "stop", "message": {"content": "Blocking story."}}
            ]
        }
        fake_post = self._patch_post(monkeypatch, response)

        out = OpenRouterStoryGenerator(user_tier="free").generate_story("hi")

        assert out == "Blocking story."
        body = fake_post.call_args.kwargs["json"]
        assert "stream" not in body
        assert fake_post.call_args.kwargs["stream"] is False
