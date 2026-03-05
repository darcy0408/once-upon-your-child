from flask import Blueprint, request, jsonify
from backend.middleware.auth import require_auth
from backend.database import db

progression_bp = Blueprint('progression', __name__)

@progression_bp.route('/sync-progression', methods=['POST'])
@require_auth
def sync_progression():
    """Sync user progression data"""
    data = request.get_json()

    user = request.current_user
    user.progression_data = data
    db.session.commit()

    return jsonify({'message': 'Synced'}), 200

@progression_bp.route('/get-progression', methods=['GET'])
@require_auth
def get_progression():
    """Get user progression data"""
    user = request.current_user
    return jsonify(user.progression_data or {}), 200
