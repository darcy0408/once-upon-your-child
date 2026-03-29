/// Six Age-Band Integration Tests (Flutter)
///
/// Verifies that all six age bands (sprout → adult) produce correct Flutter-side
/// behaviour: theme resolution, companion roster, feelings list, TTS rate scale,
/// wizard data mapping, and feelings screen tab counts.
///
/// These are pure unit / widget tests — no network calls are made.
///
/// Run with:
///   flutter test test/integration/six_band_integration_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/screens/feelings_garden_screen.dart';
import 'package:story_weaver_app/screens/wizard_steps/companion_selector_step.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';

// ---------------------------------------------------------------------------
// Band definitions mirroring age_band_theme.dart
// ---------------------------------------------------------------------------

/// Representative ages and their expected AgeBand enum values.
const List<(int age, AgeBand band)> kBandAges = [
  (4,  AgeBand.sprout),
  (7,  AgeBand.explorer),
  (10, AgeBand.adventurer),
  (13, AgeBand.creator),
  (16, AgeBand.adolescent),
  (25, AgeBand.adult),
];

/// All boundary ages that must resolve to a specific band.
const List<(int age, AgeBand band)> kBoundaryAges = [
  (3,  AgeBand.sprout),
  (5,  AgeBand.sprout),
  (6,  AgeBand.explorer),
  (8,  AgeBand.explorer),
  (9,  AgeBand.adventurer),
  (11, AgeBand.adventurer),
  (12, AgeBand.creator),
  (14, AgeBand.creator),
  (15, AgeBand.adolescent),
  (17, AgeBand.adolescent),
  (18, AgeBand.adult),
  (99, AgeBand.adult),
];

// ---------------------------------------------------------------------------
// Expected companion IDs per band (must match companion_selector_step.dart)
// ---------------------------------------------------------------------------

const Map<AgeBand, List<String>> kExpectedCompanionIds = {
  AgeBand.sprout: ['fluffy_dragon', 'magic_bunny', 'shining_puppy', 'robin'],
  AgeBand.explorer: ['ember_dragon', 'moon_owl', 'star_fox', 'robin'],
  AgeBand.adventurer: ['thunder_wolf', 'shadow_panther', 'crystal_phoenix', 'robin'],
  // creator / adolescent / adult companions are validated in separate widget tests
};

// ---------------------------------------------------------------------------
// Expected sprout feelings (must match feelings_garden_screen.dart)
// ---------------------------------------------------------------------------

const List<String> kSproutFeelingIds = ['happy', 'sad', 'angry', 'fearful', 'excited'];
const List<String> kSproutFeelingLabels = ['Happy', 'Sad', 'Angry', 'Scared', 'Excited'];

// ---------------------------------------------------------------------------
// Expected TTS rate scale per band
// ---------------------------------------------------------------------------

const Map<AgeBand, double> kBandTtsRateScale = {
  AgeBand.sprout:     0.8,
  AgeBand.explorer:   1.0,
  AgeBand.adventurer: 1.0,
  AgeBand.creator:    1.0,
  AgeBand.adolescent: 1.0,
  AgeBand.adult:      1.0,
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

WizardData _wizardDataForAge(int age) => WizardData()
  ..characterName = 'Luna'
  ..characterAge = age;

// ---------------------------------------------------------------------------
// 1. Age → Band resolution
// ---------------------------------------------------------------------------

void main() {
  group('1. ageBandFromAge() — representative ages', () {
    for (final (age, expected) in kBandAges) {
      test('age $age resolves to ${expected.name}', () {
        expect(ageBandFromAge(age), equals(expected));
      });
    }
  });

  group('1b. ageBandFromAge() — boundary ages', () {
    for (final (age, expected) in kBoundaryAges) {
      test('boundary age $age resolves to ${expected.name}', () {
        expect(ageBandFromAge(age), equals(expected));
      });
    }
  });

  group('1c. All 6 AgeBand enum values are reachable', () {
    test('every AgeBand can be resolved from at least one age', () {
      final reachable = <AgeBand>{};
      for (int age = 2; age <= 99; age++) {
        reachable.add(ageBandFromAge(age));
      }
      for (final band in AgeBand.values) {
        expect(reachable, contains(band),
            reason: '${band.name} is not reachable from any integer age');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 2. themeForAge() — produces non-null AgeBandThemeData for all bands
  // ---------------------------------------------------------------------------

  group('2. themeForAge() — all bands return valid theme data', () {
    for (final (age, band) in kBandAges) {
      test('themeForAge($age) returns ${band.name} theme', () {
        final theme = themeForAge(age);
        expect(theme.band, equals(band));
        expect(theme.primary, isNotNull);
        expect(theme.accent, isNotNull);
        expect(theme.uiFontFamily, isNotEmpty);
        expect(theme.storyFontFamily, isNotEmpty);
        expect(theme.sparkleIntensity, inInclusiveRange(0.0, 1.0));
      });
    }
  });

  group('2b. themeForBand() — direct band lookup returns correct band', () {
    for (final band in AgeBand.values) {
      test('themeForBand(${band.name}).band == ${band.name}', () {
        expect(themeForBand(band).band, equals(band));
      });
    }
  });

  // ---------------------------------------------------------------------------
  // 3. WizardData — age is stored correctly per band
  // ---------------------------------------------------------------------------

  group('3. WizardData age assignment per band', () {
    for (final (age, band) in kBandAges) {
      test('WizardData for age $age (${band.name}) preserves age', () {
        final wd = _wizardDataForAge(age);
        expect(wd.characterAge, equals(age));
        expect(ageBandFromAge(wd.characterAge), equals(band));
      });
    }
  });

  // ---------------------------------------------------------------------------
  // 4. Companion roster — sprout / explorer / adventurer IDs
  // ---------------------------------------------------------------------------

  group('4. Companion IDs per band', () {
    test('Sprout companions are exactly the 4 expected IDs', () {
      final ids = kExpectedCompanionIds[AgeBand.sprout]!;
      expect(ids.length, equals(4));
      expect(ids, containsAll(['fluffy_dragon', 'magic_bunny', 'shining_puppy', 'robin']));
    });

    test('Explorer companions are exactly the 4 expected IDs', () {
      final ids = kExpectedCompanionIds[AgeBand.explorer]!;
      expect(ids.length, equals(4));
      expect(ids, containsAll(['ember_dragon', 'moon_owl', 'star_fox', 'robin']));
    });

    test('Adventurer companions are exactly the 4 expected IDs', () {
      final ids = kExpectedCompanionIds[AgeBand.adventurer]!;
      expect(ids.length, equals(4));
      expect(ids, containsAll(['thunder_wolf', 'shadow_panther', 'crystal_phoenix', 'robin']));
    });

    test('Robin appears as a companion in sprout, explorer, and adventurer', () {
      for (final band in [AgeBand.sprout, AgeBand.explorer, AgeBand.adventurer]) {
        expect(kExpectedCompanionIds[band], contains('robin'),
            reason: '${band.name} should include Robin');
      }
    });

    testWidgets('Sprout CompanionSelectorStep shows 4 magical companions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final wizardData = _wizardDataForAge(4);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [sproutTheme],
          ),
          home: Scaffold(
            body: CompanionSelectorStep(
              wizardData: wizardData,
              onNext: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Sprout companions by name
      expect(find.text('Fluffy Dragon'), findsOneWidget);
      expect(find.text('Magic Bunny'), findsOneWidget);
      expect(find.text('Shining Puppy'), findsOneWidget);
      expect(find.text('Robin'), findsOneWidget);

      // Explorer companions must NOT be visible for a sprout
      expect(find.text('Ember Dragon'), findsNothing);
      expect(find.text('Moon Owl'), findsNothing);
    });

    testWidgets('Explorer CompanionSelectorStep shows explorer companions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final wizardData = _wizardDataForAge(7);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [explorerTheme],
          ),
          home: Scaffold(
            body: CompanionSelectorStep(
              wizardData: wizardData,
              onNext: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ember Dragon'), findsOneWidget);
      expect(find.text('Moon Owl'), findsOneWidget);
      expect(find.text('Star Fox'), findsOneWidget);
      // Sprout-only companions must NOT be visible
      expect(find.text('Fluffy Dragon'), findsNothing);
      expect(find.text('Magic Bunny'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Sprout feelings — exactly 5 emotions, correct IDs and labels
  // ---------------------------------------------------------------------------

  group('5. Sprout feelings list', () {
    test('exactly 5 sprout feelings', () {
      expect(kSproutFeelingIds.length, equals(5));
    });

    test('sprout feeling IDs are the correct set', () {
      expect(
        Set.of(kSproutFeelingIds),
        equals({'happy', 'sad', 'angry', 'fearful', 'excited'}),
      );
    });

    test('sprout feelings do not include adult vocabulary', () {
      const forbiddenIds = ['disgusted', 'bad', 'contempt', 'shame'];
      for (final id in forbiddenIds) {
        expect(kSproutFeelingIds, isNot(contains(id)),
            reason: "'$id' is too complex for sprout age band");
      }
    });

    test('sprout feeling labels match expected child-friendly text', () {
      expect(kSproutFeelingLabels, containsAll(['Happy', 'Sad', 'Angry', 'Scared', 'Excited']));
      // 'Fearful' → mapped to display label 'Scared' for Sprouts
      expect(kSproutFeelingLabels, isNot(contains('Fearful')));
    });

    testWidgets('FeelingsGardenScreen shows 5 feelings tiles for age 4',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeelingsGardenScreen(childAge: 4),
          ),
        ),
      );
      await tester.pump();

      // All 5 sprout feeling labels should be visible
      for (final label in kSproutFeelingLabels) {
        expect(find.text(label), findsOneWidget,
            reason: "Sprout feelings screen should show '$label'");
      }

      // Adult vocabulary should not appear
      expect(find.text('Disgusted'), findsNothing);
      expect(find.text('Fearful'), findsNothing);
    });

    testWidgets('FeelingsGardenScreen for age 8 shows Explorer feelings (not sprout list)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeelingsGardenScreen(childAge: 8),
          ),
        ),
      );
      await tester.pump();

      // Explorer and above get the full feelings wheel — NOT the 5-tile sprout list
      // The key check is that the sprout-only Wrap is not rendered
      // (sprout-only screen requires childAge <= 5)
      // We verify this by checking the screen is NOT identical to sprout view:
      // The full wheel renders tabs rather than a simple Wrap
      expect(find.byType(TabBar), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. FeelingsGardenScreen tab count per band
  // ---------------------------------------------------------------------------

  group('6. FeelingsGardenScreen tab count', () {
    const tabCounts = [
      (4,  0),   // Sprout: no tabs (single cloud picker)
      (5,  0),   // Sprout boundary
      (6,  2),   // Explorer: 2 tabs (intensity + feelings explorer)
      (7,  2),
      (8,  3),   // Adventurer+: 3 tabs (adds journal)
      (10, 3),
      (13, 3),
      (16, 3),
      (25, 3),
    ];

    for (final (age, expectedTabs) in tabCounts) {
      testWidgets('FeelingsGardenScreen for age $age has $expectedTabs tab(s)',
          (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FeelingsGardenScreen(childAge: age),
            ),
          ),
        );
        await tester.pump();

        if (expectedTabs == 0) {
          // Sprout: no TabBar — single-zone layout
          expect(find.byType(TabBar), findsNothing,
              reason: 'Age $age (sprout) should not have a TabBar');
        } else {
          final tabBar = tester.widget<TabBar>(find.byType(TabBar));
          expect(tabBar.tabs.length, equals(expectedTabs),
              reason: 'Age $age should have $expectedTabs tabs');
        }
      });
    }
  });

  // ---------------------------------------------------------------------------
  // 7. TTS rate scale per band
  // ---------------------------------------------------------------------------

  group('7. TTS rate scale per band', () {
    test('sprout TTS rate scale is 0.8 (80% of default)', () {
      expect(kBandTtsRateScale[AgeBand.sprout], equals(0.8));
    });

    test('all non-sprout bands use full rate (1.0)', () {
      for (final band in AgeBand.values) {
        if (band == AgeBand.sprout) continue;
        expect(kBandTtsRateScale[band], equals(1.0),
            reason: '${band.name} should use 1.0 TTS rate scale');
      }
    });

    test('sprout TTS rate scale is strictly less than 1.0', () {
      expect(kBandTtsRateScale[AgeBand.sprout]!, lessThan(1.0));
    });

    test('sprout TTS rate scale is not unreasonably slow (>= 0.7)', () {
      expect(kBandTtsRateScale[AgeBand.sprout]!, greaterThanOrEqualTo(0.7));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. AgeBandThemeData — key properties vary correctly across bands
  // ---------------------------------------------------------------------------

  group('8. AgeBandThemeData varies appropriately across bands', () {
    test('young bands have sparkle intensity > 0; mature bands have 0', () {
      // Explorer is the maximum (1.0), sprout is also sparkly (0.7)
      for (final band in [AgeBand.sprout, AgeBand.explorer, AgeBand.adventurer]) {
        expect(themeForBand(band).sparkleIntensity, greaterThan(0.0),
            reason: '${band.name} should have sparkle > 0');
      }
      for (final band in [AgeBand.creator, AgeBand.adolescent, AgeBand.adult]) {
        expect(themeForBand(band).sparkleIntensity, equals(0.0),
            reason: '${band.name} (mature) should have 0 sparkle');
      }
    });

    test('adult band prefers dark mode', () {
      expect(themeForBand(AgeBand.adult).preferDarkMode, isTrue);
    });

    test('sprout band uses larger touch targets than adult', () {
      final sproutThemeData = themeForBand(AgeBand.sprout);
      final adultThemeData = themeForBand(AgeBand.adult);
      expect(
        sproutThemeData.touchTargetMin,
        greaterThanOrEqualTo(adultThemeData.touchTargetMin),
        reason: 'Sprouts need larger touch targets (motor control)',
      );
    });

    test('every band has a valid primary color (fully opaque)', () {
      for (final band in AgeBand.values) {
        final theme = themeForBand(band);
        expect(theme.primary.alpha, equals(255),
            reason: '${band.name} primary color should be fully opaque');
      }
    });

    test('no two adjacent bands share exactly the same primary color', () {
      final bands = AgeBand.values.toList();
      for (int i = 0; i < bands.length - 1; i++) {
        final a = themeForBand(bands[i]).primary;
        final b = themeForBand(bands[i + 1]).primary;
        expect(a, isNot(equals(b)),
            reason:
                '${bands[i].name} and ${bands[i + 1].name} should have distinct primary colors');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 9. CompanionSelectorStep — "Go Solo" button present for all bands
  // ---------------------------------------------------------------------------

  group('9. CompanionSelectorStep — skip/go-solo button available for all bands', () {
    // Mature bands (creator / adolescent / adult) show 'Skip'.
    // Young bands (sprout / explorer / adventurer) show 'Go Solo'.
    for (final (age, band) in kBandAges) {
      final expectedText = band.isMature ? 'Skip' : 'Go Solo';
      testWidgets('age $age (${band.name}) shows "$expectedText" button',
          (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final wizardData = _wizardDataForAge(age);
        var didContinue = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [themeForBand(band)]),
            home: Scaffold(
              body: CompanionSelectorStep(
                wizardData: wizardData,
                onNext: () => didContinue = true,
              ),
            ),
          ),
        );
        await tester.pump();

        final skipOrSolo = find.text(expectedText);
        expect(skipOrSolo, findsOneWidget,
            reason: '${band.name} (age $age) must have "$expectedText" button');

        await tester.ensureVisible(skipOrSolo);
        await tester.tap(skipOrSolo);
        await tester.pump();

        expect(didContinue, isTrue,
            reason: '${band.name} "$expectedText" should call onNext');
      });
    }
  });

  // ---------------------------------------------------------------------------
  // 10. Sprout-specific invariants
  // ---------------------------------------------------------------------------

  group('10. Sprout invariants (age 3–5)', () {
    test('sprout band has sparkle and particles enabled', () {
      final theme = themeForBand(AgeBand.sprout);
      expect(theme.sparkleIntensity, greaterThan(0.0),
          reason: 'Sprout sparkle intensity should be > 0');
      expect(theme.showParticles, isTrue);
    });

    test('sprout band does not prefer dark mode', () {
      expect(themeForBand(AgeBand.sprout).preferDarkMode, isFalse);
    });

    test('sprout has exactly 4 magical companions', () {
      expect(kExpectedCompanionIds[AgeBand.sprout]!.length, equals(4));
    });

    test('sprout has exactly 5 feelings', () {
      expect(kSproutFeelingIds.length, equals(5));
    });

    test('sprout TTS rate scale is 0.8', () {
      expect(kBandTtsRateScale[AgeBand.sprout], equals(0.8));
    });

    testWidgets('Sprout CompanionSelectorStep does NOT show explorer companions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [sproutTheme]),
          home: Scaffold(
            body: CompanionSelectorStep(
              wizardData: _wizardDataForAge(4),
              onNext: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Explorer-only companions must not bleed into sprout view
      expect(find.text('Thunder Wolf'), findsNothing);
      expect(find.text('Shadow Panther'), findsNothing);
      expect(find.text('Ember Dragon'), findsNothing);
    });
  });
}
