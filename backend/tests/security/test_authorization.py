import jwt
import pytest
from datetime import datetime, timedelta, timezone

from backend.database import db
from backend.models import Character, ParentHiddenContext, User


def _auth_headers_for_user(user: User) -> dict[str, str]:
    payload = {
        "user_id": user.id,
        "sub": user.id,
        "email": user.email,
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    token = jwt.encode(payload, "dev-secret-key", algorithm="HS256")
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


@pytest.fixture
def other_user(app):
    with app.app_context():
        user = User(
            id="other_user_456",
            username="otheruser",
            email="other@example.com",
            password_hash="hashed_password",
            subscription_tier="free",
            role="user",
        )
        db.session.add(user)
        db.session.commit()
        yield user


@pytest.fixture
def other_auth_headers(other_user):
    return _auth_headers_for_user(other_user)


def test_user_a_cannot_read_user_b_character(client, auth_headers, app, other_user):
    with app.app_context():
        character = Character(
            id="char-owned-by-other",
            user_id=other_user.id,
            name="Shadow",
            age=8,
        )
        db.session.add(character)
        db.session.commit()

    response = client.get("/characters/char-owned-by-other", headers=auth_headers)

    assert response.status_code == 403
    assert response.get_json()["error"] == "Unauthorized"


def test_user_a_cannot_update_user_b_character(client, auth_headers, app, other_user):
    with app.app_context():
        character = Character(
            id="char-update-other",
            user_id=other_user.id,
            name="Protected",
            age=9,
        )
        db.session.add(character)
        db.session.commit()

    response = client.put(
        "/characters/char-update-other",
        json={"name": "Hacked"},
        headers=auth_headers,
    )

    assert response.status_code == 403
    with app.app_context():
        saved = db.session.get(Character, "char-update-other")
        assert saved.name == "Protected"


def test_user_a_cannot_delete_user_b_character(client, auth_headers, app, other_user):
    with app.app_context():
        character = Character(
            id="char-delete-other",
            user_id=other_user.id,
            name="Safe",
            age=7,
        )
        db.session.add(character)
        db.session.commit()

    response = client.delete("/characters/char-delete-other", headers=auth_headers)

    assert response.status_code == 403
    with app.app_context():
        assert db.session.get(Character, "char-delete-other") is not None


def test_get_characters_filters_to_current_user(client, auth_headers, test_user, app, other_user):
    with app.app_context():
        db.session.add_all(
            [
                Character(id="char-mine-1", user_id=test_user.id, name="Mine", age=6),
                Character(id="char-other-1", user_id=other_user.id, name="Not Mine", age=10),
            ]
        )
        db.session.commit()

    response = client.get("/get-characters", headers=auth_headers)

    assert response.status_code == 200
    returned_ids = {character["id"] for character in response.get_json()}
    assert "char-mine-1" in returned_ids
    assert "char-other-1" not in returned_ids


def test_user_a_cannot_read_user_b_parent_hidden_context(client, auth_headers, app, other_user):
    with app.app_context():
        context = ParentHiddenContext(
            user_id=other_user.id,
            child_profile_id="shared-profile-id",
            feeling="frustrated",
            trigger="bedtime",
            body_signal="tight fists",
            coping_tool="dragon breaths",
            repair_goal="reconnect kindly",
            parent_hidden_context="private note for other family",
        )
        db.session.add(context)
        db.session.commit()

    response = client.get(
        "/child-profiles/shared-profile-id/parent-hidden-context",
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert response.get_json()["parent_hidden_context"] is None


def test_user_a_put_parent_hidden_context_does_not_modify_user_b_record(
    client, auth_headers, app, other_user
):
    with app.app_context():
        context = ParentHiddenContext(
            user_id=other_user.id,
            child_profile_id="shared-profile-id",
            feeling="sad",
            trigger="rainy day",
            body_signal="droopy shoulders",
            coping_tool="snuggle blanket",
            repair_goal="ask for a hug",
            parent_hidden_context="other user's note",
        )
        db.session.add(context)
        db.session.commit()

    response = client.put(
        "/child-profiles/shared-profile-id/parent-hidden-context",
        json={
            "feeling": "frustrated",
            "trigger": "screen time ended",
            "body_signal": "hot face",
            "coping_tool": "dragon breaths",
            "repair_goal": "help clean up",
            "parent_hidden_context": "my own note",
        },
        headers=auth_headers,
    )

    assert response.status_code == 200

    with app.app_context():
        other_context = ParentHiddenContext.query.filter_by(
            user_id=other_user.id,
            child_profile_id="shared-profile-id",
        ).one()
        assert other_context.parent_hidden_context == "other user's note"

        current_user_context = ParentHiddenContext.query.filter_by(
            user_id="test_user_123",
            child_profile_id="shared-profile-id",
        ).one()
        assert current_user_context.parent_hidden_context == "my own note"


@pytest.mark.parametrize(
    ("method", "url", "kwargs"),
    [
        ("get", "/get-characters", {}),
        ("get", "/characters/any-id", {}),
        ("put", "/characters/any-id", {"json": {"name": "NoAuth"}}),
        ("delete", "/characters/any-id", {}),
        ("get", "/child-profiles/profile-1/parent-hidden-context", {}),
        (
            "put",
            "/child-profiles/profile-1/parent-hidden-context",
            {
                "json": {
                    "feeling": "frustrated",
                    "trigger": "a limit is set",
                    "body_signal": "hot face",
                    "coping_tool": "dragon breaths",
                    "repair_goal": "help fix what happened",
                }
            },
        ),
        ("get", "/interactive-story/any-id", {}),
        ("get", "/interactive-story/any-id/resume", {}),
    ],
)
def test_unauthenticated_requests_are_rejected(client, method, url, kwargs):
    response = getattr(client, method)(url, **kwargs)

    assert response.status_code == 401


@pytest.mark.parametrize(
    ("token", "expected_status"),
    [
        ("definitely-not-a-jwt", 401),
        (
            jwt.encode(
                {
                    "user_id": "test_user_123",
                    "exp": int((datetime.now(timezone.utc) - timedelta(hours=1)).timestamp()),
                },
                "dev-secret-key",
                algorithm="HS256",
            ),
            401,
        ),
    ],
)
def test_invalid_tokens_are_rejected(client, token, expected_status):
    response = client.get(
        "/get-characters",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == expected_status


def test_user_a_cannot_poll_user_b_task_status(client, auth_headers, monkeypatch, other_user):
    class FakeTask:
        state = "PROCESSING"
        info = {"status": "Generating story...", "user_id": other_user.id}
        result = None

    monkeypatch.setattr("backend.routes.story_routes.celery.AsyncResult", lambda _: FakeTask())

    response = client.get("/task-status/other-users-task", headers=auth_headers)

    assert response.status_code == 403
    assert response.get_json()["error"] == "Access denied"
