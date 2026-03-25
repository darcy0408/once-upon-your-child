import 'package:isar/isar.dart';

part 'chronicle_local.g.dart';

@collection
class ChronicleLocal {
  Id id = Isar.autoIncrement;

  @Index()
  late String chronicleId;

  @Index()
  late String characterId;

  late String characterName;
  late int characterAge;
  late String title;
  late String genre;
  late DateTime createdAt;
  late DateTime lastPlayedAt;
  int chapterCount = 0;
  bool isActive = true;
  String? arcSummariesJson;
  String? recentMemoriesJson;
  String? worldFactsJson;
  String? characterStateJson;
  String? unresolvedThreadsJson;
  String? lastChoiceMade;
  String? lastChapterEnding;
  String? coverImageBase64;
}
