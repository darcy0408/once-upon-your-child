import pytest


def _assert_story_response(response):
    assert response.status_code in (200, 202)
    payload = response.get_json()
    assert isinstance(payload, dict)
    if response.status_code == 200:
        assert payload.get("status") == "complete"
        assert isinstance(payload.get("story"), dict)
    else:
        assert payload.get("status") == "processing"
        assert payload.get("task_id")


@pytest.fixture
def mock_story_task(mocker):
    """Mock story generation task so integration tests stay deterministic."""
    result = {
        "status": "complete",
        "story": {
            "title": "Feature Integration Story",
            "story_text": "A short deterministic story.",
            "theme": "Adventure",
            "wisdom_gem": "Kindness helps.",
        },
    }

    eager_result = mocker.MagicMock()
    eager_result.get.return_value = result

    task = mocker.MagicMock()
    task.apply_async.return_value = eager_result
    task.delay.return_value.id = "task-feature-123"

    mocker.patch("backend.routes.story_routes.generate_story_task", task)
    return task


def _post_story_and_get_task_kwargs(
    client, auth_headers, mock_story_task, **payload_overrides
):
    payload = {
        "character": "FeatureTester",
        "age": 10,
        "theme": "Adventure",
        "story_length": "standard",
    }
    payload.update(payload_overrides)

    response = client.post("/generate-story", json=payload, headers=auth_headers)
    _assert_story_response(response)

    assert mock_story_task.apply_async.called
    forwarded = mock_story_task.apply_async.call_args.kwargs.get("kwargs")
    assert isinstance(forwarded, dict)
    return forwarded


def test_feature_archetype_is_forwarded(client, auth_headers, mock_story_task):
    forwarded = _post_story_and_get_task_kwargs(
        client,
        auth_headers,
        mock_story_task,
        character_details={"role": "The Logic Luminary"},
    )

    assert forwarded["character_details"]["role"] == "The Logic Luminary"


def test_feature_companion_pets_are_forwarded(client, auth_headers, mock_story_task):
    pets = [{"name": "Milo", "species": "dog", "type": "pet"}]
    forwarded = _post_story_and_get_task_kwargs(
        client,
        auth_headers,
        mock_story_task,
        companion_pets=pets,
    )

    assert forwarded["companion_pets"] == pets


def test_feature_companion_characters_are_forwarded(
    client, auth_headers, mock_story_task
):
    companions = [{"name": "Zara"}, {"name": "Noah"}]
    forwarded = _post_story_and_get_task_kwargs(
        client,
        auth_headers,
        mock_story_task,
        companion_characters=companions,
    )

    assert forwarded["companion_characters"] == companions


def test_feature_additional_characters_top_level_are_forwarded(
    client, auth_headers, mock_story_task
):
    """MT-194: `additional_characters` sent at the top of the request body
    (Flutter client default) must be plumbed into task_kwargs so the
    downstream prompt builder receives the guest cast.
    """
    extras = ["Maya", "Jordan"]
    forwarded = _post_story_and_get_task_kwargs(
        client,
        auth_headers,
        mock_story_task,
        additional_characters=extras,
    )

    assert forwarded["additional_characters"] == extras


def test_feature_additional_characters_nested_fallback_is_forwarded(
    client, auth_headers, mock_story_task
):
    """MT-194: wizard flow nests guests under `character_details` as
    `additionalCharacters`. When the top-level key is absent, the nested
    spelling must still reach task_kwargs.
    """
    extras = ["Grandma Rose"]
    forwarded = _post_story_and_get_task_kwargs(
        client,
        auth_headers,
        mock_story_task,
        character_details={"additionalCharacters": extras},
    )

    assert forwarded["additional_characters"] == extras


def test_feature_custom_elements_are_mapped(client, auth_headers, mock_story_task):
    custom = "A flying skateboard and a talking robot bird"
    forwarded = _post_story_and_get_task_kwargs(
        client,
        auth_headers,
        mock_story_task,
        customElements=custom,
    )

    assert forwarded["custom_elements"] == custom


def test_feature_mood_physics_are_mapped(client, auth_headers, mock_story_task):
    mood = {
        "mood": "Excited",
        "worldRule": "Gravity dances when you laugh",
        "sensoryChange": "The air crackles like soda bubbles",
    }
    forwarded = _post_story_and_get_task_kwargs(
        client,
        auth_headers,
        mock_story_task,
        moodPhysics=mood,
    )

    assert forwarded["mood_physics"] == mood


def test_feature_rhyme_time_mode_is_forwarded(client, auth_headers, mock_story_task):
    forwarded = _post_story_and_get_task_kwargs(
        client,
        auth_headers,
        mock_story_task,
        rhyme_time_mode=True,
    )

    assert forwarded["rhyme_time_mode"] is True


def test_feature_illustration_generation_ignores_user_api_key(
    client, auth_headers, monkeypatch
):
    """BYOK sunset (MT-358): a stray `user_api_key` from an old client is
    ignored — generation always runs on the server-managed pipeline and the
    response reports used_user_key=False."""
    from backend.routes import story_routes

    monkeypatch.setattr(
        story_routes,
        "_generate_flux_illustration",
        lambda **kwargs: [
            {
                "id": "img-1",
                "image_data": "a" * 256,
                "prompt": "A bright forest clearing with friendly companions.",
            }
        ],
    )

    response = client.post(
        "/generate-illustrations",
        json={
            "scene_description": "A bright forest clearing with friendly companions.",
            "character_name": "FeatureTester",
            "user_api_key": "stale-byok-key",
            "companion_pets": [{"name": "Milo", "species": "dog"}],
        },
        headers=auth_headers,
    )

    assert response.status_code == 200
    payload = response.get_json()
    assert isinstance(payload.get("illustrations"), list)
    assert payload.get("count") == 1
    assert payload["illustrations"][0].get("image_data")
    assert payload.get("used_user_key") is False
