import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/screens/splash_screen.dart';

/// MT-387 — the splash is a fixed 4-second hold on every launch. It is now
/// skippable by tapping anywhere, and reduced-motion users don't sit through
/// it at all.

Future<void> _pumpSplash(
  WidgetTester tester, {
  required VoidCallback onComplete,
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(home: SplashScreen(onComplete: onComplete)),
    ),
  );
}

void main() {
  testWidgets('tapping the splash completes it early', (tester) async {
    var completed = 0;
    await _pumpSplash(tester, onComplete: () => completed++);

    // Part-way through the 4s hold — nothing should have fired yet.
    await tester.pump(const Duration(milliseconds: 800));
    expect(completed, 0);

    await tester.tap(find.byType(SplashScreen));
    await tester.pump();
    expect(completed, 1, reason: 'A tap must skip the remaining hold');

    // Drain the rest of the animation; the status listener must not re-fire.
    await tester.pump(const Duration(seconds: 5));
    expect(completed, 1,
        reason: 'onComplete must fire exactly once, not again at 4s');
  });

  testWidgets('completes on its own after the full hold', (tester) async {
    var completed = 0;
    await _pumpSplash(tester, onComplete: () => completed++);

    await tester.pump(const Duration(milliseconds: 3999));
    expect(completed, 0, reason: 'Should still be holding just before 4s');

    await tester.pump(const Duration(milliseconds: 10));
    expect(completed, 1);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the skip hint appears during the hold', (tester) async {
    await _pumpSplash(tester, onComplete: () {});

    expect(find.text('Tap to skip'), findsOneWidget,
        reason: 'Hint is mounted from the start');
    final fader = find.byKey(const ValueKey('splash-skip-hint'));

    // It is faded out early so it never competes with the logo entrance...
    expect(tester.widget<FadeTransition>(fader).opacity.value, 0.0);

    // ...and is visible by the back half of the hold, which is what makes the
    // affordance discoverable at all.
    await tester.pump(const Duration(milliseconds: 2600));
    expect(tester.widget<FadeTransition>(fader).opacity.value,
        greaterThan(0.9));

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('reduced motion skips the hold entirely', (tester) async {
    var completed = 0;
    await _pumpSplash(
      tester,
      onComplete: () => completed++,
      reduceMotion: true,
    );

    // One frame for the post-frame callback to run — no 4s wait.
    await tester.pump();
    expect(completed, 1,
        reason: 'Reduced motion must not hold the user for 4 seconds');

    await tester.pump(const Duration(seconds: 5));
    expect(completed, 1, reason: 'Still exactly once');
  });
}
