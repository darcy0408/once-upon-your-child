"""Tests for _strip_companion_beat_labels (structural-instruction transcription filter).

The interactive engine's JSON schema asks for a structured
``companion_beats: [{"type": "dialogue|action|bond", ...}]`` field separate
from prose. The model sometimes echoes that enum as inline captions inside
`content` itself ("Action: Twiggle taps the pebble... Dialogue: 'Match
them,' Twiggle chirps... Bond: Twiggle wraps a damp frond..." — observed on
prod, 2026-07-18). This filter is the post-processing net. It must:
  - Excise label prefixes while KEEPING the sentence content.
  - Leave ordinary prose untouched, including legitimate sentences that
    happen to start with "Bond" or "Help" without a following colon.
  - Handle multiple labels within one page.
"""

from __future__ import annotations

from backend.services.story_service import _strip_companion_beat_labels


def test_action_label_prefix_removed_content_kept():
    content = "Action: Twiggle taps the pebble; its bell-notes answer the echoes."
    assert (
        _strip_companion_beat_labels(content)
        == "Twiggle taps the pebble; its bell-notes answer the echoes."
    )


def test_multiple_labels_one_page():
    content = (
        'Action: Twiggle taps the pebble. Dialogue: "Match them," Twiggle chirps. '
        "Bond: Twiggle wraps a damp frond around your wrist."
    )
    assert _strip_companion_beat_labels(content) == (
        'Twiggle taps the pebble. "Match them," Twiggle chirps. '
        "Twiggle wraps a damp frond around your wrist."
    )


def test_dash_and_em_dash_labels_removed():
    content = "Help — Twiggle points to the hidden trail."
    assert (
        _strip_companion_beat_labels(content) == "Twiggle points to the hidden trail."
    )


def test_ordinary_prose_untouched():
    pages = [
        "Bond formed quickly between the two friends.",
        "Help arrived just as the storm broke.",
        "The action-packed chase left everyone breathless.",
    ]
    for page in pages:
        assert _strip_companion_beat_labels(page) == page


def test_empty_content_returned_as_is():
    assert _strip_companion_beat_labels("") == ""
    assert _strip_companion_beat_labels(None) is None
