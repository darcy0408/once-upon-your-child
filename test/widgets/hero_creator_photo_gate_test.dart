import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';

void main() {
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  Widget buildSubject(WizardData wizardData) {
    return MaterialApp(
      home: Scaffold(
        body: HeroCreatorStep(
          wizardData: wizardData,
          onNext: () {},
        ),
      ),
    );
  }

  /// Navigate from page 1 (name/gender) to page 2 (avatar choice).
  /// Timeline: 400 ms gender-tap delay → _heroNextPage → 400 ms animation
  /// + 850 ms TTS timer = 1650 ms total to drain all pending timers.
  Future<void> advanceToAvatarPage(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Girl'));
    await pumpFor(tester, const Duration(milliseconds: 1700));
  }

  WizardData wizardDataAge10() => WizardData()
    ..characterName = 'Maya'
    ..characterGender = 'Girl'
    // age >= 9 skips particle/audio effects in _triggerPageCelebration
    ..characterAge = 10;

  group('AI Avatar card visibility gate', () {
    testWidgets('hidden when allowPhotoAvatar is false (default)', (tester) async {
      SharedPreferences.setMockInitialValues({'allow_photo_avatar': false});

      await tester.pumpWidget(buildSubject(wizardDataAge10()));
      await pumpFor(tester, const Duration(milliseconds: 500));

      await advanceToAvatarPage(tester);

      expect(find.text('Gallery Avatar'), findsOneWidget);
      expect(find.text('AI Avatar'), findsNothing);
    });

    testWidgets('hidden when allow_photo_avatar key is absent', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildSubject(wizardDataAge10()));
      await pumpFor(tester, const Duration(milliseconds: 500));

      await advanceToAvatarPage(tester);

      expect(find.text('Gallery Avatar'), findsOneWidget);
      expect(find.text('AI Avatar'), findsNothing);
    });

    testWidgets('shown when allowPhotoAvatar is true', (tester) async {
      SharedPreferences.setMockInitialValues({'allow_photo_avatar': true});

      await tester.pumpWidget(buildSubject(wizardDataAge10()));
      await pumpFor(tester, const Duration(milliseconds: 500));

      await advanceToAvatarPage(tester);

      expect(find.text('Gallery Avatar'), findsOneWidget);
      expect(find.text('AI Avatar'), findsOneWidget);
    });
  });
}
