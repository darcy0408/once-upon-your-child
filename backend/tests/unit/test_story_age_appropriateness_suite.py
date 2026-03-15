import itertools
import json
from unittest.mock import MagicMock

import pytest

from backend.services.story_service import (
    AGE_CONSTRAINTS,
    AdvancedStoryEngine,
    _build_learning_to_read_prompt,
    _build_rhyme_time_prompt,
    _get_age_band,
)
from backend.tasks.story_tasks import _is_ltr_rhyme_quality_ok, generate_story_task


AGE_BANDS = [4, 6, 9, 12, 14, 17, 25]

SCENARIO_CATEGORIES = [
    {
        "category": "Magical Worlds",
        "theme": "The Doorway Between Seasons",
        "conflict_hook": "A glitch in the magic doors is mixing up winter and summer!",
        "sensory_palette": "Swirling leaves, changing temperatures, the smell of fresh rain and autumn wood.",
        "world_bible_marker": "A circular hall of four ornate doors",
    },
    {
        "category": "Real-Life Heroes",
        "theme": "The Brave Friend",
        "conflict_hook": "A group of kids is playing a fun game, but asking to join feels like climbing a giant mountain.",
        "sensory_palette": "Happy laughter, the sound of running feet, the smell of fresh cut grass.",
        "world_bible_marker": "school playground with chalk lines",
    },
]


def _page_json(*pages: str) -> str:
    return json.dumps(
        {
            "title": "Test Story",
            "wisdom_gem": "Keep going.",
            "pages": [{"text": page} for page in pages],
        }
    )


def _repeat_sentence(sentence: str, repeat_count: int) -> str:
    return " ".join(sentence for _ in range(repeat_count))


class TestPromptContractsAcrossAgesAndCategories:
    @pytest.fixture
    def engine(self):
        return AdvancedStoryEngine()

    @pytest.mark.parametrize(
        ("age", "scene"),
        [
            pytest.param(age, scene, id=f"{_get_age_band(age)}_{scene['category'].replace(' ', '_').lower()}")
            for age, scene in itertools.product(AGE_BANDS, SCENARIO_CATEGORIES)
        ],
    )
    def test_standard_prompt_carries_scene_companions_and_length_contract(self, engine, age, scene):
        prompt = engine.generate_enhanced_prompt(
            character="Avery",
            theme=scene["theme"],
            companion_pets=[{"name": "Pip", "species": "fox"}],
            companion_characters=[{"name": "Nova", "signaturePower": "Light Step"}],
            additional_characters=[{"name": "Jordan"}],
            conflict_hook=scene["conflict_hook"],
            sensory_palette=scene["sensory_palette"],
            world_bible=scene["world_bible_marker"],
            custom_elements="ride a dragon, make friends",
            story_length="standard",
            age=age,
        )

        band = _get_age_band(age)
        low, high = AGE_CONSTRAINTS[band]["regular"]["medium"]

        assert scene["theme"] in prompt
        assert scene["conflict_hook"] in prompt
        assert scene["sensory_palette"] in prompt
        assert scene["world_bible_marker"] in prompt
        assert "Pip" in prompt
        assert "Nova" in prompt
        assert "Jordan" in prompt
        assert "ride a dragon" in prompt
        assert "make friends" in prompt
        assert f"{low}-{high}" in prompt
        assert "Every character/pet listed above MUST be in the story" in prompt
        assert "include it as a concrete scene or outcome" in prompt

    @pytest.mark.parametrize(
        ("age", "expected_markers", "forbidden_markers"),
        [
            pytest.param(
                5,
                ["LEARN TO READ story", "Dr. Seuss", "AABB", "Every page MUST end with a clear rhyming word"],
                ["Each page = one complete limerick"],
                id="age5_easy_reader_dr_seuss",
            ),
            pytest.param(
                6,
                ["LEARN TO READ story", "Dr. Seuss", "anapestic rhythm", "AABB"],
                ["Each page = one complete limerick"],
                id="age6_easy_reader_dr_seuss",
            ),
            pytest.param(
                7,
                ["funny, connected limericks", "AABBA rhyme scheme", "Each page is exactly one limerick"],
                ["Dr. Seuss"],
                id="age7_easy_reader_switches_to_limerick",
            ),
            pytest.param(
                10,
                ["funny, connected limericks", "AABBA rhyme scheme", "Each page is exactly one limerick"],
                ["Dr. Seuss"],
                id="age10_easy_reader_stays_limerick",
            ),
        ],
    )
    def test_learning_to_read_style_progression(self, age, expected_markers, forbidden_markers):
        prompt = _build_learning_to_read_prompt(
            character_name="Avery",
            theme="Adventure",
            age=age,
            character_details={"pets": [{"name": "Pip", "species": "fox"}]},
            companion_characters=[{"name": "Nova"}],
            story_length="standard",
            custom_elements="ride a dragon",
        )

        for marker in expected_markers:
            assert marker in prompt
        for marker in forbidden_markers:
            assert marker not in prompt

        assert "Pip" in prompt
        assert "Nova" in prompt
        assert "ride a dragon" in prompt

    @pytest.mark.parametrize(
        ("age", "expected_markers", "forbidden_markers"),
        [
            pytest.param(
                4,
                ["Write a full rhyming story", "Very short sentences (4-6 words per line)", "Consistent AABB rhyme scheme"],
                [],
                id="age4_rhyme_time_simple",
            ),
            pytest.param(
                7,
                ["fun, bouncy rhyming story", "Use AABBA limerick or simple AABB couplets"],
                [],
                id="age7_rhyme_time_bouncy",
            ),
            pytest.param(
                10,
                ["ballad-style rhyming story", "No sing-song bouncy limericks", "Use ABCB ballad scheme or rhyming couplets"],
                ["free verse OR sonnet"],
                id="age10_rhyme_time_ballad",
            ),
            pytest.param(
                12,
                ["narrative poem or epic ballad", "No limericks", "Use ABAB or ABCB narrative ballad form"],
                ["free verse OR sonnet"],
                id="age12_rhyme_time_narrative_poem",
            ),
            pytest.param(
                14,
                ["Write a sophisticated poem", "Free verse OR sonnet", "No limericks"],
                ["Captain Underpants energy"],
                id="age14_rhyme_time_poetry",
            ),
        ],
    )
    def test_rhyme_time_style_progression(self, age, expected_markers, forbidden_markers):
        prompt = _build_rhyme_time_prompt(
            character_name="Avery",
            theme="Adventure",
            age=age,
            character_details={"strengths": ["brave"]},
            companion_pets=[{"name": "Pip", "species": "fox"}],
            companion_characters=[{"name": "Nova"}],
            extra_characters=["Jordan"],
            story_length="standard",
            custom_elements="ride a dragon",
        )

        for marker in expected_markers:
            assert marker in prompt
        for marker in forbidden_markers:
            assert marker not in prompt

        assert "Pip" in prompt
        assert "Nova" in prompt
        assert "Jordan" in prompt


class TestStoryGenerationRoutingAndValidation:
    def test_generate_story_route_forwards_scene_and_companion_payload(self, client, auth_headers, mocker):
        task_apply = mocker.patch("backend.routes.story_routes.generate_story_task.apply")
        eager_result = MagicMock()
        eager_result.get.return_value = {
            "status": "complete",
            "story": {
                "title": "Avery and the Forest Gate",
                "story_text": "Avery met Pip and Nova in the bamboo forest.",
                "theme": "The Doorway Between Seasons",
                "wisdom_gem": "Keep going.",
                "pages": ["Avery met Pip and Nova in the bamboo forest."],
            },
        }
        task_apply.return_value = eager_result

        payload = {
            "character": "Avery",
            "age": 9,
            "theme": "The Doorway Between Seasons",
            "story_length": "standard",
            "companion_pets": [{"name": "Pip", "species": "fox"}],
            "companion_characters": [{"name": "Nova", "signaturePower": "Light Step"}],
            "customElements": "ride a dragon, make friends",
            "conflictHook": "A secret path opens in the bamboo forest.",
            "sensoryPalette": "Cool mist, creaking wood, moss underfoot.",
            "worldBible": "Bamboo forest paths loop around moon gates.",
        }

        response = client.post("/generate-story", json=payload, headers=auth_headers)

        assert response.status_code == 200
        kwargs = task_apply.call_args.kwargs["kwargs"]
        assert kwargs["theme"] == payload["theme"]
        assert kwargs["age"] == payload["age"]
        assert kwargs["story_length"] == payload["story_length"]
        assert kwargs["companion_pets"] == payload["companion_pets"]
        assert kwargs["companion_characters"] == payload["companion_characters"]
        assert kwargs["custom_elements"] == payload["customElements"]
        assert kwargs["conflict_hook"] == payload["conflictHook"]
        assert kwargs["sensory_palette"] == payload["sensoryPalette"]
        assert kwargs["world_bible"] == payload["worldBible"]

    def test_task_retries_when_story_omits_companions_or_custom_requests(self, app, mocker):
        mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)

        invalid_story = _page_json(
            _repeat_sentence(
                "Avery crossed the bamboo forest and solved the puzzle with careful steps.",
                40,
            )
        )
        valid_story = _page_json(
            _repeat_sentence(
                "Avery crossed the bamboo forest with Pip and Nova, chose to ride a dragon, and stopped to make friends beside the moon gate.",
                40,
            )
        )

        story_generator = mocker.patch(
            "backend.tasks.story_tasks._generate_story_text",
            side_effect=[invalid_story, valid_story],
        )

        result = generate_story_task.apply(
            kwargs={
                "character": "Avery",
                "theme": "Adventure",
                "user_id": "test-user",
                "age": 7,
                "story_length": "standard",
                "companion_pets": [{"name": "Pip", "species": "fox"}],
                "companion_characters": [{"name": "Nova"}],
                "custom_elements": "ride a dragon, make friends",
                "conflict_hook": "A path opens in the bamboo forest.",
                "sensory_palette": "Cool mist and pine needles.",
                "world_bible": "The bamboo forest has moon gates and echoing bridges.",
            }
        ).get()

        story_text = result["story"]["story_text"]

        assert story_generator.call_count == 2
        assert "Pip" in story_text
        assert "Nova" in story_text
        assert "ride a dragon" in story_text
        assert "make friends" in story_text
        assert "bamboo forest" in story_text
        assert len(story_text.split()) >= 500

    def test_task_retries_when_easy_reader_output_does_not_rhyme(self, app, mocker):
        mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)

        non_rhyming_story = _page_json(
            "Avery can hop to the hill.",
            "Avery can wave to the pond.",
            "Pip can run to the log.",
            "Nova can clap by the gate.",
        )
        rhyming_story = _page_json(
            "Avery and Pip pat the cat and make friends like that.",
            "Nova and Avery tip the hat and make friends like that.",
            "They run in the sun and make friends for fun.",
            "They laugh when the day feels fun and make friends in the sun.",
        )

        story_generator = mocker.patch(
            "backend.tasks.story_tasks._generate_story_text",
            side_effect=[non_rhyming_story, rhyming_story],
        )

        result = generate_story_task.apply(
            kwargs={
                "character": "Avery",
                "theme": "Adventure",
                "user_id": "test-user",
                "age": 5,
                "learning_to_read_mode": True,
                "story_length": "standard",
                "companion_pets": [{"name": "Pip", "species": "fox"}],
                "companion_characters": [{"name": "Nova"}],
                "custom_elements": "make friends",
            }
        ).get()

        assert story_generator.call_count == 2
        assert _is_ltr_rhyme_quality_ok(result["story"]["pages"])
        assert result["story"]["learning_to_read_mode"] is True
