"""
Unit tests for tonight's-feeling and comfort-item support in the standalone
bedtime prompt (_build_bedtime_prompt in backend/services/story_service.py).

Before this, a parent's feeling ("missing grandma") reached the task as
feelings_prompt but the bedtime builder never received it, so bedtime
stories ignored it while the standard path honoured it.
"""

from backend.services.story_service import (
    _build_bedtime_feelings_block,
    _build_bedtime_prompt,
)


def _prompt(**kw):
    return _build_bedtime_prompt(character_name="Maya", age=6, theme="Bedtime", **kw)


def test_prompt_unchanged_without_feeling_or_comfort_item():
    # Age 10: ages 8 and under get a randomly rotated classic opener, which
    # would make two builds differ for reasons unrelated to this feature.
    def build(**kw):
        return _build_bedtime_prompt(
            character_name="Zara", age=10, theme="Bedtime", **kw
        )

    base = build()
    assert "TONIGHT'S FEELING" not in base
    assert "COMFORT ITEM" not in base
    # Explicit None/empty must produce exactly the same prompt as omitting them.
    assert build(feelings_prompt=None, comfort_item=None) == base
    assert build(feelings_prompt="", comfort_item="") == base


def test_feeling_reaches_the_prompt():
    p = _prompt(feelings_prompt="missing grandma")
    assert "TONIGHT'S FEELING" in p
    assert "missing grandma" in p
    # The feeling sits before the rules so it frames the whole story.
    assert p.index("missing grandma") < p.index("BEDTIME STORY RULES")


def test_bedtime_feeling_is_held_not_solved():
    block = _build_bedtime_feelings_block("scared of the dark", 6, "Maya")
    assert "Do not turn the feeling into a quest" in block
    assert "Never state a lesson" in block


def test_comfort_item_reaches_the_prompt():
    p = _prompt(comfort_item="a blue blanket named Bloo")
    assert "COMFORT ITEM: Maya sleeps with a blue blanket named Bloo." in p


def test_feeling_words_scale_with_age():
    sprout = _build_bedtime_feelings_block("scared of the dark", 4, "Theo")
    explorer = _build_bedtime_feelings_block("scared of the dark", 7, "Maya")
    creator = _build_bedtime_feelings_block("had a fight with a friend", 13, "Eli")
    assert "4-5 year old" in sprout
    assert "body clue" in explorer and "4-5 year old" not in explorer
    assert "mixed or complicated" in creator


def test_empty_feeling_gives_empty_block():
    assert _build_bedtime_feelings_block(None, 6, "Maya") == ""
    assert _build_bedtime_feelings_block("", 6, "Maya") == ""
