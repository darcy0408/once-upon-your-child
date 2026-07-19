import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/local/story_local.dart';
import 'package:story_weaver_app/providers/story_provider.dart';
import 'package:story_weaver_app/saved_stories_screen.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

void main() {
  group('SavedStoriesScreen Tests', () {
    testWidgets('shows empty state when no stories', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storyListProvider.overrideWith(() => MockStoryList([])),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [explorerTheme]),
            home: const SavedStoriesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No stories saved yet!'), findsOneWidget);
    });

    testWidgets('shows story list when stories exist', (tester) async {
      final story = StoryLocal()
        ..storyId = 's1'
        ..title = 'The Brave Ant'
        ..theme = 'Adventure'
        ..storyText = 'Once upon a time...'
        ..createdAt = DateTime.now();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storyListProvider.overrideWith(() => MockStoryList([story])),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [explorerTheme]),
            home: const SavedStoriesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('The Brave Ant'), findsOneWidget);
    });

    testWidgets('filtering by favorites works', (tester) async {
      final s1 = StoryLocal()..storyId = 's1'..title = 'Normal Story'..theme='A'..storyText='T'..isFavorite = false..createdAt = DateTime.now();
      final s2 = StoryLocal()..storyId = 's2'..title = 'Favorite Story'..theme='B'..storyText='T'..isFavorite = true..createdAt = DateTime.now();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storyListProvider.overrideWith(() => MockStoryList([s1, s2])),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [explorerTheme]),
            home: const SavedStoriesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Normal Story'), findsOneWidget);
      expect(find.text('Favorite Story'), findsOneWidget);

      // Tap favorite filter in AppBar (use the IconButton tooltip to disambiguate)
      await tester.tap(find.byTooltip('Show favorites only'));
      await tester.pumpAndSettle();

      expect(find.text('Normal Story'), findsNothing);
      expect(find.text('Favorite Story'), findsOneWidget);
    });

    testWidgets('swipe-delete asks for confirmation and Keep it cancels',
        (tester) async {
      final story = StoryLocal()
        ..storyId = 's1'
        ..title = 'Keeper Story'
        ..theme = 'Adventure'
        ..storyText = 'T'
        ..createdAt = DateTime.now();
      final mock = DeleteTrackingStoryList([story]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storyListProvider.overrideWith(() => mock),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [explorerTheme]),
            home: const SavedStoriesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swipe left = delete gesture on the card.
      await tester.drag(find.text('Keeper Story'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Delete this story?'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(find.text('Keeper Story'), findsOneWidget);
      expect(mock.deleteCalls, 0);
    });

    testWidgets('confirming Delete removes the story', (tester) async {
      final story = StoryLocal()
        ..storyId = 's1'
        ..title = 'Doomed Story'
        ..theme = 'Adventure'
        ..storyText = 'T'
        ..createdAt = DateTime.now();
      final mock = DeleteTrackingStoryList([story]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storyListProvider.overrideWith(() => mock),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [explorerTheme]),
            home: const SavedStoriesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Doomed Story'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(mock.deleteCalls, 1);
    });
  });
}

/// Tracks deleteStory calls without touching Isar.
class DeleteTrackingStoryList extends MockStoryList {
  DeleteTrackingStoryList(super.initialStories);

  int deleteCalls = 0;

  @override
  Future<void> deleteStory(String storyId) async {
    deleteCalls++;
    state = AsyncData(
      (state.valueOrNull ?? [])
          .where((s) => s.storyId != storyId)
          .toList(),
    );
  }

  @override
  Future<void> refresh() async {}
}

class MockStoryList extends StoryList {
  final List<StoryLocal> initialStories;
  MockStoryList(this.initialStories);

  @override
  Future<List<StoryLocal>> build() async => initialStories;
}
