import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/pick_a_path_adventure_screen.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/services/interactive_story_service.dart';
import 'package:story_weaver_app/widgets/app_button.dart';
import 'package:story_weaver_app/widgets/error_message.dart';
import '../helpers/pick_a_path_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    // Clean up test client after each test
    InteractiveStoryService.setTestClient(null);
  });

  group('PickAPathAdventureScreen - Loading State', () {
    testWidgets('G1: Shows loading spinner when story is generating', (tester) async {
      final mockClient = MockClient((request) async {
        // Simulate slow response
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson()),
          200,
        );
      });

      // Inject mock client
      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      // Initially should show loading
      expect(find.text('Weaving your adventure...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for story to load
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Loading should be gone, story should be visible
      expect(find.text('Weaving your adventure...'), findsNothing);
    });

    testWidgets('G1: Shows correct app bar title', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson(
            title: 'Pick-A-Path Adventure'
          )),
          200,
        );
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for app bar title
      expect(find.text('Pick-A-Path Adventure'), findsOneWidget);
    });
  });

  group('PickAPathAdventureScreen - Initial Segment Display', () {
    testWidgets('G2: Displays first segment with story content', (tester) async {
      final responseJson = PickAPathTestHelpers.createStartStoryResponseJson(
        content: 'You stand at the edge of the Enchanted Forest.',
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responseJson), 200);
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
            length: 'short',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check story content is displayed
      expect(find.text('You stand at the edge of the Enchanted Forest.'), findsOneWidget);

      // Check progress indicator
      // StorybookProgressIndicator uses 'Wake Up!' for page 1 by default
      expect(find.textContaining('Wake Up!'), findsOneWidget);

      // Check choice buttons exist
      expect(find.textContaining('Choice 1'), findsOneWidget);
      expect(find.textContaining('Choice 2'), findsOneWidget);
    });

    testWidgets('G2: Shows correct number of choices for short story', (tester) async {
      final responseJson = PickAPathTestHelpers.createStartStoryResponseJson(
        choiceCount: 2,
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responseJson), 200);
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
            length: 'short',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have 2 choices for short story
      expect(find.textContaining('Choice 1'), findsOneWidget);
      expect(find.textContaining('Choice 2'), findsOneWidget);
      expect(find.textContaining('Choice 3'), findsNothing);
    });

    testWidgets('H1: Shows 3 choices for medium story', (tester) async {
      final responseJson = PickAPathTestHelpers.createStartStoryResponseJson(
        choiceCount: 3,
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responseJson), 200);
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
            length: 'medium',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have 3 choices for medium story
      expect(find.textContaining('Choice 1'), findsOneWidget);
      expect(find.textContaining('Choice 2'), findsOneWidget);
      expect(find.textContaining('Choice 3'), findsOneWidget);
    });

    testWidgets('H2: Shows 4 choices for long story', (tester) async {
      final responseJson = PickAPathTestHelpers.createStartStoryResponseJson(
        choiceCount: 4,
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responseJson), 200);
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
            length: 'long',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have 4 choices for long story
      expect(find.textContaining('Choice 1'), findsOneWidget);
      expect(find.textContaining('Choice 2'), findsOneWidget);
      expect(find.textContaining('Choice 3'), findsOneWidget);
      expect(find.textContaining('Choice 4'), findsOneWidget);
    });
  });

  group('PickAPathAdventureScreen - Inventory Section', () {
    testWidgets('G7: Updates inventory when items are added', (tester) async {
      final startResponse = PickAPathTestHelpers.createStartStoryResponseJson(
        inventory: [
           {'id': 'item_000', 'name': 'Old Map', 'acquired_at_segment': 1}
        ],
      );

      final continueResponse = PickAPathTestHelpers.createContinueStoryResponseJson(
        inventory: [
          {'id': 'item_000', 'name': 'Old Map', 'acquired_at_segment': 1},
          {
            'id': 'item_001',
            'name': 'Magic Compass',
            'description': 'A compass that points to adventure',
            'acquired_at_segment': 2,
          }
        ],
      );

      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(jsonEncode(startResponse), 200);
        } else {
          return http.Response(jsonEncode(continueResponse), 200);
        }
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Make a choice
      final choiceButton = find.textContaining('Choice 1').first;
      await tester.tap(choiceButton);
      await tester.pumpAndSettle();

      // Expand inventory
      await tester.tap(find.textContaining('Inventory'));
      await tester.pumpAndSettle();

      // Check inventory updated
      expect(find.text('Magic Compass'), findsOneWidget);
      expect(find.textContaining('Inventory (2)'), findsOneWidget);
    });
  });

  group('PickAPathAdventureScreen - Adventure Status Section', () {
    testWidgets('G4: Displays adventure status section', (tester) async {
      final responseJson = PickAPathTestHelpers.createStartStoryResponseJson(
        content: 'Different content to avoid duplicate text finders',
        state: {
          'current_location': 'Enchanted Forest',
          'current_goal': 'Find the lost treasure',
          'key_clues': [],
          'companion_status': 'Your companion is ready',
        },
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responseJson), 200);
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expand section
      await tester.tap(find.textContaining('Adventure Status'));
      await tester.pumpAndSettle();

      // Check status section exists
      expect(find.textContaining('Adventure Status'), findsOneWidget);
      expect(find.textContaining('Enchanted Forest'), findsOneWidget);
      expect(find.textContaining('Find the lost treasure'), findsOneWidget);
    });

    testWidgets('G8: Updates adventure status after choice', (tester) async {
      final startResponse = PickAPathTestHelpers.createStartStoryResponseJson(
        content: 'Start content',
        state: {
          'current_location': 'Forest Edge',
          'current_goal': 'Begin adventure',
          'key_clues': [],
          'companion_status': 'companion',
        },
      );

      final continueResponse = PickAPathTestHelpers.createContinueStoryResponseJson(
        content: 'Continued content',
        state: {
          'current_location': 'Deep Forest',
          'current_goal': 'Continue adventure',
          'key_clues': ['The path leads north'],
          'companion_status': 'Your companion is alert',
        },
      );

      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(jsonEncode(startResponse), 200);
        } else {
          return http.Response(jsonEncode(continueResponse), 200);
        }
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Make a choice
      final choiceButton = find.textContaining('Choice 1').first;
      await tester.tap(choiceButton);
      await tester.pumpAndSettle();

      // Expand section
      await tester.tap(find.textContaining('Adventure Status'));
      await tester.pumpAndSettle();

      // Check status updated
      expect(find.textContaining('Deep Forest'), findsOneWidget);
      expect(find.textContaining('Continue adventure'), findsOneWidget);
    });
  });

  group('PickAPathAdventureScreen - Choice Selection', () {
    testWidgets('G5: Shows loading state when choice is selected', (tester) async {
      final startResponse = PickAPathTestHelpers.createStartStoryResponseJson();
      final continueResponse = PickAPathTestHelpers.createContinueStoryResponseJson();

      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(jsonEncode(startResponse), 200);
        } else {
          // Simulate slow response
          await Future.delayed(const Duration(milliseconds: 500));
          return http.Response(jsonEncode(continueResponse), 200);
        }
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Make a choice
      final choiceButton = find.textContaining('Choice 1').first;
      await tester.tap(choiceButton);
      await tester.pump(const Duration(milliseconds: 100));

      // Should show loading state (Implementation uses _isContinuing to disable buttons)
      final buttons = tester.widgetList<AppButton>(find.byType(AppButton));
      for (var button in buttons) {
        expect(button.onPressed, isNull);
      }
      
      // Clean up timer
      await tester.pumpAndSettle();
    });

    testWidgets('G6: Displays next segment after choice', (tester) async {
      final startResponse = PickAPathTestHelpers.createStartStoryResponseJson(
        content: 'First segment content',
      );
      final continueResponse = PickAPathTestHelpers.createContinueStoryResponseJson(
        content: 'Second segment content',
        segmentNumber: 2,
      );

      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(jsonEncode(startResponse), 200);
        } else {
          return http.Response(jsonEncode(continueResponse), 200);
        }
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify first segment
      expect(find.text('First segment content'), findsOneWidget);
      // StorybookProgressIndicator uses 'Wake Up!' for page 1 by default
      expect(find.textContaining('Wake Up!'), findsOneWidget);

      // Make a choice
      final choiceButton = find.textContaining('Choice 1').first;
      await tester.tap(choiceButton);
      await tester.pumpAndSettle();

      // Verify second segment
      expect(find.text('Second segment content'), findsOneWidget);
      // StorybookProgressIndicator uses 'Play Time!' for page 2 by default
      expect(find.textContaining('Play Time!'), findsOneWidget);
      // First segment should not be visible (only current segment shown)
      expect(find.text('First segment content'), findsNothing);
    });
  });

  group('PickAPathAdventureScreen - Story Completion', () {
    testWidgets('G9: Shows completion UI when story ends', (tester) async {
      final startResponse = PickAPathTestHelpers.createStartStoryResponseJson();
      final continueResponse = PickAPathTestHelpers.createContinueStoryResponseJson(
        isCompleted: true,
        content: 'The adventure comes to an end.',
      );

      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(jsonEncode(startResponse), 200);
        } else {
          return http.Response(jsonEncode(continueResponse), 200);
        }
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
            length: 'short',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Make a choice to complete the story
      final choiceButton = find.textContaining('Choice 1').first;
      await tester.tap(choiceButton);
      await tester.pumpAndSettle();

      // Check completion indicators
      expect(find.textContaining('Adventure Complete'), findsOneWidget);
      // No choice buttons should be visible
      expect(find.textContaining('Choice 1'), findsNothing);
    });

    testWidgets('G10: Shows save button on completion', (tester) async {
      final startResponse = PickAPathTestHelpers.createStartStoryResponseJson();
      final continueResponse = PickAPathTestHelpers.createContinueStoryResponseJson(
        isCompleted: true,
      );

      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(jsonEncode(startResponse), 200);
        } else {
          return http.Response(jsonEncode(continueResponse), 200);
        }
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
            length: 'short',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Make a choice to complete
      final choiceButton = find.textContaining('Choice 1').first;
      await tester.tap(choiceButton);
      await tester.pumpAndSettle();

      // Check for save button
      expect(find.textContaining('Save'), findsOneWidget);
    });
  });

  group('PickAPathAdventureScreen - Error Handling', () {
    testWidgets('I1: Shows error message on network failure during generation', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response('Network error', 500);
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show error message from ErrorMessage component
      expect(find.byType(ErrorMessage), findsOneWidget);
      // Should show retry button label
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('I2: Shows error message on network failure during choice', (tester) async {
      final startResponse = PickAPathTestHelpers.createStartStoryResponseJson();

      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(jsonEncode(startResponse), 200);
        } else {
          return http.Response('Network error', 500);
        }
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Make a choice that will fail
      final choiceButton = find.textContaining('Choice 1').first;
      await tester.tap(choiceButton);
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.byType(ErrorMessage), findsOneWidget);
      expect(find.textContaining('Unable to continue'), findsOneWidget);
    });
  });

  group('PickAPathAdventureScreen - Age-Appropriate Content', () {
    testWidgets('H3: Age 5 shows simple content', (tester) async {
      final responseJson = PickAPathTestHelpers.createStartStoryResponseJson(
        content: PickAPathTestHelpers.createAgeAppropriateContent(5, 1),
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responseJson), 200);
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter(age: 5);
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Content should be simple
      expect(find.textContaining('big tree'), findsOneWidget);
    });

    testWidgets('H4: Age 14 shows complex content', (tester) async {
      final responseJson = PickAPathTestHelpers.createStartStoryResponseJson(
        content: PickAPathTestHelpers.createAgeAppropriateContent(14, 1),
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responseJson), 200);
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter(age: 14);
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Magic',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Content should be more complex
      expect(find.textContaining('ethereal'), findsOneWidget);
    });
  });
}
