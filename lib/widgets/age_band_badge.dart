import 'package:flutter/material.dart';
import '../theme/age_band_theme.dart';

/// A small badge overlaid on a scenario card indicating it is restricted to a
/// minimum age band. Shown to users who ARE in the qualifying band as a reward
/// marker ("Adventurer Exclusive"). Not shown on locked teasers — those use a
/// separate lock overlay.
class AgeBandBadge extends StatelessWidget {
  final AgeBand minBand;

  const AgeBandBadge({super.key, required this.minBand});

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(minBand);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF80CBC4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_rounded, size: 12, color: Color(0xFF80CBC4)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF80CBC4),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  static String _labelFor(AgeBand band) {
    switch (band) {
      case AgeBand.adventurer:
        return 'ADVENTURER EXCLUSIVE';
      case AgeBand.creator:
        return 'CREATOR+';
      case AgeBand.adolescent:
        return 'TEEN+';
      case AgeBand.adult:
        return '18+';
      default:
        return '9+';
    }
  }
}
