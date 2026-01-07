import 'package:isar/isar.dart';

part 'character_local_io.g.dart';

@collection
class CharacterLocal {
  Id id = Isar.autoIncrement;

  @Index()
  late String characterId;

  late String name;
  late int age;
  String? avatarUrl;

  /// Avatar customization parameters (JSON string)
  /// Stores avataaars parameters like: {"top": "curly", "hairColor": "brown", "clothing": "hoodie"}
  String? avatarParams;

  bool isSyncedToServer = false;

  @Index()
  late DateTime createdAt;

  static CharacterLocal fromJson(Map<String, dynamic> json) {
    final dynamic ageValue = json['age'];
    return CharacterLocal()
      ..characterId = json['id']?.toString() ?? ''
      ..name = json['name'] ?? ''
      ..age = ageValue is int ? ageValue : int.tryParse(ageValue?.toString() ?? '') ?? 0
      ..avatarUrl = json['avatarUrl'] ?? json['avatar_url']
      ..avatarParams = json['avatarParams']
      ..createdAt = json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now()
      ..isSyncedToServer = true;
  }

  Map<String, dynamic> toJson() => {
        'id': characterId,
        'name': name,
        'age': age,
        'avatarUrl': avatarUrl,
        'avatarParams': avatarParams,
        'createdAt': createdAt.toIso8601String(),
      };
}
