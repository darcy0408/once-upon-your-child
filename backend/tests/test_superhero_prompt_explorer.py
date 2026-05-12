"""Unit tests for the Explorer-band (ages 6-8) superhero prompt builder.

These tests exercise ``PromptService._build_superhero_prompt_explorer`` and
the age-based routing in ``PromptService.build_story_prompt``. They do NOT
hit Gemini, the Flask app, or the database — only the pure prompt module.
"""
from __future__ import annotations

import pytest

from backend.data.superhero_matrix import (
    EXPLORER_POWERS,
    EXPLORER_PROBLEMS,
    EXPLORER_VILLAIN_PROBLEMS,
    EXPLORER_VILLAINS,
)
from backend.services.prompt_service import PromptService


# ---------------------------------------------------------------------------
# Direct calls to _build_superhero_prompt_explorer.
# ---------------------------------------------------------------------------
def test_explorer_prompt_includes_hero_name_three_times_and_identity_tag_twice():
    """The prompt must reference the hero's name at least 3x and the
    identity tag at least 2x so the model has plenty of anchors when it
    writes the story body."""
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Maya",
        age=7,
        hero_costume_color="blue",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_speed",
        villain_id="tangle_knot_twins",
        problem_id="restore_what_taken",
    )
    # Hero name "Maya" should appear at least 3 times.
    assert prompt.count("Maya") >= 3, (
        f"Hero name 'Maya' appears only {prompt.count('Maya')} time(s); need >=3"
    )
    # Identity tag "Lightning Speed Maya" (Explorer power name + hero name).
    identity_tag = "Lightning Speed Maya"
    assert prompt.count(identity_tag) >= 2, (
        f"Identity tag '{identity_tag}' appears only "
        f"{prompt.count(identity_tag)} time(s); need >=2"
    )


def test_explorer_prompt_includes_villain_name_and_problem_verb():
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Leo",
        age=6,
        hero_costume_color="red",
        hero_cape_style="matching",
        hero_emblem="bolt",
        hero_power="super_hugs",
        villain_id="captain_boast",
        problem_id="bridge_the_divide",
    )
    # Villain name (Explorer-band, includes "Captain Boast").
    assert "Captain Boast" in prompt
    # Problem verb for bridge_the_divide is "bring together".
    assert "bring together" in prompt


def test_explorer_prompt_mentions_empathy_or_noticing_resolution_guardrail():
    """The Explorer-tier difference is observation + empathy. The prompt
    text MUST steer the model toward an empathy/cleverness/observation
    resolution — never force."""
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Maya",
        age=7,
        hero_costume_color="blue",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_smile",
        villain_id="the_grumblestorm",
        problem_id="calm_the_storm",
    )
    # At least one of these guardrail words/phrases must appear so the
    # model is steered toward empathy-not-force resolutions.
    keywords = ["empathy", "noticing", "noticed", "kindness", "listening", "cleverness"]
    matches = [kw for kw in keywords if kw.lower() in prompt.lower()]
    assert matches, (
        f"Explorer prompt missing empathy/observation guardrail keywords; "
        f"expected at least one of {keywords}"
    )


def test_explorer_prompt_has_250_350_word_budget():
    """Hard-rule sentinel: the Explorer prompt must announce its
    250-350 word budget so the model doesn't write a Sprout-length story."""
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Sam",
        age=7,
        hero_costume_color="green",
        hero_cape_style="matching",
        hero_emblem="leaf",
        hero_power="super_hearing",
        villain_id="echo_bandit",
        problem_id="decode_signal",
    )
    assert "250" in prompt
    assert "350" in prompt


def test_explorer_prompt_falls_back_when_hero_power_missing():
    """Missing hero_power should fall back to super_smile (shared
    between bands) and still produce a coherent prompt — not raise."""
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Riley",
        age=7,
        hero_costume_color="purple",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power=None,
        villain_id=None,
        problem_id=None,
    )
    assert isinstance(prompt, str) and len(prompt) > 0
    # super_smile in Explorer band displays as "Bright Smile".
    assert "Bright Smile" in prompt


def test_explorer_prompt_falls_back_when_hero_power_unknown():
    """An invalid power ID (e.g. a Sprout-only id that didn't exist, a
    typo, or a malformed payload) should still fall back gracefully."""
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Avery",
        age=8,
        hero_costume_color="gold",
        hero_cape_style="rainbow",
        hero_emblem="star",
        hero_power="super_potato",  # invalid
        villain_id=None,
        problem_id=None,
    )
    assert isinstance(prompt, str) and len(prompt) > 0
    # Falls back to super_smile -> "Bright Smile" in Explorer band.
    assert "Bright Smile" in prompt


def test_explorer_prompt_derives_villain_and_problem_when_missing():
    """If villain_id/problem_id aren't supplied, the prompt builder must
    call pick_pairing(band='explorer') and produce a valid pair."""
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Jordan",
        age=7,
        hero_costume_color="orange",
        hero_cape_style="matching",
        hero_emblem="bolt",
        hero_power="super_speed",
        villain_id=None,
        problem_id=None,
    )
    # Some Explorer villain name must appear in the prompt.
    villain_names = [v["name"] for v in EXPLORER_VILLAINS.values()]
    assert any(name in prompt for name in villain_names), (
        f"Expected one of {villain_names} to appear in prompt"
    )
    # Some Explorer problem verb must appear.
    problem_verbs = [p["verb"] for p in EXPLORER_PROBLEMS.values()]
    assert any(verb in prompt for verb in problem_verbs)


def test_explorer_prompt_derives_pair_when_villain_id_invalid():
    """Invalid villain_id should also route through pick_pairing fallback."""
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Pat",
        age=7,
        hero_costume_color="silver",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_smile",
        villain_id="not_a_real_villain",
        problem_id="not_a_real_problem",
    )
    villain_names = [v["name"] for v in EXPLORER_VILLAINS.values()]
    assert any(name in prompt for name in villain_names)


# ---------------------------------------------------------------------------
# Age-based routing through build_story_prompt.
# ---------------------------------------------------------------------------
def test_build_story_prompt_routes_age_7_to_explorer():
    """A 7-year-old playing Superhero Mode should hit the Explorer prompt."""
    prompt = PromptService.build_story_prompt(
        character="Maya",
        theme="superhero",
        age=7,
        hero_costume_color="blue",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_speed",
        superhero_villain_id="tangle_knot_twins",
        superhero_problem_id="restore_what_taken",
    )
    # Explorer-only markers: 250/350 word budget, Explorer band name.
    assert "Explorer band" in prompt
    assert "250" in prompt
    assert "350" in prompt
    # Should NOT contain Sprout's 130-word marker.
    assert "Stop at 130 words" not in prompt


def test_build_story_prompt_routes_age_6_and_8_to_explorer():
    """Both ends of the Explorer band (6 and 8) should also route to Explorer."""
    for age in (6, 8):
        prompt = PromptService.build_story_prompt(
            character="Maya",
            theme="superhero",
            age=age,
            hero_power="super_smile",
        )
        assert "Explorer band" in prompt, f"age={age} did not route to Explorer"
        assert "350" in prompt, f"age={age} missing Explorer 350-word marker"


def test_build_story_prompt_routes_age_4_to_sprout_unchanged():
    """REGRESSION GUARD — a 4-year-old (Sprout band) must still hit the
    Sprout prompt with its 130-word budget. Do NOT change Sprout."""
    prompt = PromptService.build_story_prompt(
        character="Mia",
        theme="superhero",
        age=4,
        hero_costume_color="pink",
        hero_cape_style="matching",
        hero_emblem="heart",
        hero_power="super_hugs",
        superhero_villain_id="cranky_crab",
        superhero_problem_id="make_peace",
    )
    # Sprout-only markers: 130-word cap, Sprout band name.
    assert "Sprout band" in prompt
    assert "130 words" in prompt
    # Explorer markers should NOT appear in Sprout output.
    assert "Explorer band" not in prompt
    assert "250-350" not in prompt


def test_build_story_prompt_routes_age_3_to_sprout():
    prompt = PromptService.build_story_prompt(
        character="Mia",
        theme="superhero",
        age=3,
        hero_power="super_hugs",
    )
    assert "Sprout band" in prompt
    assert "130 words" in prompt


# ---------------------------------------------------------------------------
# Explorer-only powers — feeling_sense + invisibility.
# ---------------------------------------------------------------------------
@pytest.mark.parametrize(
    "power_id,expected_name",
    [
        ("feeling_sense", "Feeling Sense"),
        ("invisibility", "Soft Step"),
    ],
)
def test_explorer_prompt_renders_explorer_only_powers(power_id, expected_name):
    """Both Explorer-only powers must render their display name correctly,
    including the identity tag form '<Power Name> <Hero Name>'."""
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Kai",
        age=7,
        hero_costume_color="violet",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power=power_id,
        villain_id=None,
        problem_id=None,
    )
    assert expected_name in prompt, (
        f"Explorer power '{power_id}' should display as '{expected_name}'"
    )
    identity_tag = f"{expected_name} Kai"
    assert prompt.count(identity_tag) >= 2, (
        f"Identity tag '{identity_tag}' should appear at least 2x for "
        f"power '{power_id}'"
    )
    # Verify Explorer-only power IDs aren't accidentally exposed by Sprout.
    assert "Sprout band" not in prompt
