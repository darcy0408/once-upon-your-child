"""Typed-in people (friends, cousins, grown-ups) never reach the provider by name.

The hero is HERO_1 and co-heroes are HERO_2..; a name typed into the wizard
becomes PERSON_1, PERSON_2... before any provider call and is put back locally.
"""

from __future__ import annotations

import json

import pytest

from backend.services.story_service import (
    HERO_NAME_TOKEN,
    restore_names,
    scrub_names,
    split_person_name,
)
from backend.tasks.story_tasks import generate_story_task

HERO = "Persephone-Marigold"


@pytest.fixture(autouse=True)
def _no_gemini():
    yield


# --- helpers ---------------------------------------------------------------


@pytest.mark.parametrize(
    "typed, kin, private",
    [
        ("Sam", "", "Sam"),
        ("Aunt Rosa", "Aunt", "Rosa"),
        ("Grandma", "Grandma", ""),
        ("my Uncle Bo Jangles", "my Uncle", "Bo Jangles"),
        ("Mr. Okonkwo", "Mr.", "Okonkwo"),
        ("", "", ""),
        (None, "", ""),
    ],
)
def test_split_person_name_keeps_kin_words(typed, kin, private):
    assert split_person_name(typed) == (kin, private)


def test_scrub_hides_a_name_in_any_letter_case():
    out = scrub_names("Zadie, zadie and ZADIE.", {"Zadie": "PERSON_1"})
    assert out == "PERSON_1, PERSON_1 and PERSON_1."


def test_scrub_leaves_everyday_words_alone_for_everyday_word_names():
    text = "The story will end well. Will helps. Use max 3 pages; Max digs."
    out = scrub_names(text, {"Will": "HERO_1", "Max": "PERSON_1"})
    assert out == (
        "The story will end well. HERO_1 helps. Use max 3 pages; PERSON_1 digs."
    )


def test_scrub_everyday_word_name_typed_capitalised_spares_the_lower_case_word():
    out = scrub_names("You may add May.", {"May": "PERSON_1"})
    assert out == "You may add PERSON_1."


def test_scrub_takes_the_longest_name_first():
    out = scrub_names(
        "Quillo-Marrowdew and Quillo.",
        {"Quillo": "PERSON_1", "Quillo-Marrowdew": "PERSON_2"},
    )
    assert out == "PERSON_2 and PERSON_1."


def test_scrub_does_not_touch_a_name_inside_a_longer_word():
    assert scrub_names("Samantha sampled.", {"Sam": "PERSON_1"}) == "Samantha sampled."


def test_scrub_handles_possessives_and_names_ending_in_punctuation():
    out = scrub_names("Zadie's kite. Ask J.R. now.", {"Zadie": "P1", "J.R.": "P2"})
    assert out == "P1's kite. Ask P2 now."


def test_restore_is_whole_token_and_single_pass():
    names = {"hero_1": "Ann", "hero_10": "Bea", "person_1": "HERO_10"}
    out = restore_names("HERO_1, HERO_10, person_1, PERSON_9.", names)
    assert out == "Ann, Bea, HERO_10, PERSON_9."


# --- end to end ------------------------------------------------------------


def _run_task(app, mocker, *, body, meta=None, **task_kwargs):
    """Run the task with a mocked provider. Returns (text sent, result)."""
    story = {
        "title": f"{HERO_NAME_TOKEN} and PERSON_1",
        "pages": [{"text": body * 40}],
        "themes": ["friendship"],
        "characters_featured": [HERO_NAME_TOKEN, "PERSON_1"],
        "emotional_arc": "growth",
    }
    story.update(meta or {})
    mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)
    mocker.patch(
        "backend.utils.content_moderator.moderate_story_content",
        return_value=(True, ""),
    )
    generate = mocker.patch(
        "backend.tasks.story_tasks._generate_story_text_with_metadata",
        return_value=(json.dumps(story), "mock-provider", ["mock-provider"]),
    )
    kwargs = {
        "character": HERO,
        "theme": "Adventure",
        "user_id": "anonymous",
        "age": 8,
        "story_length": "standard",
    }
    kwargs.update(task_kwargs)
    result = generate_story_task.apply(kwargs=kwargs).get()
    sent = " ".join(
        str(a) for call in generate.call_args_list for a in (*call.args, call.kwargs)
    )
    return sent, result


def test_a_typed_friend_is_hidden_and_restored(app, mocker):
    sent, result = _run_task(
        app,
        mocker,
        body=f"{HERO_NAME_TOKEN} and PERSON_1 crossed the whispering meadow. ",
        additional_characters=["Thistlequill"],
        custom_elements="thistlequill brings the kite.",
    )
    assert result["status"] == "complete", result
    assert "thistlequill" not in sent.lower()
    assert "GUESTS: PERSON_1" in sent
    assert "PERSON_1 brings the kite" in sent
    assert "stands in for a real first name" in sent
    story = result["story"]
    assert "Thistlequill" in story["story_text"]
    assert "Thistlequill" in story["title"]
    assert story["characters_featured"] == [HERO, "Thistlequill"]
    assert "PERSON_" not in json.dumps(story)
    assert "HERO_" not in json.dumps(story)


def test_a_grown_up_keeps_the_kin_word_and_loses_the_name(app, mocker):
    sent, result = _run_task(
        app,
        mocker,
        body=f"{HERO_NAME_TOKEN} and Aunt PERSON_1 crossed the whispering meadow. ",
        additional_characters=[
            {"name": "Aunt Bramblewick", "is_adult_relative": True},
            {"name": "Grandma", "is_adult_relative": True},
        ],
    )
    assert result["status"] == "complete", result
    assert "Bramblewick" not in sent
    assert "Aunt PERSON_1" in sent
    assert "Grandma" in sent
    assert "Aunt Bramblewick" in result["story"]["story_text"]


def test_a_saved_friend_sent_as_a_bare_name_is_hidden(app, mocker):
    sent, result = _run_task(
        app,
        mocker,
        body=f"{HERO_NAME_TOKEN} and PERSON_1 crossed the whispering meadow. ",
        companion_characters=[{"name": "Fernhollow"}],
    )
    assert result["status"] == "complete", result
    assert "Fernhollow" not in sent
    assert "Fernhollow" in result["story"]["story_text"]


def test_a_shipped_creature_keeps_its_name(app, mocker):
    sent, _ = _run_task(
        app,
        mocker,
        body=f"{HERO_NAME_TOKEN} and Pebble crossed the whispering meadow. ",
        meta={
            "title": f"{HERO_NAME_TOKEN} and Pebble",
            "characters_featured": [HERO_NAME_TOKEN, "Pebble"],
        },
        companion_characters=[
            {"name": "Pebble", "description": "a small stone golem"},
        ],
    )
    assert "Pebble" in sent
    assert "PERSON_" not in sent


def test_a_missing_person_is_asked_for_by_token_never_by_name(app, mocker):
    # The model leaves the friend out, so the task retries and names who is
    # missing. That note must carry the token.
    sent, _ = _run_task(
        app,
        mocker,
        body=f"{HERO_NAME_TOKEN} crossed the whispering meadow alone. ",
        meta={"title": f"{HERO_NAME_TOKEN} alone"},
        additional_characters=["Thistlequill"],
    )
    assert "Thistlequill" not in sent


@pytest.mark.parametrize(
    "mode",
    [{"bedtime_mode": True}, {"rhyme_time_mode": True}],
)
def test_typed_names_are_hidden_in_the_other_story_modes(app, mocker, mode):
    sent, _ = _run_task(
        app,
        mocker,
        body=f"{HERO_NAME_TOKEN} and PERSON_1 crossed the whispering meadow. ",
        additional_characters=["Thistlequill"],
        companion_characters=[{"name": "Fernhollow"}],
        **mode,
    )
    assert "Thistlequill" not in sent
    assert "Fernhollow" not in sent
    assert HERO not in sent
