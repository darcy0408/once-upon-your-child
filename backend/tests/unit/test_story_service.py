"""
Comprehensive unit tests for Story Service (AdvancedStoryEngine)

Tests cover:
- Age band classification
- Age-appropriate word count constraints
- Prompt generation with various parameters
- Custom elements inclusion
- Companion character handling (pets, friends, guests)
- Story length variations (quick, standard, epic)
- Rhyme time mode constraints
- Validation and error handling
- Edge cases
"""

import pytest
from backend.services.story_service import (
    AdvancedStoryEngine,
    _get_age_band,
    AGE_CONSTRAINTS,
    _build_learning_to_read_prompt,
    transform_parent_context_to_story_guidance,
)


class TestAgeBandClassification:
    """Test age band calculation logic"""

    def test_age_band_toddler(self):
        """Test ages 3-4 are classified correctly"""
        assert _get_age_band(3) == '3-4'
        assert _get_age_band(4) == '3-4'

    def test_age_band_early_elementary(self):
        """Test ages 5-7 are classified correctly"""
        assert _get_age_band(5) == '5-7'
        assert _get_age_band(6) == '5-7'
        assert _get_age_band(7) == '5-7'

    def test_age_band_late_elementary(self):
        """Test ages 8-10 are classified correctly"""
        assert _get_age_band(8) == '8-10'
        assert _get_age_band(9) == '8-10'
        assert _get_age_band(10) == '8-10'

    def test_age_band_middle_school(self):
        """Test ages 11-13 are classified correctly"""
        assert _get_age_band(11) == '11-13'
        assert _get_age_band(12) == '11-13'
        assert _get_age_band(13) == '11-13'

    def test_age_band_early_teens(self):
        """Test ages 13-15 are classified correctly"""
        assert _get_age_band(14) == '13-15'

    def test_age_band_late_teens(self):
        """Test ages 15-18 are classified correctly"""
        assert _get_age_band(15) == '15-18'
        assert _get_age_band(16) == '15-18'
        assert _get_age_band(17) == '15-18'
        assert _get_age_band(18) == '15-18'

    def test_age_band_adult(self):
        """Test ages 19+ are classified as adult"""
        assert _get_age_band(19) == 'adult'
        assert _get_age_band(25) == 'adult'
        assert _get_age_band(99) == 'adult'


class TestAdvancedStoryEngine:
    """Test AdvancedStoryEngine prompt generation"""

    @pytest.fixture
    def engine(self):
        """Create a story engine instance"""
        return AdvancedStoryEngine()

    # ========================================================================
    # AGE-APPROPRIATE WORD COUNTS
    # ========================================================================

    def test_word_count_young_child(self, engine):
        """Test 5-year-old gets age-appropriate word count (650-900)"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=5
        )

        # Should specify 650-900 word range for 5-7 age band, medium length
        assert "650-900 words" in prompt or "650" in prompt and "900" in prompt

    def test_word_count_teen(self, engine):
        """Test 15-year-old gets age-appropriate word count (3000-4200)"""
        prompt = engine.generate_enhanced_prompt(
            character="Alex",
            theme="Mystery",
            age=15
        )

        # Should specify 3000-4200 word range for 15-18 age band, medium length
        assert "3000-4200 words" in prompt or ("3000" in prompt and "4200" in prompt)

    def test_word_count_adult(self, engine):
        """Test adult gets therapeutic word count (3200-5200)"""
        prompt = engine.generate_enhanced_prompt(
            character="Sam",
            theme="Self-Discovery",
            age=25
        )

        # Should specify 3200-5200 word range for adult, medium length
        assert "3200-5200 words" in prompt or ("3200" in prompt and "5200" in prompt)

    def test_hard_complexity_targets_for_preteen(self, engine):
        """Age 12 prompt should include hard complexity targets."""
        prompt = engine.generate_enhanced_prompt(
            character="Riley",
            theme="Mystery",
            age=12
        )

        assert "Hard Complexity Targets" in prompt
        assert "30% of sentences" in prompt
        assert "tradeoff" in prompt

    def test_hard_complexity_targets_for_adult(self, engine):
        """Adult prompt should include strongest hard complexity targets."""
        prompt = engine.generate_enhanced_prompt(
            character="Jordan",
            theme="Self-Discovery",
            age=46
        )

        assert "Hard Complexity Targets" in prompt
        assert "40% of sentences" in prompt
        assert "genuinely earned through the character's actions" in prompt

    # ========================================================================
    # STORY LENGTH VARIATIONS
    # ========================================================================

    def test_story_length_quick(self, engine):
        """Test 'quick' story length uses short word count"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            story_length="quick"
        )

        # Quick maps to short: 450-650 for 5-7 age band
        assert "450-650 words" in prompt or ("450" in prompt and "650" in prompt)

    def test_story_length_standard(self, engine):
        """Test 'standard' story length uses medium word count"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            story_length="standard"
        )

        # Standard maps to medium: 650-900 for 5-7 age band
        assert "650-900 words" in prompt or ("650" in prompt and "900" in prompt)

    def test_story_length_epic(self, engine):
        """Test 'epic' story length uses long word count"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            story_length="epic"
        )

        # Epic maps to long: 900-1200 for 5-7 age band
        assert "900-1200 words" in prompt or ("900" in prompt and "1200" in prompt)

    def test_story_length_case_insensitive(self, engine):
        """Test story length is case-insensitive"""
        prompt_upper = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            story_length="QUICK"
        )

        prompt_lower = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            story_length="quick"
        )

        # Both should use short word count
        assert "450-650" in prompt_upper
        assert "450-650" in prompt_lower

    # ========================================================================
    # CUSTOM ELEMENTS
    # ========================================================================

    def test_custom_elements_included(self, engine):
        """Test custom elements are mentioned in prompt"""
        custom_elements = "talking owl, rainbow bridge, magic compass"

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            custom_elements=custom_elements
        )

        assert "talking owl" in prompt
        assert "rainbow bridge" in prompt
        assert "magic compass" in prompt

    def test_custom_elements_empty(self, engine):
        """Test prompt generation works without custom elements"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            custom_elements=""
        )

        # Should generate successfully
        assert "Luna" in prompt
        assert len(prompt) > 100

    # ========================================================================
    # COMPANION CHARACTERS
    # ========================================================================

    def test_companion_pets(self, engine):
        """Test pet companions are included in prompt"""
        companion_pets = [
            {'name': 'Fluffy', 'species': 'cat'},
            {'name': 'Rex', 'species': 'dog'}
        ]

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            companion_pets=companion_pets
        )

        assert "Fluffy" in prompt
        assert "Rex" in prompt
        assert "PETS" in prompt or "pets" in prompt.lower()

    def test_companion_friends(self, engine):
        """Test friend companions are included in prompt"""
        companion_characters = [
            {'name': 'Sam', 'signaturePower': 'Super Speed'},
            {'name': 'Maya', 'signaturePower': 'Telepathy'}
        ]

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            companion_characters=companion_characters
        )

        assert "Sam" in prompt
        assert "Maya" in prompt
        assert "FRIENDS" in prompt or "friends" in prompt.lower()

    def test_additional_characters_guests(self, engine):
        """Test additional characters (guests) are included"""
        additional_characters = [
            {'name': 'Grandma Rose'},
            {'name': 'Uncle Tom'}
        ]

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            additional_characters=additional_characters
        )

        assert "Grandma Rose" in prompt
        assert "Uncle Tom" in prompt
        assert "GUESTS" in prompt or "guests" in prompt.lower()

    def test_companion_string_format(self, engine):
        """Test companion as simple string"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            companion="Sparkle the Unicorn"
        )

        assert "Sparkle the Unicorn" in prompt

    def test_companion_dict_format(self, engine):
        """Test companion as dictionary"""
        companion_dict = {
            'name': 'Sparkle',
            'type': 'Unicorn',
            'species': 'Mythical'
        }

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            companion=companion_dict
        )

        assert "Sparkle" in prompt

    def test_all_companion_types_together(self, engine):
        """Test all companion types in one story"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            companion_pets=[{'name': 'Fluffy', 'species': 'cat'}],
            companion_characters=[{'name': 'Sam'}],
            additional_characters=[{'name': 'Grandma'}]
        )

        # All should be present
        assert "Fluffy" in prompt
        assert "Sam" in prompt
        assert "Grandma" in prompt

    # ========================================================================
    # CHARACTER DETAILS
    # ========================================================================

    def test_character_details_gender(self, engine):
        """Test character gender is included"""
        character_details = {
            'gender': 'female',
            'pronouns': 'she/her'
        }

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            character_details=character_details
        )

        assert "female" in prompt.lower() or "she/her" in prompt.lower()

    def test_character_details_strengths(self, engine):
        """Test character strengths are included"""
        character_details = {
            'strengths': ['brave', 'curious', 'kind']
        }

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            character_details=character_details
        )

        # Strengths should be mentioned
        assert "brave" in prompt.lower() or "curious" in prompt.lower()

    def test_character_details_special_ability(self, engine):
        """Test special ability is included"""
        character_details = {
            'specialAbility': 'Can talk to animals'
        }

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            character_details=character_details
        )

        assert "talk to animals" in prompt.lower()

    # ========================================================================
    # THERAPEUTIC MODE
    # ========================================================================

    def test_therapeutic_prompt_parameter(self, engine):
        """Test therapeutic prompt parameter is accepted"""
        # Note: therapeutic_prompt may be used in other parts of the system
        # Here we just verify the parameter is accepted without error
        therapeutic_prompt = "Help Luna deal with anxiety about starting school"

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Self-Discovery",
            age=7,
            therapeutic_prompt=therapeutic_prompt
        )

        # Should generate successfully
        assert len(prompt) > 100
        assert "Luna" in prompt

    def test_feelings_prompt_parameter(self, engine):
        """Test feelings prompt parameter is accepted"""
        # Note: feelings_prompt may be used in other parts of the system
        # Here we just verify the parameter is accepted without error
        feelings_prompt = "Luna is feeling nervous but excited"

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            feelings_prompt=feelings_prompt
        )

        # Should generate successfully
        assert len(prompt) > 100
        assert "Luna" in prompt

    # ========================================================================
    # MOOD PHYSICS
    # ========================================================================

    def test_mood_physics_included(self, engine):
        """Test mood physics rules are added to prompt"""
        mood_physics = {
            'mood': 'Excited',
            'worldRule': 'Everything sparkles and bounces',
            'sensoryChange': 'Colors are brighter, sounds are musical'
        }

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            mood_physics=mood_physics
        )

        assert "sparkles" in prompt.lower() and "bounces" in prompt.lower()
        assert "brighter" in prompt.lower() or "musical" in prompt.lower()

    # ========================================================================
    # SPARK TOOL (KEY ARTIFACT)
    # ========================================================================

    def test_spark_tool_young_child(self, engine):
        """Test spark tool is labeled 'HERO TOOL' for young children"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            spark_tool="Magic compass"
        )

        assert "HERO TOOL" in prompt
        assert "Magic compass" in prompt

    def test_spark_tool_teen(self, engine):
        """Test spark tool is labeled 'KEY ARTIFACT' for teens"""
        prompt = engine.generate_enhanced_prompt(
            character="Alex",
            theme="Mystery",
            age=15,
            spark_tool="Ancient medallion"
        )

        assert "KEY ARTIFACT" in prompt
        assert "Ancient medallion" in prompt

    # ========================================================================
    # SAFETY GUARDRAILS
    # ========================================================================

    def test_safety_rules_for_young_children(self, engine):
        """Test safety rules are emphasized for young children"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=5
        )

        # Should contain safety warnings for young children
        assert "SAFETY" in prompt or "scary" in prompt.lower()

    def test_no_invented_characters_rule(self, engine):
        """Test prompt includes rule against inventing characters"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7
        )

        # Should warn against inventing characters not provided
        assert "NOT invent characters" in prompt or "invent" in prompt.lower()

    # ========================================================================
    # AGE VALIDATION
    # ========================================================================

    def test_age_validation_negative(self, engine):
        """Test negative age is rejected"""
        with pytest.raises((ValueError, AssertionError)):
            engine.generate_enhanced_prompt(
                character="Luna",
                theme="Adventure",
                age=-1
            )

    def test_age_validation_too_old(self, engine):
        """Test age above 100 is rejected"""
        with pytest.raises((ValueError, AssertionError)):
            engine.generate_enhanced_prompt(
                character="Luna",
                theme="Adventure",
                age=150
            )

    def test_age_validation_boundary_values(self, engine):
        """Test boundary ages are accepted"""
        # Should not raise
        prompt_5 = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=5
        )

        prompt_17 = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=17
        )

        assert len(prompt_5) > 100
        assert len(prompt_17) > 100

    # ========================================================================
    # STORY LENGTH VALIDATION
    # ========================================================================

    def test_story_length_validation_invalid(self, engine):
        """Test invalid story length is rejected"""
        with pytest.raises((ValueError, AssertionError)):
            engine.generate_enhanced_prompt(
                character="Luna",
                theme="Adventure",
                age=7,
                story_length="extra-super-long"
            )

    def test_story_length_validation_valid_values(self, engine):
        """Test all valid story lengths are accepted"""
        valid_lengths = ['quick', 'standard', 'epic', 'short', 'medium', 'long']

        for length in valid_lengths:
            prompt = engine.generate_enhanced_prompt(
                character="Luna",
                theme="Adventure",
                age=7,
                story_length=length
            )
            assert len(prompt) > 100

    # ========================================================================
    # EDGE CASES
    # ========================================================================

    def test_empty_character_name(self, engine):
        """Test handling of empty character name"""
        prompt = engine.generate_enhanced_prompt(
            character="",
            theme="Adventure",
            age=7
        )

        # Should still generate (backend might use default)
        assert len(prompt) > 100

    def test_special_characters_in_name(self, engine):
        """Test handling of special characters in names"""
        prompt = engine.generate_enhanced_prompt(
            character="O'Brien",
            theme="Adventure",
            age=7
        )

        assert "O'Brien" in prompt

    def test_unicode_characters(self, engine):
        """Test handling of unicode characters"""
        prompt = engine.generate_enhanced_prompt(
            character="María",
            theme="Adventure",
            age=7,
            custom_elements="piñata, café"
        )

        assert "María" in prompt
        assert "piñata" in prompt or "café" in prompt

    def test_very_long_custom_elements(self, engine):
        """Test handling of very long custom elements"""
        long_elements = "a magical rainbow unicorn with golden wings, a talking tree that tells ancient stories, a crystal cave filled with glowing gems, a friendly dragon who loves to dance"

        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure",
            age=7,
            custom_elements=long_elements
        )

        # Should include at least some of the elements
        assert "unicorn" in prompt.lower() or "dragon" in prompt.lower()

    def test_minimal_parameters(self, engine):
        """Test generation with only required parameters"""
        prompt = engine.generate_enhanced_prompt(
            character="Luna",
            theme="Adventure"
        )

        # Should use defaults (age=5, story_length=standard)
        assert "Luna" in prompt
        assert len(prompt) > 100


class TestAgeConstraintsStructure:
    """Test the AGE_CONSTRAINTS data structure"""

    def test_all_age_bands_present(self):
        """Test all expected age bands are defined"""
        expected_bands = ['3-4', '5-7', '8-10', '11-13', '13-15', '15-18', 'adult']

        for band in expected_bands:
            assert band in AGE_CONSTRAINTS, f"Missing age band: {band}"

    def test_all_bands_have_regular(self):
        """Test all age bands have regular story constraints"""
        for band, config in AGE_CONSTRAINTS.items():
            assert 'regular' in config, f"Band {band} missing 'regular'"
            assert 'short' in config['regular']
            assert 'medium' in config['regular']
            assert 'long' in config['regular']

    def test_all_bands_have_rhyme(self):
        """Test all age bands have rhyme mode constraints"""
        for band, config in AGE_CONSTRAINTS.items():
            assert 'rhyme' in config, f"Band {band} missing 'rhyme'"
            assert 'short' in config['rhyme']
            assert 'medium' in config['rhyme']
            assert 'long' in config['rhyme']

    def test_word_counts_are_tuples(self):
        """Test word counts are properly formatted as (min, max) tuples"""
        for band, config in AGE_CONSTRAINTS.items():
            for mode in ['regular', 'rhyme']:
                for length in ['short', 'medium', 'long']:
                    word_range = config[mode][length]
                    assert isinstance(word_range, tuple), f"{band}/{mode}/{length} not a tuple"
                    assert len(word_range) == 2, f"{band}/{mode}/{length} not length 2"
                    assert word_range[0] < word_range[1], f"{band}/{mode}/{length} invalid range"

    def test_rhyme_mode_capped_at_1000(self):
        """Test rhyme mode is capped at reasonable length (per plan)"""
        for band, config in AGE_CONSTRAINTS.items():
            for length in ['short', 'medium', 'long']:
                _, max_words = config['rhyme'][length]
                assert max_words <= 1000, f"Rhyme mode too long in {band}/{length}: {max_words}"

    def test_word_counts_increase_with_age(self):
        """Test word counts generally increase for older ages"""
        bands_in_order = ['3-4', '5-7', '8-10', '11-13', '13-15', '15-18', 'adult']

        # Check medium regular stories increase with age
        previous_max = 0
        for band in bands_in_order:
            _, current_max = AGE_CONSTRAINTS[band]['regular']['medium']
            assert current_max > previous_max, f"Word count decreased at {band}"
            previous_max = current_max


class TestLearningToReadPrompt:
    """Test learning-to-read prompt constraints and rhyme requirements."""

    def test_ltr_prompt_for_age_4_requires_rhyming_couplets(self):
        prompt = _build_learning_to_read_prompt(
            character_name="Luna",
            theme="Magic",
            age=4,
            character_details={},
            story_length="short",
        )

        assert "RHYME REQUIREMENT (MANDATORY)" in prompt
        assert "pages 1&2 rhyme, 3&4 rhyme" in prompt
        assert '"rhyme_scheme"' in prompt

    def test_ltr_prompt_for_age_7_limerick_path_has_rhyme_scheme(self):
        prompt = _build_learning_to_read_prompt(
            character_name="Luna",
            theme="Magic",
            age=7,
            character_details={},
            story_length="short",
        )

        assert "AABBA rhyme scheme" in prompt
        assert '"rhyme_scheme"' in prompt

    def test_ltr_prompt_for_age_4_includes_worked_example(self):
        prompt = _build_learning_to_read_prompt(
            character_name="Luna",
            theme="Magic",
            age=4,
            character_details={},
            story_length="short",
        )
        assert "WORKED EXAMPLE" in prompt
        assert "Page 1" in prompt and "Page 5" in prompt


class TestStripTheEndPages:
    """Trailing 'The End' marker pages are removed; embedded 'The End' is kept."""

    def test_strips_simple_the_end(self):
        from backend.services.story_service import _strip_the_end_pages
        pages = ["Body content goes here.", "The End"]
        assert _strip_the_end_pages(pages) == ["Body content goes here."]

    def test_strips_variations(self):
        from backend.services.story_service import _strip_the_end_pages
        for marker in ["the end", "THE END", "The End.", "The End!", "Fin", "Finale.", "  The End  "]:
            assert _strip_the_end_pages(["Body.", marker]) == ["Body."], f"failed: {marker!r}"

    def test_keeps_embedded_the_end(self):
        from backend.services.story_service import _strip_the_end_pages
        pages = ["Body.", "And so the adventure came to an end. The End."]
        result = _strip_the_end_pages(pages)
        assert len(result) == 2
        assert "adventure came to an end" in result[1]

    def test_never_returns_empty(self):
        from backend.services.story_service import _strip_the_end_pages
        assert _strip_the_end_pages(["The End"]) == ["The End"]

    def test_passthrough_no_marker(self):
        from backend.services.story_service import _strip_the_end_pages
        pages = ["Page one.", "Page two with real ending content here."]
        assert _strip_the_end_pages(pages) == pages


class TestPostProcessLtrPages:
    """The deterministic fallthrough split applied after Gemini exhausts LTR retries."""

    def test_splits_dense_2page_output_into_5plus_pages_under_cap(self):
        from backend.tasks.story_tasks import _post_process_ltr_pages

        page1 = (
            "Jack and Mochi, hop, hop, hop! To the big sea, go, go, stop! "
            "Jack saw a fin, a red, red fin. It can go dip, and then hid in! "
            "And then Mochi saw a big, big log. It did not move, like a fat, wet dog! "
            'Mochi said, "Jack, go, run, run, run!" Go pat the log, oh what fun!'
        )
        result = _post_process_ltr_pages([page1, "The End"], target_pages=5, max_words=25)
        assert len(result) >= 5
        assert all(len(p.split()) <= 25 for p in result)

    def test_preserves_already_compliant_5short_pages(self):
        from backend.tasks.story_tasks import _post_process_ltr_pages

        good = [
            "Sam and Pip went out to play.",
            "It was a bright sunny day.",
            "They saw a frog hop on a log.",
            "It hopped right up to the dog.",
            "What a fun day, hooray!",
        ]
        result = _post_process_ltr_pages(good, target_pages=5, max_words=25)
        assert len(result) == 5
        assert all(len(p.split()) <= 25 for p in result)

    def test_handles_empty_input(self):
        from backend.tasks.story_tasks import _post_process_ltr_pages

        assert _post_process_ltr_pages([]) == []
        assert _post_process_ltr_pages([""]) == [""]

    def test_splits_oversize_sentence_on_commas(self):
        from backend.tasks.story_tasks import _post_process_ltr_pages

        long_sent = (
            "She ran, she jumped, she spun, she laughed, she sang, "
            "she twirled, she waved, she danced, she leapt, she beamed."
        )
        result = _post_process_ltr_pages([long_sent], target_pages=5, max_words=25)
        assert all(len(p.split()) <= 25 for p in result)


class TestParentContextTransformation:
    def test_transform_parent_context_abstracts_raw_language(self):
        guidance = transform_parent_context_to_story_guidance({
            'feeling': 'Angry',
            'trigger': 'hitting sister after hearing no',
            'body_signal': 'hot face',
            'coping_tool': 'dragon breaths',
            'repair_goal': 'help fix what happened',
            'parent_hidden_context': 'meltdown after yelling at brother',
        })

        story_guidance = guidance['story_guidance'].lower()
        assert guidance['feeling'] == 'Angry'
        assert 'hitting sister' not in story_guidance
        assert 'yelling at brother' not in story_guidance
        assert 'quick impulses' in story_guidance
        assert 'loud words when feelings spill over' in story_guidance
        assert 'dragon breaths' in story_guidance
        assert 'help fix what happened' in story_guidance

    def test_transform_parent_context_returns_empty_for_missing_data(self):
        assert transform_parent_context_to_story_guidance(None) == {}
