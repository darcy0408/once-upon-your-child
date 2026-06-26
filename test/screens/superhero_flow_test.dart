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
import 'package:story_weaver_app/screens/wizard_steps/superhero_power_screen.dart';
import 'package:story_weaver_app/screens/wizard_steps/superhero_vibe_chooser_screen.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/parent_sensitivity_interstitial.dart';

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

  // ── Explorer band — emblems + power renames ──────────────────────────────

  Future<void> advanceToEmblemPage(WidgetTester tester) async {
    // Costume screen starts at the color page. Tap the first color, which
    // auto-advances after ~300ms; then tap the first cape to advance again.
    await tester.tap(find.text('Red'));
    await tester.pump(); // start the 300ms timer
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No cape'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('Explorer costume screen shows Bolt + Comet emblems',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final wd = WizardData()
      ..characterName = 'Sam'
      ..characterAge = 7; // Explorer band

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SuperheroCostumeScreen(
          wizardData: wd,
          band: AgeBand.explorer,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await advanceToEmblemPage(tester);

    // Sprout six + Explorer two.
    expect(find.text('Star'), findsOneWidget);
    expect(find.text('Lightning'), findsOneWidget);
    expect(find.text('Heart'), findsOneWidget);
    expect(find.text('Moon'), findsOneWidget);
    expect(find.text('Paw'), findsOneWidget);
    expect(find.text('Rainbow'), findsOneWidget);
    expect(find.text('Bolt'), findsOneWidget);
    expect(find.text('Comet'), findsOneWidget);
  });

  testWidgets('Sprout costume screen does NOT show Bolt or Comet emblems',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final wd = WizardData()
      ..characterName = 'Mia'
      ..characterAge = 4; // Sprout band

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SuperheroCostumeScreen(
          wizardData: wd,
          band: AgeBand.sprout,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await advanceToEmblemPage(tester);

    // Sprout six present.
    expect(find.text('Star'), findsOneWidget);
    expect(find.text('Rainbow'), findsOneWidget);
    // Explorer-only emblems absent.
    expect(find.text('Bolt'), findsNothing);
    expect(find.text('Comet'), findsNothing);
  });

  testWidgets('Explorer power screen shows Feeling Sense + Soft Step',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final wd = WizardData()
      ..characterName = 'Sam'
      ..characterAge = 7;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SuperheroPowerScreen(
          wizardData: wd,
          band: AgeBand.explorer,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Explorer-only powers.
    expect(find.text('Feeling Sense'), findsOneWidget);
    expect(find.text('Soft Step'), findsOneWidget);
    // Explorer renames present.
    expect(find.text('Lightning Speed'), findsOneWidget);
    expect(find.text('Sky Glide'), findsOneWidget);
    expect(find.text('Bright Smile'), findsOneWidget);
    // Sprout labels should NOT appear in the Explorer view.
    expect(find.text('Super Speed'), findsNothing);
    expect(find.text('Flying'), findsNothing);
  });

  testWidgets('Sprout power screen does NOT show Explorer-only powers',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final wd = WizardData()
      ..characterName = 'Mia'
      ..characterAge = 4;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SuperheroPowerScreen(
          wizardData: wd,
          band: AgeBand.sprout,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Sprout labels present.
    expect(find.text('Super Speed'), findsOneWidget);
    expect(find.text('Super Hugs'), findsOneWidget);
    // Explorer-only labels absent.
    expect(find.text('Feeling Sense'), findsNothing);
    expect(find.text('Soft Step'), findsNothing);
    // Explorer-renamed labels also absent.
    expect(find.text('Lightning Speed'), findsNothing);
    expect(find.text('Sky Glide'), findsNothing);
  });

  // ── MT-303: teen vibe chooser + heroMode gating ──────────────────────────

  testWidgets('vibe chooser shows both cards and sets heroMode=classic',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final wd = WizardData()
      ..characterName = 'Rae'
      ..characterAge = 16; // Adolescent band

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SuperheroVibeChooserScreen(
          wizardData: wd,
          band: AgeBand.adolescent,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Be a Hero'), findsOneWidget);
    expect(find.text('Live a Double Life'), findsOneWidget);
    expect(wd.heroMode, isNull); // not chosen yet

    // Tapping "Be a Hero" sets classic mode (then pushes the flow).
    await tester.tap(find.text('Be a Hero'));
    await tester.pump();
    expect(wd.heroMode, 'classic');
  });

  testWidgets(
      'classic teen costume screen skips the sensitivity gate and Identity page',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Un-acked prefs: the antihero flow WOULD show the gate. Classic must not.
    SharedPreferences.setMockInitialValues({});

    final wd = WizardData()
      ..characterName = 'Rae'
      ..characterAge = 16
      ..heroMode = 'classic';

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SuperheroCostumeScreen(
          wizardData: wd,
          band: AgeBand.adolescent,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // No parent sensitivity gate, straight to the colors page.
    expect(find.byType(ParentSensitivityInterstitial), findsNothing);
    expect(find.text('Choose your colors'), findsOneWidget);
    // The double-life Identity page is gone — its header never appears even
    // after advancing past color → emblem (the final page is emblem).
    expect(find.text('Your double life'), findsNothing);
  });

  testWidgets(
      'antihero teen costume screen (heroMode null) still shows the sensitivity gate',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({}); // un-acked → gate shows

    final wd = WizardData()
      ..characterName = 'Rae'
      ..characterAge = 16; // heroMode null = antihero behavior, unchanged

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SuperheroCostumeScreen(
          wizardData: wd,
          band: AgeBand.adolescent,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Regression guard: the antihero path is unchanged — the gate appears.
    expect(find.byType(ParentSensitivityInterstitial), findsOneWidget);
  });

  testWidgets('classic teen power screen shows classic copy, not Edge copy',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final wd = WizardData()
      ..characterName = 'Rae'
      ..characterAge = 16
      ..heroMode = 'classic';

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SuperheroPowerScreen(
          wizardData: wd,
          band: AgeBand.adolescent,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Classic names (incl. the extra IDs strategist/gadgeteer).
    expect(find.text('Flight'), findsOneWidget);
    expect(find.text('Mastermind'), findsOneWidget);
    expect(find.text('Gadgeteer'), findsOneWidget);
    // Antihero "Edge" copy must be absent.
    expect(find.text('Ghost'), findsNothing);
    expect(find.text('The Tell'), findsNothing);
    expect(find.text('Bend the Odds'), findsNothing);
  });

  testWidgets(
      'antihero teen power screen (heroMode null) still shows Edge copy',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final wd = WizardData()
      ..characterName = 'Rae'
      ..characterAge = 16; // heroMode null = antihero, unchanged

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: SuperheroPowerScreen(
          wizardData: wd,
          band: AgeBand.adolescent,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Regression guard: Edge copy intact.
    expect(find.text('Ghost'), findsOneWidget);
    expect(find.text('The Tell'), findsOneWidget);
    // Classic copy absent.
    expect(find.text('Flight'), findsNothing);
    expect(find.text('Mastermind'), findsNothing);
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
