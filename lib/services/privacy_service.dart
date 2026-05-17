import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_analytics_service.dart';

class PrivacyService {
  PrivacyService._();

  /// Enables or disables Firebase Analytics collection.
  ///
  /// SECURITY (M-9, COPPA §312.5): analytics defaults OFF (see
  /// [FirebaseAnalyticsService.initialize]). Pass [consented] = true ONLY
  /// after a parental-consent decision is known. Prefer
  /// [applyConsentDecision], which additionally enforces the declared-age
  /// gate so analytics never turns on for an under-13 user.
  static Future<void> setAnalyticsConsent(bool consented) async {
    await FirebaseAnalyticsService.setCollectionEnabled(consented);
  }

  /// Reconciles analytics collection with a parental-consent result.
  ///
  /// Collection is enabled ONLY when BOTH hold:
  ///  - the consent flow granted consent ([consentGranted]), AND
  ///  - the declared age is >= 13 ([declaredAge]).
  ///
  /// GA-for-Firebase is not COPPA-certified for children's data, so an
  /// under-13 account never turns analytics on even with parental consent.
  ///
  /// Best-effort: this runs inside the parental-consent completion flow, so
  /// an analytics/plugin failure must NEVER propagate and break consent
  /// onboarding. Any error is caught and swallowed here.
  static Future<void> applyConsentDecision({
    required bool consentGranted,
    required int declaredAge,
  }) async {
    try {
      final allowAnalytics = consentGranted && declaredAge >= 13;
      await FirebaseAnalyticsService.setCollectionEnabled(allowAnalytics);
      if (!allowAnalytics) {
        // Defensive: clear any data buffered before the gate was evaluated.
        await resetAnalyticsData();
      }
    } catch (e) {
      // Analytics is best-effort and must not block the consent flow.
      if (kDebugMode) {
        debugPrint('PrivacyService.applyConsentDecision (non-fatal): $e');
      }
    }
  }

  /// Clears any analytics data buffered before a consent gate was evaluated.
  ///
  /// Best-effort: `resetAnalyticsData()` is not implemented on Flutter web
  /// (the plugin throws there), so it is skipped on web; any other error is
  /// swallowed. Analytics must never break a critical flow.
  static Future<void> resetAnalyticsData() async {
    if (kIsWeb) return;
    try {
      await FirebaseAnalytics.instance.resetAnalyticsData();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PrivacyService.resetAnalyticsData (non-fatal): $e');
      }
    }
  }
}
