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
  String? companion;

  String? characterId;

  @Index()
  String? characterName;

  bool? isFavorite;
}
