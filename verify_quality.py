import os
import sys
import textwrap
# Add project root to path
sys.path.append(os.getcwd())

from backend.services.story_service import AdvancedStoryEngine

def test_story_quality():
    print("✨ STARTING QUALITY CHECK: 'DELIGHT FACTOR' ✨")
    
    engine = AdvancedStoryEngine()
    
    # 1. Generate the Prompt using the new config
    prompt = engine.generate_enhanced_prompt(
        character="Leo",
        age=5,
        theme="The Giggling Garden",
        companion_pets=[{"name": "Sparky", "species": "Dragon"}],
        story_length="short", # Should trigger 450-650 words for Age 5-7
        custom_elements="The flowers tell jokes",
        therapeutic_prompt="Leo is feeling a bit shy about making friends.",
        feelings_prompt="Shy, looking down, holding tummy."
    )
    
    print("\n📋 1. VERIFYING PROMPT INSTRUCTIONS:")
    print("-" * 50)
    
    # Check for specific instructions we injected
    checks = {
        "Delight/Readability": "Simple vocabulary with occasional new words", 
        "Word Count": "450-650 words",
        "Companion Contract": "Sparky the Dragon MUST appear by name",
        "Therapeutic": "coping moment in action",
        "Magic": "magical surprise"
    }
    
    for label, phrase in checks.items():
        if phrase in prompt:
            print(f"✅ {label}: CONFIRMED")
        else:
            print(f"❌ {label}: MISSING (Check config!)")
            
    print("-" * 50)
    print("\n📝 2. GENERATED PROMPT PREVIEW (The Recipe for Magic):")
    print(textwrap.shorten(prompt, width=500, placeholder="..."))

if __name__ == "__main__":
    test_story_quality()
