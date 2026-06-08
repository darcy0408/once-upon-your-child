// Superhero Mode (Sprout 3-5, Explorer 6-8, Adventurer 9-12) — "welcome back" screen.
//
// Shown when the child already has a saved [HeroProfileLocal] for this
// character. Two paths:
//   1. "Yes! Start adventure" — re-apply the saved costume/power to
//      WizardData, set scenario, pop with `true`.
//   2. "Edit my hero" — push the costume picker, which then chains to the
//      power picker and finally pops back here. We propagate that pop.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models.dart';
import '../../models/hero_saga.dart';
import '../../models/local/hero_profile_local.dart';
import '../../services/superhero_portrait_store.dart';
import '../../theme/age_band_theme.dart';
import 'superhero_costume_screen.dart';

class SuperheroWelcomeBackScreen extends StatelessWidget {
  static const _gold = Color(0xFFFFD700);

  final WizardData wizardData;
  final HeroProfileLocal profile;

  /// Visual band — drives the gradient + greeting copy. Defaults to sprout
  /// so existing callers without a band keep current behavior.
  final AgeBand band;

  /// MT-235 Phase 2 (the returnable saga): the returning Creator hero's
  /// persisted continuity. When present AND it has continuity (at least one
  /// completed Issue), a "Previously…" recap card is shown above the greeting.
  /// Null for younger bands and a brand-new Creator hero (Issue #1).
  final HeroSaga? saga;

  const SuperheroWelcomeBackScreen({
    super.key,
    required this.wizardData,
    required this.profile,
    this.band = AgeBand.sprout,
    this.saga,
  });

  /// Humanizes the backend `nemesis_status` vocabulary into a teen-appropriate
  /// recap phrase. Falls back to the raw value (cleaned) for any unknown code.
  static String humanizeNemesisStatus(String? status) {
    switch (status) {
      case 'reconsidered':
        return 'had a change of heart';
      case 'stopped-and-accountable':
        return 'was stopped and held accountable';
      case 'still-at-large':
        return 'is still out there';
      default:
        return (status ?? '').replaceAll('-', ' ').trim();
    }
  }

  static const _emblemEmoji = <String, String>{
    'star': '⭐',
    'lightning': '⚡',
    'heart': '❤️',
    'moon': '🌙',
    'paw': '🐾',
    'rainbow': '🌈',
    // Explorer-only emblems.
    'bolt': '🔱',
    'comet': '☄️',
  };

  static const _colorHex = <String, Color>{
    'red': Color(0xFFE53935),
    'blue': Color(0xFF1E88E5),
    'green': Color(0xFF43A047),
    'yellow': Color(0xFFFDD835),
    'purple': Color(0xFF8E24AA),
    'pink': Color(0xFFEC407A),
  };

  void _startAdventure(BuildContext context) {
    HapticFeedback.mediumImpact();
    wizardData.heroCostumeColor = profile.costumeColor;
    wizardData.heroCapeStyle = profile.capeStyle;
    wizardData.heroEmblem = profile.emblem;
    wizardData.heroPower = profile.power;
    wizardData.heroSuperpower = profile.heroName;
    wizardData.selectedScenario = 'superhero';
    wizardData.customElements = 'being a superhero';
    Navigator.of(context).pop(true);
  }

  Future<void> _editHero(BuildContext context) async {
    HapticFeedback.lightImpact();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SuperheroCostumeScreen(wizardData: wizardData, band: band),
      ),
    );
    if (saved == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  static Uint8List? _decodePortrait(String? dataUri) {
    if (dataUri == null || !dataUri.contains(',')) return null;
    try {
      return base64Decode(dataUri.split(',').last);
    } catch (_) {
      return null;
    }
  }

  /// The saved AI superhero portrait in a circular gold frame.
  Widget _portraitBadge(Uint8List bytes) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _gold, width: 5),
        boxShadow: [
          BoxShadow(
              color: _gold.withAlpha(140), blurRadius: 32, spreadRadius: 4),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.memory(bytes, fit: BoxFit.cover),
    );
  }

  /// Fallback badge: a colored circle with optional cape backing + emblem.
  Widget _emblemBadge(
      Color color, String emblem, bool hasCape, bool isRainbowCape) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasCape)
            Positioned(
              top: 20,
              child: Container(
                width: 180,
                height: 200,
                decoration: BoxDecoration(
                  gradient: isRainbowCape
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFE53935),
                            Color(0xFFFFB300),
                            Color(0xFF43A047),
                            Color(0xFF1E88E5),
                            Color(0xFF8E24AA),
                          ],
                        )
                      : null,
                  color: isRainbowCape ? null : color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: _gold, width: 5),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(180),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(emblem, style: const TextStyle(fontSize: 80)),
            ),
          ),
        ],
      ),
    );
  }

  /// "Previously on…" recap card for a returning Creator hero with continuity.
  /// Shows the Issue number, the nemesis + humanized status, and teases the
  /// next_hook. Returns null when there is no saga continuity to show.
  Widget? _buildPreviouslyCard() {
    final s = saga;
    if (s == null || !s.hasContinuity) return null;

    final lines = <Widget>[];
    final nemesis = s.nemesis?.trim();
    if (nemesis != null && nemesis.isNotEmpty) {
      final status = humanizeNemesisStatus(s.nemesisStatus);
      lines.add(Text(
        status.isEmpty ? nemesis : '$nemesis $status.',
        textAlign: TextAlign.center,
        style: GoogleFonts.fredoka(
          color: Colors.white.withAlpha(230),
          fontSize: 15,
        ),
      ));
    }
    final hook = s.nextHook?.trim();
    if (hook != null && hook.isNotEmpty) {
      lines.add(const SizedBox(height: 8));
      lines.add(Text(
        hook,
        textAlign: TextAlign.center,
        style: GoogleFonts.fredoka(
          color: _gold.withAlpha(235),
          fontSize: 16,
          fontStyle: FontStyle.italic,
          height: 1.3,
        ),
      ));
    }
    if (lines.isEmpty) return null;

    // The next Issue is the completed count + 1.
    final nextIssue = s.issueNumber + 1;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(64),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withAlpha(110), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PREVIOUSLY IN YOUR SAGA',
            style: GoogleFonts.fredoka(
              color: _gold.withAlpha(210),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          ...lines,
          const SizedBox(height: 12),
          Text(
            'Issue #$nextIssue begins…',
            style: GoogleFonts.fredoka(
              color: Colors.white.withAlpha(170),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorHex[profile.costumeColor] ?? const Color(0xFF8E24AA);
    final emblem = _emblemEmoji[profile.emblem] ?? '⭐';
    final hasCape = profile.capeStyle != null && profile.capeStyle != 'none';
    final isRainbowCape = profile.capeStyle == 'rainbow';
    final heroName = profile.heroName?.trim().isNotEmpty == true
        ? profile.heroName!.trim()
        : 'Super Hero';
    // Explorer + Adventurer + Creator share the older, mission-flavored copy.
    final isExplorer = band == AgeBand.explorer ||
        band == AgeBand.adventurer ||
        band == AgeBand.creator;
    final gradient = themeForBand(band).backgroundGradient;
    final greetingLine = isExplorer ? 'Welcome back,' : 'Welcome back,';
    final invitation = isExplorer
        ? 'Ready for your next mission?'
        : 'Ready for another adventure?';
    final startCta = isExplorer ? 'Start the mission!' : 'Yes! Start adventure';
    final editCta = isExplorer ? 'Redesign my hero' : 'Edit my hero';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.vertical -
                    kToolbarHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // MT-235 Phase 2: "Previously in your saga" recap for a
                    // returning Creator hero with continuity (Creator-only; null
                    // saga / no continuity renders nothing).
                    if (_buildPreviouslyCard() case final card?) card,
                    // Hero badge: the saved AI portrait if we have one, otherwise
                    // the colored emblem badge. FutureBuilder loads the portrait
                    // persisted by the reveal screen (keyed by characterId).
                    FutureBuilder<String?>(
                      future: SuperheroPortraitStore.load(profile.characterId),
                      builder: (context, snapshot) {
                        final uri = snapshot.data;
                        final bytes = _decodePortrait(uri);
                        if (bytes != null) {
                          return _portraitBadge(bytes);
                        }
                        return _emblemBadge(
                            color, emblem, hasCape, isRainbowCape);
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      greetingLine,
                      style: GoogleFonts.fredoka(
                        color: Colors.white.withAlpha(220),
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      '$heroName!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        color: _gold,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      invitation,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        color: Colors.white.withAlpha(220),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => _startAdventure(context),
                        child: Text(
                          startCta,
                          style: GoogleFonts.fredoka(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _gold,
                          side: const BorderSide(color: _gold, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => _editHero(context),
                        child: Text(
                          editCta,
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
