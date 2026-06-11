"""MT-248 unit tests for the direct-Anthropic ``claude`` story-text provider.

Mirrors ``test_story_gen_provider_flag.py`` (the OpenRouter side). Covers:

* ``_resolve_text_model`` returns the right Claude model per tier.
* ``_extract_text`` handles the Anthropic Messages response shape: normal
  completion, refusal (-> None), max_tokens truncation (-> partial), and empty
  content (-> None).
* ``STORY_GEN_PROVIDER=claude`` routes to Claude and skips Gemini entirely
  (the whole point of the flag — Gemini's terms prohibit child-directed apps),
  falling back only to the static story on a hard failure.
* The constructor wires the tier-resolved model.

The ``anthropic`` SDK is never touched: ``_make_anthropic_client`` is patched
to return a fake client, so these tests run without the package installed.
"""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from backend.services import anthropic_story_generator as acg
from backend.services.anthropic_story_generator import (
    ANTHROPIC_FREE_MODEL,
    ANTHROPIC_PAID_MODEL,
    ClaudeDirectStoryGenerator,
    _extract_text,
    _resolve_text_model,
)
from backend.tasks import story_tasks

# A valid (non-"Sorry") story body the orchestrator accepts as success.
_OK_STORY = (
    '{"title": "T", "pages": [{"text": "Once upon a time, a brave hero set out."}]}'
)


def _text_block(text: str):
    return SimpleNamespace(type="text", text=text)


def _claude_response(content: str = _OK_STORY, stop_reason: str = "end_turn"):
    """Build a fake Anthropic Messages response matching `_extract_text` shape."""
    return SimpleNamespace(
        stop_reason=stop_reason,
        stop_details=None,
        content=[_text_block(content)],
    )


def _fake_client_returning(response) -> MagicMock:
    client = MagicMock()
    client.messages.create.return_value = response
    return client


# ---------------------------------------------------------------------------
# _resolve_text_model — pure function
# ---------------------------------------------------------------------------
class TestResolveClaudeTextModel:
    def test_free_tier_selects_free_model(self):
        assert _resolve_text_model("free") == ANTHROPIC_FREE_MODEL

    def test_free_tier_is_case_insensitive(self):
        assert _resolve_text_model("FREE") == ANTHROPIC_FREE_MODEL
        assert _resolve_text_model(" Free ") == ANTHROPIC_FREE_MODEL

    @pytest.mark.parametrize("tier", ["premium", "family", "byok"])
    def test_paid_and_byok_tiers_select_paid_model(self, tier):
        assert _resolve_text_model(tier) == ANTHROPIC_PAID_MODEL

    def test_unknown_tier_selects_paid_model(self):
        assert _resolve_text_model("enterprise") == ANTHROPIC_PAID_MODEL

    def test_missing_tier_selects_paid_model(self):
        assert _resolve_text_model(None) == ANTHROPIC_PAID_MODEL
        assert _resolve_text_model("") == ANTHROPIC_PAID_MODEL
        assert _resolve_text_model("   ") == ANTHROPIC_PAID_MODEL

    def test_paid_model_overridable_via_env(self, monkeypatch):
        monkeypatch.setenv("ANTHROPIC_PAID_MODEL", "claude-sonnet-4-6")
        assert _resolve_text_model("premium") == "claude-sonnet-4-6"

    def test_free_model_overridable_via_env(self, monkeypatch):
        monkeypatch.setenv("ANTHROPIC_FREE_MODEL", "claude-custom-free")
        assert _resolve_text_model("free") == "claude-custom-free"

    def test_default_models_are_bare_aliases_no_date_suffix(self):
        # Anthropic model IDs are bare aliases; a date suffix would 404.
        for model in (ANTHROPIC_PAID_MODEL, ANTHROPIC_FREE_MODEL):
            assert model == "claude-haiku-4-5"


# ---------------------------------------------------------------------------
# _extract_text — Anthropic response-shape parser
# ---------------------------------------------------------------------------
class TestClaudeExtractText:
    def test_normal_completion_returns_content(self):
        assert _extract_text(_claude_response("Hello world")) == "Hello world"

    def test_multiple_text_blocks_are_concatenated(self):
        resp = SimpleNamespace(
            stop_reason="end_turn",
            stop_details=None,
            content=[_text_block("Hello"), _text_block(" world")],
        )
        assert _extract_text(resp) == "Hello world"

    def test_non_text_blocks_are_ignored(self):
        resp = SimpleNamespace(
            stop_reason="end_turn",
            stop_details=None,
            content=[
                SimpleNamespace(type="thinking", thinking="hmm"),
                _text_block("real text"),
            ],
        )
        assert _extract_text(resp) == "real text"

    def test_max_tokens_returns_partial_text(self):
        assert _extract_text(_claude_response("Once upon a tim", "max_tokens")) == (
            "Once upon a tim"
        )

    def test_refusal_returns_none(self):
        resp = SimpleNamespace(
            stop_reason="refusal",
            stop_details=SimpleNamespace(category="cyber", explanation="no"),
            content=[_text_block("(refused)")],
        )
        assert _extract_text(resp) is None

    def test_empty_content_returns_none(self):
        assert _extract_text(_claude_response("", "end_turn")) is None

    def test_whitespace_only_content_returns_none(self):
        assert _extract_text(_claude_response("   \n  ", "end_turn")) is None

    def test_no_content_blocks_returns_none(self):
        resp = SimpleNamespace(stop_reason="end_turn", stop_details=None, content=[])
        assert _extract_text(resp) is None

    def test_none_response_returns_none(self):
        assert _extract_text(None) is None


# ---------------------------------------------------------------------------
# ClaudeDirectStoryGenerator — constructor + generate_story
# ---------------------------------------------------------------------------
class TestClaudeServiceModel:
    @pytest.fixture(autouse=True)
    def _service_env(self, monkeypatch):
        monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")
        monkeypatch.delenv("ANTHROPIC_PAID_MODEL", raising=False)
        monkeypatch.delenv("ANTHROPIC_FREE_MODEL", raising=False)
        # Never touch the real SDK.
        monkeypatch.setattr(acg, "_make_anthropic_client", lambda api_key: MagicMock())
        yield

    def test_free_tier_service_uses_free_model(self):
        svc = ClaudeDirectStoryGenerator(user_tier="free")
        assert svc._model_name == ANTHROPIC_FREE_MODEL

    @pytest.mark.parametrize("tier", ["premium", "family", "byok"])
    def test_paid_tier_service_uses_paid_model(self, tier):
        svc = ClaudeDirectStoryGenerator(user_tier=tier)
        assert svc._model_name == ANTHROPIC_PAID_MODEL

    def test_no_tier_arg_defaults_to_paid_model(self):
        assert ClaudeDirectStoryGenerator()._model_name == ANTHROPIC_PAID_MODEL

    def test_missing_key_raises(self, monkeypatch):
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
        with pytest.raises(ValueError, match="ANTHROPIC_API_KEY"):
            ClaudeDirectStoryGenerator()

    def test_generate_story_returns_text_on_success(self):
        with patch.object(
            acg,
            "_make_anthropic_client",
            lambda api_key: _fake_client_returning(_claude_response()),
        ):
            out = ClaudeDirectStoryGenerator(user_tier="premium").generate_story("hi")
        assert out == _OK_STORY

    def test_generate_story_returns_safety_fallback_on_refusal(self):
        refusal = SimpleNamespace(
            stop_reason="refusal",
            stop_details=SimpleNamespace(category="cyber", explanation="no"),
            content=[_text_block("(refused)")],
        )
        with patch.object(
            acg,
            "_make_anthropic_client",
            lambda api_key: _fake_client_returning(refusal),
        ):
            out = ClaudeDirectStoryGenerator().generate_story("hi")
        assert "different adventure" in out  # _SAFETY_FALLBACK marker

    def test_generate_story_returns_sorry_on_server_error(self):
        client = MagicMock()
        client.messages.create.side_effect = RuntimeError("boom")
        with patch.object(acg, "_make_anthropic_client", lambda api_key: client):
            out = ClaudeDirectStoryGenerator().generate_story("hi")
        assert out.startswith("Sorry")


# ---------------------------------------------------------------------------
# Provider-flag sequencing — STORY_GEN_PROVIDER=claude
# ---------------------------------------------------------------------------
class TestClaudeProviderFlagSequencing:
    @pytest.fixture(autouse=True)
    def _env(self, monkeypatch):
        monkeypatch.setenv("ANTHROPIC_API_KEY", "test-anthropic-key")
        # StoryGenerationService needs a Gemini key just to construct; the
        # autouse mock_gemini conftest fixture stubs the actual client.
        monkeypatch.setenv("GEMINI_API_KEY", "test-gemini-key")
        monkeypatch.setenv("STORY_GEN_PROVIDER", "claude")
        yield

    def test_claude_flag_skips_gemini_entirely(self, monkeypatch, mock_gemini):
        """The whole point of the flag — Gemini must NOT be called."""
        monkeypatch.setattr(
            acg,
            "_make_anthropic_client",
            lambda api_key: _fake_client_returning(_claude_response()),
        )

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "claude"
        assert text
        assert seq == ["claude(success)"]
        mock_gemini.models.generate_content.assert_not_called()

    def test_claude_flag_falls_back_to_static_on_hard_failure(
        self, monkeypatch, mock_gemini
    ):
        """On a hard Claude failure the flag forbids Gemini — static is the only
        option, and Gemini must STILL not be called."""
        client = MagicMock()
        client.messages.create.side_effect = RuntimeError("kaboom")
        monkeypatch.setattr(acg, "_make_anthropic_client", lambda api_key: client)

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "static"
        assert text  # static fallback is non-empty
        assert any(s.startswith("claude(fail") for s in seq)
        assert "static" in seq
        mock_gemini.models.generate_content.assert_not_called()

    def test_claude_flag_skips_when_no_key(self, monkeypatch, mock_gemini):
        """No ANTHROPIC_API_KEY -> tagged no_key, straight to static, no Gemini."""
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "static"
        assert "claude(fail:no_key)" in seq
        mock_gemini.models.generate_content.assert_not_called()

    def test_resolver_recognizes_claude(self, monkeypatch):
        monkeypatch.setenv("STORY_GEN_PROVIDER", "claude")
        assert story_tasks._resolve_story_provider() == "claude"
