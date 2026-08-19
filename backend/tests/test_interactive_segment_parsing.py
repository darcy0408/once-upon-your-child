"""Regression tests for InteractiveAdventureService._parse_segment_response.

Prod, 2026-08-19: a reader on iOS made the first choice of an interactive
adventure and got an error. Sentry (STORY-WEAVER-BACKEND-V) recorded
"Failed to parse JSON response: Invalid control character at: line 6 column
647" from continue_interactive_story_endpoint.

Cause: the parser tried several cleanup passes but every attempt called
json.loads in strict mode, which rejects literal control characters inside
string values. Story prose is written with real newlines between paragraphs and
models emit them unescaped, so a perfectly good segment was thrown away and the
reader's choice failed.

The parser is a staticmethod with no I/O, so these run fast and never touch a
provider — deliberately, since the six-band interactive test has burned real
API calls in CI before.
"""

from __future__ import annotations

import json

import pytest

from backend.services.interactive_adventure_service import InteractiveAdventureService

parse = InteractiveAdventureService._parse_segment_response


def test_accepts_literal_newlines_inside_story_prose():
    """The exact shape that broke prod: unescaped newlines between paragraphs."""
    raw = (
        "{\n"
        '  "content": "Mira stepped onto the bridge.\n\n'
        'Below her, the river answered.",\n'
        '  "choices": [{"id": "a", "text": "Cross"}]\n'
        "}"
    )
    with pytest.raises(json.JSONDecodeError):
        json.loads(raw)  # proves the input really is strict-invalid

    data = parse(raw)
    assert "Mira stepped onto the bridge." in data["content"]
    # The paragraph break is content, not noise — it must survive the parse.
    assert "\n\n" in data["content"]
    assert data["choices"][0]["text"] == "Cross"


def test_accepts_tabs_and_carriage_returns_in_prose():
    raw = '{"content": "Line one.\r\n\tIndented beat.", "choices": []}'
    data = parse(raw)
    assert "Indented beat." in data["content"]


def test_still_strips_markdown_code_fences():
    raw = '```json\n{"content": "Fenced.\nWith a break.", "choices": []}\n```'
    data = parse(raw)
    assert data["content"].startswith("Fenced.")


def test_still_repairs_trailing_commas():
    raw = '{"content": "Ends with a comma.\nSecond line.", "choices": [],}'
    data = parse(raw)
    assert data["choices"] == []


def test_genuinely_malformed_json_still_raises():
    """strict=False relaxes control characters only — not broken syntax."""
    with pytest.raises(json.JSONDecodeError):
        parse('{"content": "unterminated')


def test_empty_response_still_raises():
    with pytest.raises(json.JSONDecodeError):
        parse("   ")
