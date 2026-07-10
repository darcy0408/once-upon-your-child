import logging

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

try:
    from backend.services.achievement_service import AchievementService
except ImportError:
    from services.achievement_service import AchievementService


logger = logging.getLogger(__name__)


def create_achievement_blueprint(limiter=None):
    """Factory function to create achievement blueprint with rate limiting."""
    achievement_bp = Blueprint("achievement", __name__)
    achievement_service = AchievementService()

    @achievement_bp.route("/sync", methods=["POST"])
    @jwt_required()
    @limiter.limit("30 per minute")  # Sync can be frequent but limit abuse
    def sync_achievements():
        """Sync achievement progress from client to server."""
        try:
            user_id = get_jwt_identity()
            data = request.get_json(silent=True) or {}

            result = achievement_service.sync_achievement_progress(user_id, data)
            return jsonify(result), 200 if result["status"] == "success" else 400

        except Exception as e:
            logger.error(f"Error syncing achievements: {e}")
            return (
                jsonify({"status": "error", "message": "Failed to sync achievements"}),
                500,
            )

    @achievement_bp.route("/data", methods=["GET"])
    @jwt_required()
    @limiter.limit("60 per minute")  # Read-heavy endpoint
    def get_achievement_data():
        """Get all achievement data for the current user."""
        try:
            user_id = get_jwt_identity()
            data = achievement_service.get_achievement_data(user_id)
            return jsonify(data), 200

        except Exception as e:
            logger.error(f"Error getting achievement data: {e}")
            return (
                jsonify(
                    {"status": "error", "message": "Failed to get achievement data"}
                ),
                500,
            )

    return achievement_bp
