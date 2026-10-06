import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/age_band_theme.dart';
import 'hero_creator/companion_widgets.dart';
import 'safe_asset_image.dart';

/// The built-in companion list for [band], in unlock order.
List<CompanionData> companionsForBand(AgeBand band) {
  switch (band) {
    case AgeBand.sprout:
      return sproutCompanions;
    case AgeBand.explorer:
      return explorerCompanions;
    case AgeBand.adventurer:
      return adventurerCompanions;
    case AgeBand.creator:
      return creatorCompanions;
    case AgeBand.adolescent:
      return adolescentCompanions;
    case AgeBand.adult:
      return adultCompanions;
  }
}

/// Looks up a companion by [id] within [band], or null.
CompanionData? companionForId(AgeBand band, String id) {
  for (final c in companionsForBand(band)) {
    if (c.id == id) return c;
  }
  return null;
}

/// Small, non-modal `Name has arrived!` card shown when a story unlocks the
/// next magic companion. Dismissible with the close button; never traps focus.
class CompanionArrivalCard extends StatelessWidget {
  const CompanionArrivalCard({
    super.key,
    required this.companion,
    required this.band,
    this.onDismiss,
  });

  final CompanionData companion;
  final AgeBandThemeData band;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final onCard = band.onCard;
    return Semantics(
      container: true,
      label: '${companion.name} has arrived! ${companion.tagline}',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        decoration: BoxDecoration(
          color: band.cardColor,
          borderRadius: BorderRadius.circular(band.cardRadiusBase),
          border: Border.all(color: band.accent, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: SafeAssetImage(
                  companion.imagePath,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  alignment: companion.imageAlignment,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${companion.name} has arrived!',
                    softWrap: true,
                    style: GoogleFonts.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: onCard,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    companion.tagline,
                    softWrap: true,
                    style: GoogleFonts.quicksand(fontSize: 14, color: onCard),
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                constraints: BoxConstraints(
                  minWidth: band.touchTargetMin,
                  minHeight: band.touchTargetMin,
                ),
                icon: Icon(Icons.close, color: onCard, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
