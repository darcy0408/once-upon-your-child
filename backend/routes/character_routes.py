from flask import Blueprint, jsonify, request

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
        char = Character.query.get(char_id)
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
        char = Character.query.get(char_id)
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
        # TODO: Filter by user_id in service? Current service gets ALL characters.
        # Ideally, we should update service to filter by user_id
        # For now, let's filter the result here or just allow it if intended (but report said IDOR)
        # Given "get-characters" implies listing user's characters:
        
        # Use repository directly or add filter to service?
        # Service has `get_characters` calling `repository.get_all_characters()`
        # We should update service to accept user_id
        
        # Since I didn't update service signature for get_characters, I'll filter logic here if possible, 
        # but better to update service. However, for immediate security, let's update service later/now.
        # Actually, let's just secure the endpoint for now and maybe filter in memory (inefficient but safe) or leave it if it's "all public characters".
        # But assume they want private helper characters.
        
        # Updating service to filter by current user is best practice.
        # I will leave this as is for a moment but add @require_auth.
        # Actually I should fix it properly.
        # Let's just add auth for now.
        
        response, status_code = character_service.get_characters()
        
        # Filter response if it returns a list
        if status_code == 200 and isinstance(response, list):
             filtered = [c for c in response if not c.get('user_id') or str(c.get('user_id')) == str(request.current_user.id)]
             return jsonify(filtered), 200

        logger.info(f"Get characters result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route("/characters/<string:char_id>", methods=["GET"])
    @require_auth
    def get_character_endpoint(char_id: str):
        logger.info(f"GET /characters/{char_id} called")
        
        # Ownership check
        char = Character.query.get(char_id)
        if not char:
            return jsonify({"error": "Character not found"}), 404
        if char.user_id and str(char.user_id) != str(request.current_user.id):
             return jsonify({'error': 'Unauthorized'}), 403

        response, status_code = character_service.get_character(char_id)
        logger.info(f"Get character result: {status_code}")
        return jsonify(response), status_code

    return character_bp
