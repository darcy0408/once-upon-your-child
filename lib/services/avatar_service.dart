import 'package:flutter/material.dart';

class AvatarService {
  static String generateAvatarUrl({
    required String characterId,
    String? hairColor,
    String? eyeColor,
    String? outfit,
  }) {
    // TODO: Implement DiceBear API for avatar generation
    return 'https://api.dicebear.com/8.x/pixel-art/svg?seed=$characterId';
  }

  static Widget buildAvatarWidget({
    required String characterId,
    String? hairColor,
    String? eyeColor,
    String? outfit,
    double size = 100,
  }) {
    // TODO: Implement DiceBear API for avatar generation
    return Image.network(
      generateAvatarUrl(
        characterId: characterId,
        hairColor: hairColor,
        eyeColor: eyeColor,
        outfit: outfit,
      ),
      width: size,
      height: size,
    );
  }
}
