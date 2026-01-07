
import uuid
import json

from ..repositories import character_repository
from ..models.character import Character

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
    print(f"\n[DEBUG create_character] Received data: {data}")
    print(f"[DEBUG create_character] Pets field: {data.get('pets', 'NOT PROVIDED')}")

    missing = [k for k in ("name", "age") if not data.get(k)]
    if missing:
        return {"error": f"Missing required field(s): {', '.join(missing)}"}, 400
    try:
        age = int(data.get("age"))
    except (ValueError, TypeError):
        return {"error": "'age' must be an integer"}, 400

    new_character = Character()
    new_character.id = str(uuid.uuid4())
    new_character.name = str(data.get("name")).strip()
    new_character.age = age
    new_character.gender = data.get("gender")
    new_character.role = data.get("role")
    new_character.magic_type = data.get("magic_type")
    new_character.challenge = data.get("challenge")
    new_character.character_type = data.get("character_type", "Everyday Kid")
    new_character.superhero_name = data.get("superhero_name")
    new_character.mission = data.get("mission")
    new_character.hair = data.get("hair")
    new_character.eyes = data.get("eyes")
    new_character.outfit = data.get("outfit")
    new_character.personality_traits = _as_list(data.get("traits", []))
    new_character.personality_sliders = _sanitize_personality_sliders(data.get("personality_sliders"))
    new_character.likes = _as_list(data.get("likes", []))
    new_character.dislikes = _as_list(data.get("dislikes", []))
    new_character.fears = _as_list(data.get("fears", []))
    new_character.strengths = _as_list(data.get("strengths", []))
    new_character.goals = _as_list(data.get("goals", []))
    new_character.pets = data.get("pets", [])
    new_character.comfort_item = data.get("comfort_item")

    # Avataaars customization (DiceBear)
    new_character.avatar_params = data.get("avatar_params")

    print(f"[DEBUG create_character] Setting pets to: {new_character.pets}")

    character_repository.add_character(new_character)

    print(f"[DEBUG create_character] After save, character.pets: {new_character.pets}")

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
    print(f"\n[DEBUG update_character] Character ID: {char_id}")
    print(f"[DEBUG update_character] Received data: {data}")
    print(f"[DEBUG update_character] Pets field: {data.get('pets', 'NOT PROVIDED')}")

    char = character_repository.get_character_by_id(char_id)
    if not char:
        return {"error": "Character not found"}, 404

    print(f"[DEBUG update_character] Current pets before update: {char.pets}")

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
    if "pets" in data:
        char.pets = data.get("pets", [])  # Pets are already list of dicts, don't use _as_list
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
    if "pets" in data:
        char.pets = data["pets"] if isinstance(data["pets"], list) else []
        print(f"[DEBUG update_character] Set pets to: {char.pets}")

    print(f"[DEBUG update_character] Final pets before save: {char.pets}")

    character_repository.update_character(char)

    print(f"[DEBUG update_character] After save, character.pets: {char.pets}")

    return char.to_dict(), 200

def delete_character(char_id: str):
    char = character_repository.get_character_by_id(char_id)
    if not char:
        return {"error": "Character not found"}, 404
    character_repository.delete_character(char)
    return {"status": "deleted", "id": char_id}, 200