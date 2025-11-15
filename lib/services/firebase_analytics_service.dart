import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();

  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;
  static bool _initialized = false;
  static bool _firebaseAvailable = false;

  static FirebaseAnalytics? get analytics => _analytics;
  static FirebaseAnalyticsObserver? get observer => _observer;
  static bool get isInitialized => _initialized && _firebaseAvailable;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      await _analytics!.setAnalyticsCollectionEnabled(true);
      _firebaseAvailable = true;
      _initialized = true;
    } catch (e) {
      // Firebase not available or configured - graceful degradation
      _firebaseAvailable = false;
      _initialized = true;
    }
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
}
