"""Unit tests for the avatar→superhero transform prompt builder.

Covers the pure `build_superhero_transform_prompt` function — the verifiable
core of Superhero Mode's "turn your character into a superhero" feature
(see docs/superhero-mode-improvement-design-2026-05-31.md, Chunk A).
"""

from backend.gemini_image_generator import build_superhero_transform_prompt


def test_full_selection_includes_all_descriptors():
    prompt = build_superhero_transform_prompt(
        costume_color="red",
        cape_style="rainbow",
        emblem="lightning",
        power="flying",
    )
    assert "bold red" in prompt
    assert "rainbow" in prompt
    assert "lightning bolt" in prompt
    assert "flying" in prompt
    # Likeness + safety guardrails are always present.
    assert "EXACTLY the same" in prompt
    assert "non-photorealistic" in prompt
    assert "non-violent" in prompt


def test_partial_selection_is_graceful():
    # Only a color — no cape/emblem/power. Should still produce a valid prompt.
    prompt = build_superhero_transform_prompt(costume_color="blue")
    assert "bright blue" in prompt
    assert "EXACTLY the same" in prompt
    # No emblem chosen → no chest-emblem clause.
    assert "emblem on the chest" not in prompt


def test_none_selection_uses_safe_defaults():
    prompt = build_superhero_transform_prompt()
    assert prompt  # non-empty
    assert "superhero suit" in prompt
    assert "non-violent" in prompt


def test_power_visual_signature_is_layered_in():
    # feeling_sense has a full visual signature override that must be appended.
    prompt = build_superhero_transform_prompt(power="feeling_sense")
    assert "empathy glow" in prompt


def test_unknown_ids_do_not_raise():
    prompt = build_superhero_transform_prompt(
        costume_color="chartreuse",  # not in the map
        cape_style="bogus",
        emblem="nope",
        power="mystery",
    )
    assert prompt
    assert "superhero suit" in prompt
