import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models.dart';
import '../../theme/age_band_theme.dart';

class HeroAvatarChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// When true, render the card as a hero/featured choice: gradient
  /// background, gold glow, "NEW!" badge, and a 📸 → ✨ → 🎨 preview row
  /// so kids and parents can see at a glance that a real photo turns into
  /// a cartoon hero.
  final bool featured;

  /// Optional badge text shown on featured cards (top-right). Defaults to
  /// "✨ NEW! ✨" when [featured] is true and no override is provided.
  final String? badgeText;

  const HeroAvatarChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.featured = false,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    if (featured) return _buildFeatured();
    return _buildStandard();
  }

  Widget _buildStandard() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C1B47),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: const Color(0xFFFFD700).withAlpha(120), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withAlpha(40),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFFFFD700), size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFFFD700), size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatured() {
    final label = badgeText ?? '✨ NEW! ✨';
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6B2FB3),
                  Color(0xFFB23A8E),
                  Color(0xFFFF6B35),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: const Color(0xFFFFD700), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(80),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 📸 → ✨ → 🎨  preview row makes the transformation obvious
                // even to a 3-year-old who can't read yet.
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('📸', style: TextStyle(fontSize: 36)),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text('✨', style: TextStyle(fontSize: 36)),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text('🦸', style: TextStyle(fontSize: 36)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          color: const Color(0xFF6B2FB3), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to start',
                        style: GoogleFonts.fredoka(
                          color: const Color(0xFF6B2FB3),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -10,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 4),
                ],
              ),
              child: Text(
                label,
                style: GoogleFonts.fredoka(
                  color: const Color(0xFF2C1B47),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroCharacterChoiceCard extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;
  final ImageProvider<Object> Function(String) getAvatarProvider;

  const HeroCharacterChoiceCard({
    super.key,
    required this.character,
    required this.onTap,
    required this.getAvatarProvider,
  });

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final avatarData = character.generatedAvatar?.imageBase64;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD4A0FF).withAlpha(100)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: const Color(0xFF3A2363),
              backgroundImage: avatarData != null
                  ? getAvatarProvider(avatarData)
                  : const AssetImage('assets/images/hero_placeholder.webp')
                      as ImageProvider,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Is this ${character.name}?",
                    style: GoogleFonts.fredoka(
                      color: const Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    character.name,
                    style: band.band == AgeBand.creator
                        ? GoogleFonts.sourceSans3(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)
                        : band.band == AgeBand.adventurer
                            ? GoogleFonts.bitter(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)
                            : GoogleFonts.cinzelDecorative(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                  ),
                  Text("${character.age} years old • ${character.role}",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded,
                color: Color(0xFFFFD700), size: 40),
          ],
        ),
      ),
    );
  }
}

class HeroCreatorStepData {
  static const superpowers = [
    ('⚡ Brave Heart', 'Brave Heart'),
    ('💛 Kindness Magic', 'Kindness Magic'),
    ('🧠 Problem-Solver Brain', 'Problem-Solver Brain'),
    ('🤝 Helping Hands', 'Helping Hands'),
    ('🌟 Creative Spark', 'Creative Spark'),
    ('👂 Super Listener', 'Super Listener'),
  ];
  static const quests = [
    ('🤝 Making new friends', 'Making new friends'),
    ('🌊 Handling life\'s curveballs', 'Taming big feelings'),
    ('🦁 Being brave when scared', 'Being brave when scared'),
    ('🎁 Sharing and taking turns', 'Sharing and taking turns'),
    ('🌱 Trying something new', 'Trying something new'),
    ("🦸 Standing up for what's right", "Standing up for what's right"),
  ];
}
