from flask import Blueprint, jsonify, request
from datetime import datetime, timezone

from ..database import db
from ..middleware.auth import require_auth, require_therapist
from ..models.therapist_client import TherapistClient
from ..models.story import Story


def create_therapist_blueprint(logger, limiter=None):
    therapist_bp = Blueprint('therapist', __name__)

    def rate_limit(limit_string):
        def decorator(f):
            if limiter:
                return limiter.limit(limit_string)(f)
            return f
        return decorator

    @therapist_bp.route('/therapist/clients', methods=['POST'])
    @require_auth
    @require_therapist
    @rate_limit('30 per minute')
    def add_client():
        data = request.get_json() or {}
        child_user_id = data.get('child_user_id', '').strip()
        if not child_user_id:
            return jsonify({'error': 'child_user_id is required'}), 400

        existing = TherapistClient.query.filter_by(
            therapist_id=request.current_user.id,
            child_user_id=child_user_id,
        ).first()
        if existing:
            return jsonify({'error': 'Client already linked'}), 409

        client = TherapistClient(
            therapist_id=request.current_user.id,
            child_user_id=child_user_id,
            child_display_name=data.get('child_display_name', '').strip() or None,
        )
        db.session.add(client)
        db.session.commit()
        logger.info(f"Therapist {request.current_user.id} linked client {child_user_id}")
        return jsonify(client.to_dict()), 201

    @therapist_bp.route('/therapist/clients', methods=['GET'])
    @require_auth
    @require_therapist
    @rate_limit('60 per minute')
    def list_clients():
        clients = TherapistClient.query.filter_by(
            therapist_id=request.current_user.id
        ).order_by(TherapistClient.created_at.desc()).all()
        return jsonify([c.to_dict() for c in clients]), 200

    @therapist_bp.route('/therapist/clients/<int:client_id>', methods=['DELETE'])
    @require_auth
    @require_therapist
    @rate_limit('30 per minute')
    def remove_client(client_id):
        client = TherapistClient.query.filter_by(
            id=client_id,
            therapist_id=request.current_user.id,
        ).first()
        if not client:
            return jsonify({'error': 'Client not found'}), 404
        db.session.delete(client)
        db.session.commit()
        return jsonify({'message': 'Client unlinked'}), 200

    @therapist_bp.route('/therapist/clients/<int:client_id>/goals', methods=['PUT'])
    @require_auth
    @require_therapist
    @rate_limit('30 per minute')
    def update_goals(client_id):
        client = TherapistClient.query.filter_by(
            id=client_id,
            therapist_id=request.current_user.id,
        ).first()
        if not client:
            return jsonify({'error': 'Client not found'}), 404

        data = request.get_json() or {}
        if 'goals' in data:
            client.therapeutic_goals = data['goals']
        if 'notes' in data:
            client.notes = data['notes']
        if 'child_display_name' in data:
            client.child_display_name = data['child_display_name'] or None
        client.updated_at = datetime.now(timezone.utc)
        db.session.commit()
        return jsonify(client.to_dict()), 200

    @therapist_bp.route('/therapist/clients/<int:client_id>/progress', methods=['GET'])
    @require_auth
    @require_therapist
    @rate_limit('30 per minute')
    def get_progress(client_id):
        client = TherapistClient.query.filter_by(
            id=client_id,
            therapist_id=request.current_user.id,
        ).first()
        if not client:
            return jsonify({'error': 'Client not found'}), 404

        stories = Story.query.filter_by(
            user_id=client.child_user_id
        ).order_by(Story.created_at.desc()).all()

        story_count = len(stories)
        recent_stories = []
        story_types = {}
        for s in stories[:20]:
            story_type = getattr(s, 'story_type', None) or 'regular'
            recent_stories.append({
                'id': s.id,
                'title': s.title,
                'theme': s.theme,
                'created_at': s.created_at.isoformat() if s.created_at else None,
                'word_count': getattr(s, 'word_count', None),
                'story_type': story_type,
            })

        for s in stories:
            story_type = getattr(s, 'story_type', None) or 'regular'
            story_types[story_type] = story_types.get(story_type, 0) + 1

        return jsonify({
            'client': client.to_dict(),
            'story_count': story_count,
            'recent_stories': recent_stories,
            'story_types': story_types,
        }), 200

    @therapist_bp.route('/therapist/clients/<int:client_id>/report', methods=['GET'])
    @require_auth
    @require_therapist
    @rate_limit('20 per minute')
    def export_report(client_id):
        client = TherapistClient.query.filter_by(
            id=client_id,
            therapist_id=request.current_user.id,
        ).first()
        if not client:
            return jsonify({'error': 'Client not found'}), 404

        stories = Story.query.filter_by(
            user_id=client.child_user_id
        ).order_by(Story.created_at.desc()).all()

        story_count = len(stories)
        recent_stories = []
        story_types = {}
        for s in stories[:20]:
            story_type = getattr(s, 'story_type', None) or 'regular'
            recent_stories.append({
                'id': s.id,
                'title': s.title,
                'theme': s.theme,
                'created_at': s.created_at.isoformat() if s.created_at else None,
                'word_count': getattr(s, 'word_count', None),
                'story_type': story_type,
            })

        for s in stories:
            story_type = getattr(s, 'story_type', None) or 'regular'
            story_types[story_type] = story_types.get(story_type, 0) + 1

        return jsonify({
            'client': client.to_dict(),
            'story_count': story_count,
            'recent_stories': recent_stories,
            'story_types': story_types,
            'goals': client.therapeutic_goals or [],
            'notes': client.notes or '',
            'generated_at': datetime.now(timezone.utc).isoformat(),
        }), 200

    return therapist_bp
