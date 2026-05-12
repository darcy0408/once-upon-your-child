import 'package:isar/isar.dart';

part 'chapter_memory_local_io.g.dart';

@collection
class ChapterMemoryLocal {
  Id id = Isar.autoIncrement;

  @Index()
  late String chronicleId;

  late int chapterNumber;
  late DateTime createdAt;
  String? choiceMadeToStartChapter;
  String? summaryBulletsJson;
  String? newWorldFactsJson;
  String? characterGrowthNote;
  String? cliffhanger;
  String? newThreadsJson;
  String? resolvedThreadsJson;
  String? fullChapterText;
}
