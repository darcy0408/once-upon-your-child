import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../providers/age_band_provider.dart';
import '../services/app_tts_service.dart';
import '../services/parental_consent_service.dart';
import '../theme/app_theme.dart';
import 'parental_consent_screen.dart';
import 'parent_controls_screen.dart';

const _kUserNameKey = 'user_name';

/// Shown on first launch to collect the child's name and age.
/// Steps: 0 = title splash, 1 = name input, 2 = age picker + go button.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Called after onboarding is fully complete (consent granted if needed).
  final VoidCallback onComplete;

  const WelcomeScreen({super.key, required this.onComplete});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _nameController = TextEditingController();
  int? _selectedAge;
  bool _submitting = false;

  final _speech = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  /// Current step: 0 = title, 1 = name, 2 = age picker.
  int _step = 0;

  Timer? _titleTimer;

  static const _goldColor = Color(0xFFFFD700);

  static const _ageEntries = <({String label, int value})>[
    (label: '3', value: 3),
    (label: '4', value: 4),
    (label: '5', value: 5),
    (label: '6', value: 6),
    (label: '7', value: 7),
    (label: '8', value: 8),
    (label: '9', value: 9),
    (label: '10', value: 10),
    (label: '11', value: 11),
    (label: '12', value: 12),
    (label: '13\u201117', value: 14),
    (label: '18+', value: 21),
  ];

  @override
  void initState() {
    super.initState();
    _initVoice();
    // Auto-advance from title to name after 2.5 s (tap also advances).
    _titleTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _step == 0) {
        _enterNameStep();
      }
    });
  }

  Future<void> _initVoice() async {
    _speechEnabled = await _speech.initialize();
    if (mounted) {
      setState(() {});
      if (_step == 0) unawaited(_speak('Tap the star to start your adventure!'));
    }
  }

  Future<void> _speak(String text, {bool awaitCompletion = false}) async {
    await AppTtsService.instance.speak(text, awaitCompletion: awaitCompletion);
  }

  Future<void> _promptNameAndListen() async {
    await _speak("Hi, what's your name?");
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
          _nameController.text = result.recognizedWords;
          if (result.finalResult) {
            _isListening = false;
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleTimer?.cancel();
    AppTtsService.instance.stop();
    _speech.stop();
    super.dispose();
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _advanceFromTitle() {
    _titleTimer?.cancel();
    if (mounted && _step == 0) {
      _enterNameStep();
    }
  }

  void _enterNameStep() {
    setState(() => _step = 1);
    unawaited(_promptNameAndListen());
  }

  void _advanceFromName() {
    if (_nameController.text.trim().isNotEmpty && _step == 1) {
      AppTtsService.instance.stop();
      _speech.stop();
      setState(() => _step = 2);
      unawaited(_speak('How old are you? Tap your number!'));
    }
  }

  void _onAgeSelected(int age) {
    if (_submitting) return;
    setState(() => _selectedAge = age);
    _handleContinue();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120226),
      // Small gear icon for parents to reach controls without cluttering the UI
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: Colors.white.withAlpha(30),
        foregroundColor: Colors.white70,
        tooltip: 'Parent Controls',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ParentControlsScreen()),
        ),
        child: const Icon(Icons.settings_outlined),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Container(
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
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _buildNameStep();
      case 2:
        return _buildAgeStep();
      default:
        return _buildTitleStep();
    }
  }

  // ── Step 0: Title splash ──────────────────────────────────────────────────

  Widget _buildTitleStep() {
    return GestureDetector(
      key: const ValueKey('title'),
      onTap: _advanceFromTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.auto_awesome, color: _goldColor, size: 64),
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
          const Text(
            'Tap to begin your adventure\u2026',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ── Step 1: Name input ────────────────────────────────────────────────────

  Widget _buildNameStep() {
    return Column(
      key: const ValueKey('name'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: "Enter your name",
          textField: true,
          child: TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _advanceFromName(),
            decoration: InputDecoration(
              hintText: "What's your name?",
              hintStyle: GoogleFonts.fredoka(
                color: _goldColor.withAlpha(180),
                fontSize: 26,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              contentPadding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: _goldColor, width: 2),
              ),
              // Mic icon lives inside the field — no separate button needed
              suffixIcon: _speechEnabled
                  ? AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _isListening
                            ? const Color(0xFF9E6CFF).withAlpha(200)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: _isListening
                              ? Colors.white
                              : Colors.white54,
                          size: 28,
                        ),
                        tooltip: _isListening ? 'Listening…' : 'Say your name',
                        onPressed: _listen,
                      ),
                    )
                  : null,
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B2FBE), Color(0xFF4A148C)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2FBE).withAlpha(100),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: _goldColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "That's me!",
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_speechEnabled) ...[
          const SizedBox(height: 12),
          _PressableButton(
            onPressed: _listen,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: _isListening
                    ? const Color(0xFF9E6CFF).withAlpha(220)
                    : Colors.white.withAlpha(20),
                border: Border.all(
                  color: _isListening
                      ? const Color(0xFF9E6CFF)
                      : Colors.white38,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isListening
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded,
                    color:
                        _isListening ? Colors.white : Colors.white70,
                    size: 30,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isListening ? 'Listening…' : 'Tap to say your name',
                    style: GoogleFonts.fredoka(
                      color:
                          _isListening ? Colors.white : Colors.white70,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final circleSize =
                ((constraints.maxWidth - (spacing * 2)) / 3).clamp(32.0, 42.0);
            return GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              children: _ageEntries.map((entry) {
                return _AgeCircle(
                  label: entry.label,
                  size: circleSize,
                  selected: _selectedAge == entry.value,
                  onTap: _submitting ? null : () => _onAgeSelected(entry.value),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedAge == null) return;

    setState(() => _submitting = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserNameKey, name);

    await const ParentalConsentService().saveDeclaredAge(_selectedAge!);
    await ref.read(ageBandNotifierProvider.notifier).setAge(_selectedAge!);

    if (_selectedAge! < 13) {
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
      if (granted == true) widget.onComplete();
      return;
    }

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

/// Tappable age circle with press + selection animations.
class _AgeCircle extends StatefulWidget {
  const _AgeCircle({
    required this.label,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

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
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.selected ? _gold : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: widget.label.length > 2 ? 10 : 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
