
import uuid
import json
from ..repositories import character_repository
from ..models import Character

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

def create_character(data: dict):
    missing = [k for k in ("name", "age") if not data.get(k)]
    if missing:
        return {"error": f"Missing required field(s): {', '.join(missing)}"}, 400
    try:
        age = int(data.get("age"))
    except (ValueError, TypeError):
        return {"error": "'age' must be an integer"}, 400

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
    character_repository.add_character(new_character)
    return new_character.to_dict(), 201

def get_characters():
    """Return a simple LIST to match the Flutter code that expects a list."""
    chars = character_repository.get_all_characters()
    return [c.to_dict() for c in chars], 200

def get_character(char_id: str):
    char = character_repository.get_character_by_id(char_id)
    if not char:
        return {"error": "Character not found"}, 404
    return char.to_dict(), 200

def update_character(char_id: str, data: dict):
    """Partial update allowed."""
    char = character_repository.get_character_by_id(char_id)
    if not char:
        return {"error": "Character not found"}, 404

    if "name" in data:
        char.name = (data["name"] or "").strip() or char.name
    if "age" in data:
        try:
            char.age = int(data["age"])
        except (TypeError, ValueError):
            return {"error": "'age' must be an integer"}, 400
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

    character_repository.update_character(char)
    return char.to_dict(), 200

def delete_character(char_id: str):
    char = character_repository.get_character_by_id(char_id)
    if not char:
        return {"error": "Character not found"}, 404
    character_repository.delete_character(char)
    return {"status": "deleted", "id": char_id}, 200