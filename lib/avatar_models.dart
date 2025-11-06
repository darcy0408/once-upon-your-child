// lib/avatar_models.dart
// Avatar models matching React web app structure for cross-platform compatibility

import 'dart:convert';

/// Character Avatar configuration matching React's avataaars structure
class CharacterAvatar {
  final String skinColor;
  final String hairStyle;
  final String hairColor;
  final String eyeType;
  final String mouthType;
  final String clothingStyle;
  final String clothingColor;

  const CharacterAvatar({
    required this.skinColor,
    required this.hairStyle,
    required this.hairColor,
    required this.eyeType,
    required this.mouthType,
    required this.clothingStyle,
    required this.clothingColor,
  });

  /// Create from JSON (compatible with React web app format)
  factory CharacterAvatar.fromJson(Map<String, dynamic> json) {
    return CharacterAvatar(
      skinColor: json['skinColor'] ?? json['skin_color'] ?? 'Light',
      hairStyle: json['topType'] ?? json['hair_style'] ?? 'ShortHairShortFlat',
      hairColor: json['hairColor'] ?? json['hair_color'] ?? 'Brown',
      eyeType: json['eyeType'] ?? json['eye_type'] ?? 'Happy',
      mouthType: json['mouthType'] ?? json['mouth_type'] ?? 'Smile',
      clothingStyle: json['clotheType'] ?? json['clothing_style'] ?? 'Hoodie',
      clothingColor: json['clotheColor'] ?? json['clothing_color'] ?? 'Blue03',
    );
  }

  /// Convert to JSON (compatible with React web app format)
  Map<String, dynamic> toJson() => {
        'skinColor': skinColor,
        'topType': hairStyle,
        'hairColor': hairColor,
        'eyeType': eyeType,
        'mouthType': mouthType,
        'clotheType': clothingStyle,
        'clotheColor': clothingColor,
      };

  /// Translate this avatar into an Avataaars URL for rich SVG rendering.
  String toAvataaarsUrl({bool circleBackground = true}) {
    final query = <String, String>{
      'avatarStyle': circleBackground ? 'Circle' : 'Transparent',
      'topType': _mapTopType(hairStyle),
      'hairColor': _mapHairColor(hairColor),
      'accessoriesType': 'Blank',
      'facialHairType': 'Blank',
      'facialHairColor': 'BrownDark',
      'clotheType': clothingStyle,
      'clotheColor': _mapClothingColor(clothingColor),
      'eyeType': eyeType,
      'mouthType': mouthType,
      'skinColor': _mapSkinColor(skinColor),
    };

    query.removeWhere((_, value) => value.isEmpty);
    return Uri.https('avataaars.io', '/', query).toString();
  }

  /// Create a copy with optional parameter overrides
  CharacterAvatar copyWith({
    String? skinColor,
    String? hairStyle,
    String? hairColor,
    String? eyeType,
    String? mouthType,
    String? clothingStyle,
    String? clothingColor,
  }) {
    return CharacterAvatar(
      skinColor: skinColor ?? this.skinColor,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      eyeType: eyeType ?? this.eyeType,
      mouthType: mouthType ?? this.mouthType,
      clothingStyle: clothingStyle ?? this.clothingStyle,
      clothingColor: clothingColor ?? this.clothingColor,
    );
  }

  /// Default avatar configuration
  static const CharacterAvatar defaultAvatar = CharacterAvatar(
    skinColor: 'Light',
    hairStyle: 'ShortHairShortFlat',
    hairColor: 'Brown',
    eyeType: 'Happy',
    mouthType: 'Smile',
    clothingStyle: 'Hoodie',
    clothingColor: 'Blue03',
  );
}

/// Enhanced Character model with avatar support
class EnhancedCharacter {
  final String id;
  final String name;
  final CharacterAvatar avatar;
  final DateTime timestamp;
  final int? age;
  final String? role;
  final String? gender;

  EnhancedCharacter({
    String? id,
    required this.name,
    required this.avatar,
    DateTime? timestamp,
    this.age,
    this.role,
    this.gender,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  /// Create from JSON (cross-platform compatible)
  factory EnhancedCharacter.fromJson(Map<String, dynamic> json) {
    return EnhancedCharacter(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? 'Unknown',
      avatar: CharacterAvatar.fromJson(json['avatar'] ?? {}),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      age: json['age'],
      role: json['role'],
      gender: json['gender'],
    );
  }

  /// Convert to JSON (cross-platform compatible)
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar.toJson(),
        'timestamp': timestamp.toIso8601String(),
        if (age != null) 'age': age,
        if (role != null) 'role': role,
        if (gender != null) 'gender': gender,
      };

  /// Create a copy with optional parameter overrides
  EnhancedCharacter copyWith({
    String? id,
    String? name,
    CharacterAvatar? avatar,
    DateTime? timestamp,
    int? age,
    String? role,
    String? gender,
  }) {
    return EnhancedCharacter(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      timestamp: timestamp ?? this.timestamp,
      age: age ?? this.age,
      role: role ?? this.role,
      gender: gender ?? this.gender,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory EnhancedCharacter.fromJsonString(String jsonString) {
    return EnhancedCharacter.fromJson(jsonDecode(jsonString));
  }
}

String _mapSkinColor(String value) {
  switch (value) {
    case 'PorcelainWhite':
    case 'VeryPale':
      return 'Light';
    case 'Beige':
      return 'Pale';
    case 'DeepBrown':
      return 'DarkBrown';
    case 'VeryDark':
      return 'Black';
    default:
      return _validSkinColors.contains(value) ? value : 'Light';
  }
}

String _mapHairColor(String value) {
  if (_validHairColors.contains(value)) {
    return value;
  }
  switch (value) {
    case 'Blue':
      return 'SilverGray';
    case 'Purple':
      return 'PastelPink';
    default:
      return 'Brown';
  }
}

String _mapClothingColor(String value) {
  if (_validClothingColors.contains(value)) {
    return value;
  }
  switch (value) {
    case 'PastelPink':
      return 'Pink';
    case 'PastelPurple':
      return 'PastelBlue';
    case 'PastelGreen':
      return 'PastelGreen';
    case 'PastelYellow':
      return 'PastelYellow';
    case 'PastelOrange':
      return 'PastelOrange';
    case 'Green01':
      return 'PastelGreen';
    case 'Yellow':
      return 'PastelYellow';
    case 'Orange':
      return 'PastelOrange';
    case 'Brown':
      return 'Heather';
    default:
      return 'Blue03';
  }
}

String _mapTopType(String value) {
  if (_validTopTypes.contains(value)) {
    return value;
  }
  return 'ShortHairShortFlat';
}

const Set<String> _validSkinColors = {
  'Tanned',
  'Yellow',
  'Pale',
  'Light',
  'Brown',
  'DarkBrown',
  'Black',
};

const Set<String> _validClothingColors = {
  'Black',
  'Blue01',
  'Blue02',
  'Blue03',
  'Gray01',
  'Gray02',
  'Heather',
  'PastelBlue',
  'PastelGreen',
  'PastelOrange',
  'PastelRed',
  'PastelYellow',
  'Pink',
  'Red',
  'White',
};

const Set<String> _validHairColors = {
  'Auburn',
  'Black',
  'Blonde',
  'BlondeGolden',
  'Brown',
  'BrownDark',
  'PastelPink',
  'Platinum',
  'Red',
  'SilverGray',
};

const Set<String> _validTopTypes = {
  'ShortHairShortFlat',
  'ShortHairShortCurly',
  'ShortHairShortWaved',
  'LongHairStraight',
  'LongHairCurly',
  'LongHairBigHair',
  'LongHairBun',
  'LongHairBraids',
  'LongHairPonytail',
  'Hijab',
  'Hat',
};
