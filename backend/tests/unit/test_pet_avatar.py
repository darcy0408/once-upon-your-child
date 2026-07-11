from io import BytesIO
from unittest.mock import MagicMock, patch

# Minimal valid PNG signature + padding so the avatar route's magic-byte
# photo validation (_is_valid_image) accepts the upload.
_VALID_PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32


def test_generate_pet_avatar_route_success(
    client, premium_user_headers, test_user, premium_user_photo_consent
):
    """Test successful pet avatar generation via route."""
    # Mock the avatar service
    with patch("backend.routes.avatar_routes.get_avatar_service") as mock_get_service:
        mock_service = MagicMock()
        mock_service.generate_pet_avatar.return_value = {
            "id": "test-pet-id",
            "image_base64": "data:image/png;base64,fake-data",
            "style": "pixar-pet-custom",
            "attributes": {
                "pet_name": "Buddy",
                "species": "Dog",
                "breed_description": "Golden Retriever",
                "owner_favorite_color": "Blue",
            },
        }
        mock_get_service.return_value = mock_service

        # Prepare multipart form data
        data = {
            "photo": (BytesIO(_VALID_PNG_BYTES), "test.jpg"),
            "pet_name": "Buddy",
            "species": "Dog",
            "breed_description": "Golden Retriever",
            "owner_favorite_color": "Blue",
        }

        response = client.post(
            "/avatar/generate-pet-avatar",
            data=data,
            headers=premium_user_headers,
            content_type="multipart/form-data",
        )

        assert response.status_code == 200
        json_data = response.get_json()
        assert json_data["status"] == "success"
        assert json_data["avatar"]["id"] == "test-pet-id"
        assert "image_base64" in json_data["avatar"]


def test_generate_pet_avatar_route_missing_data(
    client, premium_user_headers, test_user, premium_user_photo_consent
):
    """Test pet avatar generation with missing fields."""
    data = {
        "pet_name": "Buddy"
        # Missing other fields
    }

    response = client.post(
        "/avatar/generate-pet-avatar",
        data=data,
        headers=premium_user_headers,
        content_type="multipart/form-data",
    )

    assert response.status_code == 400
    json_data = response.get_json()
    assert json_data["error_code"] == "MISSING_PHOTO"


def test_avatar_service_pet_generation_logic():
    """Test the AvatarGenerationService logic for pets."""
    from backend.services.avatar_generation_service import AvatarGenerationService

    mock_generator = MagicMock()
    mock_generator.generate_pet_avatar.return_value = [
        {"image_data": "YmFzZTY0ZGF0YQ=="}
    ]  # 'base64data'

    service = AvatarGenerationService(image_generator=mock_generator)

    result = service.generate_pet_avatar(
        pet_name="Buddy",
        species="Dog",
        breed_description="Small white maltese",
        owner_favorite_color="Purple",
        photo_bytes=b"fakebytes",
    )

    assert result["style"] == "pixar-pet-custom"
    assert result["attributes"]["pet_name"] == "Buddy"
    assert "image_base64" in result

    # Verify the generator was called with the right fields
    mock_generator.generate_pet_avatar.assert_called_once()
    args, kwargs = mock_generator.generate_pet_avatar.call_args
    assert kwargs["species"] == "Dog"
    assert kwargs["breed_description"] == "Small white maltese"
    assert kwargs["owner_favorite_color"] == "Purple"
    assert "Magical Pet Avatar Creator" in kwargs["prompt"]


def test_avatar_service_pet_generation_falls_back_when_gemini_fails():
    """Gemini pet failures should trigger the configured text-to-image fallback."""
    from backend.services.avatar_generation_service import AvatarGenerationService

    primary = MagicMock()
    primary.generate_pet_avatar.side_effect = RuntimeError("Gemini unavailable")

    fallback = MagicMock()
    fallback.generate_character_avatar.return_value = [
        {"image_data": "ZmFrZS1mYWxsYmFjay1pbWFnZQ=="}
    ]

    service = AvatarGenerationService(
        image_generator=primary,
        fallback_generator=fallback,
    )

    result = service.generate_pet_avatar(
        pet_name="Luna",
        species="Cat",
        breed_description="Black and white tuxedo cat",
        owner_favorite_color="Purple",
        photo_bytes=b"fakebytes",
    )

    assert result["style"] == "pixar-pet-fallback"
    assert result["provider_used"] == "magicmock"
    assert result["transformation_applied"] is True
    assert result["image_base64"].startswith("data:image/png;base64,")

    fallback.generate_character_avatar.assert_called_once()
    _, kwargs = fallback.generate_character_avatar.call_args
    assert kwargs["character_name"] == "Luna"
    assert kwargs["style"] == "pixar"
    assert kwargs["age"] == 6
    assert kwargs["num_images"] == 1
    assert kwargs["prompt"] == (
        "Pixar-style magical cat, black and white fur, "
        "sparkly eyes, transparent PNG background, 512x512"
    )
