// Explorer avatar-loading star-catcher regression coverage.
//
// A full-stage GestureDetector (empty onTapDown, HitTestBehavior.translucent)
// used to sit ABOVE the star tap-targets in ExplorerConstellation's Stack.
// In the gesture arena the topmost tap recognizer wins, so it silently
// swallowed every star tap: no haptic, no onTap, no firework, no sparkle
// counter. These tests pin the fixed behavior — tapping a drifted-in star
// target MUST reach onTap and consume the target.
//
// NOTE: ExplorerConstellation runs forever-looping animation controllers and
// a periodic spawn Timer, so `pumpAndSettle()` would time out. We drive it
// with bounded `pump()`s instead, then pump an empty tree so dispose()
// cancels timers/controllers before the test ends.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/avatar_loading_bands/explorer_constellation.dart';

void main() {
  Future<void> pumpConstellation(
    WidgetTester tester, {
    required VoidCallback onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ExplorerConstellation(
              stageSize: 280.0,
              progress: 0.5,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
    // Let initState/build settle with bounded frames (never settle — the
    // constellation animates forever).
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> tearDownView(WidgetTester tester) async {
    // Empty tree so the widget disposes (cancels its spawn timer and
    // animation controllers) and the test doesn't fail on pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
  }

  /// Advances fake time past one spawn-timer tick (2500ms) so at least one
  /// star tap-target is on the stage, then past the target's 300ms elastic
  /// scale-in — at scale 0.0 the Transform is non-invertible and the target
  /// can't be hit-tested yet.
  Future<void> waitForTarget(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.byIcon(Icons.star), findsWidgets,
        reason: 'a star tap-target should have spawned after 2.5s');
    await tester.pump(const Duration(milliseconds: 350));
  }

  group('ExplorerConstellation star-catcher', () {
    testWidgets('tapping a star target fires onTap (regression: full-stage '
        'overlay used to swallow the tap)', (tester) async {
      var taps = 0;
      await pumpConstellation(tester, onTap: () => taps++);
      await waitForTarget(tester);

      await tester.tap(find.byIcon(Icons.star).first);
      await tester.pump(const Duration(milliseconds: 16));

      expect(taps, 1,
          reason: 'the star tap must reach onTap — if this fails, something '
              'above the tap targets is winning the gesture arena');

      await tearDownView(tester);
    });

    testWidgets('a caught star is consumed and a firework burst renders',
        (tester) async {
      await pumpConstellation(tester, onTap: () {});
      await waitForTarget(tester);

      final starsBefore = find.byIcon(Icons.star).evaluate().length;
      await tester.tap(find.byIcon(Icons.star).first);
      await tester.pump(const Duration(milliseconds: 16));

      // Target consumed…
      expect(find.byIcon(Icons.star).evaluate().length, starsBefore - 1);

      // …and mid-burst a firework CustomPaint is on the stage (one more
      // paint surface than the constellation painter alone).
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.descendant(
          of: find.byType(ExplorerConstellation),
          matching: find.byType(CustomPaint),
        ),
        findsAtLeastNWidgets(2),
        reason: 'burst painter should render while its 800ms controller runs',
      );

      // Let the burst finish so its controller is removed cleanly.
      await tester.pump(const Duration(milliseconds: 900));
      await tearDownView(tester);
    });
  });
}
