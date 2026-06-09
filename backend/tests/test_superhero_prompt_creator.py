"""Unit tests for the Creator-band (ages 13-14) "Hero Saga" superhero prompt.

Exercises ``PromptService._build_superhero_prompt_creator`` and the age-based
routing in ``PromptService.build_story_prompt``. Pure prompt module — no Gemini,
Flask, or DB.
"""

from __future__ import annotations

import pytest

from backend.data.superhero_matrix import CREATOR_PROBLEMS, CREATOR_VILLAINS
from backend.services.prompt_service import PromptService


def test_creator_prompt_includes_hero_name_and_alias():
    prompt = PromptService._build_superhero_prompt_creator(
        character="Maya",
        age=13,
        hero_costume_color="charcoal",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="the_optimizer",
        problem_id="outwit_the_mastermind",
    )
    assert prompt.count("Maya") >= 4
    # The codename is the hero alias; "Mastermind" is the strategist display name.
    assert "Mastermind" in prompt


def test_creator_prompt_includes_villain_name_and_problem_verb():
    prompt = PromptService._build_superhero_prompt_creator(
        character="Leo",
        age=14,
        hero_costume_color="navy",
        hero_cape_style="none",
        hero_emblem="bolt",
        hero_power="super_hearing",
        villain_id="the_mirror",
        problem_id="clear_the_framed",
    )
    assert "the Mirror" in prompt
    assert "prove the innocence of" in prompt  # clear_the_framed verb


def test_creator_prompt_weaves_in_custom_elements():
    idea = "ride a magic carpet"
    direct = PromptService._build_superhero_prompt_creator(
        character="Mia",
        age=13,
        hero_costume_color="dark",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="gadgeteer",
        villain_id="cipher_zero",
        problem_id="expose_the_conspiracy",
        custom_elements=idea,
    )
    assert f"[USER_INPUT]{idea}[/USER_INPUT]" in direct
    routed = PromptService.build_story_prompt(
        character="Mia",
        theme="superhero",
        age=13,
        hero_power="gadgeteer",
        custom_elements=idea,
    )
    assert f"[USER_INPUT]{idea}[/USER_INPUT]" in routed


def test_creator_prompt_omits_custom_block_when_empty():
    prompt = PromptService._build_superhero_prompt_creator(
        character="Mia",
        age=13,
        hero_costume_color="dark",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="super_smile",
        villain_id="the_magnate",
        problem_id="broker_the_deal",
        custom_elements="",
    )
    assert "THEIR OWN STORY IDEA" not in prompt
    assert "[USER_INPUT]" not in prompt


def test_creator_prompt_forbids_violence_and_allows_boundaries():
    prompt = PromptService._build_superhero_prompt_creator(
        character="Maya",
        age=14,
        hero_costume_color="black",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="super_strength",
        villain_id="nightjar",
        problem_id="de_escalate_standoff",
    )
    assert "NO weapons" in prompt
    lowered = prompt.lower()
    assert "non-violent" in lowered
    # Boundaries/accountability are explicitly heroic (not just redemption).
    assert "boundaries" in lowered or "boundary" in lowered
    assert "accountability" in lowered


def test_creator_prompt_does_not_require_universal_redemption():
    """The therapeutic guardrail: a child is never told to 'fix' a villain."""
    prompt = PromptService._build_superhero_prompt_creator(
        character="Sam",
        age=13,
        hero_costume_color="grey",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="super_whisper",
        villain_id="the_benefactor",
        problem_id="win_back_trust",
    )
    lowered = prompt.lower()
    assert "responsible for" in lowered  # "...not responsible for 'fixing'..."
    assert "instant forgiveness" in lowered  # tone guardrail present


def test_creator_prompt_requires_mystery_and_real_choice():
    prompt = PromptService._build_superhero_prompt_creator(
        character="Ada",
        age=13,
        hero_costume_color="indigo",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="signal_sense" if False else "super_hearing",
        villain_id="cipher_zero",
        problem_id="expose_the_conspiracy",
    )
    lowered = prompt.lower()
    assert "mystery" in lowered
    assert "choice" in lowered
    assert "limit" in lowered or "cost" in lowered  # power-not-enough beat


def test_creator_prompt_pins_canonical_villain_roster():
    prompt = PromptService._build_superhero_prompt_creator(
        character="Maya",
        age=13,
        hero_costume_color="blue",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="gadgeteer",
        villain_id="cipher_zero",
        problem_id="expose_the_conspiracy",
    )
    for v in CREATOR_VILLAINS.values():
        assert v["name"] in prompt, f"Canonical villain '{v['name']}' missing"
    assert "must be ONE of these named Creator villains" in prompt


def test_creator_prompt_emits_continuity_saga_state():
    prompt = PromptService._build_superhero_prompt_creator(
        character="Maya",
        age=13,
        hero_costume_color="blue",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="the_optimizer",
        problem_id="outwit_the_mastermind",
    )
    assert "saga_state" in prompt
    assert "nemesis_status" in prompt
    assert "next_hook" in prompt


def test_creator_prompt_has_1100_1800_word_budget():
    prompt = PromptService._build_superhero_prompt_creator(
        character="Sam",
        age=14,
        hero_costume_color="green",
        hero_cape_style="none",
        hero_emblem="leaf",
        hero_power="super_hearing",
        villain_id="redact",
        problem_id="reveal_the_cover_up",
    )
    assert "1100" in prompt and "1800" in prompt


def test_creator_prompt_falls_back_on_missing_or_unknown_power():
    for bad in (None, "super_potato"):
        prompt = PromptService._build_superhero_prompt_creator(
            character="Riley",
            age=13,
            hero_costume_color="purple",
            hero_cape_style="none",
            hero_emblem="star",
            hero_power=bad,
            villain_id=None,
            problem_id=None,
        )
        assert isinstance(prompt, str) and len(prompt) > 0
        # super_smile in Creator displays as "Magnetism".
        assert "Magnetism" in prompt


@pytest.mark.parametrize(
    "power_id,expected", [("strategist", "Mastermind"), ("gadgeteer", "Technomancer")]
)
def test_creator_only_powers_render(power_id, expected):
    prompt = PromptService._build_superhero_prompt_creator(
        character="Kai",
        age=14,
        hero_costume_color="violet",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power=power_id,
        villain_id=None,
        problem_id=None,
    )
    assert expected in prompt


# --- Age-based routing ------------------------------------------------------
@pytest.mark.parametrize("age", [13, 14])
def test_build_story_prompt_routes_creator_ages(age):
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=age,
        hero_power="super_smile",
    )
    assert "Creator band" in prompt, f"age={age} did not route to Creator"
    assert "Adventurer band" not in prompt
    assert "Sprout band" not in prompt


def test_build_story_prompt_age_12_still_adventurer_not_creator():
    """REGRESSION GUARD — age 12 is Adventurer; Creator starts at 13."""
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=12,
        hero_power="super_smile",
    )
    assert "Adventurer band" in prompt
    assert "Creator band" not in prompt


def test_build_story_prompt_age_15_routes_adolescent_not_creator():
    """Adolescent (15-17) now routes to the antihero tier, never Creator."""
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=15,
        hero_power="super_smile",
    )
    assert "Adolescent band" in prompt
    assert "Creator band" not in prompt


# --- Phase 2: returnable saga continuity -----------------------------------
def test_creator_issue_one_has_no_continuity_block():
    """No prior_saga (Issue #1) -> a clean origin, no 'Previously' block."""
    prompt = PromptService._build_superhero_prompt_creator(
        character="Maya",
        age=13,
        hero_costume_color="charcoal",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="the_optimizer",
        problem_id="outwit_the_mastermind",
        prior_saga=None,
    )
    assert "CONTINUITY" not in prompt
    assert "Previously" not in prompt


def test_creator_prompt_weaves_prior_saga_continuity():
    """A returning hero's saga_state becomes a 'Previously…' continuity block."""
    prior = {
        "issue_number": 4,
        "nemesis": "the Optimizer",
        "nemesis_status": "still-at-large",
        "what_changed": "the transit grid trusts Mastermind now",
        "next_hook": "a second Optimizer node went dark in the harbor",
    }
    prompt = PromptService._build_superhero_prompt_creator(
        character="Maya",
        age=13,
        hero_costume_color="charcoal",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="the_optimizer",
        problem_id="outwit_the_mastermind",
        prior_saga=prior,
    )
    assert "CONTINUITY" in prompt
    assert "ISSUE #4" in prompt
    assert "the transit grid trusts Mastermind now" in prompt
    assert "a second Optimizer node went dark in the harbor" in prompt
    assert "still out there" in prompt  # humanized nemesis_status
    assert "Previously" in prompt  # cold-open recap instruction


def test_creator_continuity_renders_code_allies_and_choices():
    prior = {
        "nemesis": "Nightjar",
        "nemesis_status": "stopped-and-accountable",
        "hero_code": "never lie to the people who trust me",
        "allies": ["Reza", "Detective Okafor"],
        "key_choices": ["spared the courier", "exposed the mayor's deal"],
    }
    prompt = PromptService._build_superhero_prompt_creator(
        character="Leo",
        age=14,
        hero_costume_color="navy",
        hero_cape_style="none",
        hero_emblem="bolt",
        hero_power="super_hearing",
        villain_id="nightjar",
        problem_id="de_escalate_standoff",
        prior_saga=prior,
    )
    assert "never lie to the people who trust me" in prompt
    assert "Reza" in prompt and "Detective Okafor" in prompt
    assert "spared the courier" in prompt
    # "stopped-and-accountable" is humanized into the not-your-job-to-fix framing.
    assert "not redeemed" in prompt
    # Defaults to Issue #1 when no issue_number supplied but a saga exists.
    assert "ISSUE #1" in prompt


def test_creator_continuity_routes_through_build_story_prompt():
    """prior_saga reaches the Creator tier via the public dispatcher."""
    prior = {"issue_number": 2, "next_hook": "the harbor node is still dark"}
    prompt = PromptService.build_story_prompt(
        character="Mia",
        theme="superhero",
        age=13,
        hero_power="strategist",
        prior_saga=prior,
    )
    assert "Creator band" in prompt
    assert "CONTINUITY" in prompt
    assert "ISSUE #2" in prompt
    assert "the harbor node is still dark" in prompt


def test_creator_continuity_ignores_empty_saga_dict():
    """An empty dict (no usable fields) must not emit a stray continuity block."""
    prompt = PromptService._build_superhero_prompt_creator(
        character="Ada",
        age=13,
        hero_costume_color="indigo",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="gadgeteer",
        villain_id="cipher_zero",
        problem_id="expose_the_conspiracy",
        prior_saga={},
    )
    assert "CONTINUITY" not in prompt


def test_creator_prompt_derives_villain_and_problem_when_missing():
    prompt = PromptService._build_superhero_prompt_creator(
        character="Jordan",
        age=13,
        hero_costume_color="orange",
        hero_cape_style="none",
        hero_emblem="bolt",
        hero_power="super_speed",
        villain_id=None,
        problem_id=None,
    )
    assert any(v["name"] in prompt for v in CREATOR_VILLAINS.values())
    assert any(p["verb"] in prompt for p in CREATOR_PROBLEMS.values())
