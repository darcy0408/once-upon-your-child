import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/story_notes.dart';
import 'package:story_weaver_app/screens/story_notes_screen.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

void main() {
  testWidgets('StoryNotesScreen renders the Explorer disclosure + co-read',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoryNotesScreen.fromFocus(
          focusValue: 'a limit is set',
          band: AgeBand.explorer,
          heroName: 'Mia',
        ),
      ),
    );

    expect(find.text('What this story was about 💛'), findsOneWidget);
    expect(find.textContaining('hearing "no"'), findsOneWidget);
    expect(find.textContaining('Mia'), findsOneWidget); // co-read prompt
    expect(find.text('Back to stories'), findsOneWidget);
  });

  testWidgets('mature band shows the "Got it" dismissal, not "Back to stories"',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoryNotesScreen(
          band: AgeBand.adolescent,
          content: buildStoryNotes(
            focusValue: 'a transition happens',
            band: AgeBand.adolescent,
          ),
        ),
      ),
    );

    expect(find.text('Got it'), findsOneWidget);
    expect(find.textContaining('Straight up'), findsOneWidget);
  });

  testWidgets('StoryNotesButton is quiet and opens the reveal on tap',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StoryNotesButton(
            focusValue: 'a friendship bump happens',
            band: AgeBand.explorer,
            heroName: 'Sam',
          ),
        ),
      ),
    );

    // The pull trigger is present; the disclosure is not shown until tapped.
    expect(find.text('Why this story?'), findsOneWidget);
    expect(find.text('What this story was about 💛'), findsNothing);

    await tester.tap(find.text('Why this story?'));
    await tester.pumpAndSettle();

    // Now the reveal screen is on top.
    expect(find.text('What this story was about 💛'), findsOneWidget);
    // Explorer is the gentle tone → the longer, warmer phrasing.
    expect(find.textContaining('reconnect with a friend'), findsOneWidget);
  });
}
