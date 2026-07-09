"""Tests for MT-364 — Celery worker log redaction of child/companion PII.

The Celery worker runs with ``--loglevel=info`` in production (railway.toml),
and its stdout ships off-box to Railway/Sentry. Two related leaks in
``backend/tasks/story_tasks.py::generate_story_task`` put real child/
companion names into those logs at INFO level:

  1. The Rhyme Time branch logged the FULLY ASSEMBLED prompt
     (``f"Full prompt for rhyme time mode: {prompt}"``) *before*
     ``_scrub_real_name()`` ran — that scrub is a single call made once,
     after the whole mode if/elif chain. A real name injected via a
     free-text field (e.g. ``custom_elements``, which is embedded verbatim
     into the Rhyme Time prompt template) landed in logs unredacted even
     though the hero's *own* name is normally pseudonymized to ``HERO_1``
     before any prompt is built.
  2. Companion pet/character names are never pseudonymized like the hero
     name is (only the hero name gets the HERO_1 treatment), so logging
     ``companion_pets`` / ``companion_character_details`` /
     ``mandatory_names`` / the persisted ``characters_featured`` list
     directly put real companion (and, post-restore, real hero) names into
     INFO logs on every single story generation.

These tests run the real ``generate_story_task`` end to end (only the
outbound LLM call and the LLM-based moderation classifier are mocked) with
distinctive, obviously-not-a-coincidence real names, and assert those names
never appear in ANY captured log record — while confirming the story
response itself is unaffected (the child still gets their personalized
story back; this is a logging fix, not a functional regression).
"""

from __future__ import annotations

import json
import logging

import pytest

from backend.services.story_service import HERO_NAME_TOKEN
from backend.tasks.story_tasks import generate_story_task


# Disable the autouse Gemini mock from the parent conftest — every test here
# mocks `_generate_story_text_with_metadata` directly instead, so the real
# provider dispatch code is never reached.
@pytest.fixture(autouse=True)
def _no_gemini():
    yield


def _story_json(
    pages: list[str],
    *,
    title: str = "Test Story",
    characters_featured: list[str] | None = None,
) -> str:
    payload = {"title": title, "pages": [{"text": p} for p in pages]}
    if characters_featured is not None:
        payload["themes"] = ["friendship"]
        payload["characters_featured"] = characters_featured
        payload["emotional_arc"] = "growth"
    return json.dumps(payload)


def _assert_no_leak(caplog, *needles: str) -> None:
    """Fail with the offending record if any needle appears in any captured
    log message, at any level, from any logger."""
    for record in caplog.records:
        msg = record.getMessage()
        for needle in needles:
            assert needle not in msg, (
                f"PII leaked into worker log ({record.name} "
                f"{record.levelname}): {msg!r} contains {needle!r}"
            )


class TestGenerateStoryTaskDoesNotLogRealNames:
    """Full ``generate_story_task`` runs with distinctive real names; asserts
    none of them ever reach a captured log record."""

    def test_standard_mode_never_logs_real_names(self, app, mocker, caplog):
        """Covers: Companion Pets / Companion Character Details / Generated
        prompt length / Mandatory names / story_persisted log lines — none
        of these may carry the raw name objects, only counts/lengths.

        Creates (and tears down) its own throwaway user rather than using
        the shared ``test_user`` fixture, so this test controls the
        delete order (Story row before User row) itself instead of racing
        that fixture's teardown against the Story row this test persists.
        """
        from backend.database import db
        from backend.models.story import Story
        from backend.models.user import User

        real_name = "Persephone-Marigold"
        companion_pet_name = "Bramblewick"
        companion_character_name = "Thistlequill"
        user_id = "mt364_pii_test_user"

        with app.app_context():
            db.session.add(
                User(
                    id=user_id,
                    username="mt364testuser",
                    email="mt364@example.com",
                    password_hash="not-a-real-hash",
                    subscription_tier="free",
                    role="user",
                )
            )
            db.session.commit()

        try:
            sentence = (
                f"{HERO_NAME_TOKEN} adventured with {companion_pet_name} and "
                f"{companion_character_name} through the whispering meadow. "
            )
            story_pages = [sentence * 40]  # comfortably over the age-8 word floor
            story_json = _story_json(
                story_pages,
                characters_featured=[
                    HERO_NAME_TOKEN,
                    companion_pet_name,
                    companion_character_name,
                ],
            )

            mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)
            mocker.patch(
                "backend.utils.content_moderator.moderate_story_content",
                return_value=(True, ""),
            )
            mocker.patch(
                "backend.tasks.story_tasks._generate_story_text_with_metadata",
                return_value=(story_json, "mock-provider", ["mock-provider"]),
            )

            caplog.set_level(logging.DEBUG)

            result = generate_story_task.apply(
                kwargs={
                    "character": real_name,
                    "theme": "Adventure",
                    "user_id": user_id,
                    "age": 8,
                    "story_length": "standard",
                    "companion_pets": [
                        {"name": companion_pet_name, "species": "dragon"}
                    ],
                    "companion_characters": [{"name": companion_character_name}],
                }
            ).get()

            assert result["status"] == "complete", result

            # Sanity check: the fix is about LOGS, not the story/DB — the
            # child still gets their real name and companions back in the
            # response.
            assert real_name in result["story"]["story_text"]
            assert real_name in result["story"]["characters_featured"]
            assert companion_pet_name in result["story"]["characters_featured"]

            _assert_no_leak(
                caplog, real_name, companion_pet_name, companion_character_name
            )
        finally:
            with app.app_context():
                Story.query.filter_by(user_id=user_id).delete()
                User.query.filter_by(id=user_id).delete()
                db.session.commit()

    def test_rhyme_time_mode_never_logs_prompt_before_scrub(self, app, mocker, caplog):
        """Regression for the specific MT-364 leak: a real name injected via
        ``custom_elements`` (raw parent free text, embedded verbatim into the
        Rhyme Time prompt template) lands in the assembled prompt BEFORE
        ``_scrub_real_name()`` runs later in the function. The old code
        logged that unscrubbed prompt in full at INFO."""
        real_name = "Persephone-Marigold"
        companion_pet_name = "Bramblewick"

        story_pages = [
            f"{HERO_NAME_TOKEN} and {companion_pet_name} rhymed all day long "
            "beneath the sun so bright and strong. " * 20
        ]
        story_json = _story_json(story_pages)

        mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)
        mocker.patch(
            "backend.utils.content_moderator.moderate_story_content",
            return_value=(True, ""),
        )
        mocker.patch(
            "backend.tasks.story_tasks._generate_story_text_with_metadata",
            return_value=(story_json, "mock-provider", ["mock-provider"]),
        )

        caplog.set_level(logging.DEBUG)

        result = generate_story_task.apply(
            kwargs={
                "character": real_name,
                "theme": "Adventure",
                "user_id": "anonymous",
                "age": 8,
                "rhyme_time_mode": True,
                "companion_pets": [{"name": companion_pet_name, "species": "dragon"}],
                # Raw parent free text — this is how a stray real name has
                # historically reached the assembled prompt pre-scrub.
                "custom_elements": f"Please make sure {real_name} feels brave.",
            }
        ).get()

        assert result["status"] == "complete", result
        _assert_no_leak(caplog, real_name, companion_pet_name)
