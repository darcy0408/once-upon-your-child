// lib/customizable_avatar_widget.dart
// Avatar preview widget that renders Avataaars-based SVGs via network image.

import 'package:flutter/material.dart';
import 'avatar_models.dart';

class CustomizableAvatarWidget extends StatelessWidget {
  final CharacterAvatar avatar;
  final double size;

  const CustomizableAvatarWidget({
    super.key,
    required this.avatar,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatar.toAvataaarsUrl(circleBackground: false);

    final devicePixelRatio =
        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFF6EA),
              Color(0xFFE8F9F3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ClipOval(
            child: Image.network(
              imageUrl,
              key: ValueKey(imageUrl),
              fit: BoxFit.contain,
              width: size,
              height: size,
              cacheWidth: (size * devicePixelRatio).clamp(120, 600).round(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: SizedBox(
                    width: size * 0.35,
                    height: size * 0.35,
                    child: const CircularProgressIndicator(strokeWidth: 3),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFE0F2F1),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_outline,
                  size: 48,
                  color: Color(0xFF558B2F),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
