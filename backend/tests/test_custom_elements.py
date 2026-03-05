from backend.tasks.story_tasks import (
    _parse_custom_elements,
    _find_missing_custom_elements,
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
