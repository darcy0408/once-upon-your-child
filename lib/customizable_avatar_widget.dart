// lib/customizable_avatar_widget.dart
// Avatar preview widget that renders Avataaars-based SVGs via network image.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'avatar_models.dart';

class CustomizableAvatarWidget extends StatelessWidget {
  final CharacterAvatar avatar;
  final double size;
  final String? customSeed;

  const CustomizableAvatarWidget({
    super.key,
    required this.avatar,
    this.size = 120,
    this.customSeed,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatar.toAvataaarsUrl(
      circleBackground: false,
      customSeed: customSeed,
    );

    // Debug: print the avatar URL
    print('?? Avatar URL: $imageUrl');

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
            child: FutureBuilder<bool>(
              future: _loadSvg(imageUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SizedBox(
                      width: size * 0.35,
                      height: size * 0.35,
                      child: const CircularProgressIndicator(strokeWidth: 3),
                    ),
                  );
                } else if (snapshot.hasError || snapshot.data != true) {
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(
                        Icons.person,
                        size: size * 0.5,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                } else {
                  return SvgPicture.network(
                    imageUrl,
                    key: ValueKey(imageUrl),
                    fit: BoxFit.contain,
                    width: size,
                    height: size,
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _loadSvg(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('? Failed to load avatar SVG: $e');
      return false;
    }
  }
}
