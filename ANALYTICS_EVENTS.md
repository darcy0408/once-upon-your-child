# Analytics Events Reference (Week 3)

This file documents the key analytics events and where they are emitted for verification (C2-3.3 / G5).

## Interactive Stories
- `interactive_story_started` — `lib/services/interactive_story_analytics.dart`
- `interactive_choice_made` — same service (now includes `emotional_skill` when available)
- `interactive_story_saved` — same service

## Story Results
- `story_created` — `lib/services/story_analytics.dart`
- `story_completed` — same
- `story_result_action` — same (share/save/export/etc.)

## Feelings Corner
- `feelings_corner_viewed` — `lib/services/feelings_analytics_service.dart`
- `feelings_check_in` — same
- `feelings_reminder_toggled` — same

## Grace Period / Upgrade
- `grace_period_banner_viewed` — `lib/main_story.dart` when grace banner appears
- `grace_period_soft_prompt_shown` — `lib/main_story.dart` before soft dialog
- `grace_period_hard_limit_reached` — `lib/main_story.dart` before hard dialog
- `upgrade_prompt_clicked` — TODO (hook button taps in paywall/upgrade dialogs)

## Notes
- FirebaseAnalytics is used throughout; on web, some services guard against collection.
- Verify in-app by triggering each flow and checking console/analytics dashboard.***
