// MT-158 / content-safety audit F-08 — flow test for LifeQuestScreen's
// sensitivity interstitial.
//
// Asserts:
//   * Tapping `someone_needs_help` shows the interstitial on a fresh
//     SharedPreferences slate.
//   * Persisting the acknowledgement via SharedPreferences means a second
//     entry skips the interstitial.
//
// Note on band theming: `someone_needs_help` is only available to the
// Adolescent band (15-17). That band's chrome uses SourceSansPro via
// google_fonts, which the test environment can't fetch. We work around
// this by passing the Explorer theme extension to MaterialApp — that
// drives the typography path (Fredoka) — while still passing childAge: 16
// so the quest filter surfaces the sensitive quest.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/life_quest_screen.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/parent_sensitivity_interstitial.dart';

void main() {
  // The Adolescent band quest filter requires childAge ≥ 15.
  const adolescentAge = 16;

  Widget harness() {
    // Use the Explorer band theme extension to keep widget chrome on the
    // Fredoka font path — this avoids google_fonts trying to fetch
    // SourceSansPro at test time. The quest data filter still uses
    // ageBandFromAge(childAge) → Adolescent so the sensitive quest appears.
    return MaterialApp(
      theme: ThemeData(extensions: [explorerTheme]),
      home: const LifeQuestScreen(
        childAge: adolescentAge,
        childName: 'Sam',
        selectedEmotion: 'worried',
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAWhile(WidgetTester tester) async {
    // The screen runs a postFrameCallback for Sprout TTS; this is a no-op
    // here (we're at age 16), but we still want a couple of frames to
    // settle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'tapping a sensitive quest shows the parent interstitial first',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await pumpAWhile(tester);

      // The selector should be visible — find the Someone Needs Help card
      // by its title (worried-filtered list narrows to a handful of quests).
      final card = find.text('Someone Needs Help');
      expect(card, findsOneWidget,
          reason: 'Sensitive quest card should be on the selector');

      // Tap the card.
      await tester.tap(card);
      await pumpAWhile(tester);

      // Interstitial is now mounted.
      expect(
        find.byType(ParentSensitivityInterstitial),
        findsOneWidget,
        reason:
            'First tap on a sensitive quest should route through the interstitial',
      );
      expect(find.text('Start the story'), findsOneWidget);
      expect(find.text('Choose a different story'), findsOneWidget);
    },
  );

  testWidgets(
    'subsequent entry skips the interstitial when the parent acknowledged before',
    (tester) async {
      // Pre-populate the acknowledgement for this quest id, simulating a
      // parent who already cleared the heads-up on a prior open.
      SharedPreferences.setMockInitialValues({
        'life_quest.sensitivity_ack.someone_needs_help': true,
      });

      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await pumpAWhile(tester);

      final card = find.text('Someone Needs Help');
      expect(card, findsOneWidget);
      await tester.tap(card);
      await pumpAWhile(tester);

      // No interstitial — the screen should be in the player straight away.
      expect(
        find.byType(ParentSensitivityInterstitial),
        findsNothing,
        reason: 'Acknowledged quest should NOT re-prompt the parent',
      );
      // Sanity: the title chrome of the active quest is visible. The
      // quest player puts the quest title in the top bar.
      expect(find.text('Someone Needs Help'), findsWidgets);
    },
  );
}
