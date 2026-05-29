"""Unit tests for the rhyme-detection helpers used by Learning-to-Read mode.

These were previously colocated with the `_parse_custom_elements` /
`_find_missing_custom_elements` tests in `test_custom_elements.py`. The
custom-elements tests were removed in MT-196 B3 (the helpers themselves
were deleted after security commit 61b87a32 retired verbatim enforcement
for child-safety reasons), but the rhyme helpers remain live in
`story_tasks._is_ltr_rhyme_quality_ok` and are still exercised here.
"""

from backend.tasks.story_tasks import (
    _is_ltr_rhyme_quality_ok,
    _words_rhyme,
)


def test_words_rhyme_matches_simple_endings():
    assert _words_rhyme("cat", "hat")
    assert _words_rhyme("fun", "sun")
    assert not _words_rhyme("cat", "dog")


def test_ltr_rhyme_quality_accepts_couplet_page_endings():
    pages = [
        "Luna pets a cat.",
        "She puts on a hat.",
        "They jump in warm sun.",
        "Then laugh and have fun.",
    ]
    assert _is_ltr_rhyme_quality_ok(pages)


def test_ltr_rhyme_quality_rejects_non_rhyming_pages():
    pages = [
        "Luna sees a cave.",
        "She finds a shiny stone.",
        "A dragon smiles brightly.",
        "They walk back home.",
    ]
    assert not _is_ltr_rhyme_quality_ok(pages)


def test_ltr_rhyme_quality_accepts_within_page_rhyme():
    pages = [
        "Jackie saw the sun. It looked like fun.",
        "She climbed the hill. Her smile was still.",
        "A cat wore a hat. It sat on a mat.",
        "She made a hop. Then reached the top.",
    ]
    assert _is_ltr_rhyme_quality_ok(pages)
