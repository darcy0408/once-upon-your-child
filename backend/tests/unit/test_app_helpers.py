"""Unit tests for ``backend.utils.app_helpers``.

Covers MT-114 (narrowed content-filter age gate) and MT-113 (per-minute
expensive-tier rate-limit floors). The Flask request-context helpers are
exercised via the existing API test suites; here we focus on the pure
functions that do not require an app context.
"""

from __future__ import annotations

import logging

import pytest

from backend.utils.app_helpers import (
    make_filter_story_content,
)


# Disable the autouse Gemini mock from the parent conftest — these tests
# never touch the LLM layer and don't need the Flask app fixture either.
@pytest.fixture(autouse=True)
def _no_gemini():
    yield


@pytest.fixture
def filter_fn():
    return make_filter_story_content(logging.getLogger("test_app_helpers"))


# ---------------------------------------------------------------------------
# MT-114: narrowed _KEYWORDS_YOUNG_ONLY gate (was age<=7, now age<=5)
# ---------------------------------------------------------------------------
class TestNarrowedYoungOnlyGate:
    def test_age_5_scary_monster_defers_to_llm_classifier(self, filter_fn):
        """'scary'/'monster'/'nightmare' are no longer instant keyword blocks
        for Sprout — a bare match can't tell a friendly monster from a peril,
        and was swapping reassuring Sprout stories for the generic fallback.
        Those words now fall through to moderate_story_content, so the keyword
        gate must NOT flag them."""
        text = "Once upon a time there was a scary monster in the forest."
        _, flagged = filter_fn(text, age=5)
        assert flagged is False

    def test_age_7_with_scary_moment_is_not_flagged(self, filter_fn):
        """Explorer (age 7) gets 'scary' as normal vocabulary — must NOT flag."""
        text = "It was a scary moment, but Lily took a deep breath and felt brave."
        _, flagged = filter_fn(text, age=7)
        assert flagged is False

    def test_age_7_with_kill_the_dragon_is_not_flagged(self, filter_fn):
        """Explorer can have mild violence; the LLM safety layer catches the
        egregious cases. 'kill the dragon' must not trigger the keyword filter."""
        text = "The young knight raised her sword: 'I will kill the dragon!'"
        _, flagged = filter_fn(text, age=7)
        assert flagged is False

    def test_age_5_with_kill_is_still_flagged(self, filter_fn):
        """Regression guard — Sprout still gets the full keyword set."""
        text = "The mean wizard wanted to kill the rabbits."
        _, flagged = filter_fn(text, age=5)
        assert flagged is True


# ---------------------------------------------------------------------------
# Existing always-block keywords still apply at every age
# ---------------------------------------------------------------------------
class TestAllAgesKeywordsStillBlocked:
    def test_all_ages_keyword_blocked_for_explorer(self, filter_fn):
        """The _KEYWORDS_ALL_AGES list is age-independent — it must still fire
        on Explorer/Adventurer ages even after the gate narrowed."""
        # Use a keyword from _KEYWORDS_ALL_AGES that won't accidentally
        # collide with the narrowed list.
        text = "The story contained sexual content, which is never appropriate."
        _, flagged = filter_fn(text, age=8)
        assert flagged is True

    def test_empty_text_is_not_flagged(self, filter_fn):
        _, flagged = filter_fn("", age=5)
        assert flagged is False


# ---------------------------------------------------------------------------
# MT-113: expensive-tier per-minute floors bumped
# ---------------------------------------------------------------------------
class TestExpensiveTierPerMinuteFloors:
    """Direct lookup against the in-source `limits` dict to keep this test
    independent of Flask request-context plumbing. We re-derive the same
    structure ``get_tier_limits`` builds and assert on the per-minute floors.
    """

    def _expensive_limits(self) -> dict:
        # Mirror the structure from get_tier_limits to inspect the values
        # without needing a Flask request context. The single source of truth
        # is exercised end-to-end by tests/security/test_rate_limiting.py.
        # Re-import the function to read its literal default dict via inspect.
        import inspect

        from backend.utils import app_helpers

        src = inspect.getsource(app_helpers.get_tier_limits)
        # Sanity: the block is small; just check the literal strings appear.
        return src

    def test_free_per_minute_is_15(self):
        # MT-113 (reopen): hour/day raised above the monthly quota so they
        # never shadow it; the monthly-quota check is the real cost gate.
        src = self._expensive_limits()
        assert '"free": "15/minute; 60/hour; 100/day"' in src

    def test_premium_per_minute_is_30(self):
        src = self._expensive_limits()
        assert '"premium": "30/minute; 120/hour; 200/day"' in src

    def test_family_per_minute_is_60(self):
        src = self._expensive_limits()
        assert '"family": "60/minute; 240/hour; 400/day"' in src
