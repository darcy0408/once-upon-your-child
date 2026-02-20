import pytest
from io import BytesIO
from unittest.mock import MagicMock, patch

def test_generate_pet_avatar_route_success(client, auth_headers):
    """Test successful pet avatar generation via route."""
    # Mock the avatar service
    with patch('backend.routes.avatar_routes.get_avatar_service') as mock_get_service:
        mock_service = MagicMock()
        mock_service.generate_pet_avatar.return_value = {
            'id': 'test-pet-id',
            'image_base64': 'data:image/png;base64,fake-data',
            'style': 'pixar-pet-custom',
            'attributes': {
                'pet_name': 'Buddy',
                'species': 'Dog',
                'breed_description': 'Golden Retriever',
                'owner_favorite_color': 'Blue'
            }
        }
        mock_get_service.return_value = mock_service

        # Prepare multipart form data
        data = {
            'photo': (BytesIO(b"fake image data"), 'test.jpg'),
            'pet_name': 'Buddy',
            'species': 'Dog',
            'breed_description': 'Golden Retriever',
            'owner_favorite_color': 'Blue'
        }

        response = client.post(
            '/avatar/generate-pet-avatar',
            data=data,
            headers=auth_headers,
            content_type='multipart/form-data'
        )

        assert response.status_code == 200
        json_data = response.get_json()
        assert json_data['status'] == 'success'
        assert json_data['avatar']['id'] == 'test-pet-id'
        assert 'image_base64' in json_data['avatar']

def test_generate_pet_avatar_route_missing_data(client, auth_headers):
    """Test pet avatar generation with missing fields."""
    data = {
        'pet_name': 'Buddy'
        # Missing other fields
    }

    response = client.post(
        '/avatar/generate-pet-avatar',
        data=data,
        headers=auth_headers,
        content_type='multipart/form-data'
    )

    assert response.status_code == 400
    json_data = response.get_json()
    assert json_data['error_code'] == 'MISSING_PHOTO'

def test_avatar_service_pet_generation_logic():
    """Test the AvatarGenerationService logic for pets."""
    from backend.services.avatar_generation_service import AvatarGenerationService
    
    mock_generator = MagicMock()
    mock_generator.generate_pet_avatar.return_value = [{'image_data': 'YmFzZTY0ZGF0YQ=='}] # 'base64data'
    
    service = AvatarGenerationService(image_generator=mock_generator)
    
    result = service.generate_pet_avatar(
        pet_name="Buddy",
        species="Dog",
        breed_description="Small white maltese",
        owner_favorite_color="Purple",
        photo_bytes=b"fakebytes"
    )
    
    assert result['style'] == 'pixar-pet-custom'
    assert result['attributes']['pet_name'] == 'Buddy'
    assert 'image_base64' in result
    
    # Verify the generator was called with the right fields
    mock_generator.generate_pet_avatar.assert_called_once()
    args, kwargs = mock_generator.generate_pet_avatar.call_args
    assert kwargs['species'] == 'Dog'
    assert kwargs['breed_description'] == 'Small white maltese'
    assert kwargs['owner_favorite_color'] == 'Purple'
    assert "Magical Pet Avatar Creator v1" in kwargs['prompt']
