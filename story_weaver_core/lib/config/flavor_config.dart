import 'package:flutter/material.dart';

enum Flavor {
  development,
  staging,
  production,
}

class FlavorConfig {
  final Flavor flavor;
  final String backendUrl;

  FlavorConfig._internal({
    required this.flavor,
    required this.backendUrl,
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
          backendUrl: backendUrl,
        );
      case 'staging':
        const stagingBackend =
            'https://story-weaver-staging.up.railway.app';
        final backendUrl = customBackendOverride.isNotEmpty
            ? customBackendOverride
            : stagingBackend;
        return FlavorConfig._internal(
          flavor: Flavor.staging,
          backendUrl: backendUrl,
        );
      default:
        const devBackend = 'http://127.0.0.1:5000';
        final backendUrl = customBackendOverride.isNotEmpty
            ? customBackendOverride
            : devBackend;
        return FlavorConfig._internal(
          flavor: Flavor.development,
          backendUrl: backendUrl,
        );
    }
  }
}
