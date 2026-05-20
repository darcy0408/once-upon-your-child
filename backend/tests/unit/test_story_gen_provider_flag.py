"""MT-171 Phase 1 unit tests for the ``STORY_GEN_PROVIDER`` feature flag.

Covers:

* ``STORY_GEN_PROVIDER=openrouter`` skips Gemini entirely (the whole point of
  the flag — Gemini's API Additional Terms prohibit child-directed apps).
* ``STORY_GEN_PROVIDER=gemini`` preserves legacy behavior (Gemini -> OpenRouter
  -> static).
* ``STORY_GEN_PROVIDER=auto`` tries OpenRouter first and falls back to Gemini
  on failure (rollback-safe migration order).
* ``_resolve_text_model`` returns the right OpenRouter model per tier.
* The OpenRouter-side ``_extract_text`` helper handles normal completion,
  empty content, max_tokens truncation, content_filter blocks, and the
  Claude-style content-block list shape.
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from backend.services import openrouter_story_generator as ors
from backend.services.openrouter_story_generator import (
    OPENROUTER_FALLBACK_MODEL,
    OPENROUTER_FREE_MODEL,
    OPENROUTER_PAID_MODEL,
    _extract_text,
    _resolve_text_model,
)
from backend.tasks import story_tasks


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# A valid (non-"Sorry") story body the orchestrator will accept as success.
_OK_STORY = (
    '{"title": "T", "pages": [{"text": "Once upon a time, a brave hero set out."}]}'
)


def _ok_openrouter_response(content: str = _OK_STORY, finish_reason: str = "stop") -> MagicMock:
    """Build a successful OpenRouter chat-completion HTTP response mock."""
    resp = MagicMock()
    resp.status_code = 200
    resp.raise_for_status.return_value = None
    resp.json.return_value = {
        "choices": [
            {
                "index": 0,
                "finish_reason": finish_reason,
                "message": {"role": "assistant", "content": content},
            }
        ]
    }
    return resp


def _ok_gemini_response(text: str = _OK_STORY) -> MagicMock:
    """Build a successful Gemini response mock matching `_extract_text` shape."""
    resp = MagicMock()
    resp.text = text
    resp.prompt_feedback = None
    resp.candidates = []
    return resp


# ---------------------------------------------------------------------------
# _resolve_text_model — pure function (OpenRouter side)
# ---------------------------------------------------------------------------
class TestResolveOpenRouterTextModel:
    def test_free_tier_selects_llama(self):
        assert _resolve_text_model("free") == OPENROUTER_FREE_MODEL

    def test_free_tier_is_case_insensitive(self):
        assert _resolve_text_model("FREE") == OPENROUTER_FREE_MODEL
        assert _resolve_text_model(" Free ") == OPENROUTER_FREE_MODEL

    @pytest.mark.parametrize("tier", ["premium", "family", "byok"])
    def test_paid_and_byok_tiers_select_claude_sonnet(self, tier):
        assert _resolve_text_model(tier) == OPENROUTER_PAID_MODEL

    def test_unknown_tier_selects_paid_model(self):
        """An unrecognized tier must fail toward quality, not downgrade."""
        assert _resolve_text_model("enterprise") == OPENROUTER_PAID_MODEL

    def test_missing_tier_selects_paid_model(self):
        """A missing tier defaults to the paid model — a payer is never
        silently downgraded by a dropped kwarg."""
        assert _resolve_text_model(None) == OPENROUTER_PAID_MODEL
        assert _resolve_text_model("") == OPENROUTER_PAID_MODEL
        assert _resolve_text_model("   ") == OPENROUTER_PAID_MODEL

    def test_paid_model_overridable_via_env(self):
        with patch.dict(
            "os.environ",
            {"OPENROUTER_PAID_MODEL": "anthropic/claude-custom"},
        ):
            assert _resolve_text_model("premium") == "anthropic/claude-custom"

    def test_free_model_overridable_via_env(self):
        with patch.dict(
            "os.environ",
            {"OPENROUTER_FREE_MODEL": "meta-llama/custom-llama"},
        ):
            assert _resolve_text_model("free") == "meta-llama/custom-llama"

    def test_hard_fallback_constant_is_a_free_route(self):
        """The hard fallback must point at a free route so we never crash on
        unknown-tier paths in environments without OpenRouter credits."""
        assert ":free" in OPENROUTER_FALLBACK_MODEL


# ---------------------------------------------------------------------------
# _extract_text — OpenRouter response-shape parser
# ---------------------------------------------------------------------------
class TestOpenRouterExtractText:
    def test_normal_completion_returns_content(self):
        data = {
            "choices": [
                {
                    "finish_reason": "stop",
                    "message": {"content": "Hello world"},
                }
            ]
        }
        assert _extract_text(data) == "Hello world"

    def test_claude_end_turn_returns_content(self):
        data = {
            "choices": [
                {
                    "finish_reason": "end_turn",
                    "message": {"content": "A Claude reply."},
                }
            ]
        }
        assert _extract_text(data) == "A Claude reply."

    def test_claude_content_block_list_is_flattened(self):
        """Some OpenRouter routes return Claude's native content-block list."""
        data = {
            "choices": [
                {
                    "finish_reason": "end_turn",
                    "message": {
                        "content": [
                            {"type": "text", "text": "Hello"},
                            {"type": "text", "text": " world"},
                        ]
                    },
                }
            ]
        }
        assert _extract_text(data) == "Hello world"

    def test_max_tokens_returns_partial_text(self):
        """``max_tokens`` / ``length`` are truncated but valid — surface the
        partial text rather than dropping it on the floor."""
        data = {
            "choices": [
                {
                    "finish_reason": "max_tokens",
                    "message": {"content": "Once upon a tim"},
                }
            ]
        }
        assert _extract_text(data) == "Once upon a tim"

    def test_length_finish_reason_returns_partial_text(self):
        data = {
            "choices": [
                {
                    "finish_reason": "length",
                    "message": {"content": "Once upon a tim"},
                }
            ]
        }
        assert _extract_text(data) == "Once upon a tim"

    def test_content_filter_returns_none(self):
        data = {
            "choices": [
                {
                    "finish_reason": "content_filter",
                    "message": {"content": "(blocked)"},
                }
            ]
        }
        assert _extract_text(data) is None

    def test_empty_content_returns_none(self):
        data = {
            "choices": [
                {
                    "finish_reason": "stop",
                    "message": {"content": ""},
                }
            ]
        }
        assert _extract_text(data) is None

    def test_whitespace_only_content_returns_none(self):
        data = {
            "choices": [
                {
                    "finish_reason": "stop",
                    "message": {"content": "   \n  "},
                }
            ]
        }
        assert _extract_text(data) is None

    def test_no_choices_returns_none(self):
        assert _extract_text({"choices": []}) is None
        assert _extract_text({}) is None

    def test_non_dict_returns_none(self):
        assert _extract_text(None) is None
        assert _extract_text("not a dict") is None


# ---------------------------------------------------------------------------
# Provider-flag sequencing — _generate_story_text_with_metadata
# ---------------------------------------------------------------------------
class TestProviderFlagSequencing:
    """End-to-end-ish coverage of the orchestrator's branches.

    These tests bypass Flask app context entirely and drive the env var
    directly, which is what ``_resolve_story_provider`` falls back to outside
    an app context (e.g. raw Celery worker boot). The autouse ``mock_gemini``
    + ``mock_openrouter_story`` conftest fixtures keep both providers off the
    real network.
    """

    @pytest.fixture(autouse=True)
    def _pin_gemini_key(self, monkeypatch):
        # StoryGenerationService requires GEMINI_API_KEY to construct, even
        # though the autouse mock_gemini fixture stubs the actual client.
        monkeypatch.setenv("GEMINI_API_KEY", "test-gemini-key")
        # mock_openrouter_story conftest fixture already sets OPENROUTER_API_KEY.
        yield

    # ----- STORY_GEN_PROVIDER=openrouter -----
    def test_openrouter_flag_skips_gemini_entirely(
        self, monkeypatch, mock_gemini, mock_openrouter_story
    ):
        """The whole point of the flag — Gemini must NOT be called when
        STORY_GEN_PROVIDER=openrouter."""
        monkeypatch.setenv("STORY_GEN_PROVIDER", "openrouter")

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "openrouter"
        assert text  # non-empty
        assert seq == ["openrouter(success)"]
        mock_gemini.models.generate_content.assert_not_called()
        mock_openrouter_story.post.assert_called_once()

    def test_openrouter_flag_falls_back_to_static_on_hard_failure(
        self, monkeypatch, mock_gemini, mock_openrouter_story
    ):
        """When OpenRouter raises a hard error and the flag forbids Gemini,
        the static fallback is the only option — Gemini must STILL not be
        called even though the legacy path would have tried it."""
        monkeypatch.setenv("STORY_GEN_PROVIDER", "openrouter")
        # Make OpenRouter raise a non-retryable HTTP error.
        import requests as _real_requests
        bad = MagicMock()
        bad.status_code = 500
        bad.text = "internal server error"
        bad.headers = {}
        http_err = _real_requests.exceptions.HTTPError(response=bad)
        mock_openrouter_story.post.side_effect = http_err

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        # On hard HTTP errors the OpenRouter generator returns a "Sorry, ..."
        # sentinel; the orchestrator treats that as a failure and (under the
        # openrouter flag) skips Gemini and falls straight to the static
        # fallback.
        assert provider == "static"
        assert text  # static fallback is non-empty
        assert any(s.startswith("openrouter(fail") for s in seq)
        assert "static" in seq
        mock_gemini.models.generate_content.assert_not_called()

    def test_openrouter_flag_returns_safety_fallback_text_on_content_filter(
        self, monkeypatch, mock_gemini, mock_openrouter_story
    ):
        """A content-filter block surfaces the user-visible safety-fallback
        string and STILL counts as an OpenRouter success — mirrors the
        existing Gemini-side behavior where a safety block returns the
        ``_SAFETY_FALLBACK`` message instead of falling through to the next
        provider. The point of the test is to verify Gemini is not called."""
        monkeypatch.setenv("STORY_GEN_PROVIDER", "openrouter")
        bad = MagicMock()
        bad.status_code = 200
        bad.raise_for_status.return_value = None
        bad.json.return_value = {
            "choices": [
                {"finish_reason": "content_filter", "message": {"content": "(blocked)"}}
            ]
        }
        mock_openrouter_story.post.return_value = bad

        text, provider, _seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "openrouter"
        assert "different adventure" in text  # _SAFETY_FALLBACK marker
        mock_gemini.models.generate_content.assert_not_called()

    # ----- STORY_GEN_PROVIDER=gemini (legacy default) -----
    def test_gemini_flag_preserves_legacy_order(
        self, monkeypatch, mock_gemini, mock_openrouter_story
    ):
        """Default behavior: Gemini first, OpenRouter only as fallback."""
        monkeypatch.setenv("STORY_GEN_PROVIDER", "gemini")
        mock_gemini.models.generate_content.return_value = _ok_gemini_response()

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "gemini"
        assert seq == ["gemini(success)"]
        mock_gemini.models.generate_content.assert_called()
        mock_openrouter_story.post.assert_not_called()

    def test_gemini_flag_falls_back_to_openrouter_on_failure(
        self, monkeypatch, mock_gemini, mock_openrouter_story
    ):
        """Legacy order: Gemini fails -> OpenRouter -> success."""
        monkeypatch.setenv("STORY_GEN_PROVIDER", "gemini")
        # Make Gemini return a "Sorry" sentinel (treated as failure by the
        # orchestrator — same behavior as the prior implementation).
        sorry = MagicMock()
        sorry.text = "Sorry, there was an unexpected error."
        sorry.prompt_feedback = None
        sorry.candidates = []
        mock_gemini.models.generate_content.return_value = sorry
        # mock_openrouter_story default response is already a success.

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "openrouter"
        assert any(s.startswith("gemini(fail") for s in seq)
        assert "openrouter(success)" in seq

    def test_unset_flag_defaults_to_gemini_order(
        self, monkeypatch, mock_gemini, mock_openrouter_story
    ):
        """Unset env var must behave exactly like STORY_GEN_PROVIDER=gemini."""
        monkeypatch.delenv("STORY_GEN_PROVIDER", raising=False)
        mock_gemini.models.generate_content.return_value = _ok_gemini_response()

        _text, provider, _seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "gemini"
        mock_openrouter_story.post.assert_not_called()

    # ----- STORY_GEN_PROVIDER=auto -----
    def test_auto_flag_tries_openrouter_first(
        self, monkeypatch, mock_gemini, mock_openrouter_story
    ):
        """In ``auto`` mode, OpenRouter is the first attempt — Gemini is only
        used if OpenRouter fails (rollback-safe migration order)."""
        monkeypatch.setenv("STORY_GEN_PROVIDER", "auto")

        _text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "openrouter"
        assert seq == ["openrouter(success)"]
        mock_gemini.models.generate_content.assert_not_called()
        mock_openrouter_story.post.assert_called_once()

    def test_auto_flag_falls_back_to_gemini_on_openrouter_failure(
        self, monkeypatch, mock_gemini, mock_openrouter_story
    ):
        """When OpenRouter fails hard under ``auto``, Gemini still gets a
        chance (vs ``openrouter`` mode which skips Gemini outright)."""
        monkeypatch.setenv("STORY_GEN_PROVIDER", "auto")
        # OpenRouter raises a hard HTTP error -> returns "Sorry, ..." sentinel,
        # which the orchestrator classifies as a fail and tries the next
        # provider in the chain.
        import requests as _real_requests
        bad = MagicMock()
        bad.status_code = 500
        bad.text = "internal server error"
        bad.headers = {}
        mock_openrouter_story.post.side_effect = _real_requests.exceptions.HTTPError(
            response=bad
        )
        # Gemini works.
        mock_gemini.models.generate_content.return_value = _ok_gemini_response()

        _text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "gemini"
        assert any(s.startswith("openrouter(fail") for s in seq)
        assert "gemini(success)" in seq

    def test_unknown_flag_value_warns_and_defaults_to_gemini(
        self, monkeypatch, mock_gemini, mock_openrouter_story
    ):
        """A typo'd flag value must not break the app — fall back to legacy."""
        monkeypatch.setenv("STORY_GEN_PROVIDER", "claude-direct")
        mock_gemini.models.generate_content.return_value = _ok_gemini_response()

        _text, provider, _seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "gemini"


# ---------------------------------------------------------------------------
# OpenRouterStoryGenerator — model wired up in __init__
# ---------------------------------------------------------------------------
class TestOpenRouterServiceModel:
    """Mirrors backend/tests/unit/test_story_model_tier_selection.py — verifies
    the constructor wires the right tier-resolved model."""

    @pytest.fixture(autouse=True)
    def _service_env(self, monkeypatch):
        monkeypatch.setenv("OPENROUTER_API_KEY", "test-key")
        # Pin the models so env-overrides in other tests don't leak in.
        monkeypatch.delenv("OPENROUTER_PAID_MODEL", raising=False)
        monkeypatch.delenv("OPENROUTER_FREE_MODEL", raising=False)
        yield

    def test_free_tier_service_uses_llama(self):
        svc = ors.OpenRouterStoryGenerator(user_tier="free")
        assert svc._model_name == OPENROUTER_FREE_MODEL

    @pytest.mark.parametrize("tier", ["premium", "family", "byok"])
    def test_paid_tier_service_uses_claude_sonnet(self, tier):
        svc = ors.OpenRouterStoryGenerator(user_tier=tier)
        assert svc._model_name == OPENROUTER_PAID_MODEL

    def test_no_tier_arg_defaults_to_paid_model(self):
        svc = ors.OpenRouterStoryGenerator()
        assert svc._model_name == OPENROUTER_PAID_MODEL
