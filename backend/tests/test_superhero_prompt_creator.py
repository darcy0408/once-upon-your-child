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


def test_creator_prompt_uses_custom_alias_over_power_name():
    """MT-305 regression: a child's typed codename becomes the hero alias,
    NOT the power display name. The bug was that ``alias`` was hardcoded to
    ``power_name`` and ``hero_alias`` was ignored entirely."""
    prompt = PromptService._build_superhero_prompt_creator(
        character="Maya",
        age=13,
        hero_costume_color="charcoal",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="strategist",  # power display name is "Mastermind"
        hero_alias="Nightweaver",
        villain_id="the_optimizer",
        problem_id="outwit_the_mastermind",
    )
    assert 'Hero alias: "Nightweaver"' in prompt
    # The power display name must NOT stand in for the codename the child chose.
    assert "Mastermind" not in prompt


def test_creator_prompt_falls_back_to_power_name_when_alias_blank():
    """MT-305: with no typed codename (None/empty/whitespace), the power
    display name is used as the alias — the documented fallback."""
    for blank in (None, "", "   "):
        prompt = PromptService._build_superhero_prompt_creator(
            character="Maya",
            age=13,
            hero_costume_color="charcoal",
            hero_cape_style="none",
            hero_emblem="star",
            hero_power="strategist",
            hero_alias=blank,
            villain_id="the_optimizer",
            problem_id="outwit_the_mastermind",
        )
        assert 'Hero alias: "Mastermind"' in prompt


def test_creator_alias_routes_through_build_story_prompt():
    """MT-305: hero_alias reaches the Creator builder via the public dispatcher."""
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=13,
        hero_power="strategist",
        hero_alias="Nightweaver",
    )
    assert "Creator band" in prompt
    assert 'Hero alias: "Nightweaver"' in prompt


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


def test_creator_prompt_saga_state_includes_what_it_cost():
    """Consequence ledger: what the hero's choice/power COST is captured."""
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
    assert "what_it_cost" in prompt
    assert "COST them this Issue" in prompt


def test_creator_prompt_saga_state_includes_allies_and_defining_choice():
    """Recurring cast + defining-choices ledger are emitted into saga_state."""
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
    assert "allies" in prompt
    assert "defining_choice" in prompt
    # allies is a names-only recurring-cast contract tied to the secret.
    assert "share Maya's secret" in prompt
    # defining_choice names the Issue's key moral choice.
    assert "CHOICE Maya made this Issue" in prompt


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
        "what_it_cost": "Mastermind burned a friendship to crack the grid",
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
    # The prior Issue's cost is carried forward into the continuity block.
    assert "Mastermind burned a friendship to crack the grid" in prompt
    assert "Still owed from last time" in prompt


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


# --- B1: consequence callback mandate --------------------------------------
def test_creator_callback_mandate_fires_on_prior_cost():
    """A returning Issue's prior cost must be forced to COME DUE this Issue."""
    prior = {
        "issue_number": 4,
        "nemesis": "the Optimizer",
        "nemesis_status": "still-at-large",
        "what_changed": "the transit grid trusts Mastermind now",
        "what_it_cost": "Mastermind burned a friendship to crack the grid",
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
    assert "CONSEQUENCE CALLBACK" in prompt
    assert "Mastermind burned a friendship to crack the grid" in prompt


def test_creator_callback_mandate_absent_on_issue_one():
    """Issue #1 (no prior saga) -> no consequence-callback mandate."""
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
    assert "CONSEQUENCE CALLBACK" not in prompt


def test_creator_callback_mandate_falls_back_to_last_key_choice():
    """With no prior cost, the most recent key choice must come due instead."""
    prior = {
        "nemesis": "Nightjar",
        "nemesis_status": "stopped-and-accountable",
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
    assert "CONSEQUENCE CALLBACK" in prompt
    # Fires on the LAST key choice, not the first.
    assert "exposed the mayor's deal" in prompt


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


# --- Adult (18+) rides the Creator tier -------------------------------------
# The client (AgeBand.usesHeroSaga + SuperheroEntryScreen.visualBand) now
# exposes the full Hero Saga loop to Adult users; the backend has routed 18+
# to the Creator builder since the T9 dispatch fix. These lock the two halves
# together: an adult request must land on the Creator template AND honor a
# returning hero's prior_saga exactly like a 13-14 request does.


def test_adult_18plus_routes_to_creator_builder():
    prompt = PromptService.build_story_prompt(
        character="Dana",
        theme="superhero",
        age=34,
        hero_power="strategist",
    )
    assert "Creator band" in prompt


def test_adult_18plus_prior_saga_threads_continuity_and_callback():
    prior = {
        "issue_number": 3,
        "nemesis": "The Optimizer",
        "nemesis_status": "still-at-large",
        "what_changed": "Dana traced the shell company to the marina",
        "what_it_cost": "Burned her source at the records office",
        "next_hook": "The ledger page was missing exactly one name",
        "hero_code": "Never trade someone else's secret",
        "allies": ["Priya"],
        "key_choices": ["Let the courier walk to protect Priya"],
    }
    prompt = PromptService.build_story_prompt(
        character="Dana",
        theme="superhero",
        age=34,
        hero_power="strategist",
        prior_saga=prior,
    )
    assert "CONTINUITY" in prompt and "ISSUE #3" in prompt
    assert "The Optimizer" in prompt
    assert "Never trade someone else's secret" in prompt
    # The Creator tier's consequence-callback mandate must fire for adults too.
    assert "CONSEQUENCE CALLBACK" in prompt
    assert "Burned her source at the records office" in prompt


# --- Nemesis continuity (2026-07-17 critique C-2/P0) ------------------------
def test_creator_preserves_still_at_large_arch_nemesis():
    """A still-at-large prior nemesis who is NOT this Issue's antagonist must
    be named in the prose and kept in saga_state instead of overwritten."""
    prior = {
        "issue_number": 2,
        "nemesis": "the Optimizer",
        "nemesis_status": "still-at-large",
    }
    prompt = PromptService._build_superhero_prompt_creator(
        character="Maya",
        age=13,
        hero_costume_color="charcoal",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="cipher_zero",
        problem_id="expose_the_conspiracy",
        prior_saga=prior,
    )
    assert "the Optimizer is NOT this Issue's antagonist" in prompt
    assert "mention them by name at least once" in prompt
    assert "keep 'the Optimizer'" in prompt


def test_creator_saga_state_overwrites_resolved_nemesis():
    prior = {"nemesis": "the Optimizer", "nemesis_status": "stopped-and-accountable"}
    prompt = PromptService._build_superhero_prompt_creator(
        character="Maya",
        age=13,
        hero_costume_color="charcoal",
        hero_cape_style="none",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="cipher_zero",
        problem_id="expose_the_conspiracy",
        prior_saga=prior,
    )
    assert "keep 'the Optimizer'" not in prompt
