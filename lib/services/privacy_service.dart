import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_analytics_service.dart';
import 'privacy_defaults.dart';
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
    if (!consented) {
      // GDPR Art. 7(3): on withdrawal, also drop any data buffered while
      // collection was enabled.
      await resetAnalyticsData();
    }
  }

  /// Whether Firebase Analytics collection is currently enabled.
  ///
  /// Reflects the in-process collection flag set by [setAnalyticsConsent] /
  /// [applyConsentDecision]. Used by the Parent Controls analytics toggle so
  /// it shows the live state (PP-9, GDPR Art. 7(3)).
  static bool get isAnalyticsEnabled =>
      FirebaseAnalyticsService.isCollectionEnabled;

  /// Reconciles analytics AND crash-reporting collection with a
  /// parental-consent result.
  ///
  /// Both Firebase Analytics collection and Sentry crash reporting are enabled
  /// ONLY when BOTH hold:
  ///  - the consent flow granted consent ([consentGranted]), AND
  ///  - the declared age is an adult per [PrivacyDefaults.analyticsAllowedByDefault]
  ///    (18+; see below).
  ///
  /// The age cutoff is **18, not 13**. COPPA (under 13) prohibits this outright,
  /// but CAADCA additionally requires privacy-protective *defaults* for the
  /// whole under-18 range, and keeping analytics off for 13–17 also avoids the
  /// CCPA/CPRA risk that an analytics SDK passing identifiers counts as
  /// "sharing" a minor's data. A minor can still opt in explicitly elsewhere;
  /// this only sets the default. (CAADCA, STORE-2, M-9, COPPA §312.5.)
  ///
  /// GA-for-Firebase is not COPPA-certified for children's data, and
  /// third-party crash reporting from a child's session is prohibited by
  /// Apple Kids-Category 1.3/5.1.4.
  ///
  /// Best-effort: this runs inside the parental-consent completion flow, so
  /// an analytics/plugin failure must NEVER propagate and break consent
  /// onboarding. Any error is caught and swallowed here.
  static Future<void> applyConsentDecision({
    required bool consentGranted,
    required int declaredAge,
  }) async {
    final allowCollection =
        consentGranted && PrivacyDefaults.analyticsAllowedByDefault(declaredAge);
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
