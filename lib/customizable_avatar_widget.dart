// lib/customizable_avatar_widget.dart
// Widget to display customizable avatars matching React web app
// Uses CustomPainter for therapeutic, friendly avatar rendering

import 'package:flutter/material.dart';
import 'avatar_models.dart';
import 'dart:math' as math;

class CustomizableAvatarWidget extends StatelessWidget {
  final CharacterAvatar avatar;
  final double size;

  const CustomizableAvatarWidget({
    super.key,
    required this.avatar,
    this.size = 120,
  });

  Color _getSkinColor() {
    switch (avatar.skinColor) {
      case 'PorcelainWhite':
        return const Color(0xFFFFF5E6);
      case 'VeryPale':
        return const Color(0xFFFFE8D1);
      case 'Light':
        return const Color(0xFFFFDFC4);
      case 'Pale':
        return const Color(0xFFF0C8A0);
      case 'Beige':
        return const Color(0xFFEECBA8);
      case 'Tanned':
        return const Color(0xFFE0AC7E);
      case 'Yellow':
        return const Color(0xFFD49A6A);
      case 'Brown':
        return const Color(0xFFC68642);
      case 'DarkBrown':
        return const Color(0xFFA67C52);
      case 'Black':
        return const Color(0xFF8D5524);
      case 'DeepBrown':
        return const Color(0xFF6D4C41);
      case 'VeryDark':
        return const Color(0xFF4A2C12);
      default:
        return const Color(0xFFFFDFC4);
    }
  }

  Color _getHairColor() {
    switch (avatar.hairColor) {
      case 'Blonde':
        return const Color(0xFFF4D03F);
      case 'Brown':
        return const Color(0xFF8B4513);
      case 'Black':
        return const Color(0xFF2C3E50);
      case 'Red':
        return const Color(0xFFC0392B);
      case 'Auburn':
        return const Color(0xFFA04000);
      case 'PastelPink':
        return const Color(0xFFFF6B9D);
      case 'BlondeGolden':
        return const Color(0xFFFFD700);
      case 'SilverGray':
        return const Color(0xFFBDC3C7);
      case 'Platinum':
        return const Color(0xFFE8E8E8);
      default:
        return const Color(0xFF8B4513);
    }
  }

  Color _getClothingColor() {
    switch (avatar.clothingColor) {
      case 'White':
        return const Color(0xFFFFFFFF);
      case 'Pink':
        return const Color(0xFFFF69B4);
      case 'LightPink':
        return const Color(0xFFFFB6C1);
      case 'Purple':
        return const Color(0xFF9B59B6);
      case 'Lavender':
        return const Color(0xFFE6B3FF);
      case 'Coral':
        return const Color(0xFFFF6B6B);
      case 'Peach':
        return const Color(0xFFFFB88C);
      case 'Blue03':
        return const Color(0xFF5DADE2);
      case 'Red':
        return const Color(0xFFE74C3C);
      case 'Gray01':
        return const Color(0xFF95A5A6);
      case 'Black':
        return const Color(0xFF2C3E50);
      case 'PastelGreen':
        return const Color(0xFF58D68D);
      case 'PastelYellow':
        return const Color(0xFFF4D03F);
      case 'Mint':
        return const Color(0xFF98D8C8);
      case 'Turquoise':
        return const Color(0xFF40E0D0);
      case 'Heather':
        return const Color(0xFF3498DB);
      default:
        return const Color(0xFF5DADE2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skinColor = _getSkinColor();
    final hairColor = _getHairColor();
    final clothingColor = _getClothingColor();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Face circle
          Container(
            width: size * 0.85,
            height: size * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: skinColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),

          // Hair (top)
          Positioned(
            top: 0,
            child: Container(
              width: size * 0.85,
              height: size * 0.45,
              decoration: BoxDecoration(
                color: hairColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size),
                  topRight: Radius.circular(size),
                ),
              ),
            ),
          ),

          // Eyes
          Positioned(
            top: size * 0.32,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEye(size),
                SizedBox(width: size * 0.18),
                _buildEye(size),
              ],
            ),
          ),

          // Mouth
          Positioned(
            bottom: size * 0.22,
            child: _buildMouth(size),
          ),

          // Clothing
          Positioned(
            bottom: 0,
            child: Container(
              width: size * 0.7,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: clothingColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size * 0.1),
                  topRight: Radius.circular(size * 0.1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEye(double size) {
    if (avatar.eyeType == 'Happy') {
      // Happy curved eyes
      return Container(
        width: size * 0.14,
        height: size * 0.05,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF2C3E50),
              width: size * 0.01,
            ),
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(size * 0.07),
            bottomRight: Radius.circular(size * 0.07),
          ),
        ),
      );
    } else if (avatar.eyeType == 'Surprised') {
      // Wide surprised eyes
      return Container(
        width: size * 0.1,
        height: size * 0.1,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2C3E50),
        ),
        child: Center(
          child: Container(
            width: size * 0.04,
            height: size * 0.04,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      // Default calm eyes
      return Container(
        width: size * 0.07,
        height: size * 0.07,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2C3E50),
        ),
        child: Center(
          child: Container(
            width: size * 0.02,
            height: size * 0.02,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildMouth(double size) {
    if (avatar.mouthType == 'Smile') {
      // Smiling mouth
      return Container(
        width: size * 0.35,
        height: size * 0.15,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF2C3E50),
              width: size * 0.012,
            ),
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(size * 0.18),
            bottomRight: Radius.circular(size * 0.18),
          ),
        ),
      );
    } else if (avatar.mouthType == 'Twinkle' || avatar.mouthType == 'Excited') {
      // Excited open mouth
      return Container(
        width: size * 0.25,
        height: size * 0.12,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B9D),
          borderRadius: BorderRadius.circular(size * 0.06),
        ),
      );
    } else if (avatar.mouthType == 'Concerned') {
      // Concerned frown
      return Container(
        width: size * 0.3,
        height: size * 0.12,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFF2C3E50),
              width: size * 0.01,
            ),
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size * 0.15),
            topRight: Radius.circular(size * 0.15),
          ),
        ),
      );
    } else {
      // Neutral mouth
      return Container(
        width: size * 0.25,
        height: size * 0.02,
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50),
          borderRadius: BorderRadius.circular(size * 0.01),
        ),
      );
    }
  }
}

class _AvatarPainter extends CustomPainter {
  final Color skinColor;
  final Color hairColor;
  final Color clothingColor;
  final String eyeType;
  final String mouthType;
  final String hairStyle;

  _AvatarPainter({
    required this.skinColor,
    required this.hairColor,
    required this.clothingColor,
    required this.eyeType,
    required this.mouthType,
    required this.hairStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw face
    _drawFace(canvas, center, radius);

    // Draw hair (back layer for styles that go around head)
    if (_isHairBehind()) {
      _drawHair(canvas, center, radius);
    }

    // Draw eyes
    _drawEyes(canvas, center, radius);

    // Draw mouth
    _drawMouth(canvas, center, radius);

    // Draw hair (front layer for styles on top)
    if (!_isHairBehind()) {
      _drawHair(canvas, center, radius);
    }

    // Draw clothing
    _drawClothing(canvas, center, radius);
  }

  bool _isHairBehind() {
    return hairStyle.contains('Long') || hairStyle.contains('Bun');
  }

  void _drawFace(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.fill;

    // Draw circular face
    canvas.drawCircle(center, radius * 0.8, paint);

    // Add subtle shading for cheeks
    final blushPaint = Paint()
      ..color = Colors.pink.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx - radius * 0.4, center.dy + radius * 0.2),
      radius * 0.15,
      blushPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.4, center.dy + radius * 0.2),
      radius * 0.15,
      blushPaint,
    );
  }

  void _drawHair(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.fill;

    if (hairStyle.contains('Short')) {
      // Short hair - simple cap
      final path = Path();
      path.addArc(
        Rect.fromCircle(center: center, radius: radius * 0.85),
        -math.pi,
        math.pi,
      );
      canvas.drawPath(path, paint);
    } else if (hairStyle.contains('Long')) {
      // Long hair - flows down sides
      final path = Path();
      path.moveTo(center.dx - radius * 0.8, center.dy - radius * 0.5);
      path.lineTo(center.dx - radius * 0.9, center.dy + radius * 0.8);
      path.lineTo(center.dx - radius * 0.3, center.dy + radius * 0.8);
      path.lineTo(center.dx - radius * 0.4, center.dy - radius * 0.3);
      path.close();
      canvas.drawPath(path, paint);

      final pathRight = Path();
      pathRight.moveTo(center.dx + radius * 0.8, center.dy - radius * 0.5);
      pathRight.lineTo(center.dx + radius * 0.9, center.dy + radius * 0.8);
      pathRight.lineTo(center.dx + radius * 0.3, center.dy + radius * 0.8);
      pathRight.lineTo(center.dx + radius * 0.4, center.dy - radius * 0.3);
      pathRight.close();
      canvas.drawPath(pathRight, paint);

      // Top of hair
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.85),
        -math.pi,
        math.pi,
        true,
        paint,
      );
    } else if (hairStyle.contains('Bun')) {
      // Hair with bun on top
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.85),
        -math.pi,
        math.pi,
        true,
        paint,
      );

      // Bun
      canvas.drawCircle(
        Offset(center.dx, center.dy - radius * 0.9),
        radius * 0.25,
        paint,
      );
    } else if (hairStyle.contains('Ponytail')) {
      // Hair pulled back
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.85),
        -math.pi,
        math.pi,
        true,
        paint,
      );

      // Ponytail behind
      final ponytailPath = Path();
      ponytailPath.addOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + radius * 0.3),
          width: radius * 0.3,
          height: radius * 0.6,
        ),
      );
      canvas.drawPath(ponytailPath, paint);
    } else {
      // Default - medium hair
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.85),
        -math.pi,
        math.pi,
        true,
        paint,
      );
    }
  }

  void _drawEyes(Canvas canvas, Offset center, double radius) {
    final eyePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    final leftEye = Offset(center.dx - radius * 0.3, center.dy - radius * 0.1);
    final rightEye = Offset(center.dx + radius * 0.3, center.dy - radius * 0.1);

    if (eyeType == 'Happy') {
      // Happy eyes - curved lines
      final path = Path();
      path.moveTo(leftEye.dx - radius * 0.15, leftEye.dy);
      path.quadraticBezierTo(
        leftEye.dx,
        leftEye.dy + radius * 0.1,
        leftEye.dx + radius * 0.15,
        leftEye.dy,
      );
      canvas.drawPath(
        path,
        eyePaint..style = PaintingStyle.stroke..strokeWidth = 2,
      );

      final pathRight = Path();
      pathRight.moveTo(rightEye.dx - radius * 0.15, rightEye.dy);
      pathRight.quadraticBezierTo(
        rightEye.dx,
        rightEye.dy + radius * 0.1,
        rightEye.dx + radius * 0.15,
        rightEye.dy,
      );
      canvas.drawPath(
        pathRight,
        eyePaint..style = PaintingStyle.stroke..strokeWidth = 2,
      );
    } else if (eyeType == 'Surprised') {
      // Wide open eyes
      canvas.drawCircle(leftEye, radius * 0.12, eyePaint..style = PaintingStyle.fill);
      canvas.drawCircle(rightEye, radius * 0.12, eyePaint);
      // Highlights
      canvas.drawCircle(
        Offset(leftEye.dx - radius * 0.04, leftEye.dy - radius * 0.04),
        radius * 0.04,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(rightEye.dx - radius * 0.04, rightEye.dy - radius * 0.04),
        radius * 0.04,
        Paint()..color = Colors.white,
      );
    } else {
      // Default - simple dots
      canvas.drawCircle(leftEye, radius * 0.08, eyePaint..style = PaintingStyle.fill);
      canvas.drawCircle(rightEye, radius * 0.08, eyePaint);
    }
  }

  void _drawMouth(Canvas canvas, Offset center, double radius) {
    final mouthPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final mouthCenter = Offset(center.dx, center.dy + radius * 0.3);

    if (mouthType == 'Smile') {
      // Smiling mouth
      final path = Path();
      path.moveTo(mouthCenter.dx - radius * 0.25, mouthCenter.dy);
      path.quadraticBezierTo(
        mouthCenter.dx,
        mouthCenter.dy + radius * 0.15,
        mouthCenter.dx + radius * 0.25,
        mouthCenter.dy,
      );
      canvas.drawPath(path, mouthPaint);
    } else if (mouthType == 'Concerned') {
      // Concerned mouth - slight frown
      final path = Path();
      path.moveTo(mouthCenter.dx - radius * 0.2, mouthCenter.dy);
      path.quadraticBezierTo(
        mouthCenter.dx,
        mouthCenter.dy - radius * 0.1,
        mouthCenter.dx + radius * 0.2,
        mouthCenter.dy,
      );
      canvas.drawPath(path, mouthPaint);
    } else if (mouthType == 'Twinkle' || mouthType == 'Excited') {
      // Excited - big smile
      final path = Path();
      path.moveTo(mouthCenter.dx - radius * 0.3, mouthCenter.dy);
      path.quadraticBezierTo(
        mouthCenter.dx,
        mouthCenter.dy + radius * 0.2,
        mouthCenter.dx + radius * 0.3,
        mouthCenter.dy,
      );
      canvas.drawPath(path, mouthPaint);
    } else {
      // Default - neutral
      canvas.drawLine(
        Offset(mouthCenter.dx - radius * 0.2, mouthCenter.dy),
        Offset(mouthCenter.dx + radius * 0.2, mouthCenter.dy),
        mouthPaint,
      );
    }
  }

  void _drawClothing(Canvas canvas, Offset center, double radius) {
    final clothingPaint = Paint()
      ..color = clothingColor
      ..style = PaintingStyle.fill;

    // Simple clothing - neck/collar area
    final clothingRect = Rect.fromLTWH(
      center.dx - radius * 0.6,
      center.dy + radius * 0.7,
      radius * 1.2,
      radius * 0.5,
    );

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        clothingRect,
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
      ),
      clothingPaint,
    );

    // Add subtle border
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        clothingRect,
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
      ),
      Paint()
        ..color = clothingColor.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) {
    return oldDelegate.skinColor != skinColor ||
        oldDelegate.hairColor != hairColor ||
        oldDelegate.clothingColor != clothingColor ||
        oldDelegate.eyeType != eyeType ||
        oldDelegate.mouthType != mouthType ||
        oldDelegate.hairStyle != hairStyle;
  }
}
