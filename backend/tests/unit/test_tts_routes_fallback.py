"""Integration tests for the tiered TTS fallback chain in ``/tts/synthesize``.

Asserts the ordering and side-effects after F-01 (ElevenLabs demoted to an
opt-in premium voice; Gemini Flash TTS is the default paid voice):

* Default request (no ``premium_voice``) → Gemini serves → ``provider='gemini'``
  even when ElevenLabs is fully available.
* ``premium_voice=true`` opts into ElevenLabs → ``provider='elevenlabs'`` while
  available + within budget.
* Gemini picks up when an opted-in ElevenLabs is unconfigured, char-budget
  exhausted, or raises a runtime error → ``provider='gemini'``.
* Edge TTS is the free final fallback → ``provider='edge'``.
* All providers unavailable → HTTP 503 so clients fall to on-device TTS.

Cost-tracker side effects:

* ``provider='gemini'`` logs exactly one ``api_cost_incurred`` event with
  ``provider='gemini'``, ``feature='tts'``, ``cost_usd ≈ 0.054 × chars/1000``.
* ``provider='gemini'`` MUST NOT increment ``increment_tts_chars`` — that
  counter exists to protect the ElevenLabs Year-1 free Creator credit cap;
  Gemini is the overflow tier that exists *because* that cap is exhausted.

The three lazy service-factory functions are patched at the module level so
each test gets a clean slate regardless of the real environment.
"""

from __future__ import annotations

import base64
from dataclasses import dataclass
from typing import Optional
from unittest.mock import MagicMock

import pytest

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@dataclass
class TTSMocks:
    """Mockable surface of the TTS routes module + its quota dependencies."""

    elevenlabs: MagicMock
    gemini: MagicMock
    edge: MagicMock
    log_api_cost: MagicMock
    increment_tts_chars: MagicMock
    check_tts_chars_quota: MagicMock


@pytest.fixture
def tts(mocker) -> TTSMocks:
    """Patch the three TTS service factories + quota/cost helpers.

    By default all three services are available and return distinct audio
    so tests can assert which tier actually served the request. Override
    individual return values in a test to simulate provider failure.
    """
    # --- Service mocks ------------------------------------------------------
    elevenlabs = MagicMock(name="ElevenLabsService")
    elevenlabs.generate_speech_with_timestamps.return_value = (
        b"elevenlabs-audio",
        [{"start_ms": 0, "end_ms": 100}],
    )
    elevenlabs.generate_speech_chunked.return_value = b"elevenlabs-chunked-audio"
    elevenlabs.generate_speech_with_dialogue.return_value = b"elevenlabs-dialogue-audio"

    gemini = MagicMock(name="GeminiService")
    gemini.generate_speech_with_timestamps.return_value = (b"gemini-audio", [])

    edge = MagicMock(name="EdgeService")
    edge.generate_speech_with_timestamps.return_value = (b"edge-audio", [])

    mocker.patch("backend.routes.tts_routes._get_tts_service", return_value=elevenlabs)
    mocker.patch("backend.routes.tts_routes._get_gemini_service", return_value=gemini)
    mocker.patch("backend.routes.tts_routes._get_edge_service", return_value=edge)

    # --- Quota helpers ------------------------------------------------------
    # All quotas allow by default; tests force the cap by overriding.
    mocker.patch(
        "backend.utils.ai_quota.check_tts_quota",
        return_value=(True, 0, 1000),
    )
    mocker.patch("backend.utils.ai_quota.increment_tts_quota")

    check_chars = mocker.patch(
        "backend.utils.ai_quota.check_tts_chars_quota",
        return_value=(True, "", 0, 100_000),
    )
    increment_chars = mocker.patch("backend.utils.ai_quota.increment_tts_chars")
    mocker.patch("backend.utils.audit.audit_log")

    # --- Cost tracker -------------------------------------------------------
    log_cost = mocker.patch("backend.services.cost_tracker.log_api_cost")

    return TTSMocks(
        elevenlabs=elevenlabs,
        gemini=gemini,
        edge=edge,
        log_api_cost=log_cost,
        increment_tts_chars=increment_chars,
        check_tts_chars_quota=check_chars,
    )


def _post_synthesize(
    client,
    headers: dict,
    text: str = "Once upon a time, a brave hero set out on a quest.",
    voice_id: Optional[str] = None,
    premium_voice: bool = False,
    character_voice_id: Optional[str] = None,
) -> tuple:
    """POST /tts/synthesize and return (status, json).

    ElevenLabs is opt-in after F-01 — pass ``premium_voice=True`` (or a
    ``character_voice_id`` for dialogue synthesis) to request it.
    """
    payload = {"text": text}
    if voice_id is not None:
        payload["voice_id"] = voice_id
    if premium_voice:
        payload["premium_voice"] = True
    if character_voice_id is not None:
        payload["character_voice_id"] = character_voice_id
    resp = client.post("/tts/synthesize", json=payload, headers=headers)
    return resp.status_code, resp.get_json()


@pytest.fixture
def under13_user(app):
    """A free-tier, fully-consented user flagged ``is_under_13``.

    A verified ConsentRecord is created alongside the user: /tts/synthesize now
    sits behind @require_parental_consent, so without one the request would be
    blocked at the consent gate (403) before reaching the ElevenLabs-skip logic
    these tests actually assert. verified=True so it passes regardless of the
    COPPA_REQUIRE_VERIFIED_CONSENT flag.
    """
    from backend.database import db
    from backend.models import User
    from backend.models.consent_record import ConsentRecord

    with app.app_context():
        user = User(
            id="under13_user_001",
            username="under13user",
            email="under13@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
            role="user",
            is_under_13=True,
        )
        db.session.add(user)
        consent = ConsentRecord(
            user_id="under13_user_001",
            child_age=8,
            parent_email="parent@example.com",
            consent_method="email_verified",
            verified=True,
        )
        db.session.add(consent)
        db.session.commit()
        yield user
        db.session.delete(consent)
        db.session.delete(user)
        db.session.commit()


@pytest.fixture
def under13_user_headers(under13_user):
    """Auth headers for the under-13 user."""
    from datetime import datetime, timedelta, timezone

    import jwt

    payload = {
        "user_id": under13_user.id,
        "sub": under13_user.id,
        "email": under13_user.email,
        "subscription_tier": "free",
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(payload, "dev-secret-key", algorithm="HS256")
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


@pytest.fixture
def teen_user(app):
    """A 15-year-old, ``is_under_13=False`` with a resolved ``declared_age``.

    Mirrors a real 13-17 account: the self-attest gate POSTs declared_age
    without setting is_under_13. MT-327: this population previously slipped
    past the Gemini gate (which checked only is_under_13) and reached Gemini
    Flash TTS — barred for all minors under Gemini's API ToS.
    """
    from backend.database import db
    from backend.models import User

    with app.app_context():
        user = User(
            id="teen_user_001",
            username="teenuser",
            email="teen@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
            role="user",
            is_under_13=False,
            declared_age=15,
        )
        db.session.add(user)
        db.session.commit()
        yield user
        db.session.delete(user)
        db.session.commit()


@pytest.fixture
def teen_user_headers(teen_user):
    """Auth headers for the 13-17 teen user."""
    from datetime import datetime, timedelta, timezone

    import jwt

    payload = {
        "user_id": teen_user.id,
        "sub": teen_user.id,
        "email": teen_user.email,
        "subscription_tier": "free",
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(payload, "dev-secret-key", algorithm="HS256")
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


# ---------------------------------------------------------------------------
# Default provider — Gemini (ElevenLabs is opt-in after F-01)
# ---------------------------------------------------------------------------


class TestDefaultTier:
    """Default request serves Gemini even when ElevenLabs is fully available."""

    def test_default_serves_gemini_not_elevenlabs(
        self, client, free_user_headers, tts: TTSMocks
    ) -> None:
        # No premium_voice flag → ElevenLabs must never be touched, Gemini wins.
        status, body = _post_synthesize(client, free_user_headers)

        assert status == 200
        assert body["provider"] == "gemini"
        assert base64.b64decode(body["audio_base64"]) == b"gemini-audio"
        assert body["format"] == "mp3"
        tts.elevenlabs.generate_speech_with_timestamps.assert_not_called()
        tts.gemini.generate_speech_with_timestamps.assert_called_once()
        tts.edge.generate_speech_with_timestamps.assert_not_called()


# ---------------------------------------------------------------------------
# Opt-in premium tier — ElevenLabs via premium_voice=true
# ---------------------------------------------------------------------------


class TestElevenLabsTier:
    """ElevenLabs serves when explicitly opted-in, available, and within budget."""

    def test_serves_when_opted_in_and_available(
        self, client, free_user_headers, tts: TTSMocks
    ) -> None:
        status, body = _post_synthesize(client, free_user_headers, premium_voice=True)

        assert status == 200
        assert body["provider"] == "elevenlabs"
        assert base64.b64decode(body["audio_base64"]) == b"elevenlabs-audio"
        assert body["format"] == "mp3"
        # ElevenLabs was actually called; Gemini and Edge were not.
        tts.elevenlabs.generate_speech_with_timestamps.assert_called_once()
        tts.gemini.generate_speech_with_timestamps.assert_not_called()
        tts.edge.generate_speech_with_timestamps.assert_not_called()


# ---------------------------------------------------------------------------
# Provider ordering — Gemini fallback paths
# ---------------------------------------------------------------------------


class TestGeminiFallback:
    """Gemini Flash TTS picks up when an opted-in ElevenLabs is unavailable."""

    def test_serves_when_elevenlabs_factory_returns_none(
        self, client, free_user_headers, tts: TTSMocks, mocker
    ) -> None:
        # Premium opt-in, but ELEVENLABS_API_KEY unset — factory returns None.
        mocker.patch("backend.routes.tts_routes._get_tts_service", return_value=None)

        status, body = _post_synthesize(client, free_user_headers, premium_voice=True)

        assert status == 200
        assert body["provider"] == "gemini"
        assert base64.b64decode(body["audio_base64"]) == b"gemini-audio"
        tts.gemini.generate_speech_with_timestamps.assert_called_once()
        tts.edge.generate_speech_with_timestamps.assert_not_called()

    def test_serves_when_elevenlabs_raises_exception(
        self, client, free_user_headers, tts: TTSMocks
    ) -> None:
        # Opted-in ElevenLabs is configured but its API call blows up — Gemini
        # fallback fires.
        tts.elevenlabs.generate_speech_with_timestamps.side_effect = Exception(
            "ElevenLabs API timeout"
        )

        status, body = _post_synthesize(client, free_user_headers, premium_voice=True)

        assert status == 200
        assert body["provider"] == "gemini"
        tts.gemini.generate_speech_with_timestamps.assert_called_once()

    def test_serves_when_elevenlabs_char_budget_exhausted(
        self, client, free_user_headers, tts: TTSMocks
    ) -> None:
        # Premium opt-in, but the monthly char cap is hit — ``check_tts_chars_quota``
        # flips ``elevenlabs_ok`` to False before any ElevenLabs call.
        tts.check_tts_chars_quota.return_value = (False, "global", 100_000, 100_000)

        status, body = _post_synthesize(client, free_user_headers, premium_voice=True)

        assert status == 200
        assert body["provider"] == "gemini"
        # ElevenLabs was never invoked — budget gate stopped it cold.
        tts.elevenlabs.generate_speech_with_timestamps.assert_not_called()
        tts.gemini.generate_speech_with_timestamps.assert_called_once()


# ---------------------------------------------------------------------------
# Provider ordering — Edge fallback paths
# ---------------------------------------------------------------------------


class TestEdgeFallback:
    """Tier 3: Edge TTS serves only when both higher tiers are unavailable."""

    def test_serves_when_elevenlabs_and_gemini_unavailable(
        self, client, free_user_headers, tts: TTSMocks, mocker
    ) -> None:
        mocker.patch("backend.routes.tts_routes._get_tts_service", return_value=None)
        mocker.patch("backend.routes.tts_routes._get_gemini_service", return_value=None)

        status, body = _post_synthesize(client, free_user_headers)

        assert status == 200
        assert body["provider"] == "edge"
        assert base64.b64decode(body["audio_base64"]) == b"edge-audio"
        tts.edge.generate_speech_with_timestamps.assert_called_once()

    def test_serves_when_elevenlabs_unconfigured_and_gemini_errors(
        self, client, free_user_headers, tts: TTSMocks, mocker
    ) -> None:
        mocker.patch("backend.routes.tts_routes._get_tts_service", return_value=None)
        tts.gemini.generate_speech_with_timestamps.side_effect = Exception(
            "Gemini quota exceeded"
        )

        status, body = _post_synthesize(client, free_user_headers)

        assert status == 200
        assert body["provider"] == "edge"

    def test_503_when_all_three_providers_unavailable(
        self, client, free_user_headers, mocker
    ) -> None:
        # Patch all three factories to return None — the only path is 503
        # so the client falls back to on-device flutter_tts.
        mocker.patch("backend.routes.tts_routes._get_tts_service", return_value=None)
        mocker.patch("backend.routes.tts_routes._get_gemini_service", return_value=None)
        mocker.patch("backend.routes.tts_routes._get_edge_service", return_value=None)
        mocker.patch(
            "backend.utils.ai_quota.check_tts_quota",
            return_value=(True, 0, 1000),
        )
        mocker.patch("backend.utils.ai_quota.increment_tts_quota")
        mocker.patch(
            "backend.utils.ai_quota.check_tts_chars_quota",
            return_value=(True, "", 0, 100_000),
        )
        mocker.patch("backend.utils.audit.audit_log")

        status, body = _post_synthesize(client, free_user_headers)

        assert status == 503
        assert body is not None
        assert "TTS service unavailable" in body.get("error", "")


# ---------------------------------------------------------------------------
# Cost-tracker side effects
# ---------------------------------------------------------------------------


class TestCostTrackerSideEffects:
    """Each successful tier logs cost (or zero) with the right provider tag."""

    def test_gemini_path_logs_cost_with_gemini_provider(
        self, client, free_user_headers, tts: TTSMocks, mocker
    ) -> None:
        mocker.patch("backend.routes.tts_routes._get_tts_service", return_value=None)
        text = "Once upon a time, a brave hero set out on a quest."

        status, body = _post_synthesize(client, free_user_headers, text=text)

        assert status == 200
        assert body["provider"] == "gemini"
        # log_api_cost was called once with provider='gemini' and the right cost.
        tts.log_api_cost.assert_called_once()
        kwargs = tts.log_api_cost.call_args.kwargs
        assert kwargs["provider"] == "gemini"
        assert kwargs["feature"] == "tts"
        assert kwargs["unit_kind"] == "chars"
        # Cost is $0.054/1k chars on the cleaned text. The route calls
        # clean_text_for_tts before logging so the unit count may differ
        # slightly from raw len(text); just assert the right ballpark.
        expected = (kwargs["units"] / 1000) * 0.054
        assert abs(kwargs["cost_usd"] - expected) < 1e-6

    def test_gemini_path_does_not_increment_elevenlabs_char_budget(
        self, client, free_user_headers, tts: TTSMocks, mocker
    ) -> None:
        # Gemini exists *because* the ElevenLabs budget is gone — incrementing
        # that counter on Gemini calls would corrupt the Year-1 cap math.
        mocker.patch("backend.routes.tts_routes._get_tts_service", return_value=None)

        status, body = _post_synthesize(client, free_user_headers)

        assert status == 200
        assert body["provider"] == "gemini"
        tts.increment_tts_chars.assert_not_called()

    def test_elevenlabs_path_does_increment_elevenlabs_char_budget(
        self, client, free_user_headers, tts: TTSMocks
    ) -> None:
        # Sanity check the inverse: the opted-in ElevenLabs path MUST still
        # increment the char counter so the global cap fires when it should.
        status, body = _post_synthesize(client, free_user_headers, premium_voice=True)

        assert status == 200
        assert body["provider"] == "elevenlabs"
        tts.increment_tts_chars.assert_called_once()

    def test_edge_path_does_not_log_cost(
        self, client, free_user_headers, tts: TTSMocks, mocker
    ) -> None:
        # Edge is free — no log_api_cost row should be written.
        mocker.patch("backend.routes.tts_routes._get_tts_service", return_value=None)
        mocker.patch("backend.routes.tts_routes._get_gemini_service", return_value=None)

        status, body = _post_synthesize(client, free_user_headers)

        assert status == 200
        assert body["provider"] == "edge"
        tts.log_api_cost.assert_not_called()
        tts.increment_tts_chars.assert_not_called()


# ---------------------------------------------------------------------------
# TTS_DISABLED kill-switch
# ---------------------------------------------------------------------------


class TestTtsDisabledKillSwitch:
    """``TTS_DISABLED=1`` short-circuits all three providers."""

    def test_disabled_env_returns_503_before_any_provider(
        self, client, free_user_headers, tts: TTSMocks, monkeypatch
    ) -> None:
        monkeypatch.setenv("TTS_DISABLED", "1")

        status, body = _post_synthesize(client, free_user_headers)

        assert status == 503
        # None of the three providers should have been touched.
        tts.elevenlabs.generate_speech_with_timestamps.assert_not_called()
        tts.gemini.generate_speech_with_timestamps.assert_not_called()
        tts.edge.generate_speech_with_timestamps.assert_not_called()


# ---------------------------------------------------------------------------
# Under-13 ElevenLabs hard-gate (ElevenLabs ToS forbids under-13 audio)
# ---------------------------------------------------------------------------


class TestUnder13ElevenLabsGate:
    """A user flagged ``is_under_13`` must NEVER reach ElevenLabs, even when they
    opt in via ``premium_voice`` or request dialogue (``character_voice_id``).

    With Azure (the licensed provider, MT-248) unconfigured — as in this test
    env — the legacy Gemini -> Edge chain is ALSO barred for them: Gemini bars
    under-18 use contractually, and edge-tts isn't licensed for commercial
    use. Rather than silently falling through to either, the request 503s so
    the client falls back to its on-device voice, exactly as if Azure itself
    had failed."""

    def test_under13_premium_voice_gets_503_not_gemini(
        self, client, under13_user_headers, tts: TTSMocks
    ) -> None:
        # Explicit premium opt-in, but the user is under 13 — ElevenLabs is
        # refused, and Gemini must not silently serve the narration either.
        status, body = _post_synthesize(
            client, under13_user_headers, premium_voice=True
        )

        assert status == 503
        assert body["error"] == "TTS service unavailable"
        # No provider — licensed or legacy — was invoked for this user.
        tts.elevenlabs.generate_speech_with_timestamps.assert_not_called()
        tts.elevenlabs.generate_speech_chunked.assert_not_called()
        tts.elevenlabs.generate_speech_with_dialogue.assert_not_called()
        tts.gemini.generate_speech_with_timestamps.assert_not_called()

    def test_under13_dialogue_request_gets_503_not_gemini(
        self, client, under13_user_headers, tts: TTSMocks
    ) -> None:
        # character_voice_id normally forces ElevenLabs (only multi-voice
        # provider). Under 13 it must still be refused — no dialogue
        # synthesis, and no silent fall-through to Gemini either.
        status, body = _post_synthesize(
            client, under13_user_headers, character_voice_id="some-character-voice"
        )

        assert status == 503
        assert body["error"] == "TTS service unavailable"
        tts.elevenlabs.generate_speech_with_dialogue.assert_not_called()
        tts.elevenlabs.generate_speech_with_timestamps.assert_not_called()
        tts.gemini.generate_speech_with_timestamps.assert_not_called()

    def test_under13_does_not_fall_through_to_edge_either(
        self, client, under13_user_headers, tts: TTSMocks, mocker
    ) -> None:
        # The gate must not strand under-13 users onto Edge TTS (unlicensed
        # for commercial use, MT-248) just because Gemini happens to be
        # unavailable too — both legacy providers are barred for them
        # regardless of which one would otherwise have served the request.
        mocker.patch("backend.routes.tts_routes._get_gemini_service", return_value=None)

        status, body = _post_synthesize(
            client, under13_user_headers, premium_voice=True
        )

        assert status == 503
        assert body["error"] == "TTS service unavailable"
        tts.elevenlabs.generate_speech_with_timestamps.assert_not_called()
        tts.edge.generate_speech_with_timestamps.assert_not_called()


# ---------------------------------------------------------------------------
# 13-17 Gemini gate (MT-327) — Gemini bars ALL minors, not just under-13s
# ---------------------------------------------------------------------------


class TestTeenGeminiGate:
    """A 13-17 user (``is_under_13=False``, ``declared_age`` resolved to a
    teen value) must never reach Gemini Flash TTS in the legacy fallback
    chain — Gemini's API ToS bar under-18 use, not just under-13. Edge TTS
    remains available to this population (its gate is unchanged)."""

    def test_teen_default_request_skips_gemini_serves_edge(
        self, client, teen_user_headers, tts: TTSMocks
    ) -> None:
        status, body = _post_synthesize(client, teen_user_headers)

        assert status == 200
        assert body["provider"] == "edge"
        tts.gemini.generate_speech_with_timestamps.assert_not_called()
        tts.edge.generate_speech_with_timestamps.assert_called_once()

    def test_teen_gets_503_when_edge_also_unavailable(
        self, client, teen_user_headers, tts: TTSMocks, mocker
    ) -> None:
        mocker.patch("backend.routes.tts_routes._get_edge_service", return_value=None)

        status, body = _post_synthesize(client, teen_user_headers)

        assert status == 503
        assert body["error"] == "TTS service unavailable"
        tts.gemini.generate_speech_with_timestamps.assert_not_called()


# ---------------------------------------------------------------------------
# 13-17 ElevenLabs gate (MT-365) — ElevenLabs' ToS bar ALL minors under 18
# ---------------------------------------------------------------------------


class TestTeenElevenLabsGate:
    """A 13-17 user (``is_under_13=False``, ``declared_age`` a teen value) who
    opts into a premium/dialogue voice must NOT reach ElevenLabs — its ToS bar
    all under-18s, not just under-13s (MT-365). The opt-in gate previously
    checked only ``is_under_13``, so this population slipped through. Unlike
    under-13s, teens keep their (unchanged) Edge gate, so the request succeeds
    on Edge in the legacy fallback rather than 503-ing."""

    def test_teen_premium_voice_blocked_from_elevenlabs_serves_edge(
        self, client, teen_user_headers, tts: TTSMocks
    ) -> None:
        # Explicit premium opt-in, but the user is 13-17 — ElevenLabs is
        # refused (under-18 ToS bar). Gemini is also under-18-barred, so the
        # narration lands on Edge rather than the premium voice.
        status, body = _post_synthesize(client, teen_user_headers, premium_voice=True)

        assert status == 200
        assert body["provider"] == "edge"
        tts.elevenlabs.generate_speech_with_timestamps.assert_not_called()
        tts.elevenlabs.generate_speech_chunked.assert_not_called()
        tts.elevenlabs.generate_speech_with_dialogue.assert_not_called()
        tts.gemini.generate_speech_with_timestamps.assert_not_called()

    def test_teen_dialogue_request_blocked_from_elevenlabs_serves_edge(
        self, client, teen_user_headers, tts: TTSMocks
    ) -> None:
        # character_voice_id normally forces ElevenLabs (only multi-voice
        # provider). For a teen it must still be refused; the request falls
        # through to a single-voice Edge narration rather than reaching
        # ElevenLabs' dialogue endpoint.
        status, body = _post_synthesize(
            client, teen_user_headers, character_voice_id="some-character-voice"
        )

        assert status == 200
        assert body["provider"] == "edge"
        tts.elevenlabs.generate_speech_with_dialogue.assert_not_called()
        tts.elevenlabs.generate_speech_with_timestamps.assert_not_called()
        tts.gemini.generate_speech_with_timestamps.assert_not_called()
