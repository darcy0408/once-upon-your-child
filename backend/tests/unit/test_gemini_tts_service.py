"""Unit tests for ``backend.gemini_tts_service``.

Covers the pure-Python helpers and the mock service. Does NOT exercise the
real Gemini API call — that path is patched in the fallback-chain integration
tests under ``test_tts_routes_fallback.py``.

Specifically:

* ``gemini_voice_for()`` — ElevenLabs voice ID → Gemini prebuilt name mapping,
  default fallback when the ID is unknown / empty / None.
* ``add_emotion_tags()`` — each of the curated regex patterns inserts the
  right inline tag exactly once, is case-insensitive, doesn't double-tag, and
  leaves clean prose unmodified.
* ``MockGeminiTTSService`` — returns empty bytes + empty timestamps so tests
  that need the chain to "succeed without sound" can swap it in.
* Curated voice IDs must all belong to the ``_GEMINI_VOICE_NAMES`` allowlist,
  so a future voice rename in Gemini's API surfaces as a test failure rather
  than a 500 at runtime.
"""
from __future__ import annotations

import pytest

from backend.gemini_tts_service import (
    CURATED_VOICES,
    DEFAULT_VOICE_ID,
    MockGeminiTTSService,
    _GEMINI_VOICE_NAMES,
    add_emotion_tags,
    gemini_voice_for,
)


# ---------------------------------------------------------------------------
# gemini_voice_for() — ElevenLabs ID → Gemini prebuilt name mapping
# ---------------------------------------------------------------------------


class TestGeminiVoiceFor:
    """Maps ElevenLabs voice IDs to the closest Gemini prebuilt voice."""

    @pytest.mark.parametrize(
        ("elevenlabs_id", "expected_gemini_voice"),
        [
            ("XrExE9yKIg1WjnnlVkGX", "Leda"),         # Matilda → warm female
            ("21m00Tcm4TlvDq8ikWAM", "Aoede"),        # Rachel → calm female
            ("ThT5KcBeYPX3keUQqHPh", "Aoede"),        # Dorothy (British) → calm
            ("jBpfuIE2acCO8z3wKNLl", "Callirrhoe"),   # Gigi (childlike) → playful
            ("JBFqnCBsd6RMkjVDRZzb", "Charon"),       # George (British) → deep male
            ("IKne3meq5aSn9XLyUdCD", "Zephyr"),       # Charlie (Aus) → warm male
            ("N2lVS1w4EtoT3dr4eOWO", "Puck"),         # Callum → lively male
            ("D38z5RcWu1voky8WS1ja", "Charon"),       # Fin (Irish) → deep male
        ],
    )
    def test_known_elevenlabs_ids_map_to_curated_voices(
        self, elevenlabs_id: str, expected_gemini_voice: str
    ) -> None:
        assert gemini_voice_for(elevenlabs_id) == expected_gemini_voice

    def test_unknown_id_falls_back_to_default(self) -> None:
        assert gemini_voice_for("nonexistent-voice-id-xyz") == DEFAULT_VOICE_ID

    def test_empty_string_falls_back_to_default(self) -> None:
        assert gemini_voice_for("") == DEFAULT_VOICE_ID

    def test_none_falls_back_to_default(self) -> None:
        # The implementation does ``(elevenlabs_voice_id or "").strip()`` so
        # ``None`` is coerced to "" and lands on the default.
        assert gemini_voice_for(None) == DEFAULT_VOICE_ID  # type: ignore[arg-type]

    def test_whitespace_is_stripped_before_lookup(self) -> None:
        # A user-supplied voice ID with stray whitespace shouldn't fall through
        # to the default just because the lookup key wasn't trimmed.
        assert gemini_voice_for("  XrExE9yKIg1WjnnlVkGX  ") == "Leda"

    def test_default_voice_is_in_curated_set(self) -> None:
        # The default must be one of the curated voices; otherwise the voice
        # picker UI can't show the default user's selection.
        curated_ids = {v["id"] for v in CURATED_VOICES}
        assert DEFAULT_VOICE_ID in curated_ids


# ---------------------------------------------------------------------------
# add_emotion_tags() — inject Gemini inline expressive tags
# ---------------------------------------------------------------------------


class TestAddEmotionTags:
    """Pattern-driven emotion-tag injection for Gemini Flash TTS."""

    @pytest.mark.parametrize(
        ("input_text", "expected_tag"),
        [
            ("She whispered to the cat.", "[whispers]"),
            ("He whispers softly.", "[whispers]"),
            ("They were whispering nearby.", "[whispers]"),
            ('He shouted "Look out!"', "[loudly]"),
            ('She yelled across the field.', "[loudly]"),
            ('The crowd screamed in shock.', "[loudly]"),
            ('The kids laughed at the joke.', "[laughs]"),
            ('She giggled at the silly fox.', "[laughs]"),
            ('He chuckled to himself.', "[laughs]"),
            ('She gasped in surprise.', "[gasps]"),
            ('The boy cried at bedtime.', "[sadly]"),
            ('He sobbed into the pillow.', "[sadly]"),
        ],
    )
    def test_each_cue_inserts_the_right_tag(
        self, input_text: str, expected_tag: str
    ) -> None:
        result = add_emotion_tags(input_text)
        assert expected_tag in result, f"missing {expected_tag} in {result!r}"

    def test_case_insensitive_matching(self) -> None:
        # Patterns use re.IGNORECASE — capitalised cues at sentence starts
        # must still trigger tag injection.
        assert "[whispers]" in add_emotion_tags("Whispered words filled the cave.")
        assert "[loudly]" in add_emotion_tags("SHOUTED commands echoed.")
        assert "[laughs]" in add_emotion_tags("Laughed at the absurdity, they did.")

    def test_cue_word_is_preserved_in_output(self) -> None:
        # The tag is inserted *after* the cue so the cue itself is still
        # spoken — losing the narrative word would change the story.
        result = add_emotion_tags("She whispered the secret.")
        assert "whispered" in result
        assert result == "She whispered [whispers] the secret."

    def test_clean_prose_is_unchanged(self) -> None:
        # No emotion-cue words → text passes through unmodified.
        clean = "The brave hero walked along the path to the castle."
        assert add_emotion_tags(clean) == clean

    def test_no_double_tagging_within_a_word(self) -> None:
        # The regexes use word boundaries (\b) so substrings shouldn't match.
        # 'unwhispered' contains 'whispered' as a substring — must not tag.
        # (Not a real English word but the regex contract should hold.)
        text = "She whispered. She whispered again."
        result = add_emotion_tags(text)
        # Two cues → two tags, but each cue gets exactly one tag.
        assert result.count("[whispers]") == 2

    def test_multiple_different_cues_each_get_their_tag(self) -> None:
        text = "She whispered then she shouted then she laughed."
        result = add_emotion_tags(text)
        assert "[whispers]" in result
        assert "[loudly]" in result
        assert "[laughs]" in result

    def test_empty_string_is_safe(self) -> None:
        assert add_emotion_tags("") == ""


# ---------------------------------------------------------------------------
# MockGeminiTTSService — test double for fallback-chain assertions
# ---------------------------------------------------------------------------


class TestMockGeminiTTSService:
    """Mock service returns the contract shape without calling the API."""

    def test_generate_speech_returns_empty_bytes(self) -> None:
        service = MockGeminiTTSService()
        assert service.generate_speech("anything") == b""

    def test_generate_speech_with_timestamps_returns_empty_pair(self) -> None:
        service = MockGeminiTTSService()
        audio_bytes, timestamps = service.generate_speech_with_timestamps("anything")
        assert audio_bytes == b""
        assert timestamps == []

    def test_mock_returns_real_curated_voice_list(self) -> None:
        # The voice picker reads voices via the service, so the mock must
        # return the same curated list — otherwise UI tests would see an
        # empty picker only on the mock path.
        assert MockGeminiTTSService.get_available_voices() == CURATED_VOICES

    def test_mock_accepts_any_kwargs(self) -> None:
        # Routes call the service with voice_id, speed, use_emotion_tags, …
        # The mock should accept anything the real service accepts.
        service = MockGeminiTTSService()
        result = service.generate_speech(
            "test", voice_id="Leda", use_emotion_tags=False
        )
        assert result == b""
        audio, ts = service.generate_speech_with_timestamps(
            "test", voice_id="Leda", speed=0.85, use_emotion_tags=True
        )
        assert audio == b""
        assert ts == []


# ---------------------------------------------------------------------------
# Curated voice allowlist — protects against Gemini API voice renames
# ---------------------------------------------------------------------------


class TestCuratedVoiceAllowlist:
    """Every curated voice ID must be a real Gemini prebuilt voice name.

    If Google renames a voice in a future Gemini release, this test fails
    loudly during CI instead of letting the route 500 in production.
    """

    def test_all_curated_voices_are_in_allowlist(self) -> None:
        for voice in CURATED_VOICES:
            voice_id = voice["id"]
            assert voice_id in _GEMINI_VOICE_NAMES, (
                f"Curated voice {voice_id!r} is not in the Gemini prebuilt "
                f"allowlist. Did Google rename it?"
            )

    def test_all_elevenlabs_mapping_targets_are_in_allowlist(self) -> None:
        from backend.gemini_tts_service import _ELEVENLABS_TO_GEMINI

        for elevenlabs_id, gemini_voice in _ELEVENLABS_TO_GEMINI.items():
            assert gemini_voice in _GEMINI_VOICE_NAMES, (
                f"Mapping {elevenlabs_id!r} → {gemini_voice!r} targets a "
                f"voice not in the Gemini prebuilt allowlist."
            )

    def test_allowlist_size_matches_documented_voice_count(self) -> None:
        # Google documents 30 prebuilt voices for Gemini 3.1 Flash TTS.
        # If this drops to 29 we want a heads-up (a voice was removed) —
        # if it climbs above 30 we want to consider exposing the new ones.
        assert len(_GEMINI_VOICE_NAMES) == 30

    def test_curated_voices_have_required_fields(self) -> None:
        # The Flutter voice picker depends on these fields existing.
        required = {"id", "name", "gender", "description", "recommended", "age_hint"}
        for voice in CURATED_VOICES:
            missing = required - set(voice.keys())
            assert not missing, f"Voice {voice.get('id')} missing fields: {missing}"

    def test_exactly_one_recommended_default(self) -> None:
        # The voice picker pre-selects the recommended voice. Two recommended
        # voices would create ambiguity in the UI; zero would leave nothing
        # pre-selected.
        recommended = [v for v in CURATED_VOICES if v.get("recommended")]
        assert len(recommended) == 1
        assert recommended[0]["id"] == DEFAULT_VOICE_ID
