"""Pick-a-Path voice rules (owner decision, 2026-09-14).

Every interactive adventure is told in the "you" voice at every age, the
hero's name is said once per segment, a solo hero gets no invented companion,
and readers 15 and up are settled into the scene before anything happens.

Regression for a real adult play-through that came back "Darcy, Darcy,
Darcy" (the old 15+ third-person "co-author" framing put the name in every
choice and every closing question) with a companion nobody chose (the
companion contract was unconditional, so the model invented one).
"""

import pytest

from backend.services.interactive_adventure_prompt_builder import (
    InteractiveAdventurePromptBuilder as PB,
)

HERO = "HERO_1"  # the pseudonymised token the model actually sees


def _opening(age, companions=None):
    return PB.build_opening_prompt(
        child_name=HERO,
        age=age,
        length="short",
        theme="A quiet harbour at night",
        tone="calm",
        character={"name": HERO, "age": age},
        companions=companions,
    )


def _continuation(age, companions=None):
    return PB.build_continuation_prompt(
        story_context={
            "age": age,
            "length": "short",
            "theme": "A quiet harbour at night",
            "tone": "calm",
            "character": {"name": HERO, "age": age},
            "companions": companions or [],
        },
        selected_choice="Follow the light along the quay",
        current_segment_number=1,
    )


@pytest.mark.parametrize("age", [5, 8, 12, 16, 45])
def test_every_age_is_addressed_as_you_with_the_name_said_once(age):
    for prompt in (_opening(age), _continuation(age)):
        assert "Second person throughout, at every age" in prompt
        assert f"Use the hero's name, {HERO}, exactly once" in prompt
        assert "not in the choices, not in the closing question" in prompt
        assert "Third-person" not in prompt
        assert f"What does {HERO} decide" not in prompt
        assert "co-authoring" not in prompt
        assert "Collaborative Creative Partner" not in prompt


@pytest.mark.parametrize("age", [8, 40])
def test_solo_hero_gets_the_solo_rule_not_the_companion_contract(age):
    for prompt in (_opening(age), _continuation(age)):
        assert "Do NOT invent a companion" in prompt
        assert "companion_beats MUST be an empty list" in prompt
        assert "nobody travels with the hero" in prompt
        assert "Companion Contract" not in prompt
        assert "Must affect the story" not in prompt


def test_named_companion_keeps_the_companion_contract():
    comps = [{"name": "Biscuit", "species": "dog", "role": "pet"}]
    for prompt in (_opening(8, comps), _continuation(8, comps)):
        assert "Companion Contract" in prompt
        assert "Biscuit" in prompt
        assert "Do NOT invent a companion" not in prompt


def test_adult_opening_settles_the_reader_before_anything_happens():
    prompt = _opening(45)
    assert "Open the way a quiet guide would" in prompt
    assert "Orient first: place, time of day" in prompt
    assert "Start in motion, mid-action" not in prompt
    assert "ADULT VOICE (Ages 15+)" in prompt
    assert "Narrator of an immersive adventure for an adult listener" in prompt
    # The segment closes on the moment; the app asks the question (with the
    # "or something else?" door) so the options are never heard twice.
    assert "Close the segment on the moment just before the decision" in prompt
    assert "What does" not in prompt


def test_child_opening_keeps_the_in_motion_entry():
    prompt = _opening(8)
    assert "Start in motion, mid-action" in prompt
    assert "Open the way a quiet guide would" not in prompt
    assert "ADULT VOICE" not in prompt
    assert "Master Storyteller" in prompt


def test_big_feelings_opening_line_is_second_person_for_adults_too():
    ctx = {
        "current_feeling": {
            "emotion_name": "Nervous",
            "physical_signs": "a tight chest",
        }
    }
    line = PB._build_big_feelings_instruction(
        ctx, age=16, child_name=HERO, is_opening=True
    )
    assert "You felt so nervous." in line
    assert "Your body clue was a tight chest." in line
    assert f"{HERO} felt" not in line
    assert f"{HERO}'s body clue" not in line
