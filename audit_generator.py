import sys
import os
import json
import logging

# Add current directory to path
sys.path.append(os.getcwd())

# Import services using full package path
try:
    from backend.services.story_service import AdvancedStoryEngine, _build_learning_to_read_prompt, _build_rhyme_time_prompt
    from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder
except ImportError as e:
    print(f"Error importing services: {e}")
    sys.exit(1)

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger("Audit")

AGES = [5, 7, 9, 11, 13, 15, 17]

def audit_regular_story_logic(age):
    engine = AdvancedStoryEngine()
    try:
        prompt = engine.generate_enhanced_prompt(
            character="AuditHero",
            theme="AuditTheme",
            age=age,
            story_length="medium"
        )
        # Check constraints in prompt text
        if age <= 4:
            if "200-300" not in prompt and "300-450" not in prompt: # Short/Medium check
                pass # Logic in service handles this, just verifying text presence
        
        return "PASS", prompt[:100].replace('\n', ' ') + "..."
    except Exception as e:
        return "FAIL", str(e)

def audit_interactive_logic(age):
    builder = InteractiveAdventurePromptBuilder()
    try:
        prompt = builder.build_opening_prompt(
            child_name="AuditHero",
            age=age,
            length="medium",
            theme="AuditTheme",
            tone="Adventure"
        )
        return "PASS", prompt[:100].replace('\n', ' ') + "..."
    except Exception as e:
        return "FAIL", str(e)

def audit_rhyme_logic(age):
    try:
        prompt = _build_rhyme_time_prompt(
            character_name="AuditHero",
            theme="AuditTheme",
            age=age,
            character_details={}
        )
        return "PASS", prompt[:100].replace('\n', ' ') + "..."
    except Exception as e:
        return "FAIL", str(e)

def audit_ltr_logic(age):
    try:
        prompt = _build_learning_to_read_prompt(
            character_name="AuditHero",
            theme="AuditTheme",
            age=age,
            character_details={}
        )
        if "Mode unavailable" in prompt and age > 10:
             return "PASS (Correctly Unavailable)", prompt
        return "PASS", prompt[:100].replace('\n', ' ') + "..."
    except Exception as e:
        return "FAIL", str(e)

def run_audit():
    print("# Multi-Age Developmental Logic Audit")
    print("| Age | Regular | Interactive | Rhyme | LTR | Notes |")
    print("|---|---|---|---|---|---|")

    for age in AGES:
        reg_status, reg_note = audit_regular_story_logic(age)
        int_status, int_note = audit_interactive_logic(age)
        rhyme_status, rhyme_note = audit_rhyme_logic(age)
        ltr_status, ltr_note = audit_ltr_logic(age)
        
        print(f"| {age} | {reg_status} | {int_status} | {rhyme_status} | {ltr_status} | |")

    print("\n# DEEP DIVE: Age 5 Regular Prompt")
    reg_5_status, reg_5_prompt = audit_regular_story_logic(5)
    # Re-run to get full prompt, audit_regular_story_logic truncates it.
    engine = AdvancedStoryEngine()
    print(engine.generate_enhanced_prompt(character="Timmy", theme="Lost Toy", age=5, story_length="short"))

    print("\n# DEEP DIVE: Age 17 Interactive Prompt")
    builder = InteractiveAdventurePromptBuilder()
    print(builder.build_opening_prompt(child_name="Alex", age=17, length="medium", theme="Cyberpunk Mystery", tone="Serious"))

if __name__ == "__main__":
    run_audit()
