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
  final String sentryDsn;

  bool get showBanner => bannerLabel.isNotEmpty;

  FlavorConfig._internal({
    required this.flavor,
    required this.name,
    required this.backendUrl,
    required this.primaryColor,
    required this.bannerLabel,
    required this.bannerColor,
    required this.sentryDsn,
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
          name: 'Once Upon YOUR Child',
          backendUrl: backendUrl,
          primaryColor: Colors.deepPurple,
          bannerLabel: '',
          bannerColor: Colors.transparent,
          sentryDsn: const String.fromEnvironment(
            'SENTRY_DSN',
            defaultValue:
                'https://56313041925cdc0d25e6f83dd9f5529b@o4510948068491264.ingest.us.sentry.io/4510948091559936',
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
          name: 'Once Upon YOUR Child (Staging)',
          backendUrl: backendUrl,
          primaryColor: Colors.orange,
          bannerLabel: 'STAGING',
          bannerColor: Colors.deepOrange,
          sentryDsn: const String.fromEnvironment(
            'SENTRY_DSN',
            defaultValue:
                'https://56313041925cdc0d25e6f83dd9f5529b@o4510948068491264.ingest.us.sentry.io/4510948091559936',
          ),
        );
      default:
        // Default to local backend for development.
        // For real-device testing use:
        //   --dart-define=CUSTOM_BACKEND_URL=https://story-weaver-app-production.up.railway.app
        const String devBackend = 'http://127.0.0.1:5000';

        final backendUrl = customBackendOverride.isNotEmpty
            ? customBackendOverride
            : devBackend;
        return FlavorConfig._internal(
          flavor: Flavor.development,
          name: 'Once Upon YOUR Child (Dev)',
          backendUrl: backendUrl,
          primaryColor: Colors.green.shade700,
          bannerLabel: 'DEV',
          bannerColor: Colors.green.shade800,
          sentryDsn: const String.fromEnvironment(
            'SENTRY_DSN',
            defaultValue:
                'https://56313041925cdc0d25e6f83dd9f5529b@o4510948068491264.ingest.us.sentry.io/4510948091559936',
          ),
        );
    }
  }
}
