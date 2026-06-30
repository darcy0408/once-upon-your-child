"""Tests for self-harm / suicide crisis detection (audit finding #5).

Detection favours recall (a missed disclosure is the costly error) but must not
fire on ordinary third-person story violence.
"""

import pytest

from backend.utils.crisis_detection import (
    CRISIS_RESOURCES,
    crisis_response,
    detect_crisis,
)

# Self-directed disclosures that MUST be detected.
CRISIS_TEXTS = [
    "I want to kill myself",
    "i want to die",
    "I'm thinking about suicide",
    "feeling suicidal",
    "I'm going to hurt myself",
    "I want to harm myself",
    "self-harm",
    "self harm",
    "I keep cutting myself",
    "I cut myself",
    "I don't want to live anymore",
    "I dont want to be here",
    "I wish I was dead",
    "I wish I were not alive",
    "there's no reason to live",
    "I just want to end it all",
    "I want to end my life",
    "I might take my own life",
    "I'd be better off dead",
]

# Ordinary story / gameplay text that must NOT be flagged.
NON_CRISIS_TEXTS = [
    "",
    "the villain wants to kill the dragon",
    "the hero kills the monster and saves the day",
    "I want to fly to the moon",
    "my pet dinosaur is the best",
    "the knight will die in the final battle",
    "I cut the rope to free the prince",
    "let's explore the haunted castle",
    "the wizard casts a spell of light",
    "I want to build a treehouse with my friend",
]


@pytest.mark.parametrize("text", CRISIS_TEXTS)
def test_detects_self_harm_disclosures(text):
    assert detect_crisis(text) is True, f"missed disclosure: {text!r}"


@pytest.mark.parametrize("text", NON_CRISIS_TEXTS)
def test_ignores_ordinary_story_text(text):
    assert detect_crisis(text) is False, f"false positive: {text!r}"


def test_none_is_not_crisis():
    assert detect_crisis(None) is False


def test_detection_is_case_insensitive():
    assert detect_crisis("I WANT TO KILL MYSELF") is True


def test_crisis_response_shape():
    resp = crisis_response()
    assert resp["crisis"] is True
    assert resp["message"]
    assert resp["resources"] is CRISIS_RESOURCES
    assert any("988" in r["action"] for r in resp["resources"])
    for r in resp["resources"]:
        assert {"name", "description", "action", "url"} <= set(r)
