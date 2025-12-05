// Real implementation of IsarService for mobile platforms
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/local/character_local.dart';
import '../models/local/story_local.dart';

class IsarService {
  static Isar? _isar;

  static Future<Isar> getInstance() async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [StoryLocalSchema, CharacterLocalSchema],
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

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
