import 'package:isar/isar.dart';

part 'cached_story.g.dart';

@collection
class CachedStory {
  Id id = Isar.autoIncrement;

  late String storyId;
  late String title;
  late String storyText;
  late String theme;
  String? wisdomGem;
  late DateTime createdAt;
  late DateTime cachedAt;
  String? companion;
  String? characterId;

  @Index(caseSensitive: false)
  late String characterName;

  bool isFavorite = false;

  final characters = IsarLinks<CachedCharacter>();
}

@collection
class CachedCharacter {
  Id id = Isar.autoIncrement;

  late String characterId;
  late String name;
  int? age;
  String? gender;
  String? role;
  String? hair;
  String? eyes;
  String? skinTone;
  String? hairstyle;
  String? currentEmotion;
  String? comfortItem;
}
