import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

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

    await _safeLogEvent('story_created', parameters);
  }

  static Future<void> trackStoryCompletion({
    required String storyId,
    required int wordCount,
    required Duration readingTime,
  }) async {
    await _safeLogEvent('story_completed', {
      'story_id': storyId,
      'word_count': wordCount,
      'reading_time_seconds': readingTime.inSeconds,
    });
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
    await _safeLogEvent('story_result_action', parameters);
  }

  static Future<void> _safeLogEvent(
    String name,
    Map<String, Object?> parameters,
  ) async {
    try {
      // Convert to Map<String, dynamic> and ensure all values are primitive types
      final Map<String, dynamic> cleanParams = {};
      parameters.forEach((key, value) {
        if (value != null) {
          // Only include primitive types that Firebase Analytics accepts
          if (value is String || value is num || value is bool) {
            cleanParams[key] = value;
          } else {
            cleanParams[key] = value.toString();
          }
        }
      });
      await _analytics.logEvent(name: name, parameters: cleanParams);
    } catch (e) {
      // Do not let analytics failures crash the app (seen in web builds).
      debugPrint('Analytics logEvent failed ($name): ${e.toString()}');
    }
  }
}
