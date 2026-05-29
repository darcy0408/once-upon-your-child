"""Tests for Sprout (ages 3-5) post-generation word-cap enforcement.

The Sprout prompt instructs Gemini to stop at 130 words, but the model
overshoots. These tests cover the two-stage safety belt in
``backend.tasks.story_tasks._enforce_sprout_word_cap``:

  1. Regenerate once with a stricter prompt prefix.
  2. If regen is still over, truncate at the last sentence boundary that
     fits under 150 words, always preserving the cheer beat.

We mock the regen function so no real LLM calls are made.
"""

from __future__ import annotations

import json
from unittest.mock import MagicMock

from backend.services.prompt_service import PromptService
from backend.tasks.story_tasks import (
    SPROUT_WORD_CAP,
    _count_words,
    _enforce_sprout_word_cap,
    _has_cheer_beat,
    _truncate_to_word_cap,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _make_story_json(pages: list[str], title: str = "A Test Adventure") -> str:
    """Build the JSON envelope that ``_safe_extract_title_and_gem`` expects."""
    return json.dumps({"title": title, "pages": [{"text": p} for p in pages]})


def _words_n(text: str, n: int) -> str:
    """Build a body of exactly n words, ending with the cheer beat."""
    base = ("word " * n).strip()
    return base + ". Everyone cheered. Mia saved the day!"


# ---------------------------------------------------------------------------
# Stage-0: under cap → unchanged
# ---------------------------------------------------------------------------
class TestSproutUnderCap:
    def test_sprout_word_count_under_cap_passes(self):
        """A 100-word Sprout story is returned unchanged (no regen, no truncate)."""
        body = " ".join(["word"] * 100)
        pages = [body]
        regen_fn = MagicMock(side_effect=AssertionError("regen must NOT be called"))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=4,
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
        assert info["truncated"] is False
        assert info["final_words"] == 100
        regen_fn.assert_not_called()


# ---------------------------------------------------------------------------
# Stage-1: over cap → regen with stricter prompt
# ---------------------------------------------------------------------------
class TestSproutRegen:
    def test_sprout_word_count_over_cap_triggers_regen(self):
        """A 200-word Sprout story triggers regen with a stricter prompt prefix."""
        long_body = " ".join(["word"] * 200)
        pages = [long_body]

        # Regen returns a tidy 90-word story — well under the cap.
        short_pages = [" ".join(["tiny"] * 90)]
        regen_fn = MagicMock(return_value=_make_story_json(short_pages))

        out_body, out_pages, info = _enforce_sprout_word_cap(
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

        # Regen was invoked exactly once.
        regen_fn.assert_called_once()
        regen_prompt = regen_fn.call_args[0][0]
        assert "STRICT CONSTRAINT" in regen_prompt
        assert "200 words" in regen_prompt
        assert f"MAXIMUM is {SPROUT_WORD_CAP}" in regen_prompt
        assert "ORIGINAL PROMPT" in regen_prompt

        # Output reflects the regen result, not truncation.
        assert info["regen_used"] is True
        assert info["truncated"] is False
        assert info["final_words"] == 90
        assert out_pages == short_pages

    def test_sprout_word_count_still_over_after_regen_truncates(self):
        """If regen is still over (180 words), we truncate at sentence boundary ≤150."""
        long_body = " ".join(["word"] * 200)
        pages = [long_body]

        # Build a 180-word regen body composed of fixed-size sentences.
        # 30 sentences × 6 words each = 180 words, each ending with ". ".
        sentence = "the quiet hero walked very far"  # 6 words
        regen_pages = [
            ". ".join([sentence] * 30) + ". Everyone cheered. Mia saved the day!"
        ]
        # That cheer beat tail itself contains additional words — keep total > 150.
        regen_fn = MagicMock(return_value=_make_story_json(regen_pages))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=4,
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
        assert info["regen_used"] is True
        assert info["truncated"] is True
        assert info["final_words"] <= SPROUT_WORD_CAP
        # Cheer beat must remain after truncation.
        assert _has_cheer_beat(out_body)

    def test_sprout_cheer_beat_appended_if_cut(self):
        """When truncation drops the cheer line, it is re-appended with the hero name."""
        # Construct a body where the cheer beat is the last sentence and the
        # body is too long to fit it; truncation should re-append a generic one.
        # 200 words of plain sentences, then the cheer beat at the very end.
        sentence = "the hero walked very far again"  # 6 words
        body = ". ".join([sentence] * 35) + ". Everyone cheered. Mia saved the day!"
        # Force truncation only (no regen): regen returns the SAME body so we
        # land in stage 2.
        regen_fn = MagicMock(return_value=_make_story_json([body]))

        out_body, _out_pages, info = _enforce_sprout_word_cap(
            age=3,
            theme="superhero",
            pages=[body],
            story_body=body,
            title="t",
            post_story={},
            character_name="Mia",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
        )

        assert info["truncated"] is True
        assert _has_cheer_beat(out_body)
        assert "Mia saved the day!" in out_body
        # Even with the appended cheer suffix, we should be at or under cap.
        # (Truncation reserves words for the cheer beat in advance.)
        assert _count_words(out_body) <= SPROUT_WORD_CAP


# ---------------------------------------------------------------------------
# Non-Sprout: no cap enforced
# ---------------------------------------------------------------------------
class TestNonSprout:
    def test_non_sprout_no_cap_enforced(self):
        """An age-8 story of 400 words is returned unchanged."""
        body = " ".join(["word"] * 400)
        pages = [body]
        regen_fn = MagicMock(side_effect=AssertionError("regen must NOT be called"))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=8,
            theme="adventure",
            pages=pages,
            story_body=body,
            title="t",
            post_story={},
            character_name="Leo",
            base_prompt="ORIGINAL PROMPT",
            regen_fn=regen_fn,
        )

        assert out_body == body
        assert out_pages == pages
        assert info["regen_used"] is False
        assert info["truncated"] is False
        assert info["final_words"] == 400
        regen_fn.assert_not_called()


# ---------------------------------------------------------------------------
# Theme coverage: superhero path also goes through enforcement
# ---------------------------------------------------------------------------
class TestSuperheroThemeEnforced:
    def test_superhero_theme_word_count_enforced(self):
        """Superhero theme on Sprout still triggers regen on overshoot."""
        long_body = " ".join(["word"] * 220)
        regen_pages = [" ".join(["tiny"] * 100)]
        regen_fn = MagicMock(return_value=_make_story_json(regen_pages))

        _out_body, _out_pages, info = _enforce_sprout_word_cap(
            age=4,
            theme="superhero",  # superhero theme specifically
            pages=[long_body],
            story_body=long_body,
            title="t",
            post_story={},
            character_name="Mia",
            base_prompt="ORIGINAL SUPERHERO PROMPT",
            regen_fn=regen_fn,
        )

        regen_fn.assert_called_once()
        assert info["regen_used"] is True
        assert info["final_words"] == 100
        assert info["theme"] == "superhero"


# ---------------------------------------------------------------------------
# Direct truncate-helper coverage
# ---------------------------------------------------------------------------
class TestTruncateHelper:
    def test_truncate_keeps_under_cap(self):
        body = ". ".join(["a b c d e f"] * 30) + "."  # 180 words
        out = _truncate_to_word_cap(body, 150, "Mia")
        assert _count_words(out) <= 150

    def test_truncate_preserves_cheer_when_present(self):
        body = (
            ". ".join(["a b c d e f"] * 30) + ". Everyone cheered. Mia saved the day!"
        )
        out = _truncate_to_word_cap(body, 150, "Mia")
        assert _has_cheer_beat(out)
        assert _count_words(out) <= 150

    def test_truncate_does_not_append_cheer_if_original_lacked_one(self):
        body = ". ".join(["a b c d e f"] * 30) + "."  # no cheer beat
        out = _truncate_to_word_cap(body, 150, "Mia")
        # We never invent a cheer beat for stories that didn't have one.
        assert not _has_cheer_beat(out)


# ---------------------------------------------------------------------------
# Superhero prompts must emit the same metadata schema as the standard prompt
# (themes / characters_featured / emotional_arc) so Superhero stories don't
# silently persist _EMPTY_METADATA. Regression for the gap left by 2706b347
# which only patched the 5 templates inside story_service.py.
# ---------------------------------------------------------------------------
class TestSuperheroPromptEmitsMetadataSchema:
    def test_sprout_superhero_prompt_includes_metadata_keys(self):
        prompt = PromptService.build_story_prompt(
            character="Mia",
            theme="superhero",
            age=4,
            hero_costume_color="purple",
            hero_cape_style="matching",
            hero_emblem="star",
            hero_power="super_smile",
        )
        assert '"themes":' in prompt
        assert '"characters_featured":' in prompt
        assert '"emotional_arc":' in prompt

    def test_explorer_superhero_prompt_includes_metadata_keys(self):
        prompt = PromptService.build_story_prompt(
            character="Leo",
            theme="superhero",
            age=7,
            hero_costume_color="blue",
            hero_cape_style="matching",
            hero_emblem="lightning",
            hero_power="super_speed",
        )
        assert '"themes":' in prompt
        assert '"characters_featured":' in prompt
        assert '"emotional_arc":' in prompt
