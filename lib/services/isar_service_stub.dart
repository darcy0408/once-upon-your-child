// Stub implementation of IsarService for web platform
// Web doesn't support Isar (FFI-based database)

class Isar {
  // Stub class for web
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

  static Future<void> close() async {
    _isar = null;
  }
}
