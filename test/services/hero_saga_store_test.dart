// Unit tests for HeroSagaStore (SharedPreferences persistence, MT-235 Phase 2).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/hero_saga.dart';
import 'package:story_weaver_app/services/hero_saga_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HeroSagaStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = HeroSagaStore(prefs: await SharedPreferences.getInstance());
  });

  const sagaState = {
    'nemesis': 'Nightjar',
    'nemesis_status': 'still-at-large',
    'what_changed': 'the docks lost their watcher',
    'next_hook': 'a coded message reached the mayor',
  };

  test('load returns null when nothing is saved', () async {
    expect(await store.load('c1'), isNull);
  });

  test('save then load round-trips the saga', () async {
    final saga = const HeroSaga(characterId: 'c1').recordIssue(sagaState);
    await store.save(saga);

    final loaded = await store.load('c1');
    expect(loaded, isNotNull);
    expect(loaded!.issueNumber, 1);
    expect(loaded.nemesis, 'Nightjar');
    expect(loaded.nextHook, 'a coded message reached the mayor');
  });

  test('recordIssue persists and accumulates across calls', () async {
    final first = await store.recordIssue('c1', sagaState, heroCode: 'no collateral');
    expect(first.issueNumber, 1);
    expect(first.heroCode, 'no collateral');

    final second = await store.recordIssue('c1', {
      ...sagaState,
      'nemesis_status': 'stopped-and-accountable',
    });
    expect(second.issueNumber, 2);
    expect(second.nemesisStatus, 'stopped-and-accountable');
    // hero_code set on the first issue survives the second fold.
    expect(second.heroCode, 'no collateral');

    // And it's the persisted value, not just the returned one.
    final reloaded = await store.load('c1');
    expect(reloaded!.issueNumber, 2);
    expect(reloaded.toPriorSaga()!['issue_number'], 3);
  });

  test('sagas are isolated per character key', () async {
    await store.recordIssue('hero_a', sagaState);
    expect((await store.load('hero_a'))!.issueNumber, 1);
    expect(await store.load('hero_b'), isNull);
  });

  test('delete removes the saved saga', () async {
    await store.recordIssue('c1', sagaState);
    expect(await store.load('c1'), isNotNull);
    await store.delete('c1');
    expect(await store.load('c1'), isNull);
  });

  test('a corrupt blob loads as null rather than throwing', () async {
    SharedPreferences.setMockInitialValues({
      HeroSagaStore.storageKey('c1'): 'not json at all',
    });
    final freshStore = HeroSagaStore(prefs: await SharedPreferences.getInstance());
    expect(await freshStore.load('c1'), isNull);
  });

  test('save rejects an empty characterId', () async {
    expect(
      () => store.save(const HeroSaga(characterId: '')),
      throwsArgumentError,
    );
  });
}
