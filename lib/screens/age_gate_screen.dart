import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/parental_consent_service.dart';
import '../theme/app_theme.dart';
import 'parental_consent_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({
    super.key,
    required this.consentService,
    required this.onConsentCompleted,
  });

  final ParentalConsentService consentService;
  final VoidCallback onConsentCompleted;

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  int? _selectedAge;
  bool _submitting = false;

  static const _goldColor = Color(0xFFFFD700);

  // Age options: individual ages 3–12, then grouped 13-17 and 18+.
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
                vertical: AppSpacing.sm,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: _goldColor, size: 40),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome to\nStory Weaver!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzelDecorative(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _goldColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Parents: please select your child\'s age',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 6.0;
                        final circleSize =
                            ((constraints.maxWidth - (spacing * 2)) / 3)
                                .clamp(50.0, 56.0);
                        return GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          children: _ageEntries.map((entry) {
                            final selected = _selectedAge == entry.value;
                            return _AgeCircle(
                              label: entry.label,
                              size: circleSize,
                              selected: selected,
                              onTap: _submitting
                                  ? null
                                  : () => setState(
                                      () => _selectedAge = entry.value),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Continue arrow button
                    GestureDetector(
                      onTap: _submitting ? null : _handleContinue,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B2FBE), Color(0xFF4A148C)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B2FBE).withAlpha(100),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _submitting
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We collect age to provide age-appropriate content. See our',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          ),
                          child: Text(
                            'Privacy Policy',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: _goldColor.withAlpha(180),
                                  decoration: TextDecoration.underline,
                                  decorationColor: _goldColor.withAlpha(180),
                                ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsOfServiceScreen(),
                            ),
                          ),
                          child: Text(
                            'Terms of Service',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: _goldColor.withAlpha(180),
                                  decoration: TextDecoration.underline,
                                  decorationColor: _goldColor.withAlpha(180),
                                ),
                          ),
                        ),
                      ],
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
    if (_selectedAge == null) {
      _showSnack('Please select your age to continue.');
      return;
    }

    setState(() => _submitting = true);
    await widget.consentService.saveDeclaredAge(_selectedAge!);

    if (_selectedAge! < 13) {
      if (!mounted) return;
      final granted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ParentalConsentScreen(
            consentService: widget.consentService,
            declaredAge: _selectedAge!,
          ),
        ),
      );
      setState(() => _submitting = false);
      if (granted == true) {
        widget.onConsentCompleted();
      }
      return;
    }

    await _captureParentalKnowledgeConsent();
    if (mounted) {
      setState(() => _submitting = false);
      widget.onConsentCompleted();
    }
  }

  Future<void> _captureParentalKnowledgeConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Parent/Guardian Notification'),
        content: const Text(
          'If you are under 18, please make sure a parent or guardian knows you are using this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.consentService.recordConsent(
        age: _selectedAge!,
        method: 'self_attested',
      );
      _showSnack('Thanks! Your age has been recorded.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// A single tappable age circle with selection glow animation.
class _AgeCircle extends StatelessWidget {
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

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Container(
          width: size,
          height: size,
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
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _gold : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: label.length > 2 ? 12 : 17,
            ),
          ),
        ),
      ),
    );
  }
}
