import os
import sys
import unittest

# Add backend to path to allow imports
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from backend.services.story_service import AdvancedStoryEngine


class TestCinematicFeatures(unittest.TestCase):
    def setUp(self):
        self.engine = AdvancedStoryEngine()

    def test_cinematic_prompt_generation(self):
        # Test Data
        character_name = "Leo"
        theme = "The Lost City"

        # Enhanced Companion Data
        companion_characters = [
            {
                "name": "Barnaby",
                "role": "Best Friend",
                "signaturePower": "Bubble Shield",
                "powerConstraint": "Pops if he laughs",
                "sensoryTell": "Smell of bubblegum",
                "description": "A cheerful boy who loves gum.",
            }
        ]

        # Spark Tool
        spark_tool = "Pocket Thunderbell"

        # Mood Physics
        mood_physics = {
            "mood": "Stormy",
            "worldRule": "Gravity is wobbly when thunder rolls.",
            "sensoryChange": "Static makes hair stand up.",
        }

        # Character Details with Special Ability
        character_details = {"specialAbility": "Can jump over clouds"}

        # Generate Prompt
        prompt = self.engine.generate_enhanced_prompt(
            character=character_name,
            theme=theme,
            companion_characters=companion_characters,
            spark_tool=spark_tool,
            mood_physics=mood_physics,
            character_details=character_details,
        )

        # Assertions
        self.assertIn("HERO TOOL", prompt)
        self.assertIn("Pocket Thunderbell", prompt)
        self.assertIn("MUST be used exactly once", prompt)
        self.assertIn("WORLD PHYSICS (Mood: Stormy)", prompt)
        self.assertIn("Gravity is wobbly when thunder rolls", prompt)
        self.assertIn("Static makes hair stand up", prompt)
        self.assertIn("Barnaby", prompt)
        self.assertIn("Bubble Shield", prompt)  # companion power present in prompt

    def test_scenario_details(self):
        # Test Data
        character_name = "Maya"
        theme = "The Doorway Between Seasons"
        conflict_hook = "Must navigate through changing seasons to find the way home"
        sensory_palette = "Swirling leaves, crisp breezes, changing temperatures"

        # Generate Prompt
        prompt = self.engine.generate_enhanced_prompt(
            character=character_name,
            theme=theme,
            conflict_hook=conflict_hook,
            sensory_palette=sensory_palette,
        )

        # Assertions
        self.assertIn("**STORY SPECS**:", prompt)
        self.assertIn(f"- **CONFLICT**: {conflict_hook}", prompt)
        self.assertIn(
            "- **SENSORY PALETTE** (atmosphere seasoning — flavor scenes with it, "
            "but it must never drive the plot, and its wording must never be "
            "copied into the story text verbatim — reimagine the images in "
            f"your own words): {sensory_palette}",
            prompt,
        )

    def test_story_length(self):
        # Test Data
        character_name = "Leo"
        theme = "The Quick Adventure"

        # Default age is 5 (Sprout), whose word count is page-based and capped
        # at the ≤300-word picture-book ceiling (short=8, medium=10, long=12
        # pages × 12-25 words/page). The length tier must still move the count,
        # and the stated range must AGREE with the 300 ceiling rather than
        # contradict it as the old regular-band ranges did.

        # Test 'quick' length
        prompt_quick = self.engine.generate_enhanced_prompt(
            character=character_name, theme=theme, story_length="quick"
        )
        self.assertIn("Approximately 96-200 words", prompt_quick)

        # Test 'epic' length
        prompt_epic = self.engine.generate_enhanced_prompt(
            character=character_name, theme=theme, story_length="epic"
        )
        self.assertIn("Approximately 144-300 words", prompt_epic)

        # Test 'standard' (default) length
        prompt_standard = self.engine.generate_enhanced_prompt(
            character=character_name, theme=theme, story_length="standard"
        )
        self.assertIn("Approximately 120-250 words", prompt_standard)


if __name__ == "__main__":
    unittest.main()
