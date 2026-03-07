import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/services/avatar_service.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvatarService Asset Loading', () {
    late AvatarService avatarService;

    setUp(() {
      avatarService = AvatarService();
    });

    test('initialize loads assets correctly', () async {
      // This will fail if the assets are not found in the test environment
      // We need to mock the rootBundle or ensure the assets are accessible
      
      // Attempt to initialize
      try {
        await avatarService.initialize();
        print('✅ AvatarService initialized successfully');
      } catch (e) {
        print('❌ Failed to initialize AvatarService: $e');
        rethrow;
      }
    });
  });
}
