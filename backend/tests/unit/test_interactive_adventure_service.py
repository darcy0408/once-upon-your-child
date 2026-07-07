import json
import uuid
from unittest.mock import MagicMock, patch

import pytest

from backend.database import db
from backend.models import (
    InteractiveStory,
    StoryChoice,
    StorySegment,
    StoryState,
)
from backend.services.interactive_adventure_service import InteractiveAdventureService


@pytest.fixture
def mock_genai_client():
    """Provider-agnostic stub for the interactive segment generator.

    The service no longer calls Gemini (MT-137 — a child's data must not go to
    Gemini); it generates segments via the ToS-safe provider chain
    (``_generate_text``). To keep the existing tests unchanged, this fixture
    patches ``_generate_text`` to return whatever text the test assigns via the
    familiar ``mock_genai_client.models.generate_content.return_value.text``
    shape.
    """
    holder = MagicMock()
    with patch.object(
        InteractiveAdventureService,
        "_generate_text",
        side_effect=lambda prompt: holder.models.generate_content.return_value.text,
    ):
        yield holder


@pytest.fixture
def interactive_service(mock_genai_client):
    service = InteractiveAdventureService()
    service.image_generator = MagicMock()
    return service


def test_create_story_success(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Test successful interactive story creation"""
    # Mock Gemini response
    mock_response = MagicMock()
    mock_response.text = json.dumps(
        {
            "title": "The Crystal Forest",
            "content": "You stand at the edge of a shimmering forest.",
            "is_ending": False,
            "inventory": ["Magic Map"],
            "story_state": {
                "location": "Forest Entrance",
                "goal": "Find the Heart of the Woods",
                "key_clues": ["Whispering leaves"],
                "companion_status": "Excited",
            },
            "choices": [
                {"id": "choice_1", "text": "Enter the forest"},
                {"id": "choice_2", "text": "Wait and watch"},
            ],
            "image_description": "A beautiful shimmering forest with glowing trees",
        }
    )
    mock_genai_client.models.generate_content.return_value = mock_response

    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        db.session.commit()

        result = interactive_service.create_story(
            user_id=test_user.id,
            character_id=test_character.id,
            theme="Magic",
            tone="whimsical",
            length="short",
        )

        assert "story_id" in result
        assert result["title"] == "The Crystal Forest"

        # Cleanup story before test_user is deleted by fixture teardown
        story = db.session.get(InteractiveStory, result["story_id"])
        db.session.delete(story)
        db.session.commit()


def test_continue_story_success(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Test successful interactive story continuation"""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)

        story = InteractiveStory(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            character_id=test_character.id,
            title="Test Adventure",
            theme="Adventure",
            tone="fantasy",
            length="short",
            age=7,
            current_segment_number=1,
        )
        db.session.add(story)

        state = StoryState(
            id=str(uuid.uuid4()),
            story_id=story.id,
            current_location="Start",
            current_goal="Explore",
        )
        db.session.add(state)

        segment = StorySegment(
            id=str(uuid.uuid4()),
            story_id=story.id,
            segment_number=1,
            content="Beginning...",
        )
        db.session.add(segment)
        db.session.flush()

        choice = StoryChoice(
            id=str(uuid.uuid4()),
            segment_id=segment.id,
            choice_number=1,
            text="Next step",
        )
        db.session.add(choice)
        story.current_segment_id = segment.id
        db.session.commit()

        mock_response = MagicMock()
        mock_response.text = json.dumps(
            {
                "content": "You moved forward.",
                "is_ending": True,
                "inventory": ["Magic Map", "Golden Key"],
                "story_state": {"location": "Deep Cave", "goal": "Find exit"},
                "choices": [],
            }
        )
        mock_genai_client.models.generate_content.return_value = mock_response

        result = interactive_service.continue_story(story.id, choice.id)
        assert result["is_completed"] is True

        # Cleanup
        db.session.delete(story)
        db.session.commit()


def test_create_story_include_images_false_skips_illustration(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """include_images=False (audio-only client) must skip illustration
    generation entirely — no Replicate call, image_url stays None."""
    mock_response = MagicMock()
    mock_response.text = json.dumps(
        {
            "title": "The Silent Forest",
            "content": "You stand at the edge of a shimmering forest.",
            "is_ending": False,
            "inventory": [],
            "story_state": {
                "location": "Forest Entrance",
                "goal": "Find the Heart of the Woods",
                "key_clues": [],
                "companion_status": "Excited",
            },
            "choices": [
                {"id": "choice_1", "text": "Enter the forest"},
                {"id": "choice_2", "text": "Wait and watch"},
            ],
            "image_description": "A beautiful shimmering forest with glowing trees",
        }
    )
    mock_genai_client.models.generate_content.return_value = mock_response

    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        db.session.commit()

        result = interactive_service.create_story(
            user_id=test_user.id,
            character_id=test_character.id,
            theme="Magic",
            tone="whimsical",
            length="short",
            include_images=False,
        )

        interactive_service.image_generator.generate_story_illustration.assert_not_called()
        assert result["segment"]["image_url"] is None

        story = db.session.get(InteractiveStory, result["story_id"])
        db.session.delete(story)
        db.session.commit()


def test_create_story_default_include_images_true_generates_illustration(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Default (include_images unset) must preserve existing behavior — the
    illustration call still happens when the segment has an image_description."""
    mock_response = MagicMock()
    mock_response.text = json.dumps(
        {
            "title": "The Bright Forest",
            "content": "You stand at the edge of a shimmering forest.",
            "is_ending": False,
            "inventory": [],
            "story_state": {
                "location": "Forest Entrance",
                "goal": "Find the Heart of the Woods",
                "key_clues": [],
                "companion_status": "Excited",
            },
            "choices": [
                {"id": "choice_1", "text": "Enter the forest"},
                {"id": "choice_2", "text": "Wait and watch"},
            ],
            "image_description": "A beautiful shimmering forest with glowing trees",
        }
    )
    mock_genai_client.models.generate_content.return_value = mock_response
    interactive_service.image_generator.generate_story_illustration.return_value = [
        {"image_data": "ZmFrZQ=="}
    ]

    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        db.session.commit()

        result = interactive_service.create_story(
            user_id=test_user.id,
            character_id=test_character.id,
            theme="Magic",
            tone="whimsical",
            length="short",
        )

        interactive_service.image_generator.generate_story_illustration.assert_called_once()
        assert result["segment"]["image_url"] == "data:image/png;base64,ZmFrZQ=="

        story = db.session.get(InteractiveStory, result["story_id"])
        db.session.delete(story)
        db.session.commit()


def test_continue_story_include_images_false_skips_illustration(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """include_images=False (audio-only client) must skip illustration
    generation on continuation segments too."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        story_id, segment_id, choice_id = _seed_adventure_with_open_segment(
            test_user, test_character
        )

        mock_response = MagicMock()
        mock_response.text = json.dumps(
            {
                "content": "You moved forward.",
                "is_ending": True,
                "inventory": [],
                "story_state": {"location": "Deep Cave", "goal": "Find exit"},
                "choices": [],
                "image_description": "A glowing cave of crystals",
            }
        )
        mock_genai_client.models.generate_content.return_value = mock_response

        result = interactive_service.continue_story(
            story_id, choice_id, include_images=False
        )

        interactive_service.image_generator.generate_story_illustration.assert_not_called()
        assert result["segment"]["image_url"] is None

        db.session.delete(db.session.get(InteractiveStory, story_id))
        db.session.commit()


def test_continue_story_default_include_images_true_generates_illustration(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Default (include_images unset) must preserve existing behavior on
    continuation segments — the illustration call still happens."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        story_id, segment_id, choice_id = _seed_adventure_with_open_segment(
            test_user, test_character
        )

        mock_response = MagicMock()
        mock_response.text = json.dumps(
            {
                "content": "You moved forward.",
                "is_ending": True,
                "inventory": [],
                "story_state": {"location": "Deep Cave", "goal": "Find exit"},
                "choices": [],
                "image_description": "A glowing cave of crystals",
            }
        )
        mock_genai_client.models.generate_content.return_value = mock_response
        interactive_service.image_generator.generate_story_illustration.return_value = [
            {"image_data": "ZmFrZQ=="}
        ]

        result = interactive_service.continue_story(story_id, choice_id)

        interactive_service.image_generator.generate_story_illustration.assert_called_once()
        assert result["segment"]["image_url"] == "data:image/png;base64,ZmFrZQ=="

        db.session.delete(db.session.get(InteractiveStory, story_id))
        db.session.commit()


def test_get_story_success(app, interactive_service, test_user):
    """Test retrieving a full story"""
    with app.app_context():
        db.session.merge(test_user)
        story_id = str(uuid.uuid4())
        story = InteractiveStory(
            id=story_id,
            user_id=test_user.id,
            title="Full Story",
            theme="Theme",
            tone="tone",
            length="short",
            age=5,
        )
        db.session.add(story)
        db.session.commit()

        result = interactive_service.get_story(story_id)
        assert result["title"] == "Full Story"

        # Cleanup
        db.session.delete(story)
        db.session.commit()


def test_continue_story_already_completed(app, interactive_service, test_user):
    """Test continuation of completed story"""
    with app.app_context():
        db.session.merge(test_user)
        story = InteractiveStory(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            is_completed=True,
            title="Done",
            theme="Done",
            tone="Done",
            length="short",
            age=10,
        )
        db.session.add(story)
        db.session.commit()

        with pytest.raises(ValueError, match="Story .* is already completed"):
            interactive_service.continue_story(story.id, "any-choice")

        # Cleanup
        db.session.delete(story)
        db.session.commit()


def test_create_story_persists_big_feelings_context_in_state(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Big Feelings interactive setup should be stored in story state for continuation prompts."""
    mock_response = MagicMock()
    mock_response.text = json.dumps(
        {
            "title": "Milo and the Big Breeze",
            "content": "Milo felt so mad when someone said no.",
            "is_ending": False,
            "inventory": [],
            "story_state": {
                "location": "Playroom",
                "goal": "Feel better",
                "key_clues": ["hot face"],
                "companion_status": "close by",
            },
            "choices": [
                {"id": "choice_1", "text": "Take a dragon breath"},
                {"id": "choice_2", "text": "Roar, then stop"},
            ],
            "image_description": "A warm playroom with a child taking a calming breath",
        }
    )
    mock_genai_client.models.generate_content.return_value = mock_response

    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        db.session.commit()

        result = interactive_service.create_story(
            user_id=test_user.id,
            character_id=test_character.id,
            theme="Big Feelings",
            tone="whimsical",
            length="short",
            big_feelings_context={
                "current_feeling": {"emotion_name": "Mad"},
                "trigger": "someone said no",
                "body_signal": "Hot face",
                "coping_tool": "Take a dragon breath",
                "repair_goal": "Help fix it",
            },
        )

        story = db.session.get(InteractiveStory, result["story_id"])
        assert story is not None
        assert story.state is not None
        assert (
            story.state.additional_state["big_feelings_context"]["trigger"]
            == "someone said no"
        )
        assert (
            story.state.additional_state["big_feelings_context"]["coping_tool"]
            == "Take a dragon breath"
        )

        db.session.delete(story)
        db.session.commit()


def test_generate_segment_with_retry_repairs_trailing_commas(
    interactive_service, mock_genai_client
):
    """Interactive segment parsing should recover from common trailing-comma JSON issues."""
    mock_response = MagicMock()
    mock_response.text = """```json
{
  "title": "The Repair Path",
  "content": "You take a breath and check on Pip.",
  "is_ending": false,
  "inventory": [],
  "story_state": {
    "location": "Playroom",
    "goal": "Help Pip feel better",
    "key_clues": [],
    "companion_status": "Pip feels calmer",
  },
  "choices": [
    {"id": "choice_1", "text": "Say sorry"},
    {"id": "choice_2", "text": "Help fix it"},
  ],
}
```"""
    mock_genai_client.models.generate_content.return_value = mock_response

    data = interactive_service._generate_segment_with_retry("prompt")

    assert data["title"] == "The Repair Path"
    assert data["choices"][0]["text"] == "Say sorry"
    assert data["choices"][1]["text"] == "Help fix it"


def _seed_adventure_with_open_segment(test_user, test_character):
    """Helper: insert a story with one CHOICE-type segment and one normal choice.

    Returns the (story_id, segment_id, choice_id) tuple. Caller is responsible
    for the surrounding app_context / merge / commit lifecycle.
    """
    story = InteractiveStory(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        character_id=test_character.id,
        title="Parent-choice attribution test",
        theme="Adventure",
        tone="fantasy",
        length="short",
        age=7,
        current_segment_number=1,
    )
    db.session.add(story)

    state = StoryState(
        id=str(uuid.uuid4()),
        story_id=story.id,
        current_location="Start",
        current_goal="Explore",
    )
    db.session.add(state)

    segment = StorySegment(
        id=str(uuid.uuid4()),
        story_id=story.id,
        segment_number=1,
        content="Beginning...",
        output_type="CHOICE",
    )
    db.session.add(segment)
    db.session.flush()

    choice = StoryChoice(
        id=str(uuid.uuid4()),
        segment_id=segment.id,
        choice_number=1,
        text="Go through the door",
    )
    db.session.add(choice)
    story.current_segment_id = segment.id
    db.session.commit()

    return story.id, segment.id, choice.id


def _mock_next_segment_response(mock_genai_client, *, is_ending=True):
    """Stub Gemini with a minimal valid continuation segment."""
    mock_response = MagicMock()
    mock_response.text = json.dumps(
        {
            "content": "The next part of the adventure unfolds.",
            "is_ending": is_ending,
            "inventory": [],
            "story_state": {"location": "Hallway", "goal": "Keep going"},
            "choices": [],
        }
    )
    mock_genai_client.models.generate_content.return_value = mock_response


def test_continue_story_continue_branch_persists_null_parent_choice_id(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """MT-195: the 'continue' branch must NOT persist the literal string
    'continue' as parent_choice_id — it should be NULL, because there's no
    StoryChoice row representing a continue action."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        story_id, segment_id, _choice_id = _seed_adventure_with_open_segment(
            test_user, test_character
        )

        _mock_next_segment_response(mock_genai_client)
        interactive_service.continue_story(story_id, "continue")

        new_segment = StorySegment.query.filter_by(
            story_id=story_id, segment_number=2
        ).one()
        assert new_segment.parent_choice_id is None, (
            "continue branch must persist NULL parent_choice_id, "
            f"got {new_segment.parent_choice_id!r}"
        )

        # Cleanup
        db.session.delete(db.session.get(InteractiveStory, story_id))
        db.session.commit()


def test_continue_story_custom_branch_persists_null_parent_choice_id(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """MT-195: the 'custom' (free-text 'Something Else') branch must NOT persist
    the literal string 'custom' as parent_choice_id — it should be NULL."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        story_id, segment_id, _choice_id = _seed_adventure_with_open_segment(
            test_user, test_character
        )

        _mock_next_segment_response(mock_genai_client)
        interactive_service.continue_story(
            story_id, "custom", custom_text="I want to climb the tree instead"
        )

        new_segment = StorySegment.query.filter_by(
            story_id=story_id, segment_number=2
        ).one()
        assert new_segment.parent_choice_id is None, (
            "custom branch must persist NULL parent_choice_id, "
            f"got {new_segment.parent_choice_id!r}"
        )

        # Cleanup
        db.session.delete(db.session.get(InteractiveStory, story_id))
        db.session.commit()


def test_continue_story_normal_branch_persists_real_choice_id(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """MT-195: the normal choice branch must persist the real StoryChoice.id
    (a valid FK to story_choice) as parent_choice_id."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        story_id, segment_id, choice_id = _seed_adventure_with_open_segment(
            test_user, test_character
        )

        _mock_next_segment_response(mock_genai_client)
        interactive_service.continue_story(story_id, choice_id)

        new_segment = StorySegment.query.filter_by(
            story_id=story_id, segment_number=2
        ).one()
        assert new_segment.parent_choice_id == choice_id, (
            f"normal branch must persist real choice id {choice_id!r}, "
            f"got {new_segment.parent_choice_id!r}"
        )

        # Cleanup
        db.session.delete(db.session.get(InteractiveStory, story_id))
        db.session.commit()
