// Plain Dart stub of AvatarCacheEntry for web. No Isar annotations and no
// `part` of a generated `.g.dart` file, so the JS-incompatible 64-bit ID
// literals never reach `dart compile js`. The web stub in
// `isar_service_stub.dart` backs this with SharedPreferences.

class AvatarCacheEntry {
  int id = 0;
  late String cacheKey;
  late String svgString;
  late DateTime createdAt;
  late String schemaVersion;
  late String style;
  late String seed;
  String? optionsJson;
  String? ageTier;
  int? characterAge;
  DateTime? lastAccessedAt;

  AvatarCacheEntry();

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

  void markAccessed() {
    lastAccessedAt = DateTime.now();
  }

  bool isStale({required int maxAgeDays}) {
    final age = DateTime.now().difference(createdAt);
    return age.inDays > maxAgeDays;
  }

  bool hasValidSchema(String currentSchemaVersion) {
    return schemaVersion == currentSchemaVersion;
  }

  @override
  String toString() {
    return 'AvatarCacheEntry(key: $cacheKey, style: $style, seed: $seed, '
        'tier: $ageTier, age: ${createdAt.toIso8601String()})';
  }
}
