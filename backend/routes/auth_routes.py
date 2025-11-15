from flask import Blueprint, request, jsonify
from backend.models.user import User
from backend.database import db
import jwt
from functools import wraps
import os
from datetime import datetime, timedelta

auth_bp = Blueprint('auth', __name__)

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'x-access-token' in request.headers:
            token = request.headers['x-access-token']
        if not token:
            return jsonify({'message': 'Token is missing!'}), 401
        try:
            data = jwt.decode(token, os.environ.get('SECRET_KEY'), algorithms=["HS256"])
            current_user = User.query.filter_by(id=data['id']).first()
        except:
            return jsonify({'message': 'Token is invalid!'}), 401
        return f(current_user, *args, **kwargs)
    return decorated

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    hashed_password = User.generate_password_hash(data['password'])
    new_user = User(username=data['username'], email=data['email'], password_hash=hashed_password)
    db.session.add(new_user)
    db.session.commit()
    return jsonify({'message': 'New user created!'})

@auth_bp.route('/login', methods=['POST'])
def login():
    auth = request.authorization
    if not auth or not auth.username or not auth.password:
        return jsonify({'message': 'Could not verify'}), 401
    user = User.query.filter_by(username=auth.username).first()
    if not user:
        return jsonify({'message': 'Could not verify'}), 401
    if user.check_password(auth.password):
        token = jwt.encode({'id': user.id, 'exp': datetime.utcnow() + timedelta(minutes=30)}, os.environ.get('SECRET_KEY'))
        return jsonify({'token': token})
    return jsonify({'message': 'Could not verify'}), 401

@auth_bp.route('/setup-test-account', methods=['POST'])
def setup_test_account():
    """Create or update a test account for E2E tests."""
    username = "testuser"
    email = "testuser@test.com"
    password = "password"
    user = User.query.filter_by(username=username).first()
    if user:
        user.set_password(password)
        status = "updated"
    else:
        user = User(username=username, email=email)
        user.set_password(password)
        db.session.add(user)
        status = "created"
    db.session.commit()
    return jsonify({"status": status, "username": username}), 201 if status == "created" else 200
