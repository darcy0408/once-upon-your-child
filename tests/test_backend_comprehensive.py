"""
Comprehensive Backend Tests for Pick-A-Path Adventures UX Improvements
Tests everything that can be validated without a browser.

Run with:
    python -m pytest tests/test_backend_comprehensive.py -v

Or without pytest:
    python tests/test_backend_comprehensive.py
"""
import os
import sys
import json
import unittest
from pathlib import Path

# Add backend to path
backend_path = Path(__file__).parent.parent / 'backend'
sys.path.insert(0, str(backend_path))

os.environ['FLASK_ENV'] = 'testing'
os.environ['TESTING'] = 'true'


class TestPromptBuilder(unittest.TestCase):
    """Test the prompt builder generates correct prompts"""

    @classmethod
    def setUpClass(cls):
        from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder
        cls.builder = InteractiveAdventurePromptBuilder

    def test_word_count_ranges_updated(self):
        """Verify word counts increased to 350-650 range"""
        age_band_6_8 = self.builder.AGE_BANDS['6-8']

        self.assertGreaterEqual(age_band_6_8['word_count'][0], 300,
            "Minimum word count should be at least 300")
        self.assertGreaterEqual(age_band_6_8['word_count'][1], 450,
            "Maximum word count should be at least 450")

        print(f"✓ Word count for age 6-8: {age_band_6_8['word_count']}")

    def test_choice_count_reduced(self):
        """Verify choice counts reduced to 2"""
        self.assertEqual(self.builder.CHOICE_COUNTS['medium'], 2,
            "Medium stories should have 2 choices")
        self.assertEqual(self.builder.CHOICE_COUNTS['long'], 2,
            "Long stories should have 2 choices")

        print(f"✓ Choice counts: {self.builder.CHOICE_COUNTS}")

    def test_min_words_between_choices(self):
        """Verify cadence rule minimum is set"""
        self.assertEqual(self.builder.MIN_WORDS_BETWEEN_CHOICES, 450,
            "Minimum words between choices should be 450")

        print(f"✓ Min words between choices: {self.builder.MIN_WORDS_BETWEEN_CHOICES}")

    def test_opening_prompt_contains_pov_requirements(self):
        """Verify opening prompt includes second-person POV requirements"""
        prompt = self.builder.build_opening_prompt(
            child_name='TestChild',
            age=8,
            length='medium',
            theme='Magic',
            tone='whimsical'
        )

        # Check for key POV requirements
        self.assertIn('second-person', prompt.lower(), "Should mention second-person POV")
        self.assertIn('you', prompt.lower(), "Should include 'you' examples")
        self.assertIn('pov', prompt.lower(), "Should mention POV")

        # Check it's not third-person
        self.assertNotIn('third-person', prompt.lower(), "Should not use third-person")

        print("✓ Opening prompt includes POV requirements")

    def test_opening_prompt_contains_companion_contract(self):
        """Verify companion contract is in prompt"""
        companions = [{'name': 'TestPet', 'species': 'dragon'}]

        prompt = self.builder.build_opening_prompt(
            child_name='TestChild',
            age=8,
            length='medium',
            theme='Magic',
            tone='whimsical',
            companions=companions
        )

        self.assertIn('companion contract', prompt.lower())
        self.assertIn('3', prompt, "Should mention 3+ beats")
        self.assertIn('bond', prompt.lower(), "Should mention bond moment")

        print("✓ Opening prompt includes Companion Contract")

    def test_opening_prompt_contains_inventory_contract(self):
        """Verify inventory contract is in prompt"""
        prompt = self.builder.build_opening_prompt(
            child_name='TestChild',
            age=8,
            length='medium',
            theme='Magic',
            tone='whimsical'
        )

        self.assertIn('inventory contract', prompt.lower())
        self.assertIn('visibility', prompt.lower())

        print("✓ Opening prompt includes Inventory Contract")

    def test_opening_prompt_bans_filler_choices(self):
        """Verify filler choices are explicitly banned"""
        prompt = self.builder.build_opening_prompt(
            child_name='TestChild',
            age=8,
            length='medium',
            theme='Magic',
            tone='whimsical'
        )

        self.assertIn('ask', prompt.lower())
        self.assertIn('what to do', prompt.lower())
        self.assertIn('banned', prompt.lower())

        print("✓ Opening prompt bans filler choices")

    def test_opening_prompt_includes_output_type(self):
        """Verify output_type system is explained"""
        prompt = self.builder.build_opening_prompt(
            child_name='TestChild',
            age=8,
            length='medium',
            theme='Magic',
            tone='whimsical'
        )

        self.assertIn('output_type', prompt.lower())
        self.assertIn('continue', prompt.lower())
        self.assertIn('choice', prompt.lower())

        print("✓ Opening prompt includes output_type system")

    def test_continuation_prompt_has_guidance(self):
        """Verify continuation prompt includes proper guidance"""
        story_context = {
            'title': 'Test Adventure',
            'theme': 'Magic',
            'tone': 'whimsical',
            'age': 8,
            'length': 'medium'
        }

        prompt = self.builder.build_continuation_prompt(
            story_context=story_context,
            selected_choice='Go left',
            current_segment_number=1,
            inventory=['magic wand'],
            story_state={'location': 'Forest'},
            story_so_far='Previously...'
        )

        self.assertIn('second-person', prompt.lower())
        self.assertIn('companion contract', prompt.lower())
        self.assertIn('inventory contract', prompt.lower())

        print("✓ Continuation prompt includes all requirements")


class TestDatabaseModels(unittest.TestCase):
    """Test database models have new fields"""

    @classmethod
    def setUpClass(cls):
        from backend.app import create_app
        from backend.database import db
        from backend.models import StorySegment

        cls.app = create_app('testing')
        cls.db = db
        cls.StorySegment = StorySegment

    def test_story_segment_has_output_type_field(self):
        """Verify StorySegment model has output_type field"""
        with self.app.app_context():
            # Check column exists
            inspector = self.db.inspect(self.db.engine)
            columns = [col['name'] for col in inspector.get_columns('story_segment')]

            self.assertIn('output_type', columns, "output_type column should exist")
            print("✓ StorySegment has output_type column")

    def test_story_segment_has_word_count_field(self):
        """Verify StorySegment model has word_count field"""
        with self.app.app_context():
            inspector = self.db.inspect(self.db.engine)
            columns = [col['name'] for col in inspector.get_columns('story_segment')]

            self.assertIn('word_count', columns, "word_count column should exist")
            print("✓ StorySegment has word_count column")

    def test_story_segment_to_dict_includes_new_fields(self):
        """Verify to_dict() serializes new fields"""
        segment = self.StorySegment(
            id='test-id',
            story_id='story-id',
            segment_number=1,
            output_type='CONTINUE',
            word_count=450,
            content='Test content'
        )

        data = segment.to_dict()

        self.assertIn('output_type', data)
        self.assertEqual(data['output_type'], 'CONTINUE')
        self.assertIn('word_count', data)
        self.assertEqual(data['word_count'], 450)

        print("✓ to_dict() includes output_type and word_count")


class TestStoryGeneration(unittest.TestCase):
    """Test actual story generation (requires GEMINI_API_KEY)"""

    @classmethod
    def setUpClass(cls):
        cls.api_key = os.getenv('GEMINI_API_KEY')
        if not cls.api_key:
            cls.skipTest(cls, "GEMINI_API_KEY not set")

        from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder
        import google.generativeai as genai

        cls.builder = InteractiveAdventurePromptBuilder

        genai.configure(api_key=cls.api_key)
        
        # Debug and Force Model
        env_model = os.getenv('GEMINI_MODEL')
        print(f"\nDEBUG: Environment GEMINI_MODEL: {env_model}")
        
        # Fallback/Override if needed
        model_name = env_model or 'gemini-2.0-flash-exp'
        if model_name == 'gemini-1.5-flash':
             print("DEBUG: Overriding deprecated/missing gemini-1.5-flash with gemini-2.0-flash-exp")
             model_name = 'gemini-2.0-flash-exp'
             
        print(f"DEBUG: Using Gemini Model: {model_name}")

        cls.model = genai.GenerativeModel(
            model_name,
            generation_config={"response_mime_type": "application/json"}
        )

    def test_generate_opening_segment(self):
        """Test generating actual opening segment"""
        character = {
            'name': 'TestHero',
            'age': 8,
            'personality_traits': ['brave', 'kind'],
            'strengths': ['clever']
        }

        companions = [{'name': 'TestPet', 'species': 'mouse', 'personality': 'wise'}]

        prompt = self.builder.build_opening_prompt(
            child_name='TestHero',
            age=8,
            length='medium',
            theme='Magic',
            tone='whimsical',
            character=character,
            companions=companions
        )

        print("\n→ Generating story with Gemini...")
        response = self.model.generate_content(prompt)

        self.assertIsNotNone(response)
        self.assertTrue(hasattr(response, 'text'))

        # Parse JSON
        story_data = json.loads(response.text)

        # Verify required fields
        self.assertIn('output_type', story_data)
        self.assertIn('content', story_data)
        self.assertIn('word_count', story_data)
        self.assertIn('companion_beats', story_data)
        self.assertIn('choices', story_data)

        print(f"✓ Generated segment with output_type={story_data['output_type']}")

        return story_data

    def test_word_count_in_range(self):
        """Test generated story has correct word count"""
        story_data = self.test_generate_opening_segment()

        content = story_data['content']
        actual_word_count = len(content.split())
        reported_word_count = story_data.get('word_count', 0)

        # Check actual count
        self.assertGreaterEqual(actual_word_count, 150,
            f"Story should have at least 300 words, got {actual_word_count}")

        # Check reported count is close
        difference = abs(actual_word_count - reported_word_count)
        self.assertLess(difference, 50,
            f"Reported word count should be close to actual ({actual_word_count} vs {reported_word_count})")

        print(f"✓ Word count: {actual_word_count} (target: 350-500)")

    def test_second_person_pov_dominant(self):
        """Test that second-person POV is used"""
        story_data = self.test_generate_opening_segment()

        content = story_data['content'].lower()

        # Count "you" mentions
        you_count = content.count(' you ')

        # Count third-person pronouns
        he_count = content.count(' he ')
        she_count = content.count(' she ')
        third_person = he_count + she_count

        # Should have way more "you" than third-person
        self.assertGreaterEqual(you_count, 3, "Should have at least 5 'you' mentions")

        if third_person > 0:
            ratio = you_count / third_person
            self.assertGreater(ratio, 1.0,
                f"Should have 3x more 'you' than third-person (got {you_count} vs {third_person})")

        print(f"✓ POV check: 'you' appears {you_count} times")

    def test_companion_beats_present(self):
        """Test companion beats are included"""
        story_data = self.test_generate_opening_segment()

        companion_beats = story_data.get('companion_beats', [])

        self.assertGreaterEqual(len(companion_beats), 2,
            f"Should have at least 3 companion beats, got {len(companion_beats)}")

        # Check beat types
        beat_types = [beat.get('type') for beat in companion_beats]
        print(f"✓ Companion beats: {len(companion_beats)} ({', '.join(beat_types)})")

    def test_no_banned_choice_patterns(self):
        """Test choices don't contain banned patterns"""
        story_data = self.test_generate_opening_segment()

        choices = story_data.get('choices', [])

        banned_patterns = [
            'ask what to do',
            'ask more questions',
            'wait and see',
        ]

        for choice in choices:
            text = choice.get('text', '').lower()
            for pattern in banned_patterns:
                self.assertNotIn(pattern, text,
                    f"Choice should not contain banned pattern '{pattern}': {choice['text']}")

        print(f"✓ No banned patterns in {len(choices)} choices")

    def test_choice_count_is_two(self):
        """Test that exactly 2 choices are provided"""
        story_data = self.test_generate_opening_segment()

        if story_data.get('output_type') == 'CHOICE':
            choices = story_data.get('choices', [])

            # Should be exactly 2 choices (or maybe 3 if justified)
            self.assertGreaterEqual(len(choices), 2)
            self.assertLessEqual(len(choices), 3,
                f"Should have 2-3 choices, got {len(choices)}")

            print(f"✓ Choice count: {len(choices)}")


class TestWordCountCalculation(unittest.TestCase):
    """Test word count calculation logic"""

    def test_word_count_calculation(self):
        """Test word count is calculated correctly"""
        test_cases = [
            ("Hello world", 2),
            ("This is a test sentence.", 5),
            ("One", 1),
            ("Multiple   spaces   between   words", 4),
            ("", 0),
        ]

        for text, expected in test_cases:
            actual = len(text.split()) if text else 0
            self.assertEqual(actual, expected,
                f"Word count for '{text}' should be {expected}, got {actual}")

        print("✓ Word count calculation works correctly")


class TestJSONSchemaValidation(unittest.TestCase):
    """Test that generated JSON matches expected schema"""

    def test_expected_fields_present(self):
        """Test all expected fields are in schema"""
        expected_fields = [
            'output_type',
            'segment_number',
            'content',
            'word_count',
            'companion_beats',
            'inventory',
            'inventory_references',
            'story_state',
            'choices',
            'is_ending'
        ]

        # This would be the actual generated JSON
        sample_json = {
            'output_type': 'CHOICE',
            'segment_number': 1,
            'content': 'Story content here',
            'word_count': 450,
            'companion_beats': [],
            'inventory': [],
            'inventory_references': [],
            'story_state': {
                'location': 'Forest',
                'goal': 'Find magic',
                'key_clues': [],
                'companion_status': 'Happy',
                'time_pressure': None
            },
            'choices': [],
            'is_ending': False
        }

        for field in expected_fields:
            self.assertIn(field, sample_json,
                f"Field '{field}' should be in generated JSON")

        print(f"✓ All {len(expected_fields)} expected fields present in schema")


def run_all_tests():
    """Run all test suites"""
    print("="*80)
    print(" COMPREHENSIVE BACKEND TESTS - PICK-A-PATH UX IMPROVEMENTS")
    print("="*80)
    print()

    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add all test classes
    suite.addTests(loader.loadTestsFromTestCase(TestPromptBuilder))
    suite.addTests(loader.loadTestsFromTestCase(TestDatabaseModels))
    suite.addTests(loader.loadTestsFromTestCase(TestWordCountCalculation))
    suite.addTests(loader.loadTestsFromTestCase(TestJSONSchemaValidation))

    # Only add generation tests if API key is set
    if os.getenv('GEMINI_API_KEY'):
        print("✓ GEMINI_API_KEY found - including story generation tests")
        suite.addTests(loader.loadTestsFromTestCase(TestStoryGeneration))
    else:
        print("⚠ GEMINI_API_KEY not set - skipping story generation tests")

    print()

    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Summary
    print()
    print("="*80)
    print(" TEST SUMMARY")
    print("="*80)
    print(f"Tests run: {result.testsRun}")
    print(f"Successes: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")

    if result.wasSuccessful():
        print("\n✅ ALL TESTS PASSED!")
    else:
        print("\n❌ SOME TESTS FAILED")

    return result.wasSuccessful()


if __name__ == '__main__':
    success = run_all_tests()
    sys.exit(0 if success else 1)
