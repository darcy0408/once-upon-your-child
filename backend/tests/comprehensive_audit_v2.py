import sys
import os
import unittest
import re

# Add backend to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from backend.services.story_service import AdvancedStoryEngine, AGE_CONSTRAINTS, _build_learning_to_read_prompt, _build_rhyme_time_prompt
from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder

class TestStoryAuditVariations(unittest.TestCase):
    def setUp(self):
        self.engine = AdvancedStoryEngine()
        self.maxDiff = None  # Show full diffs on failure

    def verify_prompt_contains(self, prompt, keywords, msg=None):
        """Helper to assert keywords exist in prompt."""
        for k in keywords:
            self.assertIn(k, prompt, msg or f"Missing keyword: {k}")

    def verify_prompt_excludes(self, prompt, keywords, msg=None):
        """Helper to assert keywords do NOT exist in prompt."""
        for k in keywords:
            self.assertNotIn(k, prompt, msg or f"Found forbidden keyword: {k}")

    # =========================================================================
    # 1. GENDER & PRONOUN SPECIFICITY
    # =========================================================================
    def test_gender_inclusion(self):
        """Audit: Does the prompt actually tell the AI the character's gender?"""
        # Many AI models default "Sam" to male or generic. We want explicit gender if provided.
        char_details = {'gender': 'Girl', 'pronouns': 'She/Her', 'strengths': ['Fast']}
        prompt = self.engine.generate_enhanced_prompt(
            character="Sam", age=8, theme="Sports", character_details=char_details
        )
        
        # This test checks if we are effectively communicating gender
        # Current code analysis suggests we might NOT be. 
        try:
            self.verify_prompt_contains(prompt, ["Girl", "She/Her"], "Prompt should include explicit gender/pronouns if provided.")
        except AssertionError:
            print("\n[AUDIT FINDING] Gender not passed to prompt! Fixing...")
            raise

    # =========================================================================
    # 2. TONE STRESS TEST: "SCARY" THEMES (Age 5 vs 15)
    # =========================================================================
    def test_age_5_scary_theme_safety(self):
        """Audit: Age 5 'Haunted House' must be gentle."""
        prompt = self.engine.generate_enhanced_prompt(
            character="Tiny", age=5, theme="Haunted House", story_length="short"
        )
        self.verify_prompt_contains(prompt, [
            "Ensure NO scary imagery",
            "Safe, therapeutic tone",
            "gentle magical surprise" 
        ])
        # Should not encourage "Plot Twist" or "Tension"
        self.verify_prompt_excludes(prompt, ["psychological tension", "clever plot twist"])

    def test_age_15_scary_theme_maturity(self):
        """Audit: Age 15 'Haunted House' should allow atmosphere."""
        # Age 15 is now in the '15-18' band (Complex Stakes)
        prompt = self.engine.generate_enhanced_prompt(
            character="Alex", age=15, theme="Haunted House", story_length="medium"
        )
        self.verify_prompt_contains(prompt, [
            "Complex stakes",
            "clever plot twist",
            "moment of wonder"
        ])
        # Should allow for internal monologue
        self.verify_prompt_contains(prompt, ["internal monologue"])

    # =========================================================================
    # 3. COMPLEX COMPANIONS (Pets + Friends)
    # =========================================================================
    def test_mixed_companions(self):
        """Audit: Handling a Pet AND a Friend simultaneously."""
        pets = [{'name': 'Rex', 'species': 'Dino', 'type': 'pet'}]
        friends = [{'name': 'Maya', 'signaturePower': 'Invisibility'}]
        
        prompt = self.engine.generate_enhanced_prompt(
            character="Hero", age=10, theme="Quest", 
            companion_pets=pets, companion_characters=friends
        )
        
        self.verify_prompt_contains(prompt, [
            "Rex the Dino [ANIMAL]",
            "Maya (Power: Invisibility) [SPEAKING]",
            "MUST appear by name"
        ])

    # =========================================================================
    # 4. INTERACTIVE ENDING LOGIC
    # =========================================================================
    def test_interactive_ending_injection(self):
        """Audit: Does Pick-a-Path know when to end?"""
        # Age 10, Medium length -> Depth is 7 (from PATH_DEPTHS)
        # If we are at segment 6, it should suggest ending.
        
        context = {'age': 10, 'length': 'medium', 'title': 'Test'}
        prompt = InteractiveAdventurePromptBuilder.build_continuation_prompt(
            story_context=context,
            selected_choice="Go Left",
            current_segment_number=6, # 6 of 7
            inventory=[],
            story_state={}
        )
        
        self.verify_prompt_contains(prompt, [
            "ENDING LOGIC",
            "conclude the story",
            "segment 7/7" # 6+1 = 7
        ])

if __name__ == '__main__':
    unittest.main()
