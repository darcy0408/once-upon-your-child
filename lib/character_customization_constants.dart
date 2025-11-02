// lib/character_customization_constants.dart

import 'package:flutter/material.dart';

class CharacterCustomization {
  // Expanded skin tone palette - 8+ tones from very fair to very deep
  static const Map<String, SkinToneOption> skinTones = {
    'veryFair': SkinToneOption(
      name: 'Very Fair',
      color: Color(0xFFFDE7D6),
      description: 'Very light, pink-ivory',
    ),
    'fair': SkinToneOption(
      name: 'Fair',
      color: Color(0xFFF5D5C0),
      description: 'Fair, neutral beige',
    ),
    'lightWarm': SkinToneOption(
      name: 'Light Warm',
      color: Color(0xFFE8B895),
      description: 'Light warm, peachy',
    ),
    'lightNeutral': SkinToneOption(
      name: 'Light Neutral',
      color: Color(0xFFD4A574),
      description: 'Light neutral tone',
    ),
    'mediumGolden': SkinToneOption(
      name: 'Medium Golden',
      color: Color(0xFFC68642),
      description: 'Medium golden',
    ),
    'mediumWarm': SkinToneOption(
      name: 'Medium Warm',
      color: Color(0xFF9D6B3B),
      description: 'Medium brown',
    ),
    'deepBrown': SkinToneOption(
      name: 'Deep Brown',
      color: Color(0xFF5D3F26),
      description: 'Deep brown',
    ),
    'veryDeepWarm': SkinToneOption(
      name: 'Very Deep Warm',
      color: Color(0xFF3A2618),
      description: 'Very deep warm brown',
    ),
  };

  // Expanded hair styles - includes long, short, curly, straight, etc.
  static const List<String> hairStyles = [
    'Long Straight',
    'Long Wavy',
    'Curly',
    'Afro Puff',
    'Short Buzz',
    'Short Fade',
    'Bob',
    'Ponytail',
    'Braids',
    'Short Locs',
    'Short Spiky',
    'Medium Wavy',
  ];

  // Expanded hair colors - natural + fun colors
  static const Map<String, HairColorOption> hairColors = {
    'black': HairColorOption(name: 'Black', color: Color(0xFF1a1a1a)),
    'darkBrown': HairColorOption(name: 'Dark Brown', color: Color(0xFF3d2817)),
    'mediumBrown': HairColorOption(name: 'Medium Brown', color: Color(0xFF6b4423)),
    'lightBrown': HairColorOption(name: 'Light Brown', color: Color(0xFF8b5a2b)),
    'blonde': HairColorOption(name: 'Blonde', color: Color(0xFFf4d03f)),
    'strawberryBlonde': HairColorOption(name: 'Strawberry Blonde', color: Color(0xFFe8927c)),
    'red': HairColorOption(name: 'Red', color: Color(0xFFa52a2a)),
    'auburn': HairColorOption(name: 'Auburn', color: Color(0xFF7c2d12)),
    'blue': HairColorOption(name: 'Blue', color: Color(0xFF3b82f6)),
    'pink': HairColorOption(name: 'Pink', color: Color(0xFFec4899)),
    'purple': HairColorOption(name: 'Purple', color: Color(0xFF9333ea)),
    'green': HairColorOption(name: 'Green', color: Color(0xFF10b981)),
  };

  // Clothing style presets
  static const List<String> clothingStyles = [
    'Casual',
    'Sporty',
    'Fancy',
    'Dressy',
    'Cozy',
    'Cool',
  ];

  // Expanded clothing colors - multiple blues, greens, warm colors, neutrals
  static const Map<String, ClothingColorOption> clothingColors = {
    // Greens
    'mint': ClothingColorOption(name: 'Mint', color: Color(0xFF98D8C8)),
    'brightGreen': ClothingColorOption(name: 'Bright Green', color: Color(0xFF10b981)),
    'forestGreen': ClothingColorOption(name: 'Forest Green', color: Color(0xFF065f46)),

    // Blues
    'skyBlue': ClothingColorOption(name: 'Sky Blue', color: Color(0xFF87CEEB)),
    'royalBlue': ClothingColorOption(name: 'Royal Blue', color: Color(0xFF2563eb)),
    'navy': ClothingColorOption(name: 'Navy', color: Color(0xFF1e3a8a)),

    // Warm colors
    'red': ClothingColorOption(name: 'Red', color: Color(0xFFdc2626)),
    'orange': ClothingColorOption(name: 'Orange', color: Color(0xFFf97316)),
    'yellow': ClothingColorOption(name: 'Yellow', color: Color(0xFFfbbf24)),
    'pink': ClothingColorOption(name: 'Pink', color: Color(0xFFec4899)),
    'purple': ClothingColorOption(name: 'Purple', color: Color(0xFF9333ea)),

    // Neutrals
    'white': ClothingColorOption(name: 'White', color: Color(0xFFffffff)),
    'gray': ClothingColorOption(name: 'Gray', color: Color(0xFF6b7280)),
    'black': ClothingColorOption(name: 'Black', color: Color(0xFF1f2937)),
  };

  // Theme colors for the green-themed UI
  static const Color primaryBackground = Color(0xFF0f1a12); // Almost black with green tint
  static const Color secondaryBackground = Color(0xFF1a2f1f); // Dark green
  static const Color cardBackground = Color(0xFF2d5a3d); // Forest green
  static const Color accentGreen = Color(0xFF4a9d6a); // Bright green for highlights
  static const Color lightGreen = Color(0xFF7fd3a8); // Light green for text
  static const Color softGreen = Color(0xFFa8d5ba); // Soft green for subtle text
  static const Color borderGreen = Color(0xFF2d5a3d); // Border color
}

class SkinToneOption {
  final String name;
  final Color color;
  final String description;

  const SkinToneOption({
    required this.name,
    required this.color,
    required this.description,
  });
}

class HairColorOption {
  final String name;
  final Color color;

  const HairColorOption({
    required this.name,
    required this.color,
  });
}

class ClothingColorOption {
  final String name;
  final Color color;

  const ClothingColorOption({
    required this.name,
    required this.color,
  });
}
