import 'package:isar/isar.dart';
part 'chapter_memory_local.g.dart';

@collection
class ChapterMemoryLocal {
  Id id = Isar.autoIncrement;

  @Index()
  late String chronicleId;

  late int chapterNumber;
  late DateTime createdAt;

  /// The choice text the player made to begin this chapter (null for Ch 1)
  String? choiceMadeToStartChapter;

  /// JSON-encoded List<String> of 5-8 bullet summary strings
  String? summaryBulletsJson;

  /// JSON-encoded List<String> of new canonical world fact strings
  String? newWorldFactsJson;

  /// One sentence describing character growth this chapter
  String? characterGrowthNote;

  /// How the chapter ended / cliffhanger hook
  String? cliffhanger;

  /// JSON-encoded List<String> of new unresolved plot threads
  String? newThreadsJson;

  /// JSON-encoded List<String> of threads closed this chapter
  String? resolvedThreadsJson;

  /// Full concatenated chapter text (for re-reading and summarization input)
  String? fullChapterText;
}
