"""Unit tests for OpenAIImageGenerator (gpt-image-2 avatar provider, MT-295).

Pure unit — the OpenAI client is replaced with a fake, so no network/key is
needed. Verifies the photo path uses images.edit, the preset path uses
images.generate, the return shape matches what AvatarGenerationService's
_extract_base64_from_results expects, and that AvatarGenerationService selects
OpenAI as the primary generator when OPENAI_API_KEY is present.
"""

from __future__ import annotations

import types

import pytest

from backend.openai_image_generator import OpenAIImageGenerator

_B64 = "ZmFrZS1iNjQ="  # base64("fake-b64")


class _FakeImagesAPI:
    def __init__(self, b64):
        self._b64 = b64
        self.edit_calls = []
        self.generate_calls = []

    def _resp(self):
        return types.SimpleNamespace(
            data=[types.SimpleNamespace(b64_json=self._b64)] if self._b64 else []
        )

    def edit(self, **kwargs):
        self.edit_calls.append(kwargs)
        return self._resp()

    def generate(self, **kwargs):
        self.generate_calls.append(kwargs)
        return self._resp()


class _FakeChatCompletions:
    def __init__(
        self,
        content='{"hair_style": "wavy brown", "skin_tone": "tan", "distinguishing": "freckles"}',
        raise_exc=False,
    ):
        self._content = content
        self._raise = raise_exc
        self.calls = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        if self._raise:
            raise RuntimeError("vision boom")
        msg = types.SimpleNamespace(content=self._content)
        return types.SimpleNamespace(choices=[types.SimpleNamespace(message=msg)])


class _FakeChat:
    def __init__(self, **kw):
        self.completions = _FakeChatCompletions(**kw)


class _FakeClient:
    def __init__(self, b64=_B64, chat_kwargs=None):
        self.images = _FakeImagesAPI(b64)
        self.chat = _FakeChat(**(chat_kwargs or {}))


@pytest.fixture
def gen():
    g = OpenAIImageGenerator(api_key="test-key")
    g._client = _FakeClient()
    return g


def test_requires_api_key(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    with pytest.raises(ValueError):
        OpenAIImageGenerator(api_key=None)


def test_custom_avatar_uses_edit_endpoint(gen):
    out = gen.generate_custom_avatar(
        base_image_bytes=b"\x89PNG\r\n\x1a\nfake",
        prompt="cartoon",
        character_name="Mia",
        age=9,
    )
    assert out == [{"image_data": _B64}]
    assert gen._client.images.edit_calls, "photo avatar must use images.edit"
    assert gen._client.images.edit_calls[0]["model"] == "gpt-image-2"
    assert not gen._client.images.generate_calls


def test_custom_avatar_requires_photo_bytes(gen):
    with pytest.raises(ValueError):
        gen.generate_custom_avatar(base_image_bytes=b"", prompt="x")


def test_character_avatar_uses_generate_endpoint(gen):
    out = gen.generate_character_avatar(
        prompt="a brave hero", character_name="Mia", age=9
    )
    assert out == [{"image_data": _B64}]
    assert gen._client.images.generate_calls, "preset avatar must use images.generate"
    assert gen._client.images.generate_calls[0]["model"] == "gpt-image-2"
    assert not gen._client.images.edit_calls


def test_empty_response_returns_empty_list(gen):
    gen._client = _FakeClient(b64=None)
    assert gen.generate_character_avatar(prompt="x") == []


def test_pet_avatar_uses_edit(gen):
    out = gen.generate_pet_avatar(
        photo_bytes=b"\x89PNG\r\n\x1a\nfake", species="dog", prompt="cartoon pup"
    )
    assert out == [{"image_data": _B64}]
    assert gen._client.images.edit_calls


def test_pet_avatar_requires_photo(gen):
    with pytest.raises(ValueError):
        gen.generate_pet_avatar(photo_bytes=b"", species="dog")


def test_superhero_transform_uses_edit(gen):
    out = gen.transform_to_superhero(
        b"\x89PNG\r\n\x1a\nfake",
        costume_color="red",
        cape_style="flowing",
        emblem="star",
        power="speed",
    )
    assert out == [{"image_data": _B64}]
    assert gen._client.images.edit_calls
    assert gen._client.images.edit_calls[0]["model"] == "gpt-image-2"


def test_analyze_photo_features_parses_json(gen):
    feats = gen.analyze_photo_features(b"\x89PNG\r\n\x1a\nfake")
    assert feats["hair_style"] == "wavy brown"
    assert feats["distinguishing"] == "freckles"
    # vision call made, no Gemini involved
    assert gen._client.chat.completions.calls


def test_analyze_photo_features_failure_returns_empty(gen):
    gen._client = _FakeClient(chat_kwargs={"raise_exc": True})
    assert gen.analyze_photo_features(b"\x89PNG\r\n\x1a\nfake") == {}


def test_analyze_photo_features_empty_photo(gen):
    assert gen.analyze_photo_features(b"") == {}


def test_avatar_service_prefers_openai_when_key_present(monkeypatch):
    """AvatarGenerationService must pick OpenAI as primary, not Gemini."""
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.delenv("REPLICATE_API_TOKEN", raising=False)
    from backend.services.avatar_generation_service import AvatarGenerationService

    svc = AvatarGenerationService()
    assert type(svc.image_generator).__name__ == "OpenAIImageGenerator"
