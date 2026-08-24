import 'package:flutter/material.dart';

import 'flavor_config.dart';

class Environment {
  static String get backendUrl => FlavorConfig.instance.backendUrl;
  static bool get isProduction =>
      FlavorConfig.instance.flavor == Flavor.production;
  static bool get isStaging =>
      FlavorConfig.instance.flavor == Flavor.staging;
  static bool get isDevelopment =>
      !isProduction && !isStaging;
  static String get appName => FlavorConfig.instance.name;
  static bool get showFlavorBanner => FlavorConfig.instance.showBanner;
  static String get bannerLabel => FlavorConfig.instance.bannerLabel;
  static Color get bannerColor => FlavorConfig.instance.bannerColor;
  static Color get primaryColor => FlavorConfig.instance.primaryColor;
  static String get sentryDsn => FlavorConfig.instance.sentryDsn;

  /// Commit SHA stamped in at build time by CI
  /// (`--dart-define=SENTRY_RELEASE=<sha>`, see `.github/workflows/cicd.yml`).
  /// Empty for local builds.
  ///
  /// Without this, Sentry falls back to the pubspec version for release
  /// identity — and that has read `1.0.0+1` since the first build, so every
  /// deploy reported the same release and the build a given device was
  /// actually running could not be determined from an event.
  static const String buildRelease = String.fromEnvironment('SENTRY_RELEASE');

  /// Short form of [buildRelease] for on-screen display.
  ///
  /// Rendered in Parent Controls so the running build can be identified from
  /// the device itself. That path does not depend on Sentry: reporting is
  /// consent-gated and off by default ([SentryConsentGate]), so a device that
  /// never errors — or never grants consent — still needs to be able to say
  /// which build it is on.
  static String get buildLabel => shortenRelease(buildRelease);

  /// Pure form of [buildLabel]'s logic.
  ///
  /// Split out because [buildRelease] is a compile-time constant that is
  /// always empty under `flutter test` — only the empty branch would ever be
  /// reachable through the getter, leaving the truncation untested.
  @visibleForTesting
  static String shortenRelease(String release) {
    // Returns the identifier only — callers supply the "Build " prefix, so
    // this must not read as a sentence on its own ("Build local build").
    if (release.isEmpty) return 'local';
    return release.length <= 7 ? release : release.substring(0, 7);
  }

  // Legacy helpers for explicit endpoints.
  static String get generateStoryUrl => '$backendUrl/generate-story';
  static String get generateInteractiveStoryUrl =>
      '$backendUrl/generate-interactive-story';
  static String get continueInteractiveStoryUrl =>
      '$backendUrl/continue-interactive-story';
  static String get summarizeChapterUrl =>
      '$backendUrl/chronicle/summarize-chapter';
  static String get compressArcUrl =>
      '$backendUrl/chronicle/compress-arc';
  static String get createCharacterUrl => '$backendUrl/create-character';
  static String get getCharactersUrl => '$backendUrl/get-characters';
}
