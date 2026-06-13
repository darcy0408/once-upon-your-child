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


def test_adolescent_prompt_saga_state_includes_what_it_cost():
    """Consequence ledger: the edge's COST is captured into saga_state."""
    prompt = _build()
    assert "what_it_cost" in prompt
    # The cost contract is concrete, not abstract.
    assert "COST Maya this chapter" in prompt


def test_adolescent_prompt_saga_state_includes_allies_and_defining_choice():
    """Recurring cast + defining-choices ledger are emitted into saga_state."""
    prompt = _build()
    assert "allies" in prompt
    assert "defining_choice" in prompt
    # allies is a names-only recurring-cast contract tied to the secret.
    assert "share Maya's secret" in prompt
    # defining_choice names the chapter's key moral choice.
    assert "CHOICE Maya made this chapter" in prompt


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
        "what_it_cost": "Maya let her best friend take the blame to stay hidden",
        "next_hook": "a second ledger surfaced in the records room",
    }
    prompt = _build(prior_saga=prior)
    assert "CONTINUITY" in prompt
    assert "CHAPTER 4" in prompt
    assert "the school board sided with the Archivist" in prompt
    assert "a second ledger surfaced in the records room" in prompt
    assert "still out there" in prompt
    assert "where we left off" in prompt
    # The prior chapter's cost is carried forward into the continuity block.
    assert "Maya let her best friend take the blame to stay hidden" in prompt
    assert "Still owed from last time" in prompt


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


# --- B1: consequence callback mandate --------------------------------------
def test_adolescent_callback_mandate_fires_on_prior_cost():
    """A returning chapter's prior cost must be forced to COME DUE this chapter."""
    prior = {
        "issue_number": 4,
        "nemesis": "the Archivist",
        "nemesis_status": "still-at-large",
        "what_changed": "the school board sided with the Archivist",
        "what_it_cost": "Maya let her best friend take the blame to stay hidden",
        "next_hook": "a second ledger surfaced in the records room",
    }
    prompt = _build(prior_saga=prior)
    assert "CONSEQUENCE CALLBACK" in prompt
    assert "Maya let her best friend take the blame to stay hidden" in prompt


def test_adolescent_callback_mandate_absent_on_chapter_one():
    """Chapter 1 (no prior saga) -> no consequence-callback mandate."""
    prompt = _build(prior_saga=None)
    assert "CONSEQUENCE CALLBACK" not in prompt


def test_adolescent_callback_mandate_falls_back_to_last_key_choice():
    """With no prior cost, the most recent key choice must come due instead."""
    prior = {
        "nemesis": "the Archivist",
        "nemesis_status": "stopped-and-accountable",
        "key_choices": ["covered for her brother", "leaked the roster"],
    }
    prompt = _build(prior_saga=prior)
    assert "CONSEQUENCE CALLBACK" in prompt
    # Fires on the LAST key choice, not the first.
    assert "leaked the roster" in prompt


def test_adolescent_prompt_derives_villain_and_problem_when_missing():
    prompt = _build(hero_power="super_speed", villain_id=None, problem_id=None)
    assert any(v["name"] in prompt for v in ADOLESCENT_VILLAINS.values())
    assert any(p["verb"] in prompt for p in ADOLESCENT_PROBLEMS.values())


# --- Identity fields (hero_secret / hero_tell / hero_line) ------------------
def test_adolescent_prompt_injects_identity_fields_when_provided():
    secret = "they failed the exam they pretend they aced"
    tell = "they go quiet and pick at their sleeve"
    line = "never sell out a friend to save themselves"
    prompt = _build(
        hero_secret=secret,
        hero_tell=tell,
        hero_line=line,
    )
    # Each user value appears verbatim in the prompt prose.
    assert secret in prompt
    assert tell in prompt
    assert line in prompt
    # hero_line replaces the generic personal-line sentence.
    assert "will not do even when it costs them" in prompt
    assert "Let it be tested directly." in prompt
    # hero_secret adds the concealment-wound bullet.
    assert "hides from the people closest to them" in prompt
    # hero_tell folds into the concealment engine.
    assert "how they slip when it gets close" in prompt


def test_adolescent_prompt_identity_fields_fall_back_when_omitted():
    prompt = _build()
    # Generic personal-line sentence is used when hero_line is blank.
    assert "refuse to do even when it would be easier" in prompt
    assert "Let that line be tested." in prompt
    # No secret bullet / tell fragment when those are blank.
    assert "hides from the people closest to them" not in prompt
    assert "how they slip when it gets close" not in prompt


def test_adolescent_prompt_identity_fields_blank_strings_fall_back():
    prompt = _build(hero_secret="", hero_tell="   ", hero_line="")
    assert "refuse to do even when it would be easier" in prompt
    assert "hides from the people closest to them" not in prompt
    assert "how they slip when it gets close" not in prompt


def test_adolescent_identity_fields_route_through_build_story_prompt():
    secret = "they are the one who leaked the photos"
    tell = "they overcorrect and become too helpful"
    line = "no collateral damage to bystanders"
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=16,
        hero_power="strategist",
        hero_secret=secret,
        hero_tell=tell,
        hero_line=line,
    )
    assert "Adolescent band" in prompt
    assert secret in prompt
    assert tell in prompt
    assert line in prompt
