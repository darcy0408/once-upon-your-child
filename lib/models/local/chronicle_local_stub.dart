class ChronicleLocal {
  int id = 0;
  String chronicleId = '';
  String characterId = '';
  String characterName = '';
  int characterAge = 0;
  String title = '';
  String genre = '';
  DateTime createdAt = DateTime.now();
  DateTime lastPlayedAt = DateTime.now();
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
