import 'package:isar/isar.dart';
part 'chronicle_local.g.dart';

@collection
class ChronicleLocal {
  Id id = Isar.autoIncrement;

  @Index()
  late String chronicleId; // UUID

  @Index()
  late String characterId; // CharacterLocal.characterId

  late String characterName;
  late int characterAge;
  late String title;
  late String genre; // fantasy, sci-fi, mystery, etc.
  late DateTime createdAt;
  late DateTime lastPlayedAt;
  int chapterCount = 0;
  bool isActive = true;

  /// JSON-encoded List<String> of arc summary strings
  String? arcSummariesJson;

  /// JSON-encoded List<Map> of last 3 chapter memory objects
  /// Each map has keys: chapter_number, summary_bullets, cliffhanger
  String? recentMemoriesJson;

  /// JSON-encoded List<String> of established world fact strings
  String? worldFactsJson;

  /// JSON-encoded Map: {growth: str, items: [str], relationships: [str]}
  String? characterStateJson;

  /// JSON-encoded List<String> of open plot thread strings
  String? unresolvedThreadsJson;

  String? lastChoiceMade;

  /// Last 1-2 sentences of the previous chapter for continuity
  String? lastChapterEnding;

  /// Base64-encoded PNG cover image (optional)
  String? coverImageBase64;
}
