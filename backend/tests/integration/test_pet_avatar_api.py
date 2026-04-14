import pytest
from io import BytesIO
from unittest.mock import MagicMock, patch

@pytest.fixture(autouse=True)
def clear_rate_limits(app):
    """Clear per-user avatar rate limit counters before each test."""
    with app.app_context():
        if hasattr(app, '_avatar_generate_counts'):
            app._avatar_generate_counts.clear()

def test_pet_avatar_api_e2e(client, auth_headers):
    """
    E2E-style test for the pet avatar API route.
    Verifies that the route correctly handles multipart data and returns the expected structure.
    """
    with patch('backend.services.avatar_generation_service.AvatarGenerationService.generate_pet_avatar') as mock_gen:
        # Mock the service response
        mock_gen.return_value = {
            'id': 'magical-pet-123',
            'image_base64': 'data:image/png;base64,YmFzZTY0ZGF0YQ==',
            'style': 'pixar-pet-custom',
            'attributes': {
                'pet_name': 'Luna',
                'species': 'Cat',
                'breed_description': 'Black and white tuxedo',
                'owner_favorite_color': 'Purple'
            },
            'generated_at': '2026-02-20T12:00:00',
            'generation_time_ms': 500,
            'version': 1
        }

        # Simulate the multipart form-data request from the Flutter app
        data = {
            'photo': (BytesIO(b"fake-image-bytes"), 'pet.jpg'),
            'pet_name': 'Luna',
            'species': 'Cat',
            'breed_description': 'Black and white tuxedo',
            'owner_favorite_color': 'Purple'
        }

        response = client.post(
            '/avatar/generate-pet-avatar',
            data=data,
            headers=auth_headers,
            content_type='multipart/form-data'
        )

        # Assertions
        assert response.status_code == 200
        json_resp = response.get_json()
        assert json_resp['status'] == 'success'
        assert json_resp['avatar']['id'] == 'magical-pet-123'
        assert json_resp['avatar']['attributes']['pet_name'] == 'Luna'
        assert 'image_base64' in json_resp['avatar']
        
        # Verify the service was called with the correct arguments
        mock_gen.assert_called_once()
        _, kwargs = mock_gen.call_args
        assert kwargs['pet_name'] == 'Luna'
        assert kwargs['species'] == 'Cat'
        assert kwargs['breed_description'] == 'Black and white tuxedo'
        assert kwargs['owner_favorite_color'] == 'Purple'
        assert isinstance(kwargs['photo_bytes'], bytes)

def test_pet_avatar_api_missing_fields(client, auth_headers):
    """Test error handling for missing metadata fields."""
    data = {
        'photo': (BytesIO(b"bytes"), 'test.jpg'),
        'pet_name': 'Luna'
        # Missing species, breed, color
    }

    response = client.post(
        '/avatar/generate-pet-avatar',
        data=data,
        headers=auth_headers,
        content_type='multipart/form-data'
    )

    assert response.status_code == 400
    json_resp = response.get_json()
    assert json_resp['error_code'] == 'MISSING_DATA'
    assert 'required' in json_resp['message']


def test_pet_avatar_api_returns_partial_success_for_original_photo_fallback(client, auth_headers):
    """Returning the original pet photo should surface as HTTP 206 with provider metadata."""
    with patch('backend.services.avatar_generation_service.AvatarGenerationService.generate_pet_avatar') as mock_gen:
        mock_gen.return_value = {
            'id': 'pet-original-123',
            'image_base64': 'data:image/jpeg;base64,YmFzZTY0ZGF0YQ==',
            'style': 'pet-photo-original',
            'attributes': {
                'pet_name': 'Luna',
                'species': 'Cat',
                'breed_description': 'Black and white tuxedo',
                'owner_favorite_color': 'Purple'
            },
            'generated_at': '2026-03-14T12:00:00',
            'generation_time_ms': 120,
            'version': 1,
            'provider_used': 'original-photo',
            'transformation_applied': False,
        }

        data = {
            'photo': (BytesIO(b"fake-image-bytes"), 'pet.jpg'),
            'pet_name': 'Luna',
            'species': 'Cat',
            'breed_description': 'Black and white tuxedo',
            'owner_favorite_color': 'Purple'
        }

        response = client.post(
            '/avatar/generate-pet-avatar',
            data=data,
            headers=auth_headers,
            content_type='multipart/form-data'
        )

        assert response.status_code == 206
        json_resp = response.get_json()
        assert json_resp['status'] == 'success'
        assert json_resp['provider_used'] == 'original-photo'
        assert json_resp['transformation_applied'] is False
        assert json_resp['avatar']['style'] == 'pet-photo-original'
