// PERF-01 cancellation polish — Cancel-button wiring coverage.
//
// MagicalLoadingView surfaces a 'Cancel' button only when an `onCancel`
// callback is supplied; tapping it must invoke that callback. In production the
// callback (e.g. magic_review_step._cancelGeneration) is what flips _isGenerating
// off and fires ApiServiceManager.cancelTask(taskId).
//
// SCOPE / LIMITATION: ApiServiceManager.cancelTask is a STATIC method with no
// injection seam, so we cannot assert the network POST /cancel-task/<id> from a
// widget test without refactoring production code (deemed out of scope — the
// task said not to add a mock seam just for the test). Instead we assert the
// OBSERVABLE wiring contract this widget owns: the Cancel button is present iff
// onCancel != null, and tapping it invokes the callback exactly once. The
// callback-to-cancelTask hop is covered by the production code in
// magic_review_step.dart (_cancelGeneration) and the bedtime/quick-story
// dispose handlers, which are simple enough to verify by inspection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/magical_loading_view.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> tearDownView(WidgetTester tester) async {
    // Dispose the view so its forever-running timers/controllers are cancelled.
    await tester.pumpWidget(const SizedBox.shrink());
  }

  group('MagicalLoadingView cancel wiring', () {
    testWidgets('renders no Cancel button when onCancel is null',
        (tester) async {
      await pump(
        tester,
        const MagicalLoadingView(status: 'Making magic...', progress: 0.2),
      );
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
      await tearDownView(tester);
    });

    testWidgets('tapping Cancel invokes the onCancel callback once',
        (tester) async {
      var cancelCalls = 0;
      await pump(
        tester,
        MagicalLoadingView(
          status: 'Making magic...',
          progress: 0.2,
          onCancel: () => cancelCalls++,
        ),
      );

      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButton, findsOneWidget);

      await tester.tap(cancelButton);
      await tester.pump();

      expect(cancelCalls, 1);
      await tearDownView(tester);
    });
  });
}
