import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_analytics_service.dart';
import 'sentry_consent_gate.dart';

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

  /// Reconciles analytics AND crash-reporting collection with a
  /// parental-consent result.
  ///
  /// Both Firebase Analytics collection and Sentry crash reporting are enabled
  /// ONLY when BOTH hold:
  ///  - the consent flow granted consent ([consentGranted]), AND
  ///  - the declared age is >= 13 ([declaredAge]).
  ///
  /// GA-for-Firebase is not COPPA-certified for children's data, and
  /// third-party crash reporting from a child's session is prohibited by
  /// Apple Kids-Category 1.3/5.1.4 — so an under-13 account never turns
  /// either one on, even with parental consent (STORE-2, M-9, COPPA §312.5).
  ///
  /// Best-effort: this runs inside the parental-consent completion flow, so
  /// an analytics/plugin failure must NEVER propagate and break consent
  /// onboarding. Any error is caught and swallowed here.
  static Future<void> applyConsentDecision({
    required bool consentGranted,
    required int declaredAge,
  }) async {
    final allowCollection = consentGranted && declaredAge >= 13;
    // STORE-2: gate Sentry crash reporting on the same COPPA decision as
    // analytics. This is a pure in-process flag flip and cannot throw, so it
    // runs before the analytics block (which may fail) to guarantee the
    // Sentry gate is always reconciled.
    SentryConsentGate.setReportingEnabled(allowCollection);
    try {
      await FirebaseAnalyticsService.setCollectionEnabled(allowCollection);
      if (!allowCollection) {
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
