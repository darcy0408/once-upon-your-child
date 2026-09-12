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


# ── Limerick Mode: one AABBA verse per page ───────────────────────────────

_LIMERICK_PAGES = [
    "There once was a boy with a hat\n"
    "Who sat with his cat on a mat\n"
    "They played in the sun\n"
    "And had so much fun\n"
    "And that was the start of all that",
    "The cat found a bright yellow ball\n"
    "It rolled down the long quiet hall\n"
    "It bounced with a hop\n"
    "Then came to a stop\n"
    "And the cat gave a happy small call",
    "So Max gave the cat a big hug\n"
    "And they both had a nap on the rug\n"
    "They dreamed of the park\n"
    "Till the sky turned dark\n"
    "And they both slept as snug as a bug",
]


def test_limerick_pages_pass_limerick_check_but_fail_couplet_check():
    # Line endings (1,2) and (3,4) rhyme on every page, so the limerick
    # check passes. The legacy couplet heuristic pairs PAGE endings
    # (that/call) and sentence endings (none — no periods), and rejects the
    # same text — which is why the pipeline must ask for the limerick check
    # when limericks were requested.
    assert _is_ltr_rhyme_quality_ok(_LIMERICK_PAGES, limericks=True)
    assert not _is_ltr_rhyme_quality_ok(_LIMERICK_PAGES)


def test_limerick_check_accepts_comma_flattened_verse():
    # Observed on 2026-09-12: the model returned each limerick as one line
    # with the five verse lines joined by ", ". Still a limerick.
    flattened = [p.replace("\n", ", ") for p in _LIMERICK_PAGES]
    assert all("\n" not in p for p in flattened)
    assert _is_ltr_rhyme_quality_ok(flattened, limericks=True)


def test_limerick_check_scores_multi_syllable_rhymes():
    # Real model output (2026-09-12) that the first-vowel `_rhyme_key`
    # heuristic rejected: inside/wide, debate/gate, delight/sight, tree/glee.
    pages = [
        "The path was long, the path was wide\n"
        "with a puzzle to solve inside,\n"
        "   where colors mixed and matched with care,\n"
        "   and a hidden code to share,\n"
        "with a pot of gold to abide.",
        "Max found a secret garden gate\n"
        "that opened with a colorful debate,\n"
        "   where flowers of every hue did bloom,\n"
        "   and a sweet fragrance filled the room,\n"
        "with a scent that was simply great.",
        "The garden was full of surprise and delight\n"
        "with a treasure hunt in plain sight,\n"
        "   where clues were hidden with a grin,\n"
        "   and a mysterious map to win,\n"
        "with a thrill and a joyful sight.",
        "Max followed the map with glee\n"
        "that led to a rainbow tree,\n"
        "   where colors of the rainbow did shine,\n"
        "   and a beautiful bird did entwine,\n"
        "with a song that was happy and free.",
    ]
    assert _is_ltr_rhyme_quality_ok(pages, limericks=True)


def test_limerick_check_rejects_prose_pages():
    pages = [
        "Max walked to the park.\nHe saw a dog.\nIt was big.\nHe went home.\nThe end.",
        "The next day Max went again.\nThe dog was there.\nThey played.\nIt was nice.\nMax smiled.",
    ]
    assert not _is_ltr_rhyme_quality_ok(pages, limericks=True)


def test_limerick_check_rejects_empty():
    assert not _is_ltr_rhyme_quality_ok([], limericks=True)
    assert not _is_ltr_rhyme_quality_ok(["", "   "], limericks=True)
