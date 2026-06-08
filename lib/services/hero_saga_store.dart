// Per-child persistence for [HeroSaga], mirroring hero_profile_provider's
// SharedPreferences-JSON-per-character approach (one key per child). Kept as a
// plain store rather than a `@riverpod` provider so it is trivially unit-
// testable without build_runner; the Riverpod wrapper lands alongside the
// request/response wiring (MT-235 Phase 2, next chunk).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hero_saga.dart';

class HeroSagaStore {
  /// Pass a [prefs] instance in tests; production resolves it lazily.
  HeroSagaStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  static String storageKey(String characterId) => 'hero_saga_$characterId';

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Loads the saga for [characterId], or null if none has been saved (or the
  /// stored blob is unreadable — a corrupt entry never throws).
  Future<HeroSaga?> load(String characterId) async {
    if (characterId.isEmpty) return null;
    final raw = (await _p).getString(storageKey(characterId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return HeroSaga.fromJson(characterId, decoded);
    } catch (_) {
      return null;
    }
  }

  /// Persists [saga] under its character key.
  Future<void> save(HeroSaga saga) async {
    if (saga.characterId.isEmpty) {
      throw ArgumentError('HeroSaga.characterId must be set before save()');
    }
    await (await _p)
        .setString(storageKey(saga.characterId), json.encode(saga.toJson()));
  }

  /// Loads-or-creates the saga, folds in a completed Issue's emitted
  /// [sagaState], persists it, and returns the updated saga. This is the single
  /// call a story-result handler makes after a Creator superhero Issue lands.
  Future<HeroSaga> recordIssue(
    String characterId,
    Map<String, dynamic> sagaState, {
    String? heroCode,
    List<String> newAllies = const [],
    List<String> newKeyChoices = const [],
  }) async {
    final current =
        await load(characterId) ?? HeroSaga(characterId: characterId);
    final updated = current.recordIssue(
      sagaState,
      heroCode: heroCode,
      newAllies: newAllies,
      newKeyChoices: newKeyChoices,
    );
    await save(updated);
    return updated;
  }

  /// Removes the saved saga for [characterId]. No-op if none exists.
  Future<void> delete(String characterId) async {
    if (characterId.isEmpty) return;
    await (await _p).remove(storageKey(characterId));
  }
}
