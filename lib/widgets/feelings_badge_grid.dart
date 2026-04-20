// lib/widgets/feelings_badge_grid.dart
//
// Emotion card grid for the Adventurer band (ages 9-11).
// Shows a 4×2 grid of styled emotion cards. Single-tap selects and confirms.
// Uses large emoji + label with color-coded cards for a polished look.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/age_band_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

class _CardEmotion {
  final String id;
  final String label;
  final String emoji;
  final Color color;
  final String subtitle;

  const _CardEmotion({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    required this.subtitle,
  });
}

List<_CardEmotion> _cardsForBand(AgeBand band) => [
  const _CardEmotion(
    id: 'happy',
    label: 'Happy',
    emoji: '\u{1F60A}',
    color: Color(0xFFFFC107),
    subtitle: 'Things are good',
  ),
  const _CardEmotion(
    id: 'sad',
    label: 'Sad',
    emoji: '\u{1F622}',
    color: Color(0xFF42A5F5),
    subtitle: 'Feeling down',
  ),
  const _CardEmotion(
    id: 'worried',
    label: 'Worried',
    emoji: '\u{1F61F}',
    color: Color(0xFFFF7043),
    subtitle: "Can't stop thinking",
  ),
  const _CardEmotion(
    id: 'frustrated',
    label: 'Frustrated',
    emoji: '\u{1F624}',
    color: Color(0xFFEF5350),
    subtitle: "It's not working",
  ),
  const _CardEmotion(
    id: 'angry',
    label: 'Angry',
    emoji: '\u{1F621}',
    color: Color(0xFFD32F2F),
    subtitle: 'Ready to explode',
  ),
  const _CardEmotion(
    id: 'embarrassed',
    label: 'Embarrassed',
    emoji: '\u{1F633}',
    color: Color(0xFFEC407A),
    subtitle: 'Wish I could disappear',
  ),
  const _CardEmotion(
    id: 'excited',
    label: 'Excited',
    emoji: '\u{1F929}',
    color: Color(0xFFAB47BC),
    subtitle: "Can't wait",
  ),
  const _CardEmotion(
    id: 'calm',
    label: 'Calm',
    emoji: '\u{1F60C}',
    color: Color(0xFF26A69A),
    subtitle: 'All good right now',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

/// Emotion card grid for the Adventurer band.
/// Calls [onSelected] with a list containing the chosen emotion id.
class FeelingsBadgeGrid extends StatefulWidget {
  final ValueChanged<List<String>> onSelected;
  final AgeBand band;

  const FeelingsBadgeGrid({
    super.key,
    required this.onSelected,
    this.band = AgeBand.adventurer,
  });

  @override
  State<FeelingsBadgeGrid> createState() => _FeelingsBadgeGridState();
}

class _FeelingsBadgeGridState extends State<FeelingsBadgeGrid> {
  String? _hoveredId;

  @override
  Widget build(BuildContext context) {
    final cards = _cardsForBand(widget.band);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final card = cards[i];
        final isHovered = _hoveredId == card.id;
        return _EmotionCard(
          card: card,
          isHighlighted: isHovered,
          onTap: () => widget.onSelected([card.id]),
          onHoverChanged: (v) =>
              setState(() => _hoveredId = v ? card.id : null),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Emotion card tile
// ─────────────────────────────────────────────────────────────────────────────

class _EmotionCard extends StatelessWidget {
  final _CardEmotion card;
  final bool isHighlighted;
  final VoidCallback onTap;
  final ValueChanged<bool> onHoverChanged;

  const _EmotionCard({
    required this.card,
    required this.isHighlighted,
    required this.onTap,
    required this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${card.label} — ${card.subtitle}',
      onTap: onTap,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => onHoverChanged(true),
        onExit: (_) => onHoverChanged(false),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  card.color.withAlpha(isHighlighted ? 80 : 35),
                  card.color.withAlpha(isHighlighted ? 50 : 18),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHighlighted
                    ? card.color
                    : card.color.withAlpha(80),
                width: isHighlighted ? 2.0 : 1.0,
              ),
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(
                        color: card.color.withAlpha(60),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    card.emoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.label,
                          style: GoogleFonts.fredoka(
                            color: isHighlighted
                                ? Colors.white
                                : Colors.white.withAlpha(230),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.subtitle,
                          style: GoogleFonts.fredoka(
                            color: Colors.white.withAlpha(140),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
