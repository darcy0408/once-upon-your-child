from flask import Blueprint, jsonify, request

from ..database import db
from ..services import character_service
from ..middleware.auth import require_auth
from ..models.character import Character

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

    return character_bp
