import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models.dart';
import '../../theme/age_band_theme.dart';
import '../../theme/app_theme.dart';

class HeroAvatarChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const HeroAvatarChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C1B47),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700).withAlpha(120), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD700), size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
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
                  : const AssetImage('assets/images/hero_placeholder.jpg')
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
