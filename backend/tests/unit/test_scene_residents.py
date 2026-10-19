"""Chunk 4 — scene residents.

Characters who live in a wizard scene: introduced on a first visit, greeted
as old friends on a return visit, never companions and never in a
MUST-appear list.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest

from backend.services.interactive_adventure_prompt_builder import (
    InteractiveAdventurePromptBuilder,
)
from backend.services.scene_residents import (
    SCENE_VISIT_LOOKBACK,
    build_scene_residents_line,
    find_prior_scene_visit,
    known_resident_names,
    normalize_scenario_id,
    normalize_scene_residents,
)
from backend.services.story_service import (
    AdvancedStoryEngine,
    _strip_prompt_heading_labels,
)

GUARDIAN = {
    "name": "the Palette Guardian",
    "what": "a wise old tortoise with a rainbow-striped shell",
    "personality": "patient and kind",
}
DAB = {
    "name": "Dab",
    "what": "a Paint Sprite who carries the colour sky-blue",
    "personality": "bubbly and brave",
}

# Craft words that must never be in the prompt line: the model copies rule
# nouns into prose (PR #454).
_LEAKY_WORDS = ("resident", "npc", "optional cast", "side character")


# ---------------------------------------------------------------------------
# Normalisation
# ---------------------------------------------------------------------------


class TestNormalize:
    def test_one_resident_at_eight_and_under(self):
        assert len(normalize_scene_residents([GUARDIAN, DAB], 8)) == 1
        assert len(normalize_scene_residents([GUARDIAN, DAB], 4)) == 1

    def test_two_residents_from_nine(self):
        third = {**DAB, "name": "Brushstroke"}
        out = normalize_scene_residents([GUARDIAN, DAB, third], 9)
        assert [r["name"] for r in out] == ["the Palette Guardian", "Dab"]

    def test_drops_nameless_duplicates_and_junk(self):
        raw = ["x", {"what": "no name"}, GUARDIAN, {**GUARDIAN}, DAB]
        out = normalize_scene_residents(raw, 12)
        assert [r["name"] for r in out] == ["the Palette Guardian", "Dab"]

    def test_non_list_is_empty(self):
        assert normalize_scene_residents(None, 10) == []
        assert normalize_scene_residents({"name": "x"}, 10) == []

    def test_fields_are_capped(self):
        out = normalize_scene_residents(
            [{"name": "N" * 500, "what": "w" * 500, "personality": "p" * 500}], 10
        )
        assert len(out[0]["name"]) <= 60
        assert len(out[0]["what"]) <= 160
        assert len(out[0]["personality"]) <= 160

    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("vanishing_colors", "vanishing_colors"),
            ("  Crystal_Cavern ", "crystal_cavern"),
            ("../etc", None),
            ("has space", None),
            ("", None),
            (None, None),
            (42, None),
        ],
    )
    def test_scenario_id(self, raw, expected):
        assert normalize_scenario_id(raw) == expected


# ---------------------------------------------------------------------------
# The prompt line itself
# ---------------------------------------------------------------------------


class TestPromptLine:
    def test_empty_without_residents_or_visit(self):
        assert build_scene_residents_line([], "HERO_1") == ""

    def test_first_visit_describes_them_and_never_requires_them(self):
        line = build_scene_residents_line([GUARDIAN, DAB], "HERO_1")
        assert "the Palette Guardian" in line
        assert "rainbow-striped shell" in line
        assert "Dab" in line
        assert "never join HERO_1" in line
        assert "never required" in line
        assert "BEEN HERE BEFORE" not in line

    def test_return_visit_names_who_the_hero_knows(self):
        line = build_scene_residents_line(
            [GUARDIAN, DAB],
            "HERO_1",
            visited_before=True,
            known_names=["the Palette Guardian", "Dab"],
        )
        assert "has visited this place before" in line
        assert "already knows the Palette Guardian and Dab" in line
        assert "old friend" in line

    def test_return_visit_with_nobody_met_is_just_familiar(self):
        line = build_scene_residents_line(
            [GUARDIAN], "HERO_1", visited_before=True, known_names=[]
        )
        assert "feels a little familiar" in line
        assert "already knows" not in line

    def test_no_craft_labels_leak(self):
        line = build_scene_residents_line(
            [GUARDIAN, DAB], "HERO_1", visited_before=True, known_names=["Dab"]
        ).lower()
        for word in _LEAKY_WORDS:
            assert word not in line

    def test_known_names_keep_todays_spelling_and_order(self):
        met = {"dab", "the palette guardian"}
        assert known_resident_names([GUARDIAN, DAB], met) == [
            "the Palette Guardian",
            "Dab",
        ]
        assert known_resident_names([GUARDIAN, DAB], {"dab"}) == ["Dab"]


class TestHeadingCaptionStrip:
    @pytest.mark.parametrize(
        "leaked,expected",
        [
            ("Who lives here: a tortoise waves.", "a tortoise waves."),
            (
                "You smile. Been here before — you know the way.",
                "You smile. you know the way.",
            ),
        ],
    )
    def test_caption_excised(self, leaked, expected):
        assert _strip_prompt_heading_labels(leaked) == expected

    def test_ordinary_prose_untouched(self):
        prose = "You have been here before, and the tortoise knows it."
        assert _strip_prompt_heading_labels(prose) == prose


# ---------------------------------------------------------------------------
# Standard prompt (T1) placement
# ---------------------------------------------------------------------------


class TestStandardPrompt:
    @pytest.fixture
    def engine(self):
        return AdvancedStoryEngine()

    def _prompt(self, engine, line=""):
        return engine.generate_enhanced_prompt(
            character="HERO_1",
            theme="Rainbow World",
            age=10,
            sensory_palette="wet paint",
            companion_characters=[{"name": "Sparky"}],
            scene_residents_line=line,
        )

    def test_absent_when_no_residents(self, engine):
        prompt = self._prompt(engine)
        assert "WHO LIVES HERE" not in prompt
        assert "Palette Guardian" not in prompt

    def test_no_line_leaves_prompt_byte_identical(self, engine):
        baseline = engine.generate_enhanced_prompt(
            character="HERO_1",
            theme="Rainbow World",
            age=10,
            sensory_palette="wet paint",
            companion_characters=[{"name": "Sparky"}],
        )
        assert self._prompt(engine) == baseline

    def test_present_beside_world_bible_before_hero(self, engine):
        line = build_scene_residents_line([GUARDIAN, DAB], "HERO_1")
        prompt = self._prompt(engine, line)
        assert "WHO LIVES HERE" in prompt
        assert prompt.index("**SENSORY PALETTE**") < prompt.index("WHO LIVES HERE")
        assert prompt.index("WHO LIVES HERE") < prompt.index("- **HERO**:")

    def test_residents_never_in_mandatory_checklist(self, engine):
        line = build_scene_residents_line(
            [GUARDIAN, DAB],
            "HERO_1",
            visited_before=True,
            known_names=["the Palette Guardian"],
        )
        prompt = self._prompt(engine, line)
        checklist = next(
            ln for ln in prompt.splitlines() if "Checklist of names to include" in ln
        )
        assert "Sparky" in checklist
        assert "Palette Guardian" not in checklist
        assert "Dab" not in checklist
        companions_block = prompt.split("- **COMPANIONS**:")[1].split(
            "- **CUSTOM REQUESTS**"
        )[0]
        assert "Palette Guardian" not in companions_block


# ---------------------------------------------------------------------------
# Pick-a-Path prompts — world-facts line, never the Companion Contract
# ---------------------------------------------------------------------------


class TestPickAPathPrompts:
    def _opening(self, **kw):
        return InteractiveAdventurePromptBuilder.build_opening_prompt(
            child_name="HERO_1",
            age=10,
            length="short",
            theme="Rainbow World",
            tone="whimsical",
            **kw,
        )

    def test_opening_absent_without_residents(self):
        assert "WHO LIVES HERE" not in self._opening()

    def test_opening_without_residents_is_byte_identical(self):
        assert self._opening() == self._opening(scene_residents=[])

    def test_opening_has_line_but_no_companion_contract(self):
        prompt = self._opening(scene_residents=[GUARDIAN, DAB])
        assert "WHO LIVES HERE" in prompt
        assert "the Palette Guardian" in prompt
        assert "Companion Contract" not in prompt
        assert "MUST appear by name" not in prompt
        # Solo rule still holds: nobody joins the hero.
        assert "nobody travels with the hero" in prompt

    def test_opening_with_companion_keeps_residents_out_of_contract(self):
        prompt = self._opening(
            scene_residents=[GUARDIAN],
            companions=[{"name": "Sparky", "role": "companion"}],
        )
        companions_line = next(
            ln for ln in prompt.splitlines() if ln.startswith("- **COMPANIONS**")
        )
        assert "Sparky" in companions_line
        assert "Palette Guardian" not in companions_line

    def test_opening_return_visit(self):
        prompt = self._opening(
            scene_residents=[GUARDIAN],
            scene_visited_before=True,
            scene_known_names=["the Palette Guardian"],
        )
        assert "already knows the Palette Guardian" in prompt

    def test_continuation_carries_the_same_line(self):
        ctx = {
            "title": "T",
            "theme": "Rainbow World",
            "tone": "whimsical",
            "length": "short",
            "age": 10,
            "character": {"name": "HERO_1"},
            "companions": [],
            "scene_residents": [GUARDIAN],
            "scene_visited_before": True,
            "scene_known_names": ["the Palette Guardian"],
        }
        prompt = InteractiveAdventurePromptBuilder.build_continuation_prompt(
            story_context=ctx,
            selected_choice="Look around",
            current_segment_number=1,
        )
        assert "WHO LIVES HERE" in prompt
        assert "already knows the Palette Guardian" in prompt
        assert "MUST appear by name" not in prompt

    def test_continuation_without_residents_has_no_line(self):
        ctx = {
            "title": "T",
            "theme": "x",
            "tone": "whimsical",
            "length": "short",
            "age": 10,
            "character": {"name": "HERO_1"},
        }
        prompt = InteractiveAdventurePromptBuilder.build_continuation_prompt(
            story_context=ctx, selected_choice="Go", current_segment_number=1
        )
        assert "WHO LIVES HERE" not in prompt


# ---------------------------------------------------------------------------
# Return-visit lookup against the DB
# ---------------------------------------------------------------------------


class TestPriorSceneVisit:
    def _user_and_character(self, user_id, char_id):
        from backend.database import db
        from backend.models import Character, User

        db.session.add(
            User(
                id=user_id,
                username=f"u_{user_id}",
                email=f"{user_id}@example.com",
                password_hash="x",
                subscription_tier="free",
                role="user",
            )
        )
        db.session.add(Character(id=char_id, user_id=user_id, name="Luna", age=10))
        db.session.commit()

    def _story(self, user_id, char_id, idx, content):
        from backend.database import db
        from backend.models.story import Story

        db.session.add(
            Story(
                id=f"s_{char_id}_{idx}",
                user_id=user_id,
                character_id=char_id,
                title="X",
                theme="T",
                themes=["x"],
                characters_featured=[],
                content=content,
                created_at=datetime.now(timezone.utc) - timedelta(days=idx),
            )
        )
        db.session.commit()

    def test_no_character_or_scene_is_first_visit(self, app):
        with app.app_context():
            assert find_prior_scene_visit(None, "vanishing_colors") == (False, set())
            assert find_prior_scene_visit("c", None) == (False, set())

    def test_first_visit_when_no_matching_story(self, app):
        with app.app_context():
            self._user_and_character("sv_u1", "sv_c1")
            self._story("sv_u1", "sv_c1", 1, {"scenario_id": "crystal_cavern"})
            self._story("sv_u1", "sv_c1", 2, None)  # legacy row, no content
            visited, met = find_prior_scene_visit("sv_c1", "vanishing_colors")
            assert visited is False
            assert met == set()

    def test_return_visit_reports_who_was_met(self, app):
        with app.app_context():
            self._user_and_character("sv_u2", "sv_c2")
            self._story(
                "sv_u2",
                "sv_c2",
                1,
                {"scenario_id": "vanishing_colors", "scene_residents": [GUARDIAN]},
            )
            visited, met = find_prior_scene_visit("sv_c2", "vanishing_colors")
            assert visited is True
            assert met == {"the palette guardian"}

    def test_other_characters_history_does_not_count(self, app):
        with app.app_context():
            self._user_and_character("sv_u3", "sv_c3")
            self._user_and_character("sv_u3b", "sv_c3b")
            self._story(
                "sv_u3b",
                "sv_c3b",
                1,
                {"scenario_id": "vanishing_colors", "scene_residents": [GUARDIAN]},
            )
            assert find_prior_scene_visit("sv_c3", "vanishing_colors")[0] is False

    def test_visit_older_than_lookback_is_forgotten(self, app):
        with app.app_context():
            self._user_and_character("sv_u4", "sv_c4")
            # The matching visit is the oldest; LOOKBACK newer stories elsewhere.
            for i in range(SCENE_VISIT_LOOKBACK):
                self._story("sv_u4", "sv_c4", i, {"scenario_id": "crystal_cavern"})
            self._story(
                "sv_u4",
                "sv_c4",
                SCENE_VISIT_LOOKBACK + 1,
                {"scenario_id": "vanishing_colors", "scene_residents": [GUARDIAN]},
            )
            assert find_prior_scene_visit("sv_c4", "vanishing_colors")[0] is False

    def test_pick_a_path_visit_counts(self, app):
        from backend.database import db
        from backend.models import InteractiveStory, StoryState

        with app.app_context():
            self._user_and_character("sv_u5", "sv_c5")
            story = InteractiveStory(
                id="pap_sv_c5",
                user_id="sv_u5",
                character_id="sv_c5",
                title="T",
                theme="T",
                tone="whimsical",
                length="short",
                age=10,
            )
            db.session.add(story)
            db.session.flush()
            db.session.add(
                StoryState(
                    id="pap_state_sv_c5",
                    story_id=story.id,
                    additional_state={
                        "scenario_id": "vanishing_colors",
                        "scene_residents": [DAB],
                    },
                )
            )
            db.session.commit()
            visited, met = find_prior_scene_visit("sv_c5", "vanishing_colors")
            assert visited is True
            assert met == {"dab"}


# ---------------------------------------------------------------------------
# Pick-a-Path service: persisted on the opening, recalled on the next story
# ---------------------------------------------------------------------------


_SEGMENT = json.dumps(
    {
        "title": "Rainbow Day",
        "content": "You step onto the bouncy road.",
        "is_ending": False,
        "inventory": [],
        "story_state": {"location": "Road", "goal": "Find blue", "key_clues": []},
        "choices": [
            {"id": "choice_1", "text": "Bounce ahead"},
            {"id": "choice_2", "text": "Wave hello"},
        ],
        "image_description": "A rainbow road",
    }
)


def test_pick_a_path_second_visit_greets_old_friend(app, test_user, test_character):
    from backend.database import db
    from backend.models import InteractiveStory
    from backend.services.interactive_adventure_service import (
        InteractiveAdventureService,
    )

    prompts: list[str] = []

    def fake_generate(self, prompt):
        prompts.append(prompt)
        return _SEGMENT

    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        db.session.commit()
        with patch.object(InteractiveAdventureService, "_generate_text", fake_generate):
            service = InteractiveAdventureService()
            first = service.create_story(
                user_id=test_user.id,
                character_id=test_character.id,
                theme="Rainbow World",
                tone="whimsical",
                length="short",
                scenario_id="vanishing_colors",
                scene_residents=[GUARDIAN, DAB],  # age 7 -> capped to one
            )
            second = service.create_story(
                user_id=test_user.id,
                character_id=test_character.id,
                theme="Rainbow World",
                tone="whimsical",
                length="short",
                scenario_id="vanishing_colors",
                scene_residents=[GUARDIAN],
            )

        assert "WHO LIVES HERE" in prompts[0]
        assert "Dab" not in prompts[0]
        assert "BEEN HERE BEFORE" not in prompts[0]
        assert "already knows the Palette Guardian" in prompts[-1]

        story = db.session.get(InteractiveStory, first["story_id"])
        extra = story.state.additional_state
        assert extra["scenario_id"] == "vanishing_colors"
        assert [r["name"] for r in extra["scene_residents"]] == ["the Palette Guardian"]

        # Continuation context carries the same people forward.
        ctx = service._build_story_context(
            db.session.get(InteractiveStory, second["story_id"])
        )
        assert ctx["scene_visited_before"] is True
        assert ctx["scene_known_names"] == ["the Palette Guardian"]

        for sid in (first["story_id"], second["story_id"]):
            db.session.delete(db.session.get(InteractiveStory, sid))
        db.session.commit()
