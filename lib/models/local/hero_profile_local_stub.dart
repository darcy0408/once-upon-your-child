// Web stub for HeroProfileLocal — plain Dart class with no Isar imports.
// Storage in IsarService_stub backs onto SharedPreferences.

class HeroProfileLocal {
  int id = 0;
  String characterId = '';
  String? costumeColor;
  String? capeStyle;
  String? emblem;
  String? power;
  String? heroName;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  List<String> recentVillains = [];
  List<String> recentProblems = [];
}
