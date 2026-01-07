/// Helper class to convert avatar parameters to natural language descriptions
/// for AI image generation prompts
class AvatarToPromptHelper {
  /// Convert avataaars parameters to natural language description
  static String avatarToDescription(
    Map<String, String> avatarParams, {
    required int age,
    String? context,
  }) {
    final parts = <String>[];

    // Age and context
    parts.add('$age-year-old child');

    // Skin tone
    if (avatarParams.containsKey('skinColor')) {
      final skinTone = _humanizeSkinColor(avatarParams['skinColor']!);
      parts.add('with $skinTone skin');
    }

    // Hair
    if (avatarParams.containsKey('top')) {
      final hair = _humanizeHairStyle(avatarParams['top']!);
      final hairColor = avatarParams.containsKey('hairColor')
          ? _humanizeColor(avatarParams['hairColor']!)
          : 'brown';
      parts.add('$hairColor $hair hair');
    }

    // Facial features
    if (avatarParams.containsKey('eyes')) {
      final expression = _humanizeEyes(avatarParams['eyes']!);
      if (expression.isNotEmpty) {
        parts.add('$expression eyes');
      }
    }

    // Clothing
    if (avatarParams.containsKey('clothing')) {
      final clothingItem = _humanizeClothing(avatarParams['clothing']!);
      final color = avatarParams.containsKey('clothesColor')
          ? _humanizeColor(avatarParams['clothesColor']!)
          : '';
      parts.add('wearing a ${color.isNotEmpty ? '$color ' : ''}$clothingItem');
    }

    // Accessories
    if (avatarParams.containsKey('accessories')) {
      final accessory = _humanizeAccessory(avatarParams['accessories']!);
      if (accessory.isNotEmpty) {
        parts.add('wearing $accessory');
      }
    }

    final description = parts.join(', ');

    if (context != null) {
      return '$description, $context';
    }

    return description;
  }

  /// Generate story illustration prompt
  static String toStoryIllustrationPrompt(
    Map<String, String> avatarParams, {
    required int age,
    required String scene,
    required String emotion,
  }) {
    final characterDesc = avatarToDescription(avatarParams, age: age);

    return '''
Generate a children's book illustration:
- Character: $characterDesc
- Scene: $scene
- Emotion/Action: $emotion
- Style: Warm, friendly, age-appropriate
- Quality: High detail, colorful, expressive
''';
  }

  /// Generate coloring page prompt
  static String toColoringPagePrompt(
    Map<String, String> avatarParams, {
    required int age,
    required String activity,
  }) {
    final characterDesc = avatarToDescription(avatarParams, age: age);

    return '''
Generate a coloring book page:
- Character: $characterDesc
- Activity: $activity
- Style: Simple black outlines, white background
- Details: Clear shapes, suitable for children ages $age-${age + 2} to color
- No shading, no complex patterns, thick lines
- Full body illustration
''';
  }

  // Helper methods to convert avataaars values to natural language

  static String _humanizeSkinColor(String code) {
    // Map skin color codes to descriptions
    final map = {
      'light': 'light',
      'tanned': 'tan',
      'yellow': 'light',
      'pale': 'pale',
      'brown': 'brown',
      'darkBrown': 'dark brown',
      'black': 'dark',
    };
    return map[code] ?? 'medium';
  }

  static String _humanizeHairStyle(String style) {
    final map = {
      'curly': 'curly',
      'straight': 'straight',
      'bob': 'bob-cut',
      'bun': 'in a bun',
      'long': 'long',
      'short': 'short',
      'dreads': 'dreadlocks',
      'shaggy': 'shaggy',
      'bigHair': 'voluminous',
      'bun': 'hair in a bun',
      'curly': 'curly',
      'curvy': 'wavy',
      'dreads': 'dreadlocks',
      'frizzle': 'frizzy',
      'fro': 'afro',
      'froBand': 'afro with headband',
      'miaWallace': 'sleek bob',
      'longButNotTooLong': 'shoulder-length',
      'shavedSides': 'shaved sides',
      'straight01': 'straight',
      'straight02': 'straight and sleek',
      'straightAndStrand': 'straight with strands',
      'dreads01': 'long dreadlocks',
      'dreads02': 'short dreadlocks',
      'frida': 'updo with flowers',
      'shaggyMullet': 'shaggy mullet',
      'shaggy': 'shaggy',
      'shortCurly': 'short curly',
      'shortFlat': 'short and flat',
      'shortRound': 'short and round',
      'shortWaved': 'short wavy',
      'sides': 'side-parted',
      'theCaesar': 'caesar cut',
      'theCaesarAndSidePart': 'caesar with side part',
      'winterHat1': 'wearing a winter hat',
      'winterHat2': 'wearing a beanie',
      'winterHat3': 'wearing a knit cap',
      'winterHat4': 'wearing a winter beanie',
      'eyepatch': 'wearing an eyepatch',
      'hat': 'wearing a hat',
      'hijab': 'wearing a hijab',
      'turban': 'wearing a turban',
      'noHair': 'no hair',
    };
    return map[style] ?? style.replaceAll(RegExp(r'([A-Z])'), ' \$1').toLowerCase();
  }

  static String _humanizeEyes(String eyes) {
    final map = {
      'happy': 'happy',
      'default': 'friendly',
      'cry': 'teary',
      'surprised': 'wide surprised',
      'hearts': 'loving',
      'close': 'closed',
      'wink': 'winking',
      'winkWacky': 'playfully winking',
      'squint': 'squinting',
      'side': 'looking to the side',
      'dizzy': 'dizzy',
      'eyeRoll': 'rolling',
      'xDizzy': 'dazed',
    };
    return map[eyes] ?? '';
  }

  static String _humanizeClothing(String clothing) {
    final map = {
      'hoodie': 'hoodie',
      'blazerAndShirt': 'blazer with shirt',
      'blazerAndSweater': 'blazer with sweater',
      'collarAndSweater': 'collared sweater',
      'graphicShirt': 'graphic t-shirt',
      'overall': 'overalls',
      'shirtCrewNeck': 'crew neck shirt',
      'shirtScoopNeck': 'scoop neck shirt',
      'shirtVNeck': 'v-neck shirt',
    };
    return map[clothing] ?? clothing;
  }

  static String _humanizeAccessory(String accessory) {
    final map = {
      'prescription01': 'round glasses',
      'prescription02': 'square glasses',
      'round': 'round glasses',
      'sunglasses': 'sunglasses',
      'wayfarers': 'wayfarer sunglasses',
      'kurt': 'headband',
      'blank': '',
    };
    return map[accessory] ?? accessory;
  }

  static String _humanizeColor(String color) {
    // Handle hex colors
    if (color.startsWith('#')) {
      return _hexToColorName(color);
    }

    // Color names are already human-readable in avataaars
    // Convert camelCase to space-separated lowercase
    return color.replaceAll(RegExp(r'([A-Z])'), ' \$1').toLowerCase().trim();
  }

  static String _hexToColorName(String hex) {
    // Common color mappings for hex values
    final map = {
      '#000000': 'black',
      '#FFFFFF': 'white',
      '#FF0000': 'red',
      '#00FF00': 'green',
      '#0000FF': 'blue',
      '#FFFF00': 'yellow',
      '#FF00FF': 'magenta',
      '#00FFFF': 'cyan',
      '#FFA500': 'orange',
      '#800080': 'purple',
      '#FFC0CB': 'pink',
      '#A52A2A': 'brown',
      '#808080': 'gray',
    };

    return map[hex.toUpperCase()] ?? 'colorful';
  }
}
