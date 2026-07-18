"""Tests for backend.services.word_ranges — the single source of truth for
story word-count targets, validation floors, and post-generation caps.

The property test over the full (age x mode x length x duration) matrix is
the regression guard against the drift that motivated this module: the prompt
target, the validation floor, and the post-gen cap used to live in three
independent tables that contradicted each other, making several band/mode
combinations mathematically unsatisfiable (Explorer Superhero: prompt 250-350
vs floor 500; 9+ bedtime: prompt 650-900 vs floor 1100; etc.).
"""

from __future__ import annotations

import pytest

from backend.services.story_service import (
    _BEDTIME_WORD_RANGES,
    _duration_minutes_to_word_range,
    _narration_wpm_for_age,
)
from backend.services.superhero_validation import SUPERHERO_BAND_SPECS
from backend.services.word_ranges import (
    CAP_RATIO,
    FLOOR_RATIO,
    get_word_range,
    superhero_band_for_age,
)

AGES = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 25]
MODES = ["standard", "superhero", "bedtime", "rhyme", "ltr"]
LENGTHS = ["quick", "short", "standard", "medium", "long", "epic"]
DURATIONS = [None, "5_minutes", "10_minutes"]


# ---------------------------------------------------------------------------
# 1. Property test over the whole matrix — floor <= target_min <= target_max
#    <= cap for EVERY combination. This is the invariant that makes every
#    band/mode satisfiable: a story that lands anywhere inside the prompt's
#    stated range can never fail the floor nor trip the cap.
# ---------------------------------------------------------------------------
class TestMatrixInvariants:
    @pytest.mark.parametrize("age", AGES)
    @pytest.mark.parametrize("mode", MODES)
    @pytest.mark.parametrize("length", LENGTHS)
    @pytest.mark.parametrize("duration", DURATIONS)
    def test_floor_target_cap_ordering(self, age, mode, length, duration):
        spec = get_word_range(
            age=age, mode=mode, story_length=length, story_duration=duration
        )
        assert 0 < spec.floor, spec
        assert spec.floor <= spec.target_min, spec
        assert spec.target_min <= spec.target_max, spec
        assert spec.target_max <= spec.cap, spec

    @pytest.mark.parametrize("age", AGES)
    @pytest.mark.parametrize("mode", MODES)
    @pytest.mark.parametrize("length", LENGTHS)
    def test_floor_is_tolerant_and_cap_has_headroom(self, age, mode, length):
        """The floor must sit strictly BELOW target_min (it catches
        pathologically short output, not near-misses) and the cap strictly
        ABOVE target_max (a story slightly over target reads fine)."""
        spec = get_word_range(age=age, mode=mode, story_length=length)
        assert spec.floor < spec.target_min, spec
        assert spec.cap > spec.target_max, spec
        assert spec.floor == int(spec.target_min * FLOOR_RATIO)
        assert spec.cap == int(spec.target_max * CAP_RATIO)

    @pytest.mark.parametrize("minutes", [5, 10, 15])
    @pytest.mark.parametrize("age", AGES)
    def test_bedtime_explicit_duration_invariants(self, age, minutes):
        spec = get_word_range(age=age, mode="bedtime", duration_minutes=minutes)
        assert 0 < spec.floor <= spec.target_min <= spec.target_max <= spec.cap


# ---------------------------------------------------------------------------
# 2. Canonical numbers come from the PROMPTS' own tables (no re-declared copy)
# ---------------------------------------------------------------------------
class TestCanonicalSources:
    @pytest.mark.parametrize("band", sorted(SUPERHERO_BAND_SPECS))
    def test_superhero_targets_match_band_specs(self, band):
        ages = {
            "sprout": 4,
            "explorer": 7,
            "adventurer": 10,
            "creator": 13,
            "adolescent": 16,
        }
        spec = get_word_range(age=ages[band], mode="superhero")
        assert (spec.target_min, spec.target_max) == tuple(
            SUPERHERO_BAND_SPECS[band]["word_range"]
        )

    def test_superhero_band_param_overrides_age_derivation(self):
        spec = get_word_range(age=10, mode="superhero", superhero_band="creator")
        assert (spec.target_min, spec.target_max) == tuple(
            SUPERHERO_BAND_SPECS["creator"]["word_range"]
        )

    def test_bedtime_targets_match_bedtime_table(self):
        spec = get_word_range(age=9, mode="bedtime", story_length="standard")
        assert (spec.target_min, spec.target_max) == _BEDTIME_WORD_RANGES["8-10"][
            "medium"
        ]

    def test_sprout_standard_matches_prompt_page_override(self):
        """The standard Sprout prompt overrides its word range to
        pages*12..pages*25 (medium = 10 pages) with a hard 300-word ceiling;
        the canonical cap lands exactly on that ceiling."""
        spec = get_word_range(age=4, mode="standard", story_length="standard")
        assert (spec.target_min, spec.target_max) == (120, 250)
        assert spec.cap == 300  # int(250 * 1.2) == the prompt's HARD LIMIT

    def test_standard_duration_uses_age_appropriate_wpm(self):
        spec = get_word_range(
            age=9, mode="standard", story_length="standard", story_duration="10_minutes"
        )
        expected = _duration_minutes_to_word_range(10, wpm=_narration_wpm_for_age(9))
        assert (spec.target_min, spec.target_max) == expected

    def test_sprout_page_format_wins_over_duration(self):
        """Sprout's 8-12-page picture-book contract beats story_duration —
        mirrors generate_enhanced_prompt's own override order."""
        with_duration = get_word_range(
            age=4, mode="standard", story_length="standard", story_duration="10_minutes"
        )
        without = get_word_range(age=4, mode="standard", story_length="standard")
        assert with_duration == without

    def test_bedtime_duration_override_uses_default_narration_wpm(self):
        spec = get_word_range(age=6, mode="bedtime", duration_minutes=15)
        assert (spec.target_min, spec.target_max) == _duration_minutes_to_word_range(15)


# ---------------------------------------------------------------------------
# 3. The audit's previously-unsatisfiable combinations are now satisfiable
# ---------------------------------------------------------------------------
class TestFormerlyUnsatisfiableCombos:
    def test_explorer_superhero_300_words_passes(self):
        """Audit (a): prompt said 250-350, floor demanded 500+ — every story
        failed. An in-spec 300-word story must now clear the floor AND stay
        under the cap."""
        spec = get_word_range(age=7, mode="superhero", story_length="standard")
        assert spec.floor <= 300 <= spec.cap
        assert spec.floor <= 250  # the prompt's own minimum passes too

    def test_sprout_bedtime_350_words_within_range(self):
        """Audit (b): the flat 150-word Sprout belt fought bedtime's 260-380
        target. 350 words must be inside [floor, cap]."""
        spec = get_word_range(age=4, mode="bedtime", story_length="standard")
        assert spec.floor <= 350 <= spec.cap

    def test_age9_bedtime_800_words_passes(self):
        """Audit (d): bedtime 8-10 medium targets 650-900 but the floor
        demanded 1100 — every 9+ bedtime story ran max attempts."""
        spec = get_word_range(age=9, mode="bedtime", story_length="standard")
        assert spec.floor <= 800 <= spec.cap

    def test_adventurer_superhero_900_words_passes(self):
        """Audit (e): prompt says 900-1500 but the floor was 1100 — an
        in-spec 900-1099-word story was rejected and regenerated."""
        spec = get_word_range(age=10, mode="superhero", story_length="standard")
        assert spec.floor <= 900
        # And the prompt's "up to 1800 for a big finish" is inside the cap.
        assert spec.cap >= 1800

    def test_rhyme_time_age9_medium_within_range(self):
        """Rhyme prompts target far fewer words than regular prose (8-10
        medium rhyme = 500-650); the old 1100 floor was unsatisfiable."""
        spec = get_word_range(age=9, mode="rhyme", story_length="standard")
        assert spec.floor <= 500
        assert spec.target_max == 650

    def test_13plus_standard_keeps_a_high_floor(self):
        """The old 1700-word floor was right for 13+ STANDARD prose (target
        2400-3400) — deriving from the prompt keeps a floor in that league,
        it just no longer bleeds into superhero/bedtime/rhyme modes."""
        spec = get_word_range(age=15, mode="standard", story_length="standard")
        assert spec.floor >= 1700
        # ...while 13+ superhero (prompt: 1400-1900) floors below 1400.
        sh = get_word_range(age=15, mode="superhero")
        assert sh.floor < 1400


# ---------------------------------------------------------------------------
# 4. superhero_band_for_age (moved here from story_tasks; thresholds must
#    keep mirroring PromptService.build_story_prompt)
# ---------------------------------------------------------------------------
class TestSuperheroBandForAge:
    @pytest.mark.parametrize(
        "age, expected",
        [
            (3, "sprout"),
            (5, "sprout"),
            (6, "explorer"),
            (8, "explorer"),
            (9, "adventurer"),
            (12, "adventurer"),
            (13, "creator"),
            (14, "creator"),
            (15, "adolescent"),
            (17, "adolescent"),
            (18, "creator"),
            (None, "sprout"),
            ("junk", "sprout"),
        ],
    )
    def test_band(self, age, expected):
        assert superhero_band_for_age(age) == expected
