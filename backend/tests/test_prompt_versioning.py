"""Tests for backend.services.prompt_versioning (F-01 / MT-187).

The resolver must:
  - Return the right template_id for each (mode, age) cell.
  - Return a stable 16-char hex hash that doesn't change between calls.
  - Fall back to T1_STANDARD on unknown / malformed input rather than raise
    (persistence must never break story generation).
"""

from __future__ import annotations

import re

import pytest

from backend.services.prompt_versioning import resolve

_HEX16 = re.compile(r"^[0-9a-f]{16}$")


@pytest.mark.parametrize(
    "mode, age, expected_id",
    [
        ("standard", 4, "T1_STANDARD"),
        ("standard", 30, "T1_STANDARD"),
        ("bedtime", 6, "T5_BEDTIME"),
        ("rhyme_time", 4, "T4_RHYME_TIME"),
        ("ltr", 4, "T3_LTR_SEUSSIAN"),  # ages <=5 CVC branch
        ("ltr", 6, "T3_LTR_SEUSSIAN"),  # age-6 Dr Seuss branch
        ("ltr", 7, "T2_LTR_LIMERICK"),  # limerick band lower edge
        ("ltr", 12, "T2_LTR_LIMERICK"),  # limerick band upper edge
        ("ltr", 13, "T3_LTR_SEUSSIAN"),  # 13+ prose branch (catch-all id)
        ("superhero", 4, "T6_SUPERHERO_SPROUT"),
        ("superhero", 5, "T6_SUPERHERO_SPROUT"),
        ("superhero", 6, "T7_SUPERHERO_EXPLORER"),
        ("superhero", 8, "T7_SUPERHERO_EXPLORER"),
        ("superhero", 9, "T8_SUPERHERO_ADVENTURER"),  # Adventurer lower edge
        ("superhero", 11, "T8_SUPERHERO_ADVENTURER"),
        ("superhero", 12, "T8_SUPERHERO_ADVENTURER"),  # Adventurer upper edge
        ("superhero", 13, "T9_SUPERHERO_CREATOR"),  # Creator lower edge
        ("superhero", 14, "T9_SUPERHERO_CREATOR"),  # Creator upper edge
        ("superhero", 15, "T10_ANTIHERO_ADOLESCENT"),  # Adolescent lower edge
        ("superhero", 17, "T10_ANTIHERO_ADOLESCENT"),  # Adolescent upper edge
        ("superhero", 18, "T9_SUPERHERO_CREATOR"),  # 18+ has no Adult template;
        # routes to Creator, mirroring PromptService.build_story_prompt.
    ],
)
def test_resolve_template_ids(mode, age, expected_id):
    tid, h = resolve(mode=mode, age=age)
    assert tid == expected_id
    assert _HEX16.match(h), f"revision_hash {h!r} not a 16-char hex string"


def test_resolve_unknown_mode_defaults_to_standard():
    tid, h = resolve(mode="not_a_real_mode", age=7)
    assert tid == "T1_STANDARD"
    assert _HEX16.match(h)


def test_resolve_none_age_is_safe():
    # Anonymous / metadata-stripped requests can land here with no age.
    tid, h = resolve(mode="superhero", age=None)
    assert tid == "T6_SUPERHERO_SPROUT"  # default branch
    assert _HEX16.match(h)


def test_resolve_garbage_age_is_safe():
    tid, h = resolve(mode="ltr", age="not-an-int")  # type: ignore[arg-type]
    # Falls into the non-limerick catch-all because the age can't be coerced.
    assert tid == "T3_LTR_SEUSSIAN"
    assert _HEX16.match(h)


def test_revision_hash_is_stable():
    # Two calls must return byte-identical hashes — the source is captured
    # once at import time, not recomputed per call.
    first = resolve(mode="superhero", age=4)
    second = resolve(mode="superhero", age=4)
    assert first == second


def test_distinct_templates_have_distinct_hashes():
    # Different builders should hash differently; if two collapse to the same
    # hash, attribution loses precision.
    bedtime = resolve(mode="bedtime", age=8)[1]
    rhyme = resolve(mode="rhyme_time", age=8)[1]
    superhero_sprout = resolve(mode="superhero", age=4)[1]
    superhero_creator = resolve(mode="superhero", age=13)[1]
    standard = resolve(mode="standard", age=8)[1]
    assert len({bedtime, rhyme, superhero_sprout, superhero_creator, standard}) == 5
