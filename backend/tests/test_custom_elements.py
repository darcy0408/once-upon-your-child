from backend.tasks.story_tasks import (
    _parse_custom_elements,
    _find_missing_custom_elements,
    _is_ltr_rhyme_quality_ok,
    _words_rhyme,
    MAX_CUSTOM_ELEMENTS,
    MAX_CUSTOM_ELEMENT_LENGTH,
)


def test_parse_custom_elements_splits_and_preserves_quotes():
    raw = 'talking tree, "rainbow river", brave knight\nmagic hat'
    elements = _parse_custom_elements(raw)
    assert elements == ["talking tree", "rainbow river", "brave knight", "magic hat"]


def test_parse_custom_elements_caps_count_and_length():
    raw = ",".join([f"element-{i}" for i in range(MAX_CUSTOM_ELEMENTS + 3)])
    elements = _parse_custom_elements(raw)
    assert len(elements) == MAX_CUSTOM_ELEMENTS

    long_item = "x" * (MAX_CUSTOM_ELEMENT_LENGTH + 10)
    elements = _parse_custom_elements(long_item)
    assert len(elements[0]) == MAX_CUSTOM_ELEMENT_LENGTH


def test_find_missing_custom_elements_case_and_whitespace():
    required = ["talking tree", "magic hat"]
    story = "A Talking   Tree waved kindly. The magic hat sparkled."
    missing = _find_missing_custom_elements(required, story)
    assert missing == []


def test_find_missing_custom_elements_reports_missing():
    required = ["talking tree", "magic hat"]
    story = "The talking tree hummed."
    missing = _find_missing_custom_elements(required, story)
    assert missing == ["magic hat"]


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
