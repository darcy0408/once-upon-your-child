
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.dialects.sqlite import JSON as SQLITE_JSON
from datetime import datetime

db = SQLAlchemy()

class Character(db.Model):
    """Stores character information, traits, relationships, and metadata."""
    id = db.Column(db.String(36), primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    gender = db.Column(db.String(50))
    role = db.Column(db.String(50))
    magic_type = db.Column(db.String(50))
    challenge = db.Column(db.Text)

    # Character type and superhero specific
    character_type = db.Column(db.String(50), default='Everyday Kid')
    superhero_name = db.Column(db.String(100))
    mission = db.Column(db.Text)

    # Appearance
    hair = db.Column(db.String(50))
    eyes = db.Column(db.String(50))
    outfit = db.Column(db.String(200))

    # SQLite JSON (persists as TEXT)
    personality_traits = db.Column(SQLITE_JSON, default=list)
    personality_sliders = db.Column(SQLITE_JSON, default=dict)
    siblings = db.Column(SQLITE_JSON, default=list)
    friends = db.Column(SQLITE_JSON, default=list)
    likes = db.Column(SQLITE_JSON, default=list)
    dislikes = db.Column(SQLITE_JSON, default=list)
    fears = db.Column(SQLITE_JSON, default=list)
    strengths = db.Column(SQLITE_JSON, default=list)
    goals = db.Column(SQLITE_JSON, default=list)

    comfort_item = db.Column(db.String(200))
    created_at = db.Column(db.DateTime, default=datetime.now, index=True)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "age": self.age,
            "gender": self.gender,
            "role": self.role,
            "magic_type": self.magic_type,
            "challenge": self.challenge,
            "character_type": self.character_type,
            "superhero_name": self.superhero_name,
            "mission": self.mission,
            "hair": self.hair,
            "eyes": self.eyes,
            "outfit": self.outfit,
            "personality_traits": self.personality_traits or [],
            "personality_sliders": self.personality_sliders or {},
            "siblings": self.siblings or [],
            "friends": self.friends or [],
            "likes": self.likes or [],
            "dislikes": self.dislikes or [],
            "fears": self.fears or [],
            "strengths": self.strengths or [],
            "goals": self.goals or [],
            "comfort_item": self.comfort_item,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
