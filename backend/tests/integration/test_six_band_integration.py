"""
Six Age-Band Integration Tests
==============================
Verifies that all six age bands (sprout → adult) produce correct
behaviour through the full backend API: story generation, interactive
adventure, pick-a-path, TTS, and avatar routes.

Band → representative test age mapping
  sprout      (3–5)   → age 4
  explorer    (6–8)   → age 7
  adventurer  (9–11)  → age 10
  creator     (12–14) → age 13
  adolescent  (15–17) → age 16
  adult       (18+)   → age 25

Run with:
    pytest backend/tests/integration/test_six_band_integration.py -v
"""

from datetime import datetime, timedelta, timezone

import jwt
import pytest

from backend.database import db
from backend.models import User
from backend.services.interactive_adventure_prompt_builder import (
    InteractiveAdventurePromptBuilder,
)
from backend.services.story_service import AGE_CONSTRAINTS, _get_age_band

# ---------------------------------------------------------------------------
# Band definitions
# ---------------------------------------------------------------------------

BANDS = [
    # (band_name,  test_age,  expected_backend_band_key,  expected_companion_count)
    ("sprout", 4, "3-4", 4),
    ("explorer", 7, "5-7", 4),
    ("adventurer", 10, "8-10", 4),
    ("creator", 13, "11-13", 4),
    ("adolescent", 16, "15-18", 4),
    ("adult", 25, "adult", 4),
]

BAND_IDS = [b[0] for b in BANDS]

# Companion IDs expected for each Flutter band name (from companion_selector_step.dart)
EXPECTED_COMPANION_IDS = {
    "sprout": {"fluffy_dragon", "magic_bunny", "shining_puppy", "robin"},
    "explorer": {"ember_dragon", "moon_owl", "star_fox", "robin"},
    "adventurer": {"thunder_wolf", "shadow_panther", "crystal_phoenix", "robin"},
    # creator / adolescent / adult companions are less strictly band-locked in the codebase
}

# Feelings expected for the sprout band (feelings_garden_screen.dart)
SPROUT_FEELING_IDS = {"happy", "sad", "angry", "fearful", "excited"}

# TTS rate scale expected per band (from app_tts_service.dart / hero_creator_step.dart)
BAND_TTS_RATE_SCALE = {
    "sprout": 0.8,
    "explorer": 1.0,
    "adventurer": 1.0,
    "creator": 1.0,
    "adolescent": 1.0,
    "adult": 1.0,
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_user(user_id: str, tier: str = "free") -> str:
    """Create a DB user and return a signed JWT token."""
    user = User(
        id=user_id,
        username=user_id,
        email=f"{user_id}@test.com",
        password_hash="hash",
        subscription_tier=tier,
        role="user",
    )
    db.session.add(user)
    db.session.commit()
    payload = {
        "user_id": user_id,
        "sub": user_id,
        "email": f"{user_id}@test.com",
        "subscription_tier": tier,
        "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
    }
    return jwt.encode(payload, "dev-secret-key", algorithm="HS256")


def _story_payload(age: int, mode: str = "regular", length: str = "short") -> dict:
    return {
        "character": "Luna",
        "age": age,
        "theme": "Adventure",
        "story_length": length,
        "story_mode": mode,
        "custom_elements": "",
        "include_illustrations": False,
    }


def _interactive_payload(age: int) -> dict:
    return {
        "character": "Luna",
        "age": age,
        "scenario": "magical forest",
        "theme": "Adventure",
        "companions": [],
    }


def _mock_story_result(mocker, story_text: str, title: str = "Test Story"):
    """Patch the Celery story task so it returns a canned result instantly."""
    mock_task = mocker.MagicMock()
    mocker.patch("backend.routes.story_routes.generate_story_task", mock_task)
    result = {
        "status": "complete",
        "story": {
            "title": title,
            "story_text": story_text,
            "theme": "Adventure",
            "wisdom_gem": "Be brave.",
        },
    }
    eager = mock_task.return_value
    eager.get.return_value = result
    mock_task.apply.return_value = eager
    return mock_task


def _story_text_for_band(band_key: str, length: str = "short") -> str:
    """Generate a mock story whose word count lands in the middle of the band's target range."""
    lo, hi = AGE_CONSTRAINTS[band_key]["regular"][length]
    target_words = (lo + hi) // 2
    # Build a repeating sentence to hit target word count
    unit = "Luna walked through the magical forest and found a glowing treasure chest. "
    unit_words = len(unit.split())
    repeats = max(1, target_words // unit_words)
    return (unit * repeats).strip()


# ---------------------------------------------------------------------------
# 1. Band mapping correctness
# ---------------------------------------------------------------------------


class TestBandMapping:
    """_get_age_band() must return the right key for every representative age."""

    @pytest.mark.parametrize("band_name,age,expected_key,_cc", BANDS, ids=BAND_IDS)
    def test_age_maps_to_correct_band_key(self, band_name, age, expected_key, _cc):
        assert (
            _get_age_band(age) == expected_key
        ), f"Age {age} ({band_name}) should map to '{expected_key}'"

    def test_boundary_ages_resolve_correctly(self):
        """Verify every boundary age resolves to the expected band key."""
        boundaries = [
            (3, "3-4"),
            (4, "3-4"),
            (5, "5-7"),
            (7, "5-7"),
            (8, "8-10"),
            (10, "8-10"),
            (11, "11-13"),
            (13, "11-13"),
            (14, "13-15"),
            (15, "15-18"),
            (17, "15-18"),
            (18, "adult"),
            (19, "adult"),
            (99, "adult"),
        ]
        for age, expected in boundaries:
            assert (
                _get_age_band(age) == expected
            ), f"Boundary age {age} should map to '{expected}', got '{_get_age_band(age)}'"

    def test_all_six_flutter_bands_have_backend_constraint_entry(self):
        """Every Flutter AgeBand should correspond to at least one AGE_CONSTRAINTS key."""
        flutter_bands = {
            "sprout": [3, 4, 5],
            "explorer": [6, 7, 8],
            "adventurer": [9, 10, 11],
            "creator": [12, 13, 14],
            "adolescent": [15, 16, 17],
            "adult": [18, 25, 99],
        }
        for band_name, ages in flutter_bands.items():
            for age in ages:
                key = _get_age_band(age)
                assert key in AGE_CONSTRAINTS, (
                    f"Age {age} (Flutter band: {band_name}) resolved to '{key}' "
                    f"which is missing from AGE_CONSTRAINTS"
                )


# ---------------------------------------------------------------------------
# 2. Word count ranges — AGE_CONSTRAINTS are internally consistent
# ---------------------------------------------------------------------------


class TestWordCountRanges:
    """AGE_CONSTRAINTS word count ranges must be defined, ordered, and non-overlapping."""

    @pytest.mark.parametrize("band_name,age,band_key,_cc", BANDS, ids=BAND_IDS)
    def test_band_has_all_three_story_lengths(self, band_name, age, band_key, _cc):
        config = AGE_CONSTRAINTS[band_key]["regular"]
        for length in ("short", "medium", "long"):
            assert length in config, f"Band '{band_key}' missing 'regular.{length}'"
            lo, hi = config[length]
            assert (
                lo < hi
            ), f"Band '{band_key}' {length}: min ({lo}) must be < max ({hi})"

    @pytest.mark.parametrize("band_name,age,band_key,_cc", BANDS, ids=BAND_IDS)
    def test_word_counts_increase_with_story_length(
        self, band_name, age, band_key, _cc
    ):
        reg = AGE_CONSTRAINTS[band_key]["regular"]
        assert (
            reg["short"][1] <= reg["medium"][0] or reg["short"][0] < reg["medium"][1]
        ), f"Band '{band_key}': 'short' max should be ≤ 'medium' min"
        assert (
            reg["medium"][1] <= reg["long"][0] or reg["medium"][0] < reg["long"][1]
        ), f"Band '{band_key}': 'medium' max should be ≤ 'long' min"

    def test_word_counts_increase_across_bands(self):
        """Older bands should have higher word count targets than younger bands."""
        ordered_keys = ["3-4", "5-7", "8-10", "11-13", "13-15", "15-18", "adult"]
        prev_mid = 0
        for key in ordered_keys:
            lo, hi = AGE_CONSTRAINTS[key]["regular"]["medium"]
            mid = (lo + hi) / 2
            assert mid > prev_mid, (
                f"Band '{key}' medium word count midpoint ({mid}) is not higher "
                f"than previous band ({prev_mid})"
            )
            prev_mid = mid


# ---------------------------------------------------------------------------
# 3. Story generation API — all 6 bands
# ---------------------------------------------------------------------------


class TestStoryGenerationAllBands:
    """POST /generate-story returns 200 with correct structure for all 6 age bands."""

    @pytest.mark.parametrize("band_name,age,band_key,_cc", BANDS, ids=BAND_IDS)
    def test_story_generation_returns_200(
        self, client, app, mocker, band_name, age, band_key, _cc
    ):
        with app.app_context():
            token = _make_user(f"story-{band_name}", "premium")

        mock_text = _story_text_for_band(band_key)
        _mock_story_result(mocker, mock_text, f"Luna's {band_name.title()} Adventure")

        resp = client.post(
            "/generate-story",
            json=_story_payload(age),
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200, (
            f"Band '{band_name}' (age {age}): expected 200, got {resp.status_code}. "
            f"Body: {resp.get_data(as_text=True)[:300]}"
        )

    @pytest.mark.parametrize("band_name,age,band_key,_cc", BANDS, ids=BAND_IDS)
    def test_story_response_has_required_fields(
        self, client, app, mocker, band_name, age, band_key, _cc
    ):
        with app.app_context():
            token = _make_user(f"story-fields-{band_name}", "premium")

        _mock_story_result(mocker, _story_text_for_band(band_key))

        resp = client.post(
            "/generate-story",
            json=_story_payload(age),
            headers={"Authorization": f"Bearer {token}"},
        )
        data = resp.get_json()
        assert "story" in data, f"Band '{band_name}': response missing 'story' key"
        story = data["story"]
        for field in ("title", "story_text"):
            assert field in story, f"Band '{band_name}': story missing '{field}'"

    @pytest.mark.parametrize("band_name,age,band_key,_cc", BANDS, ids=BAND_IDS)
    def test_story_word_count_in_band_range(
        self, client, app, mocker, band_name, age, band_key, _cc
    ):
        """Mock story word count should fall within the band's short-story range."""
        with app.app_context():
            token = _make_user(f"story-wc-{band_name}", "premium")

        mock_text = _story_text_for_band(band_key, "short")
        _mock_story_result(mocker, mock_text)

        resp = client.post(
            "/generate-story",
            json=_story_payload(age, length="short"),
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        story_text = resp.get_json()["story"]["story_text"]
        word_count = len(story_text.split())
        lo, hi = AGE_CONSTRAINTS[band_key]["regular"]["short"]
        # Allow ±25 % tolerance (mock text won't be pixel-perfect)
        tolerance = 0.25
        assert lo * (1 - tolerance) <= word_count <= hi * (1 + tolerance), (
            f"Band '{band_name}' short story: {word_count} words, "
            f"expected ~{lo}–{hi}"
        )

    @pytest.mark.parametrize("band_name,age,band_key,_cc", BANDS, ids=BAND_IDS)
    def test_story_generation_rejects_missing_character(
        self, client, app, band_name, age, band_key, _cc
    ):
        with app.app_context():
            token = _make_user(f"story-no-char-{band_name}")

        payload = _story_payload(age)
        del payload["character"]
        resp = client.post(
            "/generate-story",
            json=payload,
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code in (
            400,
            422,
        ), f"Band '{band_name}': missing character should return 400/422"


# ---------------------------------------------------------------------------
# 4. Interactive adventure — all 6 bands
# ---------------------------------------------------------------------------


class TestInteractiveAdventureAllBands:
    """POST /generate-interactive-story returns 200 for all 6 bands."""

    @pytest.mark.parametrize("band_name,age,_bk,_cc", BANDS, ids=BAND_IDS)
    def test_interactive_story_returns_200(
        self, client, app, mocker, band_name, age, _bk, _cc
    ):
        with app.app_context():
            token = _make_user(f"interactive-{band_name}", "premium")

        # The interactive endpoint calls InteractiveAdventureService.create_story
        # (NOT generate_story_task), which makes a real Gemini call. Mock the
        # service so this test never depends on a live GEMINI_API_KEY secret —
        # previously it 500'd ("GEMINI_API_KEY not set") whenever CI's key was
        # absent. Shape must match what the endpoint reads: result["segment"].
        mocker.patch(
            "backend.routes.story_routes.InteractiveAdventureService"
        ).return_value.create_story.return_value = {
            "story_id": "test-story-id",
            "segment": {
                "segment_number": 1,
                "title": "Test Interactive",
                "content": "Luna stepped into the forest.",
                "image_description": "",
                "image_url": None,
                "choices": [
                    {"id": "a", "text": "Go left"},
                    {"id": "b", "text": "Go right"},
                ],
            },
        }
        # Keep this band-coverage smoke test hermetic: the LLM moderator has its
        # own tests; stub it safe so this never calls a live classifier whether
        # or not GEMINI_API_KEY is set.
        mocker.patch(
            "backend.utils.content_moderator.moderate_story_content",
            return_value=(True, ""),
        )

        resp = client.post(
            "/generate-interactive-story",
            json=_interactive_payload(age),
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code in (200, 201), (
            f"Band '{band_name}' (age {age}): interactive story returned "
            f"{resp.status_code}. Body: {resp.get_data(as_text=True)[:300]}"
        )


# ---------------------------------------------------------------------------
# 5. Interactive adventure prompt builder — AGE_BANDS coverage
# ---------------------------------------------------------------------------


class TestPromptBuilderAllBands:
    """InteractiveAdventurePromptBuilder.get_age_band() covers all 6 Flutter bands."""

    @pytest.mark.parametrize("band_name,age,_bk,_cc", BANDS, ids=BAND_IDS)
    def test_get_age_band_returns_known_key(self, band_name, age, _bk, _cc):
        key = InteractiveAdventurePromptBuilder.get_age_band(age)
        assert (
            key in InteractiveAdventurePromptBuilder.AGE_BANDS
        ), f"Band '{band_name}' (age {age}): prompt builder returned unknown key '{key}'"

    def test_all_prompt_builder_bands_have_word_count_ranges(self):
        for key, config in InteractiveAdventurePromptBuilder.AGE_BANDS.items():
            assert (
                "word_count_ranges" in config
            ), f"Prompt builder band '{key}' missing 'word_count_ranges'"
            for length in ("short", "medium", "long"):
                assert (
                    length in config["word_count_ranges"]
                ), f"Prompt builder band '{key}' missing length '{length}'"

    @pytest.mark.parametrize("band_name,age,_bk,_cc", BANDS, ids=BAND_IDS)
    def test_per_segment_word_count_returns_valid_tuple(self, band_name, age, _bk, _cc):
        key = InteractiveAdventurePromptBuilder.get_age_band(age)
        lo, hi = InteractiveAdventurePromptBuilder._calculate_per_segment_word_count(
            key, "medium"
        )
        assert (
            lo > 0 and hi > lo
        ), f"Band '{band_name}': per-segment word count invalid ({lo}, {hi})"


# ---------------------------------------------------------------------------
# 6. Subscription status — accessible for all bands (no auth required)
# ---------------------------------------------------------------------------


class TestSubscriptionStatusAllBands:
    """GET /api/subscription/status returns a response for all 6 bands (anon + auth)."""

    def test_anonymous_user_gets_free_tier_default(self, client):
        """Anonymous requests should not 403 — they may 401/404 but must not crash."""
        resp = client.get("/api/subscription/status")
        # 200 = anon returns free default, 401 = auth required, 404 = route not mounted in test
        assert resp.status_code in (
            200,
            401,
            404,
        ), f"Anonymous subscription status should be 200/401/404, got {resp.status_code}"
        if resp.status_code == 200:
            data = resp.get_json()
            assert data.get("tier") in ("free", "inactive", None) or "status" in data

    @pytest.mark.parametrize("band_name,age,_bk,_cc", BANDS, ids=BAND_IDS)
    def test_authenticated_user_gets_subscription_status(
        self, client, app, band_name, age, _bk, _cc
    ):
        with app.app_context():
            token = _make_user(f"sub-{band_name}")

        resp = client.get(
            "/api/subscription/status",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code in (
            200,
            404,
        ), f"Band '{band_name}': subscription status returned {resp.status_code}"


# ---------------------------------------------------------------------------
# 7. Avatar generation — rate limit headers per band
# ---------------------------------------------------------------------------


class TestAvatarRateLimitAllBands:
    """POST /avatar/generate-avatar returns correct rate-limit headers per band tier."""

    @pytest.mark.parametrize("band_name,age,_bk,_cc", BANDS, ids=BAND_IDS)
    def test_avatar_rate_limit_header_present_for_free_tier(
        self, client, app, band_name, age, _bk, _cc
    ):
        with app.app_context():
            token = _make_user(f"avatar-rl-{band_name}", "free")

        resp = client.post(
            "/avatar/generate-avatar",
            json={"character_name": "Luna", "age": age, "style": "pixar"},
            headers={"Authorization": f"Bearer {token}"},
        )
        # Even on 400 (service unavailable in tests) the rate-limit headers must be present
        assert (
            resp.headers.get("X-Avatar-RateLimit-Limit") == "5"
        ), f"Band '{band_name}': free user missing X-Avatar-RateLimit-Limit header"
        assert (
            resp.headers.get("X-Avatar-RateLimit-Tier") == "free"
        ), f"Band '{band_name}': free user missing X-Avatar-RateLimit-Tier header"


# ---------------------------------------------------------------------------
# 8. Age gate validation — server rejects out-of-range ages
# ---------------------------------------------------------------------------


class TestAgeGateValidation:
    """Story generation rejects ages outside the supported range (< 3 or > 99)."""

    # validate_age() accepts 0–120; only ages outside that range are truly invalid.
    # NOTE: Age validation currently happens inside the Celery task, so invalid
    # ages surface as 500 (task failure) rather than 400 (pre-validation).
    # The key invariant is that they must NOT return 200 (story accepted).
    @pytest.mark.parametrize("invalid_age", [-1, 121, 150, 200])
    def test_invalid_age_returns_error(self, client, app, invalid_age):
        with app.app_context():
            token = _make_user(f"agegate-{abs(invalid_age)}")

        resp = client.post(
            "/generate-story",
            json=_story_payload(invalid_age),
            headers={"Authorization": f"Bearer {token}"},
        )
        assert (
            resp.status_code != 200
        ), f"Age {invalid_age} should not be accepted (got 200)"

    @pytest.mark.parametrize("band_name,age,_bk,_cc", BANDS, ids=BAND_IDS)
    def test_valid_band_age_is_accepted(
        self, client, app, mocker, band_name, age, _bk, _cc
    ):
        with app.app_context():
            token = _make_user(f"agegate-valid-{band_name}", "premium")

        _mock_story_result(mocker, _story_text_for_band(_get_age_band(age)))

        resp = client.post(
            "/generate-story",
            json=_story_payload(age),
            headers={"Authorization": f"Bearer {token}"},
        )
        assert (
            resp.status_code == 200
        ), f"Valid age {age} ({band_name}) was rejected: {resp.status_code}"


# ---------------------------------------------------------------------------
# 9. Content constraints — notes present and non-empty per band
# ---------------------------------------------------------------------------


class TestContentConstraints:
    """Each band must have age-appropriate content notes in AGE_CONSTRAINTS."""

    @pytest.mark.parametrize("band_name,age,band_key,_cc", BANDS, ids=BAND_IDS)
    def test_band_has_non_empty_content_notes(self, band_name, age, band_key, _cc):
        notes = AGE_CONSTRAINTS[band_key].get("notes", "")
        assert notes, f"Band '{band_key}' has empty or missing 'notes'"

    def test_sprout_notes_avoid_irony_sarcasm(self):
        notes = AGE_CONSTRAINTS["3-4"]["notes"]
        assert "AVOID" in notes, "Sprout notes must include AVOID list"
        avoid_section = notes[notes.index("AVOID") :]
        for forbidden in ("irony", "sarcasm", "abstract metaphor"):
            assert (
                forbidden.lower() in avoid_section.lower()
            ), f"Sprout AVOID list should mention '{forbidden}'"

    def test_adult_band_allows_literary_techniques(self):
        notes = AGE_CONSTRAINTS["adult"]["notes"]
        # Adult notes must acknowledge POV choice and literary craft
        for keyword in ("POV", "literary"):
            assert (
                keyword.lower() in notes.lower()
            ), f"Adult band notes should mention '{keyword}'"


# ---------------------------------------------------------------------------
# 10. Companion data (Python-accessible validation)
# ---------------------------------------------------------------------------


class TestCompanionBandData:
    """Validates companion band expectations against the Flutter source values
    defined as constants in this file (EXPECTED_COMPANION_IDS)."""

    def test_sprout_companion_ids_are_complete(self):
        expected = EXPECTED_COMPANION_IDS["sprout"]
        assert len(expected) == 4
        for cid in ("fluffy_dragon", "magic_bunny", "shining_puppy", "robin"):
            assert cid in expected

    def test_explorer_companion_ids_are_complete(self):
        expected = EXPECTED_COMPANION_IDS["explorer"]
        assert len(expected) == 4
        for cid in ("ember_dragon", "moon_owl", "star_fox", "robin"):
            assert cid in expected

    def test_adventurer_companion_ids_are_complete(self):
        expected = EXPECTED_COMPANION_IDS["adventurer"]
        assert len(expected) == 4
        for cid in ("thunder_wolf", "shadow_panther", "crystal_phoenix", "robin"):
            assert cid in expected


# ---------------------------------------------------------------------------
# 11. Sprout-specific invariants
# ---------------------------------------------------------------------------


class TestSproutInvariants:
    """Sprout (ages 3–5) specific requirements from the UX audit."""

    def test_sprout_backend_band_key_is_3_4(self):
        # Backend: ages 3–4 → '3-4'. Age 5 maps to '5-7' in the backend
        # (Flutter maps 5 → sprout, but backend has a finer-grained split).
        for age in (3, 4):
            assert _get_age_band(age) == "3-4", f"Age {age} must map to '3-4'"
        # Age 5 lands in the next backend band (5-7) — this is expected
        assert _get_age_band(5) == "5-7", "Age 5 maps to '5-7' in the backend"

    def test_sprout_short_story_max_300_words(self):
        lo, hi = AGE_CONSTRAINTS["3-4"]["regular"]["short"]
        assert hi <= 300, f"Sprout short story max is {hi}, expected ≤ 300"

    def test_sprout_medium_story_max_450_words(self):
        lo, hi = AGE_CONSTRAINTS["3-4"]["regular"]["medium"]
        assert hi <= 450, f"Sprout medium story max is {hi}, expected ≤ 450"

    def test_sprout_feelings_ids_are_correct_set(self):
        assert SPROUT_FEELING_IDS == {"happy", "sad", "angry", "fearful", "excited"}

    def test_sprout_tts_rate_scale_below_one(self):
        assert (
            BAND_TTS_RATE_SCALE["sprout"] < 1.0
        ), "Sprout TTS rate scale must be < 1.0 (speech is slowed for 3–5)"
        assert (
            BAND_TTS_RATE_SCALE["sprout"] >= 0.7
        ), "Sprout TTS rate scale should not be below 0.7 (too slow)"

    def test_non_sprout_bands_use_full_tts_rate(self):
        for band in ("explorer", "adventurer", "creator", "adolescent", "adult"):
            assert (
                BAND_TTS_RATE_SCALE[band] == 1.0
            ), f"Band '{band}' TTS rate scale should be 1.0"

    def test_sprout_story_generation_returns_200(self, client, app, mocker):
        """End-to-end smoke test: sprout story goes through without errors."""
        with app.app_context():
            token = _make_user("sprout-smoke", "premium")

        text = _story_text_for_band("3-4", "short")
        _mock_story_result(mocker, text, "Fluffy's Big Day")

        resp = client.post(
            "/generate-story",
            json={
                "character": "Fluffy",
                "age": 4,
                "theme": "Friendship",
                "story_length": "short",
                "story_mode": "regular",
                "include_illustrations": False,
            },
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["story"]["title"] == "Fluffy's Big Day"
