"""Tests for the optional hero catchphrase (Chunk B3) threaded into the
Explorer (6-8) and Adventurer (9-12) superhero prompt builders.

Contract:
  * When a catchphrase IS supplied, it appears in the prompt and the prompt
    instructs the hero to say it at the climax (word-for-word, in quotes).
  * When NO catchphrase is supplied, the prompt is unchanged (no catchphrase
    scaffolding leaks in) — back-compat / no-op.

Pure prompt-module tests: no Gemini, Flask, or DB.
"""

from __future__ import annotations

import pytest

from backend.services.prompt_service import PromptService

_PHRASE = "Never miss a beat!"


# ---------------------------------------------------------------------------
# Adventurer band.
# ---------------------------------------------------------------------------
def test_adventurer_prompt_includes_catchphrase_when_supplied():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="lightning",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="outsmart_the_trap",
        hero_catchphrase=_PHRASE,
    )
    assert _PHRASE in prompt
    lowered = prompt.lower()
    assert "catchphrase" in lowered
    # The model is instructed to have the hero SAY it.
    assert "must say their catchphrase" in lowered


def test_adventurer_prompt_omits_catchphrase_scaffolding_when_absent():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="lightning",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="outsmart_the_trap",
        hero_catchphrase=None,
    )
    assert "Catchphrase:" not in prompt
    assert "must say their catchphrase" not in prompt.lower()


@pytest.mark.parametrize("blank", ["", "   ", None])
def test_adventurer_blank_catchphrase_is_noop(blank):
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="lightning",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="outsmart_the_trap",
        hero_catchphrase=blank,
    )
    assert "Catchphrase:" not in prompt


# ---------------------------------------------------------------------------
# Explorer band.
# ---------------------------------------------------------------------------
def test_explorer_prompt_includes_catchphrase_when_supplied():
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Sam",
        age=7,
        hero_costume_color="blue",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_speed",
        villain_id=None,
        problem_id=None,
        hero_catchphrase=_PHRASE,
    )
    assert _PHRASE in prompt
    assert "must say their catchphrase" in prompt.lower()


def test_explorer_prompt_omits_catchphrase_when_absent():
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Sam",
        age=7,
        hero_costume_color="blue",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_speed",
        villain_id=None,
        problem_id=None,
    )
    assert "Catchphrase:" not in prompt
    assert "must say their catchphrase" not in prompt.lower()


# ---------------------------------------------------------------------------
# Routing through build_story_prompt (the public entry point).
# ---------------------------------------------------------------------------
def test_build_story_prompt_threads_catchphrase_to_adventurer():
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=11,
        hero_power="super_smile",
        hero_catchphrase=_PHRASE,
    )
    assert "Adventurer band" in prompt
    assert _PHRASE in prompt


def test_build_story_prompt_threads_catchphrase_to_explorer():
    prompt = PromptService.build_story_prompt(
        character="Sam",
        theme="superhero",
        age=7,
        hero_power="super_smile",
        hero_catchphrase=_PHRASE,
    )
    assert "Explorer band" in prompt
    assert _PHRASE in prompt


def test_build_story_prompt_without_catchphrase_unchanged():
    """REGRESSION GUARD — absent catchphrase leaves the prompt clean."""
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=11,
        hero_power="super_smile",
    )
    assert "Catchphrase:" not in prompt
    assert "must say their catchphrase" not in prompt.lower()
