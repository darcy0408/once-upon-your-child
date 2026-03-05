import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();

  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await analytics.setAnalyticsCollectionEnabled(true);
    _initialized = true;
  }

  static Future<void> setUserProperties(
    String userId,
    Map<String, dynamic> properties,
  ) async {
    await analytics.setUserId(id: userId);
    for (final entry in properties.entries) {
      await analytics.setUserProperty(
        name: entry.key,
        value: entry.value?.toString(),
      );
    }
  }

  static Future<void> logEvent(String eventName, Map<String, dynamic> parameters) async {
    try {
      // Convert to Map<String, Object> for Firebase Analytics compatibility
      final Map<String, Object> cleanParams = {};
      parameters.forEach((key, value) {
        if (value != null) {
          if (value is bool) {
            cleanParams[key] = value ? 1 : 0;
          } else if (value is String || value is num) {
            cleanParams[key] = value;
          } else {
            cleanParams[key] = value.toString();
          }
        }
      });
      await analytics.logEvent(
        name: eventName,
        parameters: cleanParams.cast<String, Object>(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FirebaseAnalyticsService error: ${e.toString()}');
      }
    }
  }
}
