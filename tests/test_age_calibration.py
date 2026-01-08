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
        """Test prompt generation for Preschool (Age 3-5)"""
        prompt = self.engine.generate_enhanced_prompt(
            age=4,
            **self.base_params
        )
        self.assertIn("DENSITY CHECKLIST (Age 3-5)", prompt)
        self.assertIn("300-500 words", prompt)
        self.assertIn("sound effects", prompt)
        self.assertIn("Repetitive phrase", prompt)

    def test_age_7_recipe(self):
        """Test prompt generation for Early Reader (Age 6-7)"""
        prompt = self.engine.generate_enhanced_prompt(
            age=7,
            **self.base_params
        )
        self.assertIn("DENSITY CHECKLIST (Age 6-7)", prompt)
        self.assertIn("600-900 words", prompt)
        self.assertIn("friend/helper moment", prompt)
        
    def test_age_8_recipe(self):
        """Test prompt generation for Golden Age (Age 8)"""
        prompt = self.engine.generate_enhanced_prompt(
            age=8,
            **self.base_params
        )
        self.assertIn("MAGIC DENSITY CHECKLIST (Age 8)", prompt)
        self.assertIn("1350-1650 words", prompt)
        self.assertIn("magical set pieces", prompt)
        self.assertIn("transformations", prompt)

    def test_age_10_recipe(self):
        """Test prompt generation for Pre-Teen (Age 9-12)"""
        prompt = self.engine.generate_enhanced_prompt(
            age=10,
            **self.base_params
        )
        self.assertIn("DENSITY CHECKLIST (Age 9-12)", prompt)
        self.assertIn("1800-2500 words", prompt) # For 10_minutes duration
        self.assertIn("moral dilemma", prompt)
        
    def test_age_14_recipe(self):
        """Test prompt generation for Teen (Age 13+)"""
        prompt = self.engine.generate_enhanced_prompt(
            age=14,
            **self.base_params
        )
        self.assertIn("DENSITY CHECKLIST (Age 13+)", prompt)
        self.assertIn("2500+ words", prompt) # For 10_minutes duration
        self.assertIn("introspection", prompt.lower()) # "Deep character introspection"

    def test_short_duration_defaults(self):
        """Test that shorter duration reduces word counts"""
        params = self.base_params.copy()
        params["story_duration"] = "5_minutes"
        
        # Test Age 8 with 5 minutes
        prompt = self.engine.generate_enhanced_prompt(
            age=8,
            **params
        )
        # Should be less than the 1350-1650 range
        self.assertIn("800-1000 words", prompt)

if __name__ == '__main__':
    unittest.main()
