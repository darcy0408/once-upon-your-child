// Structural integrity for every Life Quest in the registry.
//
// Catches the classic content-authoring bugs: a choice pointing at a segment
// id that doesn't exist, an unreachable orphan segment, an ending that still
// has choices (or a non-ending with none), and a copingBreakId that doesn't
// resolve to a real technique. Added alongside the 2026-05-30 age-band review,
// which introduced two new Adventurer quests (owning_up, friend_got_picked)
// and restricted The Big Test (school_stress) away from the Adventurer band.

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/data/coping_techniques.dart';
import 'package:story_weaver_app/data/life_quest_data.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

void main() {
  group('Life Quest link integrity', () {
    test('startSegmentId resolves and segment keys match their id', () {
      for (final quest in allLifeQuests) {
        expect(
          quest.segments.containsKey(quest.startSegmentId),
          isTrue,
          reason: '${quest.id}: startSegmentId "${quest.startSegmentId}" '
              'is not in segments',
        );
        quest.segments.forEach((key, seg) {
          expect(seg.id, key,
              reason: '${quest.id}: map key "$key" != segment.id "${seg.id}"');
        });
      }
    });

    test('every choice points at a real segment', () {
      for (final quest in allLifeQuests) {
        for (final seg in quest.segments.values) {
          for (final choice in seg.choices) {
            expect(
              quest.segments.containsKey(choice.nextSegmentId),
              isTrue,
              reason: '${quest.id}/${seg.id}: choice "${choice.id}" points at '
                  'missing segment "${choice.nextSegmentId}"',
            );
          }
        }
      }
    });

    test('endings have no choices; non-endings have at least one', () {
      for (final quest in allLifeQuests) {
        for (final seg in quest.segments.values) {
          if (seg.isEnding) {
            expect(seg.choices, isEmpty,
                reason: '${quest.id}/${seg.id}: ending segment has choices');
          } else {
            expect(seg.choices, isNotEmpty,
                reason: '${quest.id}/${seg.id}: non-ending segment is a dead '
                    'end (no choices, not marked isEnding)');
          }
        }
      }
    });

    test('no unreachable segments', () {
      for (final quest in allLifeQuests) {
        final reachable = <String>{quest.startSegmentId};
        final stack = <String>[quest.startSegmentId];
        while (stack.isNotEmpty) {
          final seg = quest.segments[stack.removeLast()];
          if (seg == null) continue;
          for (final choice in seg.choices) {
            if (reachable.add(choice.nextSegmentId)) {
              stack.add(choice.nextSegmentId);
            }
          }
        }
        final orphans = quest.segments.keys.toSet().difference(reachable);
        expect(orphans, isEmpty,
            reason: '${quest.id}: unreachable segment(s) $orphans');
      }
    });

    test('every copingBreakId resolves to a real technique', () {
      for (final quest in allLifeQuests) {
        for (final seg in quest.segments.values) {
          final id = seg.copingBreakId;
          if (id != null) {
            expect(copingById(id), isNotNull,
                reason: '${quest.id}/${seg.id}: copingBreakId "$id" not found');
          }
        }
      }
    });
  });

  group('Age-band review 2026-05-30 (L-01 + new Adventurer quests)', () {
    test('new Adventurer quests are registered for the Adventurer band', () {
      for (final id in ['owning_up', 'friend_got_picked']) {
        final quest = allLifeQuests.firstWhere(
          (q) => q.id == id,
          orElse: () => throw StateError('$id missing from registry'),
        );
        expect(quest.recommendedBands, contains(AgeBand.adventurer),
            reason: '$id should be available to Adventurer (9-11)');
      }
    });

    test('The Big Test no longer reaches the Adventurer band', () {
      final bigTest =
          allLifeQuests.firstWhere((q) => q.id == 'school_stress');
      expect(
        bigTest.recommendedBands,
        isNot(contains(AgeBand.adventurer)),
        reason: 'The Big Test cram framing was pulled from Adventurer (L-01)',
      );
    });
  });
}
