import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cached_story.dart';

class IsarService {
  static late Isar isar;

  static Future<void> initialize({String? directoryPath}) async {
    final dir = directoryPath ?? (await getApplicationDocumentsDirectory()).path;
    isar = await Isar.open(
      [CachedStorySchema],
      directory: dir,
    );
  }
}
