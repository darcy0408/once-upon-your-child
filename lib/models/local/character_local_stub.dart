// Stub implementation for web platform

class CharacterLocal {
  int id = 0;
  String characterId = '';
  String name = '';
  int age = 0;
  String? avatarUrl;
  bool isSyncedToServer = false;
  DateTime createdAt = DateTime.now();

  static CharacterLocal fromJson(Map<String, dynamic> json) {
    final dynamic ageValue = json['age'];
    return CharacterLocal()
      ..characterId = json['id']?.toString() ?? ''
      ..name = json['name'] ?? ''
      ..age = ageValue is int ? ageValue : int.tryParse(ageValue?.toString() ?? '') ?? 0
      ..avatarUrl = json['avatarUrl'] ?? json['avatar_url']
      ..createdAt = json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now()
      ..isSyncedToServer = true;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': characterId,
      'name': name,
      'age': age,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
