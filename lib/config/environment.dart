import 'flavor_config.dart';

class Environment {
  static String get backendUrl => FlavorConfig.instance.backendUrl;
  static bool get isProduction =>
      FlavorConfig.instance.flavor == Flavor.production;
  static String get appName => FlavorConfig.instance.name;

  // Legacy helpers for explicit endpoints.
  static String get generateStoryUrl => '$backendUrl/generate-story';
  static String get generateInteractiveStoryUrl =>
      '$backendUrl/generate-interactive-story';
  static String get continueInteractiveStoryUrl =>
      '$backendUrl/continue-interactive-story';
  static String get createCharacterUrl => '$backendUrl/create-character';
  static String get getCharactersUrl => '$backendUrl/get-characters';
}
