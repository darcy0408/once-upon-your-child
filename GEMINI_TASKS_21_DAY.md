# Gemini Tasks - 21-Day Launch Plan
**Assigned To:** Gemini (Google Gemini 2.5 Flash)
**Your Strengths:** Backend architecture, complex refactors, server-side logic
**Claude's Focus:** Frontend integrations, critical infrastructure, deployment

---

## 🎯 Your Mission

You'll handle **8 major tasks** across the 21 days, focusing on:
- Backend architecture and modularization
- Server-side features
- Complex refactoring work
- Documentation

**Work in parallel with Codex/Claude** - backend and frontend are independent!

---

## 📋 Your Complete Task List

### **TASK 1: Backend Testing Framework** ✅
**Days:** 3-4 (alongside Codex's frontend tests)
**Branch:** `gemini/backend-tests`
**Priority:** CRITICAL

**What to do:**
1. **Set up Pytest framework:**
   ```bash
   cd backend
   pip install pytest pytest-flask pytest-cov
   mkdir tests
   ```

2. **Create test structure:**
   ```
   backend/
     tests/
       __init__.py
       conftest.py
       test_api.py
       test_services.py
       test_models.py
   ```

3. **Write API endpoint tests:**
   ```python
   # tests/test_api.py
   import pytest
   from app import app, db

   @pytest.fixture
   def client():
       app.config['TESTING'] = True
       app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'

       with app.test_client() as client:
           with app.app_context():
               db.create_all()
           yield client

   def test_health_endpoint(client):
       """Test /health returns 200 with correct data"""
       response = client.get('/health')
       assert response.status_code == 200
       data = response.get_json()
       assert data['status'] == 'ok'
       assert 'has_api_key' in data

   def test_generate_story_requires_character(client):
       """Test /generate-story validates required fields"""
       response = client.post('/generate-story', json={})
       # Should handle missing character gracefully
       assert response.status_code in [200, 400]

   def test_generate_story_with_feelings(client):
       """Test /generate-story accepts feelings wheel data"""
       response = client.post('/generate-story', json={
           'character': 'Test Child',
           'theme': 'Adventure',
           'character_age': 7,
           'current_feeling': {
               'core_emotion': 'Joy',
               'secondary_emotion': 'Excited',
               'tertiary_emotion': 'Enthusiastic',
               'intensity': 4
           }
       })
       assert response.status_code in [200, 202]  # 202 if async

   def test_create_character(client):
       """Test /create-character endpoint"""
       response = client.post('/create-character', json={
           'name': 'Test',
           'age': 7,
           'gender': 'Girl'
       })
       assert response.status_code == 201
       data = response.get_json()
       assert data['name'] == 'Test'
       assert 'id' in data
   ```

4. **Write service tests:**
   ```python
   # tests/test_services.py
   from app import _extract_current_feeling, _build_feelings_prompt

   def test_extract_feeling_handles_feelings_wheel():
       """Test feelings wheel data is parsed correctly"""
       payload = {
           'current_feeling': {
               'core_emotion': 'Sad',
               'secondary_emotion': 'Lonely',
               'tertiary_emotion': 'Isolated',
               'intensity': 3
           }
       }
       result = _extract_current_feeling(payload)
       assert result is not None
       assert result['emotion_name'] == 'Isolated'
       assert result['intensity'] == 3

   def test_extract_feeling_handles_legacy_format():
       """Test old emotion format still works"""
       payload = {
           'current_feeling': {
               'emotion_name': 'Happy',
               'emotion_emoji': '😊',
               'intensity': 4
           }
       }
       result = _extract_current_feeling(payload)
       assert result is not None
       assert result['emotion_name'] == 'Happy'

   def test_build_feelings_prompt():
       """Test feelings prompt generation"""
       feeling = {
           'emotion_name': 'Worried',
           'emotion_emoji': '😰',
           'intensity': 4,
           'what_happened': 'Test tomorrow'
       }
       prompt = _build_feelings_prompt('Emma', feeling)
       assert 'Emma' in prompt
       assert 'Worried' in prompt or 'worried' in prompt
       assert 'Test tomorrow' in prompt
   ```

5. **Write model tests:**
   ```python
   # tests/test_models.py
   from app import Character, db
   import uuid

   def test_character_creation(client):
       """Test Character model creation"""
       with client.application.app_context():
           char = Character(
               id=str(uuid.uuid4()),
               name='Test',
               age=7,
               gender='Girl'
           )
           db.session.add(char)
           db.session.commit()

           # Retrieve
           found = Character.query.filter_by(name='Test').first()
           assert found is not None
           assert found.age == 7

   def test_character_to_dict(client):
       """Test Character.to_dict() method"""
       with client.application.app_context():
           char = Character(
               id=str(uuid.uuid4()),
               name='Test',
               age=7,
               gender='Girl',
               personality_sliders={'sociability': 75}
           )
           data = char.to_dict()
           assert data['name'] == 'Test'
           assert data['personality_sliders']['sociability'] == 75
   ```

6. **Run tests with coverage:**
   ```bash
   cd backend
   pytest --cov=. --cov-report=html
   # Should aim for >70% coverage
   ```

7. **Add to CI/CD:**
   ```yaml
   # .github/workflows/backend-tests.yml
   name: Backend Tests
   on: [push, pull_request]
   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - uses: actions/setup-python@v4
           with:
             python-version: '3.11'
         - name: Install dependencies
           run: |
             cd backend
             pip install -r requirements.txt
             pip install pytest pytest-cov
         - name: Run tests
           run: |
             cd backend
             pytest --cov=. --cov-report=term
   ```

**Deliverable:** Comprehensive backend test suite with >70% coverage

---

### **TASK 2: Backend Modularization - Part 1** 🏗️
**Day:** 12
**Branch:** `gemini/backend-modular`
**Priority:** HIGH

**What to do:**
1. **Create folder structure:**
   ```bash
   cd backend
   mkdir models routes services
   touch models/__init__.py
   touch routes/__init__.py
   touch services/__init__.py
   touch extensions.py
   ```

2. **Extract database setup:**
   ```python
   # backend/extensions.py
   from flask_sqlalchemy import SQLAlchemy

   db = SQLAlchemy()

   def init_app(app):
       db.init_app(app)
   ```

3. **Extract Character model:**
   ```python
   # backend/models/character.py
   from extensions import db
   from sqlalchemy.dialects.sqlite import JSON as SQLITE_JSON
   import uuid
   from datetime import datetime

   class Character(db.Model):
       """Stores character information, traits, relationships, and metadata."""
       id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
       name = db.Column(db.String(100), nullable=False)
       age = db.Column(db.Integer, nullable=False)
       gender = db.Column(db.String(50))
       role = db.Column(db.String(200))
       magic_type = db.Column(db.String(100))
       challenge = db.Column(db.String(500))
       character_type = db.Column(db.String(50))
       character_style = db.Column(db.String(50))

       # ... rest of model definition

       def to_dict(self):
           """Convert to dictionary for JSON serialization"""
           return {
               'id': self.id,
               'name': self.name,
               'age': self.age,
               # ... rest of fields
           }
   ```

   ```python
   # backend/models/__init__.py
   from .character import Character

   __all__ = ['Character']
   ```

4. **Extract character routes:**
   ```python
   # backend/routes/character_routes.py
   from flask import Blueprint, request, jsonify
   from models import Character
   from extensions import db
   import uuid

   character_bp = Blueprint('character', __name__)

   @character_bp.route('/create-character', methods=['POST'])
   def create_character():
       """Create a new character"""
       data = request.get_json(silent=True) or {}

       # Validation
       missing = [k for k in ("name", "age") if not data.get(k)]
       if missing:
           return jsonify({"error": f"Missing: {', '.join(missing)}"}), 400

       # Create character
       new_character = Character(
           id=str(uuid.uuid4()),
           name=data.get('name'),
           age=int(data.get('age')),
           # ... rest of fields
       )

       db.session.add(new_character)
       db.session.commit()

       return jsonify(new_character.to_dict()), 201

   @character_bp.route('/get-characters', methods=['GET'])
   def get_characters():
       """Get all characters"""
       characters = Character.query.order_by(Character.created_at.desc()).all()
       return jsonify([c.to_dict() for c in characters]), 200

   @character_bp.route('/characters/<character_id>', methods=['GET'])
   def get_character(character_id):
       """Get single character"""
       character = Character.query.get(character_id)
       if not character:
           return jsonify({"error": "Character not found"}), 404
       return jsonify(character.to_dict()), 200

   @character_bp.route('/characters/<character_id>', methods=['PATCH'])
   def update_character(character_id):
       """Update character"""
       character = Character.query.get(character_id)
       if not character:
           return jsonify({"error": "Character not found"}), 404

       data = request.get_json(silent=True) or {}
       # Update fields
       for key, value in data.items():
           if hasattr(character, key):
               setattr(character, key, value)

       db.session.commit()
       return jsonify(character.to_dict()), 200

   @character_bp.route('/characters/<character_id>', methods=['DELETE'])
   def delete_character(character_id):
       """Delete character"""
       character = Character.query.get(character_id)
       if not character:
           return jsonify({"error": "Character not found"}), 404

       db.session.delete(character)
       db.session.commit()
       return jsonify({"message": "Deleted"}), 200
   ```

5. **Update app.py to use modules:**
   ```python
   # backend/app.py (at the top)
   from flask import Flask
   from flask_cors import CORS
   from extensions import db, init_app
   from routes.character_routes import character_bp
   from routes.story_routes import story_bp  # Will create in Task 3

   app = Flask(__name__)

   # Config
   app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL')
   # ... other config

   # Initialize extensions
   init_app(app)

   # Register blueprints
   app.register_blueprint(character_bp)
   app.register_blueprint(story_bp)

   # Health check remains in app.py
   @app.route('/health', methods=['GET'])
   def health():
       # ... health check logic
   ```

**Deliverable:** Character model and routes extracted to modules

---

### **TASK 3: Backend Modularization - Part 2** 🏗️
**Day:** 13
**Branch:** `gemini/backend-modular` (continue from Task 2)
**Priority:** HIGH

**What to do:**
1. **Extract story generation service:**
   ```python
   # backend/services/story_generation_service.py
   import google.generativeai as genai
   import os
   import logging

   logger = logging.getLogger(__name__)

   class StoryGenerationService:
       def __init__(self):
           api_key = os.getenv('GEMINI_API_KEY')
           if not api_key:
               raise ValueError("GEMINI_API_KEY not set")

           genai.configure(api_key=api_key)
           self.model = genai.GenerativeModel('gemini-1.5-flash')

       def generate_story(self, prompt: str) -> str:
           """Generate story from prompt"""
           try:
               response = self.model.generate_content(prompt)
               return getattr(response, 'text', '')
           except Exception as e:
               logger.error(f"Story generation failed: {e}", exc_info=True)
               raise
   ```

2. **Extract prompt building service:**
   ```python
   # backend/services/prompt_service.py
   from services.emotion_service import EmotionService

   class PromptService:
       @staticmethod
       def build_story_prompt(
           character: str,
           theme: str,
           age: int,
           companion: str = None,
           current_feeling: dict = None,
           rhyme_time_mode: bool = False,
           learning_to_read_mode: bool = False,
           character_details: dict = None
       ) -> str:
           """Build complete story generation prompt"""

           sections = []

           # Base story setup
           sections.append(f"Create a story for {character} (age {age})")
           sections.append(f"Theme: {theme}")

           if companion:
               sections.append(f"Companion: {companion}")

           # Feelings integration
           if current_feeling:
               feelings_section = EmotionService.build_feelings_prompt(
                   character, current_feeling
               )
               sections.append(feelings_section)

           # Age-appropriate content
           age_guidelines = PromptService._get_age_guidelines(age)
           sections.append(age_guidelines)

           # Mode-specific instructions
           if learning_to_read_mode:
               sections.append(PromptService._get_learning_to_read_instructions())
           elif rhyme_time_mode:
               sections.append(PromptService._get_rhyme_time_instructions())

           # Character details
           if character_details:
               details_section = PromptService._build_character_details(
                   character_details
               )
               sections.append(details_section)

           return "\n\n".join(sections)

       @staticmethod
       def _get_age_guidelines(age: int) -> str:
           """Return age-appropriate content guidelines"""
           if age <= 5:
               return """
               AGE-APPROPRIATE GUIDELINES (Ages 3-5):
               - Length: 100-150 words maximum
               - Vocabulary: Very simple (cat, dog, run, happy)
               - Sentences: 3-6 words each
               - Concepts: Concrete, tangible only
               - Use repetition for learning
               """
           elif age <= 8:
               return """
               AGE-APPROPRIATE GUIDELINES (Ages 6-8):
               - Length: 150-250 words
               - Vocabulary: Sight words + basic phonics
               - Sentences: Short and clear
               - Concepts: Simple cause and effect
               """
           # ... more age brackets

       @staticmethod
       def _get_learning_to_read_instructions() -> str:
           """Instructions for learning to read mode"""
           return """
           LEARNING TO READ MODE:
           - 50-100 words total
           - AABB rhyme scheme
           - CVC words only (cat, bat, sit, run)
           - Repetitive patterns
           - Clear rhythm
           """

       # ... more methods
   ```

3. **Extract emotion service:**
   ```python
   # backend/services/emotion_service.py

   class EmotionService:
       @staticmethod
       def extract_current_feeling(payload: dict) -> dict:
           """Extract and normalize feeling data from request"""
           if not isinstance(payload, dict):
               return None

           feeling = payload.get('current_feeling') or payload.get('currentFeeling')
           if not feeling or not isinstance(feeling, dict):
               return None

           # Handle feelings wheel structure
           emotion_name = (
               EmotionService._clean(feeling.get('emotion_name'))
               or EmotionService._clean(feeling.get('tertiary_emotion'))
               or EmotionService._clean(feeling.get('secondary_emotion'))
               or EmotionService._clean(feeling.get('core_emotion'))
           )

           normalized = {
               'emotion_id': EmotionService._clean(
                   feeling.get('tertiary_emotion') or feeling.get('emotion_id')
               ),
               'emotion_name': emotion_name,
               'emotion_emoji': EmotionService._clean(feeling.get('emotion_emoji')),
               'intensity': EmotionService._normalize_intensity(feeling.get('intensity')),
               'what_happened': EmotionService._clean(feeling.get('what_happened')),
           }

           # Only return if has meaningful data
           if not any(normalized.values()):
               return None

           return normalized

       @staticmethod
       def _clean(value):
           """Clean string value"""
           if value is None:
               return None
           return str(value).strip() or None

       @staticmethod
       def _normalize_intensity(value):
           """Normalize intensity to 1-5 range"""
           try:
               intensity = int(value)
               return max(1, min(5, intensity))
           except (TypeError, ValueError):
               return None

       @staticmethod
       def build_feelings_prompt(character_name: str, feeling: dict) -> str:
           """Build feelings-focused prompt section"""
           if not feeling:
               return ""

           emotion_name = feeling.get('emotion_name', 'a big feeling')
           intensity = feeling.get('intensity')
           what_happened = feeling.get('what_happened')

           lines = [
               f"CURRENT EMOTIONAL STATE:",
               f"- {character_name} is feeling {emotion_name}",
           ]

           if intensity:
               lines.append(f"- Intensity: {intensity}/5")

           if what_happened:
               lines.append(f"- Context: {what_happened}")

           lines.append(
               f"\nSTORY REQUIREMENTS:",
               f"1. Acknowledge {character_name} feels {emotion_name}",
               f"2. Validate the feeling (all feelings are okay)",
               f"3. Show character processing the emotion",
               f"4. Include coping strategies naturally",
               f"5. End with hopeful reflection"
           )

           return "\n".join(lines)
   ```

4. **Create story routes:**
   ```python
   # backend/routes/story_routes.py
   from flask import Blueprint, request, jsonify
   from services.story_generation_service import StoryGenerationService
   from services.prompt_service import PromptService
   from services.emotion_service import EmotionService
   import logging

   story_bp = Blueprint('story', __name__)
   logger = logging.getLogger(__name__)
   story_service = StoryGenerationService()

   @story_bp.route('/generate-story', methods=['POST'])
   def generate_story():
       """Generate a personalized story"""
       payload = request.get_json(silent=True) or {}

       # Extract parameters
       character = payload.get('character', 'a brave adventurer')
       theme = payload.get('theme', 'Adventure')
       age = payload.get('character_age', 7)
       companion = payload.get('companion')
       rhyme_time_mode = payload.get('rhyme_time_mode', False)
       learning_to_read_mode = payload.get('learning_to_read_mode', False)

       # Extract feelings
       current_feeling = EmotionService.extract_current_feeling(payload)

       # Extract character details
       character_details = payload.get('character_details', {})

       # Build prompt
       prompt = PromptService.build_story_prompt(
           character=character,
           theme=theme,
           age=age,
           companion=companion,
           current_feeling=current_feeling,
           rhyme_time_mode=rhyme_time_mode,
           learning_to_read_mode=learning_to_read_mode,
           character_details=character_details
       )

       # Generate story
       try:
           story_text = story_service.generate_story(prompt)

           # Extract title and wisdom gem
           title, wisdom_gem, cleaned_story = _extract_story_parts(
               story_text, theme
           )

           return jsonify({
               'title': title,
               'story': cleaned_story,
               'wisdom_gem': wisdom_gem,
           }), 200

       except Exception as e:
           logger.error(f"Story generation failed: {e}", exc_info=True)

           # Return fallback story
           return jsonify({
               'title': 'An Unexpected Adventure',
               'story': 'Once upon a time, a brave hero discovered that...',
               'wisdom_gem': 'Courage comes from facing our fears.',
           }), 200
   ```

5. **Update app.py:**
   ```python
   # backend/app.py
   from flask import Flask
   from flask_cors import CORS
   from extensions import db, init_app
   from routes.character_routes import character_bp
   from routes.story_routes import story_bp

   app = Flask(__name__)

   # ... config ...

   init_app(app)

   app.register_blueprint(character_bp)
   app.register_blueprint(story_bp)

   @app.route('/health', methods=['GET'])
   def health():
       # ... health check ...

   if __name__ == '__main__':
       app.run()
   ```

6. **Test everything still works:**
   ```bash
   cd backend
   pytest
   # All tests should pass

   # Manual API test
   curl -X POST http://localhost:5000/generate-story \
     -H "Content-Type: application/json" \
     -d '{"character":"Test","theme":"Adventure","character_age":7}'
   ```

**Deliverable:** Clean, modular backend architecture

---

### **TASK 4: Server-Side User Accounts** 👤
**Day:** 14 (morning)
**Branch:** `gemini/user-accounts`
**Priority:** HIGH

**What to do:**
1. **Create User model:**
   ```python
   # backend/models/user.py
   from extensions import db
   from werkzeug.security import generate_password_hash, check_password_hash
   import uuid
   from datetime import datetime

   class User(db.Model):
       id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
       email = db.Column(db.String(120), unique=True, nullable=False)
       password_hash = db.Column(db.String(200), nullable=False)
       created_at = db.Column(db.DateTime, default=datetime.utcnow)

       # Relationships
       characters = db.relationship('Character', backref='user', lazy=True)
       progression_data = db.Column(db.JSON, default=dict)

       def set_password(self, password):
           self.password_hash = generate_password_hash(password)

       def check_password(self, password):
           return check_password_hash(self.password_hash, password)

       def to_dict(self):
           return {
               'id': self.id,
               'email': self.email,
               'created_at': self.created_at.isoformat(),
           }
   ```

2. **Add user_id to Character model:**
   ```python
   # backend/models/character.py
   class Character(db.Model):
       # ... existing fields ...
       user_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=True)
       # ... rest of model ...
   ```

3. **Create auth routes:**
   ```python
   # backend/routes/auth_routes.py
   from flask import Blueprint, request, jsonify
   from models.user import User
   from extensions import db
   import jwt
   import os
   from datetime import datetime, timedelta

   auth_bp = Blueprint('auth', __name__)

   SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'your-secret-key')

   @auth_bp.route('/register', methods=['POST'])
   def register():
       """Register new user"""
       data = request.get_json()
       email = data.get('email')
       password = data.get('password')

       if not email or not password:
           return jsonify({'error': 'Email and password required'}), 400

       if User.query.filter_by(email=email).first():
           return jsonify({'error': 'Email already registered'}), 400

       user = User(email=email)
       user.set_password(password)
       db.session.add(user)
       db.session.commit()

       # Generate JWT
       token = jwt.encode({
           'user_id': user.id,
           'exp': datetime.utcnow() + timedelta(days=30)
       }, SECRET_KEY, algorithm='HS256')

       return jsonify({
           'token': token,
           'user': user.to_dict()
       }), 201

   @auth_bp.route('/login', methods=['POST'])
   def login():
       """Login user"""
       data = request.get_json()
       email = data.get('email')
       password = data.get('password')

       user = User.query.filter_by(email=email).first()
       if not user or not user.check_password(password):
           return jsonify({'error': 'Invalid credentials'}), 401

       # Generate JWT
       token = jwt.encode({
           'user_id': user.id,
           'exp': datetime.utcnow() + timedelta(days=30)
       }, SECRET_KEY, algorithm='HS256')

       return jsonify({
           'token': token,
           'user': user.to_dict()
       }), 200
   ```

4. **Create auth middleware:**
   ```python
   # backend/middleware/auth.py
   from functools import wraps
   from flask import request, jsonify
   from models.user import User
   import jwt
   import os

   def require_auth(f):
       @wraps(f)
       def decorated(*args, **kwargs):
           token = request.headers.get('Authorization')
           if not token:
               return jsonify({'error': 'No auth token'}), 401

           try:
               if token.startswith('Bearer '):
                   token = token[7:]

               data = jwt.decode(
                   token,
                   os.getenv('JWT_SECRET_KEY'),
                   algorithms=['HS256']
               )
               current_user = User.query.get(data['user_id'])
               if not current_user:
                   return jsonify({'error': 'User not found'}), 401

               request.current_user = current_user

           except jwt.ExpiredSignatureError:
               return jsonify({'error': 'Token expired'}), 401
           except jwt.InvalidTokenError:
               return jsonify({'error': 'Invalid token'}), 401

           return f(*args, **kwargs)

       return decorated
   ```

5. **Add progression sync endpoint:**
   ```python
   # backend/routes/progression_routes.py
   from flask import Blueprint, request, jsonify
   from middleware.auth import require_auth
   from extensions import db

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
   ```

6. **Register new blueprints:**
   ```python
   # backend/app.py
   from routes.auth_routes import auth_bp
   from routes.progression_routes import progression_bp

   app.register_blueprint(auth_bp)
   app.register_blueprint(progression_bp)
   ```

**Deliverable:** User accounts with JWT auth and progression sync

---

### **TASK 5: Developer Documentation** 📚
**Day:** 11
**Branch:** `gemini/architecture-docs`
**Priority:** HIGH

**What to do:**
1. **Create ARCHITECTURE.md:**
   ```markdown
   # Story Weaver Architecture

   ## System Overview

   Story Weaver is a full-stack application for creating personalized,
   therapeutic stories for children.

   ### Technology Stack
   - **Frontend:** Flutter (Web, iOS, Android)
   - **Backend:** Python Flask
   - **Database:** PostgreSQL
   - **AI:** Google Gemini API (gemini-1.5-flash)
   - **Task Queue:** Celery + Redis
   - **Hosting:** Netlify (frontend), Railway (backend)

   ## Architecture Diagram

   ```
   ┌─────────────┐
   │   Flutter   │
   │   Frontend  │
   └──────┬──────┘
          │ HTTP/REST
          ▼
   ┌─────────────┐     ┌──────────┐
   │    Flask    │────▶│   Redis  │
   │   Backend   │     │  (Queue) │
   └──────┬──────┘     └────┬─────┘
          │                 │
          │                 ▼
          │           ┌──────────┐
          │           │  Celery  │
          │           │  Worker  │
          │           └────┬─────┘
          │                │
          │                ▼
          │           ┌──────────┐
          │           │  Gemini  │
          │           │   API    │
          │           └──────────┘
          ▼
   ┌─────────────┐
   │ PostgreSQL  │
   └─────────────┘
   ```

   ## Database Schema

   ### Character Model
   ```python
   class Character:
       id: String (UUID)
       user_id: String (FK to User)
       name: String
       age: Integer
       gender: String
       role: String

       # Appearance
       hair: String
       eyes: String
       outfit: String

       # Personality
       personality_sliders: JSON

       # Interests & Growth
       likes: JSON (List)
       dislikes: JSON (List)
       fears: JSON (List)
       goals: JSON (List)

       created_at: DateTime
   ```

   ### User Model
   ```python
   class User:
       id: String (UUID)
       email: String (unique)
       password_hash: String
       progression_data: JSON
       created_at: DateTime

       # Relationships
       characters: List[Character]
   ```

   ## API Endpoints

   ### Story Generation
   ```
   POST /generate-story
   Body: {
       "character": String,
       "theme": String,
       "character_age": Integer,
       "current_feeling": Object (optional),
       "rhyme_time_mode": Boolean,
       "learning_to_read_mode": Boolean
   }
   Response: 202 Accepted
   {
       "task_id": String
   }

   GET /task-status/<task_id>
   Response: {
       "status": "pending" | "complete",
       "result": {
           "title": String,
           "story": String,
           "wisdom_gem": String
       }
   }
   ```

   ### Character Management
   ```
   POST /create-character
   GET /get-characters
   GET /characters/<id>
   PATCH /characters/<id>
   DELETE /characters/<id>
   ```

   ### Authentication
   ```
   POST /register
   POST /login
   GET /get-progression (requires auth)
   POST /sync-progression (requires auth)
   ```

   ## Service Layer

   ### StoryGenerationService
   - Handles Gemini API calls
   - Manages retries and errors
   - Returns generated story text

   ### PromptService
   - Builds story generation prompts
   - Applies age-appropriate guidelines
   - Integrates feelings wheel data
   - Adds mode-specific instructions

   ### EmotionService
   - Extracts feelings from requests
   - Normalizes emotion data
   - Builds feelings-focused prompts

   ## Frontend Architecture

   ### State Management (Riverpod)
   ```dart
   // Providers
   - charactersProvider: StateNotifier<List<Character>>
   - storyGenerationProvider: FutureProvider<String>
   - subscriptionProvider: StateNotifier<UserSubscription>
   ```

   ### Key Screens
   - **Main Story Screen:** Character selection, theme picker, story creation
   - **Character Creation:** Form for building new characters
   - **Feelings Wheel:** 72-emotion hierarchical selector
   - **Story Result:** Display generated story
   - **Insights Dashboard:** Emotion tracking over time

   ## Deployment

   ### Frontend (Netlify)
   ```bash
   flutter build web --release --dart-define=FLAVOR=production
   netlify deploy --prod --dir=build/web
   ```

   ### Backend (Railway)
   - Auto-deploys from `main` branch
   - Environment variables configured in Railway dashboard
   - Database auto-provisioned

   ## Environment Variables

   ### Backend (Railway)
   ```
   GEMINI_API_KEY=<your-key>
   DATABASE_URL=<postgresql-url>
   REDIS_URL=<redis-url>
   JWT_SECRET_KEY=<secret>
   FLASK_ENV=production
   ```

   ### Frontend (Build-time)
   ```
   FLAVOR=production
   ```

   ## Testing

   ### Backend Tests
   ```bash
   cd backend
   pytest --cov=. --cov-report=html
   ```

   ### Frontend Tests
   ```bash
   flutter test
   flutter test --coverage
   ```

   ## Monitoring

   - **Error Tracking:** Sentry
   - **Analytics:** Firebase Analytics
   - **Logs:** Railway dashboard
   - **Uptime:** Railway monitoring

   ## Security

   - API keys stored in secure environment variables
   - User passwords hashed with Werkzeug
   - JWTs for authentication
   - CORS configured for production domains
   - Flutter secure storage for client-side secrets

   ## Performance

   - Async story generation (non-blocking)
   - Redis caching for frequent requests
   - Image optimization
   - Lazy loading in Flutter
   - Database indexes on frequently queried fields

   ## Future Improvements

   - Rate limiting per user
   - Webhooks for real-time updates
   - WebSocket for live story streaming
   - CDN for static assets
   - Horizontal scaling with load balancer
   ```

2. **Update README.md technical section:**
   ```markdown
   # For Developers

   See [ARCHITECTURE.md](./ARCHITECTURE.md) for complete system documentation.

   ## Quick Start

   ### Backend
   ```bash
   cd backend
   pip install -r requirements.txt
   export GEMINI_API_KEY="your-key"
   python app.py
   ```

   ### Frontend
   ```bash
   flutter pub get
   flutter run
   ```

   ### Tests
   ```bash
   # Backend
   cd backend && pytest

   # Frontend
   flutter test
   ```

   ## Contributing

   See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.
   ```

**Deliverable:** Comprehensive technical documentation

---

### **TASK 6: Interactive Story Polish** 🎮
**Day:** 11 (afternoon)
**Branch:** `gemini/interactive-polish`
**Priority:** MEDIUM

**What to do:**
1. **Review interactive story endpoints:**
   ```python
   # backend/routes/story_routes.py
   @story_bp.route('/generate-interactive-story', methods=['POST'])
   def generate_interactive_story():
       # Verify this uses new modular services
       # Update to use PromptService, StoryGenerationService

   @story_bp.route('/continue-interactive-story', methods=['POST'])
   def continue_interactive_story():
       # Update to use modular architecture
   ```

2. **Ensure interactive stories use feelings wheel:**
   ```python
   # In generate_interactive_story
   current_feeling = EmotionService.extract_current_feeling(payload)

   # Include in prompt
   if current_feeling:
       feelings_section = EmotionService.build_feelings_prompt(
           character, current_feeling
       )
       prompt_parts.append(feelings_section)
   ```

3. **Add interactive story tests:**
   ```python
   # tests/test_api.py
   def test_interactive_story_generation(client):
       response = client.post('/generate-interactive-story', json={
           'character': 'Test',
           'theme': 'Adventure'
       })
       assert response.status_code == 200
       data = response.get_json()
       assert 'story_segment' in data
       assert 'choices' in data
   ```

**Deliverable:** Interactive stories work with new architecture

---

### **TASK 7: Database Migration Script** 💾
**Day:** 1 (afternoon, alongside Claude)
**Branch:** `gemini/postgres-migration`
**Priority:** CRITICAL

**What to do:**
1. **Create migration script:**
   ```python
   # backend/migrate_sqlite_to_postgres.py
   import sqlite3
   import psycopg2
   import os
   import json
   from datetime import datetime

   # SQLite connection
   sqlite_conn = sqlite3.connect('characters.db')
   sqlite_cursor = sqlite_conn.cursor()

   # PostgreSQL connection
   pg_conn = psycopg2.connect(os.getenv('DATABASE_URL'))
   pg_cursor = pg_conn.cursor()

   # Migrate characters
   print("Migrating characters...")
   sqlite_cursor.execute("SELECT * FROM character")
   characters = sqlite_cursor.fetchall()

   for char in characters:
       # Parse JSON fields
       personality_traits = json.loads(char[13] or '[]')
       personality_sliders = json.loads(char[14] or '{}')
       siblings = json.loads(char[15] or '[]')
       friends = json.loads(char[16] or '[]')
       likes = json.loads(char[17] or '[]')
       dislikes = json.loads(char[18] or '[]')
       fears = json.loads(char[19] or '[]')
       strengths = json.loads(char[20] or '[]')
       goals = json.loads(char[21] or '[]')

       # Insert into PostgreSQL
       pg_cursor.execute("""
           INSERT INTO character (
               id, name, age, gender, role, magic_type, challenge,
               character_type, superhero_name, mission, hair, eyes, outfit,
               personality_traits, personality_sliders, siblings, friends,
               likes, dislikes, fears, strengths, goals, comfort_item, created_at
           ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                     %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
       """, (
           char[0], char[1], char[2], char[3], char[4], char[5], char[6],
           char[7], char[8], char[9], char[10], char[11], char[12],
           json.dumps(personality_traits),
           json.dumps(personality_sliders),
           json.dumps(siblings),
           json.dumps(friends),
           json.dumps(likes),
           json.dumps(dislikes),
           json.dumps(fears),
           json.dumps(strengths),
           json.dumps(goals),
           char[22],
           datetime.fromisoformat(char[23]) if char[23] else datetime.utcnow()
       ))

   pg_conn.commit()
   print(f"Migrated {len(characters)} characters")

   # Close connections
   sqlite_cursor.close()
   sqlite_conn.close()
   pg_cursor.close()
   pg_conn.close()

   print("Migration complete!")
   ```

2. **Test migration:**
   ```bash
   # Run against test database first
   export DATABASE_URL="postgresql://test..."
   python migrate_sqlite_to_postgres.py

   # Verify data
   psql $DATABASE_URL
   SELECT COUNT(*) FROM character;
   SELECT * FROM character LIMIT 1;
   ```

**Deliverable:** Working migration from SQLite to PostgreSQL

---

### **TASK 8: Production Monitoring Setup** 📊
**Day:** 21 (morning)
**Branch:** Work on `main`
**Priority:** HIGH

**What to do:**
1. **Set up Sentry for backend:**
   ```python
   # backend/app.py
   import sentry_sdk
   from sentry_sdk.integrations.flask import FlaskIntegration

   sentry_sdk.init(
       dsn=os.getenv('SENTRY_DSN'),
       integrations=[FlaskIntegration()],
       traces_sample_rate=1.0,
       environment='production'
   )
   ```

2. **Add health check improvements:**
   ```python
   @app.route('/health', methods=['GET'])
   def health():
       health_status = {
           'status': 'ok',
           'timestamp': datetime.utcnow().isoformat(),
           'version': '1.0.0',
       }

       # Check database
       try:
           db.session.execute('SELECT 1')
           health_status['database'] = 'ok'
       except Exception as e:
           health_status['database'] = 'error'
           health_status['database_error'] = str(e)
           health_status['status'] = 'degraded'

       # Check Redis
       try:
           # Ping Redis
           health_status['redis'] = 'ok'
       except Exception as e:
           health_status['redis'] = 'error'
           health_status['status'] = 'degraded'

       # Check Gemini API
       health_status['has_api_key'] = bool(os.getenv('GEMINI_API_KEY'))

       return jsonify(health_status), 200 if health_status['status'] == 'ok' else 503
   ```

3. **Set up logging:**
   ```python
   # backend/app.py
   import logging
   from logging.handlers import RotatingFileHandler

   if not app.debug:
       # File handler
       file_handler = RotatingFileHandler(
           'logs/story_weaver.log',
           maxBytes=10240000,
           backupCount=10
       )
       file_handler.setFormatter(logging.Formatter(
           '%(asctime)s %(levelname)s: %(message)s '
           '[in %(pathname)s:%(lineno)d]'
       ))
       file_handler.setLevel(logging.INFO)
       app.logger.addHandler(file_handler)

       app.logger.setLevel(logging.INFO)
       app.logger.info('Story Weaver startup')
   ```

**Deliverable:** Production monitoring and logging configured

---

## 🗓️ Your Timeline at a Glance

| Days | Task | Priority |
|------|------|----------|
| 1 | Database migration script | CRITICAL |
| 3-4 | Backend testing framework | CRITICAL |
| 11 | Architecture docs + Interactive polish | HIGH |
| 12-13 | Backend modularization (2 days) | HIGH |
| 14 | User accounts + progression sync | HIGH |
| 21 | Production monitoring | HIGH |

**Total: 8 tasks across 7 work days**

---

## 💡 Tips for Success

### Your Strengths:
- Backend architecture
- Complex refactoring
- Service design
- Documentation

### Branch Strategy:
```bash
# Start each task
git checkout main
git pull origin main
git checkout -b gemini/[task-name]

# When done
git add .
git commit -m "[Backend] Brief description"
git push origin gemini/[task-name]

# Let Claude review and merge
```

### Testing:
- Run `pytest` after every change
- Use `pytest --cov` to check coverage
- Test API endpoints manually with curl

---

## 🎯 Success Criteria

By Day 21, you will have:
- ✅ Backend test suite (>70% coverage)
- ✅ Clean, modular backend architecture
- ✅ User accounts with auth
- ✅ Server-side progression sync
- ✅ Complete technical documentation
- ✅ Production monitoring
- ✅ Database migration working

**Focus on clean architecture - that's your specialty! 🚀**
