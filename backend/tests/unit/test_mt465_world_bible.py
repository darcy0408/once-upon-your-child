"""MT-465: the standard story path must forward the scene world bible.

The route passes ``world_bible`` to the Celery task, but the standard
``generate_enhanced_prompt`` call used to drop it, leaving the WORLD BIBLE
prompt line empty for every standard story.
"""

from backend.services.story_service import AdvancedStoryEngine
from backend.tasks.story_tasks import generate_story_task


def _run_standard_task(app, mocker, **extra):
    mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)
    mocker.patch(
        "backend.tasks.story_tasks.pseudonymize_hero_name",
        side_effect=lambda real_name, *args, **kwargs: real_name or "Hero",
    )
    mocker.patch(
        "backend.utils.content_moderator.moderate_story_content",
        return_value=(True, ""),
    )
    story = " ".join(
        ["Avery crossed the bamboo forest and listened to the quiet wind."] * 80
    )
    mocker.patch(
        "backend.tasks.story_tasks._generate_story_text_with_metadata",
        return_value=(
            '{"title": "T", "pages": ["%s"], "wisdom_gem": "Be kind."}' % story,
            "mock-provider",
            ["mock-provider"],
        ),
    )
    spy = mocker.spy(AdvancedStoryEngine, "generate_enhanced_prompt")
    kwargs = {
        "character": "Avery",
        "theme": "Adventure",
        "user_id": "test-user",
        "age": 7,
        "story_length": "standard",
    }
    kwargs.update(extra)
    generate_story_task.apply(kwargs=kwargs).get()
    return spy


def test_standard_path_forwards_world_bible(app, mocker):
    bible = "The bamboo forest has moon gates and echoing bridges."
    spy = _run_standard_task(app, mocker, world_bible=bible)

    assert spy.call_count >= 1
    assert spy.call_args_list[0].kwargs["world_bible"] == bible


def test_standard_path_defaults_world_bible_to_empty(app, mocker):
    spy = _run_standard_task(app, mocker)

    assert spy.call_count >= 1
    assert spy.call_args_list[0].kwargs["world_bible"] == ""
