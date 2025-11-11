import 'package:flutter/material.dart';

/// Generates avatar URLs using DiceBear API based on character appearance
class AvatarService {
  static const String _baseUrl = 'https://api.dicebear.com/7.x';

  /// Generate avatar URL for a character
  /// Style options: 'avataaars', 'big-smile', 'bottts', 'fun-emoji'
  static String generateAvatarUrl({
    required String characterId,
    String? hairColor,
    String? eyeColor,
    String? outfit,
    String style = 'big-smile', // kid-friendly default
    int size = 200,
  }) {
    // Use character ID as seed for consistency
    final params = <String, String>{
      'seed': characterId,
      'size': size.toString(),
    };

    // Map our appearance choices to DiceBear parameters
    if (hairColor != null) {
      final mapped = _mapHairColor(hairColor);
      if (mapped.isNotEmpty) {
        params['hairColor'] = mapped;
      }
    }

    if (eyeColor != null) {
      final mapped = _mapEyeColor(eyeColor);
      if (mapped.isNotEmpty) {
        params['eyesColor'] = mapped;
      }
    }

    if (outfit != null) {
      final mapped = _mapOutfit(outfit);
      if (mapped.isNotEmpty) {
        params['clothing'] = mapped;
      }
    }

    // Build URL with query parameters
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_baseUrl/$style/svg?$queryString';
  }

  /// Map our hair color choices to DiceBear hair colors
  static String _mapHairColor(String color) {
    final colorLower = color.toLowerCase();

    // DiceBear big-smile style supports these hair colors
    final colorMap = <String, String>{
      'black': '000000',
      'brown': '4a312c',
      'blonde': 'f59797',
      'blond': 'f59797',
      'red': 'c93305',
      'auburn': '8b4513',
      'gray': '929598',
      'grey': '929598',
      'white': 'e8e8e8',
      'blue': '0000ff',
      'green': '00ff00',
      'pink': 'ffc0cb',
      'purple': '800080',
    };

    return colorMap[colorLower] ?? '';
  }

  /// Map our eye color choices to DiceBear eye colors
  static String _mapEyeColor(String color) {
    final colorLower = color.toLowerCase();

    final colorMap = <String, String>{
      'brown': '4a312c',
      'blue': '0000ff',
      'green': '00ff00',
      'hazel': '8b7355',
      'gray': '929598',
      'grey': '929598',
      'amber': 'ffbf00',
    };

    return colorMap[colorLower] ?? '';
  }

  /// Map outfit choices to clothing styles
  static String _mapOutfit(String outfit) {
    final outfitLower = outfit.toLowerCase();

    // DiceBear has different clothing options depending on style
    // For big-smile style, we'll use the seed to influence variety
    final outfitMap = <String, String>{
      'casual': 'variant01',
      'sporty': 'variant02',
      'athletic': 'variant02',
      'fancy': 'variant03',
      'cozy': 'variant04',
      'superhero': 'variant05',
      'princess': 'variant06',
      'prince': 'variant06',
    };

    return outfitMap[outfitLower] ?? '';
  }

  /// Create an avatar widget with the generated image
  static Widget buildAvatarWidget({
    required String characterId,
    String? hairColor,
    String? eyeColor,
    String? outfit,
    double size = 100,
    String style = 'big-smile',
  }) {
    final url = generateAvatarUrl(
      characterId: characterId,
      hairColor: hairColor,
      eyeColor: eyeColor,
      outfit: outfit,
      style: style,
      size: size.toInt(),
    );

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to default avatar if loading fails
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: Icon(
              Icons.person,
              size: size * 0.6,
              color: Colors.grey[600],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: Center(
              child: SizedBox(
                width: size * 0.5,
                height: size * 0.5,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
