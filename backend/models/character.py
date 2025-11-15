from backend.database import db

class Character(db.Model):
    """Stores character information, traits, relationships, and metadata."""
        user_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=True)
    id = db.Column(db.String(36), primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    gender = db.Column(db.String(50))
    role = db.Column(db.String(50))
    magic_type = db.Column(db.String(50))
    challenge = db.Column(db.Text)

    # SQLite JSON (persists as TEXT)
    personality_traits = db.Column(db.JSON, default=list)
    siblings = db.Column(db.JSON, default=list)
    friends = db.Column(db.JSON, default=list)
    likes = db.Column(db.JSON, default=list)
    dislikes = db.Column(db.JSON, default=list)
    fears = db.Column(db.JSON, default=list)

    comfort_item = db.Column(db.String(200))
    created_at = db.Column(db.DateTime, default=db.func.now(), index=True)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "age": self.age,
            "gender": self.gender,
            "role": self.role,
            "magic_type": self.magic_type,
            "challenge": self.challenge,
            "personality_traits": self.personality_traits or [],
            "siblings": self.siblings or [],
            "friends": self.friends or [],
            "likes": self.likes or [],
            "dislikes": self.dislikes or [],
            "fears": self.fears or [],
            "comfort_item": self.comfort_item,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
