"""MT-248 unit tests for the direct-OpenAI ``openai`` story-text provider and
the ``tiered`` free->OpenAI / paid->Claude split.

Mirrors ``test_claude_story_generator.py`` (the Anthropic side). Covers:

* ``_resolve_text_model`` returns the right OpenAI model per tier.
* ``_resolve_reasoning_effort`` honors the no-reasoning sentinels.
* ``_extract_text`` handles the Chat Completions ``choice`` shape: normal
  completion, content_filter (-> None), structured refusal (-> None), length
  truncation (-> partial), and empty content (-> None).
* ``generate_story`` sends ``max_completion_tokens`` and ``reasoning_effort``,
  and omits the latter when disabled.
* ``STORY_GEN_PROVIDER=openai`` routes to OpenAI and skips Gemini entirely,
  falling back only to the static story on a hard failure.
* ``STORY_GEN_PROVIDER=tiered`` routes free->OpenAI and paid->Claude, with the
  sibling provider as cross-fallback and Gemini never touched.

The ``openai`` / ``anthropic`` SDKs are never touched: ``_make_openai_client``
and ``_make_anthropic_client`` are patched to return fake clients, so these
tests run without either package installed.
"""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from backend.services import anthropic_story_generator as acg
from backend.services import openai_story_generator as ocg
from backend.services.openai_story_generator import (
    OPENAI_FREE_MODEL,
    OPENAI_PAID_MODEL,
    OpenAIStoryGenerator,
    _extract_text,
    _resolve_reasoning_effort,
    _resolve_text_model,
)
from backend.tasks import story_tasks

# A valid (non-"Sorry") story body the orchestrator accepts as success.
_OK_STORY = (
    '{"title": "T", "pages": [{"text": "Once upon a time, a brave hero set out."}]}'
)


def _choice(content: str = _OK_STORY, finish_reason: str = "stop", refusal=None):
    return SimpleNamespace(
        finish_reason=finish_reason,
        message=SimpleNamespace(content=content, refusal=refusal),
    )


def _openai_response(
    content: str = _OK_STORY, finish_reason: str = "stop", refusal=None
):
    """Build a fake Chat Completions response matching `_extract_text` shape."""
    return SimpleNamespace(choices=[_choice(content, finish_reason, refusal)])


def _fake_client_returning(response) -> MagicMock:
    client = MagicMock()
    client.chat.completions.create.return_value = response
    return client


# Anthropic fake (for the tiered cross-provider tests) — matches acg shapes.
def _claude_response(content: str = _OK_STORY, stop_reason: str = "end_turn"):
    return SimpleNamespace(
        stop_reason=stop_reason,
        stop_details=None,
        content=[SimpleNamespace(type="text", text=content)],
    )


def _fake_claude_client_returning(response) -> MagicMock:
    client = MagicMock()
    client.messages.create.return_value = response
    return client


# ---------------------------------------------------------------------------
# _resolve_text_model — pure function
# ---------------------------------------------------------------------------
class TestResolveOpenAITextModel:
    def test_free_tier_selects_free_model(self):
        assert _resolve_text_model("free") == OPENAI_FREE_MODEL

    def test_free_tier_is_case_insensitive(self):
        assert _resolve_text_model("FREE") == OPENAI_FREE_MODEL
        assert _resolve_text_model(" Free ") == OPENAI_FREE_MODEL

    @pytest.mark.parametrize("tier", ["premium", "family", "byok"])
    def test_paid_and_byok_tiers_select_paid_model(self, tier):
        assert _resolve_text_model(tier) == OPENAI_PAID_MODEL

    def test_unknown_tier_selects_paid_model(self):
        assert _resolve_text_model("enterprise") == OPENAI_PAID_MODEL

    def test_missing_tier_selects_paid_model(self):
        assert _resolve_text_model(None) == OPENAI_PAID_MODEL
        assert _resolve_text_model("") == OPENAI_PAID_MODEL
        assert _resolve_text_model("   ") == OPENAI_PAID_MODEL

    def test_paid_model_overridable_via_env(self, monkeypatch):
        monkeypatch.setenv("OPENAI_PAID_MODEL", "gpt-5.4")
        assert _resolve_text_model("premium") == "gpt-5.4"

    def test_free_model_overridable_via_env(self, monkeypatch):
        monkeypatch.setenv("OPENAI_FREE_MODEL", "gpt-5-nano")
        assert _resolve_text_model("free") == "gpt-5-nano"

    def test_default_models_are_gpt5_mini(self):
        for model in (OPENAI_PAID_MODEL, OPENAI_FREE_MODEL):
            assert model == "gpt-5-mini"


# ---------------------------------------------------------------------------
# _resolve_reasoning_effort — pure function
# ---------------------------------------------------------------------------
class TestResolveReasoningEffort:
    def test_default_is_low(self, monkeypatch):
        monkeypatch.delenv("OPENAI_REASONING_EFFORT", raising=False)
        assert _resolve_reasoning_effort() == "low"

    def test_explicit_value_passthrough(self, monkeypatch):
        monkeypatch.setenv("OPENAI_REASONING_EFFORT", "medium")
        assert _resolve_reasoning_effort() == "medium"

    @pytest.mark.parametrize("sentinel", ["none", "off", "", "default", "  NONE  "])
    def test_no_reasoning_sentinels_return_none(self, monkeypatch, sentinel):
        monkeypatch.setenv("OPENAI_REASONING_EFFORT", sentinel)
        assert _resolve_reasoning_effort() is None


# ---------------------------------------------------------------------------
# _extract_text — Chat Completions choice parser
# ---------------------------------------------------------------------------
class TestOpenAIExtractText:
    def test_normal_completion_returns_content(self):
        assert _extract_text(_choice("Hello world")) == "Hello world"

    def test_length_returns_partial_text(self):
        assert _extract_text(_choice("Once upon a tim", "length")) == "Once upon a tim"

    def test_content_filter_returns_none(self):
        assert _extract_text(_choice("(blocked)", "content_filter")) is None

    def test_structured_refusal_returns_none(self):
        assert (
            _extract_text(_choice(None, "stop", refusal="I can't help with that"))
            is None
        )

    def test_empty_content_returns_none(self):
        assert _extract_text(_choice("", "stop")) is None

    def test_whitespace_only_content_returns_none(self):
        assert _extract_text(_choice("   \n  ", "stop")) is None

    def test_none_message_returns_none(self):
        assert (
            _extract_text(SimpleNamespace(finish_reason="stop", message=None)) is None
        )

    def test_none_choice_returns_none(self):
        assert _extract_text(None) is None


# ---------------------------------------------------------------------------
# OpenAIStoryGenerator — constructor + generate_story
# ---------------------------------------------------------------------------
class TestOpenAIServiceModel:
    @pytest.fixture(autouse=True)
    def _service_env(self, monkeypatch):
        monkeypatch.setenv("OPENAI_API_KEY", "test-key")
        monkeypatch.delenv("OPENAI_PAID_MODEL", raising=False)
        monkeypatch.delenv("OPENAI_FREE_MODEL", raising=False)
        monkeypatch.delenv("OPENAI_REASONING_EFFORT", raising=False)
        # Never touch the real SDK.
        monkeypatch.setattr(ocg, "_make_openai_client", lambda api_key: MagicMock())
        yield

    def test_free_tier_service_uses_free_model(self):
        svc = OpenAIStoryGenerator(user_tier="free")
        assert svc._model_name == OPENAI_FREE_MODEL

    @pytest.mark.parametrize("tier", ["premium", "family", "byok"])
    def test_paid_tier_service_uses_paid_model(self, tier):
        svc = OpenAIStoryGenerator(user_tier=tier)
        assert svc._model_name == OPENAI_PAID_MODEL

    def test_no_tier_arg_defaults_to_paid_model(self):
        assert OpenAIStoryGenerator()._model_name == OPENAI_PAID_MODEL

    def test_missing_key_raises(self, monkeypatch):
        monkeypatch.delenv("OPENAI_API_KEY", raising=False)
        with pytest.raises(ValueError, match="OPENAI_API_KEY"):
            OpenAIStoryGenerator()

    def test_generate_story_returns_text_on_success(self):
        with patch.object(
            ocg,
            "_make_openai_client",
            lambda api_key: _fake_client_returning(_openai_response()),
        ):
            out = OpenAIStoryGenerator(user_tier="premium").generate_story("hi")
        assert out == _OK_STORY

    def test_generate_story_sends_max_completion_tokens_and_reasoning_effort(self):
        client = _fake_client_returning(_openai_response())
        with patch.object(ocg, "_make_openai_client", lambda api_key: client):
            OpenAIStoryGenerator(user_tier="free").generate_story("hi")
        kwargs = client.chat.completions.create.call_args.kwargs
        assert kwargs["max_completion_tokens"] == 8192
        assert kwargs["reasoning_effort"] == "low"
        assert "max_tokens" not in kwargs  # deprecated for reasoning models

    def test_generate_story_omits_reasoning_effort_when_disabled(self, monkeypatch):
        monkeypatch.setenv("OPENAI_REASONING_EFFORT", "none")
        client = _fake_client_returning(_openai_response())
        with patch.object(ocg, "_make_openai_client", lambda api_key: client):
            OpenAIStoryGenerator(user_tier="free").generate_story("hi")
        kwargs = client.chat.completions.create.call_args.kwargs
        assert "reasoning_effort" not in kwargs

    def test_generate_story_returns_safety_fallback_on_refusal(self):
        with patch.object(
            ocg,
            "_make_openai_client",
            lambda api_key: _fake_client_returning(
                _openai_response(None, "stop", refusal="no")
            ),
        ):
            out = OpenAIStoryGenerator().generate_story("hi")
        assert "different adventure" in out  # _SAFETY_FALLBACK marker

    def test_generate_story_returns_sorry_on_server_error(self):
        client = MagicMock()
        client.chat.completions.create.side_effect = RuntimeError("boom")
        with patch.object(ocg, "_make_openai_client", lambda api_key: client):
            out = OpenAIStoryGenerator().generate_story("hi")
        assert out.startswith("Sorry")


# ---------------------------------------------------------------------------
# Provider-flag sequencing — STORY_GEN_PROVIDER=openai
# ---------------------------------------------------------------------------
class TestOpenAIProviderFlagSequencing:
    @pytest.fixture(autouse=True)
    def _env(self, monkeypatch):
        monkeypatch.setenv("OPENAI_API_KEY", "test-openai-key")
        monkeypatch.setenv("GEMINI_API_KEY", "test-gemini-key")
        monkeypatch.setenv("STORY_GEN_PROVIDER", "openai")
        yield

    def test_openai_flag_skips_gemini_entirely(self, monkeypatch, mock_gemini):
        monkeypatch.setattr(
            ocg,
            "_make_openai_client",
            lambda api_key: _fake_client_returning(_openai_response()),
        )

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "openai"
        assert text
        assert seq == ["openai(success)"]
        mock_gemini.models.generate_content.assert_not_called()

    def test_openai_flag_falls_back_to_static_on_hard_failure(
        self, monkeypatch, mock_gemini
    ):
        client = MagicMock()
        client.chat.completions.create.side_effect = RuntimeError("kaboom")
        monkeypatch.setattr(ocg, "_make_openai_client", lambda api_key: client)

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "static"
        assert text
        assert any(s.startswith("openai(fail") for s in seq)
        assert "static" in seq
        mock_gemini.models.generate_content.assert_not_called()

    def test_openai_flag_skips_when_no_key(self, monkeypatch, mock_gemini):
        monkeypatch.delenv("OPENAI_API_KEY", raising=False)

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
        )

        assert provider == "static"
        assert "openai(fail:no_key)" in seq
        mock_gemini.models.generate_content.assert_not_called()

    def test_resolver_recognizes_openai(self, monkeypatch):
        monkeypatch.setenv("STORY_GEN_PROVIDER", "openai")
        assert story_tasks._resolve_story_provider() == "openai"


# ---------------------------------------------------------------------------
# Provider-flag sequencing — STORY_GEN_PROVIDER=tiered (the free/paid split)
# ---------------------------------------------------------------------------
class TestTieredProviderSequencing:
    @pytest.fixture(autouse=True)
    def _env(self, monkeypatch):
        monkeypatch.setenv("OPENAI_API_KEY", "test-openai-key")
        monkeypatch.setenv("ANTHROPIC_API_KEY", "test-anthropic-key")
        monkeypatch.setenv("GEMINI_API_KEY", "test-gemini-key")
        monkeypatch.setenv("STORY_GEN_PROVIDER", "tiered")
        yield

    def test_resolver_recognizes_tiered(self):
        assert story_tasks._resolve_story_provider() == "tiered"

    def test_free_tier_routes_to_openai_first(self, monkeypatch, mock_gemini):
        monkeypatch.setattr(
            ocg,
            "_make_openai_client",
            lambda api_key: _fake_client_returning(_openai_response()),
        )
        # Claude client would raise if called — proves it isn't.
        monkeypatch.setattr(
            acg,
            "_make_anthropic_client",
            lambda api_key: (_ for _ in ()).throw(AssertionError("Claude called")),
        )

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
            user_tier="free",
        )

        assert provider == "openai"
        assert seq == ["openai(success)"]
        mock_gemini.models.generate_content.assert_not_called()

    def test_paid_tier_routes_to_claude_first(self, monkeypatch, mock_gemini):
        monkeypatch.setattr(
            acg,
            "_make_anthropic_client",
            lambda api_key: _fake_claude_client_returning(_claude_response()),
        )
        monkeypatch.setattr(
            ocg,
            "_make_openai_client",
            lambda api_key: (_ for _ in ()).throw(AssertionError("OpenAI called")),
        )

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
            user_tier="premium",
        )

        assert provider == "claude"
        assert seq == ["claude(success)"]
        mock_gemini.models.generate_content.assert_not_called()

    def test_free_tier_cross_falls_back_to_claude(self, monkeypatch, mock_gemini):
        """OpenAI hard-fails on the free leg -> Claude picks it up (not static,
        not Gemini)."""
        openai_client = MagicMock()
        openai_client.chat.completions.create.side_effect = RuntimeError("down")
        monkeypatch.setattr(ocg, "_make_openai_client", lambda api_key: openai_client)
        monkeypatch.setattr(
            acg,
            "_make_anthropic_client",
            lambda api_key: _fake_claude_client_returning(_claude_response()),
        )

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
            user_tier="free",
        )

        assert provider == "claude"
        assert any(s.startswith("openai(fail") for s in seq)
        assert "claude(success)" in seq
        mock_gemini.models.generate_content.assert_not_called()

    def test_tiered_both_down_falls_back_to_static(self, monkeypatch, mock_gemini):
        openai_client = MagicMock()
        openai_client.chat.completions.create.side_effect = RuntimeError("down")
        claude_client = MagicMock()
        claude_client.messages.create.side_effect = RuntimeError("down")
        monkeypatch.setattr(ocg, "_make_openai_client", lambda api_key: openai_client)
        monkeypatch.setattr(
            acg, "_make_anthropic_client", lambda api_key: claude_client
        )

        text, provider, seq = story_tasks._generate_story_text_with_metadata(
            prompt="Tell a story",
            theme="adventure",
            character_name="Aria",
            user_tier="free",
        )

        assert provider == "static"
        assert text
        assert any(s.startswith("openai(fail") for s in seq)
        assert any(s.startswith("claude(fail") for s in seq)
        assert "static" in seq
        mock_gemini.models.generate_content.assert_not_called()
