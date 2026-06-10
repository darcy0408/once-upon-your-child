"""Unit tests for the Adolescent-band (ages 15-17) antihero "double life" prompt.

Exercises ``PromptService._build_superhero_prompt_adolescent`` (T10) and the
age-based routing in ``PromptService.build_story_prompt``. The Adolescent tier
uses its own dedicated "Edge" matrix (social/identity-scale antagonists; powers
with a built-in cost). Pure prompt module — no Gemini, Flask, or DB.
"""

from __future__ import annotations

import pytest

from backend.data.superhero_matrix import (
    ADOLESCENT_PROBLEMS,
    ADOLESCENT_VILLAINS,
)
from backend.services.prompt_service import PromptService


def _build(**overrides):
    base = dict(
        character="Maya",
        age=16,
        hero_costume_color="charcoal",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="the_double",
        problem_id="expose_the_setup",
    )
    base.update(overrides)
    return PromptService._build_superhero_prompt_adolescent(**base)


def test_adolescent_prompt_is_double_life_register():
    prompt = _build()
    assert "DOUBLE LIFE" in prompt
    assert "CONCEALMENT" in prompt
    assert "Adolescent band" in prompt
    assert prompt.count("Maya") >= 4


def test_adolescent_prompt_uses_edge_power_names_not_creator():
    # strategist renders as the Adolescent Edge "The Tell", NOT Creator's
    # "Mastermind" — proving the dedicated matrix is wired in.
    prompt = _build(hero_power="strategist")
    assert "The Tell" in prompt
    assert "Mastermind" not in prompt


def test_adolescent_prompt_includes_villain_name_and_problem_verb():
    prompt = _build(
        character="Leo",
        hero_power="super_hearing",
        villain_id="echo",
        problem_id="clear_the_framed",
    )
    assert "Echo" in prompt
    assert "prove the innocence of" in prompt  # clear_the_framed verb


def test_adolescent_prompt_weaves_in_custom_elements():
    idea = "pull off a daring heist"
    direct = _build(hero_power="gadgeteer", custom_elements=idea)
    assert f"[USER_INPUT]{idea}[/USER_INPUT]" in direct
    routed = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=16,
        hero_power="gadgeteer",
        custom_elements=idea,
    )
    assert f"[USER_INPUT]{idea}[/USER_INPUT]" in routed


def test_adolescent_prompt_omits_custom_block_when_empty():
    prompt = _build(custom_elements="")
    assert "THEIR OWN STORY IDEA" not in prompt
    assert "[USER_INPUT]" not in prompt


def test_adolescent_prompt_forbids_violence_and_allows_boundaries():
    prompt = _build(
        hero_power="super_strength",
        villain_id="the_warden",
        problem_id="defuse_the_pileon",
    )
    assert "NO weapons" in prompt
    lowered = prompt.lower()
    assert "non-violent" in lowered
    assert "boundaries" in lowered or "boundary" in lowered
    assert "accountability" in lowered


def test_adolescent_prompt_morally_grey_is_not_cruelty():
    """The guardrail that keeps 'antihero' age-appropriate, not edgelord."""
    prompt = _build()
    lowered = prompt.lower()
    assert "morally grey" in lowered or "morally-grey" in lowered
    assert "not cruelty" in lowered
    assert "worth rooting for" in lowered


def test_adolescent_prompt_does_not_require_universal_redemption():
    prompt = _build(
        hero_power="super_smile",
        villain_id="the_patron",
        problem_id="win_back_trust",
    )
    lowered = prompt.lower()
    assert "responsible for" in lowered
    assert "instant forgiveness" in lowered


def test_adolescent_prompt_requires_mystery_and_real_choice_and_cost():
    prompt = _build(
        hero_power="super_hearing",
        villain_id="the_archivist",
        problem_id="expose_the_setup",
    )
    lowered = prompt.lower()
    assert "mystery" in lowered
    assert "choice" in lowered
    assert "limit" in lowered or "cost" in lowered


def test_adolescent_prompt_pins_canonical_villain_roster():
    prompt = _build(
        hero_power="gadgeteer",
        villain_id="the_archivist",
        problem_id="expose_the_setup",
    )
    for v in ADOLESCENT_VILLAINS.values():
        assert v["name"] in prompt, f"Canonical villain '{v['name']}' missing"
    assert "must be ONE of these named figures" in prompt


def test_adolescent_prompt_emits_continuity_saga_state():
    prompt = _build()
    assert "saga_state" in prompt
    assert "nemesis_status" in prompt
    assert "next_hook" in prompt


def test_adolescent_prompt_has_1400_2200_word_budget():
    prompt = _build(
        hero_power="super_hearing",
        villain_id="ledger",
        problem_id="surface_the_truth",
    )
    assert "1400" in prompt and "2200" in prompt


def test_adolescent_prompt_falls_back_on_missing_or_unknown_power():
    for bad in (None, "super_potato"):
        prompt = _build(hero_power=bad, villain_id=None, problem_id=None)
        assert isinstance(prompt, str) and len(prompt) > 0
        # super_smile in the Adolescent Edge matrix displays as "Pull".
        assert "Pull" in prompt


# --- Age-based routing ------------------------------------------------------
@pytest.mark.parametrize("age", [15, 16, 17])
def test_build_story_prompt_routes_adolescent_ages(age):
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=age,
        hero_power="super_smile",
    )
    assert "Adolescent band" in prompt, f"age={age} did not route to Adolescent"
    assert "DOUBLE LIFE" in prompt
    assert "Creator band" not in prompt
    assert "Sprout band" not in prompt


def test_build_story_prompt_age_14_still_creator_not_adolescent():
    """REGRESSION GUARD — age 14 is Creator; Adolescent starts at 15."""
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=14,
        hero_power="super_smile",
    )
    assert "Creator band" in prompt
    assert "DOUBLE LIFE" not in prompt


def test_build_story_prompt_age_18_not_adolescent():
    """Adult (18+) has no antihero tier — falls back, must not hit Adolescent."""
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=18,
        hero_power="super_smile",
    )
    assert "DOUBLE LIFE" not in prompt


# --- Returnable saga continuity --------------------------------------------
def test_adolescent_chapter_one_has_no_continuity_block():
    prompt = _build(prior_saga=None)
    assert "CONTINUITY" not in prompt
    assert "where we left off" not in prompt


def test_adolescent_prompt_weaves_prior_saga_continuity():
    prior = {
        "issue_number": 4,
        "nemesis": "the Archivist",
        "nemesis_status": "still-at-large",
        "what_changed": "the school board sided with the Archivist",
        "next_hook": "a second ledger surfaced in the records room",
    }
    prompt = _build(prior_saga=prior)
    assert "CONTINUITY" in prompt
    assert "CHAPTER 4" in prompt
    assert "the school board sided with the Archivist" in prompt
    assert "a second ledger surfaced in the records room" in prompt
    assert "still out there" in prompt
    assert "where we left off" in prompt


def test_adolescent_continuity_routes_through_build_story_prompt():
    prior = {"issue_number": 2, "next_hook": "the records room is still unlocked"}
    prompt = PromptService.build_story_prompt(
        character="Mia",
        theme="superhero",
        age=16,
        hero_power="strategist",
        prior_saga=prior,
    )
    assert "Adolescent band" in prompt
    assert "CONTINUITY" in prompt
    assert "CHAPTER 2" in prompt
    assert "the records room is still unlocked" in prompt


def test_adolescent_continuity_ignores_empty_saga_dict():
    prompt = _build(
        hero_power="gadgeteer",
        villain_id="the_archivist",
        problem_id="expose_the_setup",
        prior_saga={},
    )
    assert "CONTINUITY" not in prompt


def test_adolescent_prompt_derives_villain_and_problem_when_missing():
    prompt = _build(hero_power="super_speed", villain_id=None, problem_id=None)
    assert any(v["name"] in prompt for v in ADOLESCENT_VILLAINS.values())
    assert any(p["verb"] in prompt for p in ADOLESCENT_PROBLEMS.values())
