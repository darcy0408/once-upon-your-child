"""Unit tests for the Explorer-band (ages 6-8) returnable-saga continuity.

Exercises the saga_state contract and the "LAST TIME…" continuity block on
``PromptService._build_superhero_prompt_explorer`` plus the prior_saga
forwarding in ``PromptService.build_story_prompt``. Mirrors the Adventurer-band
saga tests, but the Explorer band is an EVEN GENTLER 6-8 register: short, warm,
friendly recaps and deliberately NO mature "cost comes due" / consequence-
callback / debt / noir mechanic. Pure prompt module — no Gemini, Flask, or DB.
"""

from __future__ import annotations

from backend.services.prompt_service import PromptService


# --- saga_state OUTPUT contract --------------------------------------------
def test_explorer_prompt_emits_saga_state_contract():
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Mia",
        age=7,
        hero_costume_color="sunny",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_smile",
        villain_id=None,
        problem_id=None,
    )
    assert "saga_state" in prompt
    # Same keys as the Adventurer builder (Creator MINUS what_it_cost).
    for key in (
        "nemesis",
        "nemesis_status",
        "what_changed",
        "next_hook",
        "allies",
        "defining_choice",
    ):
        assert f'"{key}"' in prompt, f"saga_state missing key '{key}'"


def test_explorer_saga_state_omits_what_it_cost():
    """The mature 'cost' field is intentionally absent for 6-8."""
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Mia",
        age=7,
        hero_costume_color="sunny",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_smile",
        villain_id=None,
        problem_id=None,
    )
    assert "what_it_cost" not in prompt
    assert "COST them this Issue" not in prompt


def test_explorer_saga_state_uses_recap_nemesis_status_vocabulary():
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Mia",
        age=7,
        hero_costume_color="sunny",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_smile",
        villain_id=None,
        problem_id=None,
    )
    assert "reconsidered | stopped-and-accountable | still-at-large" in prompt


def test_explorer_defining_choice_is_positive_not_a_debt():
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Mia",
        age=7,
        hero_costume_color="sunny",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_smile",
        villain_id=None,
        problem_id=None,
    )
    # Framed as a kind/brave/clever moment, not a moral debt.
    assert "kind, brave, or clever" in prompt


# --- "LAST TIME…" continuity (returning adventure) -------------------------
def test_explorer_weaves_prior_saga_continuity():
    prior = {
        "issue_number": 3,
        "nemesis": "Grumble",
        "nemesis_status": "still-at-large",
        "what_changed": "the playground swings work again now",
        "next_hook": "a funny new noise came from the slide",
    }
    prompt = PromptService._build_superhero_prompt_explorer(
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
    assert "LAST TIME" in prompt
    assert "ADVENTURE #3" in prompt
    assert "Grumble" in prompt
    assert "the playground swings work again now" in prompt
    assert "a funny new noise came from the slide" in prompt
    # Humanized nemesis_status (warm, not noir) — must NOT assert the old
    # villain "is back": this story pins a different villain, and the
    # contradiction taught the model to drop the old nemesis from the prose.
    assert "is still out there somewhere" in prompt
    assert "is back" not in prompt
    # Gentle "Last time…" momentum instruction, ordered AFTER the mandatory
    # opening phrase so the two first-sentence claims can't collide.
    assert "Last time" in prompt
    assert "exact opening phrase" in prompt
    # Nemesis memory: the prior nemesis is not this story's villain, so the
    # prose must still name them once.
    assert "is NOT this story's villain" in prompt
    # saga_state keeps a still-at-large arch-nemesis instead of overwriting.
    assert "keep 'Grumble'" in prompt


def test_explorer_continuity_reuses_allies_as_returning_friends():
    prior = {
        "nemesis": "Mr. Mix-Up",
        "nemesis_status": "reconsidered",
        "allies": ["Pip", "Nana Rose"],
    }
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Leo",
        age=6,
        hero_costume_color="green",
        hero_cape_style="matching",
        hero_emblem="bolt",
        hero_power="super_smile",
        villain_id=None,
        problem_id=None,
        prior_saga=prior,
    )
    assert "Pip" in prompt and "Nana Rose" in prompt
    # Friends are reused, not reintroduced.
    assert "do NOT introduce them like strangers" in prompt
    # "reconsidered" is humanized warmly for 6-8.
    assert "is being kinder now" in prompt


# --- NO mature consequence mechanic (absence assertions) --------------------
def test_explorer_continuity_has_no_consequence_callback_mandate():
    """The mature 'cost comes due' mechanic must NEVER appear for 6-8."""
    prior = {
        "issue_number": 4,
        "nemesis": "Grumble",
        "nemesis_status": "still-at-large",
        "what_changed": "the lights are fixed",
        "what_it_cost": "Mia missed the picnic to do it",
        "next_hook": "a new puddle appeared by the gate",
        "key_choices": ["shared the umbrella"],
    }
    prompt = PromptService._build_superhero_prompt_explorer(
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
    assert "consequence callback" not in prompt.lower()
    assert "still owed" not in prompt.lower()
    assert "come due" not in prompt.lower()
    assert "debt" not in prompt.lower()
    # Even though prior carried a what_it_cost, it is not surfaced as a debt.
    assert "Mia missed the picnic to do it" not in prompt


# --- Issue #1 (no prior_saga) -> no continuity block ------------------------
def test_explorer_issue_one_has_no_continuity_block():
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Mia",
        age=7,
        hero_costume_color="sunny",
        hero_cape_style="matching",
        hero_emblem="star",
        hero_power="super_smile",
        villain_id=None,
        problem_id=None,
        prior_saga=None,
    )
    assert "LAST TIME" not in prompt
    assert "Last time…" not in prompt


def test_explorer_continuity_ignores_empty_saga_dict():
    prompt = PromptService._build_superhero_prompt_explorer(
        character="Ada",
        age=8,
        hero_costume_color="violet",
        hero_cape_style="rainbow",
        hero_emblem="comet",
        hero_power="super_smile",
        villain_id=None,
        problem_id=None,
        prior_saga={},
    )
    assert "LAST TIME" not in prompt


# --- prior_saga routes through the public dispatcher ------------------------
def test_explorer_continuity_routes_through_build_story_prompt():
    prior = {"issue_number": 2, "next_hook": "the swing still squeaks at night"}
    prompt = PromptService.build_story_prompt(
        character="Mia",
        theme="superhero",
        age=7,
        hero_power="super_smile",
        prior_saga=prior,
    )
    assert "Explorer band" in prompt
    assert "LAST TIME" in prompt
    assert "ADVENTURE #2" in prompt
    assert "the swing still squeaks at night" in prompt
