// Widget tests for the Superhero Mode UI flow.
//
// Covers the dispatcher routing:
//   1. First-run (no profile) → costume picker shows.
//   2. Returning (profile exists) → welcome-back screen shows with hero name.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/models/local/hero_profile_local.dart';
import 'package:story_weaver_app/providers/hero_profile_provider.dart';
import 'package:story_weaver_app/screens/wizard_steps/superhero_entry_screen.dart';
import 'package:story_weaver_app/screens/wizard_steps/superhero_welcome_back_screen.dart';
import 'package:story_weaver_app/screens/wizard_steps/superhero_costume_screen.dart';

WizardData _makeWizardData() {
  return WizardData()
    ..characterName = 'Mia'
    ..characterAge = 4
    ..characterId = 'char_mia';
}

Widget _bootstrap(WizardData wd, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: SuperheroEntryScreen(wizardData: wd),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SuperheroEntryScreen.resolveCharacterId (regression for welcome-back bug)', () {
    test('uses name-based key when only name is set', () {
      final wd = WizardData()..characterName = 'Mia';
      expect(SuperheroEntryScreen.resolveCharacterId(wd), 'name_mia');
    });

    test('uses name-based key EVEN WHEN characterId is also set', () {
      // This is the bug fix: previously, when wd.characterId existed (set by
      // magic_review_step.dart AFTER first story generates), the lookup key
      // would change on the 2nd run, missing the saved profile.
      final wd = WizardData()
        ..characterName = 'Mia'
        ..characterId = 'char_abc123-uuid';
      expect(SuperheroEntryScreen.resolveCharacterId(wd), 'name_mia');
    });

    test('normalizes name to lowercase + underscores', () {
      final wd = WizardData()..characterName = 'Mia Grace';
      expect(SuperheroEntryScreen.resolveCharacterId(wd), 'name_mia_grace');
    });

    test('falls back to characterId when name is empty', () {
      final wd = WizardData()
        ..characterName = ''
        ..characterId = 'char_abc123';
      expect(SuperheroEntryScreen.resolveCharacterId(wd), 'char_abc123');
    });

    test('returns temp_hero when both are empty', () {
      final wd = WizardData();
      expect(SuperheroEntryScreen.resolveCharacterId(wd), 'temp_hero');
    });
  });

  testWidgets('first run shows costume picker', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final wd = _makeWizardData();

    await tester.pumpWidget(_bootstrap(
      wd,
      overrides: [
        heroProfileProvider('name_mia').overrideWith((_) async => null),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SuperheroCostumeScreen), findsOneWidget);
    expect(find.text('Pick your hero color!'), findsOneWidget);
  });

  testWidgets('returning user shows welcome-back with hero name',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final wd = _makeWizardData();
    final profile = HeroProfileLocal()
      ..characterId = 'char_mia'
      ..costumeColor = 'purple'
      ..capeStyle = 'rainbow'
      ..emblem = 'star'
      ..power = 'super_hugs'
      ..heroName = 'Super Hugs Mia'
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await tester.pumpWidget(_bootstrap(
      wd,
      overrides: [
        heroProfileProvider('name_mia').overrideWith((_) async => profile),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SuperheroWelcomeBackScreen), findsOneWidget);
    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.text('Super Hugs Mia!'), findsOneWidget);
    expect(find.text('Yes! Start adventure'), findsOneWidget);
    expect(find.text('Edit my hero'), findsOneWidget);
  });

  testWidgets('tapping Start adventure pops with true and sets scenario',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final wd = _makeWizardData();
    final profile = HeroProfileLocal()
      ..characterId = 'char_mia'
      ..costumeColor = 'blue'
      ..capeStyle = 'matching'
      ..emblem = 'lightning'
      ..power = 'super_speed'
      ..heroName = 'Super Speed Mia'
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    final popCompleter = Completer<bool?>();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        heroProfileProvider('name_mia').overrideWith((_) async => profile),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                      .push<bool>(
                    MaterialPageRoute(
                      builder: (_) => SuperheroEntryScreen(wizardData: wd),
                    ),
                  )
                      .then(popCompleter.complete);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(SuperheroWelcomeBackScreen), findsOneWidget);

    await tester.tap(find.text('Yes! Start adventure'));
    await tester.pumpAndSettle();

    final popResult = await popCompleter.future
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
    expect(popResult, isTrue);
    expect(wd.selectedScenario, 'superhero');
    expect(wd.heroCostumeColor, 'blue');
    expect(wd.heroEmblem, 'lightning');
    expect(wd.heroPower, 'super_speed');
    expect(wd.heroSuperpower, 'Super Speed Mia');
    expect(wd.customElements, 'being a superhero');
  });
}
