"""Unit tests for backend.services.superhero_validation — the pure post-
generation structural-check module backing the Superhero Mode validator fix
(see backend/tasks/story_tasks.py's ``_validate_and_regen_superhero`` for the
orchestration that calls these, tested in tests/unit/test_superhero_meta_validation.py).
"""

from __future__ import annotations

import pytest

from backend.services.superhero_validation import (
    SAGA_STATE_REQUIRED_KEYS,
    SUPERHERO_BAND_SPECS,
    backfill_saga_state,
    should_retry,
    validate_page_count,
    validate_word_count,
)


class TestValidateWordCount:
    def test_within_range_returns_none(self):
        assert validate_word_count(1500, "creator") is None  # spec is 1100-1800

    def test_under_ceiling_returns_none_even_if_under_floor(self):
        # Being under the floor is intentionally NOT this function's job — the
        # existing per-attempt min_words_threshold retry loop covers that.
        assert validate_word_count(50, "creator") is None

    def test_unknown_band_returns_none(self):
        assert validate_word_count(999999, "not-a-band") is None

    def test_flag_severity_between_15_and_25_percent_over(self):
        # Creator ceiling 1800; 15% over = 2070, 25% over = 2250.
        issue = validate_word_count(2100, "creator")
        assert issue is not None
        assert issue["severity"] == "flag"
        assert issue["type"] == "word_count"
        assert issue["band"] == "creator"
        assert issue["expected_range"] == [1100, 1800]

    def test_retry_severity_over_25_percent(self):
        issue = validate_word_count(2300, "creator")  # (2300-1800)/1800 = 0.278
        assert issue["severity"] == "retry"

    def test_adolescent_matches_observed_prod_bug(self):
        # 3044/3045 words vs the prompt's stated ceiling (now 1400-1900 after
        # the T10 hardening; was 1400-2200), observed twice in prod on
        # 2026-07-07 — still comfortably "retry" severity either way.
        issue = validate_word_count(3044, "adolescent")
        assert issue["severity"] == "retry"
        assert issue["over_ratio"] > 0.25


class TestValidatePageCount:
    @pytest.mark.parametrize(
        "band, lo, hi",
        [
            (b, s["page_range"][0], s["page_range"][1])
            for b, s in SUPERHERO_BAND_SPECS.items()
        ],
    )
    def test_within_range_returns_none(self, band, lo, hi):
        assert validate_page_count(lo, band) is None
        assert validate_page_count(hi, band) is None

    def test_creator_8_pages_matches_observed_prod_bug(self):
        # "an 8-page output where the Creator prompt demands exactly 7"
        issue = validate_page_count(8, "creator")
        assert issue is not None
        assert issue["severity"] == "retry"
        assert issue["expected_range"] == [7, 7]

    def test_unknown_band_returns_none(self):
        assert validate_page_count(3, "not-a-band") is None


class TestBackfillSagaState:
    def test_creator_missing_keys_backfilled_and_flagged(self):
        state, issue = backfill_saga_state({"nemesis": "Redact"}, "creator")
        for key in SAGA_STATE_REQUIRED_KEYS["creator"]:
            assert key in state
        assert state["allies"] == []
        assert state["what_it_cost"] == ""
        assert issue["type"] == "saga_state_incomplete"
        assert issue["severity"] == "flag"
        assert "nemesis" not in issue["missing_keys"]  # was present

    def test_adolescent_missing_keys_backfilled_and_flagged(self):
        state, issue = backfill_saga_state({}, "adolescent")
        assert issue is not None
        assert set(issue["missing_keys"]) == set(SAGA_STATE_REQUIRED_KEYS["adolescent"])

    def test_all_keys_present_no_issue(self):
        complete = {
            k: ("x" if k != "allies" else ["Ally"])
            for k in SAGA_STATE_REQUIRED_KEYS["creator"]
        }
        state, issue = backfill_saga_state(complete, "creator")
        assert issue is None
        assert state == complete

    def test_bands_outside_required_keys_are_unchanged(self):
        # Sprout/Explorer/Adventurer aren't part of the returnable-saga
        # continuity feature — a sparse saga_state is returned as-is.
        sparse = {"nemesis": "Gigawatt"}
        state, issue = backfill_saga_state(sparse, "adventurer")
        assert state == sparse
        assert issue is None

    def test_none_saga_state_for_unenforced_band_stays_none(self):
        state, issue = backfill_saga_state(None, "explorer")
        assert state is None
        assert issue is None

    def test_none_saga_state_for_enforced_band_is_backfilled(self):
        # Creator/Adolescent always emit saga_state per their prompt's OUTPUT
        # FORMAT — a fully-absent block is a real completeness issue, not a
        # "no saga this Issue" case.
        state, issue = backfill_saga_state(None, "creator")
        assert issue is not None
        assert state["allies"] == []


class TestShouldRetry:
    def test_true_when_any_retry_severity(self):
        assert should_retry([{"severity": "flag"}, {"severity": "retry"}]) is True

    def test_false_when_only_flags(self):
        assert should_retry([{"severity": "flag"}]) is False

    def test_false_when_empty(self):
        assert should_retry([]) is False
