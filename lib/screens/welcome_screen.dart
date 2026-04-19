import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../providers/age_band_provider.dart';
import '../services/app_tts_service.dart';
import '../services/parental_consent_service.dart';
import '../theme/age_band_asset_resolver.dart';
import '../theme/age_band_theme.dart';
import '../theme/app_theme.dart';
import '../widgets/breathing_avatar.dart';
import '../widgets/sprout_animations.dart';
import '../widgets/star_burst_celebration.dart';
import '../widgets/adventurer_welcome_sequence.dart';
import '../widgets/adventurer_unlock_celebration.dart';
import 'parental_consent_screen.dart';
import 'parent_controls_screen.dart';

const _kUserNameKey = 'user_name';
const _kTeaserSeenKey = 'welcome_teaser_seen';

/// Shown on first launch to collect the child's name and age.
/// Steps: 0 = age picker, 1 = title splash, 2 = name input.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Called after onboarding is fully complete (consent granted if needed).
  final VoidCallback onComplete;

  const WelcomeScreen({super.key, required this.onComplete});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  int? _selectedAge;
  bool _submitting = false;
  bool _celebratingName = false;
  final _burstController = StarBurstCelebrationController();

  final _speech = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  /// Current step: -1 = teaser, 0 = age picker, 1 = title splash, 2 = name input.
  int _step = 0;

  Timer? _titleTimer;

  /// Drives the pulsing "Tap me!" hint on the title splash.
  late final AnimationController _tapHintCtrl;
  late final Animation<double> _tapHintOpacity;

  static const _goldColor = Color(0xFFFFD700);

  /// True when the selected age maps to the Creator band (ages 12-14).
  bool get _isCreator =>
      _selectedAge != null && ageBandFromAge(_selectedAge!) == AgeBand.creator;

  /// True when the selected age maps to the Adventurer band (ages 9-11).
  bool get _isAdventurer =>
      _selectedAge != null &&
      ageBandFromAge(_selectedAge!) == AgeBand.adventurer;

  /// True when the selected age maps to the Adolescent band (ages 15-17).
  bool get _isAdolescent =>
      _selectedAge != null &&
      ageBandFromAge(_selectedAge!) == AgeBand.adolescent;

  // Ages 2-8: individual big buttons (sprout + explorer bands).
  // Ages 3-11: individual big buttons for young children (3×3 grid).
  static const _youngAgeEntries = <({String label, int value})>[
    (label: '3', value: 3),
    (label: '4', value: 4),
    (label: '5', value: 5),
    (label: '6', value: 6),
    (label: '7', value: 7),
    (label: '8', value: 8),
    (label: '9', value: 9),
    (label: '10', value: 10),
    (label: '11', value: 11),
  ];

  // Older age bands: grouped pill buttons (3 items in a single symmetrical row).
  static const _olderAgeEntries = <({String label, int value})>[
    (label: '12 – 14', value: 12),
    (label: '15 – 17', value: 16),
    (label: '18+', value: 21),
  ];

  @override
  void initState() {
    super.initState();
    // Pulsing "Tap me!" hint on the title screen.
    _tapHintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _tapHintOpacity = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _tapHintCtrl, curve: Curves.easeInOut),
    );

    _resumeFromSavedAge();
    _initVoice();
  }

  /// Determines the initial step on launch:
  /// 1. Age saved → jump to name entry (parental consent persists age; name
  ///    does not persist until consent is granted, so name is still required).
  /// 2. Teaser not yet seen → show the teaser before the age picker so the
  ///    user has context before being asked for data.
  /// 3. Otherwise → go straight to the age picker.
  Future<void> _resumeFromSavedAge() async {
    final savedAge = await const ParentalConsentService().getRecordedAge();
    final prefs = await SharedPreferences.getInstance();
    final teaserSeen = prefs.getBool(_kTeaserSeenKey) ?? false;
    if (!mounted) return;
    if (savedAge != null) {
      setState(() {
        _selectedAge = savedAge;
        _step = 2; // Skip teaser, age picker, and title splash.
      });
      if (ageBandFromAge(savedAge) == AgeBand.creator) {
        unawaited(_speak("Welcome back! What should we call you?", rateScale: 0.85));
      } else {
        unawaited(_speak("Welcome back! What's your name?", rateScale: 0.85));
      }
      return;
    }
    if (!teaserSeen) {
      setState(() => _step = -1);
      unawaited(_speak("Welcome to Story Weaver! Where you are the hero.",
          rateScale: 0.8));
      return;
    }
    unawaited(_speak(
        'Hi, welcome to Story Weaver! How old are you? Tap your age!',
        rateScale: 0.72));
  }

  Future<void> _dismissTeaser() async {
    AppTtsService.instance.markInteracted();
    AppTtsService.instance.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTeaserSeenKey, true);
    if (!mounted) return;
    setState(() => _step = 0);
    unawaited(_speak(
        'How old are you? Tap your age!',
        rateScale: 0.72));
  }

  Future<void> _initVoice() async {
    _speechEnabled = await _speech.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _speak(String text, {bool awaitCompletion = false, double rateScale = 0.85}) async {
    await AppTtsService.instance.speak(text, awaitCompletion: awaitCompletion, rateScale: rateScale);
  }

  /// Strips common introductory phrases so "my name is Jessica" → "Jessica".
  String _extractName(String raw) {
    final cleaned = raw.trim();
    // Patterns a child might say when asked their name
    final patterns = [
      RegExp(r"^(?:my name is|i'm|i am|they call me|call me)\s+", caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null) {
        final remainder = cleaned.substring(match.end).trim();
        if (remainder.isNotEmpty) return remainder;
      }
    }
    return cleaned;
  }

  Future<void> _promptNameAndListen() async {
    if (_isCreator) await _speak("What should we call you?");
    // Don't auto-open the mic on web — browser requires a user gesture first.
    if (kIsWeb) return;
    if (!_speechEnabled || _isListening || !mounted) return;
    await _listen();
  }

  Future<void> _listen() async {
    if (!_speechEnabled) return;
    
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _nameController.text = _extractName(result.recognizedWords);
          if (result.finalResult) {
            _isListening = false;
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _tapHintCtrl.dispose();
    _nameController.dispose();
    _titleTimer?.cancel();
    _burstController.dispose();
    AppTtsService.instance.stop();
    _speech.stop();
    super.dispose();
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _onAgeSelected(int age) {
    if (_submitting) return;
    // First user gesture — unlock web audio.
    AppTtsService.instance.markInteracted();
    AppTtsService.instance.stop();
    setState(() {
      _selectedAge = age;
      _step = 1; // advance to title splash
    });
    // Auto-advance from splash to name after 5 s (tap also advances).
    _titleTimer?.cancel();
    _titleTimer = Timer(const Duration(milliseconds: 5000), () {
      if (mounted && _step == 1) _enterNameStep();
    });
    final band = ageBandFromAge(age);
    if (band == AgeBand.adolescent || band == AgeBand.adult) {
      unawaited(_speak('Welcome to Story Weaver.'));
    } else if (band == AgeBand.creator) {
      unawaited(_speak('Your story begins here.'));
    } else {
      unawaited(_speak('Hi! Welcome to Story Weaver. What\'s your name?', rateScale: 0.72));
    }
  }

  void _advanceFromTitle() {
    AppTtsService.instance.markInteracted();
    _titleTimer?.cancel();
    if (mounted && _step == 1) {
      _enterNameStep();
    }
  }

  void _enterNameStep() {
    setState(() => _step = 2);
    unawaited(_promptNameAndListen());
  }

  void _advanceFromName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && _step == 2 && !_celebratingName) {
      AppTtsService.instance.stop();
      _speech.stop();
      setState(() => _celebratingName = true);
      unawaited(_burstController.trigger());
      // Say "Hi <name>!" and wait for it to finish before advancing.
      AppTtsService.instance
          .speak(
            'Hi, $name! What a great name!',
            awaitCompletion: true,
            rateScale: 0.72,
          )
          .then((_) {
        if (mounted) _handleContinue();
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120226),
      body: Stack(children: [
        Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF120226), Color(0xFF2A0A4E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _buildStep(),
                ),
              ),
            ),
          ),
        ),
      ),
      // Labeled parent button — more visible than a bare gear icon
      Positioned(
        top: 8,
        right: 8,
        child: SafeArea(
          child: TextButton.icon(
            icon: const Icon(Icons.shield_outlined, size: 18, color: Colors.white54),
            label: const Text(
              'Parent',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ParentControlsScreen()),
            ),
          ),
        ),
      ),
      ]),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case -1:
        return _buildTeaserStep();
      case 1:
        return _buildTitleStep();
      case 2:
        return _buildNameStep();
      default:
        return _buildAgeStep();
    }
  }

  // ── Step -1: First-launch teaser ──────────────────────────────────────────

  Widget _buildTeaserStep() {
    return GestureDetector(
      key: const ValueKey('teaser'),
      onTap: _dismissTeaser,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _tapHintOpacity,
                child: const Icon(
                  Icons.auto_awesome,
                  color: _goldColor,
                  size: 72,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Story Weaver',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzelDecorative(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: _goldColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your hero.\nYour story.',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _dismissTeaser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _goldColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40)),
                  elevation: 8,
                  shadowColor: _goldColor.withAlpha(160),
                ),
                child: Text(
                  "Let's start!",
                  style: GoogleFonts.fredoka(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 1: Title splash ──────────────────────────────────────────────────

  Widget _buildTitleStep() {
    return GestureDetector(
      key: const ValueKey('title'),
      onTap: _advanceFromTitle,
      child: _isAdolescent
          ? _buildAdolescentTitleStep()
          : _isCreator
              ? _buildCreatorTitleStep()
              : _isAdventurer
                  ? _buildAdventurerTitleStep()
                  : _buildDefaultTitleStep(),
    );
  }

  Widget _buildDefaultTitleStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 60),
        // Wiggling star signals "tap me!" to young children.
        WiggleWidget(
          repeat: true,
          angle: 0.12,
          duration: const Duration(milliseconds: 700),
          child: const Icon(Icons.auto_awesome, color: _goldColor, size: 64),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          label: 'Story Weaver. Welcome!',
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Once Upon\n',
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _goldColor,
                    height: 1.3,
                  ),
                ),
                TextSpan(
                  text: 'a Time',
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Pulsing "Tap me!" replaces static hint — much clearer for toddlers.
        AnimatedBuilder(
          animation: _tapHintOpacity,
          builder: (context, _) => Opacity(
            opacity: _tapHintOpacity.value,
            child: Text(
              'Tap me!',
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                color: _goldColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildCreatorTitleStep() {
    // Minimal, editorial splash for Creator band (ages 12-14).
    const creatorAccent = Color(0xFF7C4DFF);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 72),
        const Icon(Icons.edit_note_rounded, color: creatorAccent, size: 48),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          label: 'Your story begins here.',
          child: Text(
            'Your story\nbegins here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.bitter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedBuilder(
          animation: _tapHintOpacity,
          builder: (context, _) => Opacity(
            opacity: _tapHintOpacity.value,
            child: Text(
              'Tap to continue',
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSans3(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 72),
      ],
    );
  }

  Widget _buildAdventurerTitleStep() {
    return AdventurerWelcomeSequence(
      userName: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null,
      onComplete: _advanceFromTitle,
    );
  }

  // ── Step 2: Name input ────────────────────────────────────────────────────

  Widget _buildAdolescentTitleStep() {
    const adolescentAccent = Color(0xFF00BCD4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 72),
        const Icon(Icons.menu_book_rounded, color: adolescentAccent, size: 44),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          label: 'Story Weaver. Your stories, your way.',
          child: Text(
            'Story Weaver',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceSans3(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your stories, your way.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sourceSans3(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: adolescentAccent.withAlpha(200),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedBuilder(
          animation: _tapHintOpacity,
          builder: (context, _) => Opacity(
            opacity: _tapHintOpacity.value,
            child: Text(
              'Tap to continue',
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSans3(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 72),
      ],
    );
  }

  Widget _buildNameStep() {
    return (_isAdolescent || ageBandFromAge(_selectedAge ?? 0).isMature)
        ? _buildCreatorNameStep()
        : _buildDefaultNameStep();
  }

  Widget _buildDefaultNameStep() {
    final typedName = _nameController.text.trim();
    return Stack(
      key: const ValueKey('name'),
      clipBehavior: Clip.none,
      children: [
        // Star burst celebration layer — sits behind content, IgnorePointer
        Positioned.fill(
          child: IgnorePointer(
            child: StarBurstCelebration(
              controller: _burstController,
              starCount: 16,
              radiusFactor: 0.65,
              colors: const [
                Color(0xFFFFD700),
                Color(0xFFFF8CFF),
                Color(0xFF7FFFCF),
                Color(0xFFFFAA44),
                Color(0xFFB388FF),
                Color(0xFFFFFFFF),
              ],
            ),
          ),
        ),
        Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Speech bubble (centred — no mascot image) ──────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Container(
            key: ValueKey(typedName.isEmpty),
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: typedName.isEmpty
                ? Text(
                    "What's your name?",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E2723),
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    key: ValueKey(typedName),
                    tween: Tween(begin: 1.2, end: 1.0),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.elasticOut,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Text(
                      typedName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3E2723),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildNameFieldAndButton(
          hintText: _speechEnabled ? "Or type it here…" : "What's your name?",
          buttonLabel: "That's me!",
          buttonLeadingIcon: Icons.auto_awesome,
          buttonLeadingColor: _goldColor,
        ),
      ],
        ), // Column
      ],
    ); // Stack
  }

  Widget _buildCreatorNameStep() {
    // Profile-setup feel for Creator band (ages 12-14): no mascot, clean dark card.
    const creatorAccent = Color(0xFF7C4DFF);
    return Column(
      key: const ValueKey('creator-name'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.lg),
        const Icon(Icons.account_circle_outlined, color: creatorAccent, size: 52),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Set up your profile',
          style: GoogleFonts.sourceSans3(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildNameFieldAndButton(
          hintText: "What should we call you?",
          buttonLabel: "Continue",
          buttonLeadingIcon: Icons.arrow_forward_rounded,
          buttonLeadingColor: Colors.white,
          accentColor: creatorAccent,
          fieldFontFamily: 'sourceSans3',
        ),
      ],
    );
  }

  Widget _buildNameFieldAndButton({
    required String hintText,
    required String buttonLabel,
    required IconData buttonLeadingIcon,
    required Color buttonLeadingColor,
    Color? accentColor,
    String fieldFontFamily = 'fredoka',
  }) {
    final accent = accentColor ?? const Color(0xFF7B2FBE);
    final fieldStyle = fieldFontFamily == 'sourceSans3'
        ? GoogleFonts.sourceSans3(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500)
        : GoogleFonts.fredoka(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w500);
    final hintStyle = fieldFontFamily == 'sourceSans3'
        ? GoogleFonts.sourceSans3(color: Colors.white38, fontSize: 18)
        : GoogleFonts.fredoka(color: _goldColor.withAlpha(130), fontSize: 20, fontWeight: FontWeight.w500);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Voice button — primary CTA for young children ─────────────────
        if (_speechEnabled) ...[
          Semantics(
            button: true,
            label: _isListening ? 'Listening' : 'Say your name',
            child: GestureDetector(
              onTap: _listen,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? const Color(0xFF9E6CFF) : accent,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? const Color(0xFF9E6CFF) : accent).withAlpha(140),
                      blurRadius: _isListening ? 24 : 14,
                      spreadRadius: _isListening ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isListening ? 'Listening…' : 'Tap to say your name',
            style: GoogleFonts.sourceSans3(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        // ── Text field ────────────────────────────────────────────────────
        Semantics(
          label: "Enter your name",
          textField: true,
          child: TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textAlign: TextAlign.center,
            style: fieldStyle,
            autofocus: !_speechEnabled,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _advanceFromName(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: hintStyle,
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              contentPadding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accent, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          button: true,
          label: "Submit your name",
          child: _PressableButton(
            onPressed: _advanceFromName,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: [accent, accent.withAlpha(200)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withAlpha(100),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(buttonLeadingIcon, color: buttonLeadingColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    buttonLabel,
                    style: GoogleFonts.sourceSans3(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Age picker ────────────────────────────────────────────────────

  Widget _buildAgeStep() {
    return Column(
      key: const ValueKey('age'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome, color: _goldColor, size: 36),
        const SizedBox(height: 4),
        Text(
          'How old are you?',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: _goldColor,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Parents: please select your child\'s age',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 12),
        // Big circles for young children (ages 3-11) — 3×3 grid
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            const columns = 3;
            final circleSize =
                ((constraints.maxWidth - (spacing * (columns - 1))) / columns)
                    .clamp(88.0, 120.0);
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              children: _youngAgeEntries.map((entry) {
                return _AgeCircle(
                  label: entry.label,
                  value: entry.value,
                  size: circleSize,
                  glyph: _glyphForAge(entry.value),
                  selected: _selectedAge == entry.value,
                  onTap: _submitting
                      ? null
                      : () => _onAgeSelected(entry.value),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        // Divider + label for older bands
        Row(children: [
          const Expanded(child: Divider(color: Colors.white24)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Older?',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          const Expanded(child: Divider(color: Colors.white24)),
        ]),
        const SizedBox(height: 10),
        // Pill buttons for older age bands — 3 in a single symmetrical row
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: _olderAgeEntries.map((entry) {
            final selected = _selectedAge == entry.value;
            return _AgeBandButton(
              label: entry.label,
              glyph: _glyphForOlderBand(entry.value),
              selected: selected,
              onTap: _submitting ? null : () => _onAgeSelected(entry.value),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _glyphForAge(int age) {
    if (age <= 5) return '🌱'; // sprout
    if (age <= 8) return '🧭'; // explorer
    return '⚔️'; // adventurer
  }

  static String? _glyphForOlderBand(int value) {
    if (value == 12) return '🖊️'; // creator
    return null; // adolescent / adult — keep clean
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedAge == null) return;

    setState(() => _submitting = true);

    await const ParentalConsentService().saveDeclaredAge(_selectedAge!);
    await ref.read(ageBandNotifierProvider.notifier).setAge(_selectedAge!);

    if (_selectedAge! < 13) {
      // For under-13 users, obtain parental consent BEFORE persisting the
      // child's name — collecting personal info prior to consent is a COPPA
      // violation (M-1).
      if (!mounted) return;
      final granted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ParentalConsentScreen(
            consentService: const ParentalConsentService(),
            declaredAge: _selectedAge!,
          ),
        ),
      );
      if (mounted) setState(() => _submitting = false);
      if (granted == true) {
        // Consent obtained — now safe to persist the child's name.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kUserNameKey, name);
        // Offer parent controls setup before the child starts playing.
        if (mounted) {
          final setupNow = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A0533),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Shape the stories',
                style: GoogleFonts.fredoka(color: _goldColor, fontSize: 22),
              ),
              content: Text(
                'Is there something your child could use a little help with '
                'right now? Hearing no, bedtime worry, sibling moments?\n\n'
                'Pick what\'s been tough and stories will quietly work on it. '
                'Your child will never see these choices.',
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Maybe later',
                      style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goldColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Set up now'),
                ),
              ],
            ),
          );
          if (mounted && setupNow == true) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ParentControlsScreen(
                  openBigFeelings: true,
                  skipMathGate: true, // parent just completed consent
                ),
              ),
            );
          }
        }
        // One-time "new adventures unlocked" celebration for Adventurer band.
        if (mounted && ageBandFromAge(_selectedAge!) == AgeBand.adventurer) {
          await AdventurerUnlockCelebration.show(context);
        }
        if (mounted) widget.onComplete();
      }
      return;
    }

    // Age 13+ — no parental consent required; persist name immediately.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserNameKey, name);
    await const ParentalConsentService().recordConsent(
      age: _selectedAge!,
      method: 'self_attested',
    );
    if (mounted) {
      setState(() => _submitting = false);
      widget.onComplete();
    }
  }
}

/// Button that scales down on press for tactile feedback.
class _PressableButton extends StatefulWidget {
  const _PressableButton({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}


/// Wide pill button for grouped older age bands (e.g. "9 – 11").
class _AgeBandButton extends StatefulWidget {
  const _AgeBandButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.glyph,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? glyph;

  @override
  State<_AgeBandButton> createState() => _AgeBandButtonState();
}

class _AgeBandButtonState extends State<_AgeBandButton> {
  bool _pressed = false;

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A148C), Color(0xFF7B2FBE)],
            ),
            border: widget.selected
                ? Border.all(color: _gold, width: 2.5)
                : Border.all(color: Colors.white24, width: 1.5),
            boxShadow: widget.selected
                ? [BoxShadow(color: _gold.withAlpha(90), blurRadius: 14, spreadRadius: 1)]
                : [],
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.glyph != null) ...[
                  Text(widget.glyph!, style: const TextStyle(fontSize: 13, height: 1.0)),
                  const SizedBox(width: 4),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.selected ? _gold : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable age circle with press + selection animations.
class _AgeCircle extends StatefulWidget {
  const _AgeCircle({
    required this.label,
    required this.value,
    required this.size,
    required this.selected,
    required this.onTap,
    this.glyph,
  });

  final String label;
  final int value;
  final double size;
  final bool selected;
  final VoidCallback? onTap;
  final String? glyph;

  @override
  State<_AgeCircle> createState() => _AgeCircleState();
}

class _AgeCircleState extends State<_AgeCircle> {
  bool _pressed = false;

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: 'Age ${widget.label}',
      hint: widget.selected ? "Selected" : "Double tap to select",
      child: GestureDetector(
        onTapDown:
            widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.9 : (widget.selected ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutBack,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A148C), Color(0xFF7B2FBE)],
              ),
              border: widget.selected
                  ? Border.all(color: _gold, width: 3)
                  : Border.all(color: Colors.white24, width: 1.5),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: _gold.withAlpha(100),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            alignment: Alignment.center,
            child: widget.glyph != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.glyph!,
                        style: TextStyle(fontSize: widget.size * 0.22, height: 1.0),
                      ),
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.selected ? _gold : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: widget.label.length > 2
                              ? widget.size * 0.17
                              : widget.size * 0.24,
                          height: 1.1,
                        ),
                      ),
                    ],
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.selected ? _gold : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.label.length > 2
                          ? widget.size * 0.19
                          : widget.size * 0.28,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
