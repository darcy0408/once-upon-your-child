// lib/character_appearance.dart

/// Detailed character appearance for generating consistent illustrations
class CharacterAppearance {
  final String characterName;

  // Hair
  final HairColor hairColor;
  final HairLength hairLength;
  final HairStyle hairStyle;

  // Eyes
  final EyeColor eyeColor;

  // Skin
  final SkinTone skinTone;

  // Clothing
  final ClothingStyle clothingStyle;
  final ClothingColors clothingColors;

  // Build/Features (kept vague for flexibility)
  final BodyBuild bodyBuild;

  CharacterAppearance({
    required this.characterName,
    required this.hairColor,
    required this.hairLength,
    required this.hairStyle,
    required this.eyeColor,
    required this.skinTone,
    required this.clothingStyle,
    required this.clothingColors,
    this.bodyBuild = BodyBuild.average,
  });

  /// Generate a detailed prompt description for DALL-E
  String toPromptDescription() {
    return '''
Character named $characterName:
- Hair: ${hairLength.description} ${hairColor.description} hair with ${hairStyle.description} style
- Eyes: ${eyeColor.description} eyes
- Skin: ${skinTone.description} skin tone
- Build: ${bodyBuild.description} build
- Clothing: ${clothingStyle.description} in ${clothingColors.description} colors
'''.trim();
  }

  /// Generate a simplified description for coloring book pages
  String toColoringBookDescription() {
    return '''
Child character with:
- ${hairLength.description} hair (${hairStyle.description})
- ${clothingStyle.description}
- Simple, clear outlines suitable for coloring
- Friendly, engaging expression
'''.trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'characterName': characterName,
      'hairColor': hairColor.name,
      'hairLength': hairLength.name,
      'hairStyle': hairStyle.name,
      'eyeColor': eyeColor.name,
      'skinTone': skinTone.name,
      'clothingStyle': clothingStyle.name,
      'clothingColors': clothingColors.name,
      'bodyBuild': bodyBuild.name,
    };
  }

  factory CharacterAppearance.fromJson(Map<String, dynamic> json) {
    return CharacterAppearance(
      characterName: json['characterName'] as String,
      hairColor: HairColor.values.byName(json['hairColor'] as String),
      hairLength: HairLength.values.byName(json['hairLength'] as String),
      hairStyle: HairStyle.values.byName(json['hairStyle'] as String),
      eyeColor: EyeColor.values.byName(json['eyeColor'] as String),
      skinTone: SkinTone.values.byName(json['skinTone'] as String),
      clothingStyle: ClothingStyle.values.byName(json['clothingStyle'] as String),
      clothingColors: ClothingColors.values.byName(json['clothingColors'] as String),
      bodyBuild: BodyBuild.values.byName(json['bodyBuild'] as String? ?? 'average'),
    );
  }

  /// Create a copy with some fields changed
  CharacterAppearance copyWith({
    String? characterName,
    HairColor? hairColor,
    HairLength? hairLength,
    HairStyle? hairStyle,
    EyeColor? eyeColor,
    SkinTone? skinTone,
    ClothingStyle? clothingStyle,
    ClothingColors? clothingColors,
    BodyBuild? bodyBuild,
  }) {
    return CharacterAppearance(
      characterName: characterName ?? this.characterName,
      hairColor: hairColor ?? this.hairColor,
      hairLength: hairLength ?? this.hairLength,
      hairStyle: hairStyle ?? this.hairStyle,
      eyeColor: eyeColor ?? this.eyeColor,
      skinTone: skinTone ?? this.skinTone,
      clothingStyle: clothingStyle ?? this.clothingStyle,
      clothingColors: clothingColors ?? this.clothingColors,
      bodyBuild: bodyBuild ?? this.bodyBuild,
    );
  }
}

/// Hair color options
enum HairColor {
  blonde,
  brown,
  black,
  red,
  auburn,
  darkBrown,
  lightBrown,
  strawberryBlonde,
  gray,
  white;

  String get description {
    switch (this) {
      case HairColor.blonde:
        return 'bright blonde';
      case HairColor.brown:
        return 'medium brown';
      case HairColor.black:
        return 'black';
      case HairColor.red:
        return 'bright red';
      case HairColor.auburn:
        return 'auburn';
      case HairColor.darkBrown:
        return 'dark brown';
      case HairColor.lightBrown:
        return 'light brown';
      case HairColor.strawberryBlonde:
        return 'strawberry blonde';
      case HairColor.gray:
        return 'gray';
      case HairColor.white:
        return 'white';
    }
  }

  String get displayName {
    switch (this) {
      case HairColor.blonde:
        return 'Blonde';
      case HairColor.brown:
        return 'Brown';
      case HairColor.black:
        return 'Black';
      case HairColor.red:
        return 'Red';
      case HairColor.auburn:
        return 'Auburn';
      case HairColor.darkBrown:
        return 'Dark Brown';
      case HairColor.lightBrown:
        return 'Light Brown';
      case HairColor.strawberryBlonde:
        return 'Strawberry Blonde';
      case HairColor.gray:
        return 'Gray';
      case HairColor.white:
        return 'White';
    }
  }
}

/// Hair length options
enum HairLength {
  short,
  medium,
  long,
  veryLong;

  String get description {
    switch (this) {
      case HairLength.short:
        return 'short';
      case HairLength.medium:
        return 'shoulder-length';
      case HairLength.long:
        return 'long';
      case HairLength.veryLong:
        return 'very long';
    }
  }

  String get displayName {
    switch (this) {
      case HairLength.short:
        return 'Short';
      case HairLength.medium:
        return 'Medium (Shoulder)';
      case HairLength.long:
        return 'Long';
      case HairLength.veryLong:
        return 'Very Long';
    }
  }
}

/// Hair style options
enum HairStyle {
  straight,
  wavy,
  curly,
  braided,
  ponytail,
  pigtails,
  bun,
  messy;

  String get description {
    switch (this) {
      case HairStyle.straight:
        return 'straight';
      case HairStyle.wavy:
        return 'wavy';
      case HairStyle.curly:
        return 'curly';
      case HairStyle.braided:
        return 'braided';
      case HairStyle.ponytail:
        return 'in a ponytail';
      case HairStyle.pigtails:
        return 'in pigtails';
      case HairStyle.bun:
        return 'in a bun';
      case HairStyle.messy:
        return 'messy/playful';
    }
  }

  String get displayName {
    switch (this) {
      case HairStyle.straight:
        return 'Straight';
      case HairStyle.wavy:
        return 'Wavy';
      case HairStyle.curly:
        return 'Curly';
      case HairStyle.braided:
        return 'Braided';
      case HairStyle.ponytail:
        return 'Ponytail';
      case HairStyle.pigtails:
        return 'Pigtails';
      case HairStyle.bun:
        return 'Bun';
      case HairStyle.messy:
        return 'Messy/Playful';
    }
  }
}

/// Eye color options
enum EyeColor {
  brown,
  blue,
  green,
  hazel,
  gray,
  amber,
  darkBrown,
  lightBlue;

  String get description {
    switch (this) {
      case EyeColor.brown:
        return 'brown';
      case EyeColor.blue:
        return 'blue';
      case EyeColor.green:
        return 'green';
      case EyeColor.hazel:
        return 'hazel';
      case EyeColor.gray:
        return 'gray';
      case EyeColor.amber:
        return 'amber';
      case EyeColor.darkBrown:
        return 'dark brown';
      case EyeColor.lightBlue:
        return 'light blue';
    }
  }

  String get displayName {
    switch (this) {
      case EyeColor.brown:
        return 'Brown';
      case EyeColor.blue:
        return 'Blue';
      case EyeColor.green:
        return 'Green';
      case EyeColor.hazel:
        return 'Hazel';
      case EyeColor.gray:
        return 'Gray';
      case EyeColor.amber:
        return 'Amber';
      case EyeColor.darkBrown:
        return 'Dark Brown';
      case EyeColor.lightBlue:
        return 'Light Blue';
    }
  }
}

/// Skin tone options (diverse and inclusive)
enum SkinTone {
  veryFair,
  fair,
  light,
  lightMedium,
  medium,
  mediumTan,
  tan,
  brown,
  darkBrown,
  veryDark;

  String get description {
    switch (this) {
      case SkinTone.veryFair:
        return 'very fair';
      case SkinTone.fair:
        return 'fair';
      case SkinTone.light:
        return 'light';
      case SkinTone.lightMedium:
        return 'light-medium';
      case SkinTone.medium:
        return 'medium';
      case SkinTone.mediumTan:
        return 'medium-tan';
      case SkinTone.tan:
        return 'tan';
      case SkinTone.brown:
        return 'brown';
      case SkinTone.darkBrown:
        return 'dark brown';
      case SkinTone.veryDark:
        return 'very dark';
    }
  }

  String get displayName {
    switch (this) {
      case SkinTone.veryFair:
        return 'Very Fair';
      case SkinTone.fair:
        return 'Fair';
      case SkinTone.light:
        return 'Light';
      case SkinTone.lightMedium:
        return 'Light-Medium';
      case SkinTone.medium:
        return 'Medium';
      case SkinTone.mediumTan:
        return 'Medium-Tan';
      case SkinTone.tan:
        return 'Tan';
      case SkinTone.brown:
        return 'Brown';
      case SkinTone.darkBrown:
        return 'Dark Brown';
      case SkinTone.veryDark:
        return 'Very Dark';
    }
  }

  /// Get emoji for visual representation
  String get emoji {
    switch (this) {
      case SkinTone.veryFair:
      case SkinTone.fair:
        return '🧒🏻';
      case SkinTone.light:
      case SkinTone.lightMedium:
        return '🧒🏼';
      case SkinTone.medium:
      case SkinTone.mediumTan:
        return '🧒🏽';
      case SkinTone.tan:
      case SkinTone.brown:
        return '🧒🏾';
      case SkinTone.darkBrown:
      case SkinTone.veryDark:
        return '🧒🏿';
    }
  }
}

/// Clothing style options
enum ClothingStyle {
  casual,
  sporty,
  dressy,
  adventurer,
  fantasy,
  superhero,
  princess,
  scientist;

  String get description {
    switch (this) {
      case ClothingStyle.casual:
        return 'casual everyday clothes (t-shirt and pants)';
      case ClothingStyle.sporty:
        return 'sporty athletic wear';
      case ClothingStyle.dressy:
        return 'dressy nice outfit';
      case ClothingStyle.adventurer:
        return 'adventurer outfit with vest and boots';
      case ClothingStyle.fantasy:
        return 'fantasy/magical outfit with cape';
      case ClothingStyle.superhero:
        return 'superhero costume';
      case ClothingStyle.princess:
        return 'princess/royal dress';
      case ClothingStyle.scientist:
        return 'scientist outfit with lab coat';
    }
  }

  String get displayName {
    switch (this) {
      case ClothingStyle.casual:
        return 'Casual (T-shirt & Pants)';
      case ClothingStyle.sporty:
        return 'Sporty';
      case ClothingStyle.dressy:
        return 'Dressy/Nice';
      case ClothingStyle.adventurer:
        return 'Adventurer';
      case ClothingStyle.fantasy:
        return 'Fantasy/Magical';
      case ClothingStyle.superhero:
        return 'Superhero';
      case ClothingStyle.princess:
        return 'Princess/Royal';
      case ClothingStyle.scientist:
        return 'Scientist';
    }
  }

  String get icon {
    switch (this) {
      case ClothingStyle.casual:
        return '👕';
      case ClothingStyle.sporty:
        return '⚽';
      case ClothingStyle.dressy:
        return '👔';
      case ClothingStyle.adventurer:
        return '🎒';
      case ClothingStyle.fantasy:
        return '🪄';
      case ClothingStyle.superhero:
        return '🦸';
      case ClothingStyle.princess:
        return '👑';
      case ClothingStyle.scientist:
        return '🔬';
    }
  }
}

/// Clothing color schemes
enum ClothingColors {
  bright,
  pastel,
  dark,
  earth,
  rainbow,
  monochrome,
  gold,
  blue;

  String get description {
    switch (this) {
      case ClothingColors.bright:
        return 'bright, vibrant';
      case ClothingColors.pastel:
        return 'soft pastel';
      case ClothingColors.dark:
        return 'dark, cool';
      case ClothingColors.earth:
        return 'earth tones (brown, green, tan)';
      case ClothingColors.rainbow:
        return 'rainbow/multicolored';
      case ClothingColors.monochrome:
        return 'black and white';
      case ClothingColors.gold:
        return 'gold and royal';
      case ClothingColors.blue:
        return 'blue tones';
    }
  }

  String get displayName {
    switch (this) {
      case ClothingColors.bright:
        return 'Bright & Vibrant';
      case ClothingColors.pastel:
        return 'Soft Pastels';
      case ClothingColors.dark:
        return 'Dark & Cool';
      case ClothingColors.earth:
        return 'Earth Tones';
      case ClothingColors.rainbow:
        return 'Rainbow/Multicolor';
      case ClothingColors.monochrome:
        return 'Black & White';
      case ClothingColors.gold:
        return 'Gold & Royal';
      case ClothingColors.blue:
        return 'Blue Tones';
    }
  }
}

/// Body build (kept vague for child safety and flexibility)
enum BodyBuild {
  petite,
  average,
  athletic;

  String get description {
    switch (this) {
      case BodyBuild.petite:
        return 'petite';
      case BodyBuild.average:
        return 'average';
      case BodyBuild.athletic:
        return 'athletic';
    }
  }

  String get displayName {
    switch (this) {
      case BodyBuild.petite:
        return 'Petite';
      case BodyBuild.average:
        return 'Average';
      case BodyBuild.athletic:
        return 'Athletic';
    }
  }
}
