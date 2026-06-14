"""Unit tests for "The Crux Choice" two-phase Adolescent antihero prompts.

Phase 1 of the interactive-crux feature splits the single-shot Adolescent
chapter (``_build_superhero_prompt_adolescent``) into two builders that share
the same ``_antihero_brief`` setup:

- ``_build_antihero_prompt_part1`` — Beats 1-4 + the crux setup, emitting a
  ``crux`` line and two two-sided ``choices``; NO ``saga_state``.
- ``_build_antihero_prompt_part2`` — Beats 5-7 conditioned on the chosen
  option, emitting the full ``saga_state`` with ``defining_choice`` templated
  from the reader's choice.

Pure prompt module — no Gemini, Flask, or DB.
"""

from __future__ import annotations

from backend.services.prompt_service import PromptService

# Shared brief inputs — a valid Adolescent villain/problem pairing.
_BASE = dict(
    character="Maya",
    age=16,
    hero_costume_color="charcoal",
    hero_emblem="star",
    hero_power="strategist",
    villain_id="the_double",
    problem_id="expose_the_setup",
)

_SECRET = "they failed the exam they pretend they aced"
_TELL = "they go quiet and pick at their sleeve"
_LINE = "never sell out a friend to save themselves"

_CHOICE = {
    "id": "a",
    "text": "Tell the truth and burn the cover to clear her friend's name",
}
_PART1_PAGES = [
    "Beat 1 cold open prose about Maya's double life.",
    "Beat 2 the wrongness that doesn't fit.",
    "Beat 3 the first move and its real cost.",
    "Beat 4 the dissent and the truth, ending on the held breath.",
]


def _part1(**overrides):
    base = dict(_BASE)
    base.update(overrides)
    return PromptService._build_antihero_prompt_part1(**base)


def _part2(**overrides):
    base = dict(_BASE)
    base.update(overrides)
    return PromptService._build_antihero_prompt_part2(
        chosen_choice=base.pop("chosen_choice", _CHOICE),
        part1_pages=base.pop("part1_pages", _PART1_PAGES),
        **base,
    )


# --- Part 1: setup + crux, no resolution -----------------------------------
def test_part1_carries_premise_and_register():
    prompt = _part1()
    assert "DOUBLE LIFE" in prompt
    assert "CONCEALMENT" in prompt
    assert "Adolescent band" in prompt
    assert prompt.count("Maya") >= 4


def test_part1_injects_identity_fields():
    prompt = _part1(hero_secret=_SECRET, hero_tell=_TELL, hero_line=_LINE)
    assert _SECRET in prompt
    assert _TELL in prompt
    assert _LINE in prompt
    assert "hides from the people closest to them" in prompt
    assert "how they slip when it gets close" in prompt
    assert "will not do even when it costs them" in prompt


def test_part1_instructs_beats_1_through_4_plus_crux_and_stops():
    prompt = _part1()
    assert "PART 1 OF 2" in prompt
    # Beats 1-4 present; crux setup is the cap.
    assert "COLD OPEN" in prompt
    assert "THE WRONGNESS" in prompt
    assert "THE DISSENT" in prompt
    assert "THE CRUX (SETUP ONLY)" in prompt
    # Explicit stop instruction; must NOT resolve.
    assert "STOP HERE" in prompt
    assert "DO NOT resolve the chapter" in prompt
    # The 4th page wraps the dissent + crux; there is no Beat 5/6/7 page.
    assert "Beat 4" in prompt
    assert "Beat 6 — THE RESOLUTION" not in prompt
    assert "Beat 7 — AFTERMATH" not in prompt


def test_part1_json_contract_has_crux_and_two_choices():
    prompt = _part1()
    assert '"crux"' in prompt
    assert '"choices"' in prompt
    assert '"id": "a"' in prompt
    assert '"id": "b"' in prompt
    # The two options are framed as genuinely two-sided.
    assert "no clean-good option" in prompt
    assert "GENUINELY two-sided" in prompt


def test_part1_has_no_saga_state():
    prompt = _part1()
    assert "saga_state" not in prompt
    assert "defining_choice" not in prompt
    assert "next_hook" not in prompt


def test_part1_keeps_hard_safety_rules():
    prompt = _part1()
    assert "NO weapons" in prompt
    lowered = prompt.lower()
    assert "non-violent" in lowered
    assert "morally grey" in lowered or "morally-grey" in lowered
    assert "not cruelty" in lowered
    assert "worth rooting for" in lowered
    assert "grade 9-11" in lowered


def test_part1_derives_villain_when_missing():
    from backend.data.superhero_matrix import ADOLESCENT_VILLAINS

    prompt = _part1(hero_power="super_speed", villain_id=None, problem_id=None)
    assert any(v["name"] in prompt for v in ADOLESCENT_VILLAINS.values())


# --- Part 2: resolution conditioned on the chosen path ----------------------
def test_part2_includes_story_so_far_block():
    prompt = _part2()
    assert "STORY SO FAR" in prompt
    for page in _PART1_PAGES:
        assert page in prompt


def test_part2_includes_chosen_choice_text():
    prompt = _part2()
    assert _CHOICE["text"] in prompt
    assert "THE CHOICE THE READER MADE" in prompt
    assert "PART 2 OF 2" in prompt


def test_part2_instructs_beats_5_through_7():
    prompt = _part2()
    assert "THE CHOICE, RESOLVED" in prompt
    assert "THE RESOLUTION" in prompt
    assert "AFTERMATH" in prompt
    assert "Beat 5" in prompt
    assert "Beat 6" in prompt
    assert "Beat 7" in prompt
    # Part 2 does NOT re-write the setup beats.
    assert "COLD OPEN" not in prompt


def test_part2_saga_state_templates_chosen_choice():
    prompt = _part2()
    assert "saga_state" in prompt
    assert "defining_choice" in prompt
    assert "what_it_cost" in prompt
    assert "nemesis_status" in prompt
    assert "next_hook" in prompt
    assert "allies" in prompt
    # defining_choice's INSTRUCTION references the reader's choice text.
    assert (
        f'this MUST be the choice the reader picked: \\"{_CHOICE["text"]}\\"' in prompt
    )
    # what_it_cost is also templated from the choice.
    assert f'the choice \\"{_CHOICE["text"]}\\" COST Maya this chapter' in prompt


def test_part2_keeps_hard_safety_rules():
    prompt = _part2()
    assert "NO weapons" in prompt
    lowered = prompt.lower()
    assert "non-violent" in lowered
    assert "not cruelty" in lowered
    assert "grade 9-11" in lowered


def test_part2_handles_empty_part1_pages_and_missing_choice():
    # Defensive: a blank choice / empty pages must still build a string.
    prompt = PromptService._build_antihero_prompt_part2(
        chosen_choice={}, part1_pages=[], **_BASE
    )
    assert isinstance(prompt, str) and len(prompt) > 0
    assert "STORY SO FAR" in prompt


# --- Regression: single-shot builder unchanged ------------------------------
def test_single_shot_builder_still_emits_full_7_beat_saga_contract():
    """The refactor must NOT change the single-shot adolescent output shape."""
    prompt = PromptService._build_superhero_prompt_adolescent(**_BASE)
    # All 7 beats in one shot.
    assert "Beat 5 — THE TRUTH + THE CHOICE" in prompt
    assert "Beat 6 — THE RESOLUTION" in prompt
    assert "Beat 7 — AFTERMATH" in prompt
    # Full saga_state contract emitted (no crux/choices split).
    assert "saga_state" in prompt
    assert "defining_choice" in prompt
    assert "nemesis_status" in prompt
    assert "next_hook" in prompt
    assert "what_it_cost" in prompt
    # Single-shot does NOT carry the part-1 crux/choices contract.
    assert '"crux"' not in prompt
    assert '"choices"' not in prompt
