from datetime import datetime, timedelta, timezone

import jwt
import pytest

from backend.database import db
from backend.models import InteractiveStory, User


AGE_BANDS = [4, 7, 9, 12, 16]
STORY_MODES = ["standard", "rhyme", "learning_to_read"]
STORY_LENGTHS = ["quick", "standard", "epic"]

ARCHETYPES = [
    "The Bold Adventurer",
    "The Logic Luminary",
    "The Creative Catalyst",
    "The Heart Hero",
    "The Energy Engine",
    "The Quiet Observer",
]

COMPANIONS = [
    "Star Dog",
    "Shadow Cat",
    "Tiny Dragon",
    "Wise Owl",
    "Magic Unicorn",
    "Clever Fox",
]

PICK_A_PATH_SCENARIOS = [
    {"age": 5, "theme": "Magic Forest", "length": "short"},
    {"age": 8, "theme": "Space Station", "length": "medium"},
    {"age": 12, "theme": "Ocean Depths", "length": "long"},
    {"age": 16, "theme": "Cyberpunk City", "length": "short"},
    {"age": 9, "theme": "Ancient Egypt", "length": "medium"},
]


@pytest.fixture(autouse=True)
def mock_story_task(mocker):
    """Return deterministic story responses without real model calls."""
    result = {
        "status": "complete",
        "story": {
            "title": "Integration Test Story",
            "story_text": "Once upon a time, a young hero solved a challenge.",
            "theme": "Adventure",
            "wisdom_gem": "Keep going.",
        },
    }
    eager_result = mocker.MagicMock()
    eager_result.get.return_value = result

    task = mocker.MagicMock()
    task.apply.return_value = eager_result
    task.delay.return_value.id = "task-integration-123"
    mocker.patch("backend.routes.story_routes.generate_story_task", task)
    return task


@pytest.fixture(autouse=True)
def mock_interactive_service(mocker):
    service = mocker.MagicMock()
    service.create_story.return_value = {
        "story_id": "interactive-integration-story",
        "segment": {
            "segment_number": 1,
            "content": "You enter a glowing forest and hear a distant song.",
            "choices": [
                {"id": "choice-1", "text": "Follow the song"},
                {"id": "choice-2", "text": "Climb a tree"},
            ],
        },
    }
    service.continue_story.return_value = {
        "story_id": "interactive-integration-story",
        "segment": {
            "segment_number": 2,
            "content": "The song leads you to a hidden cave of crystals.",
            "choices": [
                {"id": "choice-3", "text": "Enter the cave"},
                {"id": "choice-4", "text": "Return home"},
            ],
        },
    }
    mocker.patch("backend.routes.story_routes.InteractiveAdventureService", return_value=service)
    return service


def _assert_story_generation_response(response):
    assert response.status_code in (200, 202)
    data = response.get_json()
    assert isinstance(data, dict)

    if response.status_code == 200:
        assert "story" in data
        assert isinstance(data["story"], dict)
        assert data["story"].get("story_text")
    else:
        assert data.get("status") == "processing"
        assert "task_id" in data
        assert "poll_url" in data


def _create_owned_interactive_story(app, story_id, user_id, age, theme, length):
    with app.app_context():
        db.session.add(
            InteractiveStory(
                id=story_id,
                user_id=user_id,
                title="Pick-a-Path Integration Story",
                theme=theme,
                tone="adventurous",
                length=length,
                age=age,
                current_segment_number=1,
                is_completed=False,
            )
        )
        db.session.commit()


def _create_auth_headers_for_user(app, user_id):
    with app.app_context():
        user = User(
            id=user_id,
            username=f"{user_id}_name",
            email=f"{user_id}@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
            role="user",
        )
        db.session.add(user)
        db.session.commit()

    payload = {
        "user_id": user_id,
        "sub": user_id,
        "email": f"{user_id}@example.com",
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(payload, "dev-secret-key", algorithm="HS256")
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


@pytest.mark.parametrize(
    "age,mode",
    [(age, mode) for age in AGE_BANDS for mode in STORY_MODES],
)
def test_age_group_story_generation_matrix(client, auth_headers, age, mode):
    payload = {
        "character": "Alex",
        "age": age,
        "theme": "Adventure",
        "story_length": "standard",
        "rhyme_time_mode": mode == "rhyme",
        "learning_to_read_mode": mode == "learning_to_read",
    }
    response = client.post("/generate-story", json=payload, headers=auth_headers)
    _assert_story_generation_response(response)


@pytest.mark.parametrize(
    "age,length",
    [(age, length) for age in AGE_BANDS for length in STORY_LENGTHS],
)
def test_story_duration_matrix(client, auth_headers, age, length):
    payload = {
        "character": "DurationTester",
        "age": age,
        "theme": "A Long Journey",
        "story_length": length,
    }
    response = client.post("/generate-story", json=payload, headers=auth_headers)
    _assert_story_generation_response(response)


@pytest.mark.parametrize(
    "archetype,companion",
    list(zip(ARCHETYPES, COMPANIONS)),
)
def test_feature_archetype_story_generation(client, auth_headers, archetype, companion):
    payload = {
        "character": "FeatureTester",
        "age": 10,
        "theme": "The Grand Challenge",
        "story_length": "standard",
        "character_details": {"role": archetype},
        "companion": companion,
    }
    response = client.post("/generate-story", json=payload, headers=auth_headers)
    _assert_story_generation_response(response)


def test_feature_custom_elements_story_generation(client, auth_headers):
    payload = {
        "character": "FeatureTester",
        "age": 10,
        "theme": "The Grand Challenge",
        "story_length": "standard",
        "customElements": "A flying skateboard and a talking robot bird",
        "companion": "Star Dog",
    }
    response = client.post("/generate-story", json=payload, headers=auth_headers)
    _assert_story_generation_response(response)


@pytest.mark.parametrize("scenario", PICK_A_PATH_SCENARIOS)
def test_pick_a_path_start_and_continue(client, app, scenario):
    user_id = f"pap-user-{scenario['age']}-{scenario['length']}"
    local_auth_headers = _create_auth_headers_for_user(app, user_id)
    story_id = f"pap-{scenario['age']}-{scenario['length']}"
    _create_owned_interactive_story(
        app=app,
        story_id=story_id,
        user_id=user_id,
        age=scenario["age"],
        theme=scenario["theme"],
        length=scenario["length"],
    )

    start_response = client.post(
        "/generate-interactive-story",
        json={
            "theme": scenario["theme"],
            "tone": "adventurous",
            "length": scenario["length"],
            "age": scenario["age"],
        },
        headers=local_auth_headers,
    )
    assert start_response.status_code == 200
    start_data = start_response.get_json()
    assert "story_id" in start_data
    assert "segment" in start_data
    assert start_data["segment"].get("choices")

    continue_response = client.post(
        "/continue-interactive-story",
        json={"story_id": story_id, "choice_id": "choice-1"},
        headers=local_auth_headers,
    )
    assert continue_response.status_code == 200
    continue_data = continue_response.get_json()
    assert continue_data.get("story_id")
    assert continue_data.get("segment", {}).get("segment_number") == 2
