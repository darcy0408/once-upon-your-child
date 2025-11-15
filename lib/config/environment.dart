import 'package:flutter/material.dart';

import 'flavor_config.dart';

class Environment {
  static String get backendUrl => FlavorConfig.instance.backendUrl;
  static bool get isProduction =>
      FlavorConfig.instance.flavor == Flavor.production;
  static bool get isStaging =>
      FlavorConfig.instance.flavor == Flavor.staging;
  static String get appName => FlavorConfig.instance.name;
  static bool get showFlavorBanner => FlavorConfig.instance.showBanner;
  static String get bannerLabel => FlavorConfig.instance.bannerLabel;
  static Color get bannerColor => FlavorConfig.instance.bannerColor;
  static Color get primaryColor => FlavorConfig.instance.primaryColor;
  static String? get geminiApiKey =>
      FlavorConfig.instance.geminiApiKey.isEmpty
          ? null
          : FlavorConfig.instance.geminiApiKey;

  // Legacy helpers for explicit endpoints.
  static String get generateStoryUrl => '$backendUrl/generate-story';
  static String get generateInteractiveStoryUrl =>
      '$backendUrl/generate-interactive-story';
  static String get continueInteractiveStoryUrl =>
      '$backendUrl/continue-interactive-story';
  static String get createCharacterUrl => '$backendUrl/create-character';
  static String get getCharactersUrl => '$backendUrl/get-characters';
}
