// Riverpod wrapper around [HeroSagaStore] — the Creator-band (ages 13-14)
// "Hero Saga" continuity memory (MT-235 Phase 2, the returnable saga).
//
// Mirrors hero_profile_provider's shape: a [heroSaga] FutureProvider.family
// keyed by characterId (read by the welcome-back recap + the send path), plus
// a [HeroSagaController] for the record/delete operations a story-result
// handler invokes. The actual persistence lives in [HeroSagaStore]
// (SharedPreferences, one JSON key per child) so it stays trivially unit-
// testable without a device; this layer just adds Riverpod caching +
// invalidation so the UI rebuilds when a new Issue is folded in.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/hero_saga.dart';
import '../services/hero_saga_store.dart';

part 'hero_saga_provider.g.dart';

/// Loads the persisted [HeroSaga] for [characterId], or null when no Issue has
/// ever been recorded for this hero (a fresh hero → a clean origin, no
/// `prior_saga`). Returns null for an empty id rather than throwing.
///
/// A fresh [HeroSagaStore] is constructed per call (rather than a cached
/// singleton) so it resolves SharedPreferences.getInstance() each time —
/// mirroring hero_profile_provider and keeping the provider honest under
/// SharedPreferences.setMockInitialValues in tests.
@riverpod
Future<HeroSaga?> heroSaga(HeroSagaRef ref, String characterId) async {
  if (characterId.isEmpty) return null;
  return HeroSagaStore().load(characterId);
}

/// Controller exposing the saga mutations a Creator superhero story-result
/// handler needs. Prefer these over touching [HeroSagaStore] directly so the
/// matching [heroSagaProvider] watcher is invalidated and any visible recap
/// rebuilds.
@riverpod
class HeroSagaController extends _$HeroSagaController {
  @override
  void build() {
    // Stateless controller — operations are explicit.
  }

  /// Loads-or-creates the saga, folds a completed Issue's emitted [sagaState]
  /// forward (bumps the Issue count, refreshes nemesis/status/what-changed/
  /// next-hook, optionally stamps the hero's personal [heroCode]), persists it,
  /// invalidates the watcher, and returns the updated saga. This is the single
  /// call the story-result handler makes after a Creator superhero Issue lands.
  Future<HeroSaga> recordIssue(
    String characterId,
    Map<String, dynamic> sagaState, {
    String? heroCode,
    List<String> newAllies = const [],
    List<String> newKeyChoices = const [],
  }) async {
    final updated = await HeroSagaStore().recordIssue(
      characterId,
      sagaState,
      heroCode: heroCode,
      newAllies: newAllies,
      newKeyChoices: newKeyChoices,
    );
    ref.invalidate(heroSagaProvider(characterId));
    return updated;
  }

  /// Removes the saved saga for [characterId] (e.g. "start a fresh saga").
  /// No-op if none exists. Invalidates the watcher so the recap clears.
  Future<void> delete(String characterId) async {
    if (characterId.isEmpty) return;
    await HeroSagaStore().delete(characterId);
    ref.invalidate(heroSagaProvider(characterId));
  }
}
