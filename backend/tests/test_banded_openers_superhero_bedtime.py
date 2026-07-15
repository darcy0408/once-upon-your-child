"""Banded story openers — Sprout/Explorer superhero builders + bedtime path.

Chunk 2 of the #437 banded-opener feature. #437 gave the *standard* prompt
path (``AdvancedStoryEngine.generate_enhanced_prompt``) a per-band opening
rule: Sprout (≤5) always opens with the ritual "Once upon a time,"; Explorer
(6-8) rotates a classic opener; 9+ keeps the anti-sameness FRESH OPENING rule.

These tests pin the same behaviour in the three builders #437 did NOT touch:

  * ``PromptService._build_superhero_prompt``          (Sprout superhero)
  * ``PromptService._build_superhero_prompt_explorer`` (Explorer superhero)
  * ``story_service._build_bedtime_prompt``            (all-ages bedtime)

Bedtime is deliberately asymmetric: the young bands get the ritual/classic
opener, but 9+ gets NONE — the standard FRESH OPENING rule ("begin in motion,
mid-problem, in dialogue") fights bedtime's soothing pacing, so older bedtime
stories keep their calm, unconstrained open.

Pure prompt-string assertions — no Gemini/OpenAI, no Flask, no DB.
"""

from __future__ import annotations

from backend.services.prompt_service import PromptService
from backend.services.story_service import (
    _EXPLORER_OPENER_ROTATION,
    _build_bedtime_prompt,
)

_OPENING_MARKER = "STORY OPENING (MANDATORY)"
_FRESH_MARKER = "FRESH OPENING"


# ---------------------------------------------------------------------------
# Sprout superhero builder — the ritual opener is unconditional at ≤5.
# ---------------------------------------------------------------------------
def test_sprout_superhero_mandates_once_upon_a_time():
    prompt = PromptService._build_superhero_prompt(
        character="Ellie",
        age=4,
        hero_costume_color="blue",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_smile",
        villain_id=None,
        problem_id=None,
    )
    # The mandatory opening rule is present and names the exact ritual phrase.
    assert _OPENING_MARKER in prompt
    assert 'exactly "Once upon a time,"' in prompt
    # The HERO INTRO beat example is consistent with the rule (no split-brain
    # "open with X" vs "first words must be Y").
    assert "Once upon a time, Ellie put on the" in prompt
    # The Sprout band never gets the older bands' anti-sameness rule.
    assert _FRESH_MARKER not in prompt


def test_sprout_superhero_opener_routes_through_build_story_prompt():
    """The public entry point routes a 4-year-old superhero request to the
    Sprout builder, so the ritual opener survives the real call path."""
    prompt = PromptService.build_story_prompt(
        character="Sam",
        theme="superhero",
        age=4,
        hero_power="super_smile",
    )
    assert 'exactly "Once upon a time,"' in prompt


# ---------------------------------------------------------------------------
# Explorer superhero builder — a rotated classic opener, enforced as a rule.
# ---------------------------------------------------------------------------
def test_explorer_superhero_mandates_a_rotation_opener():
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Maya",
        age=7,
        hero_costume_color="red",
        hero_cape_style="matching",
        hero_emblem="bolt",
        hero_power="super_speed",
        villain_id=None,
        problem_id=None,
    )
    assert _OPENING_MARKER in prompt
    # Exactly one of the canonical rotation openers is mandated, verbatim.
    assert any(
        f'exactly "{opener},"' in prompt for opener in _EXPLORER_OPENER_ROTATION
    ), "Explorer superhero prompt did not mandate any rotation opener"
    # Explorer is a young band — it must not inherit the 9+ FRESH OPENING rule.
    assert _FRESH_MARKER not in prompt


# ---------------------------------------------------------------------------
# Bedtime builder — ritual/classic opener for young bands, nothing for 9+.
# ---------------------------------------------------------------------------
def test_bedtime_sprout_opens_once_upon_a_time():
    prompt = _build_bedtime_prompt(character_name="Mia", age=4, theme="forest")
    assert _OPENING_MARKER in prompt
    assert 'exactly "Once upon a time,"' in prompt


def test_bedtime_explorer_gets_a_rotation_opener():
    prompt = _build_bedtime_prompt(character_name="Theo", age=7, theme="ocean")
    assert _OPENING_MARKER in prompt
    assert any(f'exactly "{opener},"' in prompt for opener in _EXPLORER_OPENER_ROTATION)


def test_bedtime_older_bands_get_no_opening_rule():
    """9+ bedtime keeps its calm open: no ritual opener, and crucially NOT the
    standard FRESH OPENING rule, which would fight bedtime's soothing pacing."""
    for age in (9, 12, 16, 30):
        prompt = _build_bedtime_prompt(
            character_name="Robin", age=age, theme="mountain"
        )
        assert _OPENING_MARKER not in prompt, f"age {age} unexpectedly got opener"
        assert _FRESH_MARKER not in prompt, f"age {age} got FRESH OPENING at bedtime"
