import 'package:firebase_analytics/firebase_analytics.dart';

class StoryAnalytics {
  StoryAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackStoryCreation({
    required String theme,
    required String characterName,
    required int characterAge,
    required bool interactiveMode,
    required bool rhymeMode,
  }) async {
    await _analytics.logEvent(
      name: 'story_created',
      parameters: {
        'theme': theme,
        'character_age': characterAge,
        'interactive_mode': interactiveMode,
        'rhyme_mode': rhymeMode,
        'character_name_length': characterName.length,
      },
    );
  }

  static Future<void> trackStoryCompletion({
    required String storyId,
    required int wordCount,
    required Duration readingTime,
  }) async {
    await _analytics.logEvent(
      name: 'story_completed',
      parameters: {
        'story_id': storyId,
        'word_count': wordCount,
        'reading_time_seconds': readingTime.inSeconds,
      },
    );
  }
}
