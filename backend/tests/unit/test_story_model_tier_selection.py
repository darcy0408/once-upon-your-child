"""Unit tests for tier-aware Gemini text-model selection.

Free-tier users (who never pay) get the cheaper ``gemini-2.5-flash-lite``
model; paid / BYOK / unknown / missing tiers get the full ``GEMINI_MODEL``.
A missing tier must fail toward quality (full model), never silently
downgrade a payer.

Covers:
  * ``_resolve_text_model`` — the pure selection function.
  * ``StoryGenerationService.__init__`` — the ``_model_name`` it ends up with.
"""
from __future__ import annotations

from unittest.mock import patch

import pytest

from backend.services.story_generation_service import (
    StoryGenerationService,
    _resolve_text_model,
)

FULL_MODEL = "gemini-2.5-flash"
LITE_MODEL = "gemini-2.5-flash-lite"


# ---------------------------------------------------------------------------
# _resolve_text_model — pure function
# ---------------------------------------------------------------------------
class TestResolveTextModel:
    @pytest.fixture(autouse=True)
    def _clean_model_env(self):
        """Pin GEMINI_MODEL / GEMINI_MODEL_FREE so tests are env-independent."""
        with patch.dict(
            "os.environ",
            {"GEMINI_MODEL": FULL_MODEL, "GEMINI_MODEL_FREE": LITE_MODEL},
        ):
            yield

    def test_free_tier_selects_flash_lite(self):
        assert _resolve_text_model("free") == LITE_MODEL

    def test_free_tier_is_case_insensitive(self):
        assert _resolve_text_model("FREE") == LITE_MODEL
        assert _resolve_text_model(" Free ") == LITE_MODEL

    @pytest.mark.parametrize("tier", ["premium", "family", "byok"])
    def test_paid_and_byok_tiers_select_full_flash(self, tier):
        assert _resolve_text_model(tier) == FULL_MODEL

    def test_unknown_tier_selects_full_flash(self):
        """An unrecognized tier must fail toward quality, not downgrade."""
        assert _resolve_text_model("enterprise") == FULL_MODEL

    def test_missing_tier_selects_full_flash(self):
        """A missing tier (None / empty) defaults to the full model — a
        payer is never silently downgraded by a dropped kwarg."""
        assert _resolve_text_model(None) == FULL_MODEL
        assert _resolve_text_model("") == FULL_MODEL
        assert _resolve_text_model("   ") == FULL_MODEL

    def test_free_model_is_overridable_via_env(self):
        """GEMINI_MODEL_FREE overrides the flash-lite default."""
        with patch.dict("os.environ", {"GEMINI_MODEL_FREE": "gemini-custom-lite"}):
            assert _resolve_text_model("free") == "gemini-custom-lite"

    def test_full_model_is_overridable_via_env(self):
        with patch.dict("os.environ", {"GEMINI_MODEL": "gemini-custom-pro"}):
            assert _resolve_text_model("premium") == "gemini-custom-pro"


# ---------------------------------------------------------------------------
# StoryGenerationService — model wired up in __init__
# ---------------------------------------------------------------------------
class TestStoryGenerationServiceModel:
    """The autouse ``mock_gemini`` conftest fixture stubs ``genai.Client``,
    so the service is constructible without real API calls."""

    @pytest.fixture(autouse=True)
    def _service_env(self):
        with patch.dict(
            "os.environ",
            {
                "GEMINI_API_KEY": "test-key",
                "GEMINI_MODEL": FULL_MODEL,
                "GEMINI_MODEL_FREE": LITE_MODEL,
            },
        ):
            yield

    def test_free_tier_service_uses_flash_lite(self):
        svc = StoryGenerationService(user_tier="free")
        assert svc._model_name == LITE_MODEL

    @pytest.mark.parametrize("tier", ["premium", "family", "byok"])
    def test_paid_tier_service_uses_full_flash(self, tier):
        svc = StoryGenerationService(user_tier=tier)
        assert svc._model_name == FULL_MODEL

    def test_unknown_tier_service_uses_full_flash(self):
        svc = StoryGenerationService(user_tier="mystery-tier")
        assert svc._model_name == FULL_MODEL

    def test_no_tier_arg_defaults_to_full_flash(self):
        """Backwards-compatible: a legacy caller that omits user_tier
        entirely gets the full model."""
        svc = StoryGenerationService()
        assert svc._model_name == FULL_MODEL
