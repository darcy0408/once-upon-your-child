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
  String toAvataaarsUrl({bool circleBackground = true, String? customSeed}) {
    final params = <String, String>{
      // Seed keeps avatars consistent across sessions
      // Use customSeed if provided (e.g. character ID), otherwise fallback to attributes
      'seed': customSeed ?? '$skinColor$hairColor$hairStyle'.toLowerCase(),
      // Turn off facial hair so kid avatars stay gender-neutral unless we add explicit options
      'facialHairProbability': '0',
      'skinColor': _mapSkinColorToDiceBear(skinColor),
      'hairColor': _mapHairColorToDiceBear(hairColor),
      'top': _mapTopTypeToDiceBear(hairStyle),
      'eyes': _mapEyeTypeToDiceBear(eyeType),
      'mouth': _mapMouthTypeToDiceBear(mouthType),
      'clothes': _mapClothingTypeToDiceBear(clothingStyle),
      'clothesColor': _mapClothingColorToDiceBear(clothingColor),
      if (circleBackground) 'backgroundColor': 'b6e3f4',
    }..removeWhere((_, value) => value.isEmpty);

    return Uri.https('api.dicebear.com', '/7.x/avataaars/svg', params).toString();
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

// DiceBear 7.x mapping functions - convert our values to DiceBear format

String _mapSkinColorToDiceBear(String value) {
  switch (value.toLowerCase()) {
    case 'yellow':
    case 'tanned':
      return 'e4b899';
    case 'pale':
    case 'porcelainwhite':
    case 'verypale':
      return 'f5d5c4';
    case 'brown':
      return 'b57c57';
    case 'darkbrown':
    case 'deepbrown':
      return '8d5524';
    case 'black':
    case 'verydark':
      return '4a3228';
    default:
      return 'fddac7';
  }
}

String _mapHairColorToDiceBear(String value) {
  switch (value.toLowerCase()) {
    case 'auburn':
      return '7c2d12';
    case 'black':
      return '1a1a1a';
    case 'blonde':
    case 'blondegolden':
      return 'f1e2b8';
    case 'bronze':
      return 'b08d57';
    case 'brown':
    case 'browndark':
      return '4a312c';
    case 'pastelpink':
      return 'f59797';
    case 'platinum':
    case 'silvergray':
    case 'gray':
    case 'silver':
      return 'e8e1e1';
    case 'red':
      return 'c93305';
    case 'gold':
    case 'blondegolden':
      return 'f1e2b8';
    case 'rainbow':
      return 'f59797'; // Map rainbow to pastel pink as closest fantasy option
    default:
      return '8d5524';
  }
}

String _mapClothingColorToDiceBear(String value) {
  switch (value.toLowerCase()) {
    case 'black':
      return '262e33';
    case 'blue01':
      return '65c9ff';
    case 'blue02':
      return '5199e4';
    case 'blue03':
      return '25557c';
    case 'pastelblue':
      return 'b1e2ff';
    case 'gray01':
      return 'e6e6e6';
    case 'gray02':
      return '929598';
    case 'heather':
      return '3c4f5c';
    case 'pastelgreen':
      return 'a7ffc4';
    case 'pastelorange':
      return 'ffafb9';
    case 'pastelred':
    case 'red':
      return 'ff5c5c';
    case 'pastelyellow':
      return 'ffffb1';
    case 'pink':
      return 'ff488e';
    case 'white':
      return 'ffffff';
    default:
      return '65c9ff';
  }
}

String _mapTopTypeToDiceBear(String value) {
  // Map our hair styles to DiceBear's camelCase options
  switch (value) {
    case 'ShortHairShortFlat':
      return 'shortFlat';
    case 'ShortHairShortCurly':
      return 'shortCurly';
    case 'ShortHairShortWaved':
      return 'shortWaved';
    case 'LongHairStraight':
      return 'straight02';
    case 'LongHairCurly':
      return 'longButNotTooLong';
    case 'LongHairBigHair':
      return 'bigHair';
    case 'LongHairBun':
      return 'bun';
    case 'LongHairBraids':
      return 'dreads02';
    case 'LongHairPonytail':
      return 'longButNotTooLong';
    case 'Hijab':
      return 'hijab';
    case 'Hat':
      return 'hat';
    default:
      return 'shortFlat';
  }
}

String _mapEyeTypeToDiceBear(String value) {
  // Map eye types to DiceBear's camelCase options
  switch (value.toLowerCase()) {
    case 'happy':
      return 'happy';
    case 'default':
      return 'default';
    case 'eyeroll':
      return 'eyeRoll';
    case 'surprised':
      return 'surprised';
    case 'sad':
    case 'cry':
      return 'cry';
    case 'wink':
      return 'wink';
    case 'hearts':
      return 'hearts';
    case 'closed':
      return 'closed';
    default:
      return 'default';
  }
}

String _mapMouthTypeToDiceBear(String value) {
  // Map mouth types to DiceBear's camelCase options
  switch (value.toLowerCase()) {
    case 'smile':
      return 'smile';
    case 'default':
      return 'default';
    case 'sad':
      return 'sad';
    case 'grimace':
    case 'concerned':
      return 'concerned';
    case 'tongue':
      return 'tongue';
    case 'twinkle':
      return 'twinkle';
    default:
      return 'smile';
  }
}

String _mapClothingTypeToDiceBear(String value) {
  // Map clothing types to DiceBear's camelCase options
  switch (value) {
    case 'Hoodie':
      return 'hoodie';
    case 'CollarSweater':
      return 'collarAndSweater';
    case 'Shirt':
    case 'ShirtCrewNeck':
    case 'ShirtScoopNeck':
      return 'shirtCrewNeck';
    case 'GraphicShirt':
      return 'graphicShirt';
    case 'BlazerShirt':
      return 'blazerAndShirt';
    case 'BlazerSweater':
      return 'blazerAndSweater';
    case 'Overall':
      return 'overall';
    default:
      return 'hoodie';
  }
}

// Legacy mapping functions for backward compatibility
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
