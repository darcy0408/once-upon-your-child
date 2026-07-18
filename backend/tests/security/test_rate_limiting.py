import json
import os
import time
from unittest.mock import MagicMock, patch

import flask
import pytest

from backend.app import create_app
from backend.config import TestingConfig
from backend.database import db
from backend.models.user import User


@pytest.fixture
def ratelimit_app():
    """
    App fixture with rate limiting explicitly enabled.
    """
    import backend.tasks.story_tasks as story_tasks
    from backend.config import config_by_name

    class RateLimitTestingConfig(TestingConfig):
        RATELIMIT_ENABLED = True
        RATELIMIT_STORAGE_URI = "memory://"
        RATELIMIT_HEADERS_ENABLED = True
        CELERY_TASK_ALWAYS_EAGER = True

    new_configs = {k: RateLimitTestingConfig for k in config_by_name.keys()}

    with patch("backend.app.config_by_name", new_configs):
        app = create_app("testing")
        app.limiter.enabled = True
        story_tasks._flask_app = app

        from backend.middleware.auth import optional_auth

        @app.route("/verify-limiter")
        @optional_auth
        @app.limiter.limit("2 per minute")
        def verify_limiter():
            # Standard helper to get ID for debugging
            from backend.utils.app_helpers import get_user_identifier

            return (
                flask.jsonify({"status": "ok", "identifier": get_user_identifier()}),
                200,
            )

        with app.app_context():
            db.create_all()
            if not db.session.get(User, "anonymous"):
                anon = User(
                    id="anonymous",
                    username="anonymous",
                    email="anon@test.com",
                    password_hash="hash",
                )
                db.session.add(anon)
                db.session.commit()

            yield app
            db.session.remove()
            db.drop_all()
            story_tasks._flask_app = None


@pytest.fixture
def ratelimit_client(ratelimit_app):
    return ratelimit_app.test_client()


@pytest.fixture
def free_user_id(ratelimit_app):
    with ratelimit_app.app_context():
        user = User(
            id="free_user_limit_test",
            username="freeuser_limit",
            email="free_limit@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
        )
        db.session.add(user)
        db.session.commit()
        return "free_user_limit_test"


from datetime import datetime, timedelta, timezone

import jwt


def _get_token(user_id, tier="free"):
    payload = {
        "user_id": user_id,
        "sub": user_id,
        "subscription_tier": tier,
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    return jwt.encode(payload, "dev-secret-key", algorithm="HS256")


def test_limiter_identifier_and_sharing(ratelimit_client, free_user_id):
    """
    Test that the limiter correctly uses user ID from token and shares state across routes.
    """
    token = _get_token(free_user_id)
    headers = {"Authorization": f"Bearer {token}"}

    # Request 1
    resp = ratelimit_client.get("/verify-limiter", headers=headers)
    assert resp.status_code == 200
    assert json.loads(resp.data)["identifier"] == f"user:{free_user_id}"

    # Request 2
    resp = ratelimit_client.get("/verify-limiter", headers=headers)
    assert resp.status_code == 200

    # Request 3 - Should be 429
    resp = ratelimit_client.get("/verify-limiter", headers=headers)
    assert resp.status_code == 429


def test_rate_limit_isolated_per_user_identifier(ratelimit_client, ratelimit_app):
    """
    Test that limits are scoped per user identifier, not globally shared.
    """
    with ratelimit_app.app_context():
        user_a = User(
            id="rate_user_a",
            username="rate_user_a",
            email="a@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
        )
        user_b = User(
            id="rate_user_b",
            username="rate_user_b",
            email="b@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
        )
        db.session.add_all([user_a, user_b])
        db.session.commit()

    token_a = _get_token("rate_user_a")
    token_b = _get_token("rate_user_b")
    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # User A consumes limit.
    assert ratelimit_client.get("/verify-limiter", headers=headers_a).status_code == 200
    assert ratelimit_client.get("/verify-limiter", headers=headers_a).status_code == 200
    assert ratelimit_client.get("/verify-limiter", headers=headers_a).status_code == 429

    # User B should still have full limit independently.
    assert ratelimit_client.get("/verify-limiter", headers=headers_b).status_code == 200
    assert ratelimit_client.get("/verify-limiter", headers=headers_b).status_code == 200
    assert ratelimit_client.get("/verify-limiter", headers=headers_b).status_code == 429


def test_free_tier_real_limits(ratelimit_client, free_user_id):
    """
    Test that free tier users are rate limited using real app limits (3/min).
    """
    token = _get_token(free_user_id, "free")
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    payload = {"character": "Test Hero", "age": 5}

    # App default for free is 3/minute.
    for i in range(3):
        # Story generation can fail in CI if external model credentials are absent.
        # Rate-limit behavior should still allow the first 3 requests through.
        status = ratelimit_client.post(
            "/generate-story", data=json.dumps(payload), headers=headers
        ).status_code
        assert (
            status != 429
        ), f"Request {i+1} unexpectedly rate-limited with status {status}"

    # 4th request should be 429
    response = ratelimit_client.post(
        "/generate-story", data=json.dumps(payload), headers=headers
    )
    assert response.status_code == 429


def test_task_status_polling_is_not_rate_limited_like_generation(
    ratelimit_client, free_user_id
):
    """/task-status polling must not consume the free-tier generation quota
    (async-task-delivery fix, 2026-07-07).

    Before the fix, GET /task-status had no route-level @limiter.limit(...)
    of its own, so it inherited the app-wide default_limits (200/day, 50/hour,
    keyed per authenticated user — see backend/app.py Limiter(...)). A client
    polling every few seconds while a 202 response is in flight burns through
    that budget in well under an hour and starts getting 429 "Free tier limit
    reached. Upgrade to Premium" on STATUS CHECKS, unrelated to how many
    stories the user has actually generated. Firing well more than the
    default 50/hour at /task-status must all come back non-429; the route's
    own generous per-IP limit (override_defaults=True, the flask-limiter
    default) replaces the tight default budget instead of adding to it.
    """
    token = _get_token(free_user_id, "free")
    headers = {"Authorization": f"Bearer {token}"}

    statuses = [
        ratelimit_client.get("/task-status/some-task-id", headers=headers).status_code
        for _ in range(60)
    ]

    assert all(status != 429 for status in statuses), statuses


def test_rate_limit_headers(ratelimit_client):
    """
    Test that rate limit headers are present.
    """
    response = ratelimit_client.get("/verify-limiter")
    assert response.status_code == 200
    assert "X-RateLimit-Limit" in response.headers
    assert "X-RateLimit-Remaining" in response.headers


def test_premium_tier_limits(ratelimit_client, ratelimit_app):
    """
    Test that premium tier users have higher limits (10/min).
    """
    with ratelimit_app.app_context():
        user = User(
            id="premium_user_test",
            username="premiumuser",
            email="premium@example.com",
            password_hash="hash",
            subscription_tier="premium",
        )
        db.session.add(user)
        db.session.commit()

    token = _get_token("premium_user_test", "premium")
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    payload = {"character": "Test Hero", "age": 5}

    # Should allow 10 requests
    for i in range(10):
        resp = ratelimit_client.post(
            "/generate-story", data=json.dumps(payload), headers=headers
        )
        assert (
            resp.status_code != 429
        ), f"Request {i+1} unexpectedly rate-limited with status {resp.status_code}"

    # 11th request should be 429
    assert (
        ratelimit_client.post(
            "/generate-story", data=json.dumps(payload), headers=headers
        ).status_code
        == 429
    )


def test_family_tier_limits(ratelimit_client, ratelimit_app):
    """
    Test that family tier users have even higher limits (15/min).
    """
    with ratelimit_app.app_context():
        user = User(
            id="family_user_test",
            username="familyuser",
            email="family@example.com",
            password_hash="hash",
            subscription_tier="family",
        )
        db.session.add(user)
        db.session.commit()

    token = _get_token("family_user_test", "family")
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    payload = {"character": "Test Hero", "age": 5}

    # Should allow 15 requests
    for i in range(15):
        resp = ratelimit_client.post(
            "/generate-story", data=json.dumps(payload), headers=headers
        )
        assert (
            resp.status_code != 429
        ), f"Request {i+1} unexpectedly rate-limited with status {resp.status_code}"

    # 16th request should be 429
    assert (
        ratelimit_client.post(
            "/generate-story", data=json.dumps(payload), headers=headers
        ).status_code
        == 429
    )


def test_rate_limit_reset_behavior(ratelimit_client, ratelimit_app):
    """
    Test that rate limits eventually reset.
    """

    # Use a very low limit for quick testing
    @ratelimit_app.route("/quick-reset")
    @ratelimit_app.limiter.limit("1 per 2 seconds")
    def quick_reset():
        return flask.jsonify({"status": "ok"}), 200

    token = _get_token("reset_user_test")
    headers = {"Authorization": f"Bearer {token}"}

    # 1st request ok
    assert ratelimit_client.get("/quick-reset", headers=headers).status_code == 200
    # 2nd request 429
    assert ratelimit_client.get("/quick-reset", headers=headers).status_code == 429

    # Wait for reset
    time.sleep(2.1)

    # 3rd request ok again
    assert ratelimit_client.get("/quick-reset", headers=headers).status_code == 200


def test_byok_tier_limits(ratelimit_client, ratelimit_app):
    """
    Test that BYOK users have extremely high limits (effectively unlimited for tests).
    """
    with ratelimit_app.app_context():
        user = User(
            id="byok_user_test",
            username="byokuser",
            email="byok@example.com",
            password_hash="hash",
            subscription_tier="byok",
        )
        db.session.add(user)
        db.session.commit()

    token = _get_token("byok_user_test", "byok")
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    payload = {"character": "Test Hero", "age": 5}

    # Should allow 20 requests without any issue (higher than family limit)
    for i in range(20):
        resp = ratelimit_client.post(
            "/generate-story", data=json.dumps(payload), headers=headers
        )
        assert (
            resp.status_code != 429
        ), f"Request {i+1} unexpectedly rate-limited with status {resp.status_code}"


def test_ip_fallback_identifier_when_no_user_header(ratelimit_client):
    """
    Test limiter falls back to IP identifier when Auth header is missing.
    """
    response = ratelimit_client.get("/verify-limiter")
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data["identifier"].startswith("ip:")


def test_tts_requires_auth(ratelimit_client):
    """
    Test that /tts/synthesize returns 401 without a valid JWT.
    """
    response = ratelimit_client.post(
        "/tts/synthesize",
        data=json.dumps({"text": "hello", "voice": "en-US-Standard-A"}),
        content_type="application/json",
    )
    assert response.status_code == 401


def test_tts_rate_limit(ratelimit_client, ratelimit_app):
    """Test that /tts/synthesize enforces the per-user daily TTS quota.

    The endpoint's flask-limiter cap is 500/hour, but the practical per-user
    throttle is the daily TTS quota (check_tts_quota -> HTTP 429
    TTS_QUOTA_EXCEEDED). That quota is Redis-backed and Redis is not available
    in the test environment, so the check is exercised here by patching it
    directly: the first N calls are allowed, then the quota reports exceeded.

    The TTS service is mocked to return a proper (audio_bytes, timestamps)
    tuple so allowed requests succeed with 200 rather than falling through to
    the 503 "no TTS provider" path — a pure test-environment artifact that has
    nothing to do with rate limiting.
    """
    from unittest.mock import patch

    with ratelimit_app.app_context():
        user = User(
            id="tts_rate_test_user",
            username="ttsrateuser",
            email="tts_rate@example.com",
            password_hash="hash",
            subscription_tier="free",
        )
        db.session.add(user)
        db.session.commit()

    token = _get_token("tts_rate_test_user")
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    # Each request uses distinct text: the server-side TTS audio cache
    # deliberately serves repeated text from cache WITHOUT consuming the daily
    # quota (see tts_routes docstring), so identical payloads would never
    # reach the quota check this test exercises.
    def _payload(i):
        return {"text": f"Once upon a time {i}", "voice_id": "en-US-Standard-A"}

    # Mock the TTS service with the real method signature: synthesize() calls
    # generate_speech_with_timestamps() and unpacks an (audio, timestamps) tuple.
    fake_audio = b"\x00\x01\x02"
    mock_service = MagicMock()
    mock_service.generate_speech_with_timestamps.return_value = (fake_audio, [])
    mock_service.generate_speech_chunked.return_value = fake_audio
    mock_service.generate_speech_with_dialogue.return_value = fake_audio

    # Per-user daily TTS quota: allow the first 20 calls, then report exceeded.
    quota_calls = {"n": 0}

    def fake_check_tts_quota(user_id, user_tier):
        quota_calls["n"] += 1
        limit = 20
        count = quota_calls["n"] - 1
        return (count < limit, count, limit)

    # backend/.env sets TTS_DISABLED=true (the route then short-circuits to a
    # 503 before any rate-limit logic runs). Clear it for this test so the
    # quota/limiter path is actually exercised.
    with patch.dict(os.environ, {"TTS_DISABLED": "false"}), patch(
        "backend.routes.tts_routes._get_tts_service", return_value=mock_service
    ), patch(
        "backend.utils.ai_quota.check_tts_quota", side_effect=fake_check_tts_quota
    ), patch(
        "backend.utils.ai_quota.check_tts_chars_quota",
        return_value=(True, None, 0, 1000000),
    ), patch(
        "backend.utils.ai_quota.increment_tts_quota"
    ), patch(
        "backend.utils.ai_quota.increment_tts_chars"
    ):
        for i in range(20):
            resp = ratelimit_client.post(
                "/tts/synthesize", data=json.dumps(_payload(i)), headers=headers
            )
            assert (
                resp.status_code != 429
            ), f"Request {i+1} unexpectedly rate-limited (status {resp.status_code})"
        resp = ratelimit_client.post(
            "/tts/synthesize", data=json.dumps(_payload(20)), headers=headers
        )
        assert resp.status_code == 429
        assert resp.get_json().get("code") == "TTS_QUOTA_EXCEEDED"

        # Cache-hit replay is quota-exempt by design: text 0 was synthesized
        # and cached above, so re-requesting it succeeds even though the
        # user's daily synthesis quota is now exhausted.
        resp = ratelimit_client.post(
            "/tts/synthesize", data=json.dumps(_payload(0)), headers=headers
        )
        assert resp.status_code == 200, (
            f"Cached re-read should bypass the spent quota, got "
            f"status {resp.status_code}"
        )
