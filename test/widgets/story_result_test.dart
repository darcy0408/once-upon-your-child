import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/story_result_screen.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/services/offline_story_service.dart';
import 'package:story_weaver_app/models/local/story_local.dart';
import 'package:story_weaver_app/widgets/open_book_frame.dart';

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
      // StoryResultScreen is now a ConsumerStatefulWidget — it needs a
      // ProviderScope ancestor.
      ProviderScope(
        child: MaterialApp(
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
      ProviderScope(
        child: MaterialApp(
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

  // MT-381(b): _effectiveAge must not collapse to the age-7 kid flip-book
  // when the character fetch is unavailable. OpenBookFrame only exists in
  // the flip-book branch, so its absence proves the >=11 reader rendered.
  Future<void> pumpResultScreen(
    WidgetTester tester, {
    int? characterAge,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StoryResultScreen(
            title: 'Band Story',
            storyText: 'A band-resolution test story.',
            characterName: 'Ava',
            storyId: 'story_band',
            characterAge: characterAge,
            trackStoryCreation: false,
            trackAnalytics: false,
            offlineService: FakeOfflineStoryService(),
          ),
        ),
      ),
    );
    await pumpUntilFound(
      tester,
      finder: find.textContaining('A band-resolution test story'),
      maxPumps: 40,
      step: const Duration(milliseconds: 100),
    );
  }

  testWidgets('caller-passed teen age gets the reader, not the flip-book',
      (tester) async {
    await pumpResultScreen(tester, characterAge: 15);
    expect(find.byType(OpenBookFrame), findsNothing);
  });

  testWidgets('with no age anywhere the age-7 flip-book remains the default',
      (tester) async {
    await pumpResultScreen(tester);
    expect(find.byType(OpenBookFrame), findsOneWidget);
  });

  testWidgets('user_age pref alone is enough to give a teen the reader',
      (tester) async {
    SharedPreferences.setMockInitialValues({'user_age': 15});
    await pumpResultScreen(tester);
    expect(find.byType(OpenBookFrame), findsNothing);
  });

  // ---------------------------------------------------------------------
  // MT-381(a): the >=11 reader renders every page into one scrolling
  // ListView. The footer arrows only mutated _currentPageIndex, which
  // nothing in that layout reads — so they moved nothing, and the
  // end-of-story row stayed hidden for anyone who finished by scrolling.
  // ---------------------------------------------------------------------

  // ~600 words: comfortably more than the 120-words-per-page split, so the
  // reader has several pages and overflows the test viewport.
  final longStoryText =
      List.generate(600, (i) => 'word$i').join(' ');

  Future<void> pumpReader(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StoryResultScreen(
            title: 'Long Story',
            storyText: longStoryText,
            characterName: 'Ava',
            storyId: 'story_long',
            characterAge: 15,
            trackStoryCreation: false,
            trackAnalytics: false,
            offlineService: FakeOfflineStoryService(),
          ),
        ),
      ),
    );
    await pumpUntilFound(
      tester,
      finder: find.byType(ListView),
      maxPumps: 40,
      step: const Duration(milliseconds: 100),
    );
  }

  ScrollController readerController(WidgetTester tester) {
    final listView = tester.widget<ListView>(find.byType(ListView).first);
    final controller = listView.controller;
    expect(
      controller,
      isNotNull,
      reason: 'MT-381(a): the reader ListView needs a ScrollController — '
          'without one the footer arrows have nothing to drive',
    );
    return controller!;
  }

  testWidgets('MT-381(a): the Next page arrow actually moves the reader',
      (tester) async {
    await pumpReader(tester);
    final controller = readerController(tester);
    final before = controller.offset;

    await tester.tap(find.byTooltip('Next page'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      controller.offset,
      greaterThan(before),
      reason: 'MT-381(a): the arrow mutated _currentPageIndex, fired a haptic '
          'and a page-turn sound, and scrolled nothing. It must move the '
          'reader.',
    );
  });

  testWidgets(
      'MT-381(a): scrolling to the end reveals the end-of-story row',
      (tester) async {
    await pumpReader(tester);

    expect(
      find.text('Quick rating:'),
      findsNothing,
      reason: 'the rating row belongs at the END of the story, not the start',
    );

    final controller = readerController(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      find.text('Quick rating:'),
      findsOneWidget,
      reason: 'MT-381(a): isOnEndPage was gated on a page index the scrolling '
          'reader never advances, so a reader who finished the normal way — '
          'by scrolling to the last word — never saw the rating row or the '
          'Color-this-page chip',
    );
  });
}
