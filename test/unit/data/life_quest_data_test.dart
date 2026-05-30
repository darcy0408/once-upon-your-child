// Graph-integrity tests for the pre-built Life Quest library.
//
// These guard every quest (including the MT-199 Adventurer "Standing On Your
// Own" ladder and the review-pending tier-3/4 quests) against broken segment
// links, dangling choices, malformed endings, and unreachable segments.

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/data/life_quest_data.dart';

void main() {
  // Every quest the app can surface, plus the gated review-pending ones — they
  // must all be structurally valid even before they go live.
  final allQuests = <LifeQuestScenario>[
    ...allLifeQuests,
    ...reviewPendingLifeQuests,
  ];

  group('Life Quest graph integrity', () {
    test('quest ids are unique across live + review-pending', () {
      final ids = allQuests.map((q) => q.id).toList();
      final dupes = ids.where((id) => ids.where((o) => o == id).length > 1).toSet();
      expect(dupes, isEmpty, reason: 'Duplicate quest ids: $dupes');
    });

    for (final quest in allQuests) {
      group('quest "${quest.id}"', () {
        test('has a start segment that exists', () {
          expect(
            quest.segments.containsKey(quest.startSegmentId),
            isTrue,
            reason: '${quest.id}: startSegmentId "${quest.startSegmentId}" '
                'not found in segments',
          );
        });

        test('has non-empty emotions and a start, and segment keys match ids', () {
          expect(quest.emotions, isNotEmpty, reason: '${quest.id}: no emotions');
          expect(quest.segments, isNotEmpty, reason: '${quest.id}: no segments');
          quest.segments.forEach((key, seg) {
            expect(seg.id, key,
                reason: '${quest.id}: segment map key "$key" != segment.id '
                    '"${seg.id}"');
          });
        });

        test('every choice points at a real segment', () {
          for (final seg in quest.segments.values) {
            for (final choice in seg.choices) {
              expect(
                quest.segments.containsKey(choice.nextSegmentId),
                isTrue,
                reason: '${quest.id}: segment "${seg.id}" choice '
                    '"${choice.id}" -> missing segment '
                    '"${choice.nextSegmentId}"',
              );
            }
          }
        });

        test('endings have no choices; non-endings have at least one', () {
          for (final seg in quest.segments.values) {
            if (seg.isEnding) {
              expect(seg.choices, isEmpty,
                  reason: '${quest.id}: ending "${seg.id}" still has choices');
            } else {
              expect(seg.choices, isNotEmpty,
                  reason: '${quest.id}: non-ending "${seg.id}" has no choices '
                      '(dead end)');
            }
          }
        });

        test('all segments are reachable from the start', () {
          final reachable = <String>{};
          final stack = <String>[quest.startSegmentId];
          while (stack.isNotEmpty) {
            final id = stack.removeLast();
            if (!reachable.add(id)) continue;
            final seg = quest.segments[id];
            if (seg == null) continue;
            for (final choice in seg.choices) {
              stack.add(choice.nextSegmentId);
            }
          }
          final orphans = quest.segments.keys.toSet().difference(reachable);
          expect(orphans, isEmpty,
              reason: '${quest.id}: unreachable segments: $orphans');
        });

        test('at least one ending is reachable', () {
          final hasEnding = quest.segments.values.any((s) => s.isEnding);
          expect(hasEnding, isTrue,
              reason: '${quest.id}: no ending segment');
        });
      });
    }
  });

  group('MT-199 Standing-On-Your-Own ladder', () {
    test('tier 1-2 quests are LIVE', () {
      final liveIds = allLifeQuests.map((q) => q.id).toSet();
      expect(liveIds, containsAll(<String>['pick_a_side', 'the_dare']));
    });

    test('tier 3-4 quests are LIVE after owner review (2026-05-30)', () {
      final liveIds = allLifeQuests.map((q) => q.id).toSet();
      expect(
        liveIds,
        containsAll(<String>['the_offer', 'the_ride_home', 'the_secret']),
      );
      // Staging slot is empty now that they've been promoted.
      expect(reviewPendingLifeQuests, isEmpty);
    });
  });
}
