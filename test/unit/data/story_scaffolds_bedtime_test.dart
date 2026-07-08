// Tests for the bedtime-aware offline scaffold fallback.
//
// The failure mode these guard against: a network hiccup at lights-out used
// to hand the child a normal-energy daytime adventure, because the scaffold
// picker had no notion of bedtime. Now bedtime requests prefer calm
// wind-down scaffolds, and daytime requests must never see them.

import 'package:flutter_test/flutter_test.dart';

import 'package:story_weaver_app/data/story_scaffolds.dart';
import 'package:story_weaver_app/services/story_scaffold_fallback.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

void main() {
  group('pickScaffoldFor bedtime selection', () {
    test('every band gets a bedtime scaffold when bedtime is requested', () {
      for (final band in AgeBand.values) {
        final scaffold = pickScaffoldFor(
          scenarioId: 'Magical Forest',
          band: band,
          bedtime: true,
        );
        expect(scaffold, isNotNull, reason: 'band $band got no scaffold');
        expect(scaffold!.isBedtime, isTrue,
            reason: 'band $band got non-bedtime scaffold ${scaffold.id}');
      }
    });

    test('bedtime selection works for an unrecognised scenario', () {
      final scaffold = pickScaffoldFor(
        scenarioId: 'somewhere entirely made up',
        band: AgeBand.sprout,
        bedtime: true,
      );
      expect(scaffold, isNotNull);
      expect(scaffold!.isBedtime, isTrue);
    });

    test('daytime requests never receive a bedtime scaffold', () {
      for (final band in AgeBand.values) {
        final scaffold = pickScaffoldFor(
          scenarioId: 'volcano_dragons',
          band: band,
        );
        if (scaffold != null) {
          expect(scaffold.isBedtime, isFalse,
              reason: 'daytime pick for $band returned ${scaffold.id}');
        }
      }
    });

    test('young and older bands get age-matched bedtime scaffolds', () {
      final sprout = pickScaffoldFor(
        scenarioId: 'bedtime',
        band: AgeBand.sprout,
        bedtime: true,
      );
      final adolescent = pickScaffoldFor(
        scenarioId: 'bedtime',
        band: AgeBand.adolescent,
        bedtime: true,
      );
      expect(sprout!.id, 'bedtime_young_starlit_meadow');
      expect(adolescent!.id, 'bedtime_older_quiet_harbor');
    });
  });

  group('bedtime scaffold content', () {
    final bedtimeScaffolds =
        allStoryScaffolds.where((s) => s.isBedtime).toList();

    test('library contains the two authored bedtime scaffolds', () {
      expect(bedtimeScaffolds, hasLength(2));
    });

    for (final withCompanion in [true, false]) {
      test(
          'interpolates cleanly ${withCompanion ? 'with' : 'without'} a companion',
          () {
        for (final scaffold in bedtimeScaffolds) {
          final result = buildScaffoldResult(
            scaffold: scaffold,
            name: 'Mira',
            companion: withCompanion ? 'Moon Owl' : '',
            gender: 'Girl',
          );
          expect(result.storyText, contains('Mira'));
          expect(result.storyText.contains('Moon Owl'), withCompanion,
              reason: 'companion presence mismatch in ${scaffold.id}');
          // No unfilled slots or conditional markers may survive.
          expect(result.storyText, isNot(matches(RegExp(r'[{}«»]'))),
              reason: 'leftover interpolation markers in ${scaffold.id}');
          expect(result.title, isNotNull);
          expect(result.title!.trim(), isNotEmpty);
        }
      });
    }

    test('stays inside a calm bedtime word budget', () {
      for (final scaffold in bedtimeScaffolds) {
        final result = buildScaffoldResult(
          scaffold: scaffold,
          name: 'Mira',
          companion: 'Moon Owl',
        );
        final words = result.storyText
            .split(RegExp(r'\s+'))
            .where((w) => w.trim().isNotEmpty)
            .length;
        expect(words, inInclusiveRange(150, 550),
            reason: '${scaffold.id} is $words words');
      }
    });

    test('ends on a sleep transition, not a cliffhanger', () {
      for (final scaffold in bedtimeScaffolds) {
        final ending = scaffold.segments.values
            .where((s) => s.isEnding)
            .map((s) => s.content.toLowerCase())
            .join(' ');
        expect(
          ending.contains('goodnight') ||
              ending.contains('rest well') ||
              ending.contains('sleep'),
          isTrue,
          reason: '${scaffold.id} ending has no sleep transition',
        );
      }
    });
  });
}
