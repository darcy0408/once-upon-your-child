"""
Unit tests for build_bedtime_overlay (backend/services/story_service.py).

The overlay is appended to ANOTHER mode's prompt (today: the superhero saga
prompt when bedtime_mode is set) and must override pacing/tone/length while
preserving the base prompt's output-format contract (saga_state emission).
"""

from backend.services.story_service import (
    _BEDTIME_WORD_RANGES,
    _duration_minutes_to_word_range,
    build_bedtime_overlay,
)


class TestBuildBedtimeOverlay:
    """Test suite for the bedtime overlay prompt fragment."""

    def test_duration_minutes_embeds_130wpm_word_range(self):
        """duration_minutes=15 at 130 wpm -> 1950 target -> 1657-2242 words."""
        # Sanity-check the helper the overlay delegates to.
        assert _duration_minutes_to_word_range(15) == (1657, 2242)

        overlay = build_bedtime_overlay(age=8, duration_minutes=15)
        assert "1657-2242 words" in overlay

    def test_age_fallback_uses_band_medium_when_duration_none(self):
        """With no duration, length falls back to the band's medium bedtime range."""
        # Age 6 -> band "5-7" -> medium (420, 580)
        lo, hi = _BEDTIME_WORD_RANGES["5-7"]["medium"]
        overlay = build_bedtime_overlay(age=6, duration_minutes=None)
        assert f"{lo}-{hi} words" in overlay

        # Age 4 -> Sprout band "3-4" -> medium (260, 380)
        lo, hi = _BEDTIME_WORD_RANGES["3-4"]["medium"]
        overlay = build_bedtime_overlay(age=4)
        assert f"{lo}-{hi} words" in overlay

        # Age 25 -> "adult" -> medium (1100, 1500)
        lo, hi = _BEDTIME_WORD_RANGES["adult"]["medium"]
        overlay = build_bedtime_overlay(age=25)
        assert f"{lo}-{hi} words" in overlay

    def test_zero_duration_falls_back_to_band_range(self):
        """duration_minutes=0 is treated as absent (falsy guard)."""
        lo, hi = _BEDTIME_WORD_RANGES["8-10"]["medium"]
        overlay = build_bedtime_overlay(age=9, duration_minutes=0)
        assert f"{lo}-{hi} words" in overlay

    def test_overlay_preserves_saga_state_and_is_labeled(self):
        """The overlay names itself and explicitly preserves saga_state output."""
        overlay = build_bedtime_overlay(age=7)
        assert "BEDTIME OVERLAY" in overlay
        assert "saga_state" in overlay

    def test_mood_is_interpolated(self):
        """The requested mood shows up in the cozy-closing rule."""
        overlay = build_bedtime_overlay(age=7, mood="dreamy")
        assert "dreamy mood" in overlay
