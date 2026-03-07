import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/age_band_provider.dart';
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

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  int? _selectedAge;
  bool _submitting = false;

  /// Current step: 0 = title, 1 = name, 2 = age + button.
  int _step = 0;

  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  Timer? _bounceTimer;
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
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -14).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
    // Auto-advance from title to name after 2.5 s (tap also advances).
    _titleTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _step == 0) setState(() => _step = 1);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bounceController.dispose();
    _bounceTimer?.cancel();
    _titleTimer?.cancel();
    super.dispose();
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _advanceFromTitle() {
    _titleTimer?.cancel();
    if (mounted && _step == 0) setState(() => _step = 1);
  }

  void _advanceFromName() {
    if (_nameController.text.trim().isNotEmpty && _step == 1) {
      setState(() => _step = 2);
    }
  }

  void _onAgeSelected(int age) {
    setState(() => _selectedAge = age);
    _startBounceCountdown();
  }

  /// After 3 s of inactivity on the age step, bounce the Let's Go button.
  void _startBounceCountdown() {
    _bounceTimer?.cancel();
    _bounceController
      ..stop()
      ..reset();
    _bounceTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_submitting) _bounceController.repeat(reverse: true);
    });
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
          RichText(
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
                  text: 'YOUR',
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                TextSpan(
                  text: ' Child',
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _goldColor,
                    height: 1.3,
                  ),
                ),
              ],
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
        const Icon(Icons.auto_awesome, color: _goldColor, size: 48),
        const SizedBox(height: AppSpacing.md),
        Text(
          "What's your name?",
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: _goldColor,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _advanceFromName(),
          decoration: InputDecoration(
            hintText: 'Enter your name\u2026',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withAlpha(15),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _goldColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _PressableButton(
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
            child: Text(
              "That's me! \u2192",
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Age picker + Let's Go ─────────────────────────────────────────

  Widget _buildAgeStep() {
    final ready = _selectedAge != null;
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
            fontSize: 23,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Parents: please select your child\'s age',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 5.0;
            final circleSize =
                ((constraints.maxWidth - (spacing * 2)) / 3).clamp(41.0, 48.0);
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
        const SizedBox(height: AppSpacing.md),

        // ── Let's Go button with bounce + brighten ─────────────────────────
        AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _bounceAnimation.value),
            child: child,
          ),
          child: _PressableButton(
            onPressed: (_submitting || !ready) ? null : _handleContinue,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: ready
                      ? [
                          const Color(0xFFFFD700),
                          const Color(0xFFFF8C00),
                        ]
                      : [Colors.white12, Colors.white12],
                ),
                boxShadow: ready
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withAlpha(130),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: _submitting
                    ? const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)
                    : Text(
                        "Let's go! \u2728",
                        style: GoogleFonts.fredoka(
                          color: ready ? Colors.white : Colors.white38,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Logic ─────────────────────────────────────────────────────────────────

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedAge == null) return;

    _bounceController.stop();
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
    return GestureDetector(
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
    );
  }
}
