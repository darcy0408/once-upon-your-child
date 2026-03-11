import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/parental_consent_service.dart';
import '../theme/app_theme.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class ParentalConsentScreen extends StatefulWidget {
  const ParentalConsentScreen({
    super.key,
    required this.consentService,
    required this.declaredAge,
  });

  final ParentalConsentService consentService;
  final int declaredAge;

  @override
  State<ParentalConsentScreen> createState() => _ParentalConsentScreenState();
}

class _ParentalConsentScreenState extends State<ParentalConsentScreen> {
  String? _parentEmail;
  bool _consentGiven = false;
  bool _allowPhotoAvatar = true;
  bool _submitting = false;
  @override
  Widget build(BuildContext context) {
    const textWhite = TextStyle(color: Colors.white);
    const textWhite70 = TextStyle(color: Colors.white70);

    return Scaffold(
      backgroundColor: AppColors.gradientStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Parental Consent Required',
          style: GoogleFonts.fredoka(color: Colors.white, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientStart, Color(0xFF1E0A3C)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello Parent/Guardian! 👋',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your child (age ${widget.declaredAge}) would like to use Story Weaver. '
                  'We need your permission because they are under 13.',
                  style: GoogleFonts.fredoka(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'What We Do:',
                  style: GoogleFonts.fredoka(
                    color: const Color(0xFFFFD700),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text('• Generate personalized stories using AI', style: textWhite),
                const Text('• Provide therapeutic content for emotional growth', style: textWhite),
                const Text('• Collect minimal data (story preferences only)', style: textWhite),
                const Text("• Never sell or share your child's information", style: textWhite),
                const Text(
                  '• Optionally let your child use a photo to create a personalised avatar'
                  ' — stored only on this device, never uploaded',
                  style: textWhite,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Your Email (optional)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'parent@example.com',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(120)),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withAlpha(25),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white54),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) => _parentEmail = value,
                ),
                const SizedBox(height: AppSpacing.sm),
                // ── Photo avatar opt-out ───────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Allow photo-based avatar creation',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Your child can use a selfie to create their avatar. '
                      'Photos are processed on-device and never uploaded.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    activeThumbColor: const Color(0xFFFFD700),
                    value: _allowPhotoAvatar,
                    onChanged: (value) =>
                        setState(() => _allowPhotoAvatar = value),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  decoration: BoxDecoration(
                    color: _consentGiven
                        ? const Color(0xFFFFD700).withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _consentGiven
                          ? const Color(0xFFFFD700)
                          : Colors.white70,
                      width: _consentGiven ? 2 : 1.5,
                    ),
                  ),
                  child: CheckboxListTile(
                    title: const Text(
                      'I am a parent/guardian and give permission',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'I have read the Privacy Policy and Terms of Service',
                      style: textWhite70,
                    ),
                    checkColor: Colors.black,
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFFFFD700);
                      }
                      return Colors.white.withValues(alpha: 0.25);
                    }),
                    side: const BorderSide(color: Colors.white70, width: 2),
                    value: _consentGiven,
                    onChanged: (value) =>
                        setState(() => _consentGiven = value ?? false),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                      child: const Text('Privacy Policy',
                          style: TextStyle(color: Color(0xFFFFD700))),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsOfServiceScreen(),
                          ),
                        );
                      },
                      child: const Text('Terms of Service',
                          style: TextStyle(color: Color(0xFFFFD700))),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: !_consentGiven || _submitting ? null : _submitConsent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _submitting ? 'Saving...' : 'Give Permission ✓',
                      style: GoogleFonts.fredoka(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Future<void> _submitConsent() async {
    setState(() => _submitting = true);
    try {
      await widget.consentService.recordConsent(
        age: widget.declaredAge,
        parentEmail: _parentEmail?.trim(),
        method: 'parent',
        allowPhotoAvatar: _allowPhotoAvatar,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save consent. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
