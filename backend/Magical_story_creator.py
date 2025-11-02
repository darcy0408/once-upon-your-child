"""
Enhanced Interactive Children's Adventure Engine – API v2.0 (Refactor, fixed)
- Single update route, fixed /get-characters, safer parsing, same behavior.
"""

import os
import uuid
import json
import logging
import random
import re
from datetime import datetime

from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import google.generativeai as genai
from sqlalchemy.dialects.sqlite import JSON as SQLITE_JSON

# ----------------------
# Flask & DB setup
# ----------------------
app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

basedir = os.path.abspath(os.path.dirname(__file__))
app.config["SQLALCHEMY_DATABASE_URI"] = f"sqlite:///{os.path.join(basedir, 'characters.db')}"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["JSON_SORT_KEYS"] = False

db = SQLAlchemy(app)

# ----------------------
# Logging
# ----------------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("story_engine")

# ----------------------
# Database model
# ----------------------
class Character(db.Model):
    """Stores character information, traits, relationships, and metadata."""
    id = db.Column(db.String(36), primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    gender = db.Column(db.String(50))
    role = db.Column(db.String(50))
    magic_type = db.Column(db.String(50))
    challenge = db.Column(db.Text)

    # SQLite JSON (persists as TEXT)
    personality_traits = db.Column(SQLITE_JSON, default=list)
    siblings = db.Column(SQLITE_JSON, default=list)
    friends = db.Column(SQLITE_JSON, default=list)
    likes = db.Column(SQLITE_JSON, default=list)
    dislikes = db.Column(SQLITE_JSON, default=list)
    fears = db.Column(SQLITE_JSON, default=list)

    comfort_item = db.Column(db.String(200))
    created_at = db.Column(db.DateTime, default=datetime.now, index=True)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "age": self.age,
            "gender": self.gender,
            "role": self.role,
            "magic_type": self.magic_type,
            "challenge": self.challenge,
            "personality_traits": self.personality_traits or [],
            "siblings": self.siblings or [],
            "friends": self.friends or [],
            "likes": self.likes or [],
            "dislikes": self.dislikes or [],
            "fears": self.fears or [],
            "comfort_item": self.comfort_item,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

with app.app_context():
    db.create_all()

# ----------------------
# Gemini setup
# ----------------------
api_key = os.getenv("GEMINI_API_KEY")

# --- DEBUG LINES START ---
print(f"API KEY EXISTS: {bool(api_key)}")
print(f"API KEY LENGTH: {len(api_key) if api_key else 0}")
print(f"MODEL: {os.getenv('GEMINI_MODEL', 'gemini-2.5-flash')}")
# --- DEBUG LINES END ---

if not api_key:
    logger.warning("GEMINI_API_KEY not set. Generation endpoints will use fallbacks.")
else:
    genai.configure(api_key=api_key)

GEMINI_MODEL = "gemini-2.5-flash"  # Hardcoded to bypass env var issues
try:
    model = genai.GenerativeModel(GEMINI_MODEL) if api_key else None
except Exception as e:
    logger.exception("Failed to initialize Gemini model: %s", e)
    model = None

# ----------------------
# Story components
# ----------------------
class StoryStructures:
    ADVENTURE_TEMPLATES = [
        {"name": "The Quest", "structure": "Hero receives mission -> Faces obstacles -> Finds strength -> Achieves goal"},
        {"name": "The Discovery", "structure": "Hero finds something unusual -> Investigates -> Uncovers truth -> Shares wisdom"},
        {"name": "The Friendship", "structure": "Hero meets someone different -> Overcomes prejudice -> Works together -> Lasting bond"},
    ]
    PLOT_TWISTS = [
        "The villain turns out to be under a spell and needs help",
        "The treasure they seek was inside them all along",
        "Their companion reveals a magical secret",
        "A tiny creature provides the most important help",
    ]

    @classmethod
    def get_random_structure(cls, theme: str | None = None):
        if theme:
            t = theme.lower()
            if "friend" in t:
                return next((s for s in cls.ADVENTURE_TEMPLATES if s["name"] == "The Friendship"), random.choice(cls.ADVENTURE_TEMPLATES))
            if any(x in t for x in ["discover", "mystery", "secret"]):
                return next((s for s in cls.ADVENTURE_TEMPLATES if s["name"] == "The Discovery"), random.choice(cls.ADVENTURE_TEMPLATES))
        return random.choice(cls.ADVENTURE_TEMPLATES)

class CompanionDynamics:
    COMPANION_ROLES = {
        "Loyal Dog": {"contribution": "sniffs out clues and warns of danger"},
        "Mysterious Cat": {"contribution": "guides through dark places and senses magic"},
        "Mischievous Fairy": {"contribution": "unlocks small spaces and talks to creatures"},
        "Tiny Dragon": {"contribution": "provides aerial view and dragon wisdom"},
    }
    @classmethod
    def get_companion_info(cls, companion_name: str | None):
        if not companion_name:
            return None
        return cls.COMPANION_ROLES.get(companion_name, {"contribution": "provides emotional support"})

class WisdomGems:
    THEME_WISDOM = {
        "Adventure": ["The greatest adventures begin with a single brave step"],
        "Friendship": ["True friends accept you exactly as you are"],
        "Magic": ["Real magic comes from believing in yourself"],
    }
    @classmethod
    def get_wisdom(cls, theme: str | None):
        return random.choice(cls.THEME_WISDOM.get(theme, cls.THEME_WISDOM["Adventure"]))

class AdvancedStoryEngine:
    def __init__(self):
        self.story_structures = StoryStructures()
        self.companion_dynamics = CompanionDynamics()
        self.wisdom_gems = WisdomGems()

    def generate_enhanced_prompt(self, character: str, theme: str, companion: str | None):
        story_structure = self.story_structures.get_random_structure(theme)
        companion_info = self.companion_dynamics.get_companion_info(companion)
        plot_twist = random.choice(self.story_structures.PLOT_TWISTS)
        wisdom = self.wisdom_gems.get_wisdom(theme)
        parts = [
            "You are a master storyteller creating an enchanting tale for children.",
            "\nSTORY DETAILS:",
            f"- Main Character: {character}",
            f"- Theme: {theme}",
            f"- Story Structure: {story_structure['structure']}",
        ]
        if companion_info:
            parts.extend([
                f"- Companion: {companion}",
                f"- How Companion Helps: {companion_info['contribution']}",
            ])
        parts.extend([
            "\nNARRATIVE REQUIREMENTS:",
            f"1. Start with an engaging opening that introduces {character}.",
            f"2. Incorporate this plot element naturally: {plot_twist}.",
            "3. End with a satisfying resolution.",
            "\nSTORY LENGTH: Approximately 500-600 words.",
            "\nFORMAT REQUIREMENTS:",
            "- Start with: [TITLE: A Creative and Engaging Title]",
            f"- End with: [WISDOM GEM: {wisdom}]",
        ])
        return "\n".join(parts)

story_engine = AdvancedStoryEngine()

# ----------------------
# Helpers
# ----------------------
_TITLE_RE = re.compile(r"\[TITLE:\s*(.*?)\s*\]", re.DOTALL)
_GEM_RE = re.compile(r"\[WISDOM GEM:\s*(.*?)\s*\]", re.DOTALL)

def _safe_extract_title_and_gem(text: str, theme: str):
    title_match = _TITLE_RE.search(text or "")
    gem_match = _GEM_RE.search(text or "")
    title = title_match.group(1).strip() if title_match and title_match.group(1).strip() else "A Brave Little Adventure"
    wisdom_gem = gem_match.group(1).strip() if gem_match and gem_match.group(1).strip() else WisdomGems.get_wisdom(theme)
    story_body = _TITLE_RE.sub("", text or "").strip()
    story_body = _GEM_RE.sub("", story_body).strip()
    return title, wisdom_gem, story_body

def _as_list(v):
    """Accept list, JSON string, comma string, or None; return list[str]."""
    if isinstance(v, list):
        return [str(x) for x in v]
    if v in (None, "", []):
        return []
    if isinstance(v, str):
        s = v.strip()
        if not s:
            return []
        if s.startswith("[") and s.endswith("]"):
            try:
                parsed = json.loads(s)
                return [str(x) for x in parsed] if isinstance(parsed, list) else [s]
            except Exception:
                pass
        return [part.strip() for part in s.split(",") if part.strip()]
    return [str(v)]

# ----------------------
# API Routes
# ----------------------
@app.route("/health", methods=["GET"])
def health():
    return {"status": "ok", "model": GEMINI_MODEL, "has_api_key": bool(api_key)}, 200

@app.route("/get-story-themes", methods=["GET"])
def get_story_themes():
    return jsonify(["Adventure", "Friendship", "Magic", "Dragons", "Castles", "Unicorns", "Space", "Ocean"]), 200

@app.route("/generate-story", methods=["POST"])
def generate_story_endpoint():
    payload = request.get_json(silent=True) or {}
    character = payload.get("character", "a brave adventurer")
    theme = payload.get("theme", "Adventure")
    companion = payload.get("companion")

    prompt = story_engine.generate_enhanced_prompt(character, theme, companion)
    try:
        if model is None:
            raise RuntimeError("Model unavailable")
        response = model.generate_content(prompt)
        raw_text = getattr(response, "text", "")
        if not raw_text:
            raise ValueError("Empty model response")

    except Exception as e:
        print(f"!!! API ERROR: {type(e).__name__}: {str(e)}")
        logger.warning("Model error, using fallback: %s", e)
        raw_text = (
            "[TITLE: An Unexpected Adventure]\n"
            "Once upon a time, a brave hero discovered that the greatest adventures come from "
            "facing our fears with courage and kindness.\n"
            f"[WISDOM GEM: {WisdomGems.get_wisdom(theme)}]"
        )

    title, wisdom_gem, story_text = _safe_extract_title_and_gem(raw_text, theme)
    return jsonify({"title": title, "story_text": story_text, "wisdom_gem": wisdom_gem}), 200

@app.route("/create-character", methods=["POST"])
def create_character():
    data = request.get_json(silent=True) or {}
    missing = [k for k in ("name", "age") if not data.get(k)]
    if missing:
        return jsonify({"error": f"Missing required field(s): {', '.join(missing)}"}), 400
    try:
        age = int(data.get("age"))
    except (ValueError, TypeError):
        return jsonify({"error": "'age' must be an integer"}), 400

    new_character = Character(
        id=str(uuid.uuid4()),
        name=str(data.get("name")).strip(),
        age=age,
        gender=data.get("gender"),
        role=data.get("role"),
        magic_type=data.get("magic_type"),
        challenge=data.get("challenge"),
        personality_traits=_as_list(data.get("traits", [])),
        likes=_as_list(data.get("likes", [])),
        dislikes=_as_list(data.get("dislikes", [])),
        fears=_as_list(data.get("fears", [])),
        comfort_item=data.get("comfort_item"),
    )
    db.session.add(new_character)
    db.session.commit()
    return jsonify(new_character.to_dict()), 201

# ---- SINGLE update route (PATCH/PUT) ----
@app.route("/characters/<string:char_id>", methods=["PATCH", "PUT"])
def update_character(char_id: str):
    """Partial update allowed."""
    char = db.session.get(Character, char_id)
    if not char:
        return jsonify({"error": "Character not found"}), 404

    data = request.get_json(silent=True) or {}

    if "name" in data:
        char.name = (data["name"] or "").strip() or char.name
    if "age" in data:
        try:
            char.age = int(data["age"])
        except (TypeError, ValueError):
            return jsonify({"error": "'age' must be an integer"}), 400
    if "gender" in data:
        char.gender = data["gender"]
    if "role" in data:
        char.role = data["role"]
    if "magic_type" in data:
        char.magic_type = data["magic_type"]
    if "challenge" in data:
        char.challenge = data["challenge"]
    if "likes" in data:
        char.likes = _as_list(data["likes"])
    if "dislikes" in data:
        char.dislikes = _as_list(data["dislikes"])
    if "fears" in data:
        char.fears = _as_list(data["fears"])
    if "personality_traits" in data or "traits" in data:
        char.personality_traits = _as_list(data.get("personality_traits", data.get("traits", [])))
    if "siblings" in data:
        char.siblings = _as_list(data["siblings"])
    if "friends" in data:
        char.friends = _as_list(data["friends"])
    if "comfort_item" in data:
        char.comfort_item = data["comfort_item"]

    db.session.commit()
    return jsonify(char.to_dict()), 200

@app.route("/characters/<string:char_id>", methods=["DELETE"])
def delete_character(char_id: str):
    char = db.session.get(Character, char_id)
    if not char:
        return jsonify({"error": "Character not found"}), 404
    db.session.delete(char)
    db.session.commit()
    return jsonify({"status": "deleted", "id": char_id}), 200

@app.route("/get-characters", methods=["GET"])
def get_characters():
    """Return a simple LIST to match the Flutter code that expects a list."""
    chars = Character.query.order_by(Character.created_at.desc()).all()
    return jsonify([c.to_dict() for c in chars]), 200

@app.route("/characters/<string:char_id>", methods=["GET"])
def get_character(char_id: str):
    char = db.session.get(Character, char_id)
    if not char:
        return jsonify({"error": "Character not found"}), 404
    return jsonify(char.to_dict()), 200

@app.route("/generate-multi-character-story", methods=["POST"])
def generate_multi_character_story():
    data = request.get_json(silent=True) or {}
    character_ids = data.get("character_ids", [])
    main_character_id = data.get("main_character_id")
    theme = data.get("theme", "Friendship")

    if not main_character_id or not character_ids:
        return jsonify({"error": "main_character_id and character_ids are required"}), 400

    chars = Character.query.filter(Character.id.in_(character_ids)).all()
    main_char_db = next((c for c in chars if c.id == main_character_id), None)
    if not main_char_db:
        return jsonify({"error": "Main character not found in the provided list"}), 400

    friends = [c.to_dict() for c in chars if c.id != main_character_id]
    main_char = main_char_db.to_dict()

    prompt_parts = [
        "You are a master storyteller. Create an enchanting and therapeutic story for a child.",
        f"\nSTORY DETAILS:\n- Theme: {theme}",
        f"\nMAIN CHARACTER:\n- Name: {main_char['name']}\n- Age: {main_char['age']}\n- Role: {main_char.get('role','Hero')}",
        f"- A specific fear they have: {', '.join(main_char.get('fears', ['the dark']))}",
        f"- Their special comfort item: {main_char.get('comfort_item', 'a cozy blanket')}",
    ]
    if friends:
        prompt_parts.append("\nFRIENDS FEATURED IN THE STORY:")
        for friend in friends:
            prompt_parts.append(f"- Friend Name: {friend['name']} (Role: {friend.get('role','Friend')})")

    prompt_parts.extend([
        "\nNARRATIVE REQUIREMENTS:",
        f"1. The story MUST be about {main_char['name']} facing their fear.",
        "2. The story must show how their friends help them.",
        "3. The character should use their comfort item to help them feel brave.",
        "4. Conclude with a satisfying resolution where the character feels more confident.",
        "\nBegin the story now."
    ])
    prompt = "\n".join(prompt_parts)

    try:
        if model is None:
            raise RuntimeError("Model unavailable")
        response = model.generate_content(prompt)
        story_text = getattr(response, "text", "")
    except Exception as e:
        logger.warning("Multi-character story model error: %s", e)
        story_text = (f"{main_char['name']} and their friends went on a wonderful adventure, "
                      "learning that teamwork is best.")

    return jsonify({"story": story_text}), 200

# ===================================================================
# INTERACTIVE / CHOOSE-YOUR-OWN-ADVENTURE STORY ENDPOINTS
# ===================================================================

@app.route("/generate-interactive-story", methods=["POST"])
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
        if model is None:
            raise RuntimeError("Model unavailable")

        response = model.generate_content(prompt)
        full_text = getattr(response, "text", "")

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


@app.route("/continue-interactive-story", methods=["POST"])
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
        if model is None:
            raise RuntimeError("Model unavailable")

        response = model.generate_content(prompt)
        full_text = getattr(response, "text", "")

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


# --- Main execution ---
if __name__ == "__main__":
    print("Enhanced Story Engine Starting...")
    print("Now with advanced character development, plot structures, and companion dynamics!")
    print("Interactive choose-your-own-adventure stories enabled!")
    print("Auto-reload enabled - server will restart on file changes!")
    app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=True)
