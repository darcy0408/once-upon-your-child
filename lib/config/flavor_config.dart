import 'package:flutter/material.dart';

enum Flavor {
  development,
  staging,
  production,
}

/// Holds configuration for each build flavor. Values are selected at runtime
/// using `--dart-define=FLAVOR=...` when launching Flutter.
class FlavorConfig {
  final Flavor flavor;
  final String name;
  final String backendUrl;
  final Color primaryColor;
  final String bannerLabel;
  final Color bannerColor;
  final String geminiApiKey;

  bool get showBanner => bannerLabel.isNotEmpty;

  FlavorConfig._internal({
    required this.flavor,
    required this.name,
    required this.backendUrl,
    required this.primaryColor,
    required this.bannerLabel,
    required this.bannerColor,
    required this.geminiApiKey,
  });

  static FlavorConfig? _instance;

  static FlavorConfig get instance => _instance ??= _buildConfig();

  static FlavorConfig _buildConfig() {
    const flavorString = String.fromEnvironment(
      'FLAVOR',
      defaultValue: 'development',
    );
    const customBackendOverride = String.fromEnvironment(
      'CUSTOM_BACKEND_URL',
      defaultValue: '',
    );

    switch (flavorString) {
      case 'production':
        const defaultBackend =
            'https://story-weaver-app-production.up.railway.app';
        final backendUrl = customBackendOverride.isNotEmpty
            ? customBackendOverride
            : defaultBackend;
        return FlavorConfig._internal(
          flavor: Flavor.production,
          name: 'Story Weaver',
          backendUrl: backendUrl,
          primaryColor: Colors.deepPurple,
          bannerLabel: '',
          bannerColor: Colors.transparent,
          geminiApiKey: const String.fromEnvironment(
            'PROD_GEMINI_API_KEY',
            defaultValue: '',
          ),
        );
      case 'staging':
        const stagingBackend =
            'https://story-weaver-staging.up.railway.app';
        final backendUrl = customBackendOverride.isNotEmpty
            ? customBackendOverride
            : stagingBackend;
        return FlavorConfig._internal(
          flavor: Flavor.staging,
          name: 'Story Weaver (Staging)',
          backendUrl: backendUrl,
          primaryColor: Colors.orange,
          bannerLabel: 'STAGING',
          bannerColor: Colors.deepOrange,
          geminiApiKey: const String.fromEnvironment(
            'STAGING_GEMINI_API_KEY',
            defaultValue: '',
          ),
        );
      default:
        const devBackend = 'http://127.0.0.1:5000';
        final backendUrl = customBackendOverride.isNotEmpty
            ? customBackendOverride
            : devBackend;
        return FlavorConfig._internal(
          flavor: Flavor.development,
          name: 'Story Weaver (Dev)',
          backendUrl: backendUrl,
          primaryColor: Colors.green.shade700,
          bannerLabel: 'DEV',
          bannerColor: Colors.green.shade800,
          geminiApiKey: const String.fromEnvironment(
            'DEV_GEMINI_API_KEY',
            defaultValue: '',
          ),
        );
    }
  }
}
