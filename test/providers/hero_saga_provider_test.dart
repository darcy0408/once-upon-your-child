// MT-235 Phase 2 — tests for the Hero Saga Riverpod wrapper + the send/record
// continuity contract (the returnable saga). These run device-free: the store
// resolves SharedPreferences via getInstance(), which honours
// setMockInitialValues, so the provider + controller exercise real persistence.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:story_weaver_app/models/hero_saga.dart';
import 'package:story_weaver_app/providers/hero_saga_provider.dart';
import 'package:story_weaver_app/services/hero_saga_store.dart';
import 'package:story_weaver_app/screens/wizard_steps/superhero_welcome_back_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('heroSagaProvider', () {
    test('returns null for an empty characterId', () async {
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();
      final saga = await container.read(heroSagaProvider('').future);
      expect(saga, isNull);
    });

    test('returns null when no saga has ever been saved', () async {
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();
      final saga = await container.read(heroSagaProvider('name_nova').future);
      expect(saga, isNull);
    });

    test('loads a previously-persisted saga', () async {
      // Seed a saga directly under the store key (a returning Issue-2 hero).
      final seed = const HeroSaga(
        characterId: 'name_nova',
        issueNumber: 1,
        nemesis: 'The Benefactor',
        nemesisStatus: 'still-at-large',
        nextHook: 'The lights over the harbor flicker out, one by one.',
      );
      SharedPreferences.setMockInitialValues({
        HeroSagaStore.storageKey('name_nova'): json.encode(seed.toJson()),
      });
      final container = makeContainer();

      final saga = await container.read(heroSagaProvider('name_nova').future);
      expect(saga, isNotNull);
      expect(saga!.issueNumber, 1);
      expect(saga.nemesis, 'The Benefactor');
      expect(saga.hasContinuity, isTrue);
    });
  });

  group('HeroSagaController.recordIssue', () {
    test('folds a saga_state forward, persists, and invalidates the watcher',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();

      // Fresh hero → first watch yields null (a clean origin).
      expect(await container.read(heroSagaProvider('name_kit').future), isNull);

      final controller = container.read(heroSagaControllerProvider.notifier);
      final updated = await controller.recordIssue(
        'name_kit',
        {
          'nemesis': 'Nightjar',
          'nemesis_status': 'stopped-and-accountable',
          'what_changed': 'Kit learned a code can cost something.',
          'next_hook': 'A second mask appears in the crowd.',
        },
        heroCode: 'I never trade someone else’s safety for a win.',
      );

      expect(updated.issueNumber, 1);
      expect(updated.nemesis, 'Nightjar');
      expect(updated.nemesisStatus, 'stopped-and-accountable');
      expect(updated.nextHook, 'A second mask appears in the crowd.');
      expect(updated.heroCode, isNotNull);

      // The provider watcher was invalidated → re-read sees the new saga.
      final reread = await container.read(heroSagaProvider('name_kit').future);
      expect(reread, isNotNull);
      expect(reread!.issueNumber, 1);
      expect(reread.nextHook, 'A second mask appears in the crowd.');
    });

    test('a partial saga_state never erases prior continuity', () async {
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();
      final controller = container.read(heroSagaControllerProvider.notifier);

      await controller.recordIssue('name_rey', {
        'nemesis': 'The Mirror',
        'next_hook': 'Hook one.',
      });
      // Second Issue emits no nemesis (model didn't echo it) — it must persist.
      final after = await controller.recordIssue('name_rey', {
        'next_hook': 'Hook two.',
      });

      expect(after.issueNumber, 2);
      expect(after.nemesis, 'The Mirror'); // carried forward
      expect(after.nextHook, 'Hook two.'); // refreshed
    });

    test('delete clears the saga and the watcher', () async {
      final seed = const HeroSaga(characterId: 'name_sam', issueNumber: 2);
      SharedPreferences.setMockInitialValues({
        HeroSagaStore.storageKey('name_sam'): json.encode(seed.toJson()),
      });
      final container = makeContainer();
      expect(
          await container.read(heroSagaProvider('name_sam').future), isNotNull);

      await container
          .read(heroSagaControllerProvider.notifier)
          .delete('name_sam');
      expect(await container.read(heroSagaProvider('name_sam').future), isNull);
    });
  });

  group('toPriorSaga — the SEND payload', () {
    test('is null on Issue #1 (no continuity → a clean origin)', () {
      const fresh = HeroSaga(characterId: 'name_ada');
      expect(fresh.hasContinuity, isFalse);
      expect(fresh.toPriorSaga(), isNull);
    });

    test('emits backend-aligned keys for a returning hero', () {
      const saga = HeroSaga(
        characterId: 'name_ada',
        issueNumber: 2,
        heroCode: 'I protect the overlooked.',
        nemesis: 'The Mirror',
        nemesisStatus: 'reconsidered',
        whatChanged: 'The district trusts Ada now.',
        nextHook: 'A copycat tests that trust.',
        allies: ['Mara', 'the night dispatcher'],
        keyChoices: ['spared the courier'],
      );
      final payload = saga.toPriorSaga();
      expect(payload, isNotNull);
      // issue_number is the UPCOMING Issue (completed + 1).
      expect(payload!['issue_number'], 3);
      expect(payload['nemesis'], 'The Mirror');
      expect(payload['nemesis_status'], 'reconsidered');
      expect(payload['what_changed'], 'The district trusts Ada now.');
      expect(payload['next_hook'], 'A copycat tests that trust.');
      expect(payload['hero_code'], 'I protect the overlooked.');
      expect(payload['allies'], contains('Mara'));
      expect(payload['key_choices'], contains('spared the courier'));
    });
  });

  group('saga_state extraction — the RECORD shape (mirrors magic_review_step)',
      () {
    // The story-result handler reads result.superheroMeta['saga_state'] (a Map)
    // and folds it forward. This asserts that contract end-to-end through the
    // store, including the Map<dynamic,dynamic> → Map<String,dynamic> coercion
    // the handler performs.
    test('a Map saga_state from superheroMeta records correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final store = HeroSagaStore();

      // Simulate the loosely-typed map that arrives off the JSON envelope.
      final Map<String, dynamic> superheroMeta = {
        'villain_id': 'the_benefactor',
        'problem_id': 'blackout',
        'saga_state': <dynamic, dynamic>{
          'nemesis': 'The Benefactor',
          'nemesis_status': 'still-at-large',
          'next_hook': 'The grid is only the first system to fall.',
        },
      };

      final rawSaga = superheroMeta['saga_state'];
      expect(rawSaga, isA<Map>());
      final sagaState = Map<String, dynamic>.from(rawSaga as Map);

      final saga = await store.recordIssue('name_io', sagaState);
      expect(saga.nemesis, 'The Benefactor');
      expect(saga.nemesisStatus, 'still-at-large');
      expect(saga.nextHook, 'The grid is only the first system to fall.');
      expect(saga.issueNumber, 1);
    });
  });

  group('humanizeNemesisStatus — the recap UI label', () {
    test('maps the backend vocabulary to teen-appropriate phrasing', () {
      expect(
        SuperheroWelcomeBackScreen.humanizeNemesisStatus('reconsidered'),
        'had a change of heart',
      );
      expect(
        SuperheroWelcomeBackScreen.humanizeNemesisStatus(
            'stopped-and-accountable'),
        'was stopped and held accountable',
      );
      expect(
        SuperheroWelcomeBackScreen.humanizeNemesisStatus('still-at-large'),
        'is still out there',
      );
      // Unknown / null degrade gracefully.
      expect(
        SuperheroWelcomeBackScreen.humanizeNemesisStatus('some-other-state'),
        'some other state',
      );
      expect(SuperheroWelcomeBackScreen.humanizeNemesisStatus(null), '');
    });
  });
}
