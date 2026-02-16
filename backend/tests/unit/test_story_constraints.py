import pytest
from backend.services.story_service import AGE_CONSTRAINTS
from backend.utils.validators import validate_age, validate_story_length
from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder

class TestStoryConstraints:
    """Test suite for Story Weaver age and length constraints."""

    def test_age_constraints_structure(self):
        """Verify AGE_CONSTRAINTS has all required age bands."""
        required_bands = ['3-4', '5-7', '8-10', '11-13', '13-15', '15-18', 'adult']
        for band in required_bands:
            assert band in AGE_CONSTRAINTS
            assert 'regular' in AGE_CONSTRAINTS[band]
            assert 'rhyme' in AGE_CONSTRAINTS[band]

    def test_word_counts_increase_with_age(self):
        """Verify that word counts generally increase with age."""
        # Compare 5-7 vs 8-10 for medium regular stories
        younger = AGE_CONSTRAINTS['5-7']['regular']['medium']
        older = AGE_CONSTRAINTS['8-10']['regular']['medium']
        
        # Tuple comparison (min_words, max_words)
        assert older[0] >= younger[0]
        assert older[1] >= younger[1]

    def test_validate_age(self):
        """Test age validation logic."""
        assert validate_age(5) == 5
        assert validate_age("5") == 5
        assert validate_age(3) == 3
        
        # Test range validation (validator doesn't clamp, logic does)
        assert validate_age(1) == 1 
        assert validate_age(100) == 100 # Allow adults
        
        # Test invalid input
        with pytest.raises(ValueError):
            validate_age("invalid")
        
        with pytest.raises(ValueError):
            validate_age(150) # Too old

    def test_interactive_path_depths(self):
        """Test that interactive stories have age-appropriate depths."""
        # Check static configuration directly
        from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder
        
        depths_young = InteractiveAdventurePromptBuilder.PATH_DEPTHS['3-4']['medium']
        depths_teen = InteractiveAdventurePromptBuilder.PATH_DEPTHS['13-15']['medium']
        
        # Expect teens to have longer/deeper stories
        assert depths_teen > depths_young

    def test_validate_story_length(self):
        """Test story length validation."""
        assert validate_story_length('short') == 'short'
        assert validate_story_length('Medium') == 'medium'
        assert validate_story_length('EPIC') == 'epic' # Validator returns valid key, service handles mapping
        
        # Test invalid input
        with pytest.raises(ValueError):
            validate_story_length('invalid_length')

