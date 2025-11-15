from flask import Blueprint, request, jsonify
from backend.models.character import Character
from backend.database import db
import uuid
from datetime import datetime
from backend.services.emotion_service import _as_list # Import _as_list from emotion_service

character_bp = Blueprint('character', __name__)



@character_bp.route("/create-character", methods=["POST"])
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

@character_bp.route("/characters/<string:char_id>", methods=["PATCH", "PUT"])
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

@character_bp.route("/characters/<string:char_id>", methods=["DELETE"])
def delete_character(char_id: str):
    char = db.session.get(Character, char_id)
    if not char:
        return jsonify({"error": "Character not found"}), 404
    db.session.delete(char)
    db.session.commit()
    return jsonify({"status": "deleted", "id": char_id}), 200

@character_bp.route("/get-characters", methods=["GET"])
def get_characters():
    """Return a simple LIST to match the Flutter code that expects a list."""
    chars = Character.query.order_by(Character.created_at.desc()).all()
    return jsonify([c.to_dict() for c in chars]), 200

@character_bp.route("/characters/<string:char_id>", methods=["GET"])
def get_character(char_id: str):
    char = db.session.get(Character, char_id)
    if not char:
        return jsonify({"error": "Character not found"}), 404
    return jsonify(char.to_dict()), 200
