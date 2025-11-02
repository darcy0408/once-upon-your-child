// lib/enhanced_character_avatar.dart
// Comprehensive avatar widget with proper facial features and emotion support

import 'package:flutter/material.dart';
import 'models.dart';
import 'emotion_models.dart';
import 'dart:math' as math;

class EnhancedCharacterAvatar extends StatelessWidget {
  final Character character;
  final EmotionState? emotionState;
  final double size;

  const EnhancedCharacterAvatar({
    super.key,
    required this.character,
    this.emotionState,
    this.size = 120,
  });

  Color _getSkinToneColor(String? skinTone) {
    final tone = skinTone?.toLowerCase() ?? 'medium';

    if (tone.contains('very fair') || tone.contains('very light')) {
      return const Color(0xFFFDE7D6);
    }
    if (tone.contains('fair')) return const Color(0xFFF7D5B7);
    if (tone.contains('light-medium')) return const Color(0xFFE8B896);
    if (tone.contains('light')) return const Color(0xFFF0D5B7);
    if (tone.contains('medium-dark') || tone.contains('tan')) {
      return const Color(0xFFB57856);
    }
    if (tone.contains('dark brown')) return const Color(0xFF8D5524);
    if (tone.contains('very dark') || tone.contains('deep')) {
      return const Color(0xFF5C3317);
    }
    if (tone.contains('brown')) return const Color(0xFFA67C52);
    if (tone.contains('medium')) return const Color(0xFFD19A6D);

    return const Color(0xFFD19A6D); // Default medium
  }

  Color _getHairColor(String? hair) {
    final hairStr = hair?.toLowerCase() ?? 'brown';

    if (hairStr.contains('black')) return Colors.black87;
    if (hairStr.contains('blonde') || hairStr.contains('blond')) {
      return const Color(0xFFFAD7A0);
    }
    if (hairStr.contains('red')) return const Color(0xFFC04000);
    if (hairStr.contains('auburn')) return const Color(0xFF91473E);
    if (hairStr.contains('brown')) return const Color(0xFF4A2511);
    if (hairStr.contains('gray') || hairStr.contains('grey')) {
      return Colors.grey.shade600;
    }
    if (hairStr.contains('white')) return Colors.grey.shade200;

    return const Color(0xFF4A2511); // Default brown
  }

  Color _getEyeColor(String? eyes) {
    final eyeStr = eyes?.toLowerCase() ?? 'brown';

    if (eyeStr.contains('blue')) return Colors.blue.shade700;
    if (eyeStr.contains('green')) return Colors.green.shade700;
    if (eyeStr.contains('hazel')) return const Color(0xFF8E7618);
    if (eyeStr.contains('gray') || eyeStr.contains('grey')) {
      return Colors.grey.shade600;
    }
    if (eyeStr.contains('amber')) return const Color(0xFFFFBF00);
    if (eyeStr.contains('brown')) return const Color(0xFF5C4033);

    return const Color(0xFF5C4033); // Default brown
  }

  @override
  Widget build(BuildContext context) {
    // Extract appearance data with fallbacks
    final hairColor = _getHairColor(character.hair);
    final eyeColor = _getEyeColor(character.eyes);
    final skinColor = _getSkinToneColor(character.skinTone);

    return Container(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AvatarPainter(
          skinColor: skinColor,
          hairColor: hairColor,
          eyeColor: eyeColor,
          emotionState: emotionState,
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final Color skinColor;
  final Color hairColor;
  final Color eyeColor;
  final EmotionState? emotionState;

  _AvatarPainter({
    required this.skinColor,
    required this.hairColor,
    required this.eyeColor,
    this.emotionState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final faceRadius = size.width * 0.4;

    // Draw face
    _drawFace(canvas, center, faceRadius);

    // Draw hair
    _drawHair(canvas, center, faceRadius, size);

    // Draw eyes
    _drawEyes(canvas, center, faceRadius);

    // Draw eyebrows (based on emotion)
    _drawEyebrows(canvas, center, faceRadius);

    // Draw nose
    _drawNose(canvas, center, faceRadius);

    // Draw mouth (based on emotion)
    _drawMouth(canvas, center, faceRadius);
  }

  void _drawFace(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Shadow
    canvas.drawCircle(center + const Offset(0, 2), radius, shadowPaint);

    // Face
    canvas.drawCircle(center, radius, paint);
  }

  void _drawHair(Canvas canvas, Offset center, double radius, Size size) {
    final paint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.fill;

    // Draw hair as a larger circle behind the face, positioned at top
    final hairPath = Path();
    hairPath.addOval(Rect.fromCenter(
      center: Offset(center.dx, center.dy - radius * 0.2),
      width: radius * 2.2,
      height: radius * 2.2,
    ));

    // Clip to show only the top portion (hair)
    final clipPath = Path();
    clipPath.addRect(Rect.fromLTWH(0, 0, size.width, center.dy + radius * 0.1));

    canvas.save();
    canvas.clipPath(clipPath);
    canvas.drawPath(hairPath, paint);
    canvas.restore();

    // Add hair texture/shine
    final shinePaint = Paint()
      ..color = hairColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipPath(clipPath);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.3, center.dy - radius * 0.5),
      radius * 0.3,
      shinePaint,
    );
    canvas.restore();
  }

  void _drawEyes(Canvas canvas, Offset center, double radius) {
    final eyeWhitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final irisPaint = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.fill;

    final pupilPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Eye positions
    final leftEyeCenter = Offset(center.dx - radius * 0.35, center.dy - radius * 0.1);
    final rightEyeCenter = Offset(center.dx + radius * 0.35, center.dy - radius * 0.1);

    final eyeWidth = radius * 0.25;
    final eyeHeight = radius * 0.20;

    // Draw left eye
    _drawEye(canvas, leftEyeCenter, eyeWidth, eyeHeight, eyeWhitePaint, irisPaint, pupilPaint);

    // Draw right eye
    _drawEye(canvas, rightEyeCenter, eyeWidth, eyeHeight, eyeWhitePaint, irisPaint, pupilPaint);
  }

  void _drawEye(Canvas canvas, Offset center, double width, double height,
      Paint whitePaint, Paint irisPaint, Paint pupilPaint) {
    // Eye white (ellipse)
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: height),
      whitePaint,
    );

    // Iris
    final irisRadius = height * 0.55;
    canvas.drawCircle(center, irisRadius, irisPaint);

    // Pupil
    final pupilRadius = height * 0.3;
    canvas.drawCircle(center, pupilRadius, pupilPaint);

    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      center + Offset(-pupilRadius * 0.3, -pupilRadius * 0.3),
      pupilRadius * 0.4,
      highlightPaint,
    );
  }

  void _drawEyebrows(Canvas canvas, Offset center, double radius) {
    final eyebrowPaint = Paint()
      ..color = hairColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.06
      ..strokeCap = StrokeCap.round;

    // Get eyebrow style based on emotion
    final emotion = emotionState?.core;

    // Left eyebrow
    final leftBrowStart = Offset(center.dx - radius * 0.5, center.dy - radius * 0.35);
    final leftBrowEnd = Offset(center.dx - radius * 0.15, center.dy - radius * 0.40);

    // Right eyebrow
    final rightBrowStart = Offset(center.dx + radius * 0.15, center.dy - radius * 0.40);
    final rightBrowEnd = Offset(center.dx + radius * 0.5, center.dy - radius * 0.35);

    if (emotion == CoreEmotion.anger) {
      // Angled down in center (angry)
      canvas.drawLine(leftBrowStart,
          Offset(center.dx - radius * 0.15, center.dy - radius * 0.35), eyebrowPaint);
      canvas.drawLine(Offset(center.dx + radius * 0.15, center.dy - radius * 0.35),
          rightBrowEnd, eyebrowPaint);
    } else if (emotion == CoreEmotion.sadness || emotion == CoreEmotion.fear) {
      // Angled up in center (sad/worried)
      canvas.drawLine(leftBrowStart,
          Offset(center.dx - radius * 0.15, center.dy - radius * 0.43), eyebrowPaint);
      canvas.drawLine(Offset(center.dx + radius * 0.15, center.dy - radius * 0.43),
          rightBrowEnd, eyebrowPaint);
    } else if (emotion == CoreEmotion.surprise) {
      // Raised eyebrows
      canvas.drawLine(
          Offset(leftBrowStart.dx, leftBrowStart.dy - radius * 0.05),
          Offset(leftBrowEnd.dx, leftBrowEnd.dy - radius * 0.05),
          eyebrowPaint);
      canvas.drawLine(
          Offset(rightBrowStart.dx, rightBrowStart.dy - radius * 0.05),
          Offset(rightBrowEnd.dx, rightBrowEnd.dy - radius * 0.05),
          eyebrowPaint);
    } else {
      // Normal/happy eyebrows
      canvas.drawLine(leftBrowStart, leftBrowEnd, eyebrowPaint);
      canvas.drawLine(rightBrowStart, rightBrowEnd, eyebrowPaint);
    }
  }

  void _drawNose(Canvas canvas, Offset center, double radius) {
    final nosePaint = Paint()
      ..color = skinColor.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    // Simple nose as small oval
    final noseCenter = Offset(center.dx, center.dy + radius * 0.1);
    canvas.drawOval(
      Rect.fromCenter(
        center: noseCenter,
        width: radius * 0.15,
        height: radius * 0.20,
      ),
      nosePaint,
    );

    // Nostrils (small dots)
    final nostrilPaint = Paint()
      ..color = skinColor.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(noseCenter.dx - radius * 0.04, noseCenter.dy + radius * 0.08),
      radius * 0.02,
      nostrilPaint,
    );
    canvas.drawCircle(
      Offset(noseCenter.dx + radius * 0.04, noseCenter.dy + radius * 0.08),
      radius * 0.02,
      nostrilPaint,
    );
  }

  void _drawMouth(Canvas canvas, Offset center, double radius) {
    final mouthPaint = Paint()
      ..color = const Color(0xFF8B4513).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.04
      ..strokeCap = StrokeCap.round;

    final emotion = emotionState?.core;
    final mouthCenter = Offset(center.dx, center.dy + radius * 0.45);

    if (emotion == CoreEmotion.joy || emotion == CoreEmotion.love) {
      // Big smile
      final path = Path();
      path.moveTo(mouthCenter.dx - radius * 0.3, mouthCenter.dy);
      path.quadraticBezierTo(
        mouthCenter.dx, mouthCenter.dy + radius * 0.2,
        mouthCenter.dx + radius * 0.3, mouthCenter.dy,
      );
      canvas.drawPath(path, mouthPaint);
    } else if (emotion == CoreEmotion.surprise) {
      // Open mouth (circle)
      final openMouthPaint = Paint()
        ..color = const Color(0xFF8B4513).withOpacity(0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(mouthCenter, radius * 0.15, openMouthPaint);
    } else if (emotion == CoreEmotion.sadness) {
      // Frown
      final path = Path();
      path.moveTo(mouthCenter.dx - radius * 0.25, mouthCenter.dy);
      path.quadraticBezierTo(
        mouthCenter.dx, mouthCenter.dy - radius * 0.15,
        mouthCenter.dx + radius * 0.25, mouthCenter.dy,
      );
      canvas.drawPath(path, mouthPaint);
    } else if (emotion == CoreEmotion.anger) {
      // Straight line (annoyed)
      canvas.drawLine(
        Offset(mouthCenter.dx - radius * 0.25, mouthCenter.dy),
        Offset(mouthCenter.dx + radius * 0.25, mouthCenter.dy),
        mouthPaint,
      );
    } else if (emotion == CoreEmotion.fear) {
      // Small worried mouth
      final path = Path();
      path.moveTo(mouthCenter.dx - radius * 0.15, mouthCenter.dy);
      path.lineTo(mouthCenter.dx + radius * 0.15, mouthCenter.dy);
      canvas.drawPath(path, mouthPaint);
    } else {
      // Neutral/slight smile
      final path = Path();
      path.moveTo(mouthCenter.dx - radius * 0.25, mouthCenter.dy);
      path.quadraticBezierTo(
        mouthCenter.dx, mouthCenter.dy + radius * 0.08,
        mouthCenter.dx + radius * 0.25, mouthCenter.dy,
      );
      canvas.drawPath(path, mouthPaint);
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) {
    return oldDelegate.skinColor != skinColor ||
        oldDelegate.hairColor != hairColor ||
        oldDelegate.eyeColor != eyeColor ||
        oldDelegate.emotionState != emotionState;
  }
}
