"""Tests for the server-side audio cache in ``/tts/synthesize``.

The route is now cache-first: identical (text, voice, speed, provider-chain)
requests replay the stored MP3 without touching any provider and WITHOUT
consuming the daily TTS quota — a re-read must be free and instant. All
provider services are mocked; Azure/ElevenLabs/Gemini/Edge are never actually
called from tests.
"""

from __future__ import annotations

import base64
from unittest.mock import MagicMock

import pytest


@pytest.fixture
def tts_cache_env(mocker):
    """Mock every provider factory + quota helper around the synthesize route.

    Azure is unconfigured (as in the test env), so a free adult user is
    served by the default Gemini tier. Returns the mocks needed to assert
    which side effects fired.
    """
    gemini = MagicMock(name="GeminiService")
    gemini.generate_speech_with_timestamps.return_value = (
        b"gemini-audio",
        [{"start_ms": 0, "end_ms": 100}],
    )
    edge = MagicMock(name="EdgeService")
    edge.generate_speech_with_timestamps.return_value = (b"edge-audio", [])

    mocker.patch("backend.routes.tts_routes._get_tts_service", return_value=None)
    mocker.patch("backend.routes.tts_routes._get_gemini_service", return_value=gemini)
    mocker.patch("backend.routes.tts_routes._get_edge_service", return_value=edge)
    mocker.patch("backend.routes.tts_routes._get_azure_service", return_value=None)

    check_quota = mocker.patch(
        "backend.utils.ai_quota.check_tts_quota",
        return_value=(True, 0, 1000),
    )
    increment_quota = mocker.patch("backend.utils.ai_quota.increment_tts_quota")
    mocker.patch(
        "backend.utils.ai_quota.check_tts_chars_quota",
        return_value=(True, "", 0, 100_000),
    )
    mocker.patch("backend.utils.ai_quota.increment_tts_chars")
    mocker.patch("backend.utils.audit.audit_log")

    return {
        "gemini": gemini,
        "edge": edge,
        "check_quota": check_quota,
        "increment_quota": increment_quota,
    }


def _post(client, headers, text="Once upon a time, a hero set out.", **extra):
    payload = {"text": text, **extra}
    resp = client.post("/tts/synthesize", json=payload, headers=headers)
    return resp.status_code, resp.get_json()


class TestCacheFirstPath:
    def test_second_identical_request_is_served_from_cache(
        self, client, free_user_headers, tts_cache_env
    ):
        status1, body1 = _post(client, free_user_headers)
        assert status1 == 200
        assert body1["provider"] == "gemini"
        assert body1["cached"] is False
        assert tts_cache_env["gemini"].generate_speech_with_timestamps.call_count == 1

        status2, body2 = _post(client, free_user_headers)
        assert status2 == 200
        assert body2["cached"] is True
        assert body2["provider"] == "gemini"
        # Identical audio replayed, provider NOT called again.
        assert body2["audio_base64"] == body1["audio_base64"]
        assert base64.b64decode(body2["audio_base64"]) == b"gemini-audio"
        assert tts_cache_env["gemini"].generate_speech_with_timestamps.call_count == 1

    def test_cache_hit_preserves_word_timestamps(
        self, client, free_user_headers, tts_cache_env
    ):
        _, body1 = _post(client, free_user_headers)
        _, body2 = _post(client, free_user_headers)
        assert body1["word_timestamps"] == [{"start_ms": 0, "end_ms": 100}]
        assert body2["word_timestamps"] == [{"start_ms": 0, "end_ms": 100}]

    def test_whitespace_differences_still_hit(
        self, client, free_user_headers, tts_cache_env
    ):
        _post(client, free_user_headers, text="Once upon a time, a hero set out.")
        status, body = _post(
            client,
            free_user_headers,
            text="  Once   upon a time,\n a hero set out.  ",
        )
        assert status == 200
        assert body["cached"] is True
        assert tts_cache_env["gemini"].generate_speech_with_timestamps.call_count == 1

    def test_different_voice_misses(self, client, free_user_headers, tts_cache_env):
        _post(client, free_user_headers)
        status, body = _post(client, free_user_headers, voice_id="21m00Tcm4TlvDq8ikWAM")
        assert status == 200
        assert body["cached"] is False
        assert tts_cache_env["gemini"].generate_speech_with_timestamps.call_count == 2

    def test_different_speed_misses(self, client, free_user_headers, tts_cache_env):
        _post(client, free_user_headers)
        status, body = _post(client, free_user_headers, speed=0.85)
        assert status == 200
        assert body["cached"] is False
        assert tts_cache_env["gemini"].generate_speech_with_timestamps.call_count == 2

    def test_different_text_misses(self, client, free_user_headers, tts_cache_env):
        _post(client, free_user_headers)
        status, body = _post(client, free_user_headers, text="A different story.")
        assert status == 200
        assert body["cached"] is False
        assert tts_cache_env["gemini"].generate_speech_with_timestamps.call_count == 2


class TestCacheQuotaInteraction:
    def test_cache_hit_skips_quota_check_and_increment(
        self, client, free_user_headers, tts_cache_env
    ):
        _post(client, free_user_headers)
        assert tts_cache_env["check_quota"].call_count == 1
        assert tts_cache_env["increment_quota"].call_count == 1

        status, body = _post(client, free_user_headers)
        assert status == 200
        assert body["cached"] is True
        # Neither the quota gate nor the increment ran for the hit.
        assert tts_cache_env["check_quota"].call_count == 1
        assert tts_cache_env["increment_quota"].call_count == 1

    def test_quota_exhausted_user_can_still_replay_cached_audio(
        self, client, free_user_headers, tts_cache_env
    ):
        # Seed the cache while within quota…
        _post(client, free_user_headers)
        # …then exhaust the daily quota.
        tts_cache_env["check_quota"].return_value = (False, 20, 20)

        status, body = _post(client, free_user_headers)
        assert status == 200
        assert body["cached"] is True

        # A *new* text is still a miss and still 429s at the quota gate.
        status, body = _post(client, free_user_headers, text="Fresh story text.")
        assert status == 429
        assert body["code"] == "TTS_QUOTA_EXCEEDED"

    def test_synthesis_failure_is_not_cached(
        self, client, free_user_headers, tts_cache_env, mocker
    ):
        # All providers down -> 503; nothing must be stored for the key.
        mocker.patch("backend.routes.tts_routes._get_gemini_service", return_value=None)
        mocker.patch("backend.routes.tts_routes._get_edge_service", return_value=None)
        status, _ = _post(client, free_user_headers)
        assert status == 503

        # Providers recover -> the same request synthesizes fresh (a miss).
        mocker.patch(
            "backend.routes.tts_routes._get_gemini_service",
            return_value=tts_cache_env["gemini"],
        )
        status, body = _post(client, free_user_headers)
        assert status == 200
        assert body["cached"] is False
