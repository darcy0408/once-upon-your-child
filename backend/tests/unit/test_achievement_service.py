from backend.database import db
from backend.models.achievement import AchievementStats, UserAchievement
from backend.services.achievement_service import AchievementService


class TestAchievementService:
    def _cleanup_for_user(self, user_id: str):
        UserAchievement.query.filter_by(user_id=user_id).delete()
        AchievementStats.query.filter_by(user_id=user_id).delete()
        db.session.commit()

    def test_get_or_create_stats_creates_and_reuses_record(self, app, test_user):
        service = AchievementService()

        with app.app_context():
            stats_first = service.get_or_create_stats(test_user.id)
            stats_second = service.get_or_create_stats(test_user.id)

            assert stats_first.id == stats_second.id
            assert stats_first.user_id == test_user.id
            self._cleanup_for_user(test_user.id)

    def test_record_story_created_updates_stats_and_unlocks(self, app, test_user):
        service = AchievementService()

        with app.app_context():
            result = service.record_story_created(test_user.id, theme="Adventure")
            stats = AchievementStats.query.filter_by(user_id=test_user.id).first()
            first_story = UserAchievement.query.filter_by(
                user_id=test_user.id,
                achievement_type="firstStory",
            ).first()

            assert result["status"] == "success"
            assert "firstStory" in result["new_unlocks"]
            assert stats.total_stories == 1
            assert stats.current_streak == 1
            assert stats.longest_streak == 1
            assert first_story is not None
            assert first_story.is_unlocked is True
            self._cleanup_for_user(test_user.id)

    def test_record_character_created_unlocks_character_creator(self, app, test_user):
        service = AchievementService()

        with app.app_context():
            stats = service.get_or_create_stats(test_user.id)
            stats.characters_created = 2
            db.session.commit()

            result = service.record_character_created(test_user.id)
            refreshed = AchievementStats.query.filter_by(user_id=test_user.id).first()
            achievement = UserAchievement.query.filter_by(
                user_id=test_user.id,
                achievement_type="characterCreator",
            ).first()

            assert result["status"] == "success"
            assert "characterCreator" in result["new_unlocks"]
            assert refreshed.characters_created == 3
            assert achievement is not None
            assert achievement.is_unlocked is True
            self._cleanup_for_user(test_user.id)

    def test_sync_achievement_progress_updates_records_and_stats(self, app, test_user):
        service = AchievementService()

        payload = {
            "achievements": [
                {
                    "type": "fiveStories",
                    "current_value": 5,
                    "target_value": 5,
                    "is_unlocked": True,
                    "unlocked_at": "2024-01-01T10:00:00.000Z",
                    "is_new": False,
                }
            ],
            "stats": {
                "total_stories": 5,
                "theme_counts": {"Adventure": 3},
                "characters_created": 1,
                "current_streak": 2,
                "longest_streak": 3,
                "last_story_date_iso": "2024-01-01",
                "earned_early_bird": True,
                "earned_night_owl": False,
                "unique_emotions_logged": 4,
            },
        }

        with app.app_context():
            result = service.sync_achievement_progress(test_user.id, payload)
            record = UserAchievement.query.filter_by(
                user_id=test_user.id,
                achievement_type="fiveStories",
            ).first()
            stats = AchievementStats.query.filter_by(user_id=test_user.id).first()
            data = service.get_achievement_data(test_user.id)

            assert result["status"] == "success"
            assert record is not None
            assert record.current_value == 5
            assert record.is_unlocked is True
            assert stats.total_stories == 5
            assert stats.theme_counts["Adventure"] == 3
            assert data["stats"]["total_stories"] == 5
            assert any(a["achievement_type"] == "fiveStories" for a in data["achievements"])
            self._cleanup_for_user(test_user.id)
