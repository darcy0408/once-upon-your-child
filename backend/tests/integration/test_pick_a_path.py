"""
Integration tests for Pick-A-Path Adventure API endpoints.

Tests the complete API contract for interactive story generation,
including:
- Story creation and initialization
- Choice selection and continuation
- State persistence across segments
- Story retrieval and resume
- Error handling and validation
"""

import uuid

import pytest

from backend.database import db
from backend.models import (
    Character,
    InteractiveStory,
    StoryChoice,
    StorySegment,
    StoryState,
)


@pytest.fixture(autouse=True)
def mock_interactive_service(mocker):
    """Mock the InteractiveAdventureService for deterministic test responses."""
    service_instance = mocker.MagicMock()

    service_instance.create_story.return_value = {
        "story_id": "test-story-123",
        "title": "The Enchanted Forest",
        "segment": {
            "segment_number": 1,
            "content": "You stand at the edge of a mysterious forest.",
            "choices": [
                {"id": "choice-1", "text": "Enter the forest bravely"},
                {"id": "choice-2", "text": "Listen to the whispers first"},
            ],
        },
        "inventory": ["Old Map"],
        "state": {
            "current_location": "Forest Edge",
            "current_goal": "Discover the heart of the forest",
            "key_clues": ["The trees are watching"],
            "companion_status": "Curious and ready",
        },
        "is_completed": False,
        "current_segment_number": 1,
    }

    service_instance.continue_story.return_value = {
        "story_id": "test-story-123",
        "segment": {
            "segment_number": 2,
            "content": "Deeper in the forest, you discover a glowing crystal clearing.",
            "choices": [
                {"id": "choice-3", "text": "Touch the crystal"},
                {"id": "choice-4", "text": "Circle around it"},
            ],
        },
        "inventory": ["Old Map", "Glowing Feather"],
        "state": {
            "current_location": "Crystal Clearing",
            "current_goal": "Understand the crystal's power",
            "key_clues": ["The trees are watching", "Crystal hums with energy"],
            "companion_status": "Protective and alert",
        },
        "is_completed": False,
        "current_segment_number": 2,
    }

    service_instance.get_story.return_value = {
        "story_id": "test-story-123",
        "title": "The Enchanted Forest",
        "theme": "Magic",
        "tone": "whimsical",
        "length": "short",
        "age": 8,
        "segments": [
            {
                "segment_number": 1,
                "content": "You stand at the edge of a mysterious forest.",
                "choices": [
                    {"id": "choice-1", "text": "Enter the forest bravely"},
                    {"id": "choice-2", "text": "Listen to the whispers first"},
                ],
            }
        ],
        "current_segment_number": 1,
        "inventory": ["Old Map"],
        "state": {
            "current_location": "Forest Edge",
            "current_goal": "Discover the heart of the forest",
            "key_clues": ["The trees are watching"],
            "companion_status": "Curious and ready",
        },
        "is_completed": False,
    }

    mock_class = mocker.patch("backend.routes.story_routes.InteractiveAdventureService")
    mock_class.return_value = service_instance
    return service_instance


@pytest.fixture
def user_in_db(app, test_user):
    """Ensure test_user is merged into the active DB session so require_auth passes."""
    with app.app_context():
        db.session.merge(test_user)
        db.session.commit()
    return test_user


@pytest.fixture
def test_character_fixture(app, test_user):
    """Create a test character for interactive stories."""
    with app.app_context():
        db.session.merge(test_user)
        character = Character(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            name="Aria",
            age=8,
            role="Hero",
            personality_sliders={"brave": 8, "creative": 7},
            avatar_data={"type": "generated", "seed": 42},
        )
        db.session.add(character)
        db.session.commit()
        yield character
        db.session.delete(character)
        db.session.commit()


@pytest.fixture
def story_in_db(app, test_user):
    """
    Create an InteractiveStory with a segment and choices owned by test_user.
    Required for routes that do ownership checks before calling the service.
    """
    story_id = "test-story-123"
    with app.app_context():
        db.session.merge(test_user)

        story = InteractiveStory(
            id=story_id,
            user_id=test_user.id,
            title="The Enchanted Forest",
            theme="Magic",
            tone="whimsical",
            length="short",
            age=8,
            is_completed=False,
            current_segment_number=1,
        )
        db.session.add(story)
        db.session.flush()

        state = StoryState(
            id=str(uuid.uuid4()),
            story_id=story_id,
            current_location="Forest Edge",
            current_goal="Discover the heart of the forest",
        )
        db.session.add(state)

        segment = StorySegment(
            id="segment-001",
            story_id=story_id,
            segment_number=1,
            content="You stand at the edge of a mysterious forest.",
        )
        db.session.add(segment)
        db.session.flush()

        choice = StoryChoice(
            id="choice-1",
            segment_id="segment-001",
            choice_number=1,
            text="Enter the forest bravely",
        )
        db.session.add(choice)

        story.current_segment_id = "segment-001"
        db.session.commit()
        yield story

        # Cleanup
        db.session.delete(story)
        db.session.commit()


class TestGenerateInteractiveStoryAPI:
    """Test POST /generate-interactive-story endpoint"""

    def test_create_interactive_story_success(
        self, client, auth_headers, test_character_fixture, mock_interactive_service
    ):
        """Test successful interactive story creation returns correct response shape."""
        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "theme": "Magic",
                "tone": "whimsical",
                "length": "short",
            },
        )

        assert response.status_code == 200
        data = response.get_json()

        assert "story_id" in data
        assert "segment" in data
        assert data["segment"]["segment_number"] == 1
        assert "content" in data["segment"]
        assert "choices" in data["segment"]
        assert len(data["segment"]["choices"]) >= 2
        assert "inventory" in data
        assert "state" in data
        assert data["is_completed"] is False

        call_kwargs = mock_interactive_service.create_story.call_args[1]
        assert call_kwargs["character_id"] == test_character_fixture.id
        assert call_kwargs["theme"] == "Magic"

    def test_create_interactive_story_theme_defaults_to_adventure(
        self, client, auth_headers, test_character_fixture, mock_interactive_service
    ):
        """Test that omitting theme defaults to 'Adventure' (not a validation error)."""
        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={"character_id": test_character_fixture.id, "length": "short"},
        )

        assert response.status_code == 200
        call_kwargs = mock_interactive_service.create_story.call_args[1]
        assert call_kwargs["theme"] == "Adventure"

    def test_create_interactive_story_passes_big_feelings_context(
        self, client, auth_headers, test_character_fixture, mock_interactive_service
    ):
        """Route should pass big_feelings_context through to the interactive service unchanged."""
        big_feelings_context = {
            "current_feeling": {
                "emotion_name": "Mad",
                "physical_signs": "Hot face",
            },
            "trigger": "someone said no",
            "body_signal": "Hot face",
            "coping_tool": "Take a dragon breath",
            "repair_goal": "Help fix it",
            "parent_hidden_context": "trouble hearing no",
        }

        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "theme": "Big Feelings",
                "tone": "whimsical",
                "length": "short",
                "big_feelings_context": big_feelings_context,
            },
        )

        assert response.status_code == 200
        call_kwargs = mock_interactive_service.create_story.call_args[1]
        assert call_kwargs["big_feelings_context"] == big_feelings_context

    def test_create_interactive_story_rhyme_mode_is_invalid(
        self, client, auth_headers, test_character_fixture
    ):
        """Test that interactive + rhyme_time_mode combination returns 400."""
        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "theme": "Magic",
                "rhyme_time_mode": True,
            },
        )

        assert response.status_code == 400

    def test_create_interactive_story_unauthorized(self, client):
        """Test story creation requires authentication."""
        response = client.post(
            "/generate-interactive-story",
            json={"theme": "Magic", "length": "short"},
        )
        assert response.status_code == 401


class TestContinueInteractiveStoryAPI:
    """Test POST /continue-interactive-story endpoint"""

    def test_continue_story_success(
        self, client, auth_headers, story_in_db, mock_interactive_service
    ):
        """Test successful story continuation returns next segment."""
        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={"story_id": story_in_db.id, "choice_id": "choice-1"},
        )

        assert response.status_code == 200
        data = response.get_json()

        assert "segment" in data
        assert data["segment"]["segment_number"] == 2
        assert "inventory" in data
        assert "state" in data
        assert data["is_completed"] is False

        mock_interactive_service.continue_story.assert_called_once_with(
            story_id=story_in_db.id, choice_id="choice-1", custom_text=None
        )

    def test_continue_story_completion(
        self, client, auth_headers, story_in_db, mock_interactive_service
    ):
        """Test story continuation when story reaches its final segment."""
        mock_interactive_service.continue_story.return_value = {
            "story_id": story_in_db.id,
            "segment": {
                "segment_number": 5,
                "content": "And so your adventure ends.",
                "choices": [],
            },
            "inventory": ["Old Map", "Crystal Heart"],
            "state": {
                "current_location": "Home",
                "current_goal": "Done",
                "key_clues": [],
                "companion_status": "",
            },
            "is_completed": True,
            "current_segment_number": 5,
        }

        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={"story_id": story_in_db.id, "choice_id": "choice-final"},
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data["is_completed"] is True
        assert data["segment"]["choices"] == []

    def test_continue_story_missing_story_id(self, client, auth_headers, user_in_db):
        """Test continuation returns 400 when story_id is absent."""
        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={"choice_id": "choice-1"},
        )

        assert response.status_code == 400
        assert "error" in response.get_json()

    def test_continue_story_missing_choice_id(self, client, auth_headers, user_in_db):
        """Test continuation returns 400 when choice_id is absent."""
        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={"story_id": "test-story-123"},
        )

        assert response.status_code == 400
        assert "error" in response.get_json()

    def test_continue_story_not_found(self, client, auth_headers, user_in_db):
        """Test continuation returns 404 when story doesn't exist."""
        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={"story_id": "nonexistent-story", "choice_id": "choice-1"},
        )

        assert response.status_code == 404
        assert "error" in response.get_json()

    def test_continue_story_invalid_choice_returns_404(
        self, client, auth_headers, story_in_db, mock_interactive_service
    ):
        """Test that an invalid choice_id raises ValueError which the route maps to 404."""
        mock_interactive_service.continue_story.side_effect = ValueError(
            "Invalid choice"
        )

        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={"story_id": story_in_db.id, "choice_id": "invalid-choice"},
        )

        # ValueError is caught by the route and returned as 404
        assert response.status_code == 404
        assert "error" in response.get_json()

    def test_continue_story_unauthorized(self, client):
        """Test continuation requires authentication."""
        response = client.post(
            "/continue-interactive-story",
            json={"story_id": "test-story-123", "choice_id": "choice-1"},
        )
        assert response.status_code == 401


class TestGetInteractiveStoryAPI:
    """Test GET /interactive-story/<story_id> endpoint"""

    def test_get_story_success(
        self, client, auth_headers, story_in_db, mock_interactive_service
    ):
        """Test retrieving full story returns service response after ownership check."""
        response = client.get(
            f"/interactive-story/{story_in_db.id}",
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.get_json()

        assert "story_id" in data
        assert "title" in data
        assert "segments" in data
        assert "current_segment_number" in data
        assert "inventory" in data
        assert "state" in data
        assert "is_completed" in data

        mock_interactive_service.get_story.assert_called_once_with(story_in_db.id)

    def test_get_story_not_found(self, client, auth_headers, user_in_db):
        """Test retrieving a non-existent story returns 404."""
        response = client.get(
            "/interactive-story/nonexistent-story",
            headers=auth_headers,
        )

        assert response.status_code == 404
        assert "error" in response.get_json()

    def test_get_story_access_denied_other_user(self, client, story_in_db, mocker):
        """Test that a different user cannot access another user's story."""
        # Create a token for a different user
        import jwt

        other_token = jwt.encode(
            {"user_id": "other-user-999", "exp": 9999999999},
            "dev-secret-key",
            algorithm="HS256",
        )
        other_headers = {"Authorization": f"Bearer {other_token}"}

        response = client.get(
            f"/interactive-story/{story_in_db.id}",
            headers=other_headers,
        )

        # 401 (user not found) or 403 (access denied) — both are acceptable rejections
        assert response.status_code in (401, 403)

    def test_get_story_unauthorized(self, client):
        """Test story retrieval requires authentication."""
        response = client.get("/interactive-story/test-story-123")
        assert response.status_code == 401


class TestResumeInteractiveStoryAPI:
    """Test GET /interactive-story/<story_id>/resume endpoint"""

    def test_resume_story_success(self, client, auth_headers, story_in_db):
        """Test resuming an in-progress story returns current segment from DB."""
        response = client.get(
            f"/interactive-story/{story_in_db.id}/resume",
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.get_json()

        # Resume builds directly from DB — shape differs from service.get_story()
        assert data["story_id"] == story_in_db.id
        assert "title" in data
        assert "segment" in data  # current segment dict
        assert "inventory" in data
        assert "is_completed" in data
        assert data["is_completed"] is False

    def test_resume_completed_story_returns_400(
        self, client, auth_headers, app, test_user
    ):
        """Test that resuming a completed story returns 400 (not resumable)."""
        completed_id = "completed-story-abc"
        with app.app_context():
            db.session.merge(test_user)
            story = InteractiveStory(
                id=completed_id,
                user_id=test_user.id,
                title="Done",
                theme="Magic",
                tone="whimsical",
                length="short",
                age=8,
                is_completed=True,
            )
            db.session.add(story)
            db.session.commit()

        response = client.get(
            f"/interactive-story/{completed_id}/resume",
            headers=auth_headers,
        )

        assert response.status_code == 400
        assert "error" in response.get_json()

        with app.app_context():
            s = db.session.get(InteractiveStory, completed_id)
            if s:
                db.session.delete(s)
                db.session.commit()

    def test_resume_story_not_found(self, client, auth_headers, user_in_db):
        """Test resuming a non-existent story returns 404."""
        response = client.get(
            "/interactive-story/nonexistent/resume",
            headers=auth_headers,
        )

        assert response.status_code == 404
        assert "error" in response.get_json()

    def test_resume_story_unauthorized(self, client):
        """Test resume requires authentication."""
        response = client.get("/interactive-story/test-story-123/resume")
        assert response.status_code == 401


class TestPickAPathStatePersistence:
    """Test state values flow through create → continue correctly."""

    def test_inventory_accumulates_across_segments(
        self, client, auth_headers, story_in_db, mock_interactive_service
    ):
        """Inventory returned by continue includes items from create."""
        create_response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={"theme": "Treasure Hunt", "length": "short"},
        )
        assert create_response.status_code == 200
        initial_inventory = create_response.get_json()["inventory"]
        assert len(initial_inventory) >= 1

        continue_response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={"story_id": story_in_db.id, "choice_id": "choice-1"},
        )
        assert continue_response.status_code == 200
        updated_inventory = continue_response.get_json()["inventory"]

        assert len(updated_inventory) >= len(initial_inventory)
        for item in initial_inventory:
            assert item in updated_inventory

    def test_state_structure_consistent_across_segments(
        self, client, auth_headers, story_in_db, mock_interactive_service
    ):
        """State dict has the same required keys after both create and continue."""
        required_keys = {
            "current_location",
            "current_goal",
            "key_clues",
            "companion_status",
        }

        create_response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={"theme": "Mystery", "length": "short"},
        )
        assert create_response.status_code == 200
        initial_state = create_response.get_json()["state"]
        assert required_keys.issubset(initial_state.keys())

        continue_response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={"story_id": story_in_db.id, "choice_id": "choice-1"},
        )
        assert continue_response.status_code == 200
        updated_state = continue_response.get_json()["state"]
        assert required_keys.issubset(updated_state.keys())

    def test_segment_number_increments_sequentially(
        self, client, auth_headers, story_in_db, mock_interactive_service
    ):
        """Segment number returned by create is 1; continue returns incrementing numbers."""
        create_response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={"theme": "Adventure", "length": "short"},
        )
        assert create_response.status_code == 200
        assert create_response.get_json()["segment"]["segment_number"] == 1

        for expected in [2, 3]:
            mock_interactive_service.continue_story.return_value["segment"][
                "segment_number"
            ] = expected
            mock_interactive_service.continue_story.return_value[
                "current_segment_number"
            ] = expected

            resp = client.post(
                "/continue-interactive-story",
                headers=auth_headers,
                json={
                    "story_id": story_in_db.id,
                    "choice_id": f"choice-{expected - 1}",
                },
            )
            assert resp.status_code == 200
            assert resp.get_json()["segment"]["segment_number"] == expected


class TestPickAPathChoiceValidation:
    """Test choice structure and validation rules."""

    def test_choices_have_required_fields(
        self, client, auth_headers, test_character_fixture, mock_interactive_service
    ):
        """Every choice in the initial segment must have 'id' and 'text'."""
        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={"theme": "Fantasy", "length": "short"},
        )

        assert response.status_code == 200
        choices = response.get_json()["segment"]["choices"]

        for choice in choices:
            assert "id" in choice
            assert "text" in choice
            assert isinstance(choice["id"], str)
            assert isinstance(choice["text"], str)
            assert len(choice["text"]) > 0

    def test_choice_count_matches_mock(
        self, client, auth_headers, test_character_fixture, mock_interactive_service
    ):
        """Choice count in response matches what the service returns."""
        mock_interactive_service.create_story.return_value["segment"]["choices"] = [
            {"id": "c1", "text": "Choice 1"},
            {"id": "c2", "text": "Choice 2"},
        ]

        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={"theme": "Adventure", "length": "short"},
        )

        assert response.status_code == 200
        assert len(response.get_json()["segment"]["choices"]) == 2

    def test_completed_story_has_no_choices(
        self, client, auth_headers, story_in_db, mock_interactive_service
    ):
        """When service returns is_completed=True, choices list is empty."""
        mock_interactive_service.continue_story.return_value["is_completed"] = True
        mock_interactive_service.continue_story.return_value["segment"]["choices"] = []

        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={"story_id": story_in_db.id, "choice_id": "final-choice"},
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data["is_completed"] is True
        assert data["segment"]["choices"] == []
