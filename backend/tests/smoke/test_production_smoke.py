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

# The COPPA enforcement flags (ENFORCE_RESOLVED_AGE et al.) are deliberately
# OFF in prod pre-launch (owner decision 2026-07-15, launch blocker #449).
# While they are off, the age-gate probe below fails by design — and generates
# a real story on prod on every CI run. The expectation is config-driven:
# CI feeds this from the repo Actions variable SMOKE_EXPECT_COPPA_GATE
# (currently "off"). Flip that variable back to "on" at launch, when the
# flags are re-enabled on Railway — the default here stays "on" so a bare
# local run remains fail-loud.
COPPA_GATE_EXPECTED = (
    os.environ.get("SMOKE_EXPECT_COPPA_GATE", "on").strip().lower() != "off"
)


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
    assert (
        response.status_code == 200
    ), f"Anonymous auth failed: status={response.status_code} body={response.text[:500]!r}"
    payload = _assert_json_response(response)
    token = payload.get("token") or payload.get("access_token")
    assert token, f"Auth response missing token: {payload!r}"
    user_id = payload.get("user_id")
    assert user_id, f"Auth response missing user_id: {payload!r}"
    headers = {"Authorization": f"Bearer {token}"}

    # MT-369 / F-1: prod enforces ENFORCE_RESOLVED_AGE, so a session that
    # never declares an age is refused at gated endpoints with 403
    # AGE_REQUIRED (TestCoppaAgeGateSmoke pins that behaviour). Declare an
    # adult age up front so the authenticated happy-path flows clear the
    # gate — mirrors the client-side back-fill added in PR #442.
    age_response = session_client.patch(
        f"{BASE_URL}/api/user/{user_id}/age",
        json={"age": 30},
        headers=headers,
        timeout=REQUEST_TIMEOUT,
    )
    assert age_response.status_code == 200, (
        f"Declaring smoke-session age failed: status={age_response.status_code} "
        f"body={age_response.text[:500]!r}"
    )
    return headers


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
        assert (
            response.status_code == 201
        ), f"Character creation failed: status={response.status_code} body={response.text[:500]!r}"
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
        """Basic health check returns 200.

        M-12: the public /health probe is intentionally minimal — only
        status + version. Diagnostic detail (database/api-key/environment)
        is not exposed to unauthenticated callers.
        """
        response = session_client.get(f"{BASE_URL}/health", timeout=REQUEST_TIMEOUT)
        assert response.status_code == 200
        data = _assert_json_response(response)
        assert data["status"] == "ok"
        assert "version" in data
        # Diagnostic fields must NOT be exposed publicly.
        assert "database" not in data
        assert "has_api_key" not in data

    def test_detailed_health(
        self, session_client: requests.Session, auth_headers: dict[str, str]
    ):
        """Detailed health is admin-only (M-12).

        Unauthenticated callers get 401. With a (non-admin) anonymous token
        the endpoint returns 403. An admin token is needed for full detail;
        the smoke suite has no admin credentials, so it only asserts the
        endpoint is gated, not the body.
        """
        response = session_client.get(
            f"{BASE_URL}/health/detailed", timeout=REQUEST_TIMEOUT
        )
        assert response.status_code == 401

        response = session_client.get(
            f"{BASE_URL}/health/detailed",
            headers=auth_headers,
            timeout=REQUEST_TIMEOUT,
        )
        # Anonymous smoke token is not admin -> 403; an admin token -> 200/503.
        assert response.status_code in (200, 403, 503)


class TestAPIContractSmoke:
    def test_unauthenticated_story_rejected(self, session_client: requests.Session):
        """Story generation requires authentication"""
        response = session_client.post(
            f"{BASE_URL}/generate-story",
            json={},
            timeout=REQUEST_TIMEOUT,
        )
        assert response.status_code in [401, 422]

    def test_unauthenticated_characters_rejected(
        self, session_client: requests.Session
    ):
        """Character listing requires authentication"""
        response = session_client.get(
            f"{BASE_URL}/get-characters", timeout=REQUEST_TIMEOUT
        )
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


class TestCoppaAgeGateSmoke:
    @pytest.mark.skipif(
        not COPPA_GATE_EXPECTED,
        reason=(
            "COPPA enforcement flags are deliberately OFF in prod "
            "(owner decision 2026-07-15, launch blocker #449). Flip the "
            "SMOKE_EXPECT_COPPA_GATE repo Actions variable to 'on' at launch."
        ),
    )
    def test_no_age_session_blocked_with_age_required(
        self, session_client: requests.Session
    ):
        """F-1 launch gate (MT-310/MT-369): an anonymous session that never
        declares an age must be refused at gated endpoints with 403
        AGE_REQUIRED. This is the positive proof that ENFORCE_RESOLVED_AGE
        is live in production — if this test fails, the COPPA age gate is
        off or broken."""
        response = session_client.post(
            f"{BASE_URL}/auth/anonymous",
            json={"client_id": f"smoke_noage_{uuid.uuid4().hex[:12]}"},
            timeout=REQUEST_TIMEOUT,
        )
        assert (
            response.status_code == 200
        ), f"Anonymous auth failed: status={response.status_code} body={response.text[:500]!r}"
        payload = _assert_json_response(response)
        token = payload.get("token") or payload.get("access_token")
        assert token, f"Auth response missing token: {payload!r}"
        headers = {"Authorization": f"Bearer {token}"}

        gen_response = session_client.post(
            f"{BASE_URL}/generate-story",
            json={
                "character": "No Age Smoke",
                "age": 7,
                "theme": "Adventure",
                "story_length": "short",
                "include_illustrations": False,
            },
            headers=headers,
            timeout=REQUEST_TIMEOUT,
        )
        assert gen_response.status_code == 403, (
            f"Expected the no-age session to be blocked (403), got "
            f"status={gen_response.status_code} body={gen_response.text[:500]!r}"
        )
        assert _assert_json_response(gen_response).get("code") == "AGE_REQUIRED"


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

        assert response.status_code in (
            200,
            202,
        ), f"Story generation failed: status={response.status_code} body={response.text[:1000]!r}"
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
        story_text = (
            story.get("story_text") or data.get("story_text") or data.get("story")
        )
        assert isinstance(story_text, str) and len(story_text.strip()) > 20
        assert elapsed < 180
