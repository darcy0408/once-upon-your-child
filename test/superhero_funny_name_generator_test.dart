// Tests for the B2 funny-name pools (HeroFunnyNameGenerator).
//
// The Explorer/Adventurer name picker draws from cooler, less-babyish pools
// than the therapeutic SuperheroNameGenerator. These tests pin the pool
// contents, the distinctness/count contract, and seeded determinism.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/superhero_name_generator.dart';

void main() {
  group('HeroFunnyNameGenerator pools', () {
    test('Explorer + Adventurer pools are non-empty and distinct sets', () {
      expect(HeroFunnyNameGenerator.explorerNames, isNotEmpty);
      expect(HeroFunnyNameGenerator.adventurerNames, isNotEmpty);

      // No duplicates within each pool.
      expect(
        HeroFunnyNameGenerator.explorerNames.toSet().length,
        HeroFunnyNameGenerator.explorerNames.length,
      );
      expect(
        HeroFunnyNameGenerator.adventurerNames.toSet().length,
        HeroFunnyNameGenerator.adventurerNames.length,
      );
    });

    test('Adventurer pool reads cooler — contains the spec exemplars', () {
      // Names called out in the design brief must be present so 9-12s never
      // see the babyish therapeutic names.
      expect(
        HeroFunnyNameGenerator.adventurerNames,
        containsAll(<String>['The Quiet Storm', 'Nightcircuit']),
      );
    });

    test('pickNames returns the requested count of DISTINCT names', () {
      final names = HeroFunnyNameGenerator.pickNames(
        HeroNameRegister.adventurer,
        count: 3,
        random: Random(42),
      );
      expect(names.length, 3);
      expect(names.toSet().length, 3, reason: 'names must be distinct');
      // Every result must come from the adventurer pool.
      for (final n in names) {
        expect(HeroFunnyNameGenerator.adventurerNames, contains(n));
      }
    });

    test('pickNames is deterministic for a fixed seed', () {
      final a = HeroFunnyNameGenerator.pickNames(
        HeroNameRegister.explorer,
        count: 3,
        random: Random(7),
      );
      final b = HeroFunnyNameGenerator.pickNames(
        HeroNameRegister.explorer,
        count: 3,
        random: Random(7),
      );
      expect(a, b);
    });

    test('explorer and adventurer registers draw from different pools', () {
      final exp = HeroFunnyNameGenerator.pickNames(
        HeroNameRegister.explorer,
        count: 99, // larger than pool → whole pool back
        random: Random(1),
      );
      final adv = HeroFunnyNameGenerator.pickNames(
        HeroNameRegister.adventurer,
        count: 99,
        random: Random(1),
      );
      expect(exp.toSet(), HeroFunnyNameGenerator.explorerNames.toSet());
      expect(adv.toSet(), HeroFunnyNameGenerator.adventurerNames.toSet());
    });
  });
}
