import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/pick_a_path_adventure_screen.dart';
import 'package:story_weaver_app/services/interactive_story_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import '../test/helpers/pick_a_path_test_helpers.dart';

/// Enhanced integration tests for Pick-A-Path Adventures
///
/// Covers Track C requirements:
/// - Maximum depth limits
/// - Choice persistence across app restarts
/// - Branching path navigation
/// - Story state recovery after interruption
///
/// To run: flutter test integration_test/pick_a_path_enhanced_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pick-A-Path: Maximum Depth Limits', () {
    testWidgets('Story does not exceed maximum segment count for short stories',
        (tester) async {
      int segmentCount = 0;
      const maxSegments = 5; // Short story limit

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/generate-interactive-story')) {
          segmentCount = 1;
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson(
              content: 'Segment 1: The adventure begins',
            )),
            200,
          );
        }

        if (request.url.path.contains('/continue-interactive-story')) {
          segmentCount++;

          // Complete story when max segments reached
          final isComplete = segmentCount >= maxSegments;

          return http.Response(
            jsonEncode(PickAPathTestHelpers.createContinueStoryResponseJson(
              segmentNumber: segmentCount,
              content: 'Segment $segmentCount: ${isComplete ? "The End" : "Continue"}',
              isCompleted: isComplete,
              choiceCount: isComplete ? 0 : 2,
            )),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      InteractiveStoryService.setTestClient(mockClient);
      SharedPreferences.setMockInitialValues({});

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Adventure',
            length: 'short',
          ),
        ),
      );

      // Wait for initial story to load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Make choices until story completes or max reached
      while (segmentCount < maxSegments) {
        // Find choice button
        final choiceButton = find.textContaining('Choice').first;
        if (choiceButton.evaluate().isEmpty) break;

        await tester.tap(choiceButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // Verify story completed at max segments
      expect(segmentCount, equals(maxSegments));
      expect(find.textContaining('Adventure Complete'), findsOneWidget);
      expect(find.textContaining('Choice'), findsNothing);

      InteractiveStoryService.setTestClient(null);
    });

    testWidgets('Medium story allows more segments than short story',
        (tester) async {
      int segmentCount = 0;
      const maxSegments = 10; // Medium story limit

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/generate-interactive-story')) {
          segmentCount = 1;
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson()),
            200,
          );
        }

        if (request.url.path.contains('/continue-interactive-story')) {
          segmentCount++;
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createContinueStoryResponseJson(
              segmentNumber: segmentCount,
              isCompleted: segmentCount >= maxSegments,
              choiceCount: segmentCount >= maxSegments ? 0 : 3,
            )),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      InteractiveStoryService.setTestClient(mockClient);
      SharedPreferences.setMockInitialValues({});

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Adventure',
            length: 'medium',
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Make several choices (test first 7 segments)
      for (int i = 0; i < 6; i++) {
        final choiceButton = find.textContaining('Choice').first;
        if (choiceButton.evaluate().isEmpty) break;

        await tester.tap(choiceButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // Verify we progressed beyond short story limit
      expect(segmentCount, greaterThan(5));
      expect(segmentCount, lessThanOrEqualTo(maxSegments));

      InteractiveStoryService.setTestClient(null);
    });
  });

  group('Pick-A-Path: Choice Persistence', () {
    testWidgets('Story ID is persisted to SharedPreferences', (tester) async {
      final mockPrefs = <String, Object>{};
      SharedPreferences.setMockInitialValues(mockPrefs);

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/generate-interactive-story')) {
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson(
              storyId: 'persistent_story_123',
            )),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Adventure',
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify story ID was saved
      final prefs = await SharedPreferences.getInstance();
      final savedStoryId =
          prefs.getString('pick_a_path_story_id_test_user');

      expect(savedStoryId, isNotNull);
      expect(savedStoryId, contains('story'));

      InteractiveStoryService.setTestClient(null);
    });

    testWidgets('Story resumes from saved state after app restart',
        (tester) async {
      const savedStoryId = 'saved_story_456';
      const currentSegment = 3;

      // Simulate saved state
      final mockPrefs = <String, Object>{
        'pick_a_path_story_id_test_user': savedStoryId,
      };
      SharedPreferences.setMockInitialValues(mockPrefs);

      bool resumeWasCalled = false;

      final mockClient = MockClient((request) async {
        // Handle resume request
        if (request.url.path.contains('/interactive-story/$savedStoryId/resume')) {
          resumeWasCalled = true;
          return http.Response(
            jsonEncode({
              'current_segment': {
                'segment_number': currentSegment,
                'content': 'You are back at segment $currentSegment',
                'choices': [
                  {'id': 'choice_1', 'text': 'Continue from here'},
                  {'id': 'choice_2', 'text': 'Make another choice'},
                ],
              },
              'inventory': ['Magic Sword', 'Shield'],
              'state': {
                'current_location': 'Crystal Cave',
                'current_goal': 'Find the treasure',
                'key_clues': ['The cave has two exits'],
                'companion_status': 'Ready',
              },
              'can_continue': true,
              'is_completed': false,
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      InteractiveStoryService.setTestClient(mockClient);

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Adventure',
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify resume was called
      expect(resumeWasCalled, isTrue);

      // Verify UI shows resumed state
      expect(find.textContaining('segment $currentSegment'), findsOneWidget);
      expect(find.textContaining('Continue from here'), findsOneWidget);

      InteractiveStoryService.setTestClient(null);
    });
  });

  group('Pick-A-Path: Branching Path Navigation', () {
    testWidgets('Different choices lead to different story segments',
        (tester) async {
      String? lastChoiceId;
      int segmentCount = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/generate-interactive-story')) {
          segmentCount = 1;
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson(
              content: 'You stand at a crossroads',
              choiceCount: 2,
            )),
            200,
          );
        }

        if (request.url.path.contains('/continue-interactive-story')) {
          final body = jsonDecode(request.body);
          lastChoiceId = body['choice_id'];
          segmentCount++;

          // Different content based on choice
          String content;
          if (lastChoiceId == 'choice_1') {
            content = 'Path 1: You enter a dark cave';
          } else {
            content = 'Path 2: You climb a bright mountain';
          }

          return http.Response(
            jsonEncode(PickAPathTestHelpers.createContinueStoryResponseJson(
              segmentNumber: segmentCount,
              content: content,
              choiceCount: 2,
            )),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      InteractiveStoryService.setTestClient(mockClient);
      SharedPreferences.setMockInitialValues({});

      final character = PickAPathTestHelpers.createTestCharacter();

      // Test Path 1
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user_path1',
            character: character,
            theme: 'Adventure',
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Select first choice
      final choice1 = find.textContaining('Choice 1').first;
      await tester.tap(choice1);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify we're on the cave path
      expect(find.textContaining('dark cave'), findsOneWidget);
      expect(find.textContaining('bright mountain'), findsNothing);

      InteractiveStoryService.setTestClient(null);
    });

    testWidgets('Story maintains branching path integrity across segments',
        (tester) async {
      final choiceHistory = <String>[];
      int segmentCount = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/generate-interactive-story')) {
          segmentCount = 1;
          choiceHistory.clear();
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson()),
            200,
          );
        }

        if (request.url.path.contains('/continue-interactive-story')) {
          final body = jsonDecode(request.body);
          choiceHistory.add(body['choice_id']);
          segmentCount++;

          return http.Response(
            jsonEncode(PickAPathTestHelpers.createContinueStoryResponseJson(
              segmentNumber: segmentCount,
              state: {
                'current_location': 'Segment $segmentCount',
                'current_goal': 'Continue',
                'key_clues': choiceHistory.map((c) => 'Chose $c').toList(),
                'companion_status': 'Active',
              },
            )),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      InteractiveStoryService.setTestClient(mockClient);
      SharedPreferences.setMockInitialValues({});

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Adventure',
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Make 3 choices
      for (int i = 0; i < 3; i++) {
        final choiceButton = find.textContaining('Choice').first;
        await tester.tap(choiceButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // Verify all choices were tracked
      expect(choiceHistory.length, equals(3));
      expect(segmentCount, equals(4)); // Initial + 3 continuations

      InteractiveStoryService.setTestClient(null);
    });
  });

  group('Pick-A-Path: Story State Recovery', () {
    testWidgets('Inventory persists after navigation interruption',
        (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/generate-interactive-story')) {
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson(
              inventory: [
                {'id': 'item1', 'name': 'Magic Wand', 'acquired_at_segment': 1}
              ],
            )),
            200,
          );
        }

        if (request.url.path.contains('/continue-interactive-story')) {
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createContinueStoryResponseJson(
              segmentNumber: 2,
              inventory: [
                {'id': 'item1', 'name': 'Magic Wand', 'acquired_at_segment': 1},
                {'id': 'item2', 'name': 'Golden Key', 'acquired_at_segment': 2},
              ],
            )),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      InteractiveStoryService.setTestClient(mockClient);
      SharedPreferences.setMockInitialValues({});

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Adventure',
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify initial inventory
      await tester.tap(find.textContaining('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('Magic Wand'), findsOneWidget);

      // Make a choice
      await tester.tap(find.textContaining('Choice').first);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify inventory accumulated
      await tester.tap(find.textContaining('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('Magic Wand'), findsOneWidget);
      expect(find.text('Golden Key'), findsOneWidget);

      InteractiveStoryService.setTestClient(null);
    });

    testWidgets('Adventure status updates correctly after recovery',
        (tester) async {
      const initialLocation = 'Forest Entrance';
      const updatedLocation = 'Deep Cave';

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/generate-interactive-story')) {
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson(
              state: {
                'current_location': initialLocation,
                'current_goal': 'Start adventure',
                'key_clues': [],
                'companion_status': 'Ready',
              },
            )),
            200,
          );
        }

        if (request.url.path.contains('/continue-interactive-story')) {
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createContinueStoryResponseJson(
              segmentNumber: 2,
              state: {
                'current_location': updatedLocation,
                'current_goal': 'Find the artifact',
                'key_clues': ['Strange markings on the wall'],
                'companion_status': 'Alert',
              },
            )),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      InteractiveStoryService.setTestClient(mockClient);
      SharedPreferences.setMockInitialValues({});

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Adventure',
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Check initial state
      await tester.tap(find.textContaining('Adventure Status'));
      await tester.pumpAndSettle();
      expect(find.textContaining(initialLocation), findsOneWidget);

      // Make a choice
      await tester.tap(find.textContaining('Choice').first);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify state updated
      await tester.tap(find.textContaining('Adventure Status'));
      await tester.pumpAndSettle();
      expect(find.textContaining(updatedLocation), findsOneWidget);
      expect(find.textContaining('Find the artifact'), findsOneWidget);

      InteractiveStoryService.setTestClient(null);
    });

    testWidgets('Completed story state persists across widget rebuild',
        (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/generate-interactive-story')) {
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createStartStoryResponseJson()),
            200,
          );
        }

        if (request.url.path.contains('/continue-interactive-story')) {
          return http.Response(
            jsonEncode(PickAPathTestHelpers.createContinueStoryResponseJson(
              segmentNumber: 5,
              content: 'The End! You completed the adventure!',
              isCompleted: true,
              choiceCount: 0,
            )),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      InteractiveStoryService.setTestClient(mockClient);
      SharedPreferences.setMockInitialValues({});

      final character = PickAPathTestHelpers.createTestCharacter();
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Adventure',
            length: 'short',
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Complete story
      final choiceButton = find.textContaining('Choice').first;
      await tester.tap(choiceButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify completion state
      expect(find.textContaining('Adventure Complete'), findsOneWidget);
      expect(find.textContaining('Choice'), findsNothing);

      // Rebuild widget
      await tester.pumpWidget(
        MaterialApp(
          home: PickAPathAdventureScreen(
            userId: 'test_user',
            character: character,
            theme: 'Adventure',
            length: 'short',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify completion state still shows
      expect(find.textContaining('Complete'), findsOneWidget);

      InteractiveStoryService.setTestClient(null);
    });
  });
}
