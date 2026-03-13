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

    def test_big_feelings_opening_prompt_uses_preschool_context(self):
        """Opening prompt should include preschool big-feelings guidance and concrete choice examples."""
        prompt = InteractiveAdventurePromptBuilder.build_opening_prompt(
            child_name='Milo',
            age=5,
            length='short',
            theme='Big Feelings',
            tone='whimsical',
            life_challenge='Handling Big Feelings',
            big_feelings_context={
                'current_feeling': {
                    'emotion_name': 'Mad',
                    'physical_signs': 'Hot face',
                },
                'trigger': 'someone said no',
                'body_signal': 'Hot face',
                'coping_tool': 'Take a dragon breath',
                'repair_goal': 'Help fix it',
            },
        )

        assert 'BIG FEELINGS INTERACTIVE CONTEXT' in prompt
        assert (
            'Opening style example: "You felt so mad. Something happened that made the feeling big. '
            'Your body clue was hot face."'
        ) in prompt
        assert 'Weave the trigger into the scene naturally instead of copying it as a stiff setup line.' in prompt
        assert 'Take a dragon breath' in prompt
        assert 'Roar, then stop' in prompt
        assert 'PRESCHOOL PICK-A-PATH RULES' in prompt
        assert 'For mad stories, the first branch should contrast helper-now versus big reaction then stop' in prompt

    def test_big_feelings_continuation_prompt_uses_repair_focused_choices(self):
        """Continuation prompt should keep the same feelings thread and repair-friendly choices."""
        prompt = InteractiveAdventurePromptBuilder.build_continuation_prompt(
            story_context={
                'title': 'Milo and the Red Storm',
                'theme': 'Big Feelings',
                'tone': 'whimsical',
                'length': 'short',
                'age': 5,
                'character': {'name': 'Milo'},
                'companions': [],
                'big_feelings_context': {
                    'current_feeling': {
                        'emotion_name': 'Mad',
                        'physical_signs': 'Hot face',
                    },
                    'trigger': 'someone said no',
                    'body_signal': 'Hot face',
                    'coping_tool': 'Take a dragon breath',
                    'repair_goal': 'Help fix it',
                },
            },
            selected_choice='Take a dragon breath',
            current_segment_number=1,
            inventory=[],
            story_state={},
            story_so_far='Milo felt so mad when someone said no.',
        )

        assert 'Keep reflecting the same feeling thread' in prompt
        assert 'Use gentle words' in prompt
        assert 'Help fix it' in prompt
        assert 'If the hero causes a bump, include this repair beat: Help fix it' in prompt
        assert (
            'For mad continuations, if the big reaction affects someone else or the room, '
            'the very next beat should move toward repair'
        ) in prompt

    def test_non_big_feelings_prompt_keeps_generic_choice_templates(self):
        """Non-feelings stories should still use generic fallback choice template guidance."""
        prompt = InteractiveAdventurePromptBuilder.build_opening_prompt(
            child_name='Ava',
            age=8,
            length='short',
            theme='Adventure',
            tone='whimsical',
        )

        assert 'First choice option (Action-oriented)' in prompt
        assert 'Second choice option (Action-oriented)' in prompt
