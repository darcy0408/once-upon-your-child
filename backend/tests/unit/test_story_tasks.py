"""Unit tests for ``backend.tasks.story_tasks`` post-generation word caps
and the word-range unification (canonical floor/cap + retry-suffix rebuild).

Covers MT-108 (the Explorer 6-8 Superhero belt reusing the Sprout
retry+truncate helper) plus the unified-word-range behaviors: caps now come
from ``backend.services.word_ranges.get_word_range`` (20% headroom over the
prompt's stated target), bedtime/duration stories are exempt from the Sprout
belt, truncation preserves pagination, and retry feedback replaces (never
accumulates onto) the previous attempt's feedback.
"""

from __future__ import annotations

import json
from unittest.mock import MagicMock

import pytest

from backend.services.word_ranges import get_word_range
from backend.tasks.story_tasks import (
    _count_words,
    _enforce_sprout_word_cap,
    generate_story_task,
)

# Canonical caps (derived — see word_ranges.py; the old hardcoded
# SPROUT_WORD_CAP=150 / EXPLORER_SUPERHERO_WORD_CAP=350 constants are gone).
EXPLORER_SH_CAP = get_word_range(age=7, mode="superhero").cap
SPROUT_SH_CAP = get_word_range(age=5, mode="superhero").cap


# Disable the autouse Gemini mock from the parent conftest — these tests
# never touch the LLM layer.
@pytest.fixture(autouse=True)
def _no_gemini():
    yield


def _make_story_json(pages: list[str], title: str = "A Test Adventure") -> str:
    """Build the JSON envelope that ``_safe_extract_title_and_gem`` expects."""
    return json.dumps({"title": title, "pages": [{"text": p} for p in pages]})


# ---------------------------------------------------------------------------
# Canonical cap values
# ---------------------------------------------------------------------------
class TestCanonicalCapValues:
    def test_explorer_cap_derives_from_prompt_target(self):
        """Explorer Superhero prompt targets [250, 350]; the post-gen cap is
        20% headroom above the upper bound — a story a hair over 350 no
        longer gets truncated, only real overshoots do."""
        assert EXPLORER_SH_CAP == int(350 * 1.2)

    def test_sprout_superhero_cap_derives_from_prompt_target(self):
        """Sprout Superhero prompt targets [100, 130] ("MAXIMUM 130 words
        TOTAL"); cap = 20% headroom above 130."""
        assert SPROUT_SH_CAP == int(130 * 1.2)


# ---------------------------------------------------------------------------
# MT-108: Explorer Superhero cap
# ---------------------------------------------------------------------------
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
            cap=EXPLORER_SH_CAP,
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
    def test_explorer_500_words_triggers_regen(self):
        """A 500-word Explorer Superhero story (past the 420 cap) triggers
        regen with a stricter prompt prefix that names the canonical cap."""
        long_body = " ".join(["word"] * 500)
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
            cap=EXPLORER_SH_CAP,
            band_label="Explorer",
            age_max=8,
        )

        # Regen was invoked with the stricter prompt referencing the cap.
        regen_fn.assert_called_once()
        regen_prompt = regen_fn.call_args[0][0]
        assert "STRICT CONSTRAINT" in regen_prompt
        assert "500 words" in regen_prompt
        assert f"MAXIMUM is {EXPLORER_SH_CAP}" in regen_prompt
        assert "ORIGINAL EXPLORER PROMPT" in regen_prompt

        assert info["regen_used"] is True
        assert info["truncated"] is False
        assert info["final_words"] == 280
        assert out_pages == regen_pages

    def test_explorer_at_cap_is_not_touched(self):
        """Boundary: exactly cap words -> no regen (the old code capped at
        exactly 350, rejecting the prompt-legal 'slightly over' zone)."""
        body = " ".join(["word"] * EXPLORER_SH_CAP)
        regen_fn = MagicMock(side_effect=AssertionError("regen must NOT be called"))

        out_body, _pages, info = _enforce_sprout_word_cap(
            age=7,
            theme="superhero",
            pages=[body],
            story_body=body,
            title="t",
            post_story={},
            character_name="Aria",
            base_prompt="P",
            regen_fn=regen_fn,
            cap=EXPLORER_SH_CAP,
            band_label="Explorer",
            age_max=8,
        )
        assert out_body == body
        assert info["truncated"] is False
        regen_fn.assert_not_called()


class TestExplorerSuperheroRegenStillOverTruncates:
    def test_explorer_regen_still_over_falls_back_to_truncate(self):
        """If the stricter regen still exceeds the cap, fall back to
        page/sentence-boundary truncation."""
        long_body = " ".join(["word"] * 600)

        # Build a ~450-word regen body composed of fixed-size sentences so
        # truncation has clean boundaries to cut at (450 > 420 cap).
        sentence = "the brave hero stepped forward without fear at last"  # 9 words
        regen_pages = [". ".join([sentence] * 50) + "."]  # 50*9 = 450 words
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
            cap=EXPLORER_SH_CAP,
            band_label="Explorer",
            age_max=8,
        )

        regen_fn.assert_called_once()
        assert info["regen_used"] is True
        assert info["truncated"] is True
        assert info["final_words"] <= EXPLORER_SH_CAP
        # Truncation must yield non-empty body.
        assert out_body
        assert _count_words(out_body) <= EXPLORER_SH_CAP


# ---------------------------------------------------------------------------
# Truncation preserves pagination (regression: the old helper collapsed the
# whole story into ONE page)
# ---------------------------------------------------------------------------
class TestTruncationPreservesPages:
    def test_truncation_keeps_multiple_pages(self):
        # 10 pages x 30 words = 300 words, cap 156 -> keep ~5 pages.
        page = " ".join(["word"] * 30)
        pages = [page] * 10
        body = "\n\n".join(pages)
        # Regen returns the same over-cap story so we land in stage 2.
        regen_fn = MagicMock(return_value=_make_story_json(pages))

        out_body, out_pages, info = _enforce_sprout_word_cap(
            age=4,
            theme="superhero",
            pages=pages,
            story_body=body,
            title="t",
            post_story={},
            character_name="Mia",
            base_prompt="P",
            regen_fn=regen_fn,
            cap=SPROUT_SH_CAP,
        )

        assert info["truncated"] is True
        assert len(out_pages) > 1  # never collapsed to a single page
        assert info["final_words"] <= SPROUT_SH_CAP
        assert out_body == "\n\n".join(out_pages)


# ---------------------------------------------------------------------------
# Age-band guards: Explorer params skip ages outside [0, 8]
# ---------------------------------------------------------------------------
class TestExplorerCapAgeGuard:
    def test_age_above_max_returns_unchanged(self):
        """When called with age_max=8, a 9-year-old story passes through
        unchanged regardless of length."""
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
            cap=EXPLORER_SH_CAP,
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
            cap=EXPLORER_SH_CAP,
            band_label="Explorer",
            age_max=8,
        )
        assert out_body == body
        assert out_pages == pages
        assert info["regen_used"] is False
        regen_fn.assert_not_called()


# ---------------------------------------------------------------------------
# Sprout belt regression (canonical superhero cap)
# ---------------------------------------------------------------------------
class TestSproutBeltRegression:
    def test_sprout_superhero_200_words_triggers_regen(self):
        """A 200-word Sprout Superhero story exceeds the canonical 156-word
        cap and triggers the stricter regen."""
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
            cap=SPROUT_SH_CAP,
        )

        regen_fn.assert_called_once()
        regen_prompt = regen_fn.call_args[0][0]
        assert f"MAXIMUM is {SPROUT_SH_CAP}" in regen_prompt
        assert info["regen_used"] is True
        assert info["final_words"] == 100
        assert out_pages == short_pages

    def test_sprout_age_6_with_default_age_max_passes_unchanged(self):
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
            cap=SPROUT_SH_CAP,
        )
        assert out_body == body
        assert out_pages == pages
        assert info["regen_used"] is False
        regen_fn.assert_not_called()


class TestRefusalSentinel:
    """The refusal sentinel must keep matching every provider's fallback string.

    story_tasks routes a story body containing ``_REFUSAL_SENTINEL`` into the
    safe-fallback regeneration (a provider safety refusal must never persist
    as the child's story). If a provider's ``_SAFETY_FALLBACK`` wording drifts
    away from the sentinel, that protection silently dies -- this test pins
    them together.
    """

    def test_sentinel_matches_all_provider_fallbacks(self):
        from backend.services import (
            anthropic_story_generator,
            openai_story_generator,
            openrouter_story_generator,
            story_generation_service,
        )
        from backend.tasks.story_tasks import _REFUSAL_SENTINEL

        for mod in (
            anthropic_story_generator,
            openai_story_generator,
            openrouter_story_generator,
            story_generation_service,
        ):
            fallback = mod._SAFETY_FALLBACK
            assert _REFUSAL_SENTINEL in fallback[:160], mod.__name__


# ---------------------------------------------------------------------------
# Full-task scenarios for the unified word ranges. Mirrors the mock recipe of
# tests/unit/test_superhero_meta_validation.py (no LLM, no external services).
# ---------------------------------------------------------------------------
def _patch_task_env(app, mocker):
    mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)
    mocker.patch(
        "backend.tasks.story_tasks.pseudonymize_hero_name",
        side_effect=lambda real_name, *a, **k: real_name or "Hero",
    )
    mocker.patch(
        "backend.utils.content_moderator.moderate_story_content",
        return_value=(True, ""),
    )


def _sentences_page(n_words: int, name: str | None = None) -> str:
    """A page of `n_words` words made of 10-word sentences (clean sentence
    boundaries for the truncation helper), optionally naming the hero."""
    sentence = "the kind hero walked on through the quiet bright morning"  # 10 words
    parts = []
    if name:
        parts.append(f"{name} smiled at the soft golden sky far above them")  # 10 words
        n_words -= 10
    parts.extend([sentence] * (n_words // 10))
    return ". ".join(parts) + "."


class TestUnifiedValidationScenarios:
    def test_explorer_superhero_300_words_passes_first_attempt(self, app, mocker):
        """Audit (a) end-to-end: a 300-word Explorer Superhero story passes
        validation on attempt 1 — no retry burn, no truncation."""
        _patch_task_env(app, mocker)
        pages = [
            _sentences_page(60, name="Riley" if i == 0 else None) for i in range(5)
        ]
        gen = mocker.patch(
            "backend.tasks.story_tasks._generate_story_text_with_metadata",
            return_value=(_make_story_json(pages), "mock", ["mock"]),
        )

        result = generate_story_task.apply(
            kwargs={
                "character": "Riley",
                "theme": "superhero",
                "user_id": "anonymous",
                "age": 7,
                "hero_power": "super_smile",
            }
        ).get()

        assert result["status"] == "complete", result
        assert gen.call_count == 1  # passed validation on the first attempt
        out_pages = result["story"]["pages"]
        assert sum(len(p.split()) for p in out_pages) == 300  # untouched

    def test_sprout_bedtime_350_words_not_capped(self, app, mocker):
        """Audit (b) end-to-end: a 350-word Sprout bedtime story is exempt
        from the Sprout belt (bedtime targets 260-380) — one attempt, all
        pages preserved, nothing truncated."""
        _patch_task_env(app, mocker)
        pages = [
            _sentences_page(50, name="Riley" if i == 0 else None) for i in range(7)
        ]
        gen = mocker.patch(
            "backend.tasks.story_tasks._generate_story_text_with_metadata",
            return_value=(_make_story_json(pages), "mock", ["mock"]),
        )

        result = generate_story_task.apply(
            kwargs={
                "character": "Riley",
                "theme": "Adventure",
                "user_id": "anonymous",
                "age": 4,
                "bedtime_mode": True,
            }
        ).get()

        assert result["status"] == "complete", result
        assert gen.call_count == 1
        out_pages = result["story"]["pages"]
        assert len(out_pages) == 7  # pagination intact
        assert sum(len(p.split()) for p in out_pages) == 350  # not truncated

    def test_age9_bedtime_800_words_passes_first_attempt(self, app, mocker):
        """Audit (d) end-to-end: bedtime 8-10 targets 650-900; an 800-word
        story must pass on attempt 1 (old floor demanded 1100)."""
        _patch_task_env(app, mocker)
        pages = [
            _sentences_page(200, name="Riley" if i == 0 else None) for i in range(4)
        ]
        gen = mocker.patch(
            "backend.tasks.story_tasks._generate_story_text_with_metadata",
            return_value=(_make_story_json(pages), "mock", ["mock"]),
        )

        result = generate_story_task.apply(
            kwargs={
                "character": "Riley",
                "theme": "Adventure",
                "user_id": "anonymous",
                "age": 9,
                "bedtime_mode": True,
            }
        ).get()

        assert result["status"] == "complete", result
        assert gen.call_count == 1

    def test_retry_suffix_replaces_instead_of_accumulating(self, app, mocker):
        """Audit (f) end-to-end: a too-short story fails validation on every
        attempt; the SECOND retry prompt must contain the retry feedback
        exactly once (rebuilt from the pristine base), not stacked twice."""
        _patch_task_env(app, mocker)
        # ~100 words: far below the age-7 standard floor (~487) on all tries.
        pages = [_sentences_page(100, name="Riley")]
        gen = mocker.patch(
            "backend.tasks.story_tasks._generate_story_text_with_metadata",
            return_value=(_make_story_json(pages), "mock", ["mock"]),
        )

        result = generate_story_task.apply(
            kwargs={
                "character": "Riley",
                "theme": "Adventure",
                "user_id": "anonymous",
                "age": 7,
                "user_tier": "premium",  # 3 attempts
                "story_length": "standard",
            }
        ).get()

        assert result["status"] == "complete", result  # best-effort ship
        assert gen.call_count == 3
        prompts = [call.args[0] for call in gen.call_args_list]
        assert prompts[0].count("RETRY INSTRUCTION") == 0
        assert prompts[1].count("RETRY INSTRUCTION") == 1
        # The old bug: attempt 3's prompt carried attempt 2's suffix AND a
        # new one. It must carry exactly one, rebuilt on the base prompt.
        assert prompts[2].count("RETRY INSTRUCTION") == 1
        assert prompts[2].startswith(prompts[0])
