// Stub implementation of IsarService for web platform
// Web doesn't support Isar (FFI-based database)
// We use SharedPreferences for basic persistence on web

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../models/local/character_local.dart';

// Create a stub Isar type that matches the API surface we need
class Isar {
  CharacterLocalsStub get characterLocals => CharacterLocalsStub();

  Future<void> writeTxn(Future<void> Function() callback) async {
    await callback();
  }

  void close() {}
}

class CharacterLocalsStub {
  static const String _storageKey = 'isar_characters';

  CharacterWhereStub where() => CharacterWhereStub();

  Future<int> put(CharacterLocal character) async {
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

    await prefs.setString(_storageKey, json.encode(characters));
    return character.id;
  }

  Future<bool> delete(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? charactersJson = prefs.getString(_storageKey);
    if (charactersJson == null) return false;

    List<dynamic> characters = json.decode(charactersJson);
    int initialLength = characters.length;
    characters.removeWhere((c) => c['id'] == id);

    if (characters.length != initialLength) {
      await prefs.setString(_storageKey, json.encode(characters));
      return true;
    }
    return false;
  }
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
