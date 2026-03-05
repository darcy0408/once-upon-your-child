import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/age_band_provider.dart';
import '../services/parental_consent_service.dart';
import '../theme/app_theme.dart';
import 'parental_consent_screen.dart';

const _kUserNameKey = 'user_name';

/// Shown on first launch to collect the child's name and age.
/// Sets the age band so every subsequent screen renders correctly.
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
    (label: '13‑17', value: 14),
    (label: '18+', value: 21),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: _goldColor, size: 48),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Welcome to\nStory Weaver!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzelDecorative(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _goldColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "Let's get you set up for your adventure",
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Name input ──────────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "What's your name?",
                        style: GoogleFonts.fredoka(
                          color: _goldColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20),
                      decoration: InputDecoration(
                        hintText: 'Enter your name…',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withAlpha(15),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: _goldColor, width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Age grid ────────────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'How old are you?',
                        style: GoogleFonts.fredoka(
                          color: _goldColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Parents: please select your child\'s age',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white38),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      children: _ageEntries.map((entry) {
                        final selected = _selectedAge == entry.value;
                        return _AgeCircle(
                          label: entry.label,
                          selected: selected,
                          onTap: _submitting
                              ? null
                              : () => setState(
                                  () => _selectedAge = entry.value),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Continue button ─────────────────────────────────────
                    GestureDetector(
                      onTap: _submitting ? null : _handleContinue,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            colors: _selectedAge != null &&
                                    _nameController.text.trim().isNotEmpty
                                ? [
                                    const Color(0xFF7B2FBE),
                                    const Color(0xFF4A148C),
                                  ]
                                : [
                                    Colors.white12,
                                    Colors.white12,
                                  ],
                          ),
                          boxShadow: _selectedAge != null &&
                                  _nameController.text.trim().isNotEmpty
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF7B2FBE)
                                        .withAlpha(100),
                                    blurRadius: 16,
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
                                  "Let's go! ✨",
                                  style: GoogleFonts.fredoka(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
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

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Please enter your name to continue.');
      return;
    }
    if (_selectedAge == null) {
      _showSnack('Please select your age to continue.');
      return;
    }

    setState(() => _submitting = true);

    // Persist name
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserNameKey, name);

    // Persist age and update the age band
    await const ParentalConsentService().saveDeclaredAge(_selectedAge!);
    await ref
        .read(ageBandNotifierProvider.notifier)
        .setAge(_selectedAge!);

    // Under-13: show parental consent screen
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

    // 13+: just record and proceed
    await const ParentalConsentService().recordConsent(
      age: _selectedAge!,
      method: 'self_attested',
    );
    if (mounted) {
      setState(() => _submitting = false);
      widget.onComplete();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Tappable age circle — shared styling.
class _AgeCircle extends StatelessWidget {
  const _AgeCircle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A148C), Color(0xFF7B2FBE)],
            ),
            border: selected
                ? Border.all(color: _gold, width: 3)
                : Border.all(color: Colors.white24, width: 1.5),
            boxShadow: selected
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
            label,
            style: TextStyle(
              color: selected ? _gold : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: label.length > 2 ? 16 : 22,
            ),
          ),
        ),
      ),
    );
  }
}
