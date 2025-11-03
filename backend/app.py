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
from dotenv import load_dotenv

from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import google.generativeai as genai
from sqlalchemy.dialects.sqlite import JSON as SQLITE_JSON

# Load environment variables from .env file
load_dotenv(override=True)

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

    # Character type and superhero specific
    character_type = db.Column(db.String(50), default='Everyday Kid')
    superhero_name = db.Column(db.String(100))
    mission = db.Column(db.Text)

    # Appearance
    hair = db.Column(db.String(50))
    eyes = db.Column(db.String(50))
    outfit = db.Column(db.String(200))

    # SQLite JSON (persists as TEXT)
    personality_traits = db.Column(SQLITE_JSON, default=list)
    siblings = db.Column(SQLITE_JSON, default=list)
    friends = db.Column(SQLITE_JSON, default=list)
    likes = db.Column(SQLITE_JSON, default=list)
    dislikes = db.Column(SQLITE_JSON, default=list)
    fears = db.Column(SQLITE_JSON, default=list)
    strengths = db.Column(SQLITE_JSON, default=list)
    goals = db.Column(SQLITE_JSON, default=list)

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
            "character_type": self.character_type,
            "superhero_name": self.superhero_name,
            "mission": self.mission,
            "hair": self.hair,
            "eyes": self.eyes,
            "outfit": self.outfit,
            "personality_traits": self.personality_traits or [],
            "siblings": self.siblings or [],
            "friends": self.friends or [],
            "likes": self.likes or [],
            "dislikes": self.dislikes or [],
            "fears": self.fears or [],
            "strengths": self.strengths or [],
            "goals": self.goals or [],
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
print(f"MODEL: {os.getenv('GEMINI_MODEL', 'gemini-1.5-flash')}")
# --- DEBUG LINES END ---

if not api_key:
    logger.warning("GEMINI_API_KEY not set. Generation endpoints will use fallbacks.")
else:
    genai.configure(api_key=api_key)

GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
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

    def generate_enhanced_prompt(self, character: str, theme: str, companion: str | None, therapeutic_prompt: str = ""):
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

        # Add therapeutic elements if provided
        if therapeutic_prompt:
            parts.extend([
                "\nTHERAPEUTIC ELEMENTS:",
                therapeutic_prompt,
            ])

        parts.extend([
            "\nNARRATIVE REQUIREMENTS:",
            f"1. Start with an engaging opening that introduces {character}.",
            f"2. Incorporate this plot element naturally: {plot_twist}.",
            "3. End with a satisfying resolution.",
        ])

        if therapeutic_prompt:
            parts.append("4. Weave therapeutic elements naturally into the story (not preachy or obvious).")

        parts.extend([
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
    therapeutic_prompt = payload.get("therapeutic_prompt", "")
    user_api_key = payload.get("user_api_key")  # Optional user-provided API key
    character_age = payload.get("character_age", 7)  # For age-appropriate content

    prompt = story_engine.generate_enhanced_prompt(character, theme, companion, therapeutic_prompt)

    # Decide which model to use
    using_user_key = False
    try:
        if user_api_key:
            # User provided their own API key - use it for unlimited generation
            genai.configure(api_key=user_api_key)
            user_model = genai.GenerativeModel(GEMINI_MODEL)
            response = user_model.generate_content(prompt)
            using_user_key = True
        else:
            # Use server's API key (free tier)
            if model is None:
                raise RuntimeError("Model unavailable")
            response = model.generate_content(prompt)
            using_user_key = False

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
    finally:
        # Reset to server API key after user's request
        if user_api_key and api_key:
            genai.configure(api_key=api_key)

    title, wisdom_gem, story_text = _safe_extract_title_and_gem(raw_text, theme)
    return jsonify({
        "title": title,
        "story_text": story_text,
        "wisdom_gem": wisdom_gem,
        "used_user_key": using_user_key  # Let client know which mode was used
    }), 200

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
        character_type=data.get("character_type", "Everyday Kid"),
        superhero_name=data.get("superhero_name"),
        mission=data.get("mission"),
        hair=data.get("hair"),
        eyes=data.get("eyes"),
        outfit=data.get("outfit"),
        personality_traits=_as_list(data.get("traits", [])),
        likes=_as_list(data.get("likes", [])),
        dislikes=_as_list(data.get("dislikes", [])),
        fears=_as_list(data.get("fears", [])),
        strengths=_as_list(data.get("strengths", [])),
        goals=_as_list(data.get("goals", [])),
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
    if "character_type" in data:
        char.character_type = data["character_type"]
    if "superhero_name" in data:
        char.superhero_name = data["superhero_name"]
    if "mission" in data:
        char.mission = data["mission"]
    if "hair" in data:
        char.hair = data["hair"]
    if "eyes" in data:
        char.eyes = data["eyes"]
    if "outfit" in data:
        char.outfit = data["outfit"]
    if "strengths" in data:
        char.strengths = _as_list(data["strengths"])
    if "goals" in data:
        char.goals = _as_list(data["goals"])

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

@app.route("/generate-interactive-story", methods=["POST"])
def generate_interactive_story():
    """Generate the opening segment of an interactive, choice-based story."""
    payload = request.get_json(silent=True) or {}
    character = payload.get("character", "a brave adventurer")
    theme = payload.get("theme", "Adventure")
    companion = payload.get("companion")
    friends = payload.get("friends", [])
    therapeutic_prompt = payload.get("therapeutic_prompt", "")

    prompt_parts = [
        "You are a master storyteller creating an interactive choose-your-own-adventure story for children.",
        f"\nSTORY DETAILS:",
        f"- Main Character: {character}",
        f"- Theme: {theme}",
    ]
    if companion and companion != "None":
        prompt_parts.append(f"- Companion: {companion}")
    if friends:
        prompt_parts.append(f"- Friends/Siblings in story: {', '.join(friends)}")

    # Add therapeutic elements if provided
    if therapeutic_prompt:
        prompt_parts.extend([
            "\nTHERAPEUTIC ELEMENTS:",
            therapeutic_prompt,
            "IMPORTANT: Weave these elements naturally into the story and choices (not preachy).",
        ])

    prompt_parts.extend([
        "\nTASK: Create the OPENING segment of an engaging story (150-200 words).",
        "Set the scene and introduce a situation where the character must make a choice.",
    ])
    if friends:
        prompt_parts.append(f"IMPORTANT: Include {', '.join(friends)} as friends/siblings who appear in the story and can help with choices.")

    prompt_parts.extend([
        "\nFORMAT YOUR RESPONSE EXACTLY AS JSON:",
        "{",
        '  "text": "The story text here...",',
        '  "choices": [',
        '    {"id": "choice1", "text": "First option (short)", "description": "What happens if they choose this"},',
        '    {"id": "choice2", "text": "Second option (short)", "description": "What happens if they choose this"},',
        '    {"id": "choice3", "text": "Third option (short)", "description": "What happens if they choose this"}',
        '  ],',
        '  "is_ending": false',
        "}",
        "\nIMPORTANT: Return ONLY valid JSON. No extra text before or after."
    ])
    prompt = "\n".join(prompt_parts)

    try:
        if model is None:
            raise RuntimeError("Model unavailable")
        response = model.generate_content(prompt)
        raw_text = getattr(response, "text", "").strip()

        # Try to extract JSON from response
        json_match = re.search(r'\{.*\}', raw_text, re.DOTALL)
        if json_match:
            raw_text = json_match.group(0)

        result = json.loads(raw_text)
        return jsonify(result), 200

    except Exception as e:
        logger.warning("Interactive story generation error: %s", e)
        # Fallback response
        friends_text = f" with {', '.join(friends)}" if friends else ""
        return jsonify({
            "text": f"{character}{friends_text} stood at the edge of a mysterious forest, hearing strange sounds within. The {companion if companion and companion != 'None' else 'wind'} seemed to whisper of adventure ahead.",
            "choices": [
                {"id": "choice1", "text": "Enter the forest bravely", "description": "Face the unknown with courage"},
                {"id": "choice2", "text": "Look for another path", "description": "Search for a safer route"},
                {"id": "choice3", "text": "Call out to see if anyone is there", "description": "Try to make friends first"}
            ],
            "is_ending": False
        }), 200

@app.route("/continue-interactive-story", methods=["POST"])
def continue_interactive_story():
    """Continue an interactive story based on the user's choice."""
    payload = request.get_json(silent=True) or {}
    character = payload.get("character", "the hero")
    theme = payload.get("theme", "Adventure")
    companion = payload.get("companion")
    friends = payload.get("friends", [])
    choice = payload.get("choice", "")
    story_so_far = payload.get("story_so_far", "")
    choices_made = payload.get("choices_made", [])
    therapeutic_prompt = payload.get("therapeutic_prompt", "")

    # Determine if this should be an ending (after 3-4 choices)
    should_end = len(choices_made) >= 3

    prompt_parts = [
        "You are continuing an interactive choose-your-own-adventure story for children.",
        f"\nCONTEXT:",
        f"- Character: {character}",
        f"- Theme: {theme}",
    ]
    if companion and companion != "None":
        prompt_parts.append(f"- Companion: {companion}")
    if friends:
        prompt_parts.append(f"- Friends/Siblings in story: {', '.join(friends)}")

    if therapeutic_prompt:
        prompt_parts.extend([
            "\nTHERAPEUTIC ELEMENTS TO WEAVE IN:",
            therapeutic_prompt,
        ])

    prompt_parts.extend([
        f"\nSTORY SO FAR:\n{story_so_far}",
        f"\nLAST CHOICE MADE: {choice}",
        f"\nCHOICES MADE SO FAR: {len(choices_made)}",
    ])

    if should_end:
        prompt_parts.extend([
            "\nTASK: Create the FINAL segment that brings the story to a satisfying conclusion (150-200 words).",
            "Resolve the adventure positively and show what the character learned.",
        ])
        if friends:
            prompt_parts.append(f"Show how {character} and their friends {', '.join(friends)} worked together and what they learned.")

        prompt_parts.extend([
            "\nFORMAT YOUR RESPONSE EXACTLY AS JSON:",
            "{",
            '  "text": "The concluding story text...",',
            '  "choices": null,',
            '  "is_ending": true',
            "}",
        ])
    else:
        prompt_parts.extend([
            "\nTASK: Continue the story based on their choice (150-200 words) and present new options.",
        ])
        if friends:
            prompt_parts.append(f"Include interactions with {', '.join(friends)} to show friendship and teamwork.")

        prompt_parts.extend([
            "\nFORMAT YOUR RESPONSE EXACTLY AS JSON:",
            "{",
            '  "text": "The continuation text here...",',
            '  "choices": [',
            '    {"id": "choice1", "text": "Option 1", "description": "Brief description"},',
            '    {"id": "choice2", "text": "Option 2", "description": "Brief description"},',
            '    {"id": "choice3", "text": "Option 3", "description": "Brief description"}',
            '  ],',
            '  "is_ending": false',
            "}",
        ])

    prompt_parts.append("\nIMPORTANT: Return ONLY valid JSON. No extra text.")
    prompt = "\n".join(prompt_parts)

    try:
        if model is None:
            raise RuntimeError("Model unavailable")
        response = model.generate_content(prompt)
        raw_text = getattr(response, "text", "").strip()

        # Try to extract JSON from response
        json_match = re.search(r'\{.*\}', raw_text, re.DOTALL)
        if json_match:
            raw_text = json_match.group(0)

        result = json.loads(raw_text)
        return jsonify(result), 200

    except Exception as e:
        logger.warning("Story continuation error: %s", e)
        # Fallback response
        friends_text = f" and {', '.join(friends)}" if friends else ""
        if should_end:
            return jsonify({
                "text": f"Thanks to their brave choices, {character}{friends_text} completed the adventure successfully and returned home with wonderful memories and new confidence!",
                "choices": None,
                "is_ending": True
            }), 200
        else:
            return jsonify({
                "text": f"After choosing to {choice.lower()}, {character}{friends_text} discovered something wonderful that brought them closer to solving the mystery.",
                "choices": [
                    {"id": "choice1", "text": "Continue forward", "description": "Keep going with determination"},
                    {"id": "choice2", "text": "Take a moment to think", "description": "Pause and consider the situation"}
                ],
                "is_ending": False
            }), 200


@app.route("/generate-superhero", methods=["GET"])
def generate_superhero():
    """Generate a random superhero name, superpower, and mission."""
    import random
    
    # Superhero name components
    adjectives = ["Mighty", "Incredible", "Amazing", "Super", "Ultra", "Fantastic", "Wonder", "Stellar", "Dynamic", "Cosmic"]
    nouns = ["Guardian", "Defender", "Champion", "Protector", "Warrior", "Hero", "Avenger", "Sentinel", "Phoenix", "Thunder"]
    
    # Superpowers
    superpowers = [
        "Super Strength", "Flight", "Invisibility", "Telekinesis", "Super Speed",
        "Energy Blasts", "Shape Shifting", "Time Control", "Healing Powers", "Ice Powers",
        "Fire Powers", "Lightning Control", "Mind Reading", "Force Fields", "Sonic Scream",
        "Animal Communication", "Super Intelligence", "Elasticity", "X-Ray Vision", "Weather Control"
    ]
    
    # Mission templates
    missions = [
        "Protect the city from villains",
        "Save people in danger",
        "Stop evil plans before they happen",
        "Help those who cannot help themselves",
        "Keep the world safe from harm",
        "Defend the innocent and fight injustice",
        "Use powers for good and never evil",
        "Bring hope to those who have lost it",
        "Stand up to bullies and protect the weak",
        "Make the world a better place"
    ]
    
    superhero_name = f"{random.choice(adjectives)} {random.choice(nouns)}"
    superpower = random.choice(superpowers)
    mission = random.choice(missions)
    
    return jsonify({
        "superhero_name": superhero_name,
        "superpower": superpower,
        "mission": mission
    }), 200

# --- Main execution ---
@app.route("/extract-story-scenes", methods=["POST"])
def extract_story_scenes():
    """Extract key scenes from a story for illustration."""
    payload = request.get_json(silent=True) or {}
    story_text = payload.get("story_text", "")
    character_name = payload.get("character_name", "the hero")
    num_scenes = payload.get("num_scenes", 3)
    
    if not story_text:
        return jsonify({"error": "story_text is required"}), 400
    
    prompt = f"""
Analyze this children's story and extract {num_scenes} key visual scenes that would make great illustrations.

Story:
{story_text}

For each scene, provide:
1. A brief title (3-5 words)
2. A detailed visual description (2-3 sentences) focusing on what would be shown in the image
3. The main character is: {character_name}

Return ONLY valid JSON in this format:
{{
  "scenes": [
    {{"title": "Scene title", "description": "Visual description here"}},
    ...
  ]
}}

Focus on the most visually interesting and important moments. Make descriptions child-friendly and colorful.
"""
    
    try:
        if model is None:
            raise RuntimeError("Model unavailable")
        
        response = model.generate_content(prompt)
        raw_text = getattr(response, "text", "")
        
        # Try to extract JSON from response
        json_match = re.search(r'\{.*\}', raw_text, re.DOTALL)
        if json_match:
            raw_text = json_match.group(0)
        
        result = json.loads(raw_text)
        return jsonify(result), 200
        
    except Exception as e:
        logger.warning("Scene extraction error: %s", e)
        # Fallback: simple scene extraction
        sentences = story_text.split('.')
        scenes = []
        step = max(1, len(sentences) // num_scenes)
        for i in range(num_scenes):
            idx = min(i * step, len(sentences) - 1)
            scenes.append({
                "title": f"Scene {i+1}",
                "description": sentences[idx].strip() if idx < len(sentences) else ""
            })
        return jsonify({"scenes": scenes}), 200

@app.route("/generate-illustrations", methods=["POST"])
def generate_illustrations():
    """Generate therapeutic story illustrations using Gemini Imagen with age-appropriate detail."""
    payload = request.get_json(silent=True) or {}
    scenes = payload.get("scenes", [])
    character_name = payload.get("character_name", "the hero")
    style = payload.get("style", "children's book illustration")
    age = payload.get("age", 7)  # User's age for appropriate detail level
    therapeutic_focus = payload.get("therapeutic_focus")  # Optional: e.g., "overcoming fear"

    if not scenes:
        return jsonify({"error": "scenes are required"}), 400

    try:
        from gemini_image_generator import GeminiImageGenerator
        generator = GeminiImageGenerator()

        illustrations = []
        for i, scene in enumerate(scenes):
            scene_description = scene.get("description", scene.get("text", ""))
            scene_title = scene.get("title", f"Scene {i+1}")

            if not scene_description:
                continue

            # Generate one therapeutic illustration per scene
            images = generator.generate_story_illustration(
                scene_description=scene_description,
                character_name=character_name,
                style=style,
                num_images=1,
                age=age,
                therapeutic_focus=therapeutic_focus
            )

            if images:
                illustrations.append({
                    "scene_title": scene_title,
                    "scene_description": scene_description,
                    "image_data": images[0]["image_data"],  # base64 PNG
                    "image_id": images[0]["id"],
                    "format": "png"
                })

        if not illustrations:
            return jsonify({"error": "Failed to generate any illustrations"}), 500

        return jsonify({"illustrations": illustrations}), 200

    except Exception as e:
        logger.error(f"Illustration generation error: {e}")
        return jsonify({"error": f"Failed to generate illustrations: {str(e)}"}), 500

@app.route("/generate-coloring-pages", methods=["POST"])
def generate_coloring_pages():
    """Generate therapeutic coloring book pages from story scenes."""
    payload = request.get_json(silent=True) or {}
    scenes = payload.get("scenes", [])
    character_name = payload.get("character_name", "the hero")
    age = payload.get("age", 7)  # User's age for appropriate intricacy
    therapeutic_focus = payload.get("therapeutic_focus")  # Optional: e.g., "relaxation"

    if not scenes:
        return jsonify({"error": "scenes are required"}), 400

    try:
        from gemini_image_generator import GeminiImageGenerator
        generator = GeminiImageGenerator()

        coloring_pages = []
        for i, scene in enumerate(scenes):
            scene_description = scene.get("description", scene.get("text", ""))
            scene_title = scene.get("title", f"Scene {i+1}")

            if not scene_description:
                continue

            # Generate therapeutic coloring page
            pages = generator.generate_coloring_page(
                scene_description=scene_description,
                character_name=character_name,
                num_images=1,
                age=age,
                therapeutic_focus=therapeutic_focus
            )

            if pages:
                coloring_pages.append({
                    "scene_title": scene_title,
                    "scene_description": scene_description,
                    "image_data": pages[0]["image_data"],  # base64 PNG
                    "image_id": pages[0]["id"],
                    "format": "png"
                })

        if not coloring_pages:
            return jsonify({"error": "Failed to generate any coloring pages"}), 500

        return jsonify({"coloring_pages": coloring_pages}), 200

    except Exception as e:
        logger.error(f"Coloring page generation error: {e}")
        return jsonify({"error": f"Failed to generate coloring pages: {str(e)}"}), 500


@app.route("/setup-test-account", methods=["POST"])
def setup_test_account():
    """Create Isabella's test account with everything unlocked."""
    # Create Isabella's character
    isabella = Character(
        id='isabella-test-account',
        name='Isabella',
        age=7,
        gender='Girl',
        role='Hero',
        hair='Short brown hair with pink highlights',
        eyes='Brown',
        outfit='Favorite outfit',
        challenge='Learning to read, still learning letters',
        character_type='Everyday Kid',
        personality_traits=['Brave', 'Curious', 'Kind', 'Determined'],
        likes=['playing', 'adventures', 'pink things'],
        dislikes=['being bored'],
        fears=[],
        strengths=['trying her best', 'being brave'],
        goals=['learn to read', 'know all her letters'],
        comfort_item='favorite stuffed animal',
    )
    
    # Check if Isabella already exists
    existing = db.session.get(Character, 'isabella-test-account')
    if existing:
        # Update existing
        existing.name = isabella.name
        existing.age = isabella.age
        existing.gender = isabella.gender
        existing.hair = isabella.hair
        existing.challenge = isabella.challenge
        existing.personality_traits = isabella.personality_traits
        existing.likes = isabella.likes
        existing.strengths = isabella.strengths
        existing.goals = isabella.goals
        db.session.commit()
        return jsonify({
            "status": "updated",
            "character": existing.to_dict(),
            "message": "Isabella's account updated with everything unlocked!"
        }), 200
    else:
        # Create new
        db.session.add(isabella)
        db.session.commit()
        return jsonify({
            "status": "created",
            "character": isabella.to_dict(),
            "message": "Isabella's test account created with everything unlocked!"
        }), 201

# ============================================================================
# TEXT-TO-SPEECH ENDPOINTS
# High-quality narration with Google Cloud TTS
# ============================================================================

# Try to import TTS service, fall back to mock if not available
try:
    from tts_service import TTSService
    tts_service = TTSService()
    logger.info("Google Cloud TTS service initialized")
except Exception as e:
    from tts_service import MockTTSService
    tts_service = MockTTSService()
    logger.warning(f"Using mock TTS service (Google Cloud TTS not available: {e})")


@app.route("/get-voices", methods=["GET"])
def get_voices():
    """
    Get list of available narrator voices

    Returns:
        JSON list of voice options with details
    """
    try:
        voices = tts_service.get_available_voices()
        return jsonify({
            "voices": voices,
            "status": "success"
        }), 200
    except Exception as e:
        logger.error(f"Error getting voices: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/generate-speech", methods=["POST"])
def generate_speech():
    """
    Generate high-quality speech audio from text

    Request body:
        {
            "text": "Story text to narrate",
            "voice_name": "en-US-Neural2-F" (optional),
            "speaking_rate": 1.0 (optional, 0.25-4.0),
            "pitch": 0.0 (optional, -20.0 to 20.0),
            "use_ssml": true (optional, adds natural pauses)
        }

    Returns:
        Audio file (MP3) as binary data
    """
    try:
        data = request.get_json(silent=True) or {}

        text = data.get("text", "")
        if not text:
            return jsonify({"error": "No text provided"}), 400

        voice_name = data.get("voice_name", "en-US-Neural2-F")
        speaking_rate = float(data.get("speaking_rate", 1.0))
        pitch = float(data.get("pitch", 0.0))
        use_ssml = data.get("use_ssml", True)

        # Validate parameters
        if speaking_rate < 0.25 or speaking_rate > 4.0:
            return jsonify({"error": "Speaking rate must be between 0.25 and 4.0"}), 400
        if pitch < -20.0 or pitch > 20.0:
            return jsonify({"error": "Pitch must be between -20.0 and 20.0"}), 400

        # Generate speech
        audio_content = tts_service.generate_speech(
            text=text,
            voice_name=voice_name,
            speaking_rate=speaking_rate,
            pitch=pitch,
            use_ssml=use_ssml,
        )

        # Return audio as binary response
        from flask import make_response
        response = make_response(audio_content)
        response.headers['Content-Type'] = 'audio/mpeg'
        response.headers['Content-Disposition'] = 'attachment; filename=narration.mp3'
        return response

    except Exception as e:
        logger.error(f"Error generating speech: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    print("*** Enhanced Story Engine Starting...")
    print("*** Now with advanced character development, plot structures, and companion dynamics!")
    app.run(host="0.0.0.0", port=5000, debug=False)
