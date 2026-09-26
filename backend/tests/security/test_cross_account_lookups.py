"""Lookups fed by request data must stay inside the caller's own records."""

import json
import uuid
from unittest.mock import patch

import pytest

from backend.database import db
from backend.models import (
    Character,
    InteractiveStory,
    StoryChoice,
    StorySegment,
    StoryState,
    User,
)
from backend.services.interactive_adventure_service import (
    InteractiveAdventureService,
)
from backend.tasks.story_tasks import _find_owned_companion


@pytest.fixture
def other_family(app):
    with app.app_context():
        user = User(
            id="other_user_456",
            username="otherfamily",
            email="other@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
            role="user",
        )
        character = Character(
            id="char_other_456", user_id=user.id, name="Milo", age=4, role="brother"
        )
        db.session.add_all([user, character])
        db.session.commit()
        yield user, character
        db.session.delete(character)
        db.session.delete(user)
        db.session.commit()


def test_companion_lookup_never_matches_another_accounts_character(
    app, test_user, test_character, other_family
):
    with app.app_context():
        assert _find_owned_companion("Milo", test_user.id) is None
        assert _find_owned_companion("Luna", test_user.id).id == test_character.id
        assert _find_owned_companion("Milo", "other_user_456").id == "char_other_456"


@pytest.mark.parametrize("user_id", [None, "", "anonymous"])
def test_companion_lookup_matches_nothing_without_a_real_user(
    app, test_character, user_id
):
    with app.app_context():
        assert _find_owned_companion("Luna", user_id) is None


def _story_with_choice(user_id, character_id, choice_text):
    story = InteractiveStory(
        id=str(uuid.uuid4()),
        user_id=user_id,
        character_id=character_id,
        title="Adventure",
        theme="Adventure",
        tone="fantasy",
        length="long",
        age=7,
        current_segment_number=1,
    )
    db.session.add(story)
    db.session.add(StoryState(id=str(uuid.uuid4()), story_id=story.id))
    segment = StorySegment(
        id=str(uuid.uuid4()), story_id=story.id, segment_number=1, content="Start."
    )
    db.session.add(segment)
    db.session.flush()
    choice = StoryChoice(
        id=str(uuid.uuid4()), segment_id=segment.id, choice_number=1, text=choice_text
    )
    db.session.add(choice)
    story.current_segment_id = segment.id
    db.session.commit()
    return story, choice


def test_continue_story_rejects_a_choice_from_a_different_story(
    app, test_user, test_character, other_family
):
    other_user, other_character = other_family
    with app.app_context():
        mine, my_choice = _story_with_choice(
            test_user.id, test_character.id, "my choice"
        )
        theirs, their_choice = _story_with_choice(
            other_user.id, other_character.id, "their private choice"
        )
        their_choice_id = their_choice.id

        service = InteractiveAdventureService()
        with patch.object(
            InteractiveAdventureService,
            "_generate_text",
            side_effect=lambda prompt: json.dumps(
                {"content": "Next.", "is_ending": True, "choices": []}
            ),
        ) as generate:
            with pytest.raises(ValueError):
                service.continue_story(mine.id, their_choice_id)
            generate.assert_not_called()

        db.session.rollback()
        assert db.session.get(StoryChoice, their_choice_id).is_selected is False

        for story in (mine, theirs):
            db.session.delete(db.session.get(InteractiveStory, story.id))
        db.session.commit()


# ---------------------------------------------------------------------------
# A character with no owner is nobody's: it must not be readable, editable,
# or usable for generation by an arbitrary signed-in account.
# ---------------------------------------------------------------------------


@pytest.fixture
def ownerless_character(app):
    with app.app_context():
        character = Character(id="char_ownerless", user_id=None, name="Nobody", age=6)
        db.session.add(character)
        db.session.commit()
        yield character
        row = db.session.get(Character, "char_ownerless")
        if row is not None:
            db.session.delete(row)
            db.session.commit()


def test_ownerless_character_cannot_be_read_edited_or_deleted(
    client, auth_headers, test_user, ownerless_character
):
    assert (
        client.get("/characters/char_ownerless", headers=auth_headers).status_code
        == 403
    )
    assert (
        client.put(
            "/characters/char_ownerless",
            json={"name": "Mine now"},
            headers=auth_headers,
        ).status_code
        == 403
    )
    assert (
        client.delete("/characters/char_ownerless", headers=auth_headers).status_code
        == 403
    )


def test_ownerless_character_cannot_be_used_to_generate_a_story(
    client, auth_headers, test_user, ownerless_character, mocker
):
    mocker.patch(
        "backend.routes.story_routes.check_daily_quota", return_value=(True, 0, 5, "")
    )
    task = mocker.patch("backend.routes.story_routes.generate_story_task")

    response = client.post(
        "/generate-story",
        json={"character_id": "char_ownerless", "theme": "Adventure"},
        headers=auth_headers,
    )

    assert response.status_code == 403
    task.delay.assert_not_called()
    task.apply_async.assert_not_called()
