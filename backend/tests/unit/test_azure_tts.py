"""MT-248 tests for the Azure AI Speech narration provider.

Covers:
* ``azure_tts_service`` pure helpers — voice mapping, speed→rate, SSML escaping,
  and ``available()`` returning False without the SDK/key (the dormant default).
* ``/tts/synthesize`` wiring — when Azure is configured it serves FIRST and the
  prohibited/unlicensed providers (ElevenLabs, Gemini, Edge) are bypassed; an
  Azure failure falls straight to 503 (client on-device), never to the legacy
  chain. When Azure is NOT configured, the legacy chain is unchanged.

The Azure SDK is never imported here — ``_get_azure_service`` / ``_azure_synthesize``
are patched at the route-module level, so these run without the package.
"""

from __future__ import annotations

import base64
from unittest.mock import MagicMock

import pytest

from backend import azure_tts_service as ats
from backend.azure_tts_service import (
    DEFAULT_AZURE_VOICE,
    AzureTTSService,
    _build_ssml,
    _speed_to_rate,
    azure_voice_for,
)


# ---------------------------------------------------------------------------
# Pure helpers
# ---------------------------------------------------------------------------
class TestAzureHelpers:
    def test_known_voice_maps(self):
        # Matilda (ElevenLabs) → the matching Azure neural voice.
        assert azure_voice_for("XrExE9yKIg1WjnnlVkGX") == "en-US-JennyNeural"

    def test_unknown_voice_falls_back_to_default(self):
        assert azure_voice_for("not-a-real-id") == DEFAULT_AZURE_VOICE
        assert azure_voice_for("") == DEFAULT_AZURE_VOICE
        assert azure_voice_for(None) == DEFAULT_AZURE_VOICE

    def test_azure_voices_match_edge_voices(self):
        # The whole point: Azure uses the SAME neural voice names as the Edge
        # fallback, so the switch is audibly seamless. Verify parity.
        from backend.edge_tts_service import _ELEVENLABS_TO_EDGE

        assert ats._ELEVENLABS_TO_AZURE == _ELEVENLABS_TO_EDGE

    @pytest.mark.parametrize(
        "speed,expected",
        [(1.0, "+0%"), (1.1, "+10%"), (0.8, "-20%"), (1.2, "+20%")],
    )
    def test_speed_to_rate(self, speed, expected):
        assert _speed_to_rate(speed) == expected

    def test_ssml_escapes_text_and_sets_voice(self):
        ssml = _build_ssml("Tom & Jerry <3 you", "en-US-AriaNeural", "+0%")
        assert 'name="en-US-AriaNeural"' in ssml
        assert 'rate="+0%"' in ssml
        # XML-special chars must be escaped so the SSML stays valid.
        assert "Tom &amp; Jerry &lt;3 you" in ssml
        assert "<3" not in ssml.replace("&lt;3", "")

    def test_available_false_without_key(self, monkeypatch):
        # SDK absent in test env → available() is False regardless of env.
        monkeypatch.delenv("AZURE_SPEECH_KEY", raising=False)
        monkeypatch.delenv("AZURE_SPEECH_REGION", raising=False)
        assert AzureTTSService.available() is False

    def test_available_false_with_key_but_no_sdk(self, monkeypatch):
        # Even with key+region, available() is False when the SDK isn't installed
        # (the dormant case until the package is pip-pinned).
        monkeypatch.setenv("AZURE_SPEECH_KEY", "k")
        monkeypatch.setenv("AZURE_SPEECH_REGION", "eastus")
        monkeypatch.setattr(ats, "AZURE_SPEECH_AVAILABLE", False)
        assert AzureTTSService.available() is False


# ---------------------------------------------------------------------------
# Route wiring — /tts/synthesize
# ---------------------------------------------------------------------------
@pytest.fixture
def legacy(mocker):
    """Patch the legacy provider factories + quota/audit helpers.

    Legacy services are 'available' so tests can assert they are NOT called when
    Azure serves. Quota helpers allow by default.
    """
    eleven = MagicMock(name="ElevenLabs")
    eleven.generate_speech_with_timestamps.return_value = (b"eleven", [])
    gemini = MagicMock(name="Gemini")
    gemini.generate_speech_with_timestamps.return_value = (b"gemini", [])
    edge = MagicMock(name="Edge")
    edge.generate_speech_with_timestamps.return_value = (b"edge", [])
    mocker.patch("backend.routes.tts_routes._get_tts_service", return_value=eleven)
    mocker.patch("backend.routes.tts_routes._get_gemini_service", return_value=gemini)
    mocker.patch("backend.routes.tts_routes._get_edge_service", return_value=edge)
    mocker.patch("backend.utils.ai_quota.check_tts_quota", return_value=(True, 0, 1000))
    mocker.patch("backend.utils.ai_quota.increment_tts_quota")
    mocker.patch(
        "backend.utils.ai_quota.check_tts_chars_quota",
        return_value=(True, "", 0, 100_000),
    )
    mocker.patch("backend.utils.ai_quota.increment_tts_chars")
    mocker.patch("backend.utils.audit.audit_log")
    return {"eleven": eleven, "gemini": gemini, "edge": edge}


def _enable_azure(mocker, synth_return):
    """Make Azure 'configured' and control what _azure_synthesize returns."""
    mocker.patch(
        "backend.routes.tts_routes._get_azure_service", return_value=MagicMock()
    )
    return mocker.patch(
        "backend.routes.tts_routes._azure_synthesize", return_value=synth_return
    )


def _post(client, headers, premium_voice=False):
    payload = {"text": "Once upon a time, a brave hero set out on a quest."}
    if premium_voice:
        payload["premium_voice"] = True
    r = client.post("/tts/synthesize", json=payload, headers=headers)
    return r.status_code, r.get_json()


class TestAzureRouteWiring:
    def test_azure_serves_first_and_bypasses_legacy(
        self, client, free_user_headers, legacy, mocker
    ):
        az = _enable_azure(mocker, (b"azure-audio", [{"start_ms": 0, "end_ms": 90}]))

        status, body = _post(client, free_user_headers)

        assert status == 200
        assert body["provider"] == "azure"
        assert base64.b64decode(body["audio_base64"]) == b"azure-audio"
        az.assert_called_once()
        # None of the prohibited/legacy providers were touched.
        legacy["eleven"].generate_speech_with_timestamps.assert_not_called()
        legacy["gemini"].generate_speech_with_timestamps.assert_not_called()
        legacy["edge"].generate_speech_with_timestamps.assert_not_called()

    def test_azure_failure_returns_503_not_legacy(
        self, client, free_user_headers, legacy, mocker
    ):
        # Azure is configured but the synth fails → must NOT fall back to the
        # prohibited Gemini/Edge chain; client drops to on-device instead.
        _enable_azure(mocker, None)

        status, body = _post(client, free_user_headers)

        assert status == 503
        assert "TTS service unavailable" in (body or {}).get("error", "")
        legacy["gemini"].generate_speech_with_timestamps.assert_not_called()
        legacy["edge"].generate_speech_with_timestamps.assert_not_called()

    def test_azure_ignores_premium_optin(
        self, client, free_user_headers, legacy, mocker
    ):
        # Even with premium_voice=true, Azure-configured bypasses ElevenLabs.
        _enable_azure(mocker, (b"azure-audio", []))

        status, body = _post(client, free_user_headers, premium_voice=True)

        assert status == 200
        assert body["provider"] == "azure"
        legacy["eleven"].generate_speech_with_timestamps.assert_not_called()

    def test_legacy_chain_unchanged_when_azure_off(
        self, client, free_user_headers, legacy, mocker
    ):
        # Azure not configured (_get_azure_service → None) → default = Gemini.
        mocker.patch("backend.routes.tts_routes._get_azure_service", return_value=None)

        status, body = _post(client, free_user_headers)

        assert status == 200
        assert body["provider"] == "gemini"
        legacy["gemini"].generate_speech_with_timestamps.assert_called_once()
