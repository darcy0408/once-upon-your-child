import 'package:firebase_analytics/firebase_analytics.dart';

class InteractiveStoryAnalytics {
  InteractiveStoryAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackStoryStarted({
    required String characterId,
    required String characterName,
    required int characterAge,
    required String theme,
    required bool hasCompanion,
  }) async {
    await _analytics.logEvent(
      name: 'interactive_story_started',
      parameters: {
        'character_id': characterId,
        'character_name_length': characterName.length,
        'character_age': characterAge,
        'theme': theme,
        'has_companion': hasCompanion,
      },
    );
  }

  static Future<void> trackChoiceSelected({
    required String characterId,
    required String theme,
    required String choiceId,
    required int choiceNumber,
    required int choiceTextLength,
  }) async {
    await _analytics.logEvent(
      name: 'interactive_choice_made',
      parameters: {
        'character_id': characterId,
        'theme': theme,
        'choice_id': choiceId,
        'choice_number': choiceNumber,
        'choice_text_length': choiceTextLength,
      },
    );
  }

  static Future<void> trackStorySaved({
    required String characterId,
    required String theme,
    required int choiceCount,
    required int segmentCount,
    required int wordCount,
  }) async {
    await _analytics.logEvent(
      name: 'interactive_story_saved',
      parameters: {
        'character_id': characterId,
        'theme': theme,
        'choice_count': choiceCount,
        'segment_count': segmentCount,
        'word_count': wordCount,
      },
    );
  }
}
