"""Custom-avatar prompt stylization coverage.

Owner report (2026-07-15): generated "magical avatars" came out looking like
lightly filtered photos — too realistic, not cartoony — because gpt-image-2's
edit path preserves input-photo fidelity and the v4 prompt's likeness
instructions outweighed its style instructions. The fix adds a per-band
``stylization`` directive (strong "FULLY cartoon" for Sprout/Explorer, scaling
down to "painterly illustration" for 15+) and an anti-photoreal register line.

These tests pin: every band carries the new keys, the assembled prompt
contains the band-appropriate stylization language, and — because
``generate_custom_avatar`` validates the fully assembled prompt against the
unsafe-content blocklist and raises on failure — that the new wording never
trips the safety validator.
"""

from unittest.mock import MagicMock

import pytest

from backend.services.avatar_generation_service import AvatarGenerationService


def _prompt_for_age(age: int) -> str:
    """Run a mocked custom-avatar generation and capture the assembled prompt."""
    gen = MagicMock()
    gen.generate_custom_avatar.return_value = [{"image_data": "YmFzZTY0ZGF0YQ=="}]
    service = AvatarGenerationService(image_generator=gen)

    service.generate_custom_avatar(
        character_name="Test Hero",
        age=age,
        gender="girl",
        eye_color="brown",
        favorite_color="blue",
        photo_bytes=b"fakebytes",
    )

    _, kwargs = gen.generate_custom_avatar.call_args
    return kwargs["prompt"]


@pytest.mark.parametrize("age", [3, 4, 7, 10, 13, 16, 30])
def test_every_band_has_stylization_keys(age):
    band_style = AvatarGenerationService._hero_style_for_age(age)
    assert band_style["stylization"], f"missing stylization for age {age}"
    assert band_style[
        "stylization_register"
    ], f"missing stylization_register for age {age}"


@pytest.mark.parametrize("age", [3, 4, 7, 10, 13, 16, 30])
def test_prompt_carries_anti_photoreal_register(age):
    prompt = _prompt_for_age(age)
    assert "NOT a retouched, filtered, or beautified photograph" in prompt
    assert "Stylization Strength:" in prompt


def test_explorer_prompt_demands_full_cartoon():
    prompt = _prompt_for_age(7)
    assert "FULLY cartoon" in prompt
    assert "ZERO photographic texture" in prompt
    assert "a frame from a Pixar-style animated film" in prompt


def test_sprout_prompt_demands_picture_book_style():
    prompt = _prompt_for_age(4)
    assert "FULLY cartoon" in prompt
    assert "picture book" in prompt


def test_adult_prompt_stays_painterly_not_cartoon():
    """15+ keeps its 'stylized realistic' direction — the strong cartoon
    directive must never leak into the older bands."""
    prompt = _prompt_for_age(30)
    assert "FULLY cartoon" not in prompt
    assert "a painted character illustration" in prompt
