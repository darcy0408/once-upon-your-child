// Stub implementation of IsarService for web platform
// Web doesn't support Isar (FFI-based database)
// Web doesn't support Isar (FFI-based database)

import '../models.dart';
import '../models/local/character_local_stub.dart';

// Create a stub Isar type that matches the API surface we need
class Isar {
  // Stub class for web
  void close() {}
}

class IsarService {
  static Isar? _isar;

  static Future<Isar> getInstance() async {
    // On web, return a stub instance
    // All data will be stored via API calls to backend
    _isar ??= Isar();
    return _isar!;
  }

  static Isar get instance {
    _isar ??= Isar();
    return _isar!;
  }

  static Future<List<Character>> getAllCharacters() async {
    // On web, return empty list - all data from API
    return [];
  }

  /// Save a character to local storage (no-op on web)
  static Future<void> saveCharacter(CharacterLocal character) async {
    // No-op on web - data stored via API
  }

  /// Save multiple characters to local storage (no-op on web)
  static Future<void> syncCharactersFromApi(List<dynamic> charactersJson) async {
    // No-op on web - data stored via API
  }

  static Future<void> close() async {
    _isar = null;
  }
}
