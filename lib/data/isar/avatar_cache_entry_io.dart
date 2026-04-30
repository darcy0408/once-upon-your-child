// ignore_for_file: public_member_api_docs

import 'package:isar/isar.dart';

part 'avatar_cache_entry_io.g.dart';

/// Offline cache for DiceBear avatar SVG strings
///
/// Enables offline-first avatar loading with cache invalidation support.
@collection
class AvatarCacheEntry {
  /// Isar auto-incremented ID
  Id id = Isar.autoIncrement;

  /// Unique cache key: hash of (style + seed + normalized options + schema version)
  ///
  /// This is the primary lookup key and must be indexed for performance.
  /// Format: sha256(style|seed|options_json|schemaVersion)
  @Index(unique: true, replace: true)
  late String cacheKey;

  /// SVG string content (stored as text, no size limit needed)
  late String svgString;

  /// Timestamp when cached
  late DateTime createdAt;

  /// Schema version hash from allowlists.json
  ///
  /// Used for cache invalidation when schema changes.
  late String schemaVersion;

  /// DiceBear style name (e.g., "adventurer")
  late String style;

  /// Random seed used for this avatar
  late String seed;

  /// Normalized options JSON (sorted keys for consistent hashing)
  ///
  /// Stored for debugging/auditing purposes.
  String? optionsJson;

  /// Age tier used (kid, teenPlus, adultPlus)
  String? ageTier;

  /// Character age when generated (optional metadata)
  int? characterAge;

  /// Last accessed timestamp (for LRU eviction)
  DateTime? lastAccessedAt;

  AvatarCacheEntry();

  /// Create a new cache entry
  factory AvatarCacheEntry.create({
    required String cacheKey,
    required String svgString,
    required String schemaVersion,
    required String style,
    required String seed,
    String? optionsJson,
    String? ageTier,
    int? characterAge,
  }) {
    return AvatarCacheEntry()
      ..cacheKey = cacheKey
      ..svgString = svgString
      ..createdAt = DateTime.now()
      ..schemaVersion = schemaVersion
      ..style = style
      ..seed = seed
      ..optionsJson = optionsJson
      ..ageTier = ageTier
      ..characterAge = characterAge
      ..lastAccessedAt = DateTime.now();
  }

  /// Update last accessed timestamp
  void markAccessed() {
    lastAccessedAt = DateTime.now();
  }

  /// Check if cache entry is stale
  bool isStale({required int maxAgeDays}) {
    final age = DateTime.now().difference(createdAt);
    return age.inDays > maxAgeDays;
  }

  /// Check if schema version matches
  bool hasValidSchema(String currentSchemaVersion) {
    return schemaVersion == currentSchemaVersion;
  }

  @override
  String toString() {
    return 'AvatarCacheEntry(key: $cacheKey, style: $style, seed: $seed, '
        'tier: $ageTier, age: ${createdAt.toIso8601String()})';
  }
}
