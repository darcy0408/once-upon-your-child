// Hero-mode profile provider — persists costume + power per child and keeps
// rolling "recent villains/problems" lists so the backend doesn't repeat.
//
// Storage notes
// -------------
// Backed by [SharedPreferences] under a single JSON-encoded key per child
// (`hero_profile_<characterId>`). This is platform-agnostic (web + native)
// and avoids the build_runner dependency that direct Isar registration
// would introduce. The Isar-backed [HeroProfileLocal] schema lives at
// `lib/models/local/hero_profile_local_io.dart` for a future migration —
// it is intentionally not wired into [IsarService] yet.
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local/hero_profile_local.dart';

part 'hero_profile_provider.g.dart';

/// Hard cap on the rolling no-repeat lists. Picked to span ~4–5 stories at
/// the upper bound of the villain/problem matrix (8 villains × 5 problems).
const int kHeroRecentListCap = 8;

String _storageKey(String characterId) => 'hero_profile_$characterId';

HeroProfileLocal _decode(String characterId, String? raw) {
  final profile = HeroProfileLocal()
    ..characterId = characterId
    ..createdAt = DateTime.now()
    ..updatedAt = DateTime.now();
  if (raw == null || raw.isEmpty) return profile;
  try {
    final map = json.decode(raw);
    if (map is! Map<String, dynamic>) return profile;
    profile.costumeColor = map['costume_color'] as String?;
    profile.capeStyle = map['cape_style'] as String?;
    profile.emblem = map['emblem'] as String?;
    profile.power = map['power'] as String?;
    profile.heroName = map['hero_name'] as String?;
    final created = map['created_at'] as String?;
    final updated = map['updated_at'] as String?;
    if (created != null) {
      profile.createdAt = DateTime.tryParse(created) ?? profile.createdAt;
    }
    if (updated != null) {
      profile.updatedAt = DateTime.tryParse(updated) ?? profile.updatedAt;
    }
    final rv = map['recent_villains'];
    if (rv is List) {
      profile.recentVillains = rv.whereType<String>().toList();
    }
    final rp = map['recent_problems'];
    if (rp is List) {
      profile.recentProblems = rp.whereType<String>().toList();
    }
  } catch (_) {
    // Malformed JSON — fall back to the empty profile we already built.
  }
  return profile;
}

Map<String, dynamic> _encode(HeroProfileLocal p) => {
      'character_id': p.characterId,
      'costume_color': p.costumeColor,
      'cape_style': p.capeStyle,
      'emblem': p.emblem,
      'power': p.power,
      'hero_name': p.heroName,
      'created_at': p.createdAt.toIso8601String(),
      'updated_at': p.updatedAt.toIso8601String(),
      'recent_villains': p.recentVillains,
      'recent_problems': p.recentProblems,
    };

/// Loads the [HeroProfileLocal] for the given [characterId], returning
/// `null` when no profile has ever been saved (distinct from an empty
/// profile with all-null costume slots).
@riverpod
Future<HeroProfileLocal?> heroProfile(
  HeroProfileRef ref,
  String characterId,
) async {
  if (characterId.isEmpty) return null;
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_storageKey(characterId));
  if (raw == null) return null;
  return _decode(characterId, raw);
}

/// CRUD controller for hero profiles. Use [HeroProfileController]'s
/// methods rather than touching SharedPreferences directly.
@riverpod
class HeroProfileController extends _$HeroProfileController {
  @override
  void build() {
    // Stateless controller — operations are explicit.
  }

  /// Persists [profile]. Stamps [HeroProfileLocal.updatedAt] to now and
  /// invalidates any in-flight [heroProfileProvider] watcher for the same
  /// `characterId`.
  Future<void> save(HeroProfileLocal profile) async {
    if (profile.characterId.isEmpty) {
      throw ArgumentError('HeroProfileLocal.characterId must be set before save()');
    }
    profile.updatedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(profile.characterId),
      json.encode(_encode(profile)),
    );
    ref.invalidate(heroProfileProvider(profile.characterId));
  }

  /// Loads-or-creates a profile, mutates with [update], saves, returns it.
  Future<HeroProfileLocal> upsert(
    String characterId,
    void Function(HeroProfileLocal) update,
  ) async {
    if (characterId.isEmpty) {
      throw ArgumentError('characterId must not be empty');
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(characterId));
    final profile = raw == null
        ? (HeroProfileLocal()
          ..characterId = characterId
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now())
        : _decode(characterId, raw);
    update(profile);
    await save(profile);
    return profile;
  }

  /// Appends [villainId] to the rolling no-repeat list, dedupes, and trims
  /// to [kHeroRecentListCap]. Newest entry ends up last.
  Future<void> pushRecentVillain(String characterId, String villainId) async {
    if (characterId.isEmpty || villainId.isEmpty) return;
    await upsert(characterId, (p) {
      final next = List<String>.from(p.recentVillains)
        ..remove(villainId)
        ..add(villainId);
      if (next.length > kHeroRecentListCap) {
        next.removeRange(0, next.length - kHeroRecentListCap);
      }
      p.recentVillains = next;
    });
  }

  /// Appends [problemId] to the rolling no-repeat list, dedupes, and trims
  /// to [kHeroRecentListCap]. Newest entry ends up last.
  Future<void> pushRecentProblem(String characterId, String problemId) async {
    if (characterId.isEmpty || problemId.isEmpty) return;
    await upsert(characterId, (p) {
      final next = List<String>.from(p.recentProblems)
        ..remove(problemId)
        ..add(problemId);
      if (next.length > kHeroRecentListCap) {
        next.removeRange(0, next.length - kHeroRecentListCap);
      }
      p.recentProblems = next;
    });
  }

  /// Deletes the saved profile for [characterId]. No-op if none exists.
  Future<void> delete(String characterId) async {
    if (characterId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(characterId));
    ref.invalidate(heroProfileProvider(characterId));
  }
}
