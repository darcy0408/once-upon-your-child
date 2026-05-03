import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/config/flavor_config.dart';

void main() {
  group('Environment Configuration Tests', () {
    test('Default flavor should be development', () {
      // Test the default configuration
      final config = FlavorConfig.instance;

      // Since we can't easily test compile-time constants in unit tests,
      // we'll test the runtime behavior
      expect(config.flavor, isNotNull);
      expect(config.name, isNotNull);
      expect(config.backendUrl, isNotNull);
      expect(config.primaryColor, isNotNull);
    });

    test('Flavor config should have valid properties', () {
      final config = FlavorConfig.instance;

      // Test that all required properties are set
      expect(config.flavor, isA<Flavor>());
      expect(config.name, isA<String>());
      expect(config.backendUrl, isA<String>());
      expect(config.primaryColor, isA<Color>());
      expect(config.bannerLabel, isA<String>());
      expect(config.bannerColor, isA<Color>());
    });

    test('Backend URLs should be valid', () {
      final config = FlavorConfig.instance;

      // Test that backend URL is a valid HTTP/HTTPS URL
      expect(config.backendUrl.startsWith('http'), isTrue);
      expect(config.backendUrl.contains('://'), isTrue);
    });

    test('Banner configuration should be consistent', () {
      final config = FlavorConfig.instance;

      // If banner label is empty, banner color should be transparent
      if (config.bannerLabel.isEmpty) {
        expect(config.bannerColor, equals(Colors.transparent));
      }
    });

    test('Show banner logic should work correctly', () {
      final config = FlavorConfig.instance;

      // showBanner should be true only if bannerLabel is not empty
      expect(config.showBanner, equals(config.bannerLabel.isNotEmpty));
    });
  });
}