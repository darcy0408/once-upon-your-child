import textwrap
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.append(REPO_ROOT)

from backend.services.interactive_adventure_prompt_builder import (
    InteractiveAdventurePromptBuilder,
)


CASES = [
    {
        "label": "mad",
        "child_name": "Milo",
        "context": {
            "current_feeling": {"emotion_name": "Mad"},
            "trigger": "someone said no",
            "body_signal": "hot face",
            "coping_tool": "Take a dragon breath",
            "repair_goal": "say sorry",
            "parent_hidden_context": "trouble hearing no",
        },
        "selected_choice": "Roar, then stop",
        "story_so_far": "You felt so mad. Someone said no. Your face got hot. Pip stayed close.",
    },
    {
        "label": "sad",
        "child_name": "Lila",
        "context": {
            "current_feeling": {"emotion_name": "Sad"},
            "trigger": "lost something",
            "body_signal": "tears",
            "coping_tool": "Ask for a hug",
            "repair_goal": "try again",
            "parent_hidden_context": "friendship hurt",
        },
        "selected_choice": "Tell someone you feel sad",
        "story_so_far": "You felt so sad. Something important was gone. Bunny listened.",
    },
    {
        "label": "scared",
        "child_name": "Owen",
        "context": {
            "current_feeling": {"emotion_name": "Scared"},
            "trigger": "the room got dark",
            "body_signal": "fast heart",
            "coping_tool": "Hold hands",
            "repair_goal": "ask for help",
            "parent_hidden_context": "bedtime worry",
        },
        "selected_choice": "Take a slow breath",
        "story_so_far": "You felt so scared. The room got dark. Star glowed beside you.",
    },
]


def _extract_lines(prompt: str) -> list[str]:
    keep_prefixes = (
        "- Opening style example:",
        "- Trigger:",
        "- Weave the trigger",
        "- Body clue to mention early:",
        "- Helper/tool to thread through choices:",
        "- If the hero causes a bump",
        "  - In the first paragraph,",
        "  - For mad stories,",
        "  - For sad or scared stories,",
        '    {"id": "choice_1"',
        '    {"id": "choice_2"',
    )
    return [line for line in prompt.splitlines() if line.startswith(keep_prefixes)]


def _print_case(case: dict) -> None:
    child_name = case["child_name"]
    big_feelings_context = case["context"]

    opening_prompt = InteractiveAdventurePromptBuilder.build_opening_prompt(
        child_name=child_name,
        age=4,
        length="short",
        theme="big_feelings_quest",
        tone="gentle",
        character={"name": child_name},
        companions=[{"name": "Pip"}],
        big_feelings_context=big_feelings_context,
    )
    continuation_prompt = InteractiveAdventurePromptBuilder.build_continuation_prompt(
        story_context={
            "title": f"{child_name} and the Big {case['label'].title()}",
            "theme": "big_feelings_quest",
            "tone": "gentle",
            "length": "short",
            "age": 4,
            "character": {"name": child_name},
            "companions": [{"name": "Pip"}],
            "big_feelings_context": big_feelings_context,
        },
        selected_choice=case["selected_choice"],
        current_segment_number=1,
        inventory=[],
        story_state={
            "location": "playroom",
            "goal": "feel better",
            "key_clues": [],
            "companion_status": "Pip stays close",
        },
        story_so_far=case["story_so_far"],
    )

    print(f"\n=== {case['label'].upper()} ===")
    print("\nOpening prompt review:")
    print(textwrap.indent("\n".join(_extract_lines(opening_prompt)), "  "))
    print("\nContinuation prompt review:")
    print(textwrap.indent("\n".join(_extract_lines(continuation_prompt)), "  "))


if __name__ == "__main__":
    print("Big Feelings Prompt Review")
    print("==========================")
    print("Local prompt-only QA for preschool interactive Big Feelings stories.")
    for case in CASES:
        _print_case(case)
