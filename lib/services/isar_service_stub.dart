// Stub implementation of IsarService for web platform
// Web doesn't support Isar (FFI-based database)
// We use SharedPreferences for basic persistence on web

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../models/local/character_local.dart';
import '../models/local/chronicle_local.dart';
import '../models/local/chapter_memory_local.dart';
import '../data/isar/avatar_cache_entry.dart';

// ---------------------------------------------------------------------------
// Shared write-safety helpers for every SharedPreferences-backed stub below.
//
// BUG: each put/delete did getString -> decode -> mutate -> setString with no
// serialization, so concurrent operations on the same key could each read the
// same snapshot and the later setString would silently drop the earlier write.
// setString can also throw QuotaExceededError once localStorage (~5 MB) fills.
// [_synchronized] serializes the full read-modify-write cycle per key, and
// [_quotaSafeSetString] evicts the oldest entry (lowest id) and retries on a
// quota failure instead of throwing.
// ---------------------------------------------------------------------------
final Map<String, Future<void>> _writeLocks = {};

Future<T> _synchronized<T>(String key, Future<T> Function() action) {
  final prev = _writeLocks[key] ?? Future<void>.value();
  final result = prev.then((_) => action());
  _writeLocks[key] = result.then((_) {}, onError: (_) {});
  return result;
}

Future<void> _quotaSafeSetString(
    SharedPreferences prefs, String key, List<dynamic> list) async {
  while (true) {
    try {
      await prefs.setString(key, json.encode(list));
      return;
    } catch (_) {
      // localStorage full — drop the oldest entry (lowest id) and retry. If
      // nothing remains to evict, give up quietly rather than throw.
      if (list.isEmpty) return;
      int oldestIdx = 0;
      int? oldestId;
      for (int i = 0; i < list.length; i++) {
        final id = ((list[i] as Map<String, dynamic>)['id'] as int?) ?? 0;
        if (oldestId == null || id < oldestId) {
          oldestId = id;
          oldestIdx = i;
        }
      }
      list.removeAt(oldestIdx);
    }
  }
}

// Create a stub Isar type that matches the API surface we need
class Isar {
  CharacterLocalsStub get characterLocals => CharacterLocalsStub();
  ChronicleLocalsStub get chronicleLocals => ChronicleLocalsStub();
  ChapterMemoryLocalsStub get chapterMemoryLocals => ChapterMemoryLocalsStub();
  AvatarCacheEntrysStub get avatarCacheEntrys => AvatarCacheEntrysStub();

  /// Generic write transaction — runs callback immediately (no DB transaction on web).
  Future<T> writeTxn<T>(Future<T> Function() callback) async {
    return await callback();
  }

  void close() {}
}

class CharacterLocalsStub {
  static const String _storageKey = 'isar_characters';

  CharacterWhereStub where() => CharacterWhereStub();

  Future<int> put(CharacterLocal character) => _synchronized(_storageKey, () async {
    final prefs = await SharedPreferences.getInstance();
    final String? charactersJson = prefs.getString(_storageKey);
    List<dynamic> characters = charactersJson != null ? json.decode(charactersJson) : [];

    if (character.id == 0) {
      // Simple ID generation for stub
      character.id = DateTime.now().millisecondsSinceEpoch;
    }

    // Find and update or add
    int index = characters.indexWhere((c) => c['id'] == character.id || (character.characterId.isNotEmpty && c['characterId'] == character.characterId));

    final charData = {
      'id': character.id,
      'characterId': character.characterId,
      'name': character.name,
      'age': character.age,
      'avatarUrl': character.avatarUrl,
      'avatarParams': character.avatarParams,
      'isSyncedToServer': character.isSyncedToServer,
      'createdAt': character.createdAt.toIso8601String(),
    };

    if (index >= 0) {
      characters[index] = charData;
    } else {
      characters.add(charData);
    }

    await _quotaSafeSetString(prefs, _storageKey, characters);
    return character.id;
  });

  Future<bool> delete(int id) => _synchronized(_storageKey, () async {
    final prefs = await SharedPreferences.getInstance();
    final String? charactersJson = prefs.getString(_storageKey);
    if (charactersJson == null) return false;

    List<dynamic> characters = json.decode(charactersJson);
    int initialLength = characters.length;
    characters.removeWhere((c) => c['id'] == id);

    if (characters.length != initialLength) {
      await _quotaSafeSetString(prefs, _storageKey, characters);
      return true;
    }
    return false;
  });
}

class CharacterWhereStub {
  Future<List<CharacterLocal>> findAll() async {
    final prefs = await SharedPreferences.getInstance();
    final String? charactersJson = prefs.getString(CharacterLocalsStub._storageKey);
    if (charactersJson == null) return [];

    List<dynamic> charactersData = json.decode(charactersJson);
    return charactersData.map((data) {
      final char = CharacterLocal()
        ..id = data['id'] ?? 0
        ..characterId = data['characterId'] ?? ''
        ..name = data['name'] ?? ''
        ..age = data['age'] ?? 0
        ..avatarUrl = data['avatarUrl']
        ..avatarParams = data['avatarParams']
        ..isSyncedToServer = data['isSyncedToServer'] ?? false
        ..createdAt = data['createdAt'] != null 
            ? DateTime.tryParse(data['createdAt']) ?? DateTime.now() 
            : DateTime.now();
      return char;
    }).toList();
  }
}

class IsarService {
  static Isar? _isar;

  static Future<Isar> getInstance() async {
    _isar ??= Isar();
    return _isar!;
  }

  static Isar get instance {
    _isar ??= Isar();
    return _isar!;
  }

  static Future<List<Character>> getAllCharacters() async {
    final isar = await getInstance();
    final locals = await isar.characterLocals.where().findAll();

    // Map to domain model
    return locals.map((lc) => Character(
      id: lc.characterId,
      name: lc.name,
      age: lc.age,
      role: 'Hero',
    )).toList();
  }

  /// Save a character to local storage
  static Future<void> saveCharacter(CharacterLocal character) async {
    final isar = await getInstance();
    await isar.characterLocals.put(character);
  }

  /// Save multiple characters to local storage (for syncing from API)
  static Future<void> syncCharactersFromApi(List<dynamic> charactersJson) async {
    final isar = await getInstance();
    await isar.writeTxn(() async {
      for (final charJson in charactersJson) {
        final localChar = CharacterLocal.fromJson(charJson);
        await isar.characterLocals.put(localChar);
      }
    });
  }

  static Future<void> close() async {
    _isar = null;
  }
}

// ---------------------------------------------------------------------------
// ChronicleLocal stubs
// ---------------------------------------------------------------------------

class ChronicleLocalsStub {
  static const String _key = 'isar_chronicles';

  ChronicleFilterStub filter() => ChronicleFilterStub();

  Future<int> put(ChronicleLocal chronicle) => _synchronized(_key, () async {
    final prefs = await SharedPreferences.getInstance();
    final List<dynamic> list =
        json.decode(prefs.getString(_key) ?? '[]') as List<dynamic>;

    if (chronicle.id == 0) {
      chronicle.id = DateTime.now().millisecondsSinceEpoch;
    }
    final idx = list.indexWhere((e) => e['id'] == chronicle.id);
    final data = _toMap(chronicle);
    if (idx >= 0) {
      list[idx] = data;
    } else {
      list.add(data);
    }
    await _quotaSafeSetString(prefs, _key, list);
    return chronicle.id;
  });

  static Map<String, dynamic> _toMap(ChronicleLocal c) => {
        'id': c.id,
        'chronicleId': c.chronicleId,
        'characterId': c.characterId,
        'characterName': c.characterName,
        'characterAge': c.characterAge,
        'title': c.title,
        'genre': c.genre,
        'chapterCount': c.chapterCount,
        'isActive': c.isActive,
        'lastPlayedAt': c.lastPlayedAt.toIso8601String(),
        'createdAt': c.createdAt.toIso8601String(),
        'worldFactsJson': c.worldFactsJson,
        'arcSummariesJson': c.arcSummariesJson,
        'recentMemoriesJson': c.recentMemoriesJson,
        'unresolvedThreadsJson': c.unresolvedThreadsJson,
        'characterStateJson': c.characterStateJson,
        'lastChapterEnding': c.lastChapterEnding,
        'lastChoiceMade': c.lastChoiceMade,
      };

  static ChronicleLocal _fromMap(Map<String, dynamic> d) => ChronicleLocal()
    ..id = d['id'] as int? ?? 0
    ..chronicleId = d['chronicleId'] as String? ?? ''
    ..characterId = d['characterId'] as String? ?? ''
    ..characterName = d['characterName'] as String? ?? ''
    ..characterAge = d['characterAge'] as int? ?? 0
    ..title = d['title'] as String? ?? ''
    ..genre = d['genre'] as String? ?? ''
    ..chapterCount = d['chapterCount'] as int? ?? 0
    ..isActive = d['isActive'] as bool? ?? true
    ..lastPlayedAt = DateTime.tryParse(d['lastPlayedAt'] as String? ?? '') ?? DateTime.now()
    ..createdAt = DateTime.tryParse(d['createdAt'] as String? ?? '') ?? DateTime.now()
    ..worldFactsJson = d['worldFactsJson'] as String?
    ..arcSummariesJson = d['arcSummariesJson'] as String?
    ..recentMemoriesJson = d['recentMemoriesJson'] as String?
    ..unresolvedThreadsJson = d['unresolvedThreadsJson'] as String?
    ..characterStateJson = d['characterStateJson'] as String?
    ..lastChapterEnding = d['lastChapterEnding'] as String?
    ..lastChoiceMade = d['lastChoiceMade'] as String?;

  static Future<List<ChronicleLocal>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final List<dynamic> list =
        json.decode(prefs.getString(_key) ?? '[]') as List<dynamic>;
    return list.map((e) => _fromMap(e as Map<String, dynamic>)).toList();
  }
}

class ChronicleFilterStub {
  String? _characterId;
  String? _chronicleId;
  bool? _isActive;

  ChronicleFilterStub characterIdEqualTo(String id) {
    _characterId = id;
    return this;
  }

  ChronicleFilterStub chronicleIdEqualTo(String id) {
    _chronicleId = id;
    return this;
  }

  ChronicleFilterStub and() => this;

  ChronicleFilterStub isActiveEqualTo(bool v) {
    _isActive = v;
    return this;
  }

  ChronicleFilterStub sortByLastPlayedAtDesc() => this;

  Future<List<ChronicleLocal>> findAll() async {
    var list = await ChronicleLocalsStub._loadAll();
    if (_characterId != null) {
      list = list.where((c) => c.characterId == _characterId).toList();
    }
    if (_chronicleId != null) {
      list = list.where((c) => c.chronicleId == _chronicleId).toList();
    }
    if (_isActive != null) {
      list = list.where((c) => c.isActive == _isActive).toList();
    }
    list.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    return list;
  }

  Future<ChronicleLocal?> findFirst() async {
    final list = await findAll();
    return list.isEmpty ? null : list.first;
  }
}

// ---------------------------------------------------------------------------
// ChapterMemoryLocal stubs
// ---------------------------------------------------------------------------

class ChapterMemoryLocalsStub {
  static const String _key = 'isar_chapter_memories';

  ChapterMemoryFilterStub filter() => ChapterMemoryFilterStub();

  Future<int> put(ChapterMemoryLocal m) => _synchronized(_key, () async {
    final prefs = await SharedPreferences.getInstance();
    final List<dynamic> list =
        json.decode(prefs.getString(_key) ?? '[]') as List<dynamic>;

    if (m.id == 0) {
      m.id = DateTime.now().millisecondsSinceEpoch;
    }
    final idx = list.indexWhere((e) => e['id'] == m.id);
    final data = _toMap(m);
    if (idx >= 0) {
      list[idx] = data;
    } else {
      list.add(data);
    }
    await _quotaSafeSetString(prefs, _key, list);
    return m.id;
  });

  static Map<String, dynamic> _toMap(ChapterMemoryLocal m) => {
        'id': m.id,
        'chronicleId': m.chronicleId,
        'chapterNumber': m.chapterNumber,
        'createdAt': m.createdAt.toIso8601String(),
        'summaryBulletsJson': m.summaryBulletsJson,
        'newWorldFactsJson': m.newWorldFactsJson,
        'characterGrowthNote': m.characterGrowthNote,
        'cliffhanger': m.cliffhanger,
        'newThreadsJson': m.newThreadsJson,
        'resolvedThreadsJson': m.resolvedThreadsJson,
        'choiceMadeToStartChapter': m.choiceMadeToStartChapter,
        'fullChapterText': m.fullChapterText,
      };

  static ChapterMemoryLocal _fromMap(Map<String, dynamic> d) =>
      ChapterMemoryLocal()
        ..id = d['id'] as int? ?? 0
        ..chronicleId = d['chronicleId'] as String? ?? ''
        ..chapterNumber = d['chapterNumber'] as int? ?? 0
        ..createdAt = DateTime.tryParse(d['createdAt'] as String? ?? '') ?? DateTime.now()
        ..summaryBulletsJson = d['summaryBulletsJson'] as String?
        ..newWorldFactsJson = d['newWorldFactsJson'] as String?
        ..characterGrowthNote = d['characterGrowthNote'] as String?
        ..cliffhanger = d['cliffhanger'] as String?
        ..newThreadsJson = d['newThreadsJson'] as String?
        ..resolvedThreadsJson = d['resolvedThreadsJson'] as String?
        ..choiceMadeToStartChapter = d['choiceMadeToStartChapter'] as String?
        ..fullChapterText = d['fullChapterText'] as String?;

  static Future<List<ChapterMemoryLocal>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final List<dynamic> list =
        json.decode(prefs.getString(_key) ?? '[]') as List<dynamic>;
    return list.map((e) => _fromMap(e as Map<String, dynamic>)).toList();
  }
}

class ChapterMemoryFilterStub {
  String? _chronicleId;

  ChapterMemoryFilterStub chronicleIdEqualTo(String id) {
    _chronicleId = id;
    return this;
  }

  ChapterMemoryFilterStub sortByChapterNumber() => this;

  Future<List<ChapterMemoryLocal>> findAll() async {
    var list = await ChapterMemoryLocalsStub._loadAll();
    if (_chronicleId != null) {
      list = list.where((m) => m.chronicleId == _chronicleId).toList();
    }
    list.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    return list;
  }
}

// ---------------------------------------------------------------------------
// AvatarCacheEntry stubs — SharedPreferences-backed avatar cache for web
// ---------------------------------------------------------------------------

class AvatarCacheEntrysStub {
  static const String _key = 'isar_avatar_cache';

  AvatarCacheWhereStub where() => AvatarCacheWhereStub();
  AvatarCacheFilterStub filter() => AvatarCacheFilterStub();

  Future<int> put(AvatarCacheEntry entry) => _synchronized(_key, () async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs.getString(_key));
    if (entry.id == 0 || entry.id == -9223372036854775808) {
      entry.id = DateTime.now().microsecondsSinceEpoch;
    }
    final idx = list.indexWhere((e) => e['id'] == entry.id);
    final data = _toMap(entry);
    if (idx >= 0) {
      list[idx] = data;
    } else {
      list.add(data);
    }
    await _quotaSafeSetString(prefs, _key, list);
    return entry.id;
  });

  Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_key)).length;
  }

  Future<int> clear() => _synchronized(_key, () async {
    final prefs = await SharedPreferences.getInstance();
    final n = _decode(prefs.getString(_key)).length;
    await prefs.remove(_key);
    return n;
  });

  Future<int> deleteAll(List<int> ids) => _synchronized(_key, () async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs.getString(_key));
    final before = list.length;
    list.removeWhere((e) => ids.contains(e['id'] as int?));
    await _quotaSafeSetString(prefs, _key, list);
    return before - list.length;
  });

  static List<dynamic> _decode(String? raw) =>
      raw != null ? json.decode(raw) as List<dynamic> : [];

  static Map<String, dynamic> _toMap(AvatarCacheEntry e) => {
        'id': e.id,
        'cacheKey': e.cacheKey,
        'svgString': e.svgString,
        'createdAt': e.createdAt.toIso8601String(),
        'schemaVersion': e.schemaVersion,
        'style': e.style,
        'seed': e.seed,
        'optionsJson': e.optionsJson,
        'ageTier': e.ageTier,
        'characterAge': e.characterAge,
        'lastAccessedAt': e.lastAccessedAt?.toIso8601String(),
      };

  static AvatarCacheEntry _fromMap(Map<String, dynamic> d) {
    final e = AvatarCacheEntry()
      ..id = d['id'] as int? ?? 0
      ..cacheKey = d['cacheKey'] as String? ?? ''
      ..svgString = d['svgString'] as String? ?? ''
      ..createdAt = DateTime.tryParse(d['createdAt'] as String? ?? '') ?? DateTime.now()
      ..schemaVersion = d['schemaVersion'] as String? ?? ''
      ..style = d['style'] as String? ?? ''
      ..seed = d['seed'] as String? ?? ''
      ..optionsJson = d['optionsJson'] as String?
      ..ageTier = d['ageTier'] as String?
      ..characterAge = d['characterAge'] as int?
      ..lastAccessedAt = d['lastAccessedAt'] != null
          ? DateTime.tryParse(d['lastAccessedAt'] as String)
          : null;
    return e;
  }

  static Future<List<AvatarCacheEntry>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_key))
        .map((e) => _fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

class AvatarCacheWhereStub {
  String? _cacheKey;

  AvatarCacheWhereStub cacheKeyEqualTo(String key) {
    _cacheKey = key;
    return this;
  }

  Future<AvatarCacheEntry?> findFirst() async {
    final list = await AvatarCacheEntrysStub._loadAll();
    try {
      return list.firstWhere((e) => e.cacheKey == _cacheKey);
    } catch (_) {
      return null;
    }
  }
}

class AvatarCacheFilterStub {
  DateTime? _createdBefore;
  String? _schemaVersion;
  bool _negate = false;

  AvatarCacheFilterStub createdAtLessThan(DateTime date) {
    _createdBefore = date;
    return this;
  }

  AvatarCacheFilterStub not() {
    _negate = true;
    return this;
  }

  AvatarCacheFilterStub schemaVersionEqualTo(String version) {
    _schemaVersion = version;
    return this;
  }

  Future<List<AvatarCacheEntry>> findAll() async {
    var list = await AvatarCacheEntrysStub._loadAll();
    if (_createdBefore != null) {
      list = list.where((e) => e.createdAt.isBefore(_createdBefore!)).toList();
    }
    if (_schemaVersion != null) {
      bool matches(AvatarCacheEntry e) => e.schemaVersion == _schemaVersion;
      list = _negate
          ? list.where((e) => !matches(e)).toList()
          : list.where(matches).toList();
    }
    return list;
  }

  Future<int> count() async => (await findAll()).length;
}
