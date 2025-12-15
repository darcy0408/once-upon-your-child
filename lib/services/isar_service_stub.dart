// Stub implementation of IsarService for web platform
// Web doesn't support Isar (FFI-based database)

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
    return [];
  }

  static Future<void> close() async {
    _isar = null;
  }
}
