import uuid
from ..database import db
from datetime import datetime, timezone

class Story(db.Model):
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=False, index=True)
    # Stable identifier for the *protagonist* character so we can recall this
    # character's prior adventures across stories. Nullable for legacy rows and
    # for anonymous / character-less generation paths. Indexed because the
    # recall query is `WHERE character_id = ? ORDER BY created_at DESC LIMIT N`.
    character_id = db.Column(db.String(36), db.ForeignKey('character.id'), nullable=True, index=True)
    title = db.Column(db.String(200))
    theme = db.Column(db.String(100), nullable=True)
    # Themes extracted from the generated story (vs. `theme` which is the user-picked input).
    # 3-6 short lowercase tags emitted by Gemini at generation time so we can recall
    # "what has this child explored before" without embeddings.
    themes = db.Column(db.JSON, default=list)
    characters_featured = db.Column(db.JSON, default=list)
    emotional_arc = db.Column(db.String(120), nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    # R2: the Celery task id this story was generated under. Lets /task-status
    # recover a finished story from the DB after the Celery result expires
    # (result_expires=1h). Indexed for the recovery lookup. Nullable for
    # legacy rows that predate R2.
    task_id = db.Column(db.String(64), nullable=True, index=True)
    # R2: the full story payload returned to the client (title, story_text,
    # pages, adventure_steps, etc.). Persisting it means a successfully
    # generated story survives Celery result expiry. Nullable for legacy rows.
    content = db.Column(db.JSON, nullable=True)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'character_id': self.character_id,
            'title': self.title,
            'theme': self.theme,
            'themes': self.themes or [],
            'characters_featured': self.characters_featured or [],
            'emotional_arc': self.emotional_arc,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }