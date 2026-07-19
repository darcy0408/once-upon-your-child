"""Guards for the saga nemesis continuity plumbing (PR #473 review follow-ups).

Two independent holes, both on the returning-Issue path:

1. **Outbound (prompt side).** Each saga builder humanizes ``nemesis_status``
   through a per-band ``_status_human`` map. The lookup used to fall back to
   the *raw* status string, and Explorer's empty-status default was
   ``"is back again"`` — which contradicts the different-villain pin sitting
   three lines below it and taught the model to drop the old nemesis from the
   prose entirely. An empty or unrecognized status must land on the band's
   neutral wording, never on raw model text and never on "is back".

2. **Inbound (return path).** When a nemesis is left unresolved, the builders
   put a conditional in the ``saga_state.nemesis`` JSON *value* slot rather
   than a literal name. Nothing validated what came back, so a model that
   copied the instruction instead of resolving it would have that string
   stored as the nemesis, shown to the child on the Saga Record screen, and
   folded into the next Issue's prompt as ``prev_nemesis``.

Pure unit tests — no network, Flask, or DB.
"""

from __future__ import annotations

import pytest

from backend.services.prompt_service import PromptService
from backend.services.story_service import _normalize_saga_state

# --- 1. outbound: nemesis_status fallbacks ---------------------------------


def _explorer(prior):
    return PromptService._build_superhero_prompt_explorer(
        character="Mia",
        age=7,
        hero_costume_color="sunny",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_smile",
        villain_id=None,
        problem_id=None,
        prior_saga=prior,
    )


def _adventurer(prior):
    return PromptService._build_superhero_prompt_adventurer(
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


def _creator(prior):
    return PromptService._build_superhero_prompt_creator(
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


def _adolescent(prior):
    return PromptService._build_superhero_prompt_adolescent(
        character="Maya",
        age=16,
        hero_costume_color="charcoal",
        hero_emblem="star",
        hero_power="strategist",
        villain_id="the_double",
        problem_id="expose_the_setup",
        prior_saga=prior,
    )


# (builder, neutral fallback wording for that band)
_BANDS = [
    pytest.param(_explorer, "is still out there somewhere", id="explorer"),
    pytest.param(_adventurer, "is still a mystery", id="adventurer"),
    pytest.param(_creator, "remains a question", id="creator"),
    pytest.param(_adolescent, "remains a question", id="adolescent"),
]

# Statuses the enum does not define: empty, missing, and free-form model text.
_BAD_STATUSES = ["", "   ", "defeated", "vanquished for good", "UNKNOWN"]


@pytest.mark.parametrize("build, neutral", _BANDS)
@pytest.mark.parametrize("status", _BAD_STATUSES)
def test_unrecognized_nemesis_status_falls_back_to_neutral_wording(
    build, neutral, status
):
    prompt = build(
        {
            "issue_number": 3,
            "nemesis": "Gigawatt",
            "nemesis_status": status,
            "what_changed": "the lights came back on",
            "next_hook": "a second outage, three blocks over",
        }
    )
    # The nemesis is still remembered...
    assert "Gigawatt" in prompt
    # ...described with the band's neutral wording...
    assert neutral in prompt
    # ...and never with the raw model string echoed into mandated prose.
    if status.strip():
        assert f"Gigawatt {status}" not in prompt
        assert f"Gigawatt: {status}" not in prompt


@pytest.mark.parametrize("status", _BAD_STATUSES)
def test_explorer_never_says_the_villain_is_back(status):
    """Explorer's old empty-status default was "is back again", which
    contradicted the different-villain pin in the very next line."""
    prompt = _explorer(
        {
            "issue_number": 2,
            "nemesis": "Grumble",
            "nemesis_status": status,
            "what_changed": "the swings work again now",
        }
    )
    assert "is back" not in prompt


# --- 2. inbound: unresolved-instruction guard ------------------------------

_INSTRUCTION_LEAKS = [
    "keep 'Gigawatt' if they remain the saga's defining unresolved nemesis "
    "after this Issue, otherwise 'Cipher Zero'",
    "keep 'Grumble' if they are still the saga's big unresolved villain after "
    "this story, otherwise 'Mr. Mix-Up'",
    "Gigawatt if they remain the saga's defining unresolved threat, otherwise "
    "the new one",
    "x" * 65,  # no real nemesis name runs this long
]


@pytest.mark.parametrize("leaked", _INSTRUCTION_LEAKS)
def test_normalize_drops_unresolved_nemesis_instruction(leaked):
    out = _normalize_saga_state(
        {
            "nemesis": leaked,
            "nemesis_status": "still-at-large",
            "what_changed": "the grid held this time",
        }
    )
    assert "nemesis" not in out
    # The rest of the saga survives — only the poisoned key is dropped.
    assert out["nemesis_status"] == "still-at-large"
    assert out["what_changed"] == "the grid held this time"


@pytest.mark.parametrize(
    "name",
    [
        "Gigawatt",
        "Cipher Zero",
        "Mr. Mix-Up",
        "The Optimizer",
        "Doctor Otherwise",  # substring of a marker, but not the instruction
    ],
)
def test_normalize_keeps_real_nemesis_names(name):
    out = _normalize_saga_state({"nemesis": name, "nemesis_status": "reconsidered"})
    assert out["nemesis"] == name


def test_normalize_drops_nemesis_without_killing_the_block():
    """A dropped nemesis must not collapse saga_state to None — the rest of
    the state still folds forward into the next Issue."""
    out = _normalize_saga_state(
        {
            "nemesis": "keep 'X' if they remain unresolved, otherwise 'Y'",
            "next_hook": "the envelope was still on the desk",
        }
    )
    assert out is not None
    assert out["next_hook"] == "the envelope was still on the desk"
