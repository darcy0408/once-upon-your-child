import 'package:flutter/foundation.dart';

import 'analytics_service.dart';

/// Therapeutic/emotional-state analytics — first-party backend ONLY.
///
/// SECURITY (H-3, docs/DECISION_D1_D2_KIDS_CATEGORY_ANALYTICS_2026-07-13.md):
/// these events (`feelings_check_in`, `therapeutic_feedback`,
/// `story_emotion_moment`) describe a child's emotional state. Even
/// consent-gated, sending them to a third party (Firebase/Google) is the
/// worst-optics data flow in the app, and under the amended COPPA rule,
/// third-party disclosure that isn't integral to the service needs separate
/// verifiable parental consent — analytics is not "integral." These events
/// are therefore routed ONLY through [AnalyticsService] (the existing
/// first-party `POST /analytics/event` -> `analytics_events` table sink,
/// see `backend/analytics_routes.py` / `backend/models/analytics_event.py`)
/// and MUST NEVER be sent to Firebase/`firebase_analytics`.
///
/// Payloads are categorical-only, matching the table's no-PII/no-story-content
/// design: enumerated emotion/coping labels (drawn from the fixed
/// `Emotion`/coping-strategy catalogs, never free-typed text), integer
/// intensity, and feedback *length* as an int — never the feedback text
/// itself, never a child's name.
class TherapeuticAnalytics {
  TherapeuticAnalytics._();

  static Future<void> trackFeelingsCheckIn({
    required String emotionName,
    required int intensity,
    required List<String> copingStrategies,
  }) async {
    try {
      AnalyticsService.track(
        'feelings_check_in',
        metadata: {
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
      AnalyticsService.track(
        'therapeutic_feedback',
        metadata: {
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
      AnalyticsService.track(
        'story_emotion_moment',
        metadata: {
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
