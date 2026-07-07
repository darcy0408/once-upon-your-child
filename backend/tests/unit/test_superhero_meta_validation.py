"""Tests for the Superhero Mode metadata-resolution fix + post-generation
validator (2026-07-07).

Covers three related bugs found in production:

1. superhero_meta band mislabeling — Creator (13-14) / Adolescent (15-17)
   requests reported ``band: "sprout"`` plus Sprout villain/problem ids that
   never appeared in the prose, because the age-band derivation in
   ``generate_story_task`` (now extracted to ``_superhero_band_for_age``)
   never had branches for those bands and fell through to "sprout", while
   ``PromptService.build_story_prompt`` derived the (correct) band itself and
   silently re-picked a different pairing. Fixed by mirroring
   prompt_service.py's exact age thresholds.

2. saga_state incompleteness — ``_normalize_saga_state`` (story_service.py)
   whitelisted only 4 of the 7 keys every band's saga_state OUTPUT FORMAT
   promises, silently dropping ``what_it_cost``/``allies``/``defining_choice``
   even when the model emitted them.

3. Decorative validation — ``validation_issues`` was always ``[]`` for every
   Superhero story regardless of band, even when word count or page count
   were badly off spec. Fixed via ``backend/services/superhero_validation.py``
   + ``_validate_and_regen_superhero``.

This file tests the pure band-derivation helper and the validation/regen
orchestration directly (no LLM/DB), plus one full ``generate_story_task`` run
per mature band to confirm the resolved ``superhero_meta`` (villain/problem/
band) actually reflects what shaped the story, including when the client
supplies an invalid or absent villain id.
"""

from __future__ import annotations

import json

import pytest

from backend.data.superhero_matrix import (
    ADOLESCENT_PROBLEMS,
    ADOLESCENT_VILLAIN_PROBLEMS,
    ADOLESCENT_VILLAINS,
    CREATOR_PROBLEMS,
    CREATOR_VILLAINS,
)
from backend.tasks.story_tasks import (
    _superhero_band_for_age,
    _validate_and_regen_superhero,
    generate_story_task,
)


# Disable the autouse Gemini mock from the parent conftest — every test here
# either never reaches the LLM layer or mocks the generation call directly.
@pytest.fixture(autouse=True)
def _no_gemini():
    yield


def _make_story_json(
    pages: list[str],
    title: str = "A Test Issue",
    saga_state: dict | None = None,
) -> str:
    payload = {"title": title, "pages": [{"text": p} for p in pages]}
    if saga_state is not None:
        payload["saga_state"] = saga_state
    return json.dumps(payload)


# ---------------------------------------------------------------------------
# 1. _superhero_band_for_age — must mirror PromptService.build_story_prompt's
#    age-band routing (prompt_service.py ~L96-197) EXACTLY.
# ---------------------------------------------------------------------------
class TestSuperheroBandForAge:
    @pytest.mark.parametrize(
        "age, expected_band",
        [
            (0, "sprout"),
            (3, "sprout"),
            (5, "sprout"),
            (6, "explorer"),
            (8, "explorer"),
            (9, "adventurer"),
            (12, "adventurer"),
            (13, "creator"),  # was the bug: used to fall through to sprout
            (14, "creator"),
            (15, "adolescent"),
            (17, "adolescent"),
            (18, "creator"),  # no dedicated Adult template; mirrors prompt_service
            (25, "creator"),
        ],
    )
    def test_band_matches_prompt_service_thresholds(self, age, expected_band):
        assert _superhero_band_for_age(age) == expected_band

    def test_none_age_defaults_to_sprout(self):
        assert _superhero_band_for_age(None) == "sprout"

    def test_unparseable_age_defaults_to_sprout(self):
        assert _superhero_band_for_age("not-an-age") == "sprout"


# ---------------------------------------------------------------------------
# 2. _validate_and_regen_superhero — word/page validation + capped-at-1 regen
# ---------------------------------------------------------------------------
class TestValidateAndRegenSuperhero:
    def _creator_pages(self, n=7, words_per_page=10):
        return [f"Beat {i} " + " ".join(["word"] * words_per_page) for i in range(n)]

    # NOTE: these generic word/page-count tests use band="adventurer" (page
    # spec 6/6, word spec 900-1500) rather than "creator" specifically so
    # they're not entangled with the Creator/Adolescent saga_state
    # completeness check (covered separately below) — Adventurer isn't part
    # of that continuity feature (see SAGA_STATE_REQUIRED_KEYS), so a bare
    # ``{"saga_state": None}`` never adds a stray issue here.

    def test_within_spec_no_regen_no_issues(self):
        pages = self._creator_pages(n=6, words_per_page=170)  # 1020 words, 6 pages
        regen_fn_calls = []

        title, body, out_pages, post, metadata, issues = _validate_and_regen_superhero(
            band="adventurer",
            theme="superhero",
            title="Adventure",
            story_body="\n\n".join(pages),
            pages=pages,
            post_story={},
            story_metadata={"saga_state": None},
            base_prompt="PROMPT",
            regen_fn=lambda p: regen_fn_calls.append(p) or "unused",
        )

        assert out_pages == pages
        assert not regen_fn_calls  # word/page count fine -> no regen attempted
        assert issues == []

    def test_page_count_wrong_triggers_regen_and_uses_compliant_result(self):
        bad_pages = self._creator_pages(n=7, words_per_page=100)  # 7 pages, need 6
        good_pages = self._creator_pages(n=6, words_per_page=100)
        regen_text = _make_story_json(good_pages, title="Adventure (regen)")
        calls = []

        def regen_fn(prompt):
            calls.append(prompt)
            return regen_text

        title, body, out_pages, post, metadata, issues = _validate_and_regen_superhero(
            band="adventurer",
            theme="superhero",
            title="Adventure",
            story_body="\n\n".join(bad_pages),
            pages=bad_pages,
            post_story={},
            story_metadata={"saga_state": None},
            base_prompt="PROMPT",
            regen_fn=regen_fn,
        )

        assert len(calls) == 1  # capped at exactly one retry
        assert len(out_pages) == 6  # the compliant regen attempt was kept
        assert title == "Adventure (regen)"
        assert issues == []  # regen fixed the page-count issue

    def test_word_count_over_25pct_triggers_regen(self):
        # Adventurer ceiling is 1500 words; >25% over = >1875.
        bad_pages = self._creator_pages(n=6, words_per_page=400)  # 2400 words
        good_pages = self._creator_pages(n=6, words_per_page=200)  # 1200 words
        regen_text = _make_story_json(good_pages)
        calls = []

        def regen_fn(prompt):
            calls.append(prompt)
            return regen_text

        _, _, out_pages, _, _, issues = _validate_and_regen_superhero(
            band="adventurer",
            theme="superhero",
            title="Adventure",
            story_body="\n\n".join(bad_pages),
            pages=bad_pages,
            post_story={},
            story_metadata={"saga_state": None},
            base_prompt="PROMPT",
            regen_fn=regen_fn,
        )

        assert len(calls) == 1
        total_words = sum(len(p.split()) for p in out_pages)
        assert total_words == sum(len(p.split()) for p in good_pages)  # regen kept
        assert total_words < 1500  # back within the Adventurer ceiling

    def test_regen_still_bad_keeps_better_of_two_attempts(self):
        # Original: word count way over AND wrong page count (2 issues).
        bad_pages = self._creator_pages(n=7, words_per_page=400)
        # Regen: only word count still bad (1 issue) -> strictly better, kept.
        regen_pages = self._creator_pages(n=6, words_per_page=400)
        regen_text = _make_story_json(regen_pages, title="Regen Attempt")

        _, _, out_pages, _, _, issues = _validate_and_regen_superhero(
            band="adventurer",
            theme="superhero",
            title="Adventure",
            story_body="\n\n".join(bad_pages),
            pages=bad_pages,
            post_story={},
            story_metadata={"saga_state": None},
            base_prompt="PROMPT",
            regen_fn=lambda p: regen_text,
        )

        assert len(out_pages) == 6  # regen kept: fewer issues than original
        assert len(issues) == 1
        assert issues[0]["type"] == "word_count"

    def test_regen_worse_keeps_original(self):
        # Original: only page count wrong (1 issue).
        original_pages = self._creator_pages(n=7, words_per_page=10)
        # Regen: BOTH word count and page count wrong (2 issues) -> worse, discarded.
        regen_pages = self._creator_pages(n=8, words_per_page=400)
        regen_text = _make_story_json(regen_pages, title="Worse Regen")

        title, _, out_pages, _, _, issues = _validate_and_regen_superhero(
            band="adventurer",
            theme="superhero",
            title="Original Title",
            story_body="\n\n".join(original_pages),
            pages=original_pages,
            post_story={},
            story_metadata={"saga_state": None},
            base_prompt="PROMPT",
            regen_fn=lambda p: regen_text,
        )

        assert title == "Original Title"
        assert len(out_pages) == 7
        assert len(issues) == 1

    def test_regen_call_failure_keeps_original(self):
        bad_pages = self._creator_pages(n=7, words_per_page=10)

        def broken_regen(prompt):
            raise RuntimeError("provider down")

        title, body, out_pages, post, metadata, issues = _validate_and_regen_superhero(
            band="adventurer",
            theme="superhero",
            title="Original Title",
            story_body="\n\n".join(bad_pages),
            pages=bad_pages,
            post_story={},
            story_metadata={"saga_state": None},
            base_prompt="PROMPT",
            regen_fn=broken_regen,
        )

        assert title == "Original Title"
        assert len(out_pages) == 7
        assert len(issues) == 1  # the original page-count issue still recorded

    def test_saga_state_backfilled_and_flagged_for_creator(self):
        incomplete_saga = {"nemesis": "The Optimizer", "nemesis_status": "reconsidered"}
        pages = self._creator_pages(n=7, words_per_page=10)

        _, _, _, _, metadata, issues = _validate_and_regen_superhero(
            band="creator",
            theme="superhero",
            title="Issue 1",
            story_body="\n\n".join(pages),
            pages=pages,
            post_story={},
            story_metadata={"saga_state": incomplete_saga},
            base_prompt="PROMPT",
            regen_fn=lambda p: (_ for _ in ()).throw(
                AssertionError("saga_state alone must never trigger a regen")
            ),
        )

        assert metadata["saga_state"]["what_it_cost"] == ""
        assert metadata["saga_state"]["allies"] == []
        assert metadata["saga_state"]["defining_choice"] == ""
        # Original keys untouched.
        assert metadata["saga_state"]["nemesis"] == "The Optimizer"
        saga_issues = [i for i in issues if i["type"] == "saga_state_incomplete"]
        assert len(saga_issues) == 1
        assert set(saga_issues[0]["missing_keys"]) == {
            "what_changed",
            "what_it_cost",
            "next_hook",
            "allies",
            "defining_choice",
        }

    def test_saga_state_completeness_not_enforced_for_adventurer(self):
        # Adventurer band isn't part of the returnable-saga continuity feature
        # (see SAGA_STATE_REQUIRED_KEYS) — a sparse saga_state is left as-is.
        sparse_saga = {"nemesis": "Gigawatt"}
        pages = ["p1", "p2", "p3", "p4", "p5", "p6"]  # 6 pages = Adventurer spec

        _, _, _, _, metadata, issues = _validate_and_regen_superhero(
            band="adventurer",
            theme="superhero",
            title="Adventure",
            story_body="\n\n".join(pages),
            pages=pages,
            post_story={},
            story_metadata={"saga_state": sparse_saga},
            base_prompt="PROMPT",
            regen_fn=lambda p: (_ for _ in ()).throw(AssertionError("must not regen")),
        )

        assert metadata["saga_state"] == {"nemesis": "Gigawatt"}
        assert issues == []


# ---------------------------------------------------------------------------
# 3. Full generate_story_task run — resolved superhero_meta correctness for
#    Creator (absent villain id) and Adolescent (invalid villain id).
# ---------------------------------------------------------------------------
class TestGenerateStoryTaskSuperheroMetaBand:
    def _run(self, app, mocker, *, age, extra_kwargs=None, story_pages=None):
        mocker.patch("backend.tasks.story_tasks.get_flask_app", return_value=app)
        mocker.patch(
            "backend.tasks.story_tasks.pseudonymize_hero_name",
            side_effect=lambda real_name, *a, **k: real_name or "Hero",
        )
        mocker.patch(
            "backend.utils.content_moderator.moderate_story_content",
            return_value=(True, ""),
        )

        if story_pages is None:
            # 7 beats, hero name present, well within any mature band's word
            # ceiling — keeps this test isolated to metadata resolution, not
            # the word/page validator (covered above).
            story_pages = [f"Beat {i}: Riley acts." for i in range(1, 8)]
        story_json = _make_story_json(story_pages, title="Test Issue")
        mocker.patch(
            "backend.tasks.story_tasks._generate_story_text_with_metadata",
            return_value=(story_json, "mocked-provider", ["mocked-provider"]),
        )

        kwargs = {
            "character": "Riley",
            "theme": "superhero",
            "user_id": "anonymous",
            "age": age,
            "hero_power": "super_smile",
        }
        kwargs.update(extra_kwargs or {})
        result = generate_story_task.apply(kwargs=kwargs).get()
        assert result["status"] == "complete", result
        return result["story"]

    def test_creator_age_14_absent_villain_id_resolves_creator_band(self, app, mocker):
        result = self._run(app, mocker, age=14)

        meta = result["superhero_meta"]
        assert meta["band"] == "creator"
        assert meta["villain_id"] in CREATOR_VILLAINS
        assert meta["problem_id"] in CREATOR_PROBLEMS
        # The bug: these used to be Sprout ids (e.g. cranky_crab/cheer_up).
        assert meta["villain_id"] not in ("cranky_crab", "the_frownerator")

    def test_adolescent_age_16_invalid_villain_id_resolves_adolescent_band(
        self, app, mocker
    ):
        # hero_nemesis_id is only honored when it's a valid id for the
        # resolved band (apply_nemesis_override) — an invalid/foreign id must
        # be ignored, not silently accepted or crash resolution.
        result = self._run(
            app,
            mocker,
            age=16,
            extra_kwargs={"hero_nemesis_id": "cranky_crab"},  # Sprout-only id
        )

        meta = result["superhero_meta"]
        assert meta["band"] == "adolescent"
        assert meta["villain_id"] in ADOLESCENT_VILLAINS
        assert meta["problem_id"] in ADOLESCENT_PROBLEMS

    def test_adolescent_age_16_valid_nemesis_id_is_honored(self, app, mocker):
        result = self._run(
            app,
            mocker,
            age=16,
            extra_kwargs={"hero_nemesis_id": "ledger"},  # valid Adolescent villain
        )

        meta = result["superhero_meta"]
        assert meta["band"] == "adolescent"
        assert meta["villain_id"] == "ledger"
        assert meta["problem_id"] in ADOLESCENT_VILLAIN_PROBLEMS["ledger"]

    def test_adult_age_25_resolves_to_creator_band(self, app, mocker):
        result = self._run(app, mocker, age=25)

        meta = result["superhero_meta"]
        assert meta["band"] == "creator"
        assert meta["villain_id"] in CREATOR_VILLAINS
