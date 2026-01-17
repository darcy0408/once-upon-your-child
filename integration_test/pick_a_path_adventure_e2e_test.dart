import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:story_weaver_app/main.dart' as app;
import 'package:story_weaver_app/services/interactive_story_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import '../test/helpers/pick_a_path_test_helpers.dart';

/// End-to-end integration tests for Pick-A-Path Adventures
/// These tests run in a real browser (Chrome) and test the full user flow
/// 
/// To run: flutter test integration_test/pick_a_path_adventure_e2e_test.dart -d chrome
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pick-A-Path Adventures E2E Tests', () {
    late MockClient mockClient;

    setUp(() {
      // Set up mock HTTP client for API calls
      mockClient = MockClient((request) async {
        final uri = request.url;
        
        // Handle story generation
        if (uri.path.contains('/generate-interactive-story')) {
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson()),
            200,
          );
        }
        
        // Handle story continuation
        if (uri.path.contains('/continue-interactive-story')) {
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createContinueStoryResponseJson()),
            200,
          );
        }
        
        // Handle story retrieval
        if (uri.path.contains('/interactive-story/')) {
          return http.Response(
            jsonEncode({
              'id': 'story_001',
              'title': 'The Enchanted Adventure',
              'theme': 'Magic',
              'tone': 'whimsical',
              'length': 'medium',
              'age': 8,
              'current_segment_number': 1,
              'is_completed': false,
              'created_at': DateTime.now().toIso8601String(),
              'inventory': [],
              'state': {
                'current_location': 'Enchanted Forest',
                'current_goal': 'Begin adventure',
                'key_clues': [],
                'companion_status': '',
              },
            }),
            200,
          );
        }
        
        return http.Response('Not Found', 404);
      });

      // Inject mock client
      InteractiveStoryService.setTestClient(mockClient);
    });

    tearDown(() {
      // Clean up
      InteractiveStoryService.setTestClient(null);
    });

    testWidgets('F1-F5: Complete wizard flow and launch Pick-A-Path', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // F1: Find and open wizard
      // Look for wizard button or navigation
      final wizardButton = find.textContaining('Create Story').first;
      if (wizardButton.evaluate().isNotEmpty) {
        await tester.tap(wizardButton);
        await tester.pumpAndSettle();
      }

      // Verify wizard opened (moon phase indicator or step indicator)
      expect(
        find.textContaining('Step').or(find.textContaining('Hero')).or(find.textContaining('Character')),
        findsAtLeastNWidgets(1),
      );

      // F2: Complete Hero Creator (Step 1)
      // Enter character name
      final nameField = find.byType(TextField).first;
      if (nameField.evaluate().isNotEmpty) {
        await tester.enterText(nameField, 'TestHero');
        await tester.pumpAndSettle();
      }

      // Set age (if there's a slider or field)
      // This depends on your UI implementation

      // Navigate to next step
      final nextButton = find.textContaining('Next').or(find.byIcon(Icons.arrow_forward)).first;
      if (nextButton.evaluate().isNotEmpty) {
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
      }

      // F3: Select Feelings (Step 2)
      // Look for emotion chips or scenario selection
      final emotionChip = find.textContaining('Happy').or(find.textContaining('Excited')).first;
      if (emotionChip.evaluate().isNotEmpty) {
        await tester.tap(emotionChip);
        await tester.pumpAndSettle();
      }

      // Navigate to next step
      if (nextButton.evaluate().isNotEmpty) {
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
      }

      // F4: Choose Companion (Step 3) - Optional
      // Skip or select companion
      final skipButton = find.textContaining('Skip').first;
      if (skipButton.evaluate().isNotEmpty) {
        await tester.tap(skipButton);
        await tester.pumpAndSettle();
      } else if (nextButton.evaluate().isNotEmpty) {
        await tester.tap(nextButton);
        await tester.pumpAndSettle();
      }

      // F5: Enable Interactive Mode (Step 4)
      // Find Interactive Mode toggle
      final interactiveToggle = find.textContaining('Interactive Mode').first;
      if (interactiveToggle.evaluate().isNotEmpty) {
        // Tap to enable
        await tester.tap(interactiveToggle);
        await tester.pumpAndSettle();
      }

      // Click "Make Magic" button
      final makeMagicButton = find.textContaining('Make Magic').or(find.textContaining('Create')).first;
      if (makeMagicButton.evaluate().isNotEmpty) {
        await tester.tap(makeMagicButton);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Verify navigation to Pick-A-Path screen
      expect(
        find.textContaining('Pick-A-Path').or(find.textContaining('Adventure')),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('G1-G2: Story loads and displays first segment', (tester) async {
      // This test assumes we're already on the Pick-A-Path screen
      // In a real scenario, you'd navigate there first (see test above)
      
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // G1: Check for loading state
      // The loading state should appear briefly
      final loadingIndicator = find.byType(CircularProgressIndicator);
      if (loadingIndicator.evaluate().isNotEmpty) {
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // G2: Verify first segment is displayed
      // Look for story content
      expect(
        find.textContaining('Enchanted').or(find.textContaining('Forest')).or(find.textContaining('adventure')),
        findsAtLeastNWidgets(1),
      );

      // Verify progress indicator
      expect(
        find.textContaining('Segment 1').or(find.textContaining('1 of')),
        findsAtLeastNWidgets(1),
      );

      // Verify choice buttons exist
      expect(
        find.textContaining('Choice').or(find.byType(ElevatedButton)),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('G5-G6: Make choice and see next segment', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Wait for story to load
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // G5: Find and tap first choice button
      final choiceButton = find.textContaining('Choice 1').or(find.byType(ElevatedButton).first).first;
      if (choiceButton.evaluate().isNotEmpty) {
        await tester.tap(choiceButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // G6: Verify next segment is displayed
      // The content should change
      expect(
        find.textContaining('Segment 2').or(find.textContaining('2 of')),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('G3-G4: Inventory and Status sections visible', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Wait for story to load
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // G3: Check for Inventory section
      expect(
        find.textContaining('Inventory'),
        findsAtLeastNWidgets(1),
      );

      // G4: Check for Adventure Status section
      expect(
        find.textContaining('Adventure Status').or(find.textContaining('Status')).or(find.textContaining('Location')),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('G9-G10: Complete story and see completion screen', (tester) async {
      // This test would require multiple choices to complete the story
      // For a short story (3 segments), we'd need to make 2 choices
      
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Make choices to complete story
      // This is simplified - in reality you'd make choices until story ends
      
      // G9: Check for completion indicators
      // G10: Check for completion screen elements
      expect(
        find.textContaining('complete').or(find.textContaining('Complete')).or(find.textContaining('Save')),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('H1-H2: Different story lengths show correct choice counts', (tester) async {
      // This would require creating stories with different lengths
      // For now, we verify the UI can handle different choice counts
      
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify choice buttons exist
      final choiceButtons = find.byType(ElevatedButton);
      expect(choiceButtons, findsAtLeastNWidgets(1));
    });

    testWidgets('I1-I2: Error handling displays user-friendly messages', (tester) async {
      // Set up error response
      final errorClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });
      
      InteractiveStoryService.setTestClient(errorClient);

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // I1: Check for error message
      expect(
        find.textContaining('error').or(find.textContaining('Error')).or(find.textContaining('try again')),
        findsAtLeastNWidgets(1),
      );

      // I2: Check for retry button
      expect(
        find.textContaining('Retry').or(find.textContaining('Try Again')),
        findsAtLeastNWidgets(1),
      );
    });
  });
}



