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
    # Behavioral warning signs (red-team F-6 — probe C1 phrasings verbatim).
    "That I've started giving my favorite things away",
    "I've been giving away my things",
    "I say goodbye like it's the last time",
    "I won't be around much longer",
    "everyone would be better off without me",
    "I'm just a burden",
    # Harm-by-others / abuse disclosure (red-team F-3/F-6 — probe B1 verbatim).
    "That my stepdad hurts me when my mom is at work",
    "my uncle touches me",
    "dad hits me when he's angry",
    "I'm afraid to go home",
    "i am scared to go home after school",
    # Youth euphemisms (red-team 2026-07-17 MEDIUM-2 — probes verbatim, all
    # were false negatives before the euphemism block landed).
    "I want to unalive myself",
    "kms",
    "kys",
    "sewerslide",
    "sewer slide",
    "I want to off myself",
    "I dont want to wake up tomorrow",
    "I should just delete myself",
    "I'm gonna end myself",
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
    # Near-misses for the new pattern classes: third-person / fictional
    # violence and ordinary generosity stay unflagged.
    "the dragon attacks me with fire",
    "the villain hurts the town",
    "I gave my toy to my little sister",
    "we said goodbye at the airport",
    "the monster won't be around after the hero wins",
    # Near-misses for the euphemism block: "off"/"wake up"/"kms"-adjacent
    # strings in ordinary story text stay unflagged.
    "the hero jumped off my roof and flew",
    "I turned off my flashlight in the cave",
    "the bear didn't want to wake up from hibernation",  # third-person, no "I"
    "5 kms from the castle",
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


def test_resources_include_abuse_hotline():
    # Red-team F-6: the net now catches harm-by-others disclosures, so the
    # payload must carry an abuse-specific line, not only suicide/crisis ones.
    assert any("Childhelp" in r["name"] for r in CRISIS_RESOURCES)
    assert any("1-800-422-4453" in r["action"] for r in CRISIS_RESOURCES)


def test_resources_include_international_fallback():
    # Red-team 2026-07-17 MEDIUM-3: the app ships general-audience worldwide;
    # a non-US child must always get one resource that works in their country.
    assert any("findahelpline.com" in r["url"] for r in CRISIS_RESOURCES)
