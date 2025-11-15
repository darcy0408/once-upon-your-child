from flask import Blueprint, request, jsonify
import logging
import os
import json
import re
from backend.services.story_generation_service import StoryGenerationService
from backend.services.prompt_service import PromptService
from backend.services.emotion_service import EmotionService
from backend.models.character import Character # For multi-character story
from backend.database import db # For multi-character story

story_bp = Blueprint('story', __name__)
logger = logging.getLogger("story_engine")

story_generation_service = StoryGenerationService()

_TITLE_RE = re.compile(r'\[TITLE:\s*(.*?)\s*\]', re.DOTALL)
_GEM_RE = re.compile(r'\[WISDOM GEM:\s*(.*?)\s*\]', re.DOTALL)

def _safe_extract_title_and_gem(text: str, theme: str):
    title_match = _TITLE_RE.search(text or "")
    gem_match = _GEM_RE.search(text or "")
    title = title_match.group(1).strip() if title_match and title_match.group(1) else "A Brave Little Adventure"
    wisdom_gem = gem_match.group(1).strip() if gem_match and gem_match.group(1) else "Always be kind." # Fallback
    story_body = _TITLE_RE.sub("", text or "").strip()
    story_body = _GEM_RE.sub("", story_body).strip()
    return title, wisdom_gem, story_body

@story_bp.route("/get-story-themes", methods=["GET"])
def get_story_themes():
    return jsonify(["Adventure", "Friendship", "Magic", "Dragons", "Castles", "Unicorns", "Space", "Ocean"])

@story_bp.route("/generate-story", methods=["POST"])
def generate_story_endpoint():
    payload = request.get_json(silent=True) or {}
    character_name = payload.get("character", "a brave adventurer")
    theme = payload.get("theme", "Adventure")
    companion = payload.get("companion")
    learning_to_read_mode = payload.get("learning_to_read_mode", False)
    character_age = payload.get("character_age", 7) # Assuming age is passed
    current_feeling = EmotionService.extract_current_feeling(payload)

    prompt = PromptService.build_story_prompt(
        character=character_name,
        theme=theme,
        age=character_age,
        companion=companion,
        current_feeling=current_feeling,
        learning_to_read_mode=learning_to_read_mode,
    )
    try:
        story_text = story_generation_service.generate_story(prompt)
        title, wisdom_gem, story_body = _safe_extract_title_and_gem(story_text, theme)
        return jsonify({"title": title, "story_text": story_body, "wisdom_gem": wisdom_gem}), 200

    except Exception as e:
        logger.warning("Model error, using fallback: %s", e)
        raw_text = (
            "[TITLE: An Unexpected Adventure]\n"
            "Once upon a time, a brave hero discovered that the greatest adventures come from "
            "facing our fears with courage and kindness.\n"
            "[WISDOM GEM: Always be kind.]"
        )
        title, wisdom_gem, story_body = _safe_extract_title_and_gem(raw_text, theme)
        return jsonify({"title": title, "story_text": story_body, "wisdom_gem": wisdom_gem}), 200

@story_bp.route("/generate-multi-character-story", methods=["POST"])
def generate_multi_character_story():
    data = request.get_json(silent=True) or {}
    character_ids = data.get("character_ids", [])
    main_character_id = data.get("main_character_id")
    theme = data.get("theme", "Friendship")
    learning_to_read_mode = data.get("learning_to_read_mode", False)
    current_feeling = EmotionService.extract_current_feeling(data)

    if not main_character_id or not character_ids:
        return jsonify({"error": "main_character_id and character_ids are required"}), 400

    chars = db.session.query(Character).filter(Character.id.in_(character_ids)).all()
    main_char_db = next((c for c in chars if c.id == main_character_id), None)
    if not main_char_db:
        return jsonify({"error": "Main character not found in the provided list"}), 400

    friends = [c.to_dict() for c in chars if c.id != main_character_id]
    main_char = main_char_db.to_dict()

    prompt = PromptService.build_story_prompt(
        character=main_char["name"],
        theme=theme,
        age=main_char["age"],
        companion=None, # Multi-character stories don't typically have a separate companion field
        current_feeling=current_feeling,
        learning_to_read_mode=learning_to_read_mode,
        character_details=main_char, # Pass main character details
        # additional_characters=[f['name'] for f in friends] # This needs to be handled in prompt service
    )

    try:
        story_text = story_generation_service.generate_story(prompt)
        # Multi-character stories don't have explicit title/wisdom gem extraction in the old code
        # For now, just return the story text
        return jsonify({"story": story_text}), 200
    except Exception as e:
        logger.warning("Multi-character story model error: %s", e)
        story_text = (f"{main_char['name']} and their friends went on a wonderful adventure, "
                      "learning that teamwork is best.")
        return jsonify({"story": story_text}), 200

@story_bp.route("/generate-interactive-story", methods=["POST"])
def generate_interactive_story():
    """
    Generate the FIRST segment of an interactive choose-your-own-adventure story.
    Returns: story text + 2-3 meaningful choices for the child to make
    """
    data = request.get_json(silent=True) or {}
    character_name = data.get("character", "Hero")
    theme = data.get("theme", "Adventure")
    companion = data.get("companion", "None")
    friends = data.get("friends", [])
    therapeutic_prompt = data.get("therapeutic_prompt", "")

    logger.info(f"Starting interactive story for {character_name}, theme={theme}")

    # Build the prompt for the initial story segment
    prompt_parts = [
        "You are a master storyteller creating an INTERACTIVE choose-your-own-adventure story for a child.",
        "This is the BEGINNING of the story. Create an engaging opening that sets up a meaningful choice.",
        "",
        f"STORY DETAILS:",
        f"- Main character: {character_name}",
        f"- Theme: {theme}",
    ]

    if companion and companion.lower() != "none":
        prompt_parts.append(f"- Companion: {companion}")

    if friends:
        friend_names = ", ".join(friends)
        prompt_parts.append(f"- Friends joining: {friend_names}")

    if therapeutic_prompt:
        prompt_parts.append(f"\nTHERAPEUTIC GOAL: {therapeutic_prompt}")

    prompt_parts.extend([
        "",
        "INSTRUCTIONS:",
        "1. Write an engaging story opening (3-4 paragraphs)",
        "2. Set up a situation where the character faces an important decision",
        "3. End with: 'What should [character name] do?'",
        "",
        "Then provide EXACTLY 3 choices in this format:",
        "CHOICE 1: [description]",
        "CHOICE 2: [description]",
        "CHOICE 3: [description]",
        "",
        "Make each choice lead to different outcomes (brave, thoughtful, creative)",
        "Keep language appropriate for children ages 5-10",
        "Be encouraging and positive",
        "",
        "Begin the story now:"
    ])

    prompt = "\n".join(prompt_parts)

    try:
        full_text = story_generation_service.generate_story(prompt)

        # Parse the response to extract story text and choices
        story_text, choices = _parse_interactive_response(full_text, character_name)

        result = {
            "text": story_text,
            "choices": choices,
            "is_ending": False
        }

        logger.info(f"Generated interactive story start with {len(choices)} choices")
        return jsonify(result), 200

    except Exception as e:
        logger.error(f"Interactive story generation error: {e}")
        # Fallback
        fallback_story = f"{character_name} stood at the edge of a magical forest. A glowing path led deeper into the trees, while a friendly bird chirped nearby, as if inviting them to follow. What should {character_name} do?"
        fallback_choices = [
            {"text": "Follow the glowing path into the forest"},
            {"text": "Talk to the friendly bird first"},
            {"text": "Look around carefully before deciding"}
        ]
        return jsonify({
            "text": fallback_story,
            "choices": fallback_choices,
            "is_ending": False
        }), 200


@story_bp.route("/continue-interactive-story", methods=["POST"])
def continue_interactive_story():
    """
    Continue an interactive story based on the user's choice.
    Tracks story history to maintain context.
    """
    data = request.get_json(silent=True) or {}
    character_name = data.get("character", "Hero")
    theme = data.get("theme", "Adventure")
    companion = data.get("companion", "None")
    friends = data.get("friends", [])
    choice_made = data.get("choice", "")
    story_so_far = data.get("story_so_far", "")
    choices_made = data.get("choices_made", [])
    therapeutic_prompt = data.get("therapeutic_prompt", "")

    # Determine if this should be the ending
    num_choices_made = len(choices_made)
    is_final_segment = num_choices_made >= 2  # End after 3 choices (2 previous + this one)

    logger.info(f"Continuing interactive story (choice #{num_choices_made + 1}): {choice_made[:50]}")

    prompt_parts = [
        "You are continuing an INTERACTIVE choose-your-own-adventure story for a child.",
    ]

    if is_final_segment:
        prompt_parts.append("This is the FINAL segment. Bring the story to a satisfying and uplifting conclusion.")
    else:
        prompt_parts.append("Continue the story and present the next important choice.")

    prompt_parts.extend([
        "",
        f"STORY SO FAR:",
        story_so_far[:1500],  # Limit context size
        "",
        f"PREVIOUS CHOICES MADE:",
    ])

    for i, past_choice in enumerate(choices_made, 1):
        prompt_parts.append(f"{i}. {past_choice}")

    prompt_parts.extend([
        "",
        f"CURRENT CHOICE: {choice_made}",
        "",
        f"CHARACTER: {character_name}",
        f"THEME: {theme}",
    ])

    if companion and companion.lower() != "none":
        prompt_parts.append(f"COMPANION: {companion}")

    if therapeutic_prompt:
        prompt_parts.append(f"THERAPEUTIC GOAL: {therapeutic_prompt}")

    if is_final_segment:
        prompt_parts.extend([
            "",
            "INSTRUCTIONS FOR ENDING:",
            f"1. Show the consequences of {character_name}'s choice: {choice_made}",
            "2. Bring the story to a heartwarming, satisfying conclusion (2-3 paragraphs)",
            "3. Include a positive message or lesson learned",
            f"4. Make {character_name} feel proud of their choices",
            "5. End with: 'THE END'",
            "",
            "Write the final part of the story now:"
        ])
    else:
        prompt_parts.extend([
            "",
            "INSTRUCTIONS:",
            f"1. Show what happens because of the choice: {choice_made}",
            "2. Continue the adventure (2-3 paragraphs)",
            "3. Present a NEW decision point",
            "4. End with: 'What should [character name] do next?'",
            "",
            "Then provide EXACTLY 3 new choices in this format:",
            "CHOICE 1: [description]",
            "CHOICE 2: [description]",
            "CHOICE 3: [description]",
            "",
            "Continue the story now:"
        ])

    prompt = "\n".join(prompt_parts)

    try:
        full_text = story_generation_service.generate_story(prompt)

        if is_final_segment:
            # Final segment - no choices, just ending
            story_text = full_text.replace("THE END", "").strip()
            result = {
                "text": story_text,
                "choices": [],
                "is_ending": True
            }
        else:
            # Continue segment - parse choices
            story_text, choices = _parse_interactive_response(full_text, character_name)
            result = {
                "text": story_text,
                "choices": choices,
                "is_ending": False
            }

        logger.info(f"Continued interactive story (ending={is_final_segment})")
        return jsonify(result), 200

    except Exception as e:
        logger.error(f"Continue interactive story error: {e}")
        # Fallback
        if is_final_segment:
            fallback = f"And so, {character_name}'s wonderful adventure came to an end. They learned that every choice they made helped them grow braver and wiser. The End!"
            return jsonify({
                "text": fallback,
                "choices": [],
                "is_ending": True
            }), 200
        else:
            fallback = f"{character_name} continued their journey. What should {character_name} do next?"
            fallback_choices = [
                {"text": "Keep going forward bravely"},
                {"text": "Take a moment to think"},
                {"text": "Ask for help from a friend"}
            ]
            return jsonify({
                "text": fallback,
                "choices": fallback_choices,
                "is_ending": False
            }), 200


def _parse_interactive_response(full_text: str, character_name: str) -> tuple[str, list]:
    """
    Parse the AI response to extract:
    1. Story text (everything before choices)
    2. List of choices

    Returns: (story_text, choices_list)
    """
    choices = []
    story_text = full_text

    # Look for choice patterns
    import re

    # Try to find choices in format "CHOICE 1:", "CHOICE 2:", etc.
    choice_pattern = r'CHOICE \d+:\s*(.+?)(?=CHOICE \d+:|$)'
    found_choices = re.findall(choice_pattern, full_text, re.IGNORECASE | re.DOTALL)

    if found_choices:
        # Extract story text (everything before first CHOICE)
        story_parts = re.split(r'CHOICE \d+:', full_text, flags=re.IGNORECASE)
        story_text = story_parts[0].strip()

        # Clean up choices
        for choice_text in found_choices:
            cleaned = choice_text.strip().split('\n')[0]  # Take first line only
            if cleaned:
                choices.append({"text": cleaned})

    # If we didn't find exactly 3 choices, provide defaults
    if len(choices) != 3:
        logger.warning(f"Expected 3 choices, found {len(choices)}, using defaults")
        choices = [
            {"text": "Choose the brave path"},
            {"text": "Choose the thoughtful path"},
            {"text": "Choose the creative path"}
        ]

    # Limit to 3 choices
    choices = choices[:3]

    return story_text, choices