import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class TherapeuticAnalytics {
  TherapeuticAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackFeelingsCheckIn({
    required String emotionName,
    required int intensity,
    required List<String> copingStrategies,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'feelings_check_in',
        parameters: {
          'emotion': emotionName,
          'intensity': intensity,
          'coping_strategies_count': copingStrategies.length,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TherapeuticAnalytics error: ${e.toString()}');
      }
    }
  }

  static Future<void> trackTherapeuticFeedback({
    required int rating,
    required String feedbackText,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'therapeutic_feedback',
        parameters: {
          'rating': rating,
          'feedback_length': feedbackText.length,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TherapeuticAnalytics error: ${e.toString()}');
      }
    }
  }

  static Future<void> trackStoryMoment({
    required String emotion,
    required String copingStrategy,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'story_emotion_moment',
        parameters: {
          'emotion': emotion,
          'coping_strategy': copingStrategy,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TherapeuticAnalytics error: ${e.toString()}');
      }
    }
  }
}
