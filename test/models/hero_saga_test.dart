// Unit tests for the HeroSaga continuity model (MT-235 Phase 2).
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/hero_saga.dart';

void main() {
  final fixedNow = DateTime(2026, 6, 8, 12);

  Map<String, dynamic> sagaState({
    String nemesis = 'the Optimizer',
    String status = 'still-at-large',
    String changed = 'the transit grid trusts Mastermind now',
    String hook = 'a second Optimizer node went dark in the harbor',
  }) =>
      {
        'nemesis': nemesis,
        'nemesis_status': status,
        'what_changed': changed,
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
