// Real implementation of IsarService for mobile platforms
import 'package:isar/isar.dart';
export 'package:isar/isar.dart'; // Export Isar type
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import '../models/local/character_local_io.dart';
import '../avatar_models.dart';
import '../models/local/story_local_io.dart';
import '../models/local/chronicle_local_io.dart';
import '../models/local/chapter_memory_local_io.dart';
import '../models/local/hero_profile_local_io.dart';
import '../data/isar/avatar_cache_entry_io.dart';
import '../models.dart'; // Domain models

class IsarService {
  static Isar? _isar;

  /// Allows injecting a mock Isar instance for testing.
  @visibleForTesting
  static void setTestInstance(Isar? isar) {
    _isar = isar;
  }

  /// Test seam for the sync dedup lookup. The underlying
  /// `isar.characterLocals.filter().characterIdEqualTo().findFirst()` uses
  /// generated Isar extension methods that mocktail cannot stub, so tests
  /// override this to control (or bypass) the lookup. Returns the existing
  /// local row id for [characterId], or null if there is no prior row.
  @visibleForTesting
  static Future<int?> Function(Isar isar, String characterId)
      findExistingCharacterId = _defaultFindExistingCharacterId;

  static Future<int?> _defaultFindExistingCharacterId(
    Isar isar,
    String characterId,
  ) async {
    final existing = await isar.characterLocals
        .filter()
        .characterIdEqualTo(characterId)
        .findFirst();
    return existing?.id;
  }

  static Future<Isar> getInstance() async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        StoryLocalSchema,
        CharacterLocalSchema,
        ChronicleLocalSchema,
        ChapterMemoryLocalSchema,
        HeroProfileLocalSchema,
        AvatarCacheEntrySchema,
      ],
      directory: dir.path,
      inspector: true,
    );
    return _isar!;
  }

  static Isar get instance {
    if (_isar == null) {
      throw Exception('IsarService not initialized. Call getInstance() first.');
    }
    return _isar!;
  }

  static Future<List<Character>> getAllCharacters() async {
    final isar = await getInstance();
    final localCharacters = await isar.characterLocals.where().findAll();

    // Map to domain model
    return localCharacters.map((lc) => Character(
      id: lc.characterId,
      name: lc.name,
      age: lc.age,
      role: 'Hero', // Default role for saved heroes
      avatar: lc.avatarUrl != null ? CharacterAvatar.defaultAvatar : null, // Partial mapping as local schema lacks full avatar details
      // Note: Full mapping would require more fields in CharacterLocal or a robust mapper.
      // For now, mapping essential fields to prevent build errors.
    )).toList();
  }

  /// Save a character to local storage
  static Future<void> saveCharacter(CharacterLocal character) async {
    final isar = await getInstance();
    await isar.writeTxn(() async {
      await isar.characterLocals.put(character);
    });
  }

  /// Save multiple characters to local storage (for syncing from API)
  static Future<void> syncCharactersFromApi(List<dynamic> charactersJson) async {
    final isar = await getInstance();
    await isar.writeTxn(() async {
      for (final charJson in charactersJson) {
        final localChar = CharacterLocal.fromJson(charJson);
        // Isar.put keys on the auto-increment `id`, which fromJson leaves unset.
        // characterId is a NON-unique index, so without copying the existing
        // row's id forward every sync would insert a duplicate. Look up the
        // existing row by characterId and reuse its id so put() updates in
        // place. Mirrors the story path in OfflineStoryService.saveStory.
        if (localChar.characterId.isNotEmpty) {
          final existingId =
              await findExistingCharacterId(isar, localChar.characterId);
          if (existingId != null) {
            localChar.id = existingId;
          }
        }
        await isar.characterLocals.put(localChar);
      }
    });
  }

  /// Erases every locally-cached collection (stories, characters, chronicles,
  /// chapter memories, hero profiles and cached avatars). Used by the COPPA/
  /// GDPR "Delete All My Data" flow (PRIV-03/PRIV-02) after a confirmed backend
  /// deletion. The web stub mirrors this by removing the backing prefs keys.
  static Future<void> clearAllCaches() async {
    final isar = await getInstance();
    await isar.writeTxn(() async {
      await isar.storyLocals.clear();
      await isar.characterLocals.clear();
      await isar.chronicleLocals.clear();
      await isar.chapterMemoryLocals.clear();
      await isar.heroProfileLocals.clear();
      await isar.avatarCacheEntrys.clear();
    });
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
