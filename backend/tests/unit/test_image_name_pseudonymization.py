"""Tests for MT-311#16 — child name pseudonymization in image vendor calls.

Verifies that the child's real name never reaches image-generation vendors
(OpenAI, Cloudflare, Replicate, OpenRouter).  Image generators produce pixels,
not text, so the name is cosmetic PII that vendors don't need.
"""


class TestAvatarPromptPseudonymization:
    """Avatar prompts must NOT contain the child's real name."""

    def test_avatar_prompt_excludes_real_name(self):
        """build_avatar_prompt() must not embed the child's real name."""
        from backend.services.avatar_prompt_service import AvatarPromptService

        real_name = "Emma"
        prompt = AvatarPromptService.build_avatar_prompt(
            character_name=real_name,
            age=7,
            style="pixar",
            features={"hair_style": "long", "skin_tone": "light"},
        )
        assert (
            real_name not in prompt
        ), f"Child's real name '{real_name}' leaked into avatar prompt"
        # Should use the generic label instead.
        assert "the character" in prompt

    def test_avatar_prompt_excludes_unusual_name(self):
        """Even unusual names must not leak."""
        from backend.services.avatar_prompt_service import AvatarPromptService

        real_name = "Xiomara-Rose"
        prompt = AvatarPromptService.build_avatar_prompt(
            character_name=real_name,
            age=12,
            style="watercolor",
        )
        assert real_name not in prompt

    def test_avatar_prompt_still_includes_age(self):
        """Age is NOT PII in this context and should remain in the prompt."""
        from backend.services.avatar_prompt_service import AvatarPromptService

        prompt = AvatarPromptService.build_avatar_prompt(
            character_name="Liam",
            age=9,
            style="pixar",
        )
        assert "9-year-old" in prompt

    def test_character_seed_still_uses_real_name(self):
        """The local hash seed should still use the real name (never sent to a
        vendor — it's a local deterministic seed for reproducibility)."""
        from backend.services.avatar_prompt_service import AvatarPromptService

        seed_a = AvatarPromptService.generate_character_seed(
            "Emma", 7, {"hair_style": "long"}
        )
        seed_b = AvatarPromptService.generate_character_seed(
            "Liam", 7, {"hair_style": "long"}
        )
        # Different names → different seeds (the seed IS name-dependent, by design).
        assert seed_a != seed_b


class TestIllustrationCacheKeyPreservation:
    """Cache keys must still use the original character_name so re-reads hit cache."""

    def test_cache_key_differs_by_character_name(self):
        """Two different children reading the same scene get different cache keys."""
        from backend.services.illustration_cache_service import compute_cache_key

        key_emma = compute_cache_key(
            scene_description="A sunny meadow",
            character_name="Emma",
            style="children's book illustration",
            age=7,
        )
        key_liam = compute_cache_key(
            scene_description="A sunny meadow",
            character_name="Liam",
            style="children's book illustration",
            age=7,
        )
        assert key_emma != key_liam, (
            "Cache keys must differ by character_name so each child's re-read "
            "hits their own cached image."
        )

    def test_cache_key_stable_for_same_inputs(self):
        """Same inputs → same key (idempotent)."""
        from backend.services.illustration_cache_service import compute_cache_key

        key1 = compute_cache_key(
            scene_description="A sunny meadow",
            character_name="Emma",
            style="children's book illustration",
            age=7,
        )
        key2 = compute_cache_key(
            scene_description="A sunny meadow",
            character_name="Emma",
            style="children's book illustration",
            age=7,
        )
        assert key1 == key2


class TestInteractiveAdventureImagePseudonymization:
    """Interactive adventure illustration path must not leak the real name."""

    def test_illustration_uses_safe_name(self):
        """_generate_segment_illustration should pass 'the hero' to the image
        generator, not the child's real name."""
        from unittest.mock import MagicMock

        from backend.services.interactive_adventure_service import (
            InteractiveAdventureService,
        )

        mock_generator = MagicMock()
        mock_generator.generate_story_illustration.return_value = [
            {"image_data": "fake_base64", "image_url": ""}
        ]

        service = InteractiveAdventureService.__new__(InteractiveAdventureService)
        service.image_generator = mock_generator
        service.logger = MagicMock()

        # Create a minimal segment
        segment = MagicMock()
        segment.image_description = "A castle on a hill"
        segment.id = "seg-1"

        character_dict = {"name": "Emma", "age": 7}

        service._generate_segment_illustration(
            segment=segment,
            character_dict=character_dict,
            companions=[],
            age=7,
        )

        # The image generator should have been called with "the hero", not "Emma".
        call_kwargs = mock_generator.generate_story_illustration.call_args
        assert call_kwargs is not None, "Image generator was not called"
        passed_name = call_kwargs.kwargs.get("character_name") or call_kwargs[1].get(
            "character_name"
        )
        assert passed_name == "the hero", (
            f"Expected 'the hero' but got '{passed_name}' — "
            "child's real name leaked to image vendor"
        )
