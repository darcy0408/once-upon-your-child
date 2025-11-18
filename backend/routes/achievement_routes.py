from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from backend.services.achievement_service import AchievementService
import logging

logger = logging.getLogger(__name__)

achievement_bp = Blueprint('achievement', __name__)
achievement_service = AchievementService()

@achievement_bp.route('/sync', methods=['POST'])
@jwt_required()
def sync_achievements():
    """Sync achievement progress from client to server."""
    try:
        user_id = get_jwt_identity()
        data = request.get_json(silent=True) or {}

        result = achievement_service.sync_achievement_progress(user_id, data)
        return jsonify(result), 200 if result['status'] == 'success' else 400

    except Exception as e:
        logger.error(f"Error syncing achievements: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to sync achievements'}), 500

@achievement_bp.route('/data', methods=['GET'])
@jwt_required()
def get_achievement_data():
    """Get all achievement data for the current user."""
    try:
        user_id = get_jwt_identity()
        data = achievement_service.get_achievement_data(user_id)
        return jsonify(data), 200

    except Exception as e:
        logger.error(f"Error getting achievement data: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to get achievement data'}), 500

@achievement_bp.route('/record/story', methods=['POST'])
@jwt_required()
def record_story():
    """Record that a story was created."""
    try:
        user_id = get_jwt_identity()
        data = request.get_json(silent=True) or {}
        theme = data.get('theme', 'Adventure')

        result = achievement_service.record_story_created(user_id, theme)
        return jsonify(result), 200 if result['status'] == 'success' else 400

    except Exception as e:
        logger.error(f"Error recording story: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to record story'}), 500

@achievement_bp.route('/record/character', methods=['POST'])
@jwt_required()
def record_character():
    """Record that a character was created."""
    try:
        user_id = get_jwt_identity()

        result = achievement_service.record_character_created(user_id)
        return jsonify(result), 200 if result['status'] == 'success' else 400

    except Exception as e:
        logger.error(f"Error recording character: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to record character'}), 500

@achievement_bp.route('/stats', methods=['GET'])
@jwt_required()
def get_achievement_stats():
    """Get achievement statistics for the current user."""
    try:
        user_id = get_jwt_identity()
        stats = achievement_service.get_or_create_stats(user_id)
        return jsonify(stats.to_dict()), 200

    except Exception as e:
        logger.error(f"Error getting achievement stats: {e}")
        return jsonify({'status': 'error', 'message': 'Failed to get achievement stats'}), 500