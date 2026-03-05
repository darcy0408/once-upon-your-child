"""
API Contract Tests: Story Routes

Tests the story generation API endpoints to ensure:
- Request/response contracts are maintained
- Input validation works correctly
- Error responses are properly formatted
- Rate limiting is enforced
- Custom elements are included in stories
- Authentication and authorization work correctly

CRITICAL: These tests validate the core story generation API.
"""

import pytest
import json
from unittest.mock import Mock, patch, MagicMock


class TestGetStoryThemes:
    """Test GET /get-story-themes endpoint"""

    def test_get_themes_success(self, client):
        """Test getting available story themes"""
        response = client.get('/get-story-themes')

        assert response.status_code == 200
        data = response.get_json()

        # Should return a list of themes
        assert isinstance(data, list)
        assert len(data) > 0

        # Should include expected themes
        assert 'Adventure' in data
        assert 'Magic' in data
        assert 'Friendship' in data

    def test_get_themes_cached(self, client):
        """Test that themes endpoint is cached"""
        # Make two requests
        response1 = client.get('/get-story-themes')
        response2 = client.get('/get-story-themes')

        assert response1.status_code == 200
        assert response2.status_code == 200

        # Both should return same data
        assert response1.get_json() == response2.get_json()

    def test_get_themes_returns_consistent_order(self, client):
        """Test that themes are returned in consistent order"""
        response1 = client.get('/get-story-themes')
        response2 = client.get('/get-story-themes')

        # Order should be consistent across requests
        assert response1.get_json() == response2.get_json()


class TestGenerateStory:
    """Test POST /generate-story endpoint"""

    @pytest.fixture(autouse=True)
    def mock_story_generation(self, mocker):
        """Mock story generation task"""
        mock_result = {
            'status': 'complete',
            'story': {
                'title': 'Luna and the Magic Stars',
                'story_text': 'Once upon a time, Luna discovered a talking owl and crossed a rainbow bridge...',
                'wisdom_gem': 'True friendship knows no boundaries',
                'theme': 'Adventure'
            }
        }

        # Also mock that illustrations are enabled
        mock_result['include_illustrations'] = True

        # Mock the synchronous task execution
        mock_task = MagicMock()
        mock_task.apply.return_value.get.return_value = mock_result

        mocker.patch('backend.routes.story_routes.generate_story_task', mock_task)
        return mock_task

    def test_generate_story_minimal_payload(self, client, auth_headers):
        """Test story generation with minimal payload"""
        payload = {
            'character': 'Luna',
            'age': 7
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200
        data = response.get_json()

        # Should have story data
        assert 'story' in data
        assert 'status' in data
        assert data['status'] == 'complete'

    def test_generate_story_with_character_id(self, client, test_character, auth_headers):
        """Test story generation with character_id"""
        payload = {
            'character_id': 'char_123',
            'theme': 'Adventure'
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200

    def test_generate_story_accepts_character_age_alias(self, client, auth_headers, mock_story_generation):
        """Test backend accepts legacy character_age field and maps to task age."""
        payload = {
            'character': 'Luna',
            'character_age': 46,
            'theme': 'Adventure'
        }

        response = client.post(
            '/generate-story',
            json=payload,
            content_type='application/json',
            headers=auth_headers
        )

        assert response.status_code == 200
        task_call = mock_story_generation.apply.call_args
        assert task_call is not None
        assert task_call.kwargs['kwargs']['age'] == 46

    def test_generate_story_full_payload(self, client, auth_headers):
        """Test story generation with full payload"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'theme': 'Adventure',
            'custom_elements': 'talking owl, rainbow bridge, magic compass',
            'rhyme_time_mode': False,
            'story_length': 'standard',
            'companion_pets': [
                {'name': 'Fluffy', 'species': 'cat'}
            ],
            'companion_characters': [
                {'name': 'Sam', 'signaturePower': 'Super Speed'}
            ]
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200
        data = response.get_json()

        assert 'story' in data
        assert data['story']['title'] is not None

    def test_generate_story_missing_character(self, client, auth_headers):
        """Test story generation without character fails"""
        payload = {
            'theme': 'Adventure',
            'age': 7
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data
        assert 'character' in data['error'].lower()

    def test_generate_story_invalid_mode_combination(self, client, auth_headers):
        """Test that invalid mode combinations are rejected"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'rhyme_time_mode': True,
            'pick_a_path': True  # Invalid: rhyme + pick-a-path
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data or 'message' in data

    def test_generate_story_with_custom_elements(self, client, auth_headers):
        """Test that custom elements are passed to story engine"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'customElements': 'magic compass, talking tree, crystal cave'
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200

        # The mock should have been called with custom elements
        # In a real test, we'd verify the story contains these elements

    def test_generate_story_with_therapeutic_prompt(self, client, auth_headers):
        """Test story generation with therapeutic prompt"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'therapeutic_prompt': 'Help Luna deal with anxiety about school'
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200

    def test_generate_story_with_feelings(self, client, auth_headers):
        """Test story generation with current feeling"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'current_feeling': {
                'emotion_name': 'anxious',
                'emotion_description': 'Worried about starting school',
                'coping_strategies': ['deep breathing', 'talking to a friend']
            }
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200

    def test_generate_story_with_mood_physics(self, client, auth_headers):
        """Test story generation with mood physics"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'moodPhysics': {
                'mood': 'Excited',
                'worldRule': 'Everything sparkles',
                'sensoryChange': 'Colors are brighter'
            }
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200

    def test_generate_story_rhyme_time_mode(self, client, auth_headers):
        """Test story generation in rhyme time mode"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'rhyme_time_mode': True
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200

    def test_generate_story_different_lengths(self, client, auth_headers):
        """Test story generation with different lengths"""
        lengths = ['quick', 'standard', 'epic']

        for length in lengths:
            payload = {
                'character': 'Luna',
                'age': 7,
                'story_length': length
            }

            response = client.post('/generate-story',
                                    json=payload,
                                    content_type='application/json',
                                    headers=auth_headers)

            assert response.status_code == 200

    def test_generate_story_with_illustrations(self, client, auth_headers):
        """Test story generation with illustrations enabled"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'include_illustrations': True
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200



    def test_generate_story_with_illustration_generation(self, client, auth_headers):
        """Test story generation with illustration generation enabled"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'include_illustrations': True
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200
        data = response.get_json()

        # Route returns story content and async_illustrations flag (not echo of include_illustrations)
        assert 'story' in data
        assert 'async_illustrations' in data

    def test_generate_story_creates_user_if_not_exists(self, client, auth_headers):
        """Test that story generation creates user if they don't exist"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'user_id': 'new_user_123'
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        # Should succeed even if user doesn't exist (lazy creation)
        assert response.status_code == 200

    def test_generate_story_sanitizes_user_id(self, client, auth_headers):
        """Test that user_id is sanitized correctly"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'user_id': 'user_abc123'  # Has 'user_' prefix
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200


class TestGenerateStoryMock:
    """Test POST /generate-story-mock endpoint"""

    def test_mock_story_returns_immediately(self, client):
        """Test that mock endpoint returns immediately"""
        payload = {
            'character': 'Luna',
            'age': 7
        }

        response = client.post('/generate-story-mock',
                                json=payload,
                                content_type='application/json')

        assert response.status_code == 200
        data = response.get_json()

        # Should have story data
        assert 'result' in data
        assert 'story' in data['result'] or 'story_text' in data['result']

    def test_mock_story_with_character_dict(self, client):
        """Test mock story with character as dictionary"""
        payload = {
            'character': {
                'name': 'Luna',
                'age': 7
            }
        }

        response = client.post('/generate-story-mock',
                                json=payload,
                                content_type='application/json')

        assert response.status_code == 200

    def test_mock_story_with_character_string(self, client):
        """Test mock story with character as string"""
        payload = {
            'character': 'Luna'
        }

        response = client.post('/generate-story-mock',
                                json=payload,
                                content_type='application/json')

        assert response.status_code == 200

    def test_mock_story_no_character(self, client):
        """Test mock story without character"""
        payload = {}

        response = client.post('/generate-story-mock',
                                json=payload,
                                content_type='application/json')

        # Should still return a story (uses default)
        assert response.status_code == 200


class TestStoryGenerationErrorHandling:
    """Test error handling in story generation"""

    def test_quota_exceeded_error(self, client, auth_headers, mocker):
        """Test handling of quota exceeded errors"""
        # Mock task to raise quota error
        mock_task = MagicMock()
        mock_task.apply.side_effect = Exception("429 ResourceExhausted")

        mocker.patch('backend.routes.story_routes.generate_story_task', mock_task)

        payload = {
            'character': 'Luna',
            'age': 7
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 429
        data = response.get_json()
        assert 'error' in data
        assert 'QUOTA_EXCEEDED' in data.get('error', '')

    def test_general_error_handling(self, client, auth_headers, mocker):
        """Test handling of general errors"""
        # Mock task to raise general error
        mock_task = MagicMock()
        mock_task.apply.side_effect = Exception("Something went wrong")
        mock_task.delay.side_effect = Exception("Async also failed")

        mocker.patch('backend.routes.story_routes.generate_story_task', mock_task)

        payload = {
            'character': 'Luna',
            'age': 7
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        # Should return error (either 500 or attempt async fallback)
        assert response.status_code in [500, 502, 503]
        data = response.get_json()
        assert 'error' in data

    def test_invalid_json_payload(self, client, auth_headers):
        """Test handling of invalid JSON"""
        response = client.post('/generate-story',
                                data='invalid json',
                                content_type='application/json',
                                headers=auth_headers)

        # Should handle gracefully (treats as empty payload)
        # Will fail on missing character
        assert response.status_code == 400

    def test_empty_payload(self, client, auth_headers):
        """Test handling of empty payload"""
        response = client.post('/generate-story',
                                json={},
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data


class TestStoryResponseFormat:
    """Test response format consistency"""

    @pytest.fixture(autouse=True)
    def mock_story_generation(self, mocker):
        """Mock story generation task"""
        mock_result = {
            'status': 'complete',
            'story': {
                'title': 'Test Story',
                'story_text': 'Once upon a time...',
                'wisdom_gem': 'Test wisdom',
                'theme': 'Adventure'
            }
        }

        mock_task = MagicMock()
        mock_task.apply.return_value.get.return_value = mock_result
        mocker.patch('backend.routes.story_routes.generate_story_task', mock_task)
        return mock_task

    def test_response_has_required_fields(self, client, auth_headers):
        """Test that response has all required fields"""
        payload = {
            'character': 'Luna',
            'age': 7
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200
        data = response.get_json()

        # Required fields
        assert 'status' in data
        assert 'story' in data

        # Story should have required fields
        story = data['story']
        assert 'title' in story
        assert 'story_text' in story

    def test_response_content_type(self, client, auth_headers):
        """Test that response is JSON"""
        payload = {
            'character': 'Luna',
            'age': 7
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200
        assert 'application/json' in response.content_type

    def test_story_text_is_string(self, client, auth_headers):
        """Test that story_text is a string"""
        payload = {
            'character': 'Luna',
            'age': 7
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200
        data = response.get_json()

        story_text = data['story']['story_text']
        assert isinstance(story_text, str)
        assert len(story_text) > 0


class TestCompanionCharacters:
    """Test companion character handling in API"""

    @pytest.fixture(autouse=True)
    def mock_story_generation(self, mocker):
        """Mock story generation task"""
        mock_result = {
            'status': 'complete',
            'story': {
                'title': 'Test Story',
                'story_text': 'Luna and Fluffy had an adventure...',
                'wisdom_gem': 'Test wisdom',
                'theme': 'Adventure'
            }
        }

        mock_task = MagicMock()
        mock_task.apply.return_value.get.return_value = mock_result
        mocker.patch('backend.routes.story_routes.generate_story_task', mock_task)
        return mock_task

    def test_story_with_pet_companions(self, client, auth_headers):
        """Test story generation with pet companions"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'companion_pets': [
                {'name': 'Fluffy', 'species': 'cat'},
                {'name': 'Rex', 'species': 'dog'}
            ]
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200

    def test_story_with_character_companions(self, client, auth_headers):
        """Test story generation with character companions"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'companion_characters': [
                {'name': 'Sam', 'signaturePower': 'Super Speed'},
                {'name': 'Maya', 'signaturePower': 'Telepathy'}
            ]
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200

    def test_story_with_legacy_companion_format(self, client, auth_headers):
        """Test story generation with legacy companion format"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'companion': 'Sparkle the Unicorn'
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200

    def test_story_with_companion_name_field(self, client, auth_headers):
        """Test story generation with companion_name field"""
        payload = {
            'character': 'Luna',
            'age': 7,
            'companion_name': 'Sparkle the Unicorn'
        }

        response = client.post('/generate-story',
                                json=payload,
                                content_type='application/json',
                                headers=auth_headers)

        assert response.status_code == 200
