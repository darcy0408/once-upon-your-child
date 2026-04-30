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
import '../data/isar/avatar_cache_entry_io.dart';
import '../models.dart'; // Domain models

class IsarService {
  static Isar? _isar;

  /// Allows injecting a mock Isar instance for testing.
  @visibleForTesting
  static void setTestInstance(Isar? isar) {
    _isar = isar;
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
        await isar.characterLocals.put(localChar);
      }
    });
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
