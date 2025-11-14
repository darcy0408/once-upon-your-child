import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();

  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  static bool _initialized = false;

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
}
