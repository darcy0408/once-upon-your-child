// Superhero portrait reveal (Explorer 6-8 / Adventurer 9-12).
//
// Takes the child's existing avatar, calls /avatar/transform-superhero, and
// reveals the result framed as a comic-book cover. Best-effort: if generation
// fails (offline, paywall, model error) it shows a friendly "ready!" state and
// the wizard continues unaffected. On success the portrait data URI is stored
// on [WizardData.heroPortraitUrl] so downstream surfaces can reuse it.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models.dart';
import '../../services/superhero_portrait_service.dart';
import '../../services/superhero_portrait_store.dart';
import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';
import 'superhero_entry_screen.dart';

class SuperheroRevealScreen extends StatefulWidget {
  final WizardData wizardData;
  final AgeBand band;
  final String heroName;

  const SuperheroRevealScreen({
    super.key,
    required this.wizardData,
    required this.band,
    required this.heroName,
  });

  @override
  State<SuperheroRevealScreen> createState() => _SuperheroRevealScreenState();
}

class _SuperheroRevealScreenState extends State<SuperheroRevealScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFFFD700);

  late final AnimationController _pulse;
  bool _loading = true;
  Uint8List? _portrait;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // reduce-motion: don't run the looping "suiting up" pulse.
    if (!MotionPrefs.reduceMotion(context)) {
      _pulse.repeat(reverse: true);
    }
    _generate();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final wd = widget.wizardData;
    final uri = wd.generatedAvatar?.imageBase64;
    // No usable source avatar → fail soft (caller already gates on this, but be
    // defensive).
    if (uri == null || !uri.contains(',')) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    Uint8List? avatarBytes;
    try {
      avatarBytes = base64Decode(uri.split(',').last);
    } catch (_) {
      avatarBytes = null;
    }
    if (avatarBytes == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final result = await SuperheroPortraitService.transform(
      avatarBytes: avatarBytes,
      costumeColor: wd.heroCostumeColor,
      capeStyle: wd.heroCapeStyle,
      emblem: wd.heroEmblem,
      power: wd.heroPower,
    );

    if (!mounted) return;
    if (result == null || !result.contains(',')) {
      setState(() => _loading = false);
      return;
    }

    wd.heroPortraitUrl = result;
    // Persist for the welcome-back screen (keyed identically to HeroProfileLocal).
    unawaited(
      SuperheroPortraitStore.save(
        SuperheroEntryScreen.resolveCharacterId(wd),
        result,
      ),
    );
    Uint8List? bytes;
    try {
      bytes = base64Decode(result.split(',').last);
    } catch (_) {
      bytes = null;
    }
    _pulse.stop();
    setState(() {
      _portrait = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gradient = themeForBand(widget.band).backgroundGradient;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: _loading
                  ? _buildLoading()
                  : (_portrait != null ? _buildCover() : _buildFallback()),
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading: "Suiting up…" ──────────────────────────────────────────────────
  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.12).animate(
            CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
          ),
          child: const Text('🦸', style: TextStyle(fontSize: 96)),
        ),
        const SizedBox(height: 28),
        Text(
          'Suiting up…',
          style: GoogleFonts.fredoka(
            color: _gold,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Turning ${widget.heroName} into a superhero!',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: Colors.white.withAlpha(210),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(_gold),
          ),
        ),
      ],
    );
  }

  // ── Success: comic-book cover ───────────────────────────────────────────────
  Widget _buildCover() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Comic cover frame.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold, width: 4),
              boxShadow: [
                BoxShadow(
                  color: _gold.withAlpha(120),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Image.memory(_portrait!, fit: BoxFit.cover),
                // Top "ISSUE #1" tab.
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _gold.withAlpha(180)),
                    ),
                    child: Text(
                      'ISSUE #1',
                      style: GoogleFonts.fredoka(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                // Bottom hero-name banner.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(190),
                        ],
                      ),
                    ),
                    child: Text(
                      widget.heroName.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(color: _gold.withAlpha(160), blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _continueButton('Start the adventure!'),
        ],
      ),
    );
  }

  // ── Fallback: generation unavailable, never block the kid ───────────────────
  Widget _buildFallback() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🦸', style: TextStyle(fontSize: 84)),
        const SizedBox(height: 20),
        Text(
          '${widget.heroName} is ready!',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: _gold,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your superhero is suited up and ready for the mission.',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: Colors.white.withAlpha(210),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 28),
        _continueButton('Start the adventure!'),
      ],
    );
  }

  Widget _continueButton(String label) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(
          label,
          style: GoogleFonts.fredoka(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
