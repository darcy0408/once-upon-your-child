
import sys
import os

# Add project root to path
sys.path.append(os.getcwd())

try:
    from backend.services.story_service import AdvancedStoryEngine
    print("Import successful.")
except Exception as e:
    print(f"Import failed: {e}")
    sys.exit(1)

def test_generation():
    engine = AdvancedStoryEngine()
    print("Engine initialized.")
    
    try:
        prompt = engine.generate_enhanced_prompt(
            character="Toby",
            theme="Adventure",
            age=5,
            story_length="standard",
            character_details={"specialAbility": "Wind Command"}
        )
        print("Prompt generation successful.")
        print(prompt[:200])
    except Exception as e:
        print(f"Error calling generate_enhanced_prompt: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_generation()
