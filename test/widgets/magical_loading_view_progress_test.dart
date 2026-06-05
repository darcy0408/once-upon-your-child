// PERF-01 cancellation polish — progress→dot mapping coverage.
//
// MagicalLoadingView's `_stepIndexForProgress` (and the corresponding
// `_stepIndex` state it drives) is PRIVATE, so this is a WIDGET test that pumps
// the real widget at several `progress` values and asserts the RENDERED dot
// state: which of the four adventure-step dots is "active" (its label is bold)
// and how many earlier dots are "done" (rendered with a check icon).
//
// Expected mapping (mirrors the production formula, last dot only at >= 0.95):
//   p < 0.95 : idx = (p / 0.95 * 3).floor()
//   p >= 0.95: idx = 3
//     0.00 -> idx 0  (0 done checks)
//     0.50 -> idx 1  (1 done check)   (0.50/0.95*3 = 1.578 -> floor 1)
//     0.95 -> idx 3  (3 done checks)
//     1.00 -> idx 3  (3 done checks)
//
// NOTE: MagicalLoadingView runs forever-looping animation controllers and
// Timer.periodic instances, so `pumpAndSettle()` would time out. We drive it
// with bounded `pump()`s instead, then pump an empty tree so the widget's
// dispose() cancels its timers/controllers before the test ends.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/magical_loading_view.dart';

void main() {
  // The four adventure-step labels rendered beneath the dot row. Kept in sync
  // with MagicalLoadingView's private `_adventureSteps`.
  const stepLabels = <String>[
    'Entering your world',
    'Finding your hero',
    'Writing the story',
    'Almost ready!',
  ];

  Future<void> pumpView(WidgetTester tester, double progress) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MagicalLoadingView(
              status: 'Making magic...',
              progress: progress,
            ),
          ),
        ),
      ),
    );
    // A few bounded frames to let initState/build settle (do NOT settle — the
    // view animates forever).
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> tearDownView(WidgetTester tester) async {
    // Replace with an empty tree so the widget disposes (cancels its timers and
    // animation controllers) and the test doesn't fail on pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
  }

  /// The index of the active step — the dot whose label is rendered bold.
  int activeStepIndex(WidgetTester tester) {
    for (var i = 0; i < stepLabels.length; i++) {
      final textWidget = tester.widget<Text>(find.text(stepLabels[i]));
      if (textWidget.style?.fontWeight == FontWeight.bold) {
        return i;
      }
    }
    fail('No active (bold) adventure-step label found');
  }

  /// Number of "done" dots — each completed dot renders a check icon.
  int doneCheckCount(WidgetTester tester) {
    return find.byIcon(Icons.check).evaluate().length;
  }

  group('MagicalLoadingView progress -> dot mapping', () {
    testWidgets('progress 0.0 lights only the first dot (none done)',
        (tester) async {
      await pumpView(tester, 0.0);
      expect(activeStepIndex(tester), 0);
      expect(doneCheckCount(tester), 0);
      await tearDownView(tester);
    });

    testWidgets('progress 0.5 advances to the second dot (one done)',
        (tester) async {
      await pumpView(tester, 0.5);
      expect(activeStepIndex(tester), 1);
      expect(doneCheckCount(tester), 1);
      await tearDownView(tester);
    });

    testWidgets('progress 0.95 lights the final dot (three done)',
        (tester) async {
      await pumpView(tester, 0.95);
      expect(activeStepIndex(tester), 3);
      expect(doneCheckCount(tester), 3);
      await tearDownView(tester);
    });

    testWidgets('progress 1.0 stays on the final dot (three done)',
        (tester) async {
      await pumpView(tester, 1.0);
      expect(activeStepIndex(tester), 3);
      expect(doneCheckCount(tester), 3);
      await tearDownView(tester);
    });

    testWidgets('final "Almost ready!" dot is NOT active just below 0.95',
        (tester) async {
      // Guards the "last dot only at >= 0.95" contract: at 0.94 the final dot
      // must not yet be the active one.
      await pumpView(tester, 0.94);
      expect(activeStepIndex(tester), isNot(3));
      await tearDownView(tester);
    });
  });
}
