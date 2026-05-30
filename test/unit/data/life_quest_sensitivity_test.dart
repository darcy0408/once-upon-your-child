// MT-158 / content-safety audit F-08 + F-16 — sensitivity metadata on the
// Life Quest data model.
//
// These tests pin TWO things:
//   1. The new fields are backwards-compatible — existing const scenarios
//      that don't set them still construct cleanly with empty/null defaults.
//   2. The five sensitive quests called out by the audit each carry the
//      metadata so the screen has something to surface on the interstitial.

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/data/life_quest_data.dart';

void main() {
  group('LifeQuestScenario sensitivity metadata (MT-158)', () {
    test('defaults are empty list + null — backwards compatible', () {
      const scenario = LifeQuestScenario(
        id: 'test',
        title: 'Test',
        hook: 'hook',
        emoji: '*',
        emotions: ['happy'],
        startSegmentId: 't_start',
        segments: {
          't_start': QuestSegment(
            id: 't_start',
            content: 'body',
            isEnding: true,
          ),
        },
      );

      expect(scenario.sensitivityTopics, isEmpty);
      expect(scenario.parentNote, isNull);
    });

    test('scenarios can opt in to sensitivity metadata', () {
      const scenario = LifeQuestScenario(
        id: 'test',
        title: 'Test',
        hook: 'hook',
        emoji: '*',
        emotions: ['sad'],
        startSegmentId: 't_start',
        segments: {
          't_start': QuestSegment(
            id: 't_start',
            content: 'body',
            isEnding: true,
          ),
        },
        sensitivityTopics: ['breakup', 'heartbreak'],
        parentNote: 'Heads up — this story is about a breakup.',
      );

      expect(scenario.sensitivityTopics, ['breakup', 'heartbreak']);
      expect(scenario.parentNote, isNotNull);
    });

    // Each of these five quests is called out as sensitive in the audit
    // (`audit-reports/02-content-safety-20260519.md` F-08 + F-16). Pin each
    // so a future content edit can't silently strip the metadata.
    final sensitiveQuestIds = <String>{
      'family_stress',
      'someone_needs_help',
      'the_fight_at_home',
      'after_the_breakup',
      'the_screenshot',
    };

    test('all five audit-flagged sensitive quests carry metadata', () {
      for (final id in sensitiveQuestIds) {
        final quest = allLifeQuests.firstWhere(
          (q) => q.id == id,
          orElse: () => throw StateError('Quest $id not found in registry'),
        );
        expect(
          quest.sensitivityTopics,
          isNotEmpty,
          reason: 'Quest $id should carry sensitivityTopics (audit F-08)',
        );
        expect(
          quest.parentNote,
          isNotNull,
          reason: 'Quest $id should carry parentNote (audit F-08)',
        );
        expect(
          quest.parentNote!.trim(),
          isNotEmpty,
          reason: 'Quest $id parentNote should not be blank',
        );
      }
    });

    test('non-sensitive quests do NOT carry metadata (sanity)', () {
      // Pick a few that the audit does NOT flag.
      const benignIds = ['big_bear_hug', 'left_out', 'sleepover'];
      for (final id in benignIds) {
        final quest = allLifeQuests.firstWhere(
          (q) => q.id == id,
          orElse: () => throw StateError('Quest $id not found in registry'),
        );
        expect(
          quest.sensitivityTopics,
          isEmpty,
          reason: 'Quest $id should NOT carry sensitivityTopics by default',
        );
        expect(
          quest.parentNote,
          isNull,
          reason: 'Quest $id should NOT carry parentNote by default',
        );
      }
    });
  });
}
