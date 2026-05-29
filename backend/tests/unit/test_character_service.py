"""
Comprehensive unit tests for Character Service

Tests cover:
- Character creation (CRUD operations)
- Validation (age, required fields)
- Sanitization (text inputs, pets, personality sliders)
- Personality slider clamping (0-100 range)
- List conversion (_as_list helper)
- Pet data sanitization
- Character updates (partial updates)
- Error handling
"""

from unittest.mock import Mock, patch

import pytest

from backend.services import character_service
from backend.services.character_service import (
    PERSONALITY_SLIDER_DEFINITIONS,
    _as_list,
    _clamp_slider_value,
    _sanitize_personality_sliders,
    _sanitize_pets,
)


class TestSliderValueClamping:
    """Test personality slider value clamping logic"""

    def test_clamp_valid_int(self):
        """Test clamping valid integer values"""
        assert _clamp_slider_value(50) == 50
        assert _clamp_slider_value(0) == 0
        assert _clamp_slider_value(100) == 100

    def test_clamp_out_of_range_positive(self):
        """Test clamping values above 100"""
        assert _clamp_slider_value(150) == 100
        assert _clamp_slider_value(200) == 100
        assert _clamp_slider_value(999) == 100

    def test_clamp_out_of_range_negative(self):
        """Test clamping negative values"""
        assert _clamp_slider_value(-1) == 0
        assert _clamp_slider_value(-50) == 0
        assert _clamp_slider_value(-999) == 0

    def test_clamp_float_values(self):
        """Test clamping float values (should round)"""
        assert _clamp_slider_value(50.4) == 50
        assert _clamp_slider_value(50.6) == 51
        assert _clamp_slider_value(99.9) == 100

    def test_clamp_string_numbers(self):
        """Test clamping string representations of numbers"""
        assert _clamp_slider_value("50") == 50
        assert _clamp_slider_value("100") == 100
        assert _clamp_slider_value("0") == 0

    def test_clamp_invalid_string(self):
        """Test handling of invalid strings"""
        assert _clamp_slider_value("abc") is None
        assert _clamp_slider_value("") is None
        assert _clamp_slider_value("fifty") is None

    def test_clamp_none(self):
        """Test handling of None"""
        assert _clamp_slider_value(None) is None

    def test_clamp_invalid_types(self):
        """Test handling of invalid types"""
        assert _clamp_slider_value([]) is None
        assert _clamp_slider_value({}) is None
        # Note: bool is subclass of int in Python, so True/False are treated as 1/0
        assert _clamp_slider_value(True) == 1  # True is treated as 1
        assert _clamp_slider_value(False) == 0  # False is treated as 0


class TestPersonalitySliderSanitization:
    """Test personality slider dictionary sanitization"""

    def test_sanitize_valid_sliders(self):
        """Test sanitizing valid slider values"""
        raw_sliders = {
            "organization_planning": 75,
            "assertiveness": 50,
            "sociability": 90,
        }

        result = _sanitize_personality_sliders(raw_sliders)

        assert result["organization_planning"] == 75
        assert result["assertiveness"] == 50
        assert result["sociability"] == 90

    def test_sanitize_clamps_out_of_range(self):
        """Test that out-of-range values are clamped"""
        raw_sliders = {"organization_planning": 150, "assertiveness": -10}

        result = _sanitize_personality_sliders(raw_sliders)

        assert result["organization_planning"] == 100
        assert result["assertiveness"] == 0

    def test_sanitize_ignores_invalid_keys(self):
        """Test that unknown slider keys are ignored"""
        raw_sliders = {
            "organization_planning": 75,
            "invalid_key": 50,
            "another_bad_key": 100,
        }

        result = _sanitize_personality_sliders(raw_sliders)

        assert "organization_planning" in result
        assert "invalid_key" not in result
        assert "another_bad_key" not in result

    def test_sanitize_ignores_invalid_values(self):
        """Test that invalid values are filtered out"""
        raw_sliders = {
            "organization_planning": 75,
            "assertiveness": "invalid",
            "sociability": None,
        }

        result = _sanitize_personality_sliders(raw_sliders)

        assert "organization_planning" in result
        assert "assertiveness" not in result
        assert "sociability" not in result

    def test_sanitize_empty_dict(self):
        """Test sanitizing empty dictionary"""
        result = _sanitize_personality_sliders({})
        assert result == {}

    def test_sanitize_none(self):
        """Test sanitizing None"""
        result = _sanitize_personality_sliders(None)
        assert result == {}

    def test_sanitize_non_dict(self):
        """Test sanitizing non-dict input"""
        assert _sanitize_personality_sliders([]) == {}
        assert _sanitize_personality_sliders("string") == {}
        assert _sanitize_personality_sliders(123) == {}


class TestListConversion:
    """Test _as_list helper function"""

    def test_as_list_from_list(self):
        """Test converting list to list"""
        result = _as_list(["reading", "astronomy", "adventure"])
        assert result == ["reading", "astronomy", "adventure"]

    def test_as_list_from_comma_string(self):
        """Test converting comma-separated string to list"""
        result = _as_list("reading, astronomy, adventure")
        assert result == ["reading", "astronomy", "adventure"]

    def test_as_list_from_json_string(self):
        """Test converting JSON string to list"""
        result = _as_list('["reading", "astronomy", "adventure"]')
        assert result == ["reading", "astronomy", "adventure"]

    def test_as_list_from_none(self):
        """Test converting None to empty list"""
        result = _as_list(None)
        assert result == []

    def test_as_list_from_empty_string(self):
        """Test converting empty string to empty list"""
        result = _as_list("")
        assert result == []

    def test_as_list_from_empty_list(self):
        """Test converting empty list to empty list"""
        result = _as_list([])
        assert result == []

    def test_as_list_single_item(self):
        """Test converting single item to list"""
        result = _as_list("reading")
        assert result == ["reading"]

    def test_as_list_trims_whitespace(self):
        """Test that whitespace is trimmed"""
        result = _as_list("  reading  ,  astronomy  ")
        assert result == ["reading", "astronomy"]

    def test_as_list_filters_empty_items(self):
        """Test that empty items are filtered"""
        result = _as_list("reading,  ,astronomy, ,")
        assert result == ["reading", "astronomy"]


class TestPetSanitization:
    """Test pet data sanitization"""

    def test_sanitize_valid_pets(self):
        """Test sanitizing valid pet data"""
        pets_data = [
            {"name": "Fluffy", "species": "cat", "color": "orange"},
            {"name": "Rex", "species": "dog", "color": "brown"},
        ]

        result = _sanitize_pets(pets_data)

        assert len(result) == 2
        assert result[0]["name"] == "Fluffy"
        assert result[0]["species"] == "cat"
        assert result[1]["name"] == "Rex"

    def test_sanitize_pets_with_numeric_fields(self):
        """Test pets with numeric fields"""
        pets_data = [{"name": "Goldie", "species": "fish", "age": 2}]

        result = _sanitize_pets(pets_data)

        assert len(result) == 1
        assert result[0]["name"] == "Goldie"
        assert result[0]["age"] == 2

    def test_sanitize_pets_with_boolean_fields(self):
        """Test pets with boolean fields"""
        pets_data = [{"name": "Fluffy", "species": "cat", "friendly": True}]

        result = _sanitize_pets(pets_data)

        assert len(result) == 1
        assert result[0]["friendly"] is True

    def test_sanitize_pets_filters_invalid_types(self):
        """Test that invalid field types are filtered"""
        pets_data = [{"name": "Fluffy", "species": "cat", "invalid": ["list"]}]

        result = _sanitize_pets(pets_data)

        assert "name" in result[0]
        assert "species" in result[0]
        assert "invalid" not in result[0]

    def test_sanitize_pets_empty_list(self):
        """Test sanitizing empty list"""
        result = _sanitize_pets([])
        assert result == []

    def test_sanitize_pets_none(self):
        """Test sanitizing None"""
        result = _sanitize_pets(None)
        assert result == []

    def test_sanitize_pets_non_dict_items(self):
        """Test that non-dict items are filtered"""
        pets_data = [
            {"name": "Fluffy", "species": "cat"},
            "invalid string",
            123,
            ["invalid", "list"],
        ]

        result = _sanitize_pets(pets_data)

        assert len(result) == 1
        assert result[0]["name"] == "Fluffy"

    def test_sanitize_pets_max_length(self):
        """Test that text fields respect max_length"""
        long_string = "a" * 300  # Exceeds 200 char limit
        pets_data = [{"name": long_string, "species": "cat"}]

        result = _sanitize_pets(pets_data)

        assert len(result[0]["name"]) <= 200


class TestCreateCharacter:
    """Test character creation"""

    @pytest.fixture
    def mock_repository(self):
        """Mock character repository"""
        with patch("backend.services.character_service.character_repository") as mock:
            mock.add_character = Mock()
            yield mock

    def test_create_character_minimal(self, mock_repository):
        """Test creating character with minimal data"""
        data = {"name": "Luna", "age": 7}

        result, status = character_service.create_character(data)

        assert status == 201
        assert result["name"] == "Luna"
        assert result["age"] == 7
        assert "id" in result

    def test_create_character_full_data(self, mock_repository):
        """Test creating character with full data"""
        data = {
            "name": "Luna",
            "age": 7,
            "gender": "female",
            "role": "explorer",
            "traits": ["brave", "curious", "kind"],
            "likes": ["astronomy", "reading"],
            "dislikes": ["loud noises"],
            "pets": [{"name": "Fluffy", "species": "cat"}],
            "personality_sliders": {"organization_planning": 75, "assertiveness": 60},
        }

        result, status = character_service.create_character(data)

        assert status == 201
        assert result["name"] == "Luna"
        assert result["age"] == 7
        assert result["gender"] == "female"
        assert "brave" in result["personality_traits"]
        assert len(result["pets"]) == 1

    def test_create_character_missing_name(self, mock_repository):
        """Test creating character without name"""
        data = {"age": 7}

        result, status = character_service.create_character(data)

        assert status == 400
        assert "error" in result
        assert "name" in result["error"].lower()

    def test_create_character_missing_age(self, mock_repository):
        """Test creating character without age"""
        data = {"name": "Luna"}

        result, status = character_service.create_character(data)

        assert status == 400
        assert "error" in result
        assert "age" in result["error"].lower()

    def test_create_character_invalid_age(self, mock_repository):
        """Test creating character with invalid age"""
        data = {"name": "Luna", "age": -5}

        result, status = character_service.create_character(data)

        assert status == 400
        assert "error" in result

    def test_create_character_age_zero_valid(self, mock_repository):
        """Test that age=0 (newborn) is valid"""
        data = {"name": "Baby", "age": 0}

        result, status = character_service.create_character(data)

        assert status == 201
        assert result["age"] == 0

    def test_create_character_with_pets(self, mock_repository):
        """Test creating character with pets"""
        data = {
            "name": "Luna",
            "age": 7,
            "pets": [
                {"name": "Fluffy", "species": "cat", "color": "orange"},
                {"name": "Rex", "species": "dog"},
            ],
        }

        result, status = character_service.create_character(data)

        assert status == 201
        assert len(result["pets"]) == 2
        assert result["pets"][0]["name"] == "Fluffy"

    def test_create_character_sanitizes_text(self, mock_repository):
        """Test that text inputs are sanitized"""
        data = {"name": '<script>alert("xss")</script>Luna', "age": 7}

        result, status = character_service.create_character(data)

        assert status == 201
        assert "<script>" not in result["name"]
        assert "Luna" in result["name"]


class TestGetCharacters:
    """Test character retrieval"""

    @pytest.fixture
    def mock_repository(self):
        """Mock character repository"""
        with patch("backend.services.character_service.character_repository") as mock:
            # Create mock characters
            char1 = Mock()
            char1.to_dict.return_value = {"id": "1", "name": "Luna", "age": 7}
            char2 = Mock()
            char2.to_dict.return_value = {"id": "2", "name": "Sam", "age": 10}

            mock.get_all_characters.return_value = [char1, char2]
            mock.get_characters_by_user.return_value = [char1]
            yield mock

    def test_get_all_characters(self, mock_repository):
        """Test getting all characters"""
        result, status = character_service.get_characters()

        assert status == 200
        assert len(result) == 2
        assert result[0]["name"] == "Luna"
        assert result[1]["name"] == "Sam"

    def test_get_characters_by_user(self, mock_repository):
        """Test getting characters by user ID"""
        result, status = character_service.get_characters(user_id="user_123")

        assert status == 200
        assert len(result) == 1
        assert result[0]["name"] == "Luna"


class TestGetCharacter:
    """Test single character retrieval"""

    @pytest.fixture
    def mock_repository(self):
        """Mock character repository"""
        with patch("backend.services.character_service.character_repository") as mock:
            char = Mock()
            char.to_dict.return_value = {"id": "1", "name": "Luna", "age": 7}

            mock.get_character_by_id.return_value = char
            yield mock

    def test_get_character_found(self, mock_repository):
        """Test getting character that exists"""
        result, status = character_service.get_character("char_123")

        assert status == 200
        assert result["name"] == "Luna"

    def test_get_character_not_found(self, mock_repository):
        """Test getting character that doesn't exist"""
        mock_repository.get_character_by_id.return_value = None

        result, status = character_service.get_character("nonexistent")

        assert status == 404
        assert "error" in result


class TestUpdateCharacter:
    """Test character updates"""

    @pytest.fixture
    def mock_character(self):
        """Create a mock character"""
        char = Mock()
        char.id = "char_123"
        char.name = "Luna"
        char.age = 7
        char.gender = "female"
        char.role = "explorer"
        char.personality_traits = ["brave"]
        char.likes = ["astronomy"]
        char.pets = []
        char.personality_sliders = {}
        char.to_dict.return_value = {
            "id": "char_123",
            "name": "Luna",
            "age": 7,
            "gender": "female",
            "personality_traits": ["brave"],
            "pets": [],
        }
        return char

    @pytest.fixture
    def mock_repository(self, mock_character):
        """Mock character repository"""
        with patch("backend.services.character_service.character_repository") as mock:
            mock.get_character_by_id.return_value = mock_character
            mock.update_character = Mock()
            yield mock

    def test_update_character_name(self, mock_repository, mock_character):
        """Test updating character name"""
        update_data = {"name": "Luna Star"}

        result, status = character_service.update_character("char_123", update_data)

        assert status == 200
        assert mock_character.name == "Luna Star"

    def test_update_character_age(self, mock_repository, mock_character):
        """Test updating character age"""
        update_data = {"age": 8}

        result, status = character_service.update_character("char_123", update_data)

        assert status == 200
        assert mock_character.age == 8

    def test_update_character_invalid_age(self, mock_repository, mock_character):
        """Test updating with invalid age"""
        update_data = {"age": 200}

        result, status = character_service.update_character("char_123", update_data)

        assert status == 400
        assert "error" in result

    def test_update_character_pets(self, mock_repository, mock_character):
        """Test updating character pets"""
        update_data = {"pets": [{"name": "Fluffy", "species": "cat"}]}

        result, status = character_service.update_character("char_123", update_data)

        assert status == 200
        assert len(mock_character.pets) == 1

    def test_update_character_personality_sliders(
        self, mock_repository, mock_character
    ):
        """Test updating personality sliders"""
        update_data = {
            "personality_sliders": {"organization_planning": 75, "assertiveness": 60}
        }

        result, status = character_service.update_character("char_123", update_data)

        assert status == 200
        assert mock_character.personality_sliders["organization_planning"] == 75

    def test_update_character_not_found(self, mock_repository):
        """Test updating character that doesn't exist"""
        mock_repository.get_character_by_id.return_value = None

        result, status = character_service.update_character("nonexistent", {})

        assert status == 404
        assert "error" in result

    def test_update_character_partial(self, mock_repository, mock_character):
        """Test partial update (only some fields)"""
        original_name = mock_character.name
        update_data = {"age": 8}

        result, status = character_service.update_character("char_123", update_data)

        assert status == 200
        assert mock_character.age == 8
        assert mock_character.name == original_name  # Name unchanged


class TestDeleteCharacter:
    """Test character deletion"""

    @pytest.fixture
    def mock_character(self):
        """Create a mock character"""
        char = Mock()
        char.id = "char_123"
        return char

    @pytest.fixture
    def mock_repository(self, mock_character):
        """Mock character repository"""
        with patch("backend.services.character_service.character_repository") as mock:
            mock.get_character_by_id.return_value = mock_character
            mock.delete_character = Mock()
            yield mock

    def test_delete_character_success(self, mock_repository):
        """Test deleting character successfully"""
        result, status = character_service.delete_character("char_123")

        assert status == 200
        assert result["status"] == "deleted"
        assert result["id"] == "char_123"

    def test_delete_character_not_found(self, mock_repository):
        """Test deleting character that doesn't exist"""
        mock_repository.get_character_by_id.return_value = None

        result, status = character_service.delete_character("nonexistent")

        assert status == 404
        assert "error" in result


class TestPersonalitySliderDefinitions:
    """Test personality slider definitions structure"""

    def test_all_sliders_have_label(self):
        """Test all sliders have a label"""
        for key, value in PERSONALITY_SLIDER_DEFINITIONS.items():
            assert "label" in value, f"{key} missing label"

    def test_all_sliders_have_left_label(self):
        """Test all sliders have a left label"""
        for key, value in PERSONALITY_SLIDER_DEFINITIONS.items():
            assert "left_label" in value, f"{key} missing left_label"

    def test_all_sliders_have_right_label(self):
        """Test all sliders have a right label"""
        for key, value in PERSONALITY_SLIDER_DEFINITIONS.items():
            assert "right_label" in value, f"{key} missing right_label"

    def test_expected_sliders_present(self):
        """Test expected slider keys are present"""
        expected_keys = [
            "organization_planning",
            "assertiveness",
            "sociability",
            "adventure",
            "expressiveness",
            "feelings_sharing",
            "problem_solving",
            "play_preference",
        ]

        for key in expected_keys:
            assert key in PERSONALITY_SLIDER_DEFINITIONS, f"Missing slider: {key}"
