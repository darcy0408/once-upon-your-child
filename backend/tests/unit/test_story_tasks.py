"""Unit tests for ``backend.tasks.story_tasks`` post-generation word caps.

Covers MT-108: the Explorer (ages 6-8) Superhero theme reuses the Sprout
retry+truncate helper with cap=350. The Sprout-specific behavior is already
covered by ``backend/tests/test_prompt_service.py``; this file focuses on
the Explorer parameterization and the band/age guards.
"""

from __future__ import annotations

import json
from unittest.mock import MagicMock

import pytest

from backend.tasks.story_tasks import (
    EXPLORER_SUPERHERO_WORD_CAP,
    SPROUT_WORD_CAP,
    _count_words,
    _enforce_sprout_word_cap,
)


# Disable the autouse Gemini mock from the parent conftest — these tests
# never touch the LLM layer.
@pytest.fixture(autouse=True)
def _no_gemini():
    yield


def _make_story_json(pages: list[str], title: str = "A Test Adventure") -> str:
    """Build the JSON envelope that ``_safe_extract_title_and_gem`` expects."""
    return json.dumps({"title": title, "pages": [{"text": p} for p in pages]})


# ---------------------------------------------------------------------------
# MT-108: Explorer Superhero cap (350 words)
# ---------------------------------------------------------------------------
class TestExplorerSuperheroCapConstant:
    def test_explorer_cap_value_is_350(self):
        """Documented contract: Explorer Superhero target range is [250, 350];
        the post-gen cap is the upper bound."""
        assert EXPLORER_SUPERHERO_WORD_CAP == 350


class TestExplorerSuperheroUnderCap:
    def test_explorer_300_words_passes_unchanged(self):
        """A 300-word Explorer Superhero story (within range) is returned
        unchanged — no regen, no truncation."""
        body = " ".join(["word"] * 300)
        pages = [body]
        regen_fn = MagicMock(side_effect=AssertionError("regen must NOT be called"))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=7,
            theme="superhero",
            pages=pages,
            story_body=body,
            title="t",
            post_story={},
            character_name="Aria",
            base_prompt="ORIGINAL EXPLORER PROMPT",
            regen_fn=regen_fn,
            cap=EXPLORER_SUPERHERO_WORD_CAP,
            band_label="Explorer",
            age_max=8,
        )

        assert out_body == body
        assert out_pages == pages
        assert info["regen_used"] is False
        assert info["truncated"] is False
        assert info["final_words"] == 300
        regen_fn.assert_not_called()


class TestExplorerSuperheroOverCapTriggersRegen:
    def test_explorer_400_words_triggers_regen(self):
        """A 400-word Explorer Superhero story triggers regen with stricter
        prompt prefix that mentions the 350-word cap."""
        long_body = " ".join(["word"] * 400)
        pages = [long_body]

        # Regen returns a tidy 280-word story — within the 250-350 range.
        regen_pages = [" ".join(["tiny"] * 280)]
        regen_fn = MagicMock(return_value=_make_story_json(regen_pages))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=7,
            theme="superhero",
            pages=pages,
            story_body=long_body,
            title="t",
            post_story={},
            character_name="Aria",
            base_prompt="ORIGINAL EXPLORER PROMPT",
            regen_fn=regen_fn,
            cap=EXPLORER_SUPERHERO_WORD_CAP,
            band_label="Explorer",
            age_max=8,
        )

        # Regen was invoked with the stricter prompt referencing 350.
        regen_fn.assert_called_once()
        regen_prompt = regen_fn.call_args[0][0]
        assert "STRICT CONSTRAINT" in regen_prompt
        assert "400 words" in regen_prompt
        assert f"MAXIMUM is {EXPLORER_SUPERHERO_WORD_CAP}" in regen_prompt
        assert "ORIGINAL EXPLORER PROMPT" in regen_prompt

        assert info["regen_used"] is True
        assert info["truncated"] is False
        assert info["final_words"] == 280
        assert out_pages == regen_pages


class TestExplorerSuperheroRegenStillOverTruncates:
    def test_explorer_regen_still_over_falls_back_to_truncate(self):
        """If the stricter regen still exceeds 350 words, fall back to
        sentence-boundary truncation. Reuses the Sprout truncate helper."""
        long_body = " ".join(["word"] * 500)

        # Build a 400-word regen body composed of fixed-size sentences so
        # truncation has clean boundaries to cut at.
        sentence = "the brave hero stepped forward without fear at last"  # 9 words
        regen_pages = [". ".join([sentence] * 44) + "."]  # 44*9 = 396 words
        regen_fn = MagicMock(return_value=_make_story_json(regen_pages))

        out_body, _out_pages, info = _enforce_sprout_word_cap(
            age=8,
            theme="superhero",
            pages=[long_body],
            story_body=long_body,
            title="t",
            post_story={},
            character_name="Aria",
            base_prompt="ORIGINAL EXPLORER PROMPT",
            regen_fn=regen_fn,
            cap=EXPLORER_SUPERHERO_WORD_CAP,
            band_label="Explorer",
            age_max=8,
        )

        regen_fn.assert_called_once()
        assert info["regen_used"] is True
        assert info["truncated"] is True
        assert info["final_words"] <= EXPLORER_SUPERHERO_WORD_CAP
        # Truncation must yield non-empty body.
        assert out_body
        assert _count_words(out_body) <= EXPLORER_SUPERHERO_WORD_CAP


# ---------------------------------------------------------------------------
# Age-band guards: Explorer params skip ages outside [0, 8]
# ---------------------------------------------------------------------------
class TestExplorerCapAgeGuard:
    def test_age_above_max_returns_unchanged(self):
        """When called with cap=350/age_max=8, a 9-year-old story passes
        through unchanged regardless of length."""
        body = " ".join(["word"] * 800)
        pages = [body]
        regen_fn = MagicMock(side_effect=AssertionError("regen must NOT be called"))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=9,
            theme="superhero",
            pages=pages,
            story_body=body,
            title="t",
            post_story={},
            character_name="Aria",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
            cap=EXPLORER_SUPERHERO_WORD_CAP,
            band_label="Explorer",
            age_max=8,
        )

        assert out_body == body
        assert out_pages == pages
        assert info["regen_used"] is False
        assert info["truncated"] is False
        regen_fn.assert_not_called()

    def test_age_none_returns_unchanged(self):
        body = " ".join(["word"] * 500)
        pages = [body]
        regen_fn = MagicMock(side_effect=AssertionError("regen must NOT be called"))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=None,
            theme="superhero",
            pages=pages,
            story_body=body,
            title="t",
            post_story={},
            character_name="Aria",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
            cap=EXPLORER_SUPERHERO_WORD_CAP,
            band_label="Explorer",
            age_max=8,
        )
        assert out_body == body
        assert out_pages == pages
        assert info["regen_used"] is False
        regen_fn.assert_not_called()


# ---------------------------------------------------------------------------
# Regression: Sprout default behavior unchanged after refactor
# ---------------------------------------------------------------------------
class TestSproutDefaultsRegression:
    def test_sprout_defaults_still_use_150_cap(self):
        """After the cap kwarg refactor, the default call path must still
        use SPROUT_WORD_CAP=150 and trigger regen on a 200-word Sprout story."""
        long_body = " ".join(["word"] * 200)
        pages = [long_body]
        short_pages = [" ".join(["tiny"] * 100)]
        regen_fn = MagicMock(return_value=_make_story_json(short_pages))

        _out_body, out_pages, info = _enforce_sprout_word_cap(
            age=5,
            theme="superhero",
            pages=pages,
            story_body=long_body,
            title="t",
            post_story={},
            character_name="Mia",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
        )

        regen_fn.assert_called_once()
        regen_prompt = regen_fn.call_args[0][0]
        assert f"MAXIMUM is {SPROUT_WORD_CAP}" in regen_prompt
        assert info["regen_used"] is True
        assert info["final_words"] == 100
        assert out_pages == short_pages

    def test_sprout_age_6_with_default_cap_passes_unchanged(self):
        """Default age_max=5 means age=6 skips Sprout enforcement entirely."""
        body = " ".join(["word"] * 500)
        pages = [body]
        regen_fn = MagicMock(side_effect=AssertionError("regen must NOT be called"))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=6,
            theme="superhero",
            pages=pages,
            story_body=body,
            title="t",
            post_story={},
            character_name="Mia",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
        )
        assert out_body == body
        assert out_pages == pages
        assert info["regen_used"] is False
        regen_fn.assert_not_called()
