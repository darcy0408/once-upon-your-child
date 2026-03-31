import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAdventurerUnlockSeenKey = 'adventurer_band_unlock_seen';

/// One-time celebration dialog shown when a user first enters the Adventurer
/// band (ages 9–11), revealing the two exclusive scenarios that are now
/// accessible: Midnight Mystery and Survival Island.
///
/// Call [show] after confirming the SharedPreferences key is absent.
/// The dialog marks the key as seen before returning.
class AdventurerUnlockCelebration extends StatelessWidget {
  const AdventurerUnlockCelebration({super.key});

  static const _scenarios = [
    _UnlockScenario(
      title: 'Midnight Mystery',
      description:
          'Something strange has happened in the night — only you can figure out what.',
      imagePath: 'assets/images/scenarios/mystery.png',
      icon: Icons.nightlight_round,
    ),
    _UnlockScenario(
      title: 'Survival Island',
      description:
          'Stranded, resourceful, and alone. Build, explore, and find your way home.',
      imagePath: 'assets/images/scenarios/survival.png',
      icon: Icons.forest_rounded,
    ),
  ];

  static Future<void> show(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kAdventurerUnlockSeenKey) == true) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => const AdventurerUnlockCelebration(),
    );
    await prefs.setBool(_kAdventurerUnlockSeenKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D2B), Color(0xFF1A1A4E), Color(0xFF0D0D2B)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF80CBC4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF80CBC4).withValues(alpha: 0.2),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A4E),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF80CBC4).withValues(alpha: 0.6),
                      width: 1),
                ),
                child: const Icon(Icons.shield_rounded,
                    size: 32, color: Color(0xFF80CBC4)),
              ),
              const SizedBox(height: 16),

              // Headline
              Text(
                "You've Unlocked New Adventures!",
                textAlign: TextAlign.center,
                style: GoogleFonts.bitter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Two exclusive missions are now open to you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.bitter(
                  fontSize: 13,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),

              // Scenario cards
              ..._scenarios.map((s) => _ScenarioUnlockCard(scenario: s)),

              const SizedBox(height: 20),

              // CTA button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF80CBC4),
                    foregroundColor: const Color(0xFF0D0D2B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Start Exploring!',
                    style: GoogleFonts.bitter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenarioUnlockCard extends StatelessWidget {
  final _UnlockScenario scenario;
  const _ScenarioUnlockCard({required this.scenario});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A4E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF80CBC4).withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D2B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF80CBC4).withValues(alpha: 0.4)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                scenario.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  scenario.icon,
                  color: const Color(0xFF80CBC4),
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      scenario.title,
                      style: GoogleFonts.bitter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D2B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: const Color(0xFF80CBC4), width: 0.8),
                      ),
                      child: Text(
                        'NEW',
                        style: GoogleFonts.bitter(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF80CBC4),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  scenario.description,
                  style: GoogleFonts.bitter(
                    fontSize: 12,
                    color: Colors.white70,
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

class _UnlockScenario {
  final String title;
  final String description;
  final String imagePath;
  final IconData icon;
  const _UnlockScenario({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.icon,
  });
}
