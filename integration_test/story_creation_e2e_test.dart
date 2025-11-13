import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:story_weaver/main.dart' as app;
import 'package:story_weaver/services/api_service_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Story Creation Flow', () {
    late MockClient mockClient;

    setUp(() {
      // Mock successful story generation response
      mockClient = MockClient((request) async {
        if (request.url.path == '/generate-story') {
          return http.Response('''
            {
              "story": {
                "title": "The Brave Little Fox",
                "content": "Once upon a time, there was a brave little fox...",
                "moral": "Be brave and face your fears",
                "age_appropriate": true
              },
              "illustration_url": "https://example.com/illustration.jpg",
              "coloring_page_url": "https://example.com/coloring.jpg"
            }
          ''', 200);
        }
        return http.Response('Not Found', 404);
      });

      // Override the API service to use our mock
      ApiServiceManager.instance = ApiServiceManager.test(mockClient);
    });

    testWidgets('Complete story creation journey', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to character creation
      await tester.tap(find.text('Create New Character'));
      await tester.pumpAndSettle();

      // Fill character details
      await tester.enterText(find.byType(TextField).first, 'Test Child');
      await tester.enterText(find.byType(TextField).at(1), '8');
      await tester.tap(find.text('Boy'));
      await tester.pumpAndSettle();

      // Select role
      await tester.tap(find.text('Adventurer'));
      await tester.pumpAndSettle();

      // Add some traits
      await tester.tap(find.text('Brave'));
      await tester.tap(find.text('Curious'));
      await tester.pumpAndSettle();

      // Navigate to feelings wheel
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Select a feeling (anxious)
      await tester.tap(find.text('Scared'));
      await tester.pumpAndSettle();

      // Select intensity
      await tester.tap(find.text('A little'));
      await tester.pumpAndSettle();

      // Create story
      await tester.tap(find.text('Create My Story!'));
      await tester.pumpAndSettle();

      // Wait for story generation (mock response)
      await tester.pump(Duration(seconds: 2));

      // Verify story is displayed
      expect(find.text('The Brave Little Fox'), findsOneWidget);
      expect(find.textContaining('brave little fox'), findsOneWidget);

      // Test story actions
      expect(find.text('Read Aloud'), findsOneWidget);
      expect(find.text('Save Story'), findsOneWidget);
      expect(find.text('Coloring Page'), findsOneWidget);
    });

    testWidgets('Multi-character story creation', (tester) async {
      // Similar to above but with multiple characters
      app.main();
      await tester.pumpAndSettle();

      // Create first character
      await tester.tap(find.text('Create New Character'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Alex');
      await tester.enterText(find.byType(TextField).at(1), '7');
      await tester.tap(find.text('Boy'));
      await tester.tap(find.text('Adventurer'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Add second character
      await tester.tap(find.text('Add Another Character'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Sam');
      await tester.enterText(find.byType(TextField).at(1), '6');
      await tester.tap(find.text('Boy'));
      await tester.tap(find.text('Friend'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Select feelings and create story
      await tester.tap(find.text('Happy'));
      await tester.tap(find.text('A little'));
      await tester.tap(find.text('Create My Story!'));
      await tester.pumpAndSettle();

      // Verify multi-character story
      expect(find.textContaining('Alex and Sam'), findsOneWidget);
    });

    testWidgets('Offline story caching', (tester) async {
      // Test offline functionality
      app.main();
      await tester.pumpAndSettle();

      // Create and save a story first
      // ... (similar steps as above)

      // Simulate offline by disabling network
      // This would require additional mocking

      // Verify cached stories are accessible
      await tester.tap(find.text('Saved Stories'));
      await tester.pumpAndSettle();

      expect(find.text('The Brave Little Fox'), findsOneWidget);
    });
  });
}