// Unit tests for the HeroSaga continuity model (MT-235 Phase 2).
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/hero_saga.dart';

void main() {
  final fixedNow = DateTime(2026, 6, 8, 12);

  Map<String, dynamic> sagaState({
    String nemesis = 'the Optimizer',
    String status = 'still-at-large',
    String changed = 'the transit grid trusts Mastermind now',
    String cost = 'Mastermind burned a friendship to crack the grid',
    String hook = 'a second Optimizer node went dark in the harbor',
  }) =>
      {
        'nemesis': nemesis,
        'nemesis_status': status,
        'what_changed': changed,
        'what_it_cost': cost,
        'next_hook': hook,
      };

  group('a fresh saga (Issue #1)', () {
    test('has no continuity and no prior_saga payload', () {
      const saga = HeroSaga(characterId: 'c1');
      expect(saga.issueNumber, 0);
      expect(saga.hasContinuity, isFalse);
      expect(saga.toPriorSaga(), isNull);
    });
  });

  group('recordIssue', () {
    test('bumps the issue count and captures the emitted saga_state', () {
      const saga = HeroSaga(characterId: 'c1');
      final next = saga.recordIssue(sagaState(), now: fixedNow);

      expect(next.issueNumber, 1);
      expect(next.hasContinuity, isTrue);
      expect(next.nemesis, 'the Optimizer');
      expect(next.nemesisStatus, 'still-at-large');
      expect(next.whatChanged, 'the transit grid trusts Mastermind now');
      expect(next.whatItCost, 'Mastermind burned a friendship to crack the grid');
      expect(next.nextHook, 'a second Optimizer node went dark in the harbor');
      expect(next.updatedAt, fixedNow);
    });

    test('accumulates across issues — count climbs, latest state wins', () {
      final s1 = const HeroSaga(characterId: 'c1').recordIssue(sagaState());
      final s2 = s1.recordIssue(
        sagaState(status: 'stopped-and-accountable', hook: 'the harbor is quiet — too quiet'),
      );
      expect(s2.issueNumber, 2);
      expect(s2.nemesisStatus, 'stopped-and-accountable');
      expect(s2.nextHook, 'the harbor is quiet — too quiet');
    });

    test('blank or missing fields keep the prior value (partial state is safe)', () {
      final s1 = const HeroSaga(characterId: 'c1').recordIssue(sagaState());
      final s2 = s1.recordIssue({'nemesis_status': 'reconsidered', 'next_hook': '   '});
      // status updated, but nemesis + what_changed + (blank) next_hook retained.
      expect(s2.nemesisStatus, 'reconsidered');
      expect(s2.nemesis, 'the Optimizer');
      expect(s2.whatChanged, 'the transit grid trusts Mastermind now');
      expect(s2.nextHook, 'a second Optimizer node went dark in the harbor');
    });

    test(
        'auto-captures allies + defining_choice emitted in saga_state '
        '(and they survive json round-trip)', () {
      final state = sagaState()
        ..['allies'] = ['Liam', 'Chloe']
        ..['defining_choice'] = 'chose to protect a friend over the cover';
      final saga =
          const HeroSaga(characterId: 'c1').recordIssue(state, now: fixedNow);

      // allies array folded in from saga_state.
      expect(saga.allies, containsAll(<String>['Liam', 'Chloe']));
      // defining_choice folded into keyChoices.
      expect(saga.keyChoices,
          contains('chose to protect a friend over the cover'));

      // Survives persistence.
      final restored = HeroSaga.fromJson('c1', saga.toJson());
      expect(restored.allies, saga.allies);
      expect(restored.keyChoices, saga.keyChoices);
      expect(restored.keyChoices,
          contains('chose to protect a friend over the cover'));
    });

    test(
        'auto-captured allies union with explicit newAllies and guard bad types',
        () {
      final state = sagaState()
        ..['allies'] = ['Chloe', 42, null] // mixed types — only Strings kept
        ..['defining_choice'] = '   '; // blank choice ignored
      final saga = const HeroSaga(characterId: 'c1')
          .recordIssue(state, newAllies: ['Reza']);
      expect(saga.allies, containsAll(<String>['Reza', 'Chloe']));
      expect(saga.allies.contains('42'), isFalse);
      // Blank defining_choice does not add an entry.
      expect(saga.keyChoices, isEmpty);
    });

    test('appends a HeroSagaChapter built from the title + saga_state', () {
      final state = sagaState(
        nemesis: 'the Optimizer',
        status: 'still-at-large',
        cost: 'Mastermind burned a friendship to crack the grid',
      )..['defining_choice'] = 'chose to protect a friend over the cover';
      final saga = const HeroSaga(characterId: 'c1')
          .recordIssue(state, title: '  Grid Lock  ', now: fixedNow);

      expect(saga.chapters.length, 1);
      final ch = saga.chapters.single;
      // Records the NEW issue number (issueNumber + 1 = 1 from a fresh saga).
      expect(ch.issueNumber, 1);
      // Title is trimmed.
      expect(ch.title, 'Grid Lock');
      expect(ch.nemesis, 'the Optimizer');
      expect(ch.nemesisStatus, 'still-at-large');
      expect(ch.cost, 'Mastermind burned a friendship to crack the grid');
      expect(ch.choice, 'chose to protect a friend over the cover');
    });

    test('an empty/whitespace title records a null chapter title', () {
      final saga = const HeroSaga(characterId: 'c1')
          .recordIssue(sagaState(), title: '   ');
      expect(saga.chapters.single.title, isNull);
    });

    test('chapters accumulate one per recorded Issue', () {
      var saga = const HeroSaga(characterId: 'c1');
      saga = saga.recordIssue(sagaState(), title: 'Issue One');
      saga = saga.recordIssue(sagaState(), title: 'Issue Two');
      expect(saga.chapters.length, 2);
      expect(saga.chapters[0].issueNumber, 1);
      expect(saga.chapters[0].title, 'Issue One');
      expect(saga.chapters[1].issueNumber, 2);
      expect(saga.chapters[1].title, 'Issue Two');
    });

    test('chapters survive a toJson -> fromJson round-trip', () {
      final state = sagaState()
        ..['defining_choice'] = 'spared the courier';
      final saga = const HeroSaga(characterId: 'c1')
          .recordIssue(state, title: 'Round Trip', now: fixedNow);
      final restored = HeroSaga.fromJson('c1', saga.toJson());

      expect(restored.chapters.length, 1);
      final ch = restored.chapters.single;
      expect(ch.issueNumber, 1);
      expect(ch.title, 'Round Trip');
      expect(ch.nemesis, saga.chapters.single.nemesis);
      expect(ch.nemesisStatus, saga.chapters.single.nemesisStatus);
      expect(ch.cost, saga.chapters.single.cost);
      expect(ch.choice, 'spared the courier');
    });

    test('chapters are capped to the most recent kSagaChapterCap entries', () {
      var saga = const HeroSaga(characterId: 'c1');
      final total = HeroSaga.kSagaChapterCap + 5;
      for (var i = 0; i < total; i++) {
        saga = saga.recordIssue(sagaState(), title: 'Issue ${i + 1}');
      }
      expect(saga.chapters.length, HeroSaga.kSagaChapterCap);
      // The issueNumber still climbs past the cap (count is independent).
      expect(saga.issueNumber, total);
      // Only the most recent entries survive: oldest kept is issue #6.
      expect(saga.chapters.first.issueNumber, total - HeroSaga.kSagaChapterCap + 1);
      expect(saga.chapters.last.issueNumber, total);
    });

    test('an old JSON blob without chapters loads as an empty list (no throw)', () {
      final saga = HeroSaga.fromJson('c1', {
        'issue_number': 3,
        'nemesis': 'the Optimizer',
        'allies': ['Reza'],
        // no 'chapters' key at all — predates the field.
      });
      expect(saga.chapters, isEmpty);
      expect(saga.issueNumber, 3);
      // A bad-typed chapters value is also tolerated.
      final saga2 = HeroSaga.fromJson('c1', {'chapters': 'nope'});
      expect(saga2.chapters, isEmpty);
    });

    test('merges allies/choices, dedupes, and caps at kSagaListCap', () {
      var saga = const HeroSaga(characterId: 'c1');
      // Two issues add an overlapping ally ("Reza") plus enough to exceed the cap.
      saga = saga.recordIssue(sagaState(),
          heroCode: 'never lie to the people who trust me',
          newAllies: ['Reza', 'Okafor']);
      saga = saga.recordIssue(sagaState(), newAllies: [
        'Reza', // duplicate -> moves to newest, not doubled
        'A', 'B', 'C', 'D', 'E', 'F', 'G',
      ]);
      expect(saga.heroCode, 'never lie to the people who trust me');
      expect(saga.allies.length, HeroSaga.kSagaListCap);
      expect(saga.allies.where((a) => a == 'Reza').length, 1);
      // Oldest distinct ally ("Okafor") was trimmed; newest survive.
      expect(saga.allies.contains('G'), isTrue);
    });
  });

  group('toPriorSaga', () {
    test('uses the backend key names and points at the upcoming issue', () {
      final saga = const HeroSaga(characterId: 'c1').recordIssue(
        sagaState(),
        heroCode: 'protect the overlooked',
        newAllies: ['Reza'],
        newKeyChoices: ['spared the courier'],
      );
      final payload = saga.toPriorSaga()!;
      // Next issue after one completed is #2.
      expect(payload['issue_number'], 2);
      expect(payload['nemesis'], 'the Optimizer');
      expect(payload['nemesis_status'], 'still-at-large');
      expect(payload['what_changed'], isNotNull);
      expect(payload['what_it_cost'], 'Mastermind burned a friendship to crack the grid');
      expect(payload['next_hook'], isNotNull);
      expect(payload['hero_code'], 'protect the overlooked');
      expect(payload['allies'], ['Reza']);
      expect(payload['key_choices'], ['spared the courier']);
    });

    test('omits empty allies/choices keys entirely', () {
      final saga = const HeroSaga(characterId: 'c1').recordIssue(sagaState());
      final payload = saga.toPriorSaga()!;
      expect(payload.containsKey('allies'), isFalse);
      expect(payload.containsKey('key_choices'), isFalse);
      expect(payload.containsKey('hero_code'), isFalse);
    });
  });

  group('json round-trip', () {
    test('survives toJson -> fromJson with all fields intact', () {
      final original = const HeroSaga(characterId: 'c1').recordIssue(
        sagaState(),
        heroCode: 'no shortcuts that cost someone else',
        newAllies: ['Reza', 'Okafor'],
        newKeyChoices: ['exposed the deal'],
        now: fixedNow,
      );
      final restored = HeroSaga.fromJson('c1', original.toJson());
      expect(restored.issueNumber, original.issueNumber);
      expect(restored.nemesis, original.nemesis);
      expect(restored.nemesisStatus, original.nemesisStatus);
      expect(restored.whatChanged, original.whatChanged);
      expect(restored.whatItCost, original.whatItCost);
      expect(restored.nextHook, original.nextHook);
      expect(restored.heroCode, original.heroCode);
      expect(restored.allies, original.allies);
      expect(restored.keyChoices, original.keyChoices);
      expect(restored.toPriorSaga(), original.toPriorSaga());
    });

    test('fromJson tolerates a sparse/garbage blob', () {
      final saga = HeroSaga.fromJson('c1', {'issue_number': 'oops', 'allies': 'nope'});
      expect(saga.issueNumber, 0);
      expect(saga.allies, isEmpty);
      expect(saga.characterId, 'c1');
    });
  });
}
