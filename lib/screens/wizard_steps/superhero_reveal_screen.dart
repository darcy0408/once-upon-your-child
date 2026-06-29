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
import 'package:http/http.dart' as http;

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
  // Noir reskin (MT-297): the mature bands (Creator purple, Adolescent teal)
  // use the band accent + Source Sans 3; younger bands keep gold + Fredoka.
  bool get _noir =>
      widget.band == AgeBand.adolescent || widget.band == AgeBand.creator;

  Color get _gold =>
      _noir ? themeForBand(widget.band).accent : const Color(0xFFFFD700);

  late final AnimationController _pulse;
  bool _loading = true;
  Uint8List? _portrait;

  // Escape hatch: the portrait transform can take up to 2 minutes (or stall on
  // a provider quota/outage). This screen is explicitly "best-effort, never
  // block the kid", but the loading state had no way out — a stalled transform
  // froze the child on "Suiting up…" and they never reached story generation.
  // Surface a subtle "Skip" after a short grace so a fast success still gets a
  // clean reveal, but a slow/stuck one is always escapable.
  bool _showSkip = false;
  Timer? _skipTimer;

  // MT-285: the screen owns the HTTP client for the portrait transform so that
  // tapping Skip (or leaving the screen) can close it and abort the in-flight
  // request — otherwise a slow transform keeps churning for up to ~2 minutes
  // after the child has already moved on. [_cancelled] also guards the late
  // success callback so it never writes state after the user has skipped.
  http.Client? _httpClient;
  bool _cancelled = false;

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
    _skipTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _loading) setState(() => _showSkip = true);
    });
    _generate();
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _cancelled = true;
    _httpClient?.close();
    _pulse.dispose();
    super.dispose();
  }

  // Skip / continue out of the reveal. Cancels the in-flight portrait transform
  // (MT-285) before popping so it stops consuming a request the child no longer
  // wants.
  void _skip() {
    _cancelled = true;
    _httpClient?.close();
    Navigator.of(context).pop();
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

    // Own the client so Skip/dispose can close it and cancel the request.
    final client = _httpClient = http.Client();
    final result = await SuperheroPortraitService.transform(
      avatarBytes: avatarBytes,
      costumeColor: wd.heroCostumeColor,
      capeStyle: wd.heroCapeStyle,
      emblem: wd.heroEmblem,
      power: wd.heroPower,
      client: client,
    );
    client.close();

    // Bail on a late return after the child skipped (or the screen went away).
    if (_cancelled || !mounted) return;
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
          style: _revealText(
            color: _gold,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Turning ${widget.heroName} into a superhero!',
          textAlign: TextAlign.center,
          style: _revealText(
            color: Colors.white.withAlpha(210),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(_gold),
          ),
        ),
        // Always-available escape hatch (revealed after a short grace) so a
        // slow or stalled portrait transform can never trap the child here.
        // Popping continues the wizard to story creation; the portrait is
        // optional and simply stays unset.
        if (_showSkip) ...[
          const SizedBox(height: 28),
          TextButton(
            onPressed: _skip,
            child: Text(
              'Skip — start my story →',
              style: _revealText(
                color: Colors.white.withAlpha(210),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: Colors.white54,
              ),
            ),
          ),
        ],
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
                      style: _revealText(
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
                      style: _revealText(
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
          style: _revealText(
            color: _gold,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your superhero is suited up and ready for the mission.',
          textAlign: TextAlign.center,
          style: _revealText(
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
          style: _revealText(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Band-aware text style for the reveal. Mature bands (Creator/Adolescent)
  /// get the crisper Source Sans 3; younger bands keep the rounded Fredoka.
  TextStyle _revealText({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    final base = _noir
        ? GoogleFonts.sourceSans3(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            letterSpacing: letterSpacing,
          )
        : GoogleFonts.fredoka(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            letterSpacing: letterSpacing,
          );
    return shadows == null ? base : base.copyWith(shadows: shadows);
  }
}
