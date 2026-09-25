"""Unit tests for the rhyme-detection helpers used by Learning-to-Read mode.

These were previously colocated with the `_parse_custom_elements` /
`_find_missing_custom_elements` tests in `test_custom_elements.py`. The
custom-elements tests were removed in MT-196 B3 (the helpers themselves
were deleted after security commit 61b87a32 retired verbatim enforcement
for child-safety reasons), but the rhyme helpers remain live in
`story_tasks._is_ltr_rhyme_quality_ok` and are still exercised here.
"""

import pytest

from backend.tasks.story_tasks import (
    _is_limerick_page_ok,
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


def test_ltr_rhyme_quality_accepts_multi_syllable_couplets():
    # MT-438: the Easy Reader check scored on the FIRST vowel, so a page
    # ending in a multi-syllable word never matched its rhyme ("inside" →
    # "insid" vs "wide" → "id"). Correctly rhyming stories were rejected,
    # burning both retries and the extra generation on every age-8 story.
    pages = [
        "Luna found a door that was tall and wide.",
        "A small sleepy fox was curled up inside.",
        "They walked to the creaky garden gate.",
        "The fox had a plan they would celebrate.",
    ]
    assert _is_ltr_rhyme_quality_ok(pages)


def test_ltr_rhyme_quality_accepts_multi_syllable_within_page_rhyme():
    # Same defect on the within-page sentence-ending path.
    pages = [
        "Luna stirred the soup with a spoon. Then she found a red balloon.",
        "The fox ran up a sandy dune. He waved at the pale white moon.",
        "They looked at the hills all around. Then sat on the cool soft ground.",
        "A tiny mouse began to seek. They heard a happy little squeak.",
    ]
    assert _is_ltr_rhyme_quality_ok(pages)


# The two age-8 stories MT-438 reproduced against `60bf10cd`, reduced to their
# page-ending words. Both were rejected by the old check and regenerated twice
# before shipping unchanged. One-line pages carry no sentence punctuation, so
# the within-page fallback never fires and the couplet path is what is scored.
_MT438_STORY_ONE_ENDINGS = [
    "sun",
    "fun",
    "sound",
    "ground",
    "air",
    "compare",
    "deep",
    "leap",
    "free",
    "glee",
]

_MT438_STORY_TWO_ENDINGS = [
    "sky",
    "spry",
    "glee",
    "see",
    "free",
    "carefree",
    "ease",
    "breeze",
    "peace",
    "release",
]


def _pages_ending_in(words):
    return [f"Luna and the fox went out to play and found the {w}" for w in words]


def test_mt438_reproduced_story_one_now_passes():
    assert _is_ltr_rhyme_quality_ok(_pages_ending_in(_MT438_STORY_ONE_ENDINGS))


def test_mt438_reproduced_story_two_now_passes():
    # Passes on 3 of 5 pairs, which meets the 0.6 ratio exactly. The two that
    # still miss are spelling-to-sound gaps the tail does not model: ease/breeze
    # (final s is voiced, so "e:s" vs "e:z") and peace/release (soft c, so "e:c"
    # vs "e:s"). Tracked as MT-448 — if that is fixed this becomes 5 of 5, and
    # if the ratio is ever raised above 0.6 this story starts failing again.
    assert _is_ltr_rhyme_quality_ok(_pages_ending_in(_MT438_STORY_TWO_ENDINGS))


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


@pytest.mark.parametrize(
    "word_a, word_b",
    [
        ("moon", "tune"),  # oo / u-silent-e
        ("spoon", "balloon"),
        ("dune", "moon"),
        ("seek", "squeak"),  # ee / ea
        ("peel", "squeal"),
        ("plane", "rain"),  # a-silent-e / ai
        ("high", "sky"),  # igh / y
        ("light", "bite"),
        ("boat", "note"),  # oa / o-silent-e
        ("new", "blue"),  # ew / ue
        ("back", "yak"),  # ck / k
        ("tall", "small"),
        ("around", "ground"),
        ("tree", "sea"),
        ("box", "socks"),  # x / cks
        ("specs", "checks"),
        ("quick", "stick"),  # qu is not a vowel
    ],
)
def test_rhyme_hears_long_vowels_across_spellings(word_a, word_b):
    # 2026-09-13 probe: the spelling-only tail rejected most of the real
    # rhymes gpt-5-mini wrote (moon/tune, seek/squeak, dune/moon), and the
    # model's workaround was to rhyme a word with itself.
    assert _words_rhyme(word_a, word_b)


@pytest.mark.parametrize(
    "word_a, word_b",
    [
        ("moon", "sun"),  # long u vs short u
        ("bite", "bit"),
        ("plane", "plan"),
        ("spun", "drum"),
        ("boing", "ploy"),
        ("park", "dog"),
        ("home", "big"),
    ],
)
def test_rhyme_keeps_short_vowels_apart_from_long(word_a, word_b):
    assert not _words_rhyme(word_a, word_b)


def test_limerick_page_survives_one_weak_b_rhyme():
    # Real after-probe verse (2026-09-13): A-lines and line 5 rhyme, the
    # short B-lines miss (hat/pan). Two of three checks pass: still a limerick.
    page = (
        "Theo mixed up a bowl for a cake\n"
        "and he carried it down to the lake.\n"
        "He wore a tall hat\n"
        "and he brought a big pan\n"
        "then he flipped the whole thing like a flake."
    )
    assert _is_limerick_page_ok(page)


def test_limerick_page_needs_more_than_one_rhyming_pair():
    # One couplet on top of three prose lines is not a limerick.
    page = (
        "Max went to the shop for a hat\n"
        "and he bought one and also a mat.\n"
        "Then he walked home.\n"
        "He ate his lunch.\n"
        "It was a nice day."
    )
    assert not _is_limerick_page_ok(page)
