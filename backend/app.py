<<<<<<< Updated upstream


import os
import uuid
import json
import logging
import random
import re
import time
from datetime import datetime
from dotenv import load_dotenv

from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import google.generativeai as genai
from sqlalchemy import text
from sqlalchemy.dialects.sqlite import JSON as SQLITE_JSON
from sqlalchemy.exc import OperationalError
import redis

# Load environment variables from .env file
load_dotenv(override=True)

# ----------------------
# Flask & DB setup
# ----------------------
app = Flask(__name__)

# IMPORTANT: Update CORS for production
# Allow both localhost (for development) and your production domains
ALLOWED_ORIGINS = [
    "http://localhost:8080",
    "http://127.0.0.1:8080",
    "https://story-weaver-app.netlify.app",
    "https://reliable-sherbet-2352c4.netlify.app",  # Production Netlify domain
    "https://*.netlify.app",  # Allow Netlify preview deploys
]

CORS(app, resources={
    r"/*": {
        "origins": ALLOWED_ORIGINS,
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"],
    }
})

basedir = os.path.abspath(os.path.dirname(__file__))

# Use PostgreSQL if DATABASE_URL is set (production), otherwise SQLite (local dev)
database_url = os.getenv("DATABASE_URL")
if database_url:
    # Railway/production: use PostgreSQL
    app.config["SQLALCHEMY_DATABASE_URI"] = database_url
    # Connection pooling for PostgreSQL
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
        "pool_size": 10,
        "max_overflow": 20,
        "pool_timeout": 30,
        "pool_recycle": 3600,
        "pool_pre_ping": True,
    }
else:
    # Local development: use SQLite
    app.config["SQLALCHEMY_DATABASE_URI"] = f"sqlite:///{os.path.join(basedir, 'characters.db')}"

app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["JSON_SORT_KEYS"] = False

db = SQLAlchemy(app)

# Redis client for caching
redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
redis_client = redis.from_url(redis_url, decode_responses=True)

# Database connection retry logic
def db_operation_with_retry(operation, max_retries=3, base_delay=0.1):
    """Execute database operation with exponential backoff retry"""
    for attempt in range(max_retries):
        try:
            return operation()
        except OperationalError as e:
            if attempt == max_retries - 1:
                raise e
            delay = base_delay * (2 ** attempt)
            app.logger.warning(f"Database operation failed (attempt {attempt + 1}/{max_retries}), retrying in {delay}s: {e}")
            time.sleep(delay)
    return None

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
    personality_sliders = db.Column(SQLITE_JSON, default=dict)
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
            "personality_sliders": self.personality_sliders or {},
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

PERSONALITY_SLIDER_DEFINITIONS = {
    "organization_planning": {"label": "Organization & Planning", "left_label": "Tidy Planner", "right_label": "Messy Freestyle"},
    "assertiveness": {"label": "Voice Style", "left_label": "Bold Voice", "right_label": "Soft Voice"},
    "sociability": {"label": "Social Energy", "left_label": "Jump-Right-In", "right_label": "Warm-Up-First"},
    "adventure": {"label": "Adventure Level", "left_label": "Let's Explore!", "right_label": "Careful Steps"},
    "expressiveness": {"label": "Energy Level", "left_label": "Mega Energy", "right_label": "Calm Breeze"},
    "feelings_sharing": {"label": "Feelings Expression", "left_label": "Heart-On-Sleeve", "right_label": "Quiet Feelings"},
    "problem_solving": {"label": "Problem-Solving Style", "left_label": "Brainy Builder", "right_label": "Imagination Wiz"},
    "play_preference": {"label": "Play Preference", "left_label": "Caring & Nurturing", "right_label": "Building & Action"},
}


def _ensure_personality_slider_column():
    """Add the JSON column if an existing SQLite file is missing it."""
    table_name = Character.__tablename__ or "character"
    try:
        with db.engine.connect() as conn:
            result = conn.execute(text(f"PRAGMA table_info({table_name})"))
            columns = {row[1] for row in result}
            if "personality_sliders" not in columns:
                conn.execute(text(f"ALTER TABLE {table_name} ADD COLUMN personality_sliders TEXT"))
                logger.info("Added missing column 'personality_sliders' to %s", table_name)
    except Exception as exc:
        logger.warning("Unable to ensure personality_sliders column exists: %s", exc)


with app.app_context():
    db.create_all()
    _ensure_personality_slider_column()

# ----------------------
# Gemini setup
# ----------------------
api_key = os.getenv("GEMINI_API_KEY")

# --- DEBUG LINES START ---
print(f"API KEY EXISTS: {bool(api_key)}")
print(f"API KEY LENGTH: {len(api_key) if api_key else 0}")
print(f"RAW GEMINI_MODEL ENV VAR: {os.getenv('GEMINI_MODEL')}")
print(f"MODEL (after default): {os.getenv('GEMINI_MODEL', 'gemini-1.5-flash')}")
# --- DEBUG LINES END ---

if not api_key:
    logger.warning("GEMINI_API_KEY not set. Generation endpoints will use fallbacks.")
else:
    genai.configure(api_key=api_key)

GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
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

    def generate_enhanced_prompt(
        self,
        character: str,
        theme: str,
        companion: str | None,
        therapeutic_prompt: str = "",
        feelings_prompt: str | None = None,
    ):
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
        if feelings_prompt:
            parts.extend([
                "\nFEELINGS-FOCUSED GUIDANCE:",
                feelings_prompt,
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
            "\nSENSORY-RICH WRITING:",
            "- Use SENSORY DETAILS: What does the character see, hear, feel, smell, taste?",
            "- SHOW emotions through body language: 'heart racing', 'palms sweating', 'warm feeling spreading'",
            "- Use VIVID DESCRIPTIONS: colors, sounds, textures, temperatures",
            "- Create IMMERSIVE scenes that readers can picture clearly",
            "- Example: Instead of 'Emma was scared', write 'Emma's heart pounded as shadows danced on the wall'",
            "\nFORMAT REQUIREMENTS:",
            f"- Start with: [TITLE: A Creative and Engaging Title]",
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

def _clamp_slider_value(value):
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(max(0, min(100, round(value))))
    if isinstance(value, str):
        try:
            return _clamp_slider_value(float(value))
        except (TypeError, ValueError):
            return None
    return None


def _sanitize_personality_sliders(raw_value):
    if not raw_value or not isinstance(raw_value, dict):
        return {}
    sanitized = {}
    for key in PERSONALITY_SLIDER_DEFINITIONS:
        if key not in raw_value:
            continue
        clamped = _clamp_slider_value(raw_value.get(key))
        if clamped is not None:
            sanitized[key] = clamped
    return sanitized


def _describe_slider_value(value, left_label, right_label):
    if value is None:
        return None
    delta = abs(value - 50)
    if delta <= 5:
        return f"balanced between {left_label.lower()} and {right_label.lower()}"
    direction = right_label if value > 50 else left_label
    if delta >= 30:
        qualifier = "strongly "
    elif delta >= 15:
        qualifier = "leans "
    else:
        qualifier = "slightly "
    return f"{qualifier}{direction.lower()}"


def _describe_personality_sliders(personality_sliders):
    if not personality_sliders:
        return []
    lines = ["\nPERSONALITY STYLE DIALS: (0 = left trait, 100 = right trait)"]
    for key, meta in PERSONALITY_SLIDER_DEFINITIONS.items():
        value = personality_sliders.get(key)
        if value is None:
            continue
        descriptor = _describe_slider_value(
            value, meta["left_label"], meta["right_label"]
        )
        if descriptor:
            toward = meta["right_label"] if value > 50 else meta["left_label"]
            lines.append(
                f"- {meta['label']}: {descriptor} ({value}/100 toward {toward.lower()})")
    return lines


def _build_character_integration(character_name, fears, strengths, likes, dislikes, comfort_item, personality_traits, personality_sliders):
    """Build concise character integration for personalized storytelling"""

    # Limit array lengths to prevent token explosion
    fears = fears[:3] if fears else []  # Max 3 fears
    strengths = strengths[:3] if strengths else []  # Max 3 strengths
    likes = likes[:3] if likes else []  # Max 3 likes
    dislikes = dislikes[:2] if dislikes else []  # Max 2 dislikes
    personality_traits = personality_traits[:4] if personality_traits else []  # Max 4 traits

    parts = [
        f"CHARACTER: {character_name}",
    ]

    # Personality (condensed)
    if personality_traits:
        traits_str = ", ".join(personality_traits)
        parts.append(f"TRAITS: {traits_str}")

    # Key therapeutic elements (much shorter)
    if fears:
        fears_str = ", ".join(fears)
        parts.append(f"FEARS: {fears_str} - help character overcome these naturally")

    if strengths:
        strengths_str = ", ".join(strengths)
        parts.append(f"STRENGTHS: {strengths_str} - use these to solve problems")

    if comfort_item:
        parts.append(f"COMFORT: {comfort_item}")

    if likes:
        likes_str = ", ".join(likes)
        parts.append(f"LIKES: {likes_str}")

    return "\n".join(parts)


def _get_age_guidelines(age: int) -> dict:
    if age <= 5:
        return {
            "length_guideline": "100-150 words",
            "vocabulary_level": "very simple vocabulary (CVC + sight words)",
            "sentence_structure": "3-6 word sentences with repetition",
            "vocabulary_examples": "cat, dog, hop, sun, play, happy",
            "concepts": "tangible, concrete ideas only",
            "special_instructions": "Use rhyme, rhythm, and repeatable frames.",
        }
    if age <= 8:
        return {
            "length_guideline": "150-250 words",
            "vocabulary_level": "simple (sight words + basic phonics)",
            "sentence_structure": "short, clear, mostly present-tense sentences",
            "vocabulary_examples": "magic, brave, puzzle, curious",
            "concepts": "simple cause/effect with predictable plots",
            "special_instructions": "Include dialogue and phonics-friendly words.",
        }
    if age <= 12:
        return {
            "length_guideline": "250-400 words",
            "vocabulary_level": "grade-level vocabulary",
            "sentence_structure": "mix of short and complex sentences",
            "vocabulary_examples": "determined, shimmering, mysterious, courageous",
            "concepts": "character growth with layered plots and emotional arcs",
            "special_instructions": "Highlight problem-solving and empathy.",
        }
    if age <= 15:
        return {
            "length_guideline": "400-600 words",
            "vocabulary_level": "advanced / expressive vocabulary",
            "sentence_structure": "sophisticated and varied sentences",
            "vocabulary_examples": "contemplated, resilience, luminous, intricate",
            "concepts": "identity exploration, moral dilemmas, nuanced relationships",
            "special_instructions": "Use nuanced emotions and real-world parallels.",
        }
    return {
        "length_guideline": "600-800 words",
        "vocabulary_level": "mature / literary vocabulary",
        "sentence_structure": "complex, literary prose",
        "vocabulary_examples": "introspective, paradoxical, cathartic, transcendent",
        "concepts": "philosophical questions and mature themes",
        "special_instructions": "Employ literary devices, symbolism, and deep psychology.",
    }


def _build_age_instruction_block(age: int) -> str:
    guidelines = _get_age_guidelines(age)
    return (
        f"AGE-APPROPRIATE GUIDELINES FOR {age}-YEAR-OLD:\n"
        f"- LENGTH: {guidelines['length_guideline']} (strict requirement)\n"
        f"- VOCABULARY: {guidelines['vocabulary_level']}\n"
        f"- SENTENCE STYLE: {guidelines['sentence_structure']}\n"
        f"- WORD EXAMPLES: {guidelines['vocabulary_examples']}\n"
        f"- CONCEPTS: {guidelines['concepts']}\n"
        f"- SPECIAL NOTES: {guidelines['special_instructions']}"
    )


def _build_learning_to_read_prompt(character_name, theme, age, character_details, companion=None, extra_characters=None):
    def _format_list(label, values):
        if not values:
            return ""
        clean = [v.strip() for v in values if isinstance(v, str) and v.strip()]
        if not clean:
            return ""
        return f"\n{label}: {', '.join(clean[:5])}"

    detail_section = ""
    if character_details:
        detail_section += _format_list("LIKES", character_details.get("likes"))
        detail_section += _format_list("STRENGTHS", character_details.get("strengths"))
        comfort_item = character_details.get("comfort_item")
        if comfort_item:
            detail_section += f"\nCOMFORT ITEM: {comfort_item}"

    if extra_characters:
        detail_section += f"\nFRIENDS IN STORY: {', '.join(extra_characters[:5])}"

    companion_text = ""
    if companion and companion != "None":
        companion_text = f"\nCOMPANION: Include {companion} as a gentle helper."

    return (
        f"You are creating a LEARNING TO READ rhyming story for a {age}-year-old child named {character_name}.\n\n"
        "STRICT REQUIREMENTS (NO EXCEPTIONS):\n"
        "1. TOTAL LENGTH: 50-100 words only.\n"
        "2. RHYME PATTERN: AABB (line 1 rhymes with line 2, line 3 with line 4, etc.).\n"
        "3. LINE LENGTH: Each line must use only 4-6 simple words.\n"
        "4. VOCABULARY: Only CVC words (cat, dog, hop, sun) and common sight words (the, and, can, see, like, play). "
        "Avoid blends, silent letters, or complex spelling patterns.\n"
        f"5. STRUCTURE: Repetition helps reading. Use predictable frames like \"Can {character_name} ___? Yes, {character_name} can ___!\".\n"
        "6. TONE: Encouraging, musical, confident.\n"
        "7. FORMAT: Place each short sentence or clause on its own line for easy finger tracking.\n\n"
        f"THEME: {theme}{companion_text}{detail_section}\n\n"
        f"Create the rhyming learning-to-read story about {character_name} now."
    )

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

def _extract_current_feeling(container):
    """Return a normalized current feeling dictionary or None."""
    if not isinstance(container, dict):
        return None
    feeling = container.get("current_feeling")
    if feeling is None and "currentFeeling" in container:
        feeling = container.get("currentFeeling")
    if not isinstance(feeling, dict):
        return None

    def _clean(value):
        if value is None:
            return None
        value_str = str(value).strip()
        return value_str or None

    intensity = feeling.get("intensity")
    try:
        intensity = int(intensity)
    except (TypeError, ValueError):
        intensity = None
    else:
        intensity = max(1, min(intensity, 5))

    coping_value = feeling.get("coping_strategies")
    if coping_value is None and "copingStrategies" in feeling:
        coping_value = feeling.get("copingStrategies")
    coping_strategies = [item for item in _as_list(coping_value) if item]

    # Handle both old emotion structure and new feelings wheel structure
    emotion_name = (
        _clean(feeling.get("emotion_name") or feeling.get("emotionName"))
        or _clean(feeling.get("tertiary_emotion"))  # New feelings wheel
        or _clean(feeling.get("secondary_emotion"))  # Fallback to secondary
        or _clean(feeling.get("core_emotion"))  # Fallback to core
    )

    normalized = {
        "emotion_id": _clean(feeling.get("emotion_id") or feeling.get("emotionId") or feeling.get("tertiary_emotion")),
        "emotion_name": emotion_name,
        "emotion_emoji": _clean(feeling.get("emotion_emoji") or feeling.get("emotionEmoji")),
        "emotion_description": _clean(feeling.get("emotion_description") or feeling.get("emotionDescription")),
        "intensity": intensity,
        "what_happened": _clean(feeling.get("what_happened") or feeling.get("whatHappened")),
        "physical_signs": _clean(feeling.get("physical_signs") or feeling.get("physicalSigns")),
        "coping_strategies": coping_strategies,
    }

    # If no meaningful data, return None
    if not any(value for key, value in normalized.items() if key != "coping_strategies"):
        if not normalized["coping_strategies"]:
            return None
    return normalized

def _build_feelings_prompt(character_name: str, feeling: dict | None) -> str:
    if not feeling:
        return ""

    emotion_name = feeling.get("emotion_name") or "a big feeling"
    emoji = feeling.get("emotion_emoji") or ""
    description = feeling.get("emotion_description")
    what_happened = feeling.get("what_happened")
    physical_signs = feeling.get("physical_signs")
    intensity = feeling.get("intensity")
    coping = feeling.get("coping_strategies") or []

    lines = [
        f"- Current emotion: {emotion_name} {emoji}".strip(),
    ]
    if intensity:
        lines.append(f"- Intensity: {intensity} out of 5 (1=calm, 5=very strong).")
    if description:
        lines.append(f"- How it feels: {description}.")
    if what_happened:
        lines.append(f"- Recent situation: {what_happened}.")
    if physical_signs:
        lines.append(f"- Body clues: {physical_signs}.")
    if coping:
        strategies = ", ".join(coping)
        lines.append(f"- Coping strategies to highlight: {strategies}.")

    guidelines = [
        f"1. Begin the story by acknowledging that {character_name} feels {emotion_name.lower()} and why.",
        "2. Validate the feeling with compassionate language (all feelings are okay).",
        "3. Describe the character's body sensations and thoughts tied to the emotion.",
        "4. Weave coping strategies into the narrative in a natural, supportive way.",
        "5. Show the character processing the feeling, using coping skills, and noticing a shift.",
        "6. End with hopeful reflection—what the character learned about their feelings.",
    ]

    return "\n".join([
        *lines,
        "\nFEELINGS STORY REQUIREMENTS:",
        *guidelines,
        "7. Keep the tone gentle, therapeutic, and empowering throughout.",
    ])

# ----------------------
# API Routes
# ----------------------
@app.route("/health", methods=["GET"])
def health():
    return {"status": "ok", "model": GEMINI_MODEL, "has_api_key": bool(api_key)}, 200

@app.route("/get-story-themes", methods=["GET"])
def get_story_themes():
    return jsonify(["Adventure", "Friendship", "Magic", "Dragons", "Castles", "Unicorns", "Space", "Ocean"])

@app.route("/generate-story", methods=["POST"])
def generate_story_endpoint():
    payload = request.get_json(silent=True) or {}
    rhyme_time_mode = payload.get("rhyme_time_mode", False)
    learning_to_read_mode = payload.get("learning_to_read_mode", False)
    character = payload.get("character", "a brave adventurer")
    theme = payload.get("theme", "Adventure")
    companion = payload.get("companion")
    therapeutic_prompt = payload.get("therapeutic_prompt", "")
    user_api_key = payload.get("user_api_key")  # Optional user-provided API key
    character_age = payload.get("character_age", 7)  # For age-appropriate content
    current_feeling = _extract_current_feeling(payload)
    feelings_prompt = _build_feelings_prompt(character, current_feeling)
    supporting_characters = (
        payload.get("characters") if isinstance(payload.get("characters"), list) else None
    )

    if learning_to_read_mode:
        rhyme_time_mode = False  # learning mode already enforces rhyme/length

    # Deep character integration - get full character details
    character_details = payload.get("character_details") or {}
    if not isinstance(character_details, dict):
        character_details = {}
    fears = character_details.get("fears", [])
    strengths = character_details.get("strengths", [])
    likes = character_details.get("likes", [])
    dislikes = character_details.get("dislikes", [])
    comfort_item = character_details.get("comfort_item", "")
    personality_traits = character_details.get("personality_traits", [])
    personality_sliders = _sanitize_personality_sliders(
        character_details.get("personality_sliders", {})
    )

    age_instruction_block = _build_age_instruction_block(character_age)

    if learning_to_read_mode:
        prompt = _build_learning_to_read_prompt(
            character,
            theme,
            character_age,
            character_details,
            companion=companion,
            extra_characters=supporting_characters,
        )
    else:
        prompt = story_engine.generate_enhanced_prompt(
            character,
            theme,
            companion,
            therapeutic_prompt,
            feelings_prompt if feelings_prompt else None,
        )

        character_integration = _build_character_integration(
            character,
            fears,
            strengths,
            likes,
            dislikes,
            comfort_item,
            personality_traits,
            personality_sliders,
        )

        sections = [prompt, character_integration]
        sections.append(f"\n{age_instruction_block}")
        if rhyme_time_mode:
            rhyme_instruction = (
                "\nSTORY STYLE:\n"
                "**This is extremely important:** Write the entire story in a playful, silly, rhyming verse, like a Dr. Seuss or Julia Donaldson book. "
                "Use AABB or ABAB rhyme schemes. The story must rhyme."
            )
            sections.append(rhyme_instruction)
        prompt = "\n\n".join(sections)

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
        print(f"!!! Prompt length: {len(prompt)} characters")
        print(f"!!! Learning to read mode: {learning_to_read_mode}, Rhyme time mode: {rhyme_time_mode}")
        print(f"!!! Character age: {character_age}, Theme: {theme}")
        logger.error("Model error, using fallback story. Error: %s", e, exc_info=True)
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
        "story": story_text,  # Changed from story_text to story for Flutter compatibility
        "story_text": story_text,  # Keep for backward compatibility
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
        personality_sliders=_sanitize_personality_sliders(data.get("personality_sliders")),
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
    if "personality_sliders" in data:
        raw_sliders = data.get("personality_sliders")
        if raw_sliders is None:
            char.personality_sliders = {}
        else:
            char.personality_sliders = _sanitize_personality_sliders(raw_sliders)
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
    current_feeling = _extract_current_feeling(data)

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

    feelings_prompt = _build_feelings_prompt(main_char["name"], current_feeling)
    if feelings_prompt:
        prompt_parts.extend([
            "\nFEELINGS-FOCUSED CONTEXT:",
            feelings_prompt,
        ])

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
    """Generate the opening segment of an interactive,
choice-based story."""
    payload = request.get_json(silent=True) or {}
    character_name = payload.get("character", "a brave adventurer")
    character_age = payload.get("character_age", 7)
    theme = payload.get("theme", "Adventure")
    companion = payload.get("companion")
    friends = payload.get("friends", [])
    therapeutic_prompt = payload.get("therapeutic_prompt", "")

    # Extract feelings using the helper function
    current_feeling = _extract_current_feeling(payload)

    prompt_parts = [
        "You are a master storyteller creating an interactive "
        "choose-your-own-adventure story for children.",
        f"\nSTORY DETAILS:",
        f"- Main Character: {character_name}",
        f"- Character Age: {character_age}",
        f"- Theme: {theme}",
    ]
    if companion and companion != "None":
        prompt_parts.append(f"- Companion: {companion}")
    if friends:
        prompt_parts.append(f"- Friends/Siblings in story: "
                            f"{', '.join(friends)}")

    # Build and add feelings section if a feeling was provided
    if current_feeling:
        feelings_section = \
_build_feelings_prompt(character_name, current_feeling)
        prompt_parts.append(feelings_section)

    # Add therapeutic elements if provided
    if therapeutic_prompt:
        prompt_parts.extend([
            "\nTHERAPEUTIC ELEMENTS:",
            therapeutic_prompt,
            "IMPORTANT: Weave these elements naturally into the story and choices (not preachy).",
        ])

    # Add age-appropriate guidelines
    age_guidelines = _build_age_instruction_block(character_age)
    prompt_parts.append(age_guidelines)

    prompt_parts.extend([
        "\nTASK: Create the OPENING segment of an engaging story "
        "(150-200 words).",
        "Set the scene and introduce a situation where the "
        "character must make a choice.",
    ])
    if friends:
        prompt_parts.append(f"IMPORTANT: Include {', '.join(friends)} "
                            f"as friends/siblings who appear in the story and "
                            f"can help with choices.")

    prompt_parts.extend([
        "\nFORMAT YOUR RESPONSE EXACTLY AS JSON:",
        "{",
        '  "text": "The story text here...",',
        '  "choices": [',
        '    {"id": "choice1", "text": "First option (short)", '
        '"description": "What happens if they choose this"},',
        '    {"id": "choice2", "text": "Second option (short)", '
        '"description": "What happens if they choose this"},',
        '    {"id": "choice3", "text": "Third option (short)", '
        '"description": "What happens if they choose this"}',
        '],',
        '  "is_ending": false,',
        '}',
        "\nIMPORTANT: Return ONLY valid JSON. No extra text "
        "before or after."
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
            "text": f"{character_name}{friends_text} stood at the "
                    f"edge of a mysterious forest, hearing strange sounds within. The "
                    f"{companion if companion and companion != 'None' else 'wind'} "
                    f"seemed to whisper of adventure ahead.",
            "choices": [
                {"id": "choice1", "text": "Enter the forest "
                                          "bravely", "description": "Face the unknown with courage"},
                {"id": "choice2", "text": "Look for another "
                                          "path", "description": "Search for a safer route"},
                {"id": "choice3", "text": "Call out to see if "
                                          "anyone is there", "description": "Try to make friends first"}
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
            "\nTASK: Create the FINAL segment that brings the story to a satisfying conclusion (150-200 words).\n",
            "Resolve the adventure positively and show what the character learned.",
        ])
        if friends:
            prompt_parts.append(f"Show how {character} and their friends {', '.join(friends)} worked together and what they learned.")

        prompt_parts.extend([
            "\nFORMAT YOUR RESPONSE EXACTLY AS JSON:",
            "{",
            '  "text": "The concluding story text...",',
            '  "choices": [],',
            '  "is_ending": true,',
            '}',
        ])
    else:
        prompt_parts.extend([
            "\nTASK: Create the NEXT story segment (150-200 "
            "words) that continues from the last choice.",
            "Introduce a new situation where the character must "
            "make another choice.",
        ])
        if friends:
            prompt_parts.append(f"Include interactions with {', '.join(friends)} to show friendship and teamwork.")

        prompt_parts.extend([
            "\nFORMAT YOUR RESPONSE EXACTLY AS JSON:",
            "{",
            '  "text": "The story text here...",',
            '  "choices": [',
            '    {"id": "choice1", "text": "First option", '
            '"description": "What happens next"},',
            '    {"id": "choice2", "text": "Second option", '
            '"description": "What happens next"},',
            '    {"id": "choice3", "text": "Third option", '
            '"description": "What happens next"}',
            '],',
            '  "is_ending": false,',
            '}',
        ])

    prompt_parts.append("\nIMPORTANT: Return ONLY valid JSON. No extra text before or after.")
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
                "choices": [],
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
        raw_text = getattr(response, "text", "").strip()
        
        # Try to extract JSON from response
        json_match = re.search(r'\{{.*\}}', raw_text, re.DOTALL)
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
    # Use PORT from environment (Railway sets this)
    port = int(os.environ.get("PORT", 5000))
    # Bind to 0.0.0.0 for Railway
    app.run(host="0.0.0.0", port=port, debug=False)
=======
"""
Enhanced Interactive Children's Adventure Engine – API v2.0 (Refactor, fixed)
- Single update route, fixed /get-characters, safer parsing, same behavior.
"""

import os
import time
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
from sqlalchemy import text
from sqlalchemy.dialects.sqlite import JSON as SQLITE_JSON
from prometheus_client import Counter, Histogram, generate_latest, CollectorRegistry, Gauge
# Initialize New Relic APM
import newrelic.agent
newrelic.agent.initialize()


# Load environment variables from .env file
load_dotenv(override=True)

# ----------------------
# Flask & DB setup
# ----------------------
app = Flask(__name__)

# Prometheus metrics
registry = CollectorRegistry()
story_generation_requests = Counter("story_generation_requests_total", "Total story generation requests", registry=registry)
story_generation_duration = Histogram("story_generation_duration_seconds", "Story generation duration", registry=registry)
api_requests_total = Counter("api_requests_total", "Total API requests", ["method", "endpoint"], registry=registry)
stories_by_theme = Counter("stories_by_theme_total", "Stories generated by theme", ["theme"], registry=registry)
stories_by_age = Counter("stories_by_age_total", "Stories generated by character age", ["age_group"], registry=registry)
db_connection_pool_size = Gauge("db_connection_pool_size", "Database connection pool size", registry=registry)
# IMPORTANT: Update CORS for production
# Allow both localhost (for development) and your production domains
ALLOWED_ORIGINS = [
    "http://localhost:8080",
@app.before_request
def track_request():
    if request.endpoint:
        api_requests_total.labels(method=request.method, endpoint=request.endpoint).inc()
    "http://127.0.0.1:8080",
    "https://story-weaver-app.netlify.app",
    "https://reliable-sherbet-2352c4.netlify.app",  # Production Netlify domain
    "https://*.netlify.app",  # Allow Netlify preview deploys
]

CORS(app, resources={
    r"/*": {
        "origins": ALLOWED_ORIGINS,
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"],
    }
})

basedir = os.path.abspath(os.path.dirname(__file__))

# Use PostgreSQL if DATABASE_URL is set (production), otherwise SQLite (local dev)
database_url = os.getenv("DATABASE_URL")
if database_url:
    # Railway/production: use PostgreSQL
    app.config["SQLALCHEMY_DATABASE_URI"] = database_url
else:
    # Local development: use SQLite
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
    """
    SQLAlchemy model for storing character information.

    Attributes:
        id (str): Primary key, unique UUID for the character.
        name (str): The name of the character.
        age (int): The age of the character.
        gender (str): The gender of the character.
        role (str): The role of the character (e.g., Hero, Sidekick).
        magic_type (str): The type of magic the character possesses.
        challenge (str): A challenge the character is currently facing.
        character_type (str): The type of character (e.g., Everyday Kid, Superhero).
        superhero_name (str): The superhero name if applicable.
        mission (str): The superhero mission if applicable.
        hair (str): Description of the character's hair.
        eyes (str): Description of the character's eyes.
        outfit (str): Description of the character's outfit.
        personality_traits (list): JSON list of personality traits.
        personality_sliders (dict): JSON dictionary of personality slider values (0-100).
        siblings (list): JSON list of sibling names.
        friends (list): JSON list of friend names.
        likes (list): JSON list of things the character likes.
        dislikes (list): JSON list of things the character dislikes.
        fears (list): JSON list of the character's fears.
        strengths (list): JSON list of the character's strengths.
        goals (list): JSON list of the character's goals.
        comfort_item (str): A comfort item the character possesses.
        created_at (datetime): Timestamp of when the character was created.
    """
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
    personality_sliders = db.Column(SQLITE_JSON, default=dict)
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
        """
        Converts the Character object to a dictionary.

        Returns:
            dict: A dictionary representation of the character,
                  including all its attributes.
        """
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
            "personality_sliders": self.personality_sliders or {},
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

PERSONALITY_SLIDER_DEFINITIONS = {
    "organization_planning": {"label": "Organization & Planning", "left_label": "Tidy Planner", "right_label": "Messy Freestyle"},
    "assertiveness": {"label": "Voice Style", "left_label": "Bold Voice", "right_label": "Soft Voice"},
    "sociability": {"label": "Social Energy", "left_label": "Jump-Right-In", "right_label": "Warm-Up-First"},
    "adventure": {"label": "Adventure Level", "left_label": "Let's Explore!", "right_label": "Careful Steps"},
    "expressiveness": {"label": "Energy Level", "left_label": "Mega Energy", "right_label": "Calm Breeze"},
    "feelings_sharing": {"label": "Feelings Expression", "left_label": "Heart-On-Sleeve", "right_label": "Quiet Feelings"},
    "problem_solving": {"label": "Problem-Solving Style", "left_label": "Brainy Builder", "right_label": "Imagination Wiz"},
    "play_preference": {"label": "Play Preference", "left_label": "Caring & Nurturing", "right_label": "Building & Action"},
}


def _ensure_personality_slider_column():
    """
    Ensures that the 'personality_sliders' column exists in the Character table.

    This function is a migration helper. If an existing SQLite database file
    (e.g., 'characters.db') is loaded and the 'personality_sliders' column
    is missing from the 'Character' table, it adds the column as TEXT.
    This prevents errors when loading older database schemas.
    """
    table_name = Character.__tablename__ or "character"
    try:
        with db.engine.connect() as conn:
            result = conn.execute(text(f"PRAGMA table_info({table_name})"))
            columns = {row[1] for row in result}
            if "personality_sliders" not in columns:
                conn.execute(text(f"ALTER TABLE {table_name} ADD COLUMN personality_sliders TEXT"))
                logger.info("Added missing column 'personality_sliders' to %s", table_name)
    except Exception as exc:
        logger.warning("Unable to ensure personality_sliders column exists: %s", exc)


with app.app_context():
    db.create_all()
    _ensure_personality_slider_column()

# ----------------------
# Gemini setup
# ----------------------
api_key = os.getenv("GEMINI_API_KEY")

# --- DEBUG LINES START ---
print(f"API KEY EXISTS: {bool(api_key)}")
print(f"API KEY LENGTH: {len(api_key) if api_key else 0}")
print(f"RAW GEMINI_MODEL ENV VAR: {os.getenv('GEMINI_MODEL')}")
print(f"MODEL (after default): {os.getenv('GEMINI_MODEL', 'gemini-1.5-flash')}")
# --- DEBUG LINES END ---

if not api_key:
    logger.warning("GEMINI_API_KEY not set. Generation endpoints will use fallbacks.")
else:
    genai.configure(api_key=api_key)

GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
try:
    model = genai.GenerativeModel(GEMINI_MODEL) if api_key else None
except Exception as e:
    logger.exception("Failed to initialize Gemini model: %s", e)
    model = None

# ----------------------
# Story components
# ----------------------
class StoryStructures:
    """
    Provides predefined story structures and plot twists for story generation.
    """
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
        """
        Retrieves a random story structure, optionally filtered by theme.

        Args:
            theme (str | None): An optional theme to prioritize specific structures.

        Returns:
            dict: A dictionary containing the name and structure of the chosen story template.
        """
        if theme:
            t = theme.lower()
            if "friend" in t:
                return next((s for s in cls.ADVENTURE_TEMPLATES if s["name"] == "The Friendship"), random.choice(cls.ADVENTURE_TEMPLATES))
            if any(x in t for x in ["discover", "mystery", "secret"]):
                return next((s for s in cls.ADVENTURE_TEMPLATES if s["name"] == "The Discovery"), random.choice(cls.ADVENTURE_TEMPLATES))
        return random.choice(cls.ADVENTURE_TEMPLATES)

class CompanionDynamics:
    """
    Manages information about story companions and their contributions.
    """
    COMPANION_ROLES = {
        "Loyal Dog": {"contribution": "sniffs out clues and warns of danger"},
        "Mysterious Cat": {"contribution": "guides through dark places and senses magic"},
        "Mischievous Fairy": {"contribution": "unlocks small spaces and talks to creatures"},
        "Tiny Dragon": {"contribution": "provides aerial view and dragon wisdom"},
    }
    @classmethod
    def get_companion_info(cls, companion_name: str | None):
        """
        Retrieves the contribution of a specified companion.

        Args:
            companion_name (str | None): The name of the companion.

        Returns:
            dict | None: A dictionary describing the companion's contribution,
                         or None if the companion is not found or not provided.
        """
        if not companion_name:
            return None
        return cls.COMPANION_ROLES.get(companion_name, {"contribution": "provides emotional support"})

class WisdomGems:
    """
    Provides a collection of wisdom gems/morals for story conclusions.
    """
    THEME_WISDOM = {
        "Adventure": ["The greatest adventures begin with a single brave step"],
        "Friendship": ["True friends accept you exactly as you are"],
        "Magic": ["Real magic comes from believing in yourself"],
    }
    @classmethod
    def get_wisdom(cls, theme: str | None):
        """
        Retrieves a random wisdom gem, optionally filtered by theme.

        Args:
            theme (str | None): An optional theme to prioritize specific wisdom.

        Returns:
            str: A wisdom gem string.
        """
        return random.choice(cls.THEME_WISDOM.get(theme, cls.THEME_WISDOM["Adventure"]))

class AdvancedStoryEngine:
    """
    Orchestrates the generation of enhanced story prompts using various components.
    """
    def __init__(self):
        """
        Initializes the AdvancedStoryEngine with instances of StoryStructures,
        CompanionDynamics, and WisdomGems.
        """
        self.story_structures = StoryStructures()
        self.companion_dynamics = CompanionDynamics()
        self.wisdom_gems = WisdomGems()

    def generate_enhanced_prompt(
        self,
        character: str,
        theme: str,
        companion: str | None,
        therapeutic_prompt: str = "",
        feelings_prompt: str | None = None,
    ):
        """
        Generates an enhanced story prompt for the Gemini model.

        Args:
            character (str): The main character's name or description.
            theme (str): The theme of the story.
            companion (str | None): An optional companion for the character.
            therapeutic_prompt (str): Optional therapeutic elements to include.
            feelings_prompt (str | None): Optional feelings-focused guidance.

        Returns:
            str: The complete, formatted story prompt.
        """
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
        if feelings_prompt:
            parts.extend([
                "\nFEELINGS-FOCUSED GUIDANCE:",
                feelings_prompt,
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
            "\nSENSORY-RICH WRITING:",
            "- Use SENSORY DETAILS: What does the character see, hear, feel, smell, taste?",
            "- SHOW emotions through body language: 'heart racing', 'palms sweating', 'warm feeling spreading'",
            "- Use VIVID DESCRIPTIONS: colors, sounds, textures, temperatures",
            "- Create IMMERSIVE scenes that readers can picture clearly",
            "- Example: Instead of 'Emma was scared', write 'Emma's heart pounded as shadows danced on the wall'",
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
    """
    Safely extracts the title and wisdom gem from a generated story text.

    Args:
        text (str): The raw story text generated by the model.
        theme (str): The theme of the story, used as a fallback for the wisdom gem.

    Returns:
        tuple[str, str, str]: A tuple containing the extracted title,
                              wisdom gem, and the story body.
    """
    title_match = _TITLE_RE.search(text or "")
    gem_match = _GEM_RE.search(text or "")
    title = title_match.group(1).strip() if title_match and title_match.group(1).strip() else "A Brave Little Adventure"
    wisdom_gem = gem_match.group(1).strip() if gem_match and gem_match.group(1).strip() else WisdomGems.get_wisdom(theme)
    story_body = _TITLE_RE.sub("", text or "").strip()
    story_body = _GEM_RE.sub("", story_body).strip()
    return title, wisdom_gem, story_body

def _clamp_slider_value(value):
    """
    Clamps a given slider value to be within the range of 0 to 100.

    Args:
        value: The raw slider value, which can be an int, float, or string.

    Returns:
        int | None: The clamped integer value (0-100), or None if the input
                    cannot be converted to a number.
    """
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(max(0, min(100, round(value))))
    if isinstance(value, str):
        try:
            return _clamp_slider_value(float(value))
        except (TypeError, ValueError):
            return None
    return None


def _sanitize_personality_sliders(raw_value):
    """
    Sanitizes a dictionary of personality slider values.

    Ensures that only valid slider keys are present and their values are
    clamped between 0 and 100.

    Args:
        raw_value (dict): A dictionary of raw personality slider values.

    Returns:
        dict: A sanitized dictionary with clamped slider values.
    """
    if not raw_value or not isinstance(raw_value, dict):
        return {}
    sanitized = {}
    for key in PERSONALITY_SLIDER_DEFINITIONS:
        if key not in raw_value:
            continue
        clamped = _clamp_slider_value(raw_value.get(key))
        if clamped is not None:
            sanitized[key] = clamped
    return sanitized


def _describe_slider_value(value, left_label, right_label):
    """
    Generates a human-readable description for a single personality slider value.

    Args:
        value (int | None): The clamped slider value (0-100).
        left_label (str): The label for the left extreme of the slider.
        right_label (str): The label for the right extreme of the slider.

    Returns:
        str | None: A descriptive string (e.g., "strongly leans Bold Voice"),
                    or None if the value is None.
    """
    if value is None:
        return None
    delta = abs(value - 50)
    if delta <= 5:
        return f"balanced between {left_label.lower()} and {right_label.lower()}"
    direction = right_label if value > 50 else left_label
    if delta >= 30:
        qualifier = "strongly "
    elif delta >= 15:
        qualifier = "leans "
    else:
        qualifier = "slightly "
    return f"{qualifier}{direction.lower()}"


def _describe_personality_sliders(personality_sliders):
    """
    Generates a list of human-readable descriptions for all personality slider values.

    Args:
        personality_sliders (dict): A dictionary of personality slider values.

    Returns:
        list[str]: A list of descriptive strings for each slider.
    """
    if not personality_sliders:
        return []
    lines = ["\nPERSONALITY STYLE DIALS: (0 = left trait, 100 = right trait)"]
    for key, meta in PERSONALITY_SLIDER_DEFINITIONS.items():
        value = personality_sliders.get(key)
        if value is None:
            continue
        descriptor = _describe_slider_value(
            value, meta["left_label"], meta["right_label"]
        )
        if descriptor:
            toward = meta["right_label"] if value > 50 else meta["left_label"]
            lines.append(
                f"- {meta['label']}: {descriptor} ({value}/100 toward {toward.lower()})"
            )
    return lines


def _build_character_integration(character_name, fears, strengths, likes, dislikes, comfort_item, personality_traits, personality_sliders):
    """
    Builds a detailed character integration prompt for personalized, therapeutic storytelling.

    This prompt incorporates various character attributes like fears, strengths, likes,
    dislikes, comfort items, personality traits, and slider values to guide the
    story generation towards a therapeutic and engaging narrative.

    Args:
        character_name (str): The name of the main character.
        fears (list): A list of the character's fears.
        strengths (list): A list of the character's strengths.
        likes (list): A list of things the character likes.
        dislikes (list): A list of things the character dislikes.
        comfort_item (str): The character's comfort item.
        personality_traits (list): A list of the character's personality traits.
        personality_sliders (dict): A dictionary of the character's personality slider values.

    Returns:
        str: A formatted string containing deep character integration details for the story prompt.
    """

    parts = [
        "DEEP CHARACTER INTEGRATION:",
        f"Character Name: {character_name}",
    ]

    # Personality
    if personality_traits:
        traits_str = ", ".join(personality_traits)
        parts.append(f"Personality: {traits_str}")

    slider_lines = _describe_personality_sliders(personality_sliders)
    if slider_lines:
        parts.extend(slider_lines)

    # Fears (Critical for therapeutic stories)
    if fears:
        fears_str = ", ".join(fears)
        parts.extend([
            f"\nFEARS TO ADDRESS: {fears_str}",
            "IMPORTANT: The story MUST help the character face and overcome one of these fears.",
            "Show the character feeling scared at first, then discovering courage and strength.",
            "Make the fear resolution realistic and empowering, not dismissive.",
        ])

    # Strengths (Use these to overcome challenges)
    if strengths:
        strengths_str = ", ".join(strengths)
        parts.extend([
            f"\nSTRENGTHS TO UTILIZE: {strengths_str}",
            f"IMPORTANT: Show how {character_name} uses these strengths to solve problems.",
            "Let the character discover that they already have what they need inside them.",
        ])

    # Comfort item (Emotional security)
    if comfort_item:
        parts.extend([
            f"\nCOMFORT ITEM: {comfort_item}",
            f"Include the {comfort_item} in the story as a source of courage and comfort.",
            f"Perhaps {character_name} carries it during scary moments or it helps them feel brave.",
        ])

    # Likes (Make story engaging)
    if likes:
        likes_str = ", ".join(likes)
        parts.extend([
            f"\nLIKES: {likes_str}",
            f"Incorporate elements related to {likes_str} to make the story personally engaging.",
        ])

    # Dislikes (Add realistic challenges)
    if dislikes:
        dislikes_str = ", ".join(dislikes)
        parts.extend([
            f"\nDISLIKES: {dislikes_str}",
            f"Consider using one of these dislikes as a minor challenge or something {character_name} must face.",
        ])

    # Therapeutic structure
    parts.extend([
        "\nSTORY STRUCTURE (CRITICAL):",
        f"1. BEGINNING: Introduce {character_name} in their normal world, showing their personality traits",
        "2. CHALLENGE: Present a situation that involves one of their fears or growth areas",
        "3. STRUGGLE: Show realistic difficulty - fears are real, challenges are hard",
        "4. DISCOVERY: Character realizes they have inner strength (use their strengths list)",
        "5. RESOLUTION: Character overcomes the challenge, grows emotionally, learns about themselves",
        "6. REFLECTION: End with character feeling proud, more confident, emotionally stronger",
        "\nNARRATIVE REQUIREMENTS:",
        "- Use sensory details (what they see, hear, feel, smell) to make scenes vivid",
        "- Show emotions, don't just tell (e.g., 'heart pounding' not 'felt scared')",
        f"- Keep {character_name} as the main character who drives the action",
        "- Make the therapeutic element natural, not preachy or obvious",
        "- Create a clear emotional arc: vulnerable → challenged → growing → empowered",
    ])

    return "\n".join(parts)


def _get_age_guidelines(age: int) -> dict:
    """
    Retrieves age-appropriate guidelines for story generation.

    Args:
        age (int): The age of the target audience.

    Returns:
        dict: A dictionary containing guidelines for story length, vocabulary,
              sentence structure, concepts, and special instructions.
    """
    if age <= 5:
        return {
            "length_guideline": "100-150 words",
            "vocabulary_level": "very simple vocabulary (CVC + sight words)",
            "sentence_structure": "3-6 word sentences with repetition",
            "vocabulary_examples": "cat, dog, hop, sun, play, happy",
            "concepts": "tangible, concrete ideas only",
            "special_instructions": "Use rhyme, rhythm, and repeatable frames.",
        }
    if age <= 8:
        return {
            "length_guideline": "150-250 words",
            "vocabulary_level": "simple (sight words + basic phonics)",
            "sentence_structure": "short, clear, mostly present-tense sentences",
            "vocabulary_examples": "magic, brave, puzzle, curious",
            "concepts": "simple cause/effect with predictable plots",
            "special_instructions": "Include dialogue and phonics-friendly words.",
        }
    if age <= 12:
        return {
            "length_guideline": "250-400 words",
            "vocabulary_level": "grade-level vocabulary",
            "sentence_structure": "mix of short and complex sentences",
            "vocabulary_examples": "determined, shimmering, mysterious, courageous",
            "concepts": "character growth with layered plots and emotional arcs",
            "special_instructions": "Highlight problem-solving and empathy.",
        }
    if age <= 15:
        return {
            "length_guideline": "400-600 words",
            "vocabulary_level": "advanced / expressive vocabulary",
            "sentence_structure": "sophisticated and varied sentences",
            "vocabulary_examples": "contemplated, resilience, luminous, intricate",
            "concepts": "identity exploration, moral dilemmas, nuanced relationships",
            "special_instructions": "Use nuanced emotions and real-world parallels.",
        }
    return {
        "length_guideline": "600-800 words",
        "vocabulary_level": "mature / literary vocabulary",
        "sentence_structure": "complex, literary prose",
        "vocabulary_examples": "introspective, paradoxical, cathartic, transcendent",
        "concepts": "philosophical questions and mature themes",
        "special_instructions": "Employ literary devices, symbolism, and deep psychology.",
    }


def _build_age_instruction_block(age: int) -> str:
    """
    Constructs a formatted instruction block based on age-appropriate guidelines.

    Args:
        age (int): The age of the target audience.

    Returns:
        str: A multi-line string detailing age-specific story requirements.
    """
    guidelines = _get_age_guidelines(age)
    return (
        f"AGE-APPROPRIATE GUIDELINES FOR {age}-YEAR-OLD:\n"
        f"- LENGTH: {guidelines['length_guideline']} (strict requirement)\n"
        f"- VOCABULARY: {guidelines['vocabulary_level']}\n"
        f"- SENTENCE STYLE: {guidelines['sentence_structure']}\n"
        f"- WORD EXAMPLES: {guidelines['vocabulary_examples']}\n"
        f"- CONCEPTS: {guidelines['concepts']}\n"
        f"- SPECIAL NOTES: {guidelines['special_instructions']}"
    )


def _build_learning_to_read_prompt(character_name, theme, age, character_details, companion=None, extra_characters=None):
    """
    Builds a specialized prompt for generating a rhyming, learning-to-read story.

    This prompt includes strict requirements for length, rhyme scheme, vocabulary,
    and sentence structure suitable for young readers.

    Args:
        character_name (str): The name of the main character.
        theme (str): The theme of the story.
        age (int): The age of the target reader.
        character_details (dict): Additional details about the character.
        companion (str | None): Optional companion for the character.
        extra_characters (list | None): Optional list of extra characters.

    Returns:
        str: The formatted prompt for a learning-to-read story.
    """
    def _format_list(label, values):
        if not values:
            return ""
        clean = [v.strip() for v in values if isinstance(v, str) and v.strip()]
        if not clean:
            return ""
        return f"\n{label}: {', '.join(clean[:5])}"

    detail_section = ""
    if character_details:
        detail_section += _format_list("LIKES", character_details.get("likes"))
        detail_section += _format_list("STRENGTHS", character_details.get("strengths"))
        comfort_item = character_details.get("comfort_item")
        if comfort_item:
            detail_section += f"\nCOMFORT ITEM: {comfort_item}"

    if extra_characters:
        detail_section += f"\nFRIENDS IN STORY: {', '.join(extra_characters[:5])}"

    companion_text = ""
    if companion and companion != "None":
        companion_text = f"\nCOMPANION: Include {companion} as a gentle helper."

    return (
        f"You are creating a LEARNING TO READ rhyming story for a {age}-year-old child named {character_name}.\n\n"
        "STRICT REQUIREMENTS (NO EXCEPTIONS):\n"
        "1. TOTAL LENGTH: 50-100 words only.\n"
        "2. RHYME PATTERN: AABB (line 1 rhymes with line 2, line 3 with line 4, etc.).\n"
        "3. LINE LENGTH: Each line must use only 4-6 simple words.\n"
        "4. VOCABULARY: Only CVC words (cat, dog, hop, sun) and common sight words (the, and, can, see, like, play). "
        "Avoid blends, silent letters, or complex spelling patterns.\n"
        f"5. STRUCTURE: Repetition helps reading. Use predictable frames like \"Can {character_name} ___? Yes, {character_name} can ___!\".\n"
        "6. TONE: Encouraging, musical, confident.\n"
        "7. FORMAT: Place each short sentence or clause on its own line for easy finger tracking.\n\n"
        f"THEME: {theme}{companion_text}{detail_section}\n\n"
        f"Create the rhyming learning-to-read story about {character_name} now."
    )

def _as_list(v):
    """
    Converts various input types (list, JSON string, comma-separated string, None)
    into a list of strings.

    Args:
        v (any): The input value to convert.

    Returns:
        list[str]: A list of strings.
    """
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

def _extract_current_feeling(container):
    """
    Extracts and normalizes current feeling data from a request payload.

    Handles variations in key naming (e.g., "current_feeling" vs "currentFeeling")
    and ensures intensity and coping strategies are correctly formatted.

    Args:
        container (dict): The request payload dictionary.

    Returns:
        dict | None: A normalized dictionary of feeling data, or None if no
                     meaningful feeling data is present.
    """
    """Return a normalized current feeling dictionary or None."""
    if not isinstance(container, dict):
        return None
    feeling = container.get("current_feeling")
    if feeling is None and "currentFeeling" in container:
        feeling = container.get("currentFeeling")
    if not isinstance(feeling, dict):
        return None

    def _clean(value):
        if value is None:
            return None
        value_str = str(value).strip()
        return value_str or None

    intensity = feeling.get("intensity")
    try:
        intensity = int(intensity)
    except (TypeError, ValueError):
        intensity = None
    else:
        intensity = max(1, min(intensity, 5))

    coping_value = feeling.get("coping_strategies")
    if coping_value is None and "copingStrategies" in feeling:
        coping_value = feeling.get("copingStrategies")
    coping_strategies = [item for item in _as_list(coping_value) if item]

    # Handle both old emotion structure and new feelings wheel structure
    emotion_name = (
        _clean(feeling.get("emotion_name") or feeling.get("emotionName"))
        or _clean(feeling.get("tertiary_emotion"))  # New feelings wheel
        or _clean(feeling.get("secondary_emotion"))  # Fallback to secondary
        or _clean(feeling.get("core_emotion"))  # Fallback to core
    )

    normalized = {
        "emotion_id": _clean(feeling.get("emotion_id") or feeling.get("emotionId") or feeling.get("tertiary_emotion")),
        "emotion_name": emotion_name,
        "emotion_emoji": _clean(feeling.get("emotion_emoji") or feeling.get("emotionEmoji")),
        "emotion_description": _clean(feeling.get("emotion_description") or feeling.get("emotionDescription")),
        "intensity": intensity,
        "what_happened": _clean(feeling.get("what_happened") or feeling.get("whatHappened")),
        "physical_signs": _clean(feeling.get("physical_signs") or feeling.get("physicalSigns")),
        "coping_strategies": coping_strategies,
    }

    # If no meaningful data, return None
    if not any(value for key, value in normalized.items() if key != "coping_strategies"):
        if not normalized["coping_strategies"]:
            return None
    return normalized

def _build_feelings_prompt(character_name: str, feeling: dict | None) -> str:
@app.route("/metrics")
def metrics():
    return generate_latest(registry), 200, {"Content-Type": "text/plain; charset=utf-8"}
    """
    Builds a feelings-focused prompt section for story generation.

    This prompt guides the story to acknowledge, validate, and help the character
    process their emotions, incorporating coping strategies.

    Args:
        character_name (str): The name of the main character.
        feeling (dict | None): A dictionary of normalized feeling data, or None.

    Returns:
        str: A formatted string containing feelings-focused guidance for the story prompt.
    """
    if not feeling:
        return ""

    emotion_name = feeling.get("emotion_name") or "a big feeling"
    emoji = feeling.get("emotion_emoji") or ""
    description = feeling.get("emotion_description")
    what_happened = feeling.get("what_happened")
    physical_signs = feeling.get("physical_signs")
    intensity = feeling.get("intensity")
    coping = feeling.get("coping_strategies") or []

    lines = [
        f"- Current emotion: {emotion_name} {emoji}".strip(),
    ]
    if intensity:
        lines.append(f"- Intensity: {intensity} out of 5 (1=calm, 5=very strong).")
    if description:
        lines.append(f"- How it feels: {description}.")
    if what_happened:
        lines.append(f"- Recent situation: {what_happened}.")
    if physical_signs:
        lines.append(f"- Body clues: {physical_signs}.")
    if coping:
        strategies = ", ".join(coping)
        lines.append(f"- Coping strategies to highlight: {strategies}.")

    guidelines = [
        f"1. Begin the story by acknowledging that {character_name} feels {emotion_name.lower()} and why.",
        "2. Validate the feeling with compassionate language (all feelings are okay).",
        "3. Describe the character's body sensations and thoughts tied to the emotion.",
        "4. Weave coping strategies into the narrative in a natural, supportive way.",
        "5. Show the character processing the feeling, using coping skills, and noticing a shift.",
        "6. End with hopeful reflection—what the character learned about their feelings.",
    ]

    return "\n".join([
        *lines,
        "\nFEELINGS STORY REQUIREMENTS:",
        *guidelines,
        "7. Keep the tone gentle, therapeutic, and empowering throughout.",
    ])

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
    rhyme_time_mode = payload.get("rhyme_time_mode", False)
    learning_to_read_mode = payload.get("learning_to_read_mode", False)
    character = payload.get("character", "a brave adventurer")
    theme = payload.get("theme", "Adventure")
    companion = payload.get("companion")
    therapeutic_prompt = payload.get("therapeutic_prompt", "")
    user_api_key = payload.get("user_api_key")  # Optional user-provided API key
    character_age = payload.get("character_age", 7)  # For age-appropriate content
    current_feeling = _extract_current_feeling(payload)
    feelings_prompt = _build_feelings_prompt(character, current_feeling)
    supporting_characters = (
        payload.get("characters") if isinstance(payload.get("characters"), list) else None
    )

    if learning_to_read_mode:
        rhyme_time_mode = False  # learning mode already enforces rhyme/length

    # Deep character integration - get full character details
    character_details = payload.get("character_details") or {}
    if not isinstance(character_details, dict):
        character_details = {}
    stories_by_theme.labels(theme=theme).inc()
    age_group = "5-8" if character_age <= 8 else "9-12" if character_age <= 12 else "13+"
    stories_by_age.labels(age_group=age_group).inc()
    fears = character_details.get("fears", [])
    strengths = character_details.get("strengths", [])
    story_generation_requests.inc()
    likes = character_details.get("likes", [])
    dislikes = character_details.get("dislikes", [])
    comfort_item = character_details.get("comfort_item", "")
    personality_traits = character_details.get("personality_traits", [])
    personality_sliders = _sanitize_personality_sliders(
        character_details.get("personality_sliders", {})
    )

    age_instruction_block = _build_age_instruction_block(character_age)

    if learning_to_read_mode:
        prompt = _build_learning_to_read_prompt(
            character,
            theme,
            character_age,
            character_details,
            companion=companion,
        if generation_duration:
            story_generation_duration.observe(generation_duration)
            extra_characters=supporting_characters,
        )
    else:
        prompt = story_engine.generate_enhanced_prompt(
            character,
            theme,
            companion,
            therapeutic_prompt,
            feelings_prompt if feelings_prompt else None,
        )
    # Track story generation performance
    start_time = time.time()
    generation_duration = None
        generation_duration = time.time() - start_time
        newrelic.agent.record_custom_metric("Custom/StoryGeneration/Duration", generation_duration)
        newrelic.agent.record_custom_metric("Custom/StoryGeneration/Success", 1)

        character_integration = _build_character_integration(
            character,
            fears,
            strengths,
        newrelic.agent.record_custom_metric("Custom/StoryGeneration/Failure", 1)
            likes,
            dislikes,
            comfort_item,
            personality_traits,
            personality_sliders,
        # Record successful story generation metrics
        generation_time = time.time() - start_time
        story_generation_success = True
        
        # New Relic custom metrics
        import newrelic.agent as nr
        nr.record_custom_metric("Custom/StoryGeneration/Duration", generation_time)
        # Record failed story generation metrics
        generation_time = time.time() - start_time
        import newrelic.agent as nr
        nr.record_custom_metric("Custom/StoryGeneration/Duration", generation_time)
        nr.record_custom_metric("Custom/StoryGeneration/Failure", 1)
        nr.record_custom_event("Custom/StoryGeneration/Error", {
            "error_type": type(e).__name__,
            "error_message": str(e),
            "using_user_key": using_user_key,
            "theme": theme,
            "character_age": character_age
        })
        nr.record_custom_metric("Custom/StoryGeneration/Success", 1)
        if using_user_key:
            nr.record_custom_metric("Custom/StoryGeneration/UserKeyUsage", 1)
        else:
            nr.record_custom_metric("Custom/StoryGeneration/FreeTierUsage", 1)
    # Start timing for story generation metrics
    start_time = time.time()
    story_generation_success = False
        )

        sections = [prompt, character_integration]
        sections.append(f"\n{age_instruction_block}")
        if rhyme_time_mode:
            rhyme_instruction = (
                "\nSTORY STYLE:\n"
                "**This is extremely important:** Write the entire story in a playful, silly, rhyming verse, like a Dr. Seuss or Julia Donaldson book. "
                "Use AABB or ABAB rhyme schemes. The story must rhyme."
            )
            sections.append(rhyme_instruction)
        prompt = "\n\n".join(sections)

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
        print(f"!!! Prompt length: {len(prompt)} characters")
        print(f"!!! Learning to read mode: {learning_to_read_mode}, Rhyme time mode: {rhyme_time_mode}")
        print(f"!!! Character age: {character_age}, Theme: {theme}")
        logger.error("Model error, using fallback story. Error: %s", e, exc_info=True)
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
        "story": story_text,  # Changed from story_text to story for Flutter compatibility
        "story_text": story_text,  # Keep for backward compatibility
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
        personality_sliders=_sanitize_personality_sliders(data.get("personality_sliders")),
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
    if "personality_sliders" in data:
        raw_sliders = data.get("personality_sliders")
        if raw_sliders is None:
            char.personality_sliders = {}
        else:
            char.personality_sliders = _sanitize_personality_sliders(raw_sliders)
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
    current_feeling = _extract_current_feeling(data)

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

    feelings_prompt = _build_feelings_prompt(main_char["name"], current_feeling)
    if feelings_prompt:
        prompt_parts.extend([
            "\nFEELINGS-FOCUSED CONTEXT:",
            feelings_prompt,
        ])

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

    # Start timing for interactive story generation
    start_time = time.time()
    interactive_generation_success = False
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

        # Record successful interactive story generation metrics
        generation_time = time.time() - start_time
        interactive_generation_success = True
        # Record failed interactive story generation metrics
        generation_time = time.time() - start_time
        import newrelic.agent as nr
        nr.record_custom_metric("Custom/InteractiveStoryGeneration/Duration", generation_time)
        nr.record_custom_metric("Custom/InteractiveStoryGeneration/Failure", 1)
        nr.record_custom_event("Custom/InteractiveStoryGeneration/Error", {
            "error_type": type(e).__name__,
            "error_message": str(e),
            "character": character,
            "theme": theme
        })
        
        import newrelic.agent as nr
        nr.record_custom_metric("Custom/InteractiveStoryGeneration/Duration", generation_time)
        nr.record_custom_metric("Custom/InteractiveStoryGeneration/Success", 1)
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
    """
    Continue an interactive story
    ---
    tags:
      - Interactive Story
    summary: Continue an interactive story
    description: Continues an interactive story based on a user's choice, generating the next segment or a conclusion.
    parameters:
      - in: body
        name: body
        schema:
          id: ContinueInteractiveStoryRequest
          type: object
          required:
            - character
            - theme
            - choice
            - story_so_far
            - choices_made
          properties:
            character:
              type: string
              description: The main character's name or description.
              example: "Lily"
            theme:
              type: string
              description: The theme of the interactive story.
              example: "Mystery"
            companion:
              type: string
              description: An optional companion for the character.
              example: "Wise Owl"
            friends:
              type: array
              items:
                type: string
              description: A list of friends or siblings included in the story.
              example: ["Tom", "Mia"]
            choice:
              type: string
              description: The user's chosen option from the previous story segment.
              example: "Enter the dark cave"
            story_so_far:
              type: string
              description: The complete story text generated up to this point.
              example: "Lily stood at the entrance of a dark cave..."
            choices_made:
              type: array
              items:
                type: string
              description: A list of all choices made so far in the story.
              example: ["choice1", "choiceA"]
            therapeutic_prompt:
              type: string
              description: An optional therapeutic element to weave into the story.
              example: "Reinforce courage."
    responses:
      200:
        description: Successfully generated next interactive story segment or conclusion.
        schema:
          $ref: '#/definitions/InteractiveStoryResponse'
      500:
        description: Internal server error or model generation failed.
        schema:
          type: object
          properties:
            error:
              type: string
              description: Error message.
    """
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
    """
    Generate a random superhero
    ---
    tags:
      - Character Management
    summary: Generate a random superhero
    description: Generates a random superhero name, superpower, and mission.
    responses:
      200:
        description: Successfully generated superhero details.
        schema:
          type: object
          properties:
            superhero_name:
              type: string
              description: The generated superhero name.
              example: "Mighty Guardian"
            superpower:
              type: string
              description: The generated superpower.
              example: "Flight"
            mission:
              type: string
              description: The generated superhero mission.
              example: "Protect the city from villains"
    """
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
    """
    Generate story illustrations
    ---
    tags:
      - Story Illustration
    summary: Generate story illustrations
    description: Generates illustrations for provided story scenes using Gemini Imagen, with options for style, age-appropriateness, and therapeutic focus.
    parameters:
      - in: body
        name: body
        schema:
          id: GenerateIllustrationsRequest
          type: object
          required:
            - scenes
          properties:
            scenes:
              type: array
              items:
                type: object
                properties:
                  title:
                    type: string
                    description: Title of the scene.
                  description:
                    type: string
                    description: Detailed visual description of the scene.
              description: A list of scene objects, each with a title and description.
            character_name:
              type: string
              description: The name of the main character to guide illustration generation.
              default: "the hero"
              example: "Lily"
            style:
              type: string
              description: The artistic style for the illustrations.
              default: "children's book illustration"
              example: "watercolor"
            age:
              type: integer
              description: The target age for the illustrations, influencing detail and complexity.
              default: 7
              example: 5
            therapeutic_focus:
              type: string
              description: Optional therapeutic theme to incorporate into the illustrations.
              example: "calming colors"
    responses:
      200:
        description: Successfully generated illustrations.
        schema:
          type: object
          properties:
            illustrations:
              type: array
              items:
                type: object
                properties:
                  scene_title:
                    type: string
                  scene_description:
                    type: string
                  image_data:
                    type: string
                    format: byte
                    description: Base64 encoded PNG image data.
                  image_id:
                    type: string
                  format:
                    type: string
      400:
        description: Missing required scenes.
        schema:
          type: object
          properties:
            error:
              type: string
              description: Error message.
      500:
        description: Internal server error or illustration generation failed.
        schema:
          type: object
          properties:
            error:
              type: string
              description: Error message.
    """
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
    """
    Generate coloring pages from story scenes
    ---
    tags:
      - Story Illustration
    summary: Generate coloring pages from story scenes
    description: Generates coloring book pages for provided story scenes, with options for age-appropriateness and therapeutic focus.
    parameters:
      - in: body
        name: body
        schema:
          id: GenerateColoringPagesRequest
          type: object
          required:
            - scenes
          properties:
            scenes:
              type: array
              items:
                type: object
                properties:
                  title:
                    type: string
                    description: Title of the scene.
                  description:
                    type: string
                    description: Detailed visual description of the scene.
              description: A list of scene objects, each with a title and description.
            character_name:
              type: string
              description: The name of the main character to guide coloring page generation.
              default: "the hero"
              example: "Lily"
            age:
              type: integer
              description: The target age for the coloring pages, influencing intricacy.
              default: 7
              example: 5
            therapeutic_focus:
              type: string
              description: Optional therapeutic theme to incorporate into the coloring pages.
              example: "mindfulness"
    responses:
      200:
        description: Successfully generated coloring pages.
        schema:
          type: object
          properties:
            coloring_pages:
              type: array
              items:
                type: object
                properties:
                  scene_title:
                    type: string
                  scene_description:
                    type: string
                  image_data:
                    type: string
                    format: byte
                    description: Base64 encoded PNG image data.
                  image_id:
                    type: string
                  format:
                    type: string
      400:
        description: Missing required scenes.
        schema:
          type: object
          properties:
            error:
              type: string
              description: Error message.
      500:
        description: Internal server error or coloring page generation failed.
        schema:
          type: object
          properties:
            error:
              type: string
              description: Error message.
    """
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
    """
    Setup test account
    ---
    tags:
      - Admin
    summary: Setup test account
    description: Creates or updates a predefined test character ("Isabella") with unlocked features for testing purposes.
    responses:
      200:
        description: Test account updated successfully.
        schema:
          type: object
          properties:
            status:
              type: string
            character:
              $ref: '#/definitions/CharacterResponse'
            message:
              type: string
      201:
        description: Test account created successfully.
        schema:
          type: object
          properties:
            status:
              type: string
            character:
              $ref: '#/definitions/CharacterResponse'
            message:
              type: string
    """
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
    Get available narrator voices
    ---
    tags:
      - Text-to-Speech
    summary: Get available narrator voices
    description: Retrieves a list of available text-to-speech voices with their details.
    responses:
      200:
        description: A list of available voice options.
        schema:
          type: object
          properties:
            voices:
              type: array
              items:
                type: object
                properties:
                  name:
                    type: string
                    description: The name of the voice.
                  language_codes:
                    type: array
                    items:
                      type: string
                    description: Language codes supported by the voice.
                  ssml_gender:
                    type: string
                    description: The SSML gender of the voice (e.g., "FEMALE", "MALE", "NEUTRAL").
                  natural_sample_rate_hertz:
                    type: integer
                    description: The natural sample rate in Hertz.
            status:
              type: string
              description: Status of the request (e.g., "success").
      500:
        description: Error retrieving voices.
        schema:
          type: object
          properties:
            error:
              type: string
              description: Error message.
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
    Generate speech audio from text
    ---
    tags:
      - Text-to-Speech
    summary: Generate speech audio from text
    description: Converts provided text into high-quality speech audio using Google Cloud TTS.
    parameters:
      - in: body
        name: body
        schema:
          id: GenerateSpeechRequest
          type: object
          required:
            - text
          properties:
            text:
              type: string
              description: The text to be converted to speech.
              example: "Hello, this is a story."
            voice_name:
              type: string
              description: The name of the voice to use for narration.
              default: "en-US-Neural2-F"
              example: "en-GB-Wavenet-A"
            speaking_rate:
              type: number
              format: float
              description: The speed of the speech (0.25 to 4.0).
              default: 1.0
              example: 1.2
            pitch:
              type: number
              format: float
              description: The pitch of the speech (-20.0 to 20.0).
              default: 0.0
              example: 2.5
            use_ssml:
              type: boolean
              description: Whether to use SSML (Speech Synthesis Markup Language) for natural pauses.
              default: true
              example: false
    responses:
      200:
        description: Successfully generated speech audio.
        schema:
          type: string
          format: binary
          description: MP3 audio file.
      400:
        description: Invalid parameters or no text provided.
        schema:
          type: object
          properties:
            error:
              type: string
              description: Error message.
      500:
        description: Internal server error or speech generation failed.
        schema:
          type: object
          properties:
            error:
              type: string
              description: Error message.
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
    # Use PORT from environment (Railway sets this)
    port = int(os.environ.get("PORT", 5000))
    # Bind to 0.0.0.0 for Railway
    app.run(host="0.0.0.0", port=port, debug=False)
>>>>>>> Stashed changes
