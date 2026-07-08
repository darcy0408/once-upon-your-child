// Registry + age-register integrity for the coping-technique library.
//
// Pins the young/teen split added with the Creator/Adolescent "Reset kit":
// which set each age receives, id resolution across both sets, and the
// 13+ copy-register accessors, so content edits can't silently hand a
// 15-year-old Dragon's Breath or a 7-year-old the Physiological Sigh.

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/data/coping_techniques.dart';

void main() {
  group('copingTechniquesForAge', () {
    test('under-13 gets the young set (Adventurer top edge included)', () {
      for (final age in [6, 8, 10, 12]) {
        final set = copingTechniquesForAge(age);
        expect(set, same(allCopingTechniques), reason: 'age $age');
        expect(set.map((t) => t.id), contains('dragon_breath'));
        expect(set.map((t) => t.id), isNot(contains('box_breath')));
      }
    });

    test('13+ gets the teen set with no cartoon-register techniques', () {
      for (final age in [13, 15, 17]) {
        final set = copingTechniquesForAge(age);
        expect(set, same(teenCopingTechniques), reason: 'age $age');
        expect(
          set.map((t) => t.id),
          containsAll(
              ['box_breath', 'physio_sigh', 'body_scan', 'grounding_54321']),
        );
        expect(set.map((t) => t.id), isNot(contains('dragon_breath')));
        expect(set.map((t) => t.id), isNot(contains('hot_cocoa_breath')));
      }
    });

    test('threshold matches the Creator band floor', () {
      expect(teenCopingAge, 13);
      expect(copingTechniquesForAge(12), same(allCopingTechniques));
      expect(copingTechniquesForAge(13), same(teenCopingTechniques));
    });
  });

  group('copingById', () {
    test('resolves ids from both sets', () {
      for (final t in [...allCopingTechniques, ...teenCopingTechniques]) {
        expect(copingById(t.id), same(t), reason: t.id);
      }
    });

    test('returns null for unknown ids', () {
      expect(copingById('nonexistent'), isNull);
    });

    test('ids are unique across the union of both sets', () {
      final union = {...allCopingTechniques, ...teenCopingTechniques};
      final ids = union.map((t) => t.id).toSet();
      expect(ids.length, union.length);
    });
  });

  group('age-register copy accessors', () {
    test('5-4-3-2-1 swaps to teen copy at 13, keeps young copy below', () {
      final g = copingById('grounding_54321')!;
      expect(g.taglineForAge(10), g.tagline);
      expect(g.descriptionForAge(10), g.description);
      expect(g.taglineForAge(13), g.olderTagline);
      expect(g.descriptionForAge(15), g.olderDescription);
      expect(g.olderTagline, isNotNull);
      expect(g.olderDescription, isNotNull);
    });

    test('techniques without teen overrides fall back to base copy', () {
      final box = copingById('box_breath')!;
      expect(box.taglineForAge(15), box.tagline);
      expect(box.descriptionForAge(15), box.description);
    });

    test('existing olderName behavior unchanged (swap at 9)', () {
      final belly = copingById('belly_breath')!;
      expect(belly.nameForAge(8), 'Belly Breath');
      expect(belly.nameForAge(9), 'Steady Breath');
    });
  });

  group('technique integrity (both sets)', () {
    final union = {...allCopingTechniques, ...teenCopingTechniques};

    test('every technique has steps, copy, and at least one cycle', () {
      for (final t in union) {
        expect(t.steps, isNotEmpty, reason: t.id);
        expect(t.cycles, greaterThanOrEqualTo(1), reason: t.id);
        expect(t.tagline, isNotEmpty, reason: t.id);
        expect(t.description, isNotEmpty, reason: t.id);
        expect(t.emoji, isNotEmpty, reason: t.id);
      }
    });

    test('total practice time stays inside an attention span (< 3.5 min)',
        () {
      for (final t in union) {
        expect(t.totalDuration, greaterThan(Duration.zero), reason: t.id);
        expect(
          t.totalDuration,
          lessThan(const Duration(minutes: 3, seconds: 30)),
          reason: t.id,
        );
      }
    });

    test('breath techniques exhale at least as long as they inhale', () {
      // Down-regulation basics: for every breathing technique the summed
      // exhale time per cycle must be >= the summed inhale time.
      for (final t in union) {
        final inhale = t.steps
            .where((s) => s.action == CopingAction.breatheIn)
            .fold(Duration.zero, (sum, s) => sum + s.duration);
        final exhale = t.steps
            .where((s) => s.action == CopingAction.breatheOut)
            .fold(Duration.zero, (sum, s) => sum + s.duration);
        if (inhale == Duration.zero) continue; // prompt-only techniques
        expect(exhale, greaterThanOrEqualTo(inhale), reason: t.id);
      }
    });
  });
}
