import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/story_result_screen.dart';
import 'package:story_weaver_app/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StoryResultScreen shows story text and wisdom gem', (tester) async {
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
        ),
      ),
    );

    // Allow async operations to complete
    await tester.pump();

    expect(find.text('Test Story'), findsOneWidget);
    expect(find.textContaining('Once upon a testing time'), findsOneWidget);
    expect(find.textContaining('Be kind and curious'), findsOneWidget);
  });
}
