import os
import sys
from pprint import pprint

# Ensure we're in the right package context
root_path = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, root_path)

try:
    from backend.services.story_service import (
        AdvancedStoryEngine, 
        _build_rhyme_time_prompt, 
        _build_learning_to_read_prompt
    )
    from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder
except ImportError as e:
    print(f"Error importing modules: {e}")
    sys.exit(1)

def test_story_matrix():
    ages = [4, 6, 9, 12, 14, 16, 25] 
    themes = ["Crystal Cavern", "Rainbow Land", "Volcano Dragons", "Big Feelings Quest"]
    modes = ["regular", "rhyme_time", "learning_to_read", "interactive"]
    
    problems_found = []
    
    engine = AdvancedStoryEngine()
    interactive_builder = InteractiveAdventurePromptBuilder

    for age in ages:
        for theme in themes:
            for mode in modes:
                try:
                    prompt = ""
                    char_details = {"gender": "boy", "role": "explorer"}
                    
                    if mode == "regular":
                        prompt = engine.generate_enhanced_prompt(
                            character="TestHero",
                            theme=theme,
                            age=age,
                            companion="tiny dragon",
                            character_details=char_details
                        )
                    elif mode == "rhyme_time":
                        prompt = _build_rhyme_time_prompt(
                            character_name="TestHero",
                            theme=theme,
                            age=age,
                            character_details=char_details,
                            extra_characters=[],
                            story_length="standard",
                            custom_elements=""
                        )
                    elif mode == "learning_to_read":
                        prompt = _build_learning_to_read_prompt(
                            character_name="TestHero",
                            theme=theme,
                            age=age,
                            character_details=char_details,
                            companion="tiny dragon",
                            extra_characters=[],
                            story_length="standard",
                            custom_elements=""
                        )
                    elif mode == "interactive":
                        prompt = interactive_builder.build_opening_prompt(
                            child_name="TestHero",
                            age=age,
                            length="standard",
                            theme=theme,
                            tone="Adventurous",
                            companions=[{"name": "tiny dragon", "type": "pet"}]
                        )
                    
                    if not prompt:
                        problems_found.append(f"[{age}yo | {theme} | {mode}] Prompt is EMPTY")
                        continue

                    # 1. Check for unreplaced placeholders
                    placeholders = ["{character_name}", "{theme}", "{age}", "{companion}"]
                    for p in placeholders:
                        if p in prompt:
                            problems_found.append(f"[{age}yo | {theme} | {mode}] Unreplaced variable found: {p}")

                    # 2. Check for "None" string leak (usually from optional params)
                    if "None" in prompt:
                        # Filter out known intentional "None" entries
                        lines = prompt.split('\n')
                        for line in lines:
                            if "None" in line:
                                if "Custom Requests: None" in line: continue
                                if "Companions: None" in line: continue
                                if "Inventory: None" in line: continue
                                if "Magic Tool: None" in line: continue
                                if "Invisible Virtue: None" in line: continue
                                if "Special Strength: None" in line: continue
                                if "Interests: None" in line: continue
                                if "Mood Physics: None" in line: continue
                                if "Sensory Palette: None" in line: continue
                                # If we hit here, it might be a leak
                                problems_found.append(f"[{age}yo | {theme} | {mode}] Potential 'None' leak in line: {line.strip()}")

                except Exception as e:
                    problems_found.append(f"[{age}yo | {theme} | {mode}] Exception: {str(e)}")

    print("-" * 40)
    if problems_found:
        print(f"Audit Complete! Found {len(problems_found)} potential issues:")
        for p in sorted(set(problems_found)):
            print(f" ERROR: {p}")
    else:
        print("Audit Complete! 🟢 No logic problems found in the prompt matrix.")
    print("-" * 40)

if __name__ == "__main__":
    test_story_matrix()
