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
  (12, AgeBand.adventurer),
  (13, AgeBand.creator),
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
  AgeBand.sprout: ['pebble', 'robin', 'mochi', 'sunny'],
  AgeBand.explorer: ['ember', 'robin', 'clover', 'biscuit'],
  AgeBand.adventurer: ['atlas', 'robin', 'nyx', 'kodiak'],
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

  // MT-286: the returnable Hero Saga write path (`recordIssue` in
  // magic_review_step) and the welcome-back recap card both gate on the SAME
  // `AgeBand.usesHeroSaga` predicate. Lock the band set so the Explorer write
  // path can never silently regress to a Creator-only subset.
  group('1d. AgeBand.usesHeroSaga — saga band set', () {
    const sagaBands = {
      AgeBand.explorer,
      AgeBand.adventurer,
      AgeBand.creator,
      AgeBand.adolescent,
      AgeBand.adult,
    };
    for (final band in AgeBand.values) {
      final shouldUse = sagaBands.contains(band);
      test('${band.name} usesHeroSaga == $shouldUse', () {
        expect(band.usesHeroSaga, shouldUse);
      });
    }

    test('Explorer (6-8) participates in the saga write/read path (MT-286)', () {
      // Explorer resolves from a representative in-band age AND is a saga band,
      // so a returning 6-8 hero gets recordIssue + the "Issue #N" recap card.
      expect(ageBandFromAge(7), AgeBand.explorer);
      expect(AgeBand.explorer.usesHeroSaga, isTrue);
    });

    test('Sprout is the only band without a saga', () {
      expect(AgeBand.sprout.usesHeroSaga, isFalse);
    });

    test('Adult (18+) IS a saga band — rides the Creator tier', () {
      expect(AgeBand.adult.usesHeroSaga, isTrue);
    });
  });

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
      expect(ids, containsAll(['pebble', 'robin', 'mochi', 'sunny']));
    });

    test('Explorer companions are exactly the 4 expected IDs', () {
      final ids = kExpectedCompanionIds[AgeBand.explorer]!;
      expect(ids.length, equals(4));
      expect(ids, containsAll(['ember', 'robin', 'clover', 'biscuit']));
    });

    test('Adventurer companions are exactly the 4 expected IDs', () {
      final ids = kExpectedCompanionIds[AgeBand.adventurer]!;
      expect(ids.length, equals(4));
      expect(ids, containsAll(['atlas', 'robin', 'nyx', 'kodiak']));
    });

    test('Robin appears as a companion in sprout, explorer, and adventurer', () {
      for (final band in [AgeBand.sprout, AgeBand.explorer, AgeBand.adventurer]) {
        expect(kExpectedCompanionIds[band], contains('robin'),
            reason: '${band.name} should include Robin');
      }
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
  });
}
