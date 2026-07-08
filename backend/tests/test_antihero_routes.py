"""Route + run-helper tests for "The Crux Choice" two-phase antihero flow (Phase 2).

Covers the two new endpoints and the part-2 run helper:

- ``POST /generate-antihero-crux``       → awaiting_choice + continuation_token,
  4 pages + 2 choices, quota incremented exactly once.
- ``POST /generate-antihero-resolution`` → complete + assembled 7 pages, with
  ``superhero_meta.saga_state.defining_choice`` reflecting the chosen text; the
  continuation token is consumed; quota is NOT re-incremented.
- invalid / expired token → 410; invalid choice_id → 400.
- ``run_antihero_part2`` unit test: the chosen choice text reaches
  ``saga_state.defining_choice`` (LLM mocked at the
  ``_generate_story_text_with_metadata`` boundary).

The LLM is mocked at the ``_generate_story_text_with_metadata`` boundary in
``backend.tasks.story_tasks`` so no live provider is hit. Moderation runs for
real but fails OPEN (no Gemini client in tests) so child-safe canned prose
passes. The blueprint's NullCache (testing config) is swapped for a dict-backed
fake so the continuation token round-trips.
"""

from __future__ import annotations

import json

import pytest

from backend.tasks import story_tasks

# --- canned LLM JSON for each phase ----------------------------------------
_PART1_JSON = json.dumps(
    {
        "title": "The Quiet Tell",
        "themes": ["identity", "concealment", "loyalty-vs-truth"],
        "characters_featured": ["Maya"],
        "emotional_arc": "guarded → cornered",
        "pages": [
            {
                "text": "Maya moved through the hallway, her double life already in motion."
            },
            {
                "text": "Something underneath the easy story did not fit, and Maya noticed."
            },
            {
                "text": "Maya used the edge, and it was not enough; the cost landed hard."
            },
            {
                "text": "A friend pushed back, fair and sharp, and the truth surfaced at last."
            },
        ],
        "crux": "Protect the cover, or tell the truth and clear a friend's name.",
        "choices": [
            {
                "id": "a",
                "text": "Tell the truth and burn the cover to clear her friend.",
            },
            {
                "id": "b",
                "text": "Hold the secret and let her friend take the fall quietly.",
            },
        ],
    }
)

_PART2_JSON_TEMPLATE = json.dumps(
    {
        "pages": [
            {
                "text": "Maya acted on the choice, and the room shifted around the decision."
            },
            {
                "text": "With judgment over force, Maya resolved the case by wits and a hard boundary."
            },
            {
                "text": "The aftermath was quiet; one thread stayed loose, pulling toward next time."
            },
        ],
        "saga_state": {
            "nemesis": "The Double",
            "nemesis_status": "reconsidered",
            "what_changed": "Maya's double life is a little less hidden now.",
            "what_it_cost": "A frayed bond with someone who trusted the cover.",
            "next_hook": "Someone else saw the tell.",
            "allies": ["Priya"],
            "defining_choice": "__DEFINING_CHOICE__",
        },
    }
)


@pytest.fixture(autouse=True)
def antihero_enabled(monkeypatch):
    """The server-side gate (red-team F-1) defaults OFF; these tests exercise
    the flow behind it, so enable it. Gate-specific tests below override this
    per-test with delenv/setenv."""
    monkeypatch.setenv("ANTIHERO_CRUX_ENABLED", "1")


@pytest.fixture
def fake_cache(app):
    """Swap the blueprint's NullCache for a dict-backed fake so the continuation
    token round-trips in tests (TestingConfig uses NullCache, which discards
    everything). Patches the Flask-Caching ``Cache`` proxy the routes closed
    over (the key in ``app.extensions['cache']``).
    """
    store: dict = {}
    cache_proxy = next(iter(app.extensions["cache"].keys()))

    def _set(key, value, timeout=None):
        store[key] = value
        return True

    def _get(key):
        return store.get(key)

    def _delete(key):
        store.pop(key, None)
        return True

    cache_proxy.set = _set
    cache_proxy.get = _get
    cache_proxy.delete = _delete
    return store


@pytest.fixture
def adolescent_character(app, test_user):
    """An age-16 character owned by ``test_user`` (the antihero band)."""
    from backend.database import db
    from backend.models import Character

    with app.app_context():
        character = Character(
            id="char_teen_16",
            user_id=test_user.id,
            name="Maya",
            age=16,
            personality_sliders={"brave": 7},
        )
        db.session.add(character)
        db.session.commit()
        yield character
        db.session.delete(character)
        db.session.commit()


def _mock_llm(monkeypatch, part1_text=_PART1_JSON, part2_text=None):
    """Patch _generate_story_text_with_metadata to echo canned JSON.

    Routes which value to return by sniffing the prompt for the PART 1 / PART 2
    marker the builders embed, so a single patch serves both phases.
    """

    def _fake(prompt, theme, character_name, *args, **kwargs):
        if "PART 2 OF 2" in prompt:
            return (part2_text or _PART2_JSON_TEMPLATE), "claude", ["claude(success)"]
        return part1_text, "claude", ["claude(success)"]

    monkeypatch.setattr(story_tasks, "_generate_story_text_with_metadata", _fake)
    # The canned _PART1/2_JSON is known-safe; these tests vet routing, not
    # moderation. The crux moderator now fails CLOSED on a classifier outage
    # (audit P1#8), which without a live/mocked Gemini key would flag the
    # canned prose as "unverified" — so stub it to safe here.
    monkeypatch.setattr(story_tasks, "_moderate_antihero_text", lambda *a, **k: True)


def _month_count(app, user_id):
    """Read the monthly DB story counter (incremented by increment_daily_quota
    when Redis is absent, as in tests)."""
    from backend.models import User

    with app.app_context():
        u = User.query.filter_by(id=user_id).first()
        return int(getattr(u, "stories_generated_this_month", 0) or 0)


# --- /generate-antihero-crux ------------------------------------------------
def test_crux_returns_awaiting_choice_with_token_pages_and_choices(
    client, auth_headers, monkeypatch, fake_cache, adolescent_character, app, test_user
):
    _mock_llm(monkeypatch)
    before = _month_count(app, test_user.id)

    resp = client.post(
        "/generate-antihero-crux",
        json={
            "character_id": adolescent_character.id,
            "age": 16,
            "hero_power": "strategist",
            "hero_secret": "they failed the exam they pretend they aced",
        },
        headers=auth_headers,
    )

    assert resp.status_code == 200, resp.get_data(as_text=True)
    body = resp.get_json()
    assert body["status"] == "awaiting_choice"
    assert body["continuation_token"]
    story = body["story"]
    assert len(story["pages"]) == 4
    assert len(story["choices"]) == 2
    assert {c["id"] for c in story["choices"]} == {"a", "b"}
    assert story["crux"]

    # Quota charged exactly once on the crux call.
    assert _month_count(app, test_user.id) == before + 1

    # The token actually landed in the (faked) cache.
    assert f"antihero-crux:{body['continuation_token']}" in fake_cache


def test_crux_crisis_in_hero_secret_blocks_generation_and_quota(
    client, auth_headers, monkeypatch, fake_cache, adolescent_character, app, test_user
):
    """MT-327: a self-harm disclosure in hero_secret must return crisis
    resources instead of running part1 or charging the daily quota."""
    _mock_llm(monkeypatch)
    before = _month_count(app, test_user.id)

    resp = client.post(
        "/generate-antihero-crux",
        json={
            "character_id": adolescent_character.id,
            "age": 16,
            "hero_power": "strategist",
            "hero_secret": "I don't want to be alive anymore",
        },
        headers=auth_headers,
    )

    assert resp.status_code == 200, resp.get_data(as_text=True)
    body = resp.get_json()
    assert body.get("crisis") is True
    assert "resources" in body
    assert "continuation_token" not in body

    # Quota must NOT be charged and no continuation context cached.
    assert _month_count(app, test_user.id) == before
    assert not fake_cache


def test_crux_requires_character(client, auth_headers, monkeypatch, fake_cache):
    _mock_llm(monkeypatch)
    resp = client.post(
        "/generate-antihero-crux",
        json={"age": 16, "hero_power": "strategist"},  # no character / character_id
        headers=auth_headers,
    )
    assert resp.status_code == 400


# --- /generate-antihero-resolution -----------------------------------------
def test_resolution_assembles_seven_pages_and_threads_choice_into_saga(
    client, auth_headers, monkeypatch, fake_cache, adolescent_character, app, test_user
):
    _mock_llm(monkeypatch)

    crux_resp = client.post(
        "/generate-antihero-crux",
        json={
            "character_id": adolescent_character.id,
            "age": 16,
            "hero_power": "strategist",
        },
        headers=auth_headers,
    )
    assert crux_resp.status_code == 200
    token = crux_resp.get_json()["continuation_token"]
    after_crux = _month_count(app, test_user.id)

    chosen_text = "Tell the truth and burn the cover to clear her friend."
    # The part-2 mock templates the chosen text into defining_choice.
    part2_text = _PART2_JSON_TEMPLATE.replace("__DEFINING_CHOICE__", chosen_text)
    _mock_llm(monkeypatch, part2_text=part2_text)

    res_resp = client.post(
        "/generate-antihero-resolution",
        json={"continuation_token": token, "choice_id": "a"},
        headers=auth_headers,
    )

    assert res_resp.status_code == 200, res_resp.get_data(as_text=True)
    body = res_resp.get_json()
    assert body["status"] == "complete"
    story = body["story"]
    # 4 part-1 pages + 3 part-2 pages = 7 assembled pages.
    assert len(story["pages"]) == 7
    # saga_state lifted onto superhero_meta; defining_choice reflects the choice.
    saga = story["superhero_meta"]["saga_state"]
    assert saga["defining_choice"] == chosen_text
    # what_it_cost / allies survive (NOT stripped by _normalize_saga_state).
    assert saga["what_it_cost"]
    assert saga["allies"] == ["Priya"]

    # Quota NOT re-incremented on resolution.
    assert _month_count(app, test_user.id) == after_crux

    # Token consumed.
    assert f"antihero-crux:{token}" not in fake_cache

    # Clean up the persisted Story row so it doesn't outlive the user/character
    # fixtures' teardown (Story.user_id is NOT NULL; an orphaned row would make
    # the test_user delete fail with an IntegrityError).
    from backend.database import db
    from backend.models.story import Story

    with app.app_context():
        Story.query.filter_by(id=story["id"]).delete()
        db.session.commit()


def test_resolution_expired_or_missing_token_returns_410(
    client, auth_headers, fake_cache
):
    resp = client.post(
        "/generate-antihero-resolution",
        json={"continuation_token": "does-not-exist", "choice_id": "a"},
        headers=auth_headers,
    )
    assert resp.status_code == 410
    assert resp.get_json()["code"] == "TOKEN_EXPIRED"


def test_resolution_invalid_choice_id_returns_400(
    client, auth_headers, monkeypatch, fake_cache, adolescent_character
):
    _mock_llm(monkeypatch)
    crux_resp = client.post(
        "/generate-antihero-crux",
        json={
            "character_id": adolescent_character.id,
            "age": 16,
            "hero_power": "strategist",
        },
        headers=auth_headers,
    )
    token = crux_resp.get_json()["continuation_token"]

    resp = client.post(
        "/generate-antihero-resolution",
        json={"continuation_token": token, "choice_id": "z"},
        headers=auth_headers,
    )
    assert resp.status_code == 400
    assert "valid_choices" in resp.get_json()


def test_resolution_missing_body_fields_returns_400(client, auth_headers, fake_cache):
    resp = client.post(
        "/generate-antihero-resolution",
        json={"continuation_token": "tok"},  # no choice_id
        headers=auth_headers,
    )
    assert resp.status_code == 400


# --- egress scrub on the antihero path (red-team F-4) ------------------------
def test_crux_output_scrubs_injected_contact_strings(
    client, auth_headers, monkeypatch, fake_cache, adolescent_character
):
    """An off-platform contact string in the model output (pages, crux, or a
    choice label) must never reach the client — this path previously had no
    deterministic net, and the probe's t.me/Proton payload survived verbatim."""
    dirty = json.loads(_PART1_JSON)
    dirty["pages"][0]["text"] = (
        "Maya found the note: reach me at t.me/vanishhelp or "
        "vanishhelp@proton.me if you ever need to vanish."
    )
    dirty["crux"] = "Trust the stranger at www.vanish-help.com, or walk away."
    dirty["choices"][0]["text"] = "Message t.me/vanishhelp and disappear."
    _mock_llm(monkeypatch, part1_text=json.dumps(dirty))

    resp = client.post(
        "/generate-antihero-crux",
        json={
            "character_id": adolescent_character.id,
            "age": 16,
            "hero_power": "strategist",
        },
        headers=auth_headers,
    )

    assert resp.status_code == 200, resp.get_data(as_text=True)
    blob = json.dumps(resp.get_json())
    for needle in ("t.me", "vanishhelp", "proton.me", "www.vanish-help.com"):
        assert needle not in blob, f"{needle!r} survived to client output"


def test_resolution_output_scrubs_injected_contact_strings(
    client, auth_headers, monkeypatch, fake_cache, adolescent_character, app
):
    """Part-2 pages AND saga_state (which persists into superhero_meta and
    feeds the next issue's continuity prompt) must be scrubbed."""
    _mock_llm(monkeypatch)
    crux_resp = client.post(
        "/generate-antihero-crux",
        json={
            "character_id": adolescent_character.id,
            "age": 16,
            "hero_power": "strategist",
        },
        headers=auth_headers,
    )
    token = crux_resp.get_json()["continuation_token"]

    dirty2 = json.loads(_PART2_JSON_TEMPLATE)
    dirty2["pages"][0][
        "text"
    ] = "The note read: vanishhelp@proton.me — an offer that smelled of care."
    dirty2["saga_state"]["next_hook"] = "Someone left a card: t.me/vanishhelp."
    dirty2["saga_state"]["defining_choice"] = "She kept the number."
    _mock_llm(monkeypatch, part2_text=json.dumps(dirty2))

    res_resp = client.post(
        "/generate-antihero-resolution",
        json={"continuation_token": token, "choice_id": "a"},
        headers=auth_headers,
    )

    assert res_resp.status_code == 200, res_resp.get_data(as_text=True)
    body = res_resp.get_json()
    blob = json.dumps(body)
    for needle in ("t.me", "vanishhelp", "proton.me"):
        assert needle not in blob, f"{needle!r} survived to client output"

    # Clean up the persisted Story row (Story.user_id FK teardown, as above).
    from backend.database import db
    from backend.models.story import Story

    with app.app_context():
        Story.query.filter_by(id=body["story"]["id"]).delete()
        db.session.commit()


# --- server-side gate (red-team F-1) ----------------------------------------
def test_crux_rejected_403_when_flag_unset(
    client, auth_headers, monkeypatch, fake_cache, adolescent_character, app, test_user
):
    """Default posture: ANTIHERO_CRUX_ENABLED unset → 403, no generation, no
    quota charge. This is the server-side mirror of Dart's cruxChoiceEnabled."""
    _mock_llm(monkeypatch)
    monkeypatch.delenv("ANTIHERO_CRUX_ENABLED", raising=False)
    before = _month_count(app, test_user.id)

    resp = client.post(
        "/generate-antihero-crux",
        json={
            "character_id": adolescent_character.id,
            "age": 16,
            "hero_power": "strategist",
        },
        headers=auth_headers,
    )

    assert resp.status_code == 403
    assert resp.get_json()["error"] == "FEATURE_DISABLED"
    assert _month_count(app, test_user.id) == before
    assert not fake_cache


def test_resolution_rejected_403_when_flag_unset(
    client, auth_headers, monkeypatch, fake_cache
):
    monkeypatch.delenv("ANTIHERO_CRUX_ENABLED", raising=False)
    resp = client.post(
        "/generate-antihero-resolution",
        json={"continuation_token": "tok", "choice_id": "a"},
        headers=auth_headers,
    )
    assert resp.status_code == 403
    assert resp.get_json()["error"] == "FEATURE_DISABLED"


def test_crux_rejects_age_outside_adolescent_band(
    client, auth_headers, monkeypatch, fake_cache, app, test_user
):
    """Even with the flag on, only the 15-17 band may reach the antihero
    builders — a 12-year-old payload age is refused."""
    _mock_llm(monkeypatch)
    before = _month_count(app, test_user.id)

    resp = client.post(
        "/generate-antihero-crux",
        json={"character": "Kid", "age": 12, "hero_power": "strategist"},
        headers=auth_headers,
    )

    assert resp.status_code == 403
    assert resp.get_json()["error"] == "AGE_BAND_NOT_SUPPORTED"
    assert _month_count(app, test_user.id) == before


def test_crux_band_check_uses_verified_age_not_declared(
    client, auth_headers, monkeypatch, fake_cache, app, test_user
):
    """A younger child cannot reach the adolescent band by declaring 16: the
    owned character's age anchors the resolve DOWN, and the gate then rejects."""
    from backend.database import db
    from backend.models import Character

    _mock_llm(monkeypatch)
    with app.app_context():
        character = Character(
            id="char_kid_12",
            user_id=test_user.id,
            name="Kid",
            age=12,
            personality_sliders={},
        )
        db.session.add(character)
        db.session.commit()

    try:
        resp = client.post(
            "/generate-antihero-crux",
            json={"character_id": "char_kid_12", "age": 16, "hero_power": "strategist"},
            headers=auth_headers,
        )
        assert resp.status_code == 403
        assert resp.get_json()["error"] == "AGE_BAND_NOT_SUPPORTED"
    finally:
        with app.app_context():
            Character.query.filter_by(id="char_kid_12").delete()
            db.session.commit()


def test_crisis_check_runs_before_gate(
    client, auth_headers, monkeypatch, fake_cache, adolescent_character
):
    """A distressed teen gets crisis resources, not a 403 — the crisis guard
    deliberately runs before the feature gate."""
    _mock_llm(monkeypatch)
    monkeypatch.delenv("ANTIHERO_CRUX_ENABLED", raising=False)

    resp = client.post(
        "/generate-antihero-crux",
        json={
            "character_id": adolescent_character.id,
            "age": 16,
            "hero_secret": "I don't want to be alive anymore",
        },
        headers=auth_headers,
    )

    assert resp.status_code == 200
    assert resp.get_json().get("crisis") is True


def test_resolution_rejects_cached_context_outside_band(
    client, auth_headers, monkeypatch, fake_cache, app, test_user
):
    """Belt-and-suspenders: a continuation context carrying a non-adolescent
    age is refused at resolution time too."""
    fake_cache["antihero-crux:tok-kid"] = {
        "user_id": str(test_user.id),
        "age": 12,
        "choices": [{"id": "a", "text": "x"}, {"id": "b", "text": "y"}],
        "part1_pages": ["p1"],
        "title": "T",
    }
    resp = client.post(
        "/generate-antihero-resolution",
        json={"continuation_token": "tok-kid", "choice_id": "a"},
        headers=auth_headers,
    )
    assert resp.status_code == 403
    assert resp.get_json()["error"] == "AGE_BAND_NOT_SUPPORTED"


# --- run_antihero_part2 unit test ------------------------------------------
def test_run_antihero_part2_threads_choice_into_defining_choice(app, monkeypatch):
    """The chosen choice text must reach saga_state.defining_choice."""
    chosen = {"id": "a", "text": "Burn the cover to clear her friend's name"}
    part2_text = _PART2_JSON_TEMPLATE.replace("__DEFINING_CHOICE__", chosen["text"])

    def _fake(prompt, theme, character_name, *args, **kwargs):
        # Sanity: the chosen text is templated into the prompt the builder made.
        assert chosen["text"] in prompt
        return part2_text, "claude", ["claude(success)"]

    monkeypatch.setattr(story_tasks, "_generate_story_text_with_metadata", _fake)
    # Crux moderator fails closed on classifier outage (P1#8); canned text is
    # known-safe, so stub the moderation pass for this routing-focused test.
    monkeypatch.setattr(story_tasks, "_moderate_antihero_text", lambda *a, **k: True)

    with app.app_context():
        result = story_tasks.run_antihero_part2(
            chosen_choice=chosen,
            part1_pages=["Beat 1", "Beat 2", "Beat 3", "Beat 4"],
            character="Maya",
            age=16,
            hero_power="strategist",
            villain_id="the_double",
            problem_id="expose_the_setup",
        )

    assert len(result["pages"]) == 3
    assert result["saga_state"]["defining_choice"] == chosen["text"]
    assert result["saga_state"]["allies"] == ["Priya"]
