import uuid
from ..database import db
from datetime import datetime, timezone

class Story(db.Model):
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=False, index=True)
    title = db.Column(db.String(200))
    theme = db.Column(db.String(100), nullable=True)
    # Themes extracted from the generated story (vs. `theme` which is the user-picked input).
    # 3-6 short lowercase tags emitted by Gemini at generation time so we can recall
    # "what has this child explored before" without embeddings.
    themes = db.Column(db.JSON, default=list)
    characters_featured = db.Column(db.JSON, default=list)
    emotional_arc = db.Column(db.String(120), nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), index=True)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'title': self.title,
            'theme': self.theme,
            'themes': self.themes or [],
            'characters_featured': self.characters_featured or [],
            'emotional_arc': self.emotional_arc,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }