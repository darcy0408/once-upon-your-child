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
from backend.services.interactive_adventure_service import (
    InteractiveAdventureService,
    generate_segment_illustration,
)


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


def test_create_story_returns_before_any_image_work(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Latency audit fix A: create_story must return text-only — NO image
    provider is invoked synchronously and image_url is null. Illustration
    generation happens out-of-band (schedule_segment_illustration)."""
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

    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        db.session.commit()

        with patch(
            "backend.routes.story_routes._generate_flux_illustration"
        ) as mock_flux:
            result = interactive_service.create_story(
                user_id=test_user.id,
                character_id=test_character.id,
                theme="Magic",
                tone="whimsical",
                length="short",
            )

        # No synchronous image work of any kind.
        mock_flux.assert_not_called()
        interactive_service.image_generator.generate_story_illustration.assert_not_called()
        assert result["segment"]["image_url"] is None
        # But the image_description is preserved so the background path can
        # generate the illustration afterwards.
        assert result["segment"]["image_description"]

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


def test_continue_story_returns_before_any_image_work(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Latency audit fix A: continue_story must return text-only — NO image
    provider is invoked synchronously and image_url is null."""
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

        with patch(
            "backend.routes.story_routes._generate_flux_illustration"
        ) as mock_flux:
            result = interactive_service.continue_story(story_id, choice_id)

        mock_flux.assert_not_called()
        interactive_service.image_generator.generate_story_illustration.assert_not_called()
        assert result["segment"]["image_url"] is None
        assert result["segment"]["image_description"]

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


# ---------------------------------------------------------------------------
# Latency / continuity / endings audit tests (fixes A-E)
# ---------------------------------------------------------------------------


def _seed_two_segment_adventure(test_user, test_character):
    """Insert a story with two segments (segment 2 current) and a selected
    choice on segment 2, so a continuation exercises the story-so-far builder.

    Segment 2's content introduces the name "Zephyrina" and a cliffhanger well
    past the first 200 characters — the exact material the old 200-char
    truncation dropped.
    """
    seg1_content = (
        "You wake in the meadow as the sun rises over the hills. "
        "A soft wind carries the smell of rain. "
        "At the very end of the morning you find a silver whistle "
        "called Bramblehorn."
    )
    seg2_content = (
        "You follow the winding river path deeper into the valley, counting "
        "the stepping stones one by one while the water hums a quiet song "
        "beside you. The reeds part and a tiny boat drifts into view, painted "
        "with golden stars. Inside the boat sits Zephyrina, a fox with a "
        "lantern, who whispers that the bridge ahead will vanish at moonrise."
    )
    assert len(seg2_content) > 260  # name + cliffhanger sit past the old cutoff

    story = InteractiveStory(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        character_id=None,  # no hero-name pseudonymization in play
        title="Continuity Test Adventure",
        theme="Adventure",
        tone="whimsical",
        length="short",
        age=7,
        current_segment_number=2,
    )
    db.session.add(story)

    state = StoryState(
        id=str(uuid.uuid4()),
        story_id=story.id,
        current_location="River path",
        current_goal="Cross the bridge",
    )
    db.session.add(state)

    seg1 = StorySegment(
        id=str(uuid.uuid4()),
        story_id=story.id,
        segment_number=1,
        content=seg1_content,
        output_type="CHOICE",
    )
    seg2 = StorySegment(
        id=str(uuid.uuid4()),
        story_id=story.id,
        segment_number=2,
        content=seg2_content,
        output_type="CHOICE",
    )
    db.session.add_all([seg1, seg2])
    db.session.flush()

    choice = StoryChoice(
        id=str(uuid.uuid4()),
        segment_id=seg2.id,
        choice_number=1,
        text="Row toward the bridge",
    )
    db.session.add(choice)
    story.current_segment_id = seg2.id
    db.session.commit()

    return story.id, seg1_content, seg2_content, choice.id


def test_continuation_prompt_contains_full_previous_segment_text(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Audit fix C: the continuation prompt must carry the ENTIRE previous
    segment verbatim — including names/cliffhangers introduced after the old
    200-char truncation point — plus a compact summary of older segments."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        story_id, seg1_content, seg2_content, choice_id = _seed_two_segment_adventure(
            test_user, test_character
        )

        captured_prompts = []

        def _record(prompt):
            captured_prompts.append(prompt)
            return json.dumps(
                {
                    "content": "You row across before the moon rises.",
                    "is_ending": True,
                    "inventory": [],
                    "story_state": {"location": "Bridge", "goal": "Cross"},
                    "choices": [],
                }
            )

        service = InteractiveAdventureService()
        with patch.object(
            InteractiveAdventureService, "_generate_text", side_effect=_record
        ):
            service.continue_story(story_id, choice_id)

        assert captured_prompts, "continuation never reached the text provider"
        prompt = captured_prompts[0]

        # Full previous segment, verbatim — including the late-introduced
        # character and the cliffhanger.
        assert seg2_content in prompt
        assert "Zephyrina" in prompt
        assert "vanish at moonrise" in prompt

        # Older segments are summarized, not included in full...
        assert seg1_content not in prompt
        # ...but their first sentence and late-introduced proper nouns survive.
        assert "You wake in the meadow as the sun rises over the hills." in prompt
        assert "Bramblehorn" in prompt

        db.session.delete(db.session.get(InteractiveStory, story_id))
        db.session.commit()


def test_continue_story_forces_completion_at_path_depth(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Audit fix D: at/beyond path_depth the story completes server-side even
    if the model returns is_ending=false with more choices. Age 7 + short =>
    path depth 5 (band 5-7)."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        story_id, segment_id, choice_id = _seed_adventure_with_open_segment(
            test_user, test_character
        )
        story = db.session.get(InteractiveStory, story_id)
        story.current_segment_number = 4  # next segment = 5 = path depth
        db.session.commit()

        # Model tries to keep the adventure going forever.
        mock_response = MagicMock()
        mock_response.text = json.dumps(
            {
                "content": "The tunnel keeps going and going.",
                "is_ending": False,
                "inventory": [],
                "story_state": {"location": "Tunnel", "goal": "Explore"},
                "choices": [
                    {"id": "choice_1", "text": "Keep walking"},
                    {"id": "choice_2", "text": "Turn back"},
                ],
            }
        )
        mock_genai_client.models.generate_content.return_value = mock_response

        result = interactive_service.continue_story(story_id, choice_id)

        assert result["is_completed"] is True
        assert result["segment"]["choices"] == []
        new_segment = StorySegment.query.filter_by(
            story_id=story_id, segment_number=5
        ).one()
        assert new_segment.choices.count() == 0

        db.session.delete(db.session.get(InteractiveStory, story_id))
        db.session.commit()


def test_continue_story_before_path_depth_respects_model_is_ending_false(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Below path depth the model's is_ending=false is respected — no forced
    completion."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        story_id, segment_id, choice_id = _seed_adventure_with_open_segment(
            test_user, test_character
        )  # current_segment_number=1 -> next=2, depth=5

        mock_response = MagicMock()
        mock_response.text = json.dumps(
            {
                "content": "The path splits in two.",
                "is_ending": False,
                "inventory": [],
                "story_state": {"location": "Fork", "goal": "Explore"},
                "choices": [
                    {"id": "choice_1", "text": "Go left"},
                    {"id": "choice_2", "text": "Go right"},
                ],
            }
        )
        mock_genai_client.models.generate_content.return_value = mock_response

        result = interactive_service.continue_story(story_id, choice_id)

        assert result["is_completed"] is False
        assert len(result["segment"]["choices"]) == 2

        db.session.delete(db.session.get(InteractiveStory, story_id))
        db.session.commit()


def _segment_json(choices, content="You step into the clearing."):
    return json.dumps(
        {
            "content": content,
            "is_ending": False,
            "inventory": [],
            "story_state": {"location": "Clearing", "goal": "Explore"},
            "choices": choices,
        }
    )


def test_placeholder_choices_trigger_single_retry(interactive_service):
    """Audit fix E: template placeholder text in a choice triggers exactly one
    regeneration; the retried (clean) segment is returned."""
    placeholder = _segment_json(
        [
            {"id": "choice_1", "text": "First choice option (Action-oriented)"},
            {"id": "choice_2", "text": "Second choice option (Action-oriented)"},
        ]
    )
    clean = _segment_json(
        [
            {"id": "choice_1", "text": "Climb the mossy wall"},
            {"id": "choice_2", "text": "Follow the fireflies"},
        ]
    )
    gen = MagicMock(side_effect=[placeholder, clean])
    with patch.object(InteractiveAdventureService, "_generate_text", gen):
        data = interactive_service._generate_segment_with_retry("prompt")

    assert gen.call_count == 2
    assert [c["text"] for c in data["choices"]] == [
        "Climb the mossy wall",
        "Follow the fireflies",
    ]


def test_placeholder_choices_dropped_after_failed_retry(interactive_service):
    """If the single retry STILL contains placeholder text, the offending
    choices are dropped (never shown to the child) and no further retries
    burn."""
    placeholder = _segment_json(
        [
            {"id": "choice_1", "text": "First choice option (Action-oriented)"},
            {"id": "choice_2", "text": "Swim across the silver lake"},
        ]
    )
    gen = MagicMock(side_effect=[placeholder, placeholder])
    with patch.object(InteractiveAdventureService, "_generate_text", gen):
        data = interactive_service._generate_segment_with_retry("prompt")

    assert gen.call_count == 2
    assert [c["text"] for c in data["choices"]] == ["Swim across the silver lake"]


def test_meta_leakage_stripped_from_segment_content(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Audit fix E: the standard story path's meta-leakage stripper runs on
    segment prose before it is persisted/returned."""
    mock_response = MagicMock()
    mock_response.text = json.dumps(
        {
            "title": "The Hidden Grove",
            "content": (
                "You tiptoe past the sleeping owl. "
                "It was an earned ending to the challenge arc."
            ),
            "is_ending": False,
            "inventory": [],
            "story_state": {"location": "Grove", "goal": "Explore"},
            "choices": [
                {"id": "choice_1", "text": "Wake the owl"},
                {"id": "choice_2", "text": "Sneak onward"},
            ],
            "image_description": "A quiet grove",
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

        assert result["segment"]["content"] == "You tiptoe past the sleeping owl."

        db.session.delete(db.session.get(InteractiveStory, result["story_id"]))
        db.session.commit()


def test_lesson_ending_stripped_on_ending_segment():
    """The lesson-summary stripper (last sentence, ending segments only) is
    applied via _apply_content_hygiene."""
    data = {
        "content": (
            "The dragon waved goodbye from the cliff. "
            "From that day on, you knew sharing made everything brighter."
        ),
        "is_ending": True,
        "choices": [],
    }
    cleaned = InteractiveAdventureService._apply_content_hygiene(data)
    assert cleaned["content"] == "The dragon waved goodbye from the cliff."


def test_generate_segment_illustration_persists_data_uri(
    app, test_user, test_character
):
    """The background illustration path uses the shared Flux chain and persists
    a data URI onto the segment."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        story = InteractiveStory(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            title="Async Illustration Test",
            theme="Magic",
            tone="whimsical",
            length="short",
            age=7,
        )
        db.session.add(story)
        segment = StorySegment(
            id=str(uuid.uuid4()),
            story_id=story.id,
            segment_number=1,
            content="A quiet start.",
            image_description="A shimmering forest with glowing trees",
        )
        db.session.add(segment)
        db.session.commit()

        with patch(
            "backend.routes.story_routes._generate_flux_illustration",
            return_value=[{"image_data": "ZmFrZQ==", "format": "png"}],
        ) as mock_flux:
            assert generate_segment_illustration(segment.id) is True

        mock_flux.assert_called_once()
        # The child's real name never reaches the image vendor (MT-311#16).
        assert mock_flux.call_args.kwargs["character_name"] == "the hero"
        refreshed = db.session.get(StorySegment, segment.id)
        assert refreshed.image_url == "data:image/png;base64,ZmFrZQ=="

        db.session.delete(db.session.get(InteractiveStory, story.id))
        db.session.commit()


def test_generate_segment_illustration_is_noop_when_image_exists(
    app, test_user, test_character
):
    """Idempotent: an already-illustrated segment never re-bills a provider."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        story = InteractiveStory(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            title="Idempotency Test",
            theme="Magic",
            tone="whimsical",
            length="short",
            age=7,
        )
        db.session.add(story)
        segment = StorySegment(
            id=str(uuid.uuid4()),
            story_id=story.id,
            segment_number=1,
            content="A quiet start.",
            image_description="A shimmering forest",
            image_url="data:image/png;base64,ZXhpc3Rpbmc=",
        )
        db.session.add(segment)
        db.session.commit()

        with patch(
            "backend.routes.story_routes._generate_flux_illustration"
        ) as mock_flux:
            assert generate_segment_illustration(segment.id) is False

        mock_flux.assert_not_called()

        db.session.delete(db.session.get(InteractiveStory, story.id))
        db.session.commit()


def test_final_continuation_prompt_template_forces_ending():
    """Audit fix D (template): at path depth the JSON template flips to
    is_ending true with an empty choices array and a resolution instruction;
    one segment earlier keeps the MAY-conclude language."""
    from backend.services.interactive_adventure_prompt_builder import (
        InteractiveAdventurePromptBuilder,
    )

    story_context = {
        "title": "The Long Trail",
        "theme": "Adventure",
        "tone": "whimsical",
        "length": "short",
        "age": 7,  # band 5-7, short => path depth 5
        "character": {"name": "Hero"},
        "companions": [],
    }

    final_prompt = InteractiveAdventurePromptBuilder.build_continuation_prompt(
        story_context=story_context,
        selected_choice="Open the gate",
        current_segment_number=4,  # next = 5 = path depth
        inventory=[],
        story_state={},
        story_so_far="Previously...",
    )
    assert '"is_ending": true' in final_prompt
    assert '"is_ending": false' not in final_prompt
    assert "FINAL SEGMENT" in final_prompt
    assert "MUST be empty" in final_prompt

    near_end_prompt = InteractiveAdventurePromptBuilder.build_continuation_prompt(
        story_context=story_context,
        selected_choice="Open the gate",
        current_segment_number=3,  # next = 4 = depth - 1
        inventory=[],
        story_state={},
        story_so_far="Previously...",
    )
    assert '"is_ending": false' in near_end_prompt
    assert "MAY conclude" in near_end_prompt
    assert "FINAL SEGMENT" not in near_end_prompt
