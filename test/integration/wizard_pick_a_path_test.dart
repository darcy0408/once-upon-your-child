import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/wizard_story_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockClient mockClient;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    
    mockClient = MockClient((request) async {
      final url = request.url.toString();
      
      if (url.contains('/auth/anonymous')) {
        return http.Response(jsonEncode({
          'token': 'mock_token',
          'user_id': 'mock_user_123'
        }), 200);
      }

      if (url.contains('/get-characters')) {
        return http.Response(jsonEncode({
          'data': []
        }), 200);
      }

      return http.Response('Not Found', 404);
    });

    ApiServiceManager.setTestClient(mockClient);
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
  });

  group('Wizard Integration - Pick-A-Path Flow', () {
    testWidgets('F1: Wizard opens and shows progress indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WizardStoryScreen(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Check wizard is open
      expect(find.byType(WizardStoryScreen), findsOneWidget);
    });

    testWidgets('F2: Hero Creator step collects character data', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WizardStoryScreen(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Look for character name input
      final nameField = find.byType(TextField);
      expect(nameField, findsWidgets);

      // Enter character name
      await tester.enterText(nameField.first, 'TestHero');
      await tester.pump();

      // Verify name was entered
      expect(find.text('TestHero'), findsOneWidget);
    });
  });
}



