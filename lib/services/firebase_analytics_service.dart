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

  // Tracks whether collection has been explicitly enabled after a consent
  // decision. Until then, `logEvent`/`setUserProperties` are no-ops so nothing
  // is reported pre-consent.
  static bool _collectionEnabled = false;
  static bool get isCollectionEnabled => _collectionEnabled;

  /// Initializes Firebase but leaves analytics collection OFF.
  ///
  /// SECURITY (M-9, COPPA §312.5(a)): GA-for-Firebase is not COPPA-certified
  /// for children's data, and collection must not begin before verified
  /// parental consent. Collection is enabled later — and only — via
  /// [PrivacyService.applyConsentDecision], which is wired to the consent
  /// result AND the adult-age default gate (18+; see [PrivacyDefaults]).
  static Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Default collection OFF — do NOT enable here. It fires for under-13
    // users and before the consent screen otherwise.
    // setAnalyticsCollectionEnabled causes a JS interop TypeError on web
    // (FirebaseException can't be cast to JavaScriptObject). Skip on web.
    if (!kIsWeb) {
      try {
        await analytics.setAnalyticsCollectionEnabled(false);
      } catch (e) {
        // Non-fatal.
      }
    }
    _collectionEnabled = false;
    _initialized = true;
  }

  /// Enables or disables analytics collection at runtime. Called by
  /// [PrivacyService.applyConsentDecision] once a consent decision is known.
  /// [consented] must already encode the privacy gate (verified consent AND
  /// adult-age default per [PrivacyDefaults]) — this method does not re-check it.
  static Future<void> setCollectionEnabled(bool consented) async {
    _collectionEnabled = consented;
    if (kIsWeb) {
      // Web skips the native interop call; the in-process `_collectionEnabled`
      // guard still prevents events from being logged.
      return;
    }
    try {
      await analytics.setAnalyticsCollectionEnabled(consented);
    } catch (e) {
      // Non-fatal.
    }
  }

  static Future<void> setUserProperties(
    String userId,
    Map<String, dynamic> properties,
  ) async {
    if (!_initialized || !_collectionEnabled) return;
    try {
      await analytics.setUserId(id: userId);
      for (final entry in properties.entries) {
        await analytics.setUserProperty(
          name: entry.key,
          value: entry.value?.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FirebaseAnalyticsService.setUserProperties error: $e');
      }
    }
  }

  static Future<void> logEvent(String eventName, Map<String, dynamic> parameters) async {
    if (!_initialized || !_collectionEnabled) return;
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
