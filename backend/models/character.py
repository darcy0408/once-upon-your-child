from ..database import db

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

    # Character type and superhero specific
    character_type = db.Column(db.String(50), default='Everyday Kid')
    superhero_name = db.Column(db.String(100))
    mission = db.Column(db.Text)

    # Appearance
    hair = db.Column(db.String(50))
    eyes = db.Column(db.String(50))
    outfit = db.Column(db.String(200))

    # AI-Generated Avatar Data
    avatar_data = db.Column(db.JSON, nullable=True, default=None)
    # Structure: {
    #   'id': str,
    #   'image_base64': str (data:image/png;base64,...),
    #   'seed': str,
    #   'style': str (pixar|watercolor|cartoon|clay),
    #   'attributes': {hair_style, hair_color, skin_tone, outfit, expression},
    #   'emotion_data': {core, eye_type, mouth_type},
    #   'generated_at': str (ISO),
    #   'version': int
    # }

    # Avataaars Customization Parameters (DiceBear)
    avatar_params = db.Column(db.JSON, nullable=True, default=None)
    # Structure: {'top': 'curly', 'hairColor': 'brown', 'clothing': 'hoodie', ...}

    # SQLite JSON (persists as TEXT)
    personality_traits = db.Column(db.JSON, default=list)
    personality_sliders = db.Column(db.JSON, default=dict)
    siblings = db.Column(db.JSON, default=list)
    friends = db.Column(db.JSON, default=list)
    likes = db.Column(db.JSON, default=list)
    dislikes = db.Column(db.JSON, default=list)
    fears = db.Column(db.JSON, default=list)
    strengths = db.Column(db.JSON, default=list)
    goals = db.Column(db.JSON, default=list)
    pets = db.Column(db.JSON, default=list)

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
            "pets": self.pets or [],
            "comfort_item": self.comfort_item,
            "avatar_data": self.avatar_data,
            "avatar_params": self.avatar_params,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
