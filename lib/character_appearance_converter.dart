// lib/character_appearance_converter.dart
// Converts simple Character model to detailed CharacterAppearance for image generation

import 'models.dart';
import 'character_appearance.dart';
import 'story_illustration_service.dart';

class CharacterAppearanceConverter {
  /// Convert a Character to CharacterAppearance for image generation
  static CharacterAppearance fromCharacter(Character character) {
    return CharacterAppearance(
      characterName: character.name,
      hairColor: _parseHairColor(character.hair),
      hairLength: _guessHairLength(character.hairstyle),
      hairStyle: _parseHairStyle(character.hairstyle),
      eyeColor: _parseEyeColor(character.eyes),
      skinTone: _parseSkinTone(character.skinTone),
      clothingStyle: _guessClothingStyle(character.role),
      clothingColors: ClothingColors.bright, // Default to bright for kids
      bodyBuild: BodyBuild.average, // Default to average
    );
  }

  /// Parse hair color from string
  static HairColor _parseHairColor(String? hairColorStr) {
    if (hairColorStr == null) return HairColor.brown;

    final normalized = hairColorStr.toLowerCase().trim();

    if (normalized.contains('blonde') || normalized.contains('blond')) {
      if (normalized.contains('strawberry')) {
        return HairColor.strawberryBlonde;
      }
      return HairColor.blonde;
    }
    if (normalized.contains('black')) {
      return HairColor.black;
    }
    if (normalized.contains('red')) {
      return HairColor.red;
    }
    if (normalized.contains('auburn')) {
      return HairColor.auburn;
    }
    if (normalized.contains('dark brown')) {
      return HairColor.darkBrown;
    }
    if (normalized.contains('light brown')) {
      return HairColor.lightBrown;
    }
    if (normalized.contains('brown')) {
      return HairColor.brown;
    }
    if (normalized.contains('gray') || normalized.contains('grey')) {
      return HairColor.gray;
    }
    if (normalized.contains('white')) {
      return HairColor.white;
    }

    // Default
    return HairColor.brown;
  }

  /// Parse hairstyle from string
  static HairStyle _parseHairStyle(String? hairstyleStr) {
    if (hairstyleStr == null) return HairStyle.straight;

    final normalized = hairstyleStr.toLowerCase().trim();

    if (normalized.contains('curly') || normalized.contains('curl')) {
      return HairStyle.curly;
    }
    if (normalized.contains('wavy') || normalized.contains('wave')) {
      return HairStyle.wavy;
    }
    if (normalized.contains('braid')) {
      return HairStyle.braided;
    }
    if (normalized.contains('ponytail') || normalized.contains('pony tail')) {
      return HairStyle.ponytail;
    }
    if (normalized.contains('pigtail')) {
      return HairStyle.pigtails;
    }
    if (normalized.contains('bun')) {
      return HairStyle.bun;
    }
    if (normalized.contains('messy') || normalized.contains('wild')) {
      return HairStyle.messy;
    }
    if (normalized.contains('straight')) {
      return HairStyle.straight;
    }

    // Afro special case
    if (normalized.contains('afro')) {
      return HairStyle.curly; // Afros are curly
    }

    // Default
    return HairStyle.straight;
  }

  /// Guess hair length from hairstyle
  static HairLength _guessHairLength(String? hairstyleStr) {
    if (hairstyleStr == null) return HairLength.medium;

    final normalized = hairstyleStr.toLowerCase().trim();

    if (normalized.contains('long')) return HairLength.long;
    if (normalized.contains('short')) return HairLength.short;
    if (normalized.contains('afro')) return HairLength.medium;
    if (normalized.contains('ponytail') || normalized.contains('braid')) {
      return HairLength.long; // Usually need long hair for these
    }

    // Default
    return HairLength.medium;
  }

  /// Parse eye color from string
  static EyeColor _parseEyeColor(String? eyeColorStr) {
    if (eyeColorStr == null) return EyeColor.brown;

    final normalized = eyeColorStr.toLowerCase().trim();

    if (normalized.contains('blue')) {
      if (normalized.contains('light')) {
        return EyeColor.lightBlue;
      }
      return EyeColor.blue;
    }
    if (normalized.contains('green')) {
      return EyeColor.green;
    }
    if (normalized.contains('hazel')) {
      return EyeColor.hazel;
    }
    if (normalized.contains('gray') || normalized.contains('grey')) {
      return EyeColor.gray;
    }
    if (normalized.contains('amber')) {
      return EyeColor.amber;
    }
    if (normalized.contains('dark brown')) {
      return EyeColor.darkBrown;
    }
    if (normalized.contains('brown')) {
      return EyeColor.brown;
    }

    // Default
    return EyeColor.brown;
  }

  /// Parse skin tone from string
  static SkinTone _parseSkinTone(String? skinToneStr) {
    if (skinToneStr == null) return SkinTone.medium;

    final normalized = skinToneStr.toLowerCase().trim();

    // Very specific matches first
    if (normalized.contains('very fair')) return SkinTone.veryFair;
    if (normalized.contains('very light')) return SkinTone.veryFair;
    if (normalized.contains('very dark')) return SkinTone.veryDark;
    if (normalized.contains('very deep')) return SkinTone.veryDark;

    // Compound matches
    if (normalized.contains('light-medium') ||
        normalized.contains('light medium')) {
      return SkinTone.lightMedium;
    }
    if (normalized.contains('medium-dark') ||
        normalized.contains('medium dark')) {
      return SkinTone.brown;
    }
    if (normalized.contains('medium-tan') ||
        normalized.contains('medium tan')) {
      return SkinTone.mediumTan;
    }

    // Single word matches
    if (normalized.contains('fair')) return SkinTone.fair;
    if (normalized.contains('light')) return SkinTone.light;
    if (normalized.contains('medium')) return SkinTone.medium;
    if (normalized.contains('tan')) return SkinTone.tan;
    if (normalized.contains('dark brown')) return SkinTone.darkBrown;
    if (normalized.contains('brown')) return SkinTone.brown;
    if (normalized.contains('dark')) return SkinTone.darkBrown;
    if (normalized.contains('deep')) return SkinTone.veryDark;

    // Default
    return SkinTone.medium;
  }

  /// Guess clothing style from character role
  static ClothingStyle _guessClothingStyle(String? role) {
    if (role == null) return ClothingStyle.casual;

    final normalized = role.toLowerCase().trim();

    if (normalized.contains('superhero')) return ClothingStyle.superhero;
    if (normalized.contains('princess') || normalized.contains('prince')) {
      return ClothingStyle.princess;
    }
    if (normalized.contains('scientist')) return ClothingStyle.scientist;
    if (normalized.contains('explorer') || normalized.contains('adventurer')) {
      return ClothingStyle.adventurer;
    }
    if (normalized.contains('wizard') ||
        normalized.contains('witch') ||
        normalized.contains('magic')) {
      return ClothingStyle.fantasy;
    }
    if (normalized.contains('sport') || normalized.contains('athlete')) {
      return ClothingStyle.sporty;
    }

    // Default
    return ClothingStyle.casual;
  }

  /// Create a detailed prompt description for the character
  static String createDetailedPrompt(Character character,
      {String? additionalContext}) {
    final appearance = fromCharacter(character);
    final basePrompt = appearance.toPromptDescription();

    String ageDescription = '';
    if (character.age <= 5) {
      ageDescription = 'young child (age ${character.age})';
    } else if (character.age <= 8) {
      ageDescription = 'child (age ${character.age})';
    } else if (character.age <= 12) {
      ageDescription = 'pre-teen child (age ${character.age})';
    } else {
      ageDescription = 'teenager (age ${character.age})';
    }

    String genderDescription = character.gender ?? 'child';

    String fullPrompt = '''
$basePrompt
- Age: $ageDescription
- Gender presentation: $genderDescription
''';

    if (additionalContext != null && additionalContext.isNotEmpty) {
      fullPrompt += '\n$additionalContext';
    }

    return fullPrompt.trim();
  }

  /// Create a prompt specifically for coloring book pages
  static String createColoringBookPrompt(Character character, String scene) {
    final appearance = fromCharacter(character);

    return '''
Create a BLACK AND WHITE COLORING BOOK PAGE (line art only) for children.

CHARACTER DETAILS:
${appearance.toColoringBookDescription()}
- Name: ${character.name}
- Age: ${character.age}

SCENE: $scene

REQUIREMENTS:
- BLACK OUTLINES ONLY on white background
- NO colors, NO shading, NO gray tones
- Bold, clear lines suitable for coloring
- Simple shapes and large areas to color
- Child-friendly and engaging
- Include character prominently
- Safe for ages 4-8
- High contrast for easy printing

STYLE: Classic children's coloring book, clean line art
'''
        .trim();
  }

  /// Create a prompt for story illustrations
  static String createStoryIllustrationPrompt(
    Character character,
    String scene, {
    String? theme,
    IllustrationStyle style = IllustrationStyle.childrenBook,
  }) {
    final detailedCharacter = createDetailedPrompt(character);

    return '''
Create a beautiful children's story illustration ${style.promptModifier}.

CHARACTER:
$detailedCharacter

SCENE: $scene
${theme != null ? 'THEME: $theme' : ''}

REQUIREMENTS:
- Child-friendly and safe for ages 4-8
- Warm, engaging, colorful
- Show the character clearly
- Express emotion and action
- Beautiful composition
- Professional quality
- No scary or inappropriate elements

STYLE: ${style.displayName} illustration
'''
        .trim();
  }

  /// Create a prompt for character portrait
  static String createPortraitPrompt(Character character) {
    final detailedCharacter = createDetailedPrompt(character);

    return '''
Create a beautiful character portrait for a children's story.

CHARACTER DETAILS:
$detailedCharacter

PORTRAIT REQUIREMENTS:
- Head and shoulders view
- Friendly, warm expression
- Smiling or pleasant look
- Clear facial features
- Engaging and approachable
- Professional quality
- Bright, cheerful colors
- Safe and appropriate for children ages 4-8
- Beautiful lighting
- Storybook illustration style

STYLE: Children's book illustration, warm and inviting
'''
        .trim();
  }
}
