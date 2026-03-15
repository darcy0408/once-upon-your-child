import re

from flask import Blueprint, jsonify, request

from ..database import db
from ..services import character_service
from ..middleware.auth import require_auth
from ..models.character import Character
from ..models.parent_hidden_context import ParentHiddenContext
from ..utils.validators import sanitize_text

_PARENT_CONTEXT_REQUIRED_FIELDS = (
    "feeling",
    "trigger",
    "body_signal",
    "coping_tool",
    "repair_goal",
)


def _contains_disallowed_pii(value: str | None) -> bool:
    if not value:
        return False
    patterns = [
        r"\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b",
        r"\b(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?){2}\d{4}\b",
        r"https?://",
    ]
    return any(re.search(pattern, value) for pattern in patterns)


def _sanitize_parent_hidden_payload(data: dict) -> tuple[dict | None, str | None]:
    sanitized = {}
    for field in _PARENT_CONTEXT_REQUIRED_FIELDS:
        value = sanitize_text(data.get(field), max_length=160)
        if not value:
            return None, f"{field} is required"
        if _contains_disallowed_pii(value):
            return None, f"{field} contains disallowed personal information"
        sanitized[field] = value

    note = sanitize_text(data.get("parent_hidden_context"), max_length=280)
    if note and _contains_disallowed_pii(note):
        return None, "parent_hidden_context contains disallowed personal information"
    sanitized["parent_hidden_context"] = note or None
    return sanitized, None

def create_character_blueprint(limiter, logger):
    character_bp = Blueprint("character", __name__)

    @limiter.limit("20 per hour")
    @character_bp.route("/create-character", methods=["POST"])
    @require_auth
    def create_character_endpoint():
        logger.info("POST /create-character called")
        data = request.get_json(silent=True) or {}
        # Enforce user ownership
        data['user_id'] = request.current_user.id
        
        response, status_code = character_service.create_character(data)
        logger.info(f"Character creation result: {status_code}")
        return jsonify(response), status_code

    @limiter.limit("30 per hour")
    @character_bp.route("/characters/<string:char_id>", methods=["PATCH", "PUT"])
    @require_auth
    def update_character_endpoint(char_id: str):
        logger.info(f"PATCH/PUT /characters/{char_id} called")
        
        # Ownership check
        char = db.session.get(Character, char_id)
        if not char:
            return jsonify({"error": "Character not found"}), 404
        if char.user_id and str(char.user_id) != str(request.current_user.id):
             return jsonify({'error': 'Unauthorized'}), 403
            
        data = request.get_json(silent=True) or {}
        response, status_code = character_service.update_character(char_id, data)
        logger.info(f"Character update result: {status_code}")
        return jsonify(response), status_code

    @limiter.limit("10 per hour")
    @character_bp.route("/characters/<string:char_id>", methods=["DELETE"])
    @require_auth
    def delete_character_endpoint(char_id: str):
        logger.info(f"DELETE /characters/{char_id} called")
        
        # Ownership check
        char = db.session.get(Character, char_id)
        if not char:
            return jsonify({"error": "Character not found"}), 404
        if char.user_id and str(char.user_id) != str(request.current_user.id):
             return jsonify({'error': 'Unauthorized'}), 403

        response, status_code = character_service.delete_character(char_id)
        logger.info(f"Character deletion result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route("/get-characters", methods=["GET"])
    @require_auth
    def get_characters_endpoint():
        logger.info("GET /get-characters called")
        
        # Filter by current user ID at the service/database level
        user_id = request.current_user.id
        response, status_code = character_service.get_characters(user_id=user_id)
        
        logger.info(f"Get characters result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route("/characters/<string:char_id>", methods=["GET"])
    @require_auth
    def get_character_endpoint(char_id: str):
        logger.info(f"GET /characters/{char_id} called")
        
        # Ownership check
        char = db.session.get(Character, char_id)
        if not char:
            return jsonify({"error": "Character not found"}), 404
        if char.user_id and str(char.user_id) != str(request.current_user.id):
             return jsonify({'error': 'Unauthorized'}), 403

        response, status_code = character_service.get_character(char_id)
        logger.info(f"Get character result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route("/child-profiles/<string:profile_id>/parent-hidden-context", methods=["GET"])
    @require_auth
    def get_parent_hidden_context_endpoint(profile_id: str):
        logger.info(f"GET /child-profiles/{profile_id}/parent-hidden-context called")
        context = ParentHiddenContext.query.filter_by(
            user_id=request.current_user.id,
            child_profile_id=profile_id,
        ).first()
        return jsonify({"parent_hidden_context": context.to_dict() if context else None}), 200

    @limiter.limit("20 per hour")
    @character_bp.route("/child-profiles/<string:profile_id>/parent-hidden-context", methods=["PUT"])
    @require_auth
    def save_parent_hidden_context_endpoint(profile_id: str):
        logger.info(f"PUT /child-profiles/{profile_id}/parent-hidden-context called")
        payload = request.get_json(silent=True) or {}
        sanitized, error = _sanitize_parent_hidden_payload(payload)
        if error:
            return jsonify({"error": error}), 400

        context = ParentHiddenContext.query.filter_by(
            user_id=request.current_user.id,
            child_profile_id=profile_id,
        ).first()
        if context is None:
            context = ParentHiddenContext(
                user_id=request.current_user.id,
                child_profile_id=profile_id,
            )
            db.session.add(context)

        for key, value in sanitized.items():
            setattr(context, key, value)

        db.session.commit()
        return jsonify({"parent_hidden_context": context.to_dict()}), 200

    return character_bp
