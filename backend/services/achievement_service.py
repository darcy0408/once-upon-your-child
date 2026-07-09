import logging
from datetime import datetime

from ..database import db
from ..models.achievement import AchievementStats, UserAchievement

logger = logging.getLogger(__name__)


class AchievementService:
    """Backend service for managing user achievements."""

    # Achievement definitions (mirroring frontend)
    ACHIEVEMENT_DEFINITIONS = {
        "firstStory": {"target_value": 1, "category": "storyCount"},
        "fiveStories": {"target_value": 5, "category": "storyCount"},
        "tenStories": {"target_value": 10, "category": "storyCount"},
        "twentyFiveStories": {"target_value": 25, "category": "storyCount"},
        "fiftyStories": {"target_value": 50, "category": "storyCount"},
        "hundredStories": {"target_value": 100, "category": "storyCount"},
        "adventureExplorer": {"target_value": 10, "category": "themes"},
        "friendshipBuilder": {"target_value": 10, "category": "themes"},
        "magicMaster": {"target_value": 10, "category": "themes"},
        "dragonTamer": {"target_value": 10, "category": "themes"},
        "castleGuardian": {"target_value": 10, "category": "themes"},
        "unicornDreamer": {"target_value": 10, "category": "themes"},
        "spaceAdventurer": {"target_value": 10, "category": "themes"},
        "oceanGuardian": {"target_value": 10, "category": "themes"},
        "streak3": {"target_value": 3, "category": "streaks"},
        "streak7": {"target_value": 7, "category": "streaks"},
        "streak30": {"target_value": 30, "category": "streaks"},
        "earlyBird": {"target_value": 1, "category": "time"},
        "nightOwl": {"target_value": 1, "category": "time"},
        "characterCreator": {"target_value": 3, "category": "characters"},
        "characterChampion": {"target_value": 10, "category": "characters"},
        "emotionExplorer": {"target_value": 5, "category": "emotions"},
        "emotionMentor": {"target_value": 12, "category": "emotions"},
        "emotionMaster": {"target_value": 20, "category": "emotions"},
    }

    def get_or_create_stats(self, user_id: str) -> AchievementStats:
        """Get or create achievement stats for a user."""
        stats = AchievementStats.query.filter_by(user_id=user_id).first()
        if not stats:
            stats = AchievementStats(user_id=user_id)
            db.session.add(stats)
            db.session.commit()
        return stats

    def sync_achievement_progress(self, user_id: str, achievement_data: dict):
        """
        Sync achievement progress from frontend to backend.

        Expected format:
        {
            'achievements': [
                {
                    'type': 'firstStory',
                    'current_value': 1,
                    'target_value': 1,
                    'is_unlocked': True,
                    'unlocked_at': '2024-01-01T10:00:00.000Z',
                    'is_new': False
                },
                ...
            ],
            'stats': {
                'total_stories': 5,
                'theme_counts': {'Adventure': 3, 'Friendship': 2},
                'characters_created': 2,
                'current_streak': 2,
                'longest_streak': 3,
                'last_story_date_iso': '2024-01-01',
                'earned_early_bird': False,
                'earned_night_owl': True,
                'unique_emotions_logged': 8
            }
        }
        """
        try:
            # Update achievement records
            if "achievements" in achievement_data:
                for achievement in achievement_data["achievements"]:
                    self._update_achievement_record(user_id, achievement)

            # Update stats
            if "stats" in achievement_data:
                self._update_achievement_stats(user_id, achievement_data["stats"])

            db.session.commit()
            return {"status": "success"}

        except Exception as e:
            db.session.rollback()
            logger.error(f"Failed to sync achievements for user {user_id}: {e}")
            return {"status": "error", "message": str(e)}

    def _update_achievement_record(self, user_id: str, achievement_data: dict):
        """Update a single achievement record."""
        achievement_type = achievement_data["type"]

        # Get or create achievement record
        record = UserAchievement.query.filter_by(
            user_id=user_id, achievement_type=achievement_type
        ).first()

        if not record:
            record = UserAchievement(
                user_id=user_id,
                achievement_type=achievement_type,
                target_value=achievement_data["target_value"],
            )
            db.session.add(record)

        # Update record
        record.current_value = achievement_data["current_value"]
        record.is_unlocked = achievement_data["is_unlocked"]
        record.is_new = achievement_data.get("is_new", False)

        if achievement_data.get("unlocked_at"):
            record.unlocked_at = datetime.fromisoformat(
                achievement_data["unlocked_at"].replace("Z", "+00:00")
            )

    def _update_achievement_stats(self, user_id: str, stats_data: dict):
        """Update achievement statistics."""
        stats = self.get_or_create_stats(user_id)

        # Update stats fields
        stats.total_stories = stats_data.get("total_stories", stats.total_stories)
        stats.theme_counts = stats_data.get("theme_counts", stats.theme_counts)
        stats.characters_created = stats_data.get(
            "characters_created", stats.characters_created
        )
        stats.current_streak = stats_data.get("current_streak", stats.current_streak)
        stats.longest_streak = stats_data.get("longest_streak", stats.longest_streak)
        # Column is VARCHAR(10) (YYYY-MM-DD). Older app clients post a full ISO
        # datetime; truncate to the date portion to avoid StringDataRightTruncation.
        last_story_date = stats_data.get(
            "last_story_date_iso", stats.last_story_date_iso
        )
        if last_story_date and len(last_story_date) > 10:
            last_story_date = last_story_date[:10]
        stats.last_story_date_iso = last_story_date
        stats.earned_early_bird = stats_data.get(
            "earned_early_bird", stats.earned_early_bird
        )
        stats.earned_night_owl = stats_data.get(
            "earned_night_owl", stats.earned_night_owl
        )
        stats.unique_emotions_logged = stats_data.get(
            "unique_emotions_logged", stats.unique_emotions_logged
        )

    def get_achievement_data(self, user_id: str) -> dict:
        """Get all achievement data for a user."""
        try:
            # Get achievement records
            records = UserAchievement.query.filter_by(user_id=user_id).all()
            achievements = [record.to_dict() for record in records]

            # Get stats
            stats = self.get_or_create_stats(user_id)
            stats_data = stats.to_dict()

            return {"achievements": achievements, "stats": stats_data}

        except Exception as e:
            logger.error(f"Failed to get achievement data for user {user_id}: {e}")
            return {"achievements": [], "stats": {}}

