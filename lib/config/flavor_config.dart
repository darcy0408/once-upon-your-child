import 'package:flutter/material.dart';

enum Flavor {
  development,
  staging,
  production,
}

class FlavorConfig {
  final Flavor flavor;
  final String name;
  final String backendUrl;
  final Color primaryColor;

  FlavorConfig._internal({
    required this.flavor,
    required this.name,
    required this.backendUrl,
    required this.primaryColor,
  });

  static FlavorConfig? _instance;

  static FlavorConfig get instance => _instance ??= _buildConfig();

  static FlavorConfig _buildConfig() {
    const flavorString = String.fromEnvironment(
      'FLAVOR',
      defaultValue: 'development',
    );

    switch (flavorString) {
      case 'production':
        return FlavorConfig._internal(
          flavor: Flavor.production,
          name: 'Story Weaver',
          backendUrl: 'https://story-weaver-app-production.up.railway.app',
          primaryColor: Colors.deepPurple,
        );
      case 'staging':
        return FlavorConfig._internal(
          flavor: Flavor.staging,
          name: 'Story Weaver (Staging)',
          backendUrl: 'https://story-weaver-staging.up.railway.app',
          primaryColor: Colors.orange,
        );
      default:
        return FlavorConfig._internal(
          flavor: Flavor.development,
          name: 'Story Weaver (Dev)',
          backendUrl: 'http://127.0.0.1:5000',
          primaryColor: Colors.green,
        );
    }
  }
}
