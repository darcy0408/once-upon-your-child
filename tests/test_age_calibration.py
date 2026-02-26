import unittest
import sys
import os

# Ensure backend package is importable
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from backend.services.story_service import AdvancedStoryEngine

class TestAgeCalibration(unittest.TestCase):
    def setUp(self):
        self.engine = AdvancedStoryEngine()
        self.base_params = {
            "character": "Hero",
            "theme": "Adventure",
            "story_length": "standard", # This is the legacy param
            "story_duration": "10_minutes" # This is the new param we want to test
        }

    def test_age_4_recipe(self):
        """Test prompt generation for Preschool (Age 3-4)"""
        prompt = self.engine.generate_enhanced_prompt(
            age=4,
            **self.base_params
        )
        self.assertIn("300-450 words", prompt)
        self.assertIn("repetition", prompt.lower())
        self.assertIn("comforting rhythm", prompt.lower())
        self.assertIn("simple vocabulary", prompt.lower())

    def test_age_7_recipe(self):
        """Test prompt generation for Early Reader (Age 5-7)"""
        prompt = self.engine.generate_enhanced_prompt(
            age=7,
            **self.base_params
        )
        self.assertIn("650-900 words", prompt)
        self.assertIn("simple vocabulary", prompt.lower())

    def test_age_8_recipe(self):
        """Test prompt generation for Mid-Elementary (Age 8-10 band)"""
        prompt = self.engine.generate_enhanced_prompt(
            age=8,
            **self.base_params
        )
        self.assertIn("1200-1800 words", prompt)
        self.assertIn("two-part", prompt.lower())
        self.assertIn("cause-effect", prompt.lower())

    def test_age_10_recipe(self):
        """Test prompt generation for Pre-Teen (also Age 8-10 band)"""
        prompt = self.engine.generate_enhanced_prompt(
            age=10,
            **self.base_params
        )
        # Age 10 maps to the 8-10 age band
        self.assertIn("1200-1800 words", prompt)
        self.assertIn("two-part", prompt.lower())

    def test_age_14_recipe(self):
        """Test prompt generation for Teen (Age 13-15 band)"""
        prompt = self.engine.generate_enhanced_prompt(
            age=14,
            **self.base_params
        )
        self.assertIn("1800-2400 words", prompt)
        self.assertIn("identity", prompt.lower())
        self.assertIn("reflection", prompt.lower())

    def test_short_duration_defaults(self):
        """Test that age-band word count constraints are applied (duration no longer changes range)"""
        params = self.base_params.copy()
        params["story_duration"] = "5_minutes"

        # Age 8 uses the 8-10 band regardless of story_duration
        prompt = self.engine.generate_enhanced_prompt(
            age=8,
            **params
        )
        self.assertIn("1200-1800 words", prompt)
        self.assertIn("two-part", prompt.lower())

if __name__ == '__main__':
    unittest.main()
