"""Tests for _strip_attempt_labels (structural-instruction transcription filter).

The RULE OF THREE / TRY-FAIL prompt instructions were being transcribed into
child-facing prose ("Attempt one: Mia climbed a low drift. ... It failed."
— observed on prod, 2026-07-16). The prompt now bans the wording; this filter
is the post-processing net. It must:
  - Excise try-counter labels while KEEPING the sentence content.
  - Drop bare failure-announcement sentences ("It failed.") entirely.
  - Leave ordinary prose untouched, including legitimate uses of "attempt".
  - Never return an empty page.
"""

from __future__ import annotations

from backend.services.story_service import _strip_attempt_labels


def test_label_prefix_removed_content_kept():
    pages = ["Attempt one: Mia climbed a low drift. Snow fell WHOOSH."]
    assert _strip_attempt_labels(pages) == [
        "Mia climbed a low drift. Snow fell WHOOSH."
    ]


def test_numeric_and_dash_labels_removed():
    pages = ["Attempt 2 — Mia listened for a clue. A bell went ZING."]
    assert _strip_attempt_labels(pages) == [
        "Mia listened for a clue. A bell went ZING."
    ]


def test_failure_announcement_sentence_dropped():
    pages = ["It failed. Mia sighed. Rusty shivered."]
    assert _strip_attempt_labels(pages) == ["Mia sighed. Rusty shivered."]


def test_didnt_work_variant_dropped():
    pages = ["The plan didn't work. Mia tried the door instead."]
    assert _strip_attempt_labels(pages) == ["Mia tried the door instead."]


def test_ordinary_prose_untouched():
    pages = [
        "Her attempt to reach the shelf was brave.",
        "Two days later, the fox returned.",
        "The kite failed to rise at first, then caught the wind.",
    ]
    assert _strip_attempt_labels(pages) == pages


def test_page_never_emptied():
    pages = ["It failed."]
    # Dropping the only sentence would empty the page — keep the original.
    assert _strip_attempt_labels(pages) == ["It failed."]


def test_multiple_labels_one_page():
    pages = [
        "Attempt one: Mia climbed. Attempt two: Mia listened. "
        "Attempt three: Mia used kind hands."
    ]
    assert _strip_attempt_labels(pages) == [
        "Mia climbed. Mia listened. Mia used kind hands."
    ]
