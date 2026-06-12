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
    test('Explorer + Adventurer + Adolescent pools are non-empty and distinct '
        'sets', () {
      expect(HeroFunnyNameGenerator.explorerNames, isNotEmpty);
      expect(HeroFunnyNameGenerator.adventurerNames, isNotEmpty);
      expect(HeroFunnyNameGenerator.adolescentNames, isNotEmpty);

      // No duplicates within each pool.
      expect(
        HeroFunnyNameGenerator.explorerNames.toSet().length,
        HeroFunnyNameGenerator.explorerNames.length,
      );
      expect(
        HeroFunnyNameGenerator.adventurerNames.toSet().length,
        HeroFunnyNameGenerator.adventurerNames.length,
      );
      expect(
        HeroFunnyNameGenerator.adolescentNames.toSet().length,
        HeroFunnyNameGenerator.adolescentNames.length,
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

    test('explorer, adventurer, and adolescent registers draw from different '
        'pools', () {
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
      final ado = HeroFunnyNameGenerator.pickNames(
        HeroNameRegister.adolescent,
        count: 99,
        random: Random(1),
      );
      expect(exp.toSet(), HeroFunnyNameGenerator.explorerNames.toSet());
      expect(adv.toSet(), HeroFunnyNameGenerator.adventurerNames.toSet());
      expect(ado.toSet(), HeroFunnyNameGenerator.adolescentNames.toSet());
    });

    test('Adolescent pool reads neo-noir — contains the spec exemplars', () {
      // Codenames called out in the antihero design brief must be present so a
      // 15-17 never sees the wholesome Explorer/Adventurer names.
      expect(
        HeroFunnyNameGenerator.adolescentNames,
        containsAll(<String>['Nightjar', 'Halflight']),
      );
    });

    test('Adolescent pickNames returns DISTINCT names only from its pool', () {
      final names = HeroFunnyNameGenerator.pickNames(
        HeroNameRegister.adolescent,
        count: 3,
        random: Random(42),
      );
      expect(names.length, 3);
      expect(names.toSet().length, 3, reason: 'names must be distinct');
      for (final n in names) {
        expect(HeroFunnyNameGenerator.adolescentNames, contains(n));
      }
    });

    test('Adolescent pickNames is deterministic for a fixed seed', () {
      final a = HeroFunnyNameGenerator.pickNames(
        HeroNameRegister.adolescent,
        count: 3,
        random: Random(7),
      );
      final b = HeroFunnyNameGenerator.pickNames(
        HeroNameRegister.adolescent,
        count: 3,
        random: Random(7),
      );
      expect(a, b);
    });
  });
}
