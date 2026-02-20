import base64
from unittest.mock import MagicMock

import pytest

from backend.services.avatar_generation_service import AvatarGenerationService, get_error_message


class TestAvatarGenerationService:
    def test_generate_avatar_rejects_invalid_inputs(self):
        service = AvatarGenerationService(image_generator=MagicMock(), fallback_generator=MagicMock())

        with pytest.raises(ValueError, match="Character name is required"):
            service.generate_avatar(character_name="", age=8)

        with pytest.raises(ValueError, match="Age must be between 3 and 17"):
            service.generate_avatar(character_name="Luna", age=2)

        with pytest.raises(ValueError, match="Invalid style"):
            service.generate_avatar(character_name="Luna", age=8, style="oil")

    def test_generate_avatar_requires_generator(self):
        service = AvatarGenerationService(image_generator=MagicMock(), fallback_generator=MagicMock())
        service.image_generator = None
        service.fallback_generator = None

        with pytest.raises(Exception, match="No image generator available"):
            service.generate_avatar(character_name="Luna", age=8)

    def test_generate_avatar_success(self):
        service = AvatarGenerationService(image_generator=MagicMock(), fallback_generator=MagicMock())
        service.prompt_service = MagicMock()
        service.prompt_service.generate_character_seed.return_value = "seed_123"
        service.prompt_service.build_avatar_prompt.return_value = "safe prompt"
        service.prompt_service.validate_prompt_safety.return_value = (True, "ok")
        service._generate_image_with_gemini = MagicMock(return_value=b"fake_image_bytes")
        service._verify_non_photorealistic = MagicMock(return_value=True)

        result = service.generate_avatar(
            character_name="Luna",
            age=8,
            style="pixar",
            features={"hair_color": "brown"},
        )

        assert result["seed"] == "seed_123"
        assert result["style"] == "pixar"
        assert result["attributes"] == {"hair_color": "brown"}
        assert result["image_base64"] == "data:image/png;base64," + base64.b64encode(b"fake_image_bytes").decode("utf-8")
        assert result["version"] == 1

    def test_generate_avatar_retries_after_failed_verification(self):
        service = AvatarGenerationService(image_generator=MagicMock(), fallback_generator=MagicMock())
        service.prompt_service = MagicMock()
        service.prompt_service.generate_character_seed.return_value = "seed_abc"
        service.prompt_service.build_avatar_prompt.return_value = "safe prompt"
        service.prompt_service.validate_prompt_safety.return_value = (True, "ok")
        service._generate_image_with_gemini = MagicMock(return_value=b"fake_image_bytes")
        service._verify_non_photorealistic = MagicMock(side_effect=[False, True])

        result = service.generate_avatar(character_name="Kai", age=9, style="cartoon")

        assert result["style"] == "cartoon"
        assert service._generate_image_with_gemini.call_count == 2
        assert service._verify_non_photorealistic.call_count == 2

    def test_generate_image_with_gemini_falls_back_to_openrouter(self):
        primary = MagicMock()
        primary.generate_character_avatar.side_effect = Exception("primary failed")
        fallback = MagicMock()
        fallback.generate_character_avatar.return_value = [{"image_data": "aGVsbG8="}]
        service = AvatarGenerationService(image_generator=primary, fallback_generator=fallback)

        image_bytes = service._generate_image_with_gemini(
            prompt="draw",
            character_name="Luna",
            age=8,
            style="pixar",
        )

        assert image_bytes == b"hello"
        primary.generate_character_avatar.assert_called_once()
        fallback.generate_character_avatar.assert_called_once()

    def test_fallback_avatar_catalog_and_error_messages(self):
        service = AvatarGenerationService(image_generator=MagicMock(), fallback_generator=MagicMock())
        avatars = service.get_fallback_avatars()
        pixar_only = service.get_fallback_avatars(style="pixar")

        assert len(avatars) == 8
        assert len(pixar_only) == 2
        assert get_error_message("invalid_style")
        assert "Something magical went wrong" in get_error_message("unknown_code")
