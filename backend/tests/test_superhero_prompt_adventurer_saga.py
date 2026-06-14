"""Unit tests for the Adventurer-band (ages 9-12) returnable-saga continuity.

Exercises the saga_state contract and the "PREVIOUSLY IN YOUR SAGA" continuity
block on ``PromptService._build_superhero_prompt_adventurer`` plus the prior_saga
forwarding in ``PromptService.build_story_prompt``. Mirrors the Creator-band
saga tests' style, but the Adventurer band is heroic-adventure (warm, exciting)
and deliberately OMITS the mature "cost comes due" / consequence-callback
mechanic. Pure prompt module — no Gemini, Flask, or DB.
"""

from __future__ import annotations

from backend.services.prompt_service import PromptService


# --- saga_state OUTPUT contract --------------------------------------------
def test_adventurer_prompt_emits_saga_state_contract():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
    )
    assert "saga_state" in prompt
    # Same keys as the Creator builder EXCEPT what_it_cost.
    for key in (
        "nemesis",
        "nemesis_status",
        "what_changed",
        "next_hook",
        "allies",
        "defining_choice",
    ):
        assert f'"{key}"' in prompt, f"saga_state missing key '{key}'"


def test_adventurer_saga_state_omits_what_it_cost():
    """The mature 'cost' field is intentionally absent for 9-12."""
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
    )
    assert "what_it_cost" not in prompt
    assert "COST them this Issue" not in prompt


def test_adventurer_saga_state_uses_recap_nemesis_status_vocabulary():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
    )
    assert "reconsidered | stopped-and-accountable | still-at-large" in prompt


def test_adventurer_defining_choice_is_positive_not_a_debt():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
    )
    # Framed as courage/kindness/cleverness, not a moral debt.
    assert "courage, kindness, or cleverness" in prompt


# --- "PREVIOUSLY IN YOUR SAGA" continuity (returning issue) -----------------
def test_adventurer_weaves_prior_saga_continuity():
    prior = {
        "issue_number": 3,
        "nemesis": "Gigawatt",
        "nemesis_status": "still-at-large",
        "what_changed": "the lighthouse runs on Maya's clever new circuit now",
        "next_hook": "a strange hum started under the old pier",
    }
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
        prior_saga=prior,
    )
    assert "PREVIOUSLY IN YOUR SAGA" in prompt
    assert "ISSUE #3" in prompt
    assert "Gigawatt" in prompt
    assert "the lighthouse runs on Maya's clever new circuit now" in prompt
    assert "a strange hum started under the old pier" in prompt
    # Humanized nemesis_status (warm, not noir).
    assert "is still out there" in prompt
    # Cold-open momentum instruction.
    assert "Previously" in prompt


def test_adventurer_continuity_renders_allies_and_key_choices():
    prior = {
        "nemesis": "the Gatekeeper",
        "nemesis_status": "reconsidered",
        "allies": ["Pip", "Coach Rivera"],
        "key_choices": ["shared the last battery", "told the truth to the mayor"],
    }
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Leo",
        age=11,
        hero_costume_color="crimson",
        hero_cape_style="matching",
        hero_emblem="bolt",
        hero_power="super_hugs",
        villain_id="the_gatekeeper",
        problem_id="earn_their_trust",
        prior_saga=prior,
    )
    assert "Pip" in prompt and "Coach Rivera" in prompt
    assert "shared the last battery" in prompt
    assert "told the truth to the mayor" in prompt
    # "reconsidered" is humanized warmly.
    assert "is rethinking things now" in prompt


# --- NO mature consequence mechanic (absence assertions) --------------------
def test_adventurer_continuity_has_no_consequence_callback_mandate():
    """The mature 'cost comes due' mechanic must NEVER appear for 9-12."""
    prior = {
        "issue_number": 4,
        "nemesis": "Gigawatt",
        "nemesis_status": "still-at-large",
        "what_changed": "the harbor lights are fixed",
        "what_it_cost": "Maya gave up the science fair to do it",
        "next_hook": "a new blackout hit the east side",
        "key_choices": ["unplugged the master switch"],
    }
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
        prior_saga=prior,
    )
    assert "CONSEQUENCE CALLBACK" not in prompt
    assert "Still owed from last time" not in prompt
    assert "COME DUE" not in prompt
    assert "debt" not in prompt.lower()
    # Even though prior carried a what_it_cost, it is not surfaced as a debt.
    assert "Maya gave up the science fair to do it" not in prompt


# --- Issue #1 (no prior_saga) -> no continuity block ------------------------
def test_adventurer_issue_one_has_no_continuity_block():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
        prior_saga=None,
    )
    assert "PREVIOUSLY IN YOUR SAGA" not in prompt
    # The saga_state JSON's own contract line uses "next issue" phrasing, so we
    # only assert the absence of the *continuity* recap, not the word entirely.
    assert "Previously…" not in prompt


def test_adventurer_continuity_ignores_empty_saga_dict():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Ada",
        age=10,
        hero_costume_color="midnight",
        hero_cape_style="rainbow",
        hero_emblem="comet",
        hero_power="gadgeteer",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
        prior_saga={},
    )
    assert "PREVIOUSLY IN YOUR SAGA" not in prompt


# --- prior_saga routes through the public dispatcher ------------------------
def test_adventurer_continuity_routes_through_build_story_prompt():
    prior = {"issue_number": 2, "next_hook": "the old pier still hums at night"}
    prompt = PromptService.build_story_prompt(
        character="Mia",
        theme="superhero",
        age=10,
        hero_power="strategist",
        prior_saga=prior,
    )
    assert "Adventurer band" in prompt
    assert "PREVIOUSLY IN YOUR SAGA" in prompt
    assert "ISSUE #2" in prompt
    assert "the old pier still hums at night" in prompt
