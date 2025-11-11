class Environment {
  // Toggle this for development vs production
  static const bool isDevelopment = false;

  // Backend URLs
  static const String developmentBackendUrl = 'http://127.0.0.1:5000';
  static const String productionBackendUrl = 'https://story-weaver-app-production.up.railway.app';

  // Get current backend URL
  static String get backendUrl => isDevelopment ? developmentBackendUrl : productionBackendUrl;

  // API endpoints
  static String get generateStoryUrl => '$backendUrl/generate-story';
  static String get generateInteractiveStoryUrl => '$backendUrl/generate-interactive-story';
  static String get continueInteractiveStoryUrl => '$backendUrl/continue-interactive-story';
  static String get createCharacterUrl => '$backendUrl/create-character';
  static String get getCharactersUrl => '$backendUrl/get-characters';
}
