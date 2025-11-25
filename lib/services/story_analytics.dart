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
    double? qualityScore,
    String? qualityBadge,
    int? wordCount,
    double? readabilityScore,
  }) async {
    final parameters = <String, Object?>{
      'theme': theme,
      'character_age': characterAge,
      'interactive_mode': interactiveMode,
      'rhyme_mode': rhymeMode,
      'character_name_length': characterName.length,
    };

    if (qualityScore != null) {
      parameters['quality_score'] = qualityScore;
    }
    if (qualityBadge != null) {
      parameters['quality_badge'] = qualityBadge;
    }
    if (wordCount != null) {
      parameters['word_count'] = wordCount;
    }
    if (readabilityScore != null) {
      parameters['readability_score'] = readabilityScore;
    }

    await _analytics.logEvent(
      name: 'story_created',
      parameters: parameters,
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

  static Future<void> trackStoryResultAction({
    required String storyId,
    required String action,
    String? theme,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final parameters = <String, Object?>{
      'story_id': storyId,
      'action': action,
    };
    if (theme != null) {
      parameters['theme'] = theme;
    }
    parameters.addAll(extra);
    await _analytics.logEvent(
      name: 'story_result_action',
      parameters: parameters,
    );
  }
}
