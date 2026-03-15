"""
Production Smoke Tests
Run: python -m pytest backend/tests/smoke/test_production_smoke.py -v
Requires: SMOKE_TEST_API_KEY env var (or uses test auth)
"""

import os
import time
import uuid

import pytest
import requests


BASE_URL = os.environ.get(
    "SMOKE_TEST_URL",
    "https://story-weaver-app-production.up.railway.app",
).rstrip("/")
REQUEST_TIMEOUT = int(os.environ.get("SMOKE_TEST_TIMEOUT", "30"))


def _assert_json_response(response: requests.Response) -> dict:
    content_type = response.headers.get("Content-Type", "")
    assert "json" in content_type.lower(), (
        f"Expected JSON response, got Content-Type={content_type!r} "
        f"body={response.text[:500]!r}"
    )
    return response.json()


@pytest.fixture(scope="session")
def session_client() -> requests.Session:
    session = requests.Session()
    session.headers.update({"Accept": "application/json"})
    return session


@pytest.fixture(scope="session")
def auth_headers(session_client: requests.Session) -> dict[str, str]:
    configured_token = (
        os.environ.get("SMOKE_TEST_API_KEY")
        or os.environ.get("SMOKE_TEST_TOKEN")
        or os.environ.get("SMOKE_TEST_JWT")
    )
    if configured_token:
        return {"Authorization": f"Bearer {configured_token}"}

    client_id = os.environ.get("SMOKE_TEST_CLIENT_ID", f"smoke_{uuid.uuid4().hex[:12]}")
    response = session_client.post(
        f"{BASE_URL}/auth/anonymous",
        json={"client_id": client_id},
        timeout=REQUEST_TIMEOUT,
    )
    assert response.status_code == 200, (
        f"Anonymous auth failed: status={response.status_code} body={response.text[:500]!r}"
    )
    payload = _assert_json_response(response)
    token = payload.get("token") or payload.get("access_token")
    assert token, f"Auth response missing token: {payload!r}"
    assert payload.get("user_id"), f"Auth response missing user_id: {payload!r}"
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def character_factory(session_client: requests.Session, auth_headers: dict[str, str]):
    created_ids: list[str] = []

    def _create(**overrides) -> dict:
        payload = {
            "name": f"Smoke Kid {uuid.uuid4().hex[:6]}",
            "age": 7,
            "traits": ["curious", "brave"],
        }
        payload.update(overrides)
        response = session_client.post(
            f"{BASE_URL}/create-character",
            json=payload,
            headers=auth_headers,
            timeout=REQUEST_TIMEOUT,
        )
        assert response.status_code == 201, (
            f"Character creation failed: status={response.status_code} body={response.text[:500]!r}"
        )
        body = _assert_json_response(response)
        assert body["name"] == payload["name"]
        assert body["age"] == payload["age"]
        assert body.get("id"), f"Character response missing id: {body!r}"
        created_ids.append(body["id"])
        return body

    yield _create

    for character_id in reversed(created_ids):
        try:
            session_client.delete(
                f"{BASE_URL}/characters/{character_id}",
                headers=auth_headers,
                timeout=REQUEST_TIMEOUT,
            )
        except requests.RequestException:
            pass


class TestHealthSmoke:
    def test_health_endpoint(self, session_client: requests.Session):
        """Basic health check returns 200"""
        response = session_client.get(f"{BASE_URL}/health", timeout=REQUEST_TIMEOUT)
        assert response.status_code == 200
        data = _assert_json_response(response)
        assert data["status"] == "ok"
        assert data["database"] == "ok"
        assert data["has_api_key"] is True

    def test_detailed_health(self, session_client: requests.Session):
        """Detailed health shows all systems healthy"""
        response = session_client.get(f"{BASE_URL}/health/detailed", timeout=REQUEST_TIMEOUT)
        assert response.status_code == 200
        data = _assert_json_response(response)
        assert data["status"] == "healthy"
        assert data["checks"]["database"]["status"] == "healthy"
        assert data["checks"]["gemini_api"]["configured"] is True


class TestAPIContractSmoke:
    def test_unauthenticated_story_rejected(self, session_client: requests.Session):
        """Story generation requires authentication"""
        response = session_client.post(
            f"{BASE_URL}/generate-story",
            json={},
            timeout=REQUEST_TIMEOUT,
        )
        assert response.status_code in [401, 422]

    def test_unauthenticated_characters_rejected(self, session_client: requests.Session):
        """Character listing requires authentication"""
        response = session_client.get(f"{BASE_URL}/get-characters", timeout=REQUEST_TIMEOUT)
        assert response.status_code in [401, 422]

    def test_invalid_token_rejected(self, session_client: requests.Session):
        """Invalid JWT token is rejected"""
        headers = {"Authorization": "Bearer invalid-token-here"}
        response = session_client.get(
            f"{BASE_URL}/get-characters",
            headers=headers,
            timeout=REQUEST_TIMEOUT,
        )
        assert response.status_code in [401, 422]

    def test_cors_headers_present(self, session_client: requests.Session):
        """CORS preflight does not fail"""
        response = session_client.options(
            f"{BASE_URL}/health",
            headers={
                "Origin": "https://example.com",
                "Access-Control-Request-Method": "GET",
            },
            timeout=REQUEST_TIMEOUT,
        )
        assert response.status_code != 500

    def test_404_returns_json(self, session_client: requests.Session):
        """Non-existent routes return proper error, not HTML"""
        response = session_client.get(
            f"{BASE_URL}/this-route-does-not-exist",
            timeout=REQUEST_TIMEOUT,
        )
        assert response.status_code == 404
        _assert_json_response(response)


class TestAuthenticatedCriticalFlows:
    def test_anonymous_auth_or_env_token_works(
        self,
        session_client: requests.Session,
        auth_headers: dict[str, str],
    ):
        """The suite can obtain a working authenticated session"""
        response = session_client.get(
            f"{BASE_URL}/get-characters",
            headers=auth_headers,
            timeout=REQUEST_TIMEOUT,
        )
        assert response.status_code == 200, (
            f"Authenticated character listing failed: status={response.status_code} "
            f"body={response.text[:500]!r}"
        )
        assert isinstance(_assert_json_response(response), list)

    def test_character_crud_flow(
        self,
        session_client: requests.Session,
        auth_headers: dict[str, str],
        character_factory,
    ):
        """Create, fetch, update, list, and delete a character"""
        created = character_factory()
        character_id = created["id"]

        get_response = session_client.get(
            f"{BASE_URL}/characters/{character_id}",
            headers=auth_headers,
            timeout=REQUEST_TIMEOUT,
        )
        assert get_response.status_code == 200
        fetched = _assert_json_response(get_response)
        assert fetched["id"] == character_id

        updated_name = f"{created['name']} Updated"
        patch_response = session_client.patch(
            f"{BASE_URL}/characters/{character_id}",
            json={"name": updated_name, "traits": ["focused"]},
            headers=auth_headers,
            timeout=REQUEST_TIMEOUT,
        )
        assert patch_response.status_code == 200
        patched = _assert_json_response(patch_response)
        assert patched["name"] == updated_name
        assert patched.get("personality_traits") == ["focused"]

        list_response = session_client.get(
            f"{BASE_URL}/get-characters",
            headers=auth_headers,
            timeout=REQUEST_TIMEOUT,
        )
        assert list_response.status_code == 200
        characters = _assert_json_response(list_response)
        assert any(character.get("id") == character_id for character in characters)

        delete_response = session_client.delete(
            f"{BASE_URL}/characters/{character_id}",
            headers=auth_headers,
            timeout=REQUEST_TIMEOUT,
        )
        assert delete_response.status_code == 200
        deleted = _assert_json_response(delete_response)
        assert deleted == {"status": "deleted", "id": character_id}

        verify_response = session_client.get(
            f"{BASE_URL}/characters/{character_id}",
            headers=auth_headers,
            timeout=REQUEST_TIMEOUT,
        )
        assert verify_response.status_code == 404

    def test_story_generation_flow(
        self,
        session_client: requests.Session,
        auth_headers: dict[str, str],
    ):
        """Generate one authenticated story with a minimal payload"""
        payload = {
            "character": f"Smoke Hero {uuid.uuid4().hex[:6]}",
            "age": 7,
            "theme": "Adventure",
            "story_length": "short",
            "include_illustrations": False,
            "async_illustrations": False,
        }

        started_at = time.time()
        response = session_client.post(
            f"{BASE_URL}/generate-story",
            json=payload,
            headers=auth_headers,
            timeout=max(REQUEST_TIMEOUT, 120),
        )
        elapsed = time.time() - started_at

        assert response.status_code in (200, 202), (
            f"Story generation failed: status={response.status_code} body={response.text[:1000]!r}"
        )
        data = _assert_json_response(response)

        if response.status_code == 202:
            assert data.get("status") == "processing"
            assert data.get("task_id")
            assert "poll_url" in data
            return

        assert data.get("status") == "complete"
        story = data.get("story") or {}
        assert isinstance(story, dict), f"Unexpected story payload: {data!r}"
        assert story.get("title"), f"Missing story title: {data!r}"
        story_text = story.get("story_text") or data.get("story_text") or data.get("story")
        assert isinstance(story_text, str) and len(story_text.strip()) > 20
        assert elapsed < 180
