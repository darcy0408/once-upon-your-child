import 'package:firebase_analytics/firebase_analytics.dart';

class TherapeuticAnalytics {
  TherapeuticAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackFeelingsCheckIn({
    required String emotionName,
    required int intensity,
    required List<String> copingStrategies,
  }) async {
    await _analytics.logEvent(
      name: 'feelings_check_in',
      parameters: {
        'emotion': emotionName,
        'intensity': intensity,
        'coping_strategies_count': copingStrategies.length,
      },
    );
  }

  static Future<void> trackTherapeuticFeedback({
    required int rating,
    required String feedbackText,
  }) async {
    await _analytics.logEvent(
      name: 'therapeutic_feedback',
      parameters: {
        'rating': rating,
        'feedback_length': feedbackText.length,
      },
    );
  }
}
