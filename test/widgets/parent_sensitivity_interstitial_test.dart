// MT-158 / content-safety audit F-08 — widget test for the parent-facing
// sensitivity interstitial.
//
// Pins:
//   * Quest title renders.
//   * All sensitivity topics render as chips.
//   * parentNote body copy renders.
//   * Both action buttons render and fire their callbacks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/parent_sensitivity_interstitial.dart';

void main() {
  Widget harness(Widget child) {
    // Black background so the warm-sand panel stays visible in the goldens
    // and so the inherited AgeBandThemeData default (useSerif fallback) is
    // exercised — the widget reads the band extension defensively.
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: child,
      ),
    );
  }

  testWidgets('renders title, topics, parentNote, and both actions',
      (tester) async {
    await tester.pumpWidget(
      harness(
        ParentSensitivityInterstitial(
          questTitle: 'Behind Closed Doors',
          topics: const ['parental conflict', 'tension at home'],
          parentNote:
              'This quest is about hearing grown-ups argue from behind a '
              'closed door.',
          onStart: () {},
          onBack: () {},
        ),
      ),
    );

    // Title
    expect(find.text('Behind Closed Doors'), findsOneWidget);

    // Each topic appears
    expect(find.text('parental conflict'), findsOneWidget);
    expect(find.text('tension at home'), findsOneWidget);

    // Body copy
    expect(
      find.textContaining('hearing grown-ups argue'),
      findsOneWidget,
    );

    // Buttons
    expect(find.text('Start the story'), findsOneWidget);
    expect(find.text('Choose a different story'), findsOneWidget);
  });

  testWidgets('Start the story button fires onStart', (tester) async {
    var started = 0;
    var backed = 0;
    await tester.pumpWidget(
      harness(
        ParentSensitivityInterstitial(
          questTitle: 'X',
          topics: const ['t'],
          parentNote: 'note',
          onStart: () => started++,
          onBack: () => backed++,
        ),
      ),
    );

    await tester.tap(find.text('Start the story'));
    await tester.pumpAndSettle();
    expect(started, 1);
    expect(backed, 0);
  });

  testWidgets('Choose a different story button fires onBack', (tester) async {
    var started = 0;
    var backed = 0;
    await tester.pumpWidget(
      harness(
        ParentSensitivityInterstitial(
          questTitle: 'X',
          topics: const ['t'],
          parentNote: 'note',
          onStart: () => started++,
          onBack: () => backed++,
        ),
      ),
    );

    await tester.tap(find.text('Choose a different story'));
    await tester.pumpAndSettle();
    expect(backed, 1);
    expect(started, 0);
  });

  testWidgets('renders without topic chips when topics list is empty',
      (tester) async {
    // Defensive — callers should normally not show this widget without
    // topics, but a future caller might. Title + parentNote + actions must
    // still appear.
    await tester.pumpWidget(
      harness(
        ParentSensitivityInterstitial(
          questTitle: 'Empty Topics',
          topics: const [],
          parentNote: 'Just a note.',
          onStart: () {},
          onBack: () {},
        ),
      ),
    );

    expect(find.text('Empty Topics'), findsOneWidget);
    expect(find.text('Just a note.'), findsOneWidget);
    expect(find.text('Start the story'), findsOneWidget);
    expect(find.text('Choose a different story'), findsOneWidget);
  });
}
