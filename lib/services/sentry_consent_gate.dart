/// Consent gate for Sentry crash/error reporting.
///
/// SECURITY (STORE-2, Apple Kids-Category 1.3 / 5.1.4, COPPA §312.5):
/// `SentryFlutter.init()` cannot be deferred — it must wrap `runApp` — so it is
/// always called, but it ships NOTHING until parental consent is verified.
///
/// The `beforeSend` hook in `main()` consults [isReportingEnabled]; while the
/// flag is false (the default) every event is dropped before leaving the
/// device. The flag is flipped true ONLY by
/// [PrivacyService.applyConsentDecision], and only when consent was granted
/// AND the declared age is >= 13 — mirroring exactly how Firebase Analytics
/// collection is gated (see [FirebaseAnalyticsService]).
class SentryConsentGate {
  SentryConsentGate._();

  // Defaults OFF: nothing is reported until a consent decision is applied.
  static bool _reportingEnabled = false;

  /// Whether Sentry is currently permitted to send events off-device.
  static bool get isReportingEnabled => _reportingEnabled;

  /// Sets the reporting flag. Called by [PrivacyService.applyConsentDecision]
  /// once a consent decision is known. [enabled] must already encode the
  /// COPPA gate (verified consent AND declared age >= 13) — this method does
  /// not re-check it.
  static void setReportingEnabled(bool enabled) {
    _reportingEnabled = enabled;
  }
}
