import 'package:flutter/material.dart';
import '../services/child_profile_service.dart';

class ChildProfileSwitcher extends StatelessWidget {
  final List<ChildProfile> profiles;
  final String? activeProfileId;
  final ValueChanged<ChildProfile> onProfileSelected;
  final VoidCallback onAddProfile;

  const ChildProfileSwitcher({
    super.key,
    required this.profiles,
    required this.activeProfileId,
    required this.onProfileSelected,
    required this.onAddProfile,
  });

  Color _hexColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  Future<bool?> _confirmDelete(BuildContext context, ChildProfile profile) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove profile?'),
        content: Text('Remove "${profile.name}" from the profile list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          ...profiles.map((profile) {
            final isActive = profile.id == activeProfileId;
            final color = _hexColor(profile.colorHex);
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => onProfileSelected(profile),
                onLongPress: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final confirmed = await _confirmDelete(context, profile);
                  if (confirmed == true) {
                    final fullyDeleted =
                        await ChildProfileService().deleteProfile(profile.id);
                    if (!fullyDeleted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Profile removed from this device, but the stored "
                            "data couldn't be deleted from our servers. Please "
                            "try again when you're online.",
                          ),
                        ),
                      );
                    }
                    // Notify parent by selecting a different profile if needed
                    if (profile.id == activeProfileId &&
                        profiles.length > 1) {
                      final next = profiles.firstWhere(
                          (p) => p.id != profile.id,
                          orElse: () => profiles.first);
                      onProfileSelected(next);
                    }
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.9),
                        border: isActive
                            ? Border.all(
                                color: const Color(0xFFFFD700), width: 3)
                            : Border.all(
                                color: Colors.white24, width: 1.5),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          profile.avatarEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive
                              ? const Color(0xFFFFD700)
                              : Colors.white70,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // "+" add button
          GestureDetector(
            onTap: onAddProfile,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DashedCircle(
                  size: 52,
                  child: const Icon(Icons.add, color: Colors.white54, size: 22),
                ),
                const SizedBox(height: 4),
                const SizedBox(
                  width: 56,
                  child: Text(
                    'Add',
                    style: TextStyle(fontSize: 10, color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A circle with a dashed border.
class DashedCircle extends StatelessWidget {
  final double size;
  final Widget child;

  const DashedCircle({super.key, required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCirclePainter(),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashCount = 12;
    const dashAngle = 3.14159 * 2 / dashCount;
    final radius = size.width / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle * 0.5,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
