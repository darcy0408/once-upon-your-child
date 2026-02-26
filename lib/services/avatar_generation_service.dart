import 'package:flutter/foundation.dart';
import '../models/generated_avatar.dart';

/// Service for generating avatars using DiceBear (https://dicebear.com)
/// No API key required — avatars are generated deterministically from a seed URL.
class AvatarGenerationService {
  AvatarGenerationService({String? baseUrl}); // baseUrl kept for API compatibility

  // Maps app style names to DiceBear collection names
  static const _styleMap = {
    'pixar': 'adventurer',
    'watercolor': 'lorelei',
    'cartoon': 'avataaars',
    'clay': 'micah',
  };

  // Maps skin tone labels to DiceBear skinColor hex values (no #)
  static const _skinToneMap = {
    'Very Light': 'ffdbb4',
    'Light': 'edb98a',
    'Medium Light': 'd08b5b',
    'Medium Tan': 'ae5d29',
    'Tan': 'ae5d29',
    'Brown': '614335',
    'Dark Brown': '4a312c',
    'Very Dark': '3b2219',
  };

  /// Generate a new avatar using DiceBear.
  /// Returns instantly — the image URL is loaded lazily by the widget.
  Future<GeneratedAvatar> generateAvatar({
    required String characterName,
    required int age,
    required String style,
    Map<String, String>? features,
    Map<String, dynamic>? emotionData,
    String? seed,
  }) async {
    final effectiveSeed = seed ?? '${characterName}_${DateTime.now().millisecondsSinceEpoch}';
    final imageUrl = _buildDiceBearUrl(style, effectiveSeed, features);

    debugPrint('🎨 Avatar URL: $imageUrl');

    return GeneratedAvatar(
      id: 'dicebear_${DateTime.now().millisecondsSinceEpoch}',
      imageBase64: imageUrl, // Widget handles both URLs and base64
      seed: effectiveSeed,
      style: style,
      attributes: features ?? {},
      emotionData: emotionData,
      generatedAt: DateTime.now(),
    );
  }

  /// Regenerate an avatar (for "re-roll" functionality)
  Future<GeneratedAvatar> regenerateAvatar({
    required String characterName,
    required int age,
    required String style,
    required Map<String, String> features,
    Map<String, dynamic>? emotionData,
  }) async {
    // No seed = new variation via timestamp
    return generateAvatar(
      characterName: characterName,
      age: age,
      style: style,
      features: features,
      emotionData: emotionData,
      seed: null,
    );
  }

  /// Get fallback preset avatars using DiceBear seeds
  Future<List<Map<String, String>>> getFallbackAvatars({String? style}) async {
    final diceBearStyle = _styleMap[style] ?? 'adventurer';
    final seeds = ['Aria', 'Leo', 'Mia', 'Sam', 'Zoe', 'Kai'];
    return seeds.map((seed) => {
      'name': seed,
      'image_url': 'https://api.dicebear.com/9.x/$diceBearStyle/png?seed=$seed&size=150',
    }).toList();
  }

  /// Always healthy — no backend dependency
  Future<bool> checkHealth() async => true;

  String _buildDiceBearUrl(String style, String seed, Map<String, String>? features) {
    final diceBearStyle = _styleMap[style] ?? 'adventurer';
    final encodedSeed = Uri.encodeComponent(seed);
    final params = StringBuffer('seed=$encodedSeed&size=300&radius=10');

    if (features != null) {
      final skinColor = _skinToneMap[features['skin_tone']];
      if (skinColor != null) params.write('&skinColor=$skinColor');
    }

    return 'https://api.dicebear.com/9.x/$diceBearStyle/png?$params';
  }
}

/// Exception thrown when avatar generation fails
class AvatarGenerationException implements Exception {
  final String message;
  final String? errorCode;

  AvatarGenerationException(this.message, {this.errorCode});

  @override
  String toString() => 'AvatarGenerationException: $message${errorCode != null ? ' ($errorCode)' : ''}';
}

/// Exception thrown when avatar validation fails
class AvatarValidationException implements Exception {
  final String message;

  AvatarValidationException(this.message);

  @override
  String toString() => 'AvatarValidationException: $message';
}
