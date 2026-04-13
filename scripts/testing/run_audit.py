import os
import sys
import json
import logging

# Ensure root is in path
sys.path.append(os.getcwd())

# Import using full package path to satisfy relative imports inside backend
from backend.services.story_service import (
    AdvancedStoryEngine,
    _build_learning_to_read_prompt,
    _build_rhyme_time_prompt
)
from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder

# Configure logging to file
logging.basicConfig(
    filename='audit_samples_output.txt',
    level=logging.INFO,
    format='%(message)s',
    filemode='w'
)

AGES = [5, 7, 9, 11, 13, 15, 17]
THEME = "The Lost Key" # Consistent theme for comparison
CHARACTER_NAME = "Alex"

def generate_samples():
    print("🚀 Starting Content Generation for Audit...")
    
    results = {}
    engine = AdvancedStoryEngine()

    for age in AGES:
        print(f"⏳ Generating for Age {age}...")
        results[age] = {}
        
        # 1. Regular Story
        try:
            print(f"   - Regular Story...")
            regular_prompt = engine.generate_enhanced_prompt(
                character=CHARACTER_NAME,
                theme=THEME,
                age=age,
                story_length="short",
                companion="Zoom the Robot"
            )
            results[age]['regular_prompt'] = regular_prompt

            # 2. Pick-a-Path Prompt
            print(f"   - Pick-a-Path...")
            pap_prompt = InteractiveAdventurePromptBuilder.build_opening_prompt(
                child_name=CHARACTER_NAME,
                age=age,
                length="short",
                theme=THEME,
                tone="adventurous"
            )
            results[age]['pap_prompt'] = pap_prompt

            # 3. Learn to Read (only relevant for younger)
            if age <= 9:
                print(f"   - Learn to Read...")
                ltr_prompt = _build_learning_to_read_prompt(
                    character_name=CHARACTER_NAME,
                    theme=THEME,
                    age=age,
                    character_details={},
                    companion="Zoom the Robot"
                )
                results[age]['ltr_prompt'] = ltr_prompt
            
            # 4. Rhyme Time
            print(f"   - Rhyme Time...")
            rhyme_prompt = _build_rhyme_time_prompt(
                character_name=CHARACTER_NAME,
                theme=THEME,
                age=age,
                character_details={}
            )
            results[age]['rhyme_prompt'] = rhyme_prompt

        except Exception as e:
            print(f"❌ Error for age {age}: {e}")
            results[age]['error'] = str(e)

    # Save results to file
    with open('audit_prompts_dump.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print("✅ Generation Complete. Saved to audit_prompts_dump.json")

if __name__ == "__main__":
    generate_samples()