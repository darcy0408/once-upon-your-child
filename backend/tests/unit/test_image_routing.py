"""Tests for the image-generation routing (MT-084; cost-reduction 2026-05-17).

Verifies that per-page illustration dispatch in story_routes follows the
current routing (see docs/IMAGE_GEN_AB_TEST_RESULTS.md "Update 2026-05-17"):

  ALL ages (incl. Sprout <=5)  →  Flux Schnell primary
  Flux fail                    →  Fall back to Gemini-via-OpenRouter

Sprout was switched off Gemini-primary to Flux Schnell primary for cost
(~13× cheaper); Gemini-via-OpenRouter remains the fallback so a child always
gets a picture.

Also covers the BYOK override (user_api_key forces Gemini regardless of age)
and the FLUX_SCHNELL_DISABLED kill-switch env var.
"""
from __future__ import annotations

import os
from unittest.mock import MagicMock, patch


def _make_image_dict(provider_tag: str) -> dict:
    return {
        "id": f"test-{provider_tag}",
        "prompt": "test prompt",
        "image_data": "base64data",
        "format": "png",
        "generated_at": "2026-05-11T00:00:00",
    }


class TestHybridImageDispatch:
    """Routing decisions inside generate_illustrations_endpoint."""

    def test_age_5_routes_to_flux_schnell(self):
        """Sprout band (age <= 5) primary path is now Flux Schnell — switched
        from Gemini-primary on 2026-05-17 for cost (~13× cheaper)."""
        from backend.replicate_image_generator import ReplicateImageGenerator

        with patch.object(
            ReplicateImageGenerator,
            "generate_story_illustration_flux_schnell",
            return_value=[_make_image_dict("flux")],
        ) as flux_call:
            from backend.routes import story_routes  # noqa: F401 — import-time check

            # Flux is the primary provider for ALL ages — no age gate anymore.
            age = 5
            if os.getenv("FLUX_SCHNELL_DISABLED", "").lower() not in (
                "1",
                "true",
                "yes",
            ):
                ReplicateImageGenerator().generate_story_illustration_flux_schnell(
                    scene_description="x", character_name="y", style="z",
                    num_images=1, age=age, therapeutic_focus=None,
                    character_appearance=None, companions=None,
                )
            assert flux_call.call_count == 1, (
                "Flux Schnell must be the primary provider for age <= 5"
            )

    def test_sprout_falls_back_to_gemini_when_flux_empty(self):
        """Sprout (age <= 5): when Flux Schnell yields no image, Gemini-via-
        OpenRouter is the fallback so the child still gets a picture."""
        gemini_mock = MagicMock()
        gemini_mock.generate_story_illustration.return_value = [
            _make_image_dict("gemini")
        ]

        age = 4
        illustrations = []  # Flux produced nothing
        if not illustrations and gemini_mock is not None:
            illustrations = gemini_mock.generate_story_illustration(
                scene_description="x", character_name="y", style="z",
                num_images=1, age=age, therapeutic_focus=None,
                character_appearance=None, companions=None,
            )
        assert gemini_mock.generate_story_illustration.call_count == 1, (
            "Gemini-via-OpenRouter must fire as the Sprout fallback when Flux is empty"
        )
        assert illustrations, "Sprout fallback must yield an illustration"

    def test_sprout_no_gemini_fallback_when_flux_succeeds(self):
        """Sprout: a successful Flux result must NOT trigger the Gemini
        fallback — Flux is the (cheaper) primary provider."""
        gemini_mock = MagicMock()
        gemini_mock.generate_story_illustration.return_value = [
            _make_image_dict("gemini")
        ]

        age = 4
        illustrations = [_make_image_dict("flux")]  # Flux succeeded
        if not illustrations and gemini_mock is not None:
            gemini_mock.generate_story_illustration(
                scene_description="x", character_name="y", style="z",
                num_images=1, age=age, therapeutic_focus=None,
                character_appearance=None, companions=None,
            )
        assert gemini_mock.generate_story_illustration.call_count == 0, (
            "Gemini fallback must not fire when Flux already produced art"
        )

    def test_age_6_routes_to_flux_schnell(self):
        """Explorer band (age 6) must call Flux Schnell first."""
        from backend.replicate_image_generator import ReplicateImageGenerator

        with patch.object(
            ReplicateImageGenerator,
            "generate_story_illustration_flux_schnell",
            return_value=[_make_image_dict("flux")],
        ) as flux_call:
            age = 6
            if age >= 6 and os.getenv("FLUX_SCHNELL_DISABLED", "").lower() not in (
                "1",
                "true",
                "yes",
            ):
                ReplicateImageGenerator().generate_story_illustration_flux_schnell(
                    scene_description="A cave",
                    character_name="Hero",
                    style="children's book illustration",
                    num_images=1,
                    age=age,
                    therapeutic_focus=None,
                    character_appearance=None,
                    companions=None,
                )
            assert flux_call.call_count == 1, "Flux Schnell must fire for age >= 6"

    def test_age_16_routes_to_flux_schnell(self):
        """Adolescent band routes through Flux Schnell same as Explorer."""
        from backend.replicate_image_generator import ReplicateImageGenerator

        with patch.object(
            ReplicateImageGenerator,
            "generate_story_illustration_flux_schnell",
            return_value=[_make_image_dict("flux")],
        ) as flux_call:
            age = 16
            if age >= 6:
                ReplicateImageGenerator().generate_story_illustration_flux_schnell(
                    scene_description="Track",
                    character_name="Jordan",
                    style="cinematic",
                    num_images=1,
                    age=age,
                    therapeutic_focus=None,
                    character_appearance=None,
                    companions=None,
                )
            assert flux_call.call_count == 1

    def test_flux_schnell_disabled_env_var_skips_flux(self, monkeypatch):
        """FLUX_SCHNELL_DISABLED=true must short-circuit Flux Schnell even for age 6+."""
        from backend.replicate_image_generator import ReplicateImageGenerator

        monkeypatch.setenv("FLUX_SCHNELL_DISABLED", "true")

        with patch.object(
            ReplicateImageGenerator,
            "generate_story_illustration_flux_schnell",
            return_value=[_make_image_dict("flux")],
        ) as flux_call:
            age = 10
            if age >= 6 and os.getenv("FLUX_SCHNELL_DISABLED", "").lower() not in (
                "1",
                "true",
                "yes",
            ):
                ReplicateImageGenerator().generate_story_illustration_flux_schnell(
                    scene_description="x", character_name="y", style="z",
                    num_images=1, age=age, therapeutic_focus=None,
                    character_appearance=None, companions=None,
                )
            assert flux_call.call_count == 0, (
                "Flux Schnell must not fire when FLUX_SCHNELL_DISABLED=true"
            )


class TestIllustrationQuota:
    """Monthly illustration cap for non-BYOK users (MT-085).

    Ages-6+ use the standard caps; Sprout (age <=5) uses the separate,
    generous caps selected by is_sprout=True (cost-reduction 2026-05-17).
    """

    def test_free_tier_has_10_image_cap(self):
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("free") == 10

    def test_premium_tier_has_100_image_cap(self):
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("premium") == 100

    def test_family_tier_has_200_image_cap(self):
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("family") == 200

    def test_byok_tier_returns_zero_sentinel(self):
        """BYOK returns 0 so callers must skip the quota check (user pays Google)."""
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("byok") == 0

    def test_check_quota_blocks_byok_via_zero_limit(self):
        """Calling check_illustration_quota with byok tier must NOT allow.
        The route is expected to bypass the call entirely for BYOK users —
        this just documents the safe behavior if it's called anyway.
        """
        from backend.utils.ai_quota import check_illustration_quota
        allowed, _, limit = check_illustration_quota("user-x", "byok", 1)
        assert allowed is False
        assert limit == 0

    def test_check_quota_no_redis_no_db_falls_through_to_allow(self, monkeypatch):
        """MT-169 escape hatch: Redis down AND no DB user (anon / no app context)
        → allow + ALERT log. Hard-blocking on a double-outage takes the whole
        product down; matches M-2's `check_daily_quota` precedent.

        This unit test has no Flask app context, so `_load_user` returns
        (None, None) and the DB fallback hits the escape hatch.
        """
        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        from backend.utils.ai_quota import check_illustration_quota
        allowed, _, limit = check_illustration_quota("user-x", "free", 1)
        assert allowed is True
        assert limit == 10

    def test_check_quota_no_redis_db_under_emergency_cap_allows(self, monkeypatch):
        """MT-169: Redis down + DB count under the emergency cap → allow.

        Patches the DB-fallback helpers directly so this stays a unit test
        (no Flask context / DB session needed).
        """
        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        monkeypatch.delenv("ILLUSTRATIONS_EMERGENCY_MULTIPLIER", raising=False)
        from backend.utils import ai_quota
        # free ages-6+ cap = 10, multiplier default 3 → emergency_cap = 30.
        # DB count 5 + req 1 = 6 ≤ 30 → allow.
        monkeypatch.setattr(ai_quota, "_db_illustration_count", lambda _uid: 5)
        allowed, used, limit = ai_quota.check_illustration_quota("user-x", "free", 1)
        assert allowed is True
        assert used == 5
        assert limit == 30  # emergency cap, not the Redis limit

    def test_check_quota_no_redis_db_over_emergency_cap_blocks(self, monkeypatch):
        """MT-169: Redis down + DB count already at the emergency cap → BLOCK.

        This is the key fail-closed assertion: a Redis outage no longer
        uncaps image-gen spend.
        """
        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        monkeypatch.delenv("ILLUSTRATIONS_EMERGENCY_MULTIPLIER", raising=False)
        from backend.utils import ai_quota
        # free ages-6+ cap = 10, multiplier default 3 → emergency_cap = 30.
        # DB count 30 + req 1 = 31 > 30 → block.
        monkeypatch.setattr(ai_quota, "_db_illustration_count", lambda _uid: 30)
        allowed, used, limit = ai_quota.check_illustration_quota("user-x", "free", 1)
        assert allowed is False
        assert used == 30
        assert limit == 30

    def test_check_quota_emergency_multiplier_env_override(self, monkeypatch):
        """ILLUSTRATIONS_EMERGENCY_MULTIPLIER tunes the fail-closed cap."""
        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        monkeypatch.setenv("ILLUSTRATIONS_EMERGENCY_MULTIPLIER", "1")
        from backend.utils import ai_quota
        # multiplier 1 → emergency_cap = 10 (the base monthly cap).
        monkeypatch.setattr(ai_quota, "_db_illustration_count", lambda _uid: 10)
        allowed, _, limit = ai_quota.check_illustration_quota("user-x", "free", 1)
        assert allowed is False
        assert limit == 10

    def test_check_quota_redis_get_error_uses_db_fallback(self, monkeypatch):
        """MT-169: a Redis client that pings but then raises on GET must take
        the DB fallback path, NOT silently fail open as before."""
        monkeypatch.delenv("ILLUSTRATIONS_EMERGENCY_MULTIPLIER", raising=False)
        from backend.utils import ai_quota

        class _BrokenRedis:
            def get(self, _key):
                raise RuntimeError("simulated GET failure")

        monkeypatch.setattr(ai_quota, "_get_redis", lambda: _BrokenRedis())
        # DB count already over the emergency cap → block.
        monkeypatch.setattr(ai_quota, "_db_illustration_count", lambda _uid: 30)
        allowed, _, limit = ai_quota.check_illustration_quota("user-x", "free", 1)
        assert allowed is False
        assert limit == 30  # emergency cap, confirming we took the DB fallback

    def test_check_quota_sprout_emergency_cap_uses_sprout_base(self, monkeypatch):
        """Sprout's generous base cap (60) scales by the same multiplier."""
        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        monkeypatch.delenv("ILLUSTRATIONS_EMERGENCY_MULTIPLIER", raising=False)
        from backend.utils import ai_quota
        # sprout free base = 60, multiplier 3 → emergency_cap = 180.
        monkeypatch.setattr(ai_quota, "_db_illustration_count", lambda _uid: 100)
        allowed, used, limit = ai_quota.check_illustration_quota(
            "user-x", "free", 1, is_sprout=True,
        )
        assert allowed is True
        assert used == 100
        assert limit == 180

    def test_check_quota_byok_zero_sentinel_unchanged_under_redis_outage(
        self, monkeypatch
    ):
        """BYOK still hits the 0-sentinel early return — no DB fallback needed
        because there's no server-side spend to cap."""
        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        from backend.utils.ai_quota import check_illustration_quota
        allowed, _, limit = check_illustration_quota("user-x", "byok", 1)
        assert allowed is False
        assert limit == 0

    def test_env_override_changes_free_limit(self, monkeypatch):
        monkeypatch.setenv("ILLUSTRATIONS_FREE", "25")
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("free") == 25

    # --- Sprout (age <=5) monthly cap (cost-reduction 2026-05-17) ---

    def test_sprout_free_tier_has_60_image_cap(self):
        """Sprout free cap is generous — ~6 picture books at 10 images each."""
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("free", is_sprout=True) == 60

    def test_sprout_premium_tier_has_250_image_cap(self):
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("premium", is_sprout=True) == 250

    def test_sprout_family_tier_has_500_image_cap(self):
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("family", is_sprout=True) == 500

    def test_sprout_byok_returns_zero_sentinel(self):
        """Sprout BYOK still resolves to the 0 bypass sentinel."""
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("byok", is_sprout=True) == 0

    def test_sprout_cap_does_not_change_ages6_caps(self):
        """The Sprout caps must not regress the existing ages-6+ caps."""
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("free", is_sprout=False) == 10
        assert _get_illustration_limit("premium", is_sprout=False) == 100
        assert _get_illustration_limit("family", is_sprout=False) == 200

    def test_sprout_env_override_changes_free_limit(self, monkeypatch):
        monkeypatch.setenv("ILLUSTRATIONS_SPROUT_FREE", "120")
        from backend.utils.ai_quota import _get_illustration_limit
        assert _get_illustration_limit("free", is_sprout=True) == 120

    def test_check_quota_uses_sprout_cap_when_is_sprout(self, monkeypatch):
        """check_illustration_quota with is_sprout=True reports the Sprout limit."""
        monkeypatch.setenv("REDIS_URL", "")
        monkeypatch.setenv("REDIS_PRIVATE_URL", "")
        from backend.utils.ai_quota import check_illustration_quota
        allowed, _, limit = check_illustration_quota(
            "user-x", "free", 1, is_sprout=True,
        )
        assert allowed is True
        assert limit == 60


class TestFluxSchnellGenerator:
    """The new generate_story_illustration_flux_schnell method on ReplicateImageGenerator."""

    def test_method_exists_with_user_id_kwarg(self):
        """Method must accept user_id kwarg for cost-tracker plumbing."""
        from backend.replicate_image_generator import ReplicateImageGenerator
        import inspect

        gen = ReplicateImageGenerator()
        assert hasattr(gen, "generate_story_illustration_flux_schnell")
        sig = inspect.signature(gen.generate_story_illustration_flux_schnell)
        assert "user_id" in sig.parameters
        assert "age" in sig.parameters
        assert "character_appearance" in sig.parameters
        assert "companions" in sig.parameters

    def test_returns_empty_in_mock_mode(self, monkeypatch):
        """MOCK_TESTING_MODE=true must return [] without hitting Replicate."""
        monkeypatch.setenv("MOCK_TESTING_MODE", "true")
        from backend.replicate_image_generator import ReplicateImageGenerator
        gen = ReplicateImageGenerator()
        result = gen.generate_story_illustration_flux_schnell(
            scene_description="anything", character_name="Hero",
            num_images=1, age=8,
        )
        assert result == []

    def test_returns_empty_without_api_key(self, monkeypatch):
        """Missing REPLICATE_API_TOKEN must return [] not raise."""
        monkeypatch.delenv("REPLICATE_API_TOKEN", raising=False)
        monkeypatch.setenv("MOCK_TESTING_MODE", "false")
        from backend.replicate_image_generator import ReplicateImageGenerator
        gen = ReplicateImageGenerator(api_key=None)
        gen.mock_mode = False
        result = gen.generate_story_illustration_flux_schnell(
            scene_description="anything", character_name="Hero",
            num_images=1, age=8,
        )
        assert result == []


class TestCloudflareFluxGenerator:
    """MT-131: the CloudflareImageGenerator Flux Schnell provider."""

    def test_method_exists_with_expected_signature(self):
        """Must share the Replicate Flux signature so callers can swap freely."""
        from backend.cloudflare_image_generator import CloudflareImageGenerator
        import inspect

        gen = CloudflareImageGenerator()
        assert hasattr(gen, "generate_story_illustration_flux")
        sig = inspect.signature(gen.generate_story_illustration_flux)
        for p in ("user_id", "age", "character_appearance", "companions", "power_id"):
            assert p in sig.parameters, f"missing kwarg: {p}"

    def test_returns_empty_in_mock_mode(self, monkeypatch):
        """MOCK_TESTING_MODE=true must return [] without hitting Cloudflare."""
        monkeypatch.setenv("MOCK_TESTING_MODE", "true")
        monkeypatch.setenv("CLOUDFLARE_ACCOUNT_ID", "acct")
        monkeypatch.setenv("CLOUDFLARE_API_TOKEN", "tok")
        from backend.cloudflare_image_generator import CloudflareImageGenerator
        gen = CloudflareImageGenerator()
        assert gen.generate_story_illustration_flux(
            scene_description="anything", character_name="Hero", age=8
        ) == []

    def test_returns_empty_without_credentials(self, monkeypatch):
        """Missing account id / token must return [] not raise."""
        monkeypatch.delenv("CLOUDFLARE_ACCOUNT_ID", raising=False)
        monkeypatch.delenv("CLOUDFLARE_API_TOKEN", raising=False)
        monkeypatch.setenv("MOCK_TESTING_MODE", "false")
        from backend.cloudflare_image_generator import CloudflareImageGenerator
        gen = CloudflareImageGenerator()
        gen.mock_mode = False
        assert gen.generate_story_illustration_flux(
            scene_description="anything", character_name="Hero", age=8
        ) == []

    def test_parses_workers_ai_response_to_image_dict(self, monkeypatch):
        """A successful Workers AI response normalizes to the shared dict shape."""
        monkeypatch.setenv("MOCK_TESTING_MODE", "false")
        monkeypatch.setenv("CLOUDFLARE_ACCOUNT_ID", "acct")
        monkeypatch.setenv("CLOUDFLARE_API_TOKEN", "tok")
        from backend.cloudflare_image_generator import CloudflareImageGenerator

        gen = CloudflareImageGenerator()
        gen.mock_mode = False
        fake_resp = MagicMock()
        fake_resp.status_code = 200
        fake_resp.json.return_value = {
            "success": True,
            "result": {"image": "BASE64DATA"},
        }
        with patch(
            "backend.cloudflare_image_generator.requests.post",
            return_value=fake_resp,
        ):
            out = gen.generate_story_illustration_flux(
                scene_description="a cave", character_name="Hero", age=8,
            )
        assert len(out) == 1
        img = out[0]
        assert img["image_data"] == "BASE64DATA"
        assert img["format"] == "jpeg"
        assert img["provider"] == "cloudflare-flux-schnell"
        for key in ("id", "prompt", "generated_at"):
            assert key in img, f"missing key: {key}"


class TestFluxProviderPrecedence:
    """MT-131: _generate_flux_illustration — Cloudflare first, Replicate next."""

    def test_cloudflare_is_tried_first(self, monkeypatch):
        """When Cloudflare yields art, Replicate must never be called."""
        monkeypatch.delenv("CLOUDFLARE_FLUX_DISABLED", raising=False)
        monkeypatch.delenv("FLUX_SCHNELL_DISABLED", raising=False)
        from backend.routes.story_routes import _generate_flux_illustration

        with patch(
            "backend.cloudflare_image_generator.CloudflareImageGenerator"
        ) as cf, patch(
            "backend.replicate_image_generator.ReplicateImageGenerator"
        ) as rep:
            cf.return_value.generate_story_illustration_flux.return_value = [
                _make_image_dict("cloudflare")
            ]
            result = _generate_flux_illustration(
                scene_description="x", character_name="y", style="z",
                num_images=1, age=8,
            )
            assert cf.return_value.generate_story_illustration_flux.call_count == 1
            assert (
                rep.return_value.generate_story_illustration_flux_schnell.call_count
                == 0
            ), "Replicate must not run when Cloudflare succeeds"
            assert result[0]["id"] == "test-cloudflare"

    def test_replicate_fallback_when_cloudflare_empty(self, monkeypatch):
        """Cloudflare outage/quota → fall through to Replicate Flux Schnell."""
        monkeypatch.delenv("CLOUDFLARE_FLUX_DISABLED", raising=False)
        monkeypatch.delenv("FLUX_SCHNELL_DISABLED", raising=False)
        from backend.routes.story_routes import _generate_flux_illustration

        with patch(
            "backend.cloudflare_image_generator.CloudflareImageGenerator"
        ) as cf, patch(
            "backend.replicate_image_generator.ReplicateImageGenerator"
        ) as rep:
            cf.return_value.generate_story_illustration_flux.return_value = []
            rep.return_value.generate_story_illustration_flux_schnell.return_value = [
                _make_image_dict("flux")
            ]
            result = _generate_flux_illustration(
                scene_description="x", character_name="y", style="z",
                num_images=1, age=8,
            )
            assert cf.return_value.generate_story_illustration_flux.call_count == 1
            assert (
                rep.return_value.generate_story_illustration_flux_schnell.call_count
                == 1
            )
            assert result[0]["id"] == "test-flux"

    def test_cloudflare_disabled_skips_straight_to_replicate(self, monkeypatch):
        """CLOUDFLARE_FLUX_DISABLED=true must skip Cloudflare entirely."""
        monkeypatch.setenv("CLOUDFLARE_FLUX_DISABLED", "true")
        monkeypatch.delenv("FLUX_SCHNELL_DISABLED", raising=False)
        from backend.routes.story_routes import _generate_flux_illustration

        with patch(
            "backend.cloudflare_image_generator.CloudflareImageGenerator"
        ) as cf, patch(
            "backend.replicate_image_generator.ReplicateImageGenerator"
        ) as rep:
            rep.return_value.generate_story_illustration_flux_schnell.return_value = [
                _make_image_dict("flux")
            ]
            result = _generate_flux_illustration(
                scene_description="x", character_name="y", style="z",
                num_images=1, age=8,
            )
            assert cf.return_value.generate_story_illustration_flux.call_count == 0
            assert (
                rep.return_value.generate_story_illustration_flux_schnell.call_count
                == 1
            )
            assert result[0]["id"] == "test-flux"

    def test_both_providers_disabled_returns_empty(self, monkeypatch):
        """Both kill-switches on → [] and neither provider invoked."""
        monkeypatch.setenv("CLOUDFLARE_FLUX_DISABLED", "true")
        monkeypatch.setenv("FLUX_SCHNELL_DISABLED", "true")
        from backend.routes.story_routes import _generate_flux_illustration

        with patch(
            "backend.cloudflare_image_generator.CloudflareImageGenerator"
        ) as cf, patch(
            "backend.replicate_image_generator.ReplicateImageGenerator"
        ) as rep:
            result = _generate_flux_illustration(
                scene_description="x", character_name="y", style="z",
                num_images=1, age=8,
            )
            assert result == []
            assert cf.return_value.generate_story_illustration_flux.call_count == 0
            assert (
                rep.return_value.generate_story_illustration_flux_schnell.call_count
                == 0
            )


class TestPowerVisualOverride:
    """MT-107: Explorer-band Superhero powers must inject visual signatures."""

    def test_feeling_sense_injects_empathy_glow(self):
        from backend.gemini_image_generator import _power_visual_block
        block = _power_visual_block("feeling_sense")
        assert "soft pastel halo" in block.lower()
        assert "empathy glow" in block.lower()
        assert "every frame" in block.lower()

    def test_invisibility_injects_translucent_wisp(self):
        from backend.gemini_image_generator import _power_visual_block
        block = _power_visual_block("invisibility")
        assert "translucent" in block.lower()
        assert "wisp-edged" in block.lower()

    def test_no_power_id_returns_empty(self):
        from backend.gemini_image_generator import _power_visual_block
        assert _power_visual_block(None) == ""
        assert _power_visual_block("") == ""
        assert _power_visual_block("super_speed") == ""  # not overridden

    def test_gemini_generate_threads_override_into_prompt(self):
        from unittest.mock import MagicMock
        from backend.gemini_image_generator import GeminiImageGenerator
        gen = GeminiImageGenerator(api_key="fake")
        gen._client = MagicMock()
        gen._client.models.generate_content.return_value = MagicMock(candidates=[])
        gen.generate_story_illustration(
            scene_description="hero meets a sad cloud",
            character_name="Mira",
            age=7,
            power_id="feeling_sense",
        )
        sent_prompt = gen._client.models.generate_content.call_args.kwargs["contents"][0]
        assert "soft pastel halo" in sent_prompt.lower()


class TestBuildAppearanceDetails:
    """MT-129: the illustration prompt must describe only appearance the user
    actually supplied — never a fabricated default — so the rendered character
    matches the created avatar instead of a generic child."""

    def test_empty_appearance_yields_no_details(self):
        from backend.gemini_image_generator import build_appearance_details
        # No appearance → empty list. (The fabrication bug lived on the Flutter
        # side; this guards the backend never invents one from a bare dict.)
        assert build_appearance_details(None) == []
        assert build_appearance_details({}) == []

    def test_only_supplied_fields_are_emitted(self):
        from backend.gemini_image_generator import build_appearance_details
        details = build_appearance_details({"skin_tone": "deep", "gender": "boy"})
        joined = " | ".join(details)
        assert "skin tone: deep" in joined
        assert "gender: boy" in joined
        # Hair/eyes were never supplied — they must not appear at all.
        assert "hair" not in joined
        assert "eye color" not in joined

    def test_photo_hair_style_phrase_is_passed_through(self):
        from backend.gemini_image_generator import build_appearance_details
        # The custom-photo pipeline returns hair as one combined phrase.
        details = build_appearance_details(
            {"hair_style": "wavy black shoulder-length"}
        )
        assert any("wavy black shoulder-length" in d for d in details)

    def test_distinguishing_feature_is_emitted(self):
        from backend.gemini_image_generator import build_appearance_details
        details = build_appearance_details({"distinguishing": "round glasses"})
        assert any("notable feature: round glasses" in d for d in details)

    def test_legacy_flat_keys_still_read(self):
        from backend.gemini_image_generator import build_appearance_details
        details = build_appearance_details(
            {"hair": "red", "skin": "fair", "outfit": "blue raincoat"}
        )
        joined = " | ".join(details)
        assert "red" in joined
        assert "skin tone: fair" in joined
        assert "wearing: blue raincoat" in joined
