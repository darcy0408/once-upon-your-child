"""Pick-a-Path listening-comprehension guards (MT-418, 2026-09-14).

An Explorer-band (age 8) adventure played on a real phone came back with
"shivers like a hidden pocket waiting to breathe", "that small bravery settles
like a scarf around your shoulders", "a seam in the wallpaper", "beckoning",
and the prompt caption "A moment of wonder:" printed verbatim mid-paragraph.

Two root causes, both fixed here:

1. The builder's vocabulary avoid-list existed only for the 3-4 and 5-7 bands
   and was gated on ``age <= 7``, so an 8-year-old got the "richer detail"
   register with no guardrail at all.
2. The safety block said "Must Include: A Moment of Wonder (...), a coping
   moment in action (...)" — a capitalised label the model copies into prose.
   The line is now plain words, and a post-filter excises the caption if it
   leaks anyway.
"""

import pytest

from backend.services.interactive_adventure_prompt_builder import (
    InteractiveAdventurePromptBuilder as PB,
)
from backend.services.interactive_adventure_service import (
    InteractiveAdventureService,
)
from backend.services.story_service import _strip_prompt_heading_labels

HERO = "HERO_1"


def _opening(age):
    return PB.build_opening_prompt(
        child_name=HERO,
        age=age,
        length="short",
        theme="A house where the wallpaper hides a door",
        tone="adventurous",
        character={"name": HERO, "age": age},
    )


def _continuation(age):
    return PB.build_continuation_prompt(
        story_context={
            "age": age,
            "length": "short",
            "theme": "A house where the wallpaper hides a door",
            "tone": "adventurous",
            "character": {"name": HERO, "age": age},
            "companions": [],
        },
        selected_choice="Press the loose corner of the wallpaper",
        current_segment_number=1,
    )


# ---------------------------------------------------------------------------
# Root cause 1: the 8-10 band now carries a read-aloud avoid-list
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("age", [8, 9, 10])
def test_ages_eight_to_ten_get_a_read_aloud_vocabulary_rule(age):
    for prompt in (_opening(age), _continuation(age)):
        assert f"**VOCABULARY FOR AGE {age}**" in prompt
        assert "read ALOUD" in prompt
        assert "one idea per sentence" in prompt
        # The exact words the owner's age-8 adventure tripped on.
        for banned in ("beckoning", "seam", "settles", "nestled"):
            assert banned in prompt


@pytest.mark.parametrize("age", [4, 5, 6, 7])
def test_younger_bands_keep_their_existing_avoid_list(age):
    for prompt in (_opening(age), _continuation(age)):
        assert f"**VOCABULARY FOR AGE {age}**" in prompt
        assert "parchment" in prompt


@pytest.mark.parametrize("age", [11, 13, 16, 45])
def test_older_bands_still_get_no_avoid_list(age):
    for prompt in (_opening(age), _continuation(age)):
        assert "**VOCABULARY FOR AGE" not in prompt


def test_avoid_list_rendering_follows_the_band_not_a_hardcoded_age():
    """The gate used to be ``if age <= 7``; it must now follow the band data,
    so a future band gains a rule by adding the key and nothing else."""
    assert "vocabulary_avoid" in PB.AGE_BANDS["8-10"]
    assert "vocabulary_avoid" not in PB.AGE_BANDS["11-13"]
    assert "**VOCABULARY FOR AGE 8**" in _opening(8)
    assert "**VOCABULARY FOR AGE 11**" not in _opening(11)


# ---------------------------------------------------------------------------
# Root cause 2: no copyable heading in the safety block
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("age", [5, 8, 12, 45])
def test_safety_block_carries_no_copyable_labels(age):
    for prompt in (_opening(age), _continuation(age)):
        assert "Moment of Wonder" not in prompt
        assert "Must Include" not in prompt
        assert "coping moment" not in prompt.lower()
        # The plain-words replacement is present instead.
        assert "stops and stares at something amazing" in prompt


@pytest.mark.parametrize(
    "leaked, expected",
    [
        (
            "A moment of wonder: You look up and the ceiling is full of stars.",
            "You look up and the ceiling is full of stars.",
        ),
        (
            "You push the door. Moment of wonder — the hall is made of glass.",
            "You push the door. the hall is made of glass.",
        ),
        (
            "A coping moment: You breathe in slowly and count to four.",
            "You breathe in slowly and count to four.",
        ),
    ],
)
def test_leaked_heading_caption_is_excised_but_the_sentence_survives(leaked, expected):
    assert _strip_prompt_heading_labels(leaked) == expected


def test_ordinary_prose_that_mentions_wonder_is_left_alone():
    prose = "A moment of wonder washed over you as the stars came out."
    assert _strip_prompt_heading_labels(prose) == prose
    assert _strip_prompt_heading_labels("") == ""


def test_content_hygiene_applies_the_heading_strip_to_segments():
    segment = {
        "content": "A moment of wonder: The tree opens like a door.",
        "is_ending": False,
    }
    cleaned = InteractiveAdventureService._apply_content_hygiene(segment)
    assert cleaned["content"] == "The tree opens like a door."
