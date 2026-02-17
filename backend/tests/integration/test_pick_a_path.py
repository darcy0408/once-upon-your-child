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

import json
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock

import jwt
import pytest

from backend.database import db
from backend.models import InteractiveStory, StorySegment, StoryChoice, StoryState, Character


@pytest.fixture(autouse=True)
def mock_interactive_service(mocker):
    """Mock the InteractiveAdventureService for deterministic test responses."""
    service_instance = mocker.MagicMock()

    # Default mock for create_story
    service_instance.create_story.return_value = {
        "story_id": "test-story-123",
        "title": "The Enchanted Forest",
        "segment": {
            "segment_number": 1,
            "content": "You stand at the edge of a mysterious forest. The trees whisper secrets in the wind.",
            "choices": [
                {"id": "choice-1", "text": "Enter the forest bravely"},
                {"id": "choice-2", "text": "Listen to the whispers first"},
            ],
            "image_url": "https://example.com/forest.jpg"
        },
        "inventory": ["Old Map"],
        "state": {
            "current_location": "Forest Edge",
            "current_goal": "Discover the heart of the forest",
            "key_clues": ["The trees are watching"],
            "companion_status": "Curious and ready"
        },
        "is_completed": False,
        "current_segment_number": 1
    }

    # Default mock for continue_story
    service_instance.continue_story.return_value = {
        "story_id": "test-story-123",
        "segment": {
            "segment_number": 2,
            "content": "Deeper in the forest, you discover a glowing crystal clearing.",
            "choices": [
                {"id": "choice-3", "text": "Touch the crystal"},
                {"id": "choice-4", "text": "Circle around it"},
            ],
            "image_url": "https://example.com/crystal.jpg"
        },
        "inventory": ["Old Map", "Glowing Feather"],
        "state": {
            "current_location": "Crystal Clearing",
            "current_goal": "Understand the crystal's power",
            "key_clues": ["The trees are watching", "Crystal hums with energy"],
            "companion_status": "Protective and alert"
        },
        "is_completed": False,
        "current_segment_number": 2
    }

    # Default mock for get_story
    service_instance.get_story.return_value = {
        "story_id": "test-story-123",
        "title": "The Enchanted Forest",
        "theme": "Magic",
        "tone": "whimsical",
        "length": "short",
        "age": 8,
        "character_name": "Aria",
        "segments": [
            {
                "segment_number": 1,
                "content": "You stand at the edge of a mysterious forest.",
                "choices": [
                    {"id": "choice-1", "text": "Enter the forest bravely"},
                    {"id": "choice-2", "text": "Listen to the whispers first"},
                ]
            }
        ],
        "current_segment_number": 1,
        "inventory": ["Old Map"],
        "state": {
            "current_location": "Forest Edge",
            "current_goal": "Discover the heart of the forest",
            "key_clues": ["The trees are watching"],
            "companion_status": "Curious and ready"
        },
        "is_completed": False
    }

    # Mock the class where it's imported in the routes file
    mock_class = mocker.patch("backend.routes.story_routes.InteractiveAdventureService")
    mock_class.return_value = service_instance
    return service_instance


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
            avatar_data={"type": "generated", "seed": 42}
        )
        db.session.add(character)
        db.session.commit()
        yield character
        # Cleanup
        db.session.delete(character)
        db.session.commit()


class TestGenerateInteractiveStoryAPI:
    """Test POST /generate-interactive-story endpoint"""

    def test_create_interactive_story_success(self, client, auth_headers, test_character_fixture, mock_interactive_service):
        """Test successful interactive story creation with valid inputs"""
        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "theme": "Magic",
                "tone": "whimsical",
                "length": "short"
            }
        )

        assert response.status_code == 200
        data = response.get_json()

        # Verify response structure
        assert "story_id" in data
        assert "segment" in data
        assert data["segment"]["segment_number"] == 1
        assert "content" in data["segment"]
        assert "choices" in data["segment"]
        assert len(data["segment"]["choices"]) >= 2
        assert "inventory" in data
        assert "state" in data
        assert data["is_completed"] is False

        # Verify service was called correctly
        mock_interactive_service.create_story.assert_called_once()
        call_kwargs = mock_interactive_service.create_story.call_args[1]
        assert call_kwargs["character_id"] == test_character_fixture.id
        assert call_kwargs["theme"] == "Magic"
        assert call_kwargs["tone"] == "whimsical"
        assert call_kwargs["length"] == "short"

    def test_create_interactive_story_missing_theme(self, client, auth_headers, test_character_fixture):
        """Test story creation fails without required theme"""
        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "length": "short"
            }
        )

        assert response.status_code == 400
        data = response.get_json()
        assert "error" in data
        assert "theme" in data["error"].lower()

    def test_create_interactive_story_unauthorized(self, client, test_character_fixture):
        """Test story creation requires authentication"""
        response = client.post(
            "/generate-interactive-story",
            json={
                "character_id": test_character_fixture.id,
                "theme": "Magic",
                "length": "short"
            }
        )

        assert response.status_code == 401

    def test_create_interactive_story_rate_limit(self, client, auth_headers, test_character_fixture):
        """Test rate limiting on story creation (5 per minute)"""
        # Make 5 requests (should all succeed)
        for _ in range(5):
            response = client.post(
                "/generate-interactive-story",
                headers=auth_headers,
                json={
                    "character_id": test_character_fixture.id,
                    "theme": "Magic",
                    "length": "short"
                }
            )
            assert response.status_code == 200

        # 6th request should be rate limited
        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "theme": "Magic",
                "length": "short"
            }
        )
        assert response.status_code == 429


class TestContinueInteractiveStoryAPI:
    """Test POST /continue-interactive-story endpoint"""

    def test_continue_story_success(self, client, auth_headers, mock_interactive_service):
        """Test successful story continuation with valid choice"""
        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={
                "story_id": "test-story-123",
                "choice_id": "choice-1"
            }
        )

        assert response.status_code == 200
        data = response.get_json()

        # Verify response structure
        assert "segment" in data
        assert data["segment"]["segment_number"] == 2
        assert "inventory" in data
        assert "state" in data
        assert data["is_completed"] is False

        # Verify service was called with correct parameters
        mock_interactive_service.continue_story.assert_called_once_with(
            "test-story-123",
            "choice-1"
        )

    def test_continue_story_completion(self, client, auth_headers, mock_interactive_service):
        """Test story continuation when story reaches completion"""
        # Mock service to return completed story
        mock_interactive_service.continue_story.return_value = {
            "story_id": "test-story-123",
            "segment": {
                "segment_number": 5,
                "content": "And so, your adventure comes to a wonderful end. The forest will remember you always.",
                "choices": [],
                "image_url": "https://example.com/ending.jpg"
            },
            "inventory": ["Old Map", "Glowing Feather", "Crystal Heart"],
            "state": {
                "current_location": "Home",
                "current_goal": "Adventure completed!",
                "key_clues": [],
                "companion_status": "Happy and proud"
            },
            "is_completed": True,
            "current_segment_number": 5
        }

        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={
                "story_id": "test-story-123",
                "choice_id": "choice-final"
            }
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data["is_completed"] is True
        assert data["segment"]["choices"] == []

    def test_continue_story_missing_story_id(self, client, auth_headers):
        """Test continuation fails without story_id"""
        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={
                "choice_id": "choice-1"
            }
        )

        assert response.status_code == 400
        data = response.get_json()
        assert "error" in data

    def test_continue_story_missing_choice_id(self, client, auth_headers):
        """Test continuation fails without choice_id"""
        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={
                "story_id": "test-story-123"
            }
        )

        assert response.status_code == 400
        data = response.get_json()
        assert "error" in data

    def test_continue_story_invalid_choice(self, client, auth_headers, mock_interactive_service):
        """Test continuation with invalid choice_id"""
        mock_interactive_service.continue_story.side_effect = ValueError("Invalid choice")

        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={
                "story_id": "test-story-123",
                "choice_id": "invalid-choice"
            }
        )

        assert response.status_code == 400
        data = response.get_json()
        assert "error" in data

    def test_continue_story_unauthorized(self, client):
        """Test continuation requires authentication"""
        response = client.post(
            "/continue-interactive-story",
            json={
                "story_id": "test-story-123",
                "choice_id": "choice-1"
            }
        )

        assert response.status_code == 401


class TestGetInteractiveStoryAPI:
    """Test GET /interactive-story/<story_id> endpoint"""

    def test_get_story_success(self, client, auth_headers, mock_interactive_service):
        """Test retrieving full interactive story"""
        response = client.get(
            "/interactive-story/test-story-123",
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.get_json()

        # Verify response structure
        assert data["story_id"] == "test-story-123"
        assert "title" in data
        assert "segments" in data
        assert "current_segment_number" in data
        assert "inventory" in data
        assert "state" in data
        assert "is_completed" in data

        # Verify service was called
        mock_interactive_service.get_story.assert_called_once_with("test-story-123")

    def test_get_story_not_found(self, client, auth_headers, mock_interactive_service):
        """Test retrieving non-existent story"""
        mock_interactive_service.get_story.side_effect = ValueError("Story not found")

        response = client.get(
            "/interactive-story/nonexistent-story",
            headers=auth_headers
        )

        assert response.status_code == 404

    def test_get_story_unauthorized(self, client):
        """Test story retrieval requires authentication"""
        response = client.get("/interactive-story/test-story-123")
        assert response.status_code == 401


class TestResumeInteractiveStoryAPI:
    """Test GET /interactive-story/<story_id>/resume endpoint"""

    def test_resume_story_success(self, client, auth_headers, mock_interactive_service):
        """Test resuming an in-progress story"""
        # Mock get_story to return current state
        mock_interactive_service.get_story.return_value = {
            "story_id": "test-story-123",
            "title": "The Enchanted Forest",
            "current_segment_number": 3,
            "segments": [
                {
                    "segment_number": 3,
                    "content": "You continue deeper into the mysterious realm...",
                    "choices": [
                        {"id": "choice-5", "text": "Investigate the glowing pool"},
                        {"id": "choice-6", "text": "Follow the winding path"},
                    ]
                }
            ],
            "inventory": ["Old Map", "Glowing Feather"],
            "state": {
                "current_location": "Mystic Pool",
                "current_goal": "Find the ancient guardian",
                "key_clues": ["Water reflects hidden truths"],
                "companion_status": "Vigilant"
            },
            "is_completed": False
        }

        response = client.get(
            "/interactive-story/test-story-123/resume",
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.get_json()

        # Verify current segment is returned
        assert "current_segment" in data
        assert data["current_segment"]["segment_number"] == 3
        assert "inventory" in data
        assert "state" in data
        assert data["can_continue"] is True

    def test_resume_completed_story(self, client, auth_headers, mock_interactive_service):
        """Test resuming a completed story shows final state"""
        mock_interactive_service.get_story.return_value = {
            "story_id": "test-story-123",
            "title": "The Enchanted Forest",
            "current_segment_number": 5,
            "segments": [
                {
                    "segment_number": 5,
                    "content": "Your adventure concludes magnificently!",
                    "choices": []
                }
            ],
            "inventory": ["Old Map", "Glowing Feather", "Guardian's Blessing"],
            "state": {
                "current_location": "Journey's End",
                "current_goal": "Return home victorious",
                "key_clues": [],
                "companion_status": "Fulfilled"
            },
            "is_completed": True
        }

        response = client.get(
            "/interactive-story/test-story-123/resume",
            headers=auth_headers
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data["can_continue"] is False
        assert data["is_completed"] is True

    def test_resume_story_not_found(self, client, auth_headers, mock_interactive_service):
        """Test resuming non-existent story"""
        mock_interactive_service.get_story.side_effect = ValueError("Story not found")

        response = client.get(
            "/interactive-story/nonexistent/resume",
            headers=auth_headers
        )

        assert response.status_code == 404

    def test_resume_story_unauthorized(self, client):
        """Test resume requires authentication"""
        response = client.get("/interactive-story/test-story-123/resume")
        assert response.status_code == 401


class TestPickAPathStatePersistence:
    """Test state persistence across story segments"""

    def test_inventory_accumulates(self, client, auth_headers, test_character_fixture, mock_interactive_service):
        """Test that inventory items accumulate across segments"""
        # Create story with initial item
        create_response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "theme": "Treasure Hunt",
                "length": "short"
            }
        )
        assert create_response.status_code == 200
        create_data = create_response.get_json()
        initial_inventory = create_data["inventory"]
        assert len(initial_inventory) >= 1

        # Continue story and verify inventory grows
        continue_response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={
                "story_id": create_data["story_id"],
                "choice_id": "choice-1"
            }
        )
        assert continue_response.status_code == 200
        continue_data = continue_response.get_json()
        updated_inventory = continue_data["inventory"]

        # Inventory should have grown
        assert len(updated_inventory) >= len(initial_inventory)
        # Original items should still be present
        for item in initial_inventory:
            assert item in updated_inventory

    def test_state_updates_consistently(self, client, auth_headers, test_character_fixture, mock_interactive_service):
        """Test that story state updates logically across segments"""
        # Create story
        create_response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "theme": "Mystery",
                "length": "short"
            }
        )
        assert create_response.status_code == 200
        create_data = create_response.get_json()
        initial_state = create_data["state"]

        # Verify initial state structure
        assert "current_location" in initial_state
        assert "current_goal" in initial_state
        assert "key_clues" in initial_state
        assert "companion_status" in initial_state

        # Continue story
        continue_response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={
                "story_id": create_data["story_id"],
                "choice_id": "choice-1"
            }
        )
        assert continue_response.status_code == 200
        continue_data = continue_response.get_json()
        updated_state = continue_data["state"]

        # State should have same structure
        assert "current_location" in updated_state
        assert "current_goal" in updated_state
        assert "key_clues" in updated_state
        assert "companion_status" in updated_state

        # Location or clues should have changed
        assert (updated_state["current_location"] != initial_state["current_location"] or
                updated_state["key_clues"] != initial_state["key_clues"])

    def test_segment_number_increments(self, client, auth_headers, test_character_fixture, mock_interactive_service):
        """Test that segment numbers increment sequentially"""
        # Create story
        create_response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "theme": "Adventure",
                "length": "short"
            }
        )
        assert create_response.status_code == 200
        create_data = create_response.get_json()
        assert create_data["segment"]["segment_number"] == 1

        # Continue story multiple times
        story_id = create_data["story_id"]
        for expected_segment in [2, 3]:
            # Update mock to return next segment
            mock_interactive_service.continue_story.return_value["segment"]["segment_number"] = expected_segment
            mock_interactive_service.continue_story.return_value["current_segment_number"] = expected_segment

            continue_response = client.post(
                "/continue-interactive-story",
                headers=auth_headers,
                json={
                    "story_id": story_id,
                    "choice_id": f"choice-{expected_segment - 1}"
                }
            )
            assert continue_response.status_code == 200
            continue_data = continue_response.get_json()
            assert continue_data["segment"]["segment_number"] == expected_segment


class TestPickAPathChoiceValidation:
    """Test choice validation and error handling"""

    def test_choices_have_required_fields(self, client, auth_headers, test_character_fixture, mock_interactive_service):
        """Test that all choices include required fields (id and text)"""
        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "theme": "Fantasy",
                "length": "short"
            }
        )

        assert response.status_code == 200
        data = response.get_json()
        choices = data["segment"]["choices"]

        for choice in choices:
            assert "id" in choice, "Choice missing 'id' field"
            assert "text" in choice, "Choice missing 'text' field"
            assert isinstance(choice["id"], str), "Choice id must be string"
            assert isinstance(choice["text"], str), "Choice text must be string"
            assert len(choice["text"]) > 0, "Choice text cannot be empty"

    def test_choice_count_matches_length(self, client, auth_headers, test_character_fixture, mock_interactive_service):
        """Test that number of choices matches story length expectations"""
        # Short stories should have 2 choices
        mock_interactive_service.create_story.return_value["segment"]["choices"] = [
            {"id": "c1", "text": "Choice 1"},
            {"id": "c2", "text": "Choice 2"},
        ]

        response = client.post(
            "/generate-interactive-story",
            headers=auth_headers,
            json={
                "character_id": test_character_fixture.id,
                "theme": "Adventure",
                "length": "short"
            }
        )

        assert response.status_code == 200
        data = response.get_json()
        assert len(data["segment"]["choices"]) == 2

    def test_completed_story_has_no_choices(self, client, auth_headers, mock_interactive_service):
        """Test that completed stories have no available choices"""
        # Mock completed story
        mock_interactive_service.continue_story.return_value["is_completed"] = True
        mock_interactive_service.continue_story.return_value["segment"]["choices"] = []

        response = client.post(
            "/continue-interactive-story",
            headers=auth_headers,
            json={
                "story_id": "test-story-123",
                "choice_id": "final-choice"
            }
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data["is_completed"] is True
        assert data["segment"]["choices"] == []
