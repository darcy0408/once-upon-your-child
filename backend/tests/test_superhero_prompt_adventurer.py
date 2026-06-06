"""Unit tests for the Adventurer-band (ages 9-12) superhero prompt builder.

These tests exercise ``PromptService._build_superhero_prompt_adventurer`` and
the age-based routing in ``PromptService.build_story_prompt``. They do NOT hit
Gemini, the Flask app, or the database — only the pure prompt module.
"""

from __future__ import annotations

import pytest

from backend.data.superhero_matrix import (
    ADVENTURER_PROBLEMS,
    ADVENTURER_VILLAINS,
)
from backend.services.prompt_service import PromptService


# ---------------------------------------------------------------------------
# Direct calls to _build_superhero_prompt_adventurer.
# ---------------------------------------------------------------------------
def test_adventurer_prompt_includes_hero_name_4x_and_identity_tag_3x():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="lightning",
        hero_power="strategist",
        villain_id="gigawatt",
        problem_id="outsmart_the_trap",
    )
    assert (
        prompt.count("Maya") >= 4
    ), f"Hero name 'Maya' appears only {prompt.count('Maya')} time(s); need >=4"
    identity_tag = "Master Strategist Maya"
    assert prompt.count(identity_tag) >= 3, (
        f"Identity tag '{identity_tag}' appears only "
        f"{prompt.count(identity_tag)} time(s); need >=3"
    )


def test_adventurer_prompt_includes_villain_name_and_problem_verb():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Leo",
        age=11,
        hero_costume_color="crimson",
        hero_cape_style="matching",
        hero_emblem="bolt",
        hero_power="super_hugs",
        villain_id="the_gatekeeper",
        problem_id="earn_their_trust",
    )
    assert "the Gatekeeper" in prompt
    # Problem verb for earn_their_trust is "win over".
    assert "win over" in prompt


def test_adventurer_prompt_honors_kid_chosen_nemesis():
    """C4: the kid's chosen nemesis id drives the villain in the prompt.

    story_tasks overrides the server-picked villain with the client's
    hero_nemesis_id; this asserts the builder actually renders the chosen
    villain (and that a different choice changes the output)."""
    base = dict(
        character="Ada",
        age=10,
        hero_costume_color="midnight",
        hero_cape_style="rainbow",
        hero_emblem="comet",
        hero_power="strategist",
        problem_id="earn_their_trust",
    )
    p1 = PromptService._build_superhero_prompt_adventurer(
        villain_id="booger_baron", **base
    )
    p2 = PromptService._build_superhero_prompt_adventurer(
        villain_id="professor_picklejuice", **base
    )
    # All villain NAMES appear in the pinned roster, so assert on each villain's
    # unique ACTION text — that only renders for the *active* (chosen) villain.
    assert "goo" in p1  # booger_baron's action
    assert "pickle" not in p1
    assert "pickle" in p2  # professor_picklejuice's action
    assert "goo" not in p2


# ---------------------------------------------------------------------------
# Real-villain-with-a-motive — the Adventurer tone (Option 1).
# ---------------------------------------------------------------------------
def test_adventurer_prompt_emphasizes_villain_motive_and_understanding():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="blue",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_hearing",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
    )
    lowered = prompt.lower()
    # The villain must have a real, understandable motive — not be "evil".
    assert "motive" in lowered
    assert "NOT evil" in prompt
    # Resolution turns on understanding / perspective-taking.
    assert "understand" in lowered


# ---------------------------------------------------------------------------
# Non-violence guardrail — the non-negotiable spine.
# ---------------------------------------------------------------------------
def test_adventurer_prompt_forbids_violence_and_force():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=12,
        hero_costume_color="green",
        hero_cape_style="none",
        hero_emblem="leaf",
        hero_power="super_strength",
        villain_id="professor_picklejuice",
        problem_id="find_the_fair_path",
    )
    assert "NO weapons" in prompt
    assert "NO fighting" in prompt or "NO violence" in prompt
    lowered = prompt.lower()
    # Resolution must be cleverness/empathy/understanding, never force.
    assert "never through force" in lowered or "never by force" in lowered
    assert any(kw in lowered for kw in ("cleverness", "empathy", "understanding"))


# ---------------------------------------------------------------------------
# MT-121 — villain roster pinning + anti-abstract-puzzle guardrail.
# ---------------------------------------------------------------------------
def test_adventurer_prompt_pins_full_canonical_villain_roster():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="blue",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="gadgeteer",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
    )
    required_names = [v["name"] for v in ADVENTURER_VILLAINS.values()]
    for name in required_names:
        assert (
            name in prompt
        ), f"Canonical villain '{name}' missing from Adventurer prompt roster"


def test_adventurer_prompt_uses_must_language_for_villain_constraint():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="purple",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="gadgeteer",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
    )
    assert "MUST be one of these named Adventurer villains" in prompt


def test_adventurer_prompt_forbids_abstract_puzzle_substitute():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Maya",
        age=10,
        hero_costume_color="blue",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="gadgeteer",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
    )
    forbid_keywords = [
        "abstract setting",
        "weather pattern",
        "riddle",
        "puzzle",
        "logic game",
    ]
    matches = [kw for kw in forbid_keywords if kw in prompt]
    assert matches, (
        "Adventurer prompt missing anti-abstract-motif guardrail; expected one "
        f"of {forbid_keywords} to appear."
    )


def test_adventurer_prompt_has_900_1500_word_budget():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Sam",
        age=10,
        hero_costume_color="green",
        hero_cape_style="matching",
        hero_emblem="leaf",
        hero_power="super_hearing",
        villain_id="gigawatt",
        problem_id="uncover_the_truth",
    )
    assert "900" in prompt
    assert "1500" in prompt
    # Must NOT carry the younger-band caps.
    assert "Stop at 350 words" not in prompt
    assert "130 words" not in prompt


# ---------------------------------------------------------------------------
# Fallbacks.
# ---------------------------------------------------------------------------
def test_adventurer_prompt_falls_back_when_hero_power_missing():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Riley",
        age=10,
        hero_costume_color="purple",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power=None,
        villain_id=None,
        problem_id=None,
    )
    assert isinstance(prompt, str) and len(prompt) > 0
    # super_smile in Adventurer band displays as "Disarming Charm".
    assert "Disarming Charm" in prompt


def test_adventurer_prompt_falls_back_when_hero_power_unknown():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Avery",
        age=12,
        hero_costume_color="gold",
        hero_cape_style="rainbow",
        hero_emblem="star",
        hero_power="super_potato",  # invalid
        villain_id=None,
        problem_id=None,
    )
    assert isinstance(prompt, str) and len(prompt) > 0
    assert "Disarming Charm" in prompt


def test_adventurer_prompt_derives_villain_and_problem_when_missing():
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Jordan",
        age=10,
        hero_costume_color="orange",
        hero_cape_style="matching",
        hero_emblem="bolt",
        hero_power="super_speed",
        villain_id=None,
        problem_id=None,
    )
    villain_names = [v["name"] for v in ADVENTURER_VILLAINS.values()]
    assert any(
        name in prompt for name in villain_names
    ), f"Expected one of {villain_names} to appear in prompt"
    problem_verbs = [p["verb"] for p in ADVENTURER_PROBLEMS.values()]
    assert any(verb in prompt for verb in problem_verbs)


# ---------------------------------------------------------------------------
# Age-based routing through build_story_prompt.
# ---------------------------------------------------------------------------
@pytest.mark.parametrize("age", [9, 10, 11, 12])
def test_build_story_prompt_routes_adventurer_ages(age):
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=age,
        hero_power="super_smile",
    )
    assert "Adventurer band" in prompt, f"age={age} did not route to Adventurer"
    assert "900" in prompt, f"age={age} missing Adventurer word-budget marker"
    # Must not collapse to the younger-band prompts.
    assert "Explorer band" not in prompt
    assert "Sprout band" not in prompt


def test_build_story_prompt_age_8_still_explorer_not_adventurer():
    """REGRESSION GUARD — age 8 stays Explorer; the new branch starts at 9."""
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=8,
        hero_power="super_smile",
    )
    assert "Explorer band" in prompt
    assert "Adventurer band" not in prompt


def test_build_story_prompt_age_4_still_sprout_not_adventurer():
    """REGRESSION GUARD — Sprout untouched by the Adventurer branch."""
    prompt = PromptService.build_story_prompt(
        character="Mia",
        theme="superhero",
        age=4,
        hero_power="super_hugs",
    )
    assert "Sprout band" in prompt
    assert "Adventurer band" not in prompt


# ---------------------------------------------------------------------------
# Adventurer-only powers — strategist + gadgeteer.
# ---------------------------------------------------------------------------
@pytest.mark.parametrize(
    "power_id,expected_name",
    [
        ("strategist", "Master Strategist"),
        ("gadgeteer", "Gadgeteer"),
    ],
)
def test_adventurer_prompt_renders_adventurer_only_powers(power_id, expected_name):
    prompt = PromptService._build_superhero_prompt_adventurer(
        character="Kai",
        age=11,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power=power_id,
        villain_id=None,
        problem_id=None,
    )
    assert (
        expected_name in prompt
    ), f"Adventurer power '{power_id}' should display as '{expected_name}'"
    identity_tag = f"{expected_name} Kai"
    assert prompt.count(identity_tag) >= 3, (
        f"Identity tag '{identity_tag}' should appear at least 3x for "
        f"power '{power_id}'"
    )
