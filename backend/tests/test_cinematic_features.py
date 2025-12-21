
import unittest
import sys
import os

# Add backend to path to allow imports
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

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
                "description": "A cheerful boy who loves gum."
            }
        ]
        
        # Spark Tool
        spark_tool = "Pocket Thunderbell"
        
        # Mood Physics
        mood_physics = {
            "mood": "Stormy",
            "worldRule": "Gravity is wobbly when thunder rolls.",
            "sensoryChange": "Static makes hair stand up."
        }
        
        # Character Details with Special Ability
        character_details = {
            "specialAbility": "Can jump over clouds"
        }

        # Generate Prompt
        prompt = self.engine.generate_enhanced_prompt(
            character=character_name,
            theme=theme,
            companion_characters=companion_characters,
            spark_tool=spark_tool,
            mood_physics=mood_physics,
            character_details=character_details
        )

        print("\n--- GENERATED PROMPT SNIPPET ---\n")
        print(prompt)
        print("\n--------------------------------\n")

        # Assertions
        
        # 1. Spark Tool Verification
        self.assertIn("✨ SPARK TOOL: Pocket Thunderbell", prompt)
        self.assertIn("MUST be used EXACTLY ONCE", prompt)

        # 2. Mood Physics Verification
        self.assertIn("🌍 MOOD PHYSICS (Stormy)", prompt)
        self.assertIn("Gravity is wobbly when thunder rolls", prompt)
        self.assertIn("Static makes hair stand up", prompt)

        # 3. Companion Details Verification
        self.assertIn("Barnaby", prompt)
        self.assertIn("⭐️ MAGICAL COMPANION", prompt)
        self.assertIn("SIGNATURE POWER: Bubble Shield", prompt)
        self.assertIn("CONSTRAINT: Pops if he laughs", prompt)
        self.assertIn("SENSORY TELL: Smell of bubblegum", prompt)

        # 4. Three-Key Lock Verification
        self.assertIn("🔐 THE 'THREE-KEY LOCK' CLIMAX RULE", prompt)
        self.assertIn("1. The Hero's Signature Move: Can jump over clouds", prompt)
        # Note checks for parts of the companion instruction
        self.assertIn("2. The Companion's Unique Power/Help", prompt)
        self.assertIn("3. The Setting/Spark Tool", prompt)

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
            sensory_palette=sensory_palette
        )

        # Assertions
        self.assertIn("📍 SCENARIO DETAILS:", prompt)
        self.assertIn(f"- INCITING CONFLICT: {conflict_hook}", prompt)
        self.assertIn(f"- SENSORY PALETTE: {sensory_palette}", prompt)

    def test_story_length(self):
        # Test Data
        character_name = "Leo"
        theme = "The Quick Adventure"
        
        # Test 'quick' length
        prompt_quick = self.engine.generate_enhanced_prompt(
            character=character_name,
            theme=theme,
            story_length='quick'
        )
        self.assertIn("Approx. 300-400 words", prompt_quick)
        
        # Test 'epic' length
        prompt_epic = self.engine.generate_enhanced_prompt(
            character=character_name,
            theme=theme,
            story_length='epic'
        )
        self.assertIn("Approx. 1000-1200 words", prompt_epic)
        
        # Test 'standard' (default) length
        prompt_standard = self.engine.generate_enhanced_prompt(
            character=character_name,
            theme=theme,
            story_length='standard'
        )
        self.assertIn("Approx. 600-800 words", prompt_standard)


if __name__ == '__main__':
    unittest.main()
