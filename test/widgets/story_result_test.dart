import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/story_result_screen.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/services/offline_story_service.dart';
import 'package:story_weaver_app/models/local/story_local.dart';

class FakeOfflineStoryService extends Fake implements OfflineStoryService {
  @override
  Future<StoryLocal?> getStory(String storyId) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpUntilFound(
    WidgetTester tester, {
    required Finder finder,
    int maxPumps = 40,
    Duration step = const Duration(milliseconds: 100),
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      await tester.pump(step);
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for finder: $finder');
  }

  testWidgets('StoryResultScreen shows story text and wisdom gem',
      (tester) async {
    final story = SavedStory(
      title: 'Test Story',
      storyText: 'Once upon a testing time...',
      theme: 'Adventure',
      characters: [
        Character(
          id: '1',
          name: 'Ava',
          age: 7,
          role: 'Hero',
          likes: const [],
          dislikes: const [],
          fears: const [],
          strengths: const [],
          personalityTraits: const [],
          personalitySliders: const {},
        ),
      ],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryResultScreen(
          title: story.title,
          storyText: story.storyText,
          wisdomGem: 'Be kind and curious.',
          characterName: story.characters.first.name,
          storyId: story.id,
          trackStoryCreation: false, // Disable achievement tracking in test
          trackAnalytics: false, // Disable analytics tracking in test
          offlineService: FakeOfflineStoryService(),
        ),
      ),
    );

    // Wait for first story content frame without relying on full settle.
    await pumpUntilFound(
      tester,
      finder: find.textContaining('Once upon a testing time'),
      maxPumps: 50,
      step: const Duration(milliseconds: 100),
    );

    expect(find.text('Test Story'), findsOneWidget);
    expect(find.textContaining('Once upon a testing time'), findsOneWidget);
    // wisdom_chip removed — stories now end without a lesson overlay
    expect(find.byKey(const Key('wisdom_chip')), findsNothing);
  });

    testWidgets('StoryResultScreen hides wisdom chip when wisdom text is empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoryResultScreen(
          title: 'No Wisdom Story',
          storyText: 'A tiny test story.',
          wisdomGem: '',
          characterName: 'Ava',
          storyId: 'story_no_wisdom',
          trackStoryCreation: false,
          trackAnalytics: false,
          offlineService: FakeOfflineStoryService(),
        ),
      ),
    );

    await pumpUntilFound(
      tester,
      finder: find.textContaining('A tiny test story'),
      maxPumps: 40,
      step: const Duration(milliseconds: 100),
    );

    expect(find.textContaining('A tiny test story'), findsOneWidget);
    expect(find.byKey(const Key('wisdom_chip')), findsNothing);
    });
}
