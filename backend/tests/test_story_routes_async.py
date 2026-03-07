import pytest
from backend.routes import story_routes

def test_generate_story_enqueues_task_and_returns_poll_url(client, auth_headers, monkeypatch):
    # Use a character name (no DB lookup) so the test is not coupled to fixture
    # session scoping; the async-polling logic is what we're testing here.
    captured_kwargs = {}

    class _FakeTask:
        def __init__(self):
            self.id = "task-123"

        def delay(self, **kwargs):
            captured_kwargs.update(kwargs)
            return self

        def apply(self, kwargs=None):
            # Force timeout to trigger async path
            from celery.exceptions import TimeoutError
            raise TimeoutError("Simulated timeout")

    monkeypatch.setattr(story_routes, "generate_story_task", _FakeTask())
    monkeypatch.setattr(story_routes, "_celery_runs_eagerly", lambda: False)

    response = client.post(
        "/generate-story",
        json={"character": "Luna", "age": 7, "theme": "Courage"},
        headers=auth_headers
    )

    assert response.status_code == 202
    payload = response.get_json()
    assert payload["task_id"] == "task-123"
    assert payload["status"] == "processing"
    assert payload["poll_url"].endswith("task-123")
    assert captured_kwargs["character"] == "Luna"
    assert captured_kwargs["theme"] == "Courage"

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

        def apply(self, kwargs=None):
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

    response = client.post("/generate-story", json={"character": {"name": "Sam"}}, headers=auth_headers)

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
        ("PROCESSING", {"status": "Working"}, {"status": "processing", "message": "Working"}),
        ("SUCCESS", {"story": "done"}, {"status": "complete", "result": {"story": "done"}}),
        ("FAILURE", RuntimeError("boom"), {"status": "failed", "error": "boom"}),
    ],
)
def test_task_status_maps_celery_states(client, auth_headers, monkeypatch, state, info, expected):
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

    response = client.get("/task-status/demo-task", headers=auth_headers)
    assert response.status_code == 200

    payload = response.get_json()
    for key, value in expected.items():
        assert payload[key] == value

def test_generate_story_requires_character_payload(client, auth_headers):
    response = client.post("/generate-story", json={"theme": "Adventure"}, headers=auth_headers)
    assert response.status_code == 400
    assert "error" in response.get_json()
