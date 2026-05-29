from ..database import db
from datetime import datetime, timezone
import uuid


class UserAchievement(db.Model):
    """Tracks user achievement progress and unlocks."""

    __tablename__ = "user_achievements"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey("user.id"), nullable=False)
    achievement_type = db.Column(
        db.String(50), nullable=False
    )  # AchievementType enum name
    current_value = db.Column(db.Integer, default=0, nullable=False)
    target_value = db.Column(db.Integer, nullable=False)
    is_unlocked = db.Column(db.Boolean, default=False, nullable=False)
    unlocked_at = db.Column(db.DateTime, nullable=True)
    is_new = db.Column(db.Boolean, default=False, nullable=False)
    last_updated = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    user = db.relationship("User", backref=db.backref("achievements", lazy=True))

    __table_args__ = (
        db.UniqueConstraint(
            "user_id", "achievement_type", name="unique_user_achievement"
        ),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "achievement_type": self.achievement_type,
            "current_value": self.current_value,
            "target_value": self.target_value,
            "is_unlocked": self.is_unlocked,
            "unlocked_at": self.unlocked_at.isoformat() if self.unlocked_at else None,
            "is_new": self.is_new,
            "last_updated": self.last_updated.isoformat(),
        }


class AchievementStats(db.Model):
    """Tracks user achievement statistics and streaks."""

    __tablename__ = "achievement_stats"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(
        db.String(36), db.ForeignKey("user.id"), nullable=False, unique=True
    )

    # Story tracking
    total_stories = db.Column(db.Integer, default=0, nullable=False)
    theme_counts = db.Column(
        db.JSON, default=dict, nullable=False
    )  # {'Adventure': 5, 'Friendship': 3, ...}

    # Character tracking
    characters_created = db.Column(db.Integer, default=0, nullable=False)

    # Streak tracking
    current_streak = db.Column(db.Integer, default=0, nullable=False)
    longest_streak = db.Column(db.Integer, default=0, nullable=False)
    last_story_date_iso = db.Column(db.String(10), nullable=True)  # YYYY-MM-DD format

    # Time-based achievements
    earned_early_bird = db.Column(db.Boolean, default=False, nullable=False)
    earned_night_owl = db.Column(db.Boolean, default=False, nullable=False)

    # Emotion tracking
    unique_emotions_logged = db.Column(db.Integer, default=0, nullable=False)

    last_updated = db.Column(
        db.DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationships
    user = db.relationship(
        "User",
        backref=db.backref(
            "achievement_stats", uselist=False, cascade="all, delete-orphan"
        ),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "total_stories": self.total_stories,
            "theme_counts": self.theme_counts,
            "characters_created": self.characters_created,
            "current_streak": self.current_streak,
            "longest_streak": self.longest_streak,
            "last_story_date_iso": self.last_story_date_iso,
            "earned_early_bird": self.earned_early_bird,
            "earned_night_owl": self.earned_night_owl,
            "unique_emotions_logged": self.unique_emotions_logged,
            "last_updated": self.last_updated.isoformat(),
        }
