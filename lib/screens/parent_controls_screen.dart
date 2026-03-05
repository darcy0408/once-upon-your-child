import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/parental_consent_service.dart';
import '../theme/app_theme.dart';
import 'byok_setup_wizard.dart';

class ParentControlsScreen extends StatefulWidget {
  const ParentControlsScreen({super.key});

  @override
  State<ParentControlsScreen> createState() => _ParentControlsScreenState();
}

class _ParentControlsScreenState extends State<ParentControlsScreen> {
  final _consentService = const ParentalConsentService();
  bool _allowPhotoAvatar = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _consentService.getAllowPhotoAvatar().then((v) {
      if (mounted) setState(() { _allowPhotoAvatar = v; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gradientStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Parent Controls',
          style: GoogleFonts.fredoka(color: Colors.white, fontSize: 22),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _SectionHeader(title: '🖼️  Avatar & Photos'),
                  _ControlTile(
                    title: 'Allow photo-based avatar creation',
                    subtitle:
                        'Your child can use a selfie to create their avatar. '
                        'Photos are processed on-device and never uploaded.',
                    value: _allowPhotoAvatar,
                    onChanged: (v) async {
                      await _consentService.setAllowPhotoAvatar(v);
                      if (mounted) setState(() => _allowPhotoAvatar = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionHeader(title: '🔑  Bring Your Own API Key (BYOK)'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'By default, Story Weaver uses our shared AI service. '
                      'If you have a Google Gemini API key, you can use it instead — '
                      'this unlocks premium-quality illustrations and personalised '
                      'avatars at no extra cost to us.',
                      style: GoogleFonts.fredoka(
                          color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  _ActionTile(
                    icon: Icons.vpn_key_rounded,
                    title: 'Set up your own API key',
                    subtitle: 'Unlock premium AI illustrations & avatar generation',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ByokSetupWizardScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'More parental controls coming soon.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fredoka(
                        color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: GoogleFonts.fredoka(
          color: const Color(0xFFFFD700),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: SwitchListTile(
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        activeThumbColor: const Color(0xFFFFD700),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFD700), size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
