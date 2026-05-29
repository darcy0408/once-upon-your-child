from datetime import datetime, timedelta, timezone

import jwt
import pytest
from flask_jwt_extended import create_access_token

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


def test_get_characters_filters_to_current_user(
    client, auth_headers, test_user, app, other_user
):
    with app.app_context():
        db.session.add_all(
            [
                Character(id="char-mine-1", user_id=test_user.id, name="Mine", age=6),
                Character(
                    id="char-other-1", user_id=other_user.id, name="Not Mine", age=10
                ),
            ]
        )
        db.session.commit()

    response = client.get("/get-characters", headers=auth_headers)

    assert response.status_code == 200
    returned_ids = {character["id"] for character in response.get_json()}
    assert "char-mine-1" in returned_ids
    assert "char-other-1" not in returned_ids


def test_user_a_cannot_read_user_b_parent_hidden_context(
    client, auth_headers, app, other_user
):
    with app.app_context():
        context = ParentHiddenContext(
            user_id=other_user.id,
            child_profile_id="shared-profile-id",
            feeling="frustrated",
            trigger="a limit is set",
            body_signal="a hot face",
            coping_tool="dragon breaths",
            repair_goal="try again with warmth",
        )
        db.session.add(context)
        db.session.commit()

    response = client.get(
        "/child-profiles/shared-profile-id/parent-hidden-context",
        headers=auth_headers,
    )

    assert response.status_code == 200
    # User A sees no record because the profile belongs to user B
    assert response.get_json()["parent_hidden_context"] is None


def test_user_a_put_parent_hidden_context_does_not_modify_user_b_record(
    client, auth_headers, app, other_user
):
    with app.app_context():
        context = ParentHiddenContext(
            user_id=other_user.id,
            child_profile_id="shared-profile-id",
            feeling="sad",
            trigger="a sibling conflict starts",
            body_signal="a tight tummy",
            coping_tool="a quiet pause",
            repair_goal="say sorry simply",
        )
        db.session.add(context)
        db.session.commit()

    response = client.put(
        "/child-profiles/shared-profile-id/parent-hidden-context",
        json={
            "feeling": "frustrated",
            "trigger": "a limit is set",
            "body_signal": "a hot face",
            "coping_tool": "dragon breaths",
            "repair_goal": "help fix what happened",
        },
        headers=auth_headers,
    )

    assert response.status_code == 200

    with app.app_context():
        other_context = ParentHiddenContext.query.filter_by(
            user_id=other_user.id,
            child_profile_id="shared-profile-id",
        ).one()
        # User B's record is unchanged
        assert other_context.trigger == "a sibling conflict starts"

        current_user_context = ParentHiddenContext.query.filter_by(
            user_id="test_user_123",
            child_profile_id="shared-profile-id",
        ).one()
        assert current_user_context.trigger == "a limit is set"


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
                    "exp": int(
                        (datetime.now(timezone.utc) - timedelta(hours=1)).timestamp()
                    ),
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


def test_user_a_cannot_poll_user_b_task_status(
    client, auth_headers, monkeypatch, other_user
):
    class FakeTask:
        state = "PROCESSING"
        info = {"status": "Generating story...", "user_id": other_user.id}
        result = None

    monkeypatch.setattr(
        "backend.routes.story_routes.celery.AsyncResult", lambda _: FakeTask()
    )

    response = client.get("/task-status/other-users-task", headers=auth_headers)

    assert response.status_code == 403
    assert response.get_json()["error"] == "Access denied"


def _jwt_extended_headers(app, user: User) -> dict[str, str]:
    with app.app_context():
        token = create_access_token(identity=user.id)
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


def test_api_key_set_requires_auth(client):
    response = client.post(
        "/api/user/settings/api-key", json={"api_key": "AIza" + ("a" * 35)}
    )

    assert response.status_code == 401


def test_api_key_set_own_key_succeeds(client, auth_headers, mocker, app, test_user):
    mocker.patch(
        "backend.routes.api_key_routes.test_gemini_api_key", return_value=(True, None)
    )
    mocker.patch(
        "backend.routes.api_key_routes.encrypt_api_key", return_value="encrypted-key"
    )
    response = client.post(
        "/api/user/settings/api-key",
        json={"api_key": "AIza" + ("a" * 35)},
        headers=auth_headers,
    )

    assert response.status_code == 200
    with app.app_context():
        user = db.session.get(User, test_user.id)
        assert user.has_byok is True


def test_api_key_cross_user_blocked(
    client, auth_headers, mocker, app, test_user, other_user
):
    mocker.patch(
        "backend.routes.api_key_routes.test_gemini_api_key", return_value=(True, None)
    )
    mocker.patch(
        "backend.routes.api_key_routes.encrypt_api_key", return_value="encrypted-key"
    )
    headers = {**auth_headers, "X-User-ID": other_user.id}
    response = client.post(
        "/api/user/settings/api-key",
        json={"api_key": "AIza" + ("a" * 35)},
        headers=headers,
    )

    assert response.status_code == 200
    with app.app_context():
        assert db.session.get(User, test_user.id).has_byok is True
        assert db.session.get(User, other_user.id).has_byok is False


def test_api_key_delete_requires_auth(client):
    response = client.delete("/api/user/settings/api-key")

    assert response.status_code == 401


def test_api_key_usage_requires_auth(client):
    response = client.get("/api/user/usage")

    assert response.status_code == 401


def test_api_key_usage_cross_user_blocked(
    client, auth_headers, app, test_user, other_user
):
    with app.app_context():
        db.session.get(User, test_user.id).stories_generated_this_month = 1
        db.session.get(User, other_user.id).stories_generated_this_month = 9
        db.session.commit()
    response = client.get(
        "/api/user/usage", headers={**auth_headers, "X-User-ID": other_user.id}
    )

    assert response.status_code == 200
    assert response.get_json()["stories"]["used"] == 1


def test_generate_illustrations_requires_auth(client):
    response = client.post(
        "/generate-illustrations", json={"scene_description": "A bright field"}
    )

    assert response.status_code == 401


def test_generate_illustrations_cross_character_blocked(
    client, auth_headers, app, other_user
):
    with app.app_context():
        db.session.add(
            Character(id="char-illus-other", user_id=other_user.id, name="Other", age=8)
        )
        db.session.commit()
    response = client.post(
        "/generate-story",
        json={
            "character_id": "char-illus-other",
            "theme": "Adventure",
            "include_illustrations": True,
        },
        headers=auth_headers,
    )

    assert response.status_code == 403


def test_generate_coloring_pages_requires_auth(client):
    response = client.post(
        "/generate-coloring-pages", json={"scene_description": "A calm castle"}
    )

    assert response.status_code == 401


def test_achievement_data_requires_auth(client):
    response = client.get("/achievement/data")

    assert response.status_code == 401


def test_achievement_sync_requires_auth(client):
    response = client.post("/achievement/sync", json={"achievements": [], "stats": {}})

    assert response.status_code == 401


def test_achievement_data_scoped_to_current_user(client, app, test_user, other_user):
    from backend.models import AchievementStats, UserAchievement

    user_headers = _jwt_extended_headers(app, test_user)
    other_headers = _jwt_extended_headers(app, other_user)
    create_response = client.post(
        "/achievement/record/story", json={"theme": "Adventure"}, headers=user_headers
    )
    response = client.get("/achievement/data", headers=other_headers)

    assert create_response.status_code == 200
    assert response.status_code == 200
    assert response.get_json()["stats"]["total_stories"] == 0
    assert not response.get_json()["achievements"]
    with app.app_context():
        UserAchievement.query.delete()
        AchievementStats.query.delete()
        db.session.commit()
