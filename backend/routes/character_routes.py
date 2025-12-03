from flask import Blueprint, jsonify, request

from ..services import character_service


def create_character_blueprint(limiter, logger):
    character_bp = Blueprint("character", __name__)

    @limiter.limit("20 per hour")
    @character_bp.route("/create-character", methods=["POST"])
    def create_character_endpoint():
        logger.info("POST /create-character called")
        data = request.get_json(silent=True) or {}
        response, status_code = character_service.create_character(data)
        logger.info(f"Character creation result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route("/characters/<string:char_id>", methods=["PATCH", "PUT"])
    def update_character_endpoint(char_id: str):
        logger.info(f"PATCH/PUT /characters/{char_id} called")
        data = request.get_json(silent=True) or {}
        response, status_code = character_service.update_character(char_id, data)
        logger.info(f"Character update result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route("/characters/<string:char_id>", methods=["DELETE"])
    def delete_character_endpoint(char_id: str):
        logger.info(f"DELETE /characters/{char_id} called")
        response, status_code = character_service.delete_character(char_id)
        logger.info(f"Character deletion result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route("/get-characters", methods=["GET"])
    def get_characters_endpoint():
        logger.info("GET /get-characters called")
        response, status_code = character_service.get_characters()
        logger.info(f"Get characters result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route("/characters/<string:char_id>", methods=["GET"])
    def get_character_endpoint(char_id: str):
        logger.info(f"GET /characters/{char_id} called")
        response, status_code = character_service.get_character(char_id)
        logger.info(f"Get character result: {status_code}")
        return jsonify(response), status_code

    return character_bp
