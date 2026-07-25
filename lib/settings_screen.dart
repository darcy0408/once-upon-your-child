// lib/settings_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/environment.dart';
import 'models/subscription_status.dart';
import 'providers/subscription_provider.dart';
import 'providers/text_scale_provider.dart';
import 'providers/theme_provider.dart';
import 'subscription_screen.dart';
import 'theme/age_band_theme.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/parental_gate_dialog.dart';
import 'screens/child_profile_manager_screen.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/subscription_management_screen.dart';
import 'screens/weekly_recap_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _parentUnlocked = false;

  Future<void> _unlockParentSettings() async {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    final rng = DateTime.now().millisecondsSinceEpoch;
    final a = 12 + (rng % 15);
    final b = 7 + ((rng ~/ 100) % 12);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        String? error;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF2C1B47),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Parent Verification',
                style: TextStyle(
                    fontFamily: band?.uiFontFamily ?? 'Quicksand',
                    color: const Color(0xFFFFD700),
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Solve to access parent settings:',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                Text('$a + $b = ?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: InputDecoration(
                    labelText: 'Answer',
                    hintText: '?',
                    hintStyle: const TextStyle(color: Colors.white24),
                    errorText: error,
                    errorStyle: const TextStyle(color: Colors.orangeAccent),
                    filled: true,
                    fillColor: Colors.white.withAlpha(15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) {
                    if (int.tryParse(controller.text.trim()) == a + b) {
                      Navigator.pop(ctx, true);
                    } else {
                      setDialogState(() => error = 'Try again!');
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A)),
                  onPressed: () {
                    if (int.tryParse(controller.text.trim()) == a + b) {
                      Navigator.pop(ctx, true);
                    } else {
                      setDialogState(() => error = 'Try again!');
                    }
                  },
                  child: const Text('Unlock',
                      style: TextStyle(color: Colors.white))),
            ],
          ),
        );
      },
    );

    if (result == true && mounted) {
      setState(() => _parentUnlocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeNotifierProvider);
    final band = Theme.of(context).extension<AgeBandThemeData>();
    // Gate parent-only settings behind an arithmetic puzzle for young bands
    // (sprout/explorer/adventurer). Mature bands (creator/adolescent/adult)
    // are the account holder — no gate. Previously the gate only excluded
    // Creator, which inadvertently locked adults out of their own account.
    final isMature = band?.band.isMature ?? false;
    final isChildBand = band != null && !isMature;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Toggle between light and dark themes'),
                value: themeMode == ThemeMode.dark,
                onChanged: (_) {
                  ref.read(themeModeNotifierProvider.notifier).toggle();
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildTextSizeCard(context),
            const SizedBox(height: AppSpacing.lg),
            if (isChildBand && !_parentUnlocked) ...[
              AppCard(
                child: ListTile(
                  leading:
                      const Icon(Icons.lock_outline, color: Color(0xFFD4A0FF)),
                  title: Text('Parent Settings',
                      style: TextStyle(
                          fontFamily: band.uiFontFamily,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text('Subscription, dashboard, and account',
                      style: TextStyle(
                          fontFamily: band.uiFontFamily,
                          fontSize: 13,
                          color: Colors.grey)),
                  trailing:
                      const Icon(Icons.chevron_right, color: Color(0xFFD4A0FF)),
                  onTap: _unlockParentSettings,
                ),
              ),
            ] else ...[
              AppCard(
                child: ListTile(
                  leading: const Icon(Icons.dashboard_rounded,
                      color: AppColors.primary),
                  title: Text(
                      isMature ? 'Activity Dashboard' : 'Parent Dashboard',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(isMature
                      ? 'Your stories, feelings trends & activity'
                      : 'Stories, feelings trends & activity'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ParentDashboardScreen()),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: ListTile(
                  leading: const Icon(Icons.calendar_view_week_rounded,
                      color: AppColors.primary),
                  title: const Text('Weekly Recap',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(isMature
                      ? 'Your last 7 days — printable summary'
                      : 'The last 7 days — printable for a therapist or teacher'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WeeklyRecapScreen()),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: ListTile(
                  leading: const Icon(Icons.people_rounded,
                      color: AppColors.primary),
                  title: Text(
                      isMature ? 'Manage Profiles' : 'Manage Child Profiles',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(isMature
                      ? 'Add, edit or switch profiles'
                      : 'Add, edit or switch child profiles'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChildProfileManagerScreen()),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildSubscriptionCard(context),
            ],
            const SizedBox(height: AppSpacing.lg),
            _buildLegalLinks(context),
            if (Environment.isDevelopment) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildDevToolsCard(context),
            ],
          ],
        ),
      ),
    );
  }

  /// "Text Size" section — an app-wide, persisted text scale independent of
  /// the age-band theme. Flutter web doesn't read the OS/browser font-size
  /// setting, so this is the only way a parent with large system fonts can
  /// make in-app text bigger.
  Widget _buildTextSizeCard(BuildContext context) {
    final textScale = ref.watch(textScaleNotifierProvider);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Text Size', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Make in-app text bigger or smaller',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            Row(
              children: [
                const Text('A', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Slider(
                    value: textScale,
                    min: kMinTextScale,
                    max: kMaxTextScale,
                    divisions: 5,
                    label: '${(textScale * 100).round()}%',
                    onChanged: (value) {
                      ref.read(textScaleNotifierProvider.notifier).setScale(value);
                    },
                  ),
                ),
                const Text('A', style: TextStyle(fontSize: 28)),
              ],
            ),
            Center(
              child: Text(
                'The quick brown fox jumps over the lazy dog.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16 * textScale),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context) {
    return AppCard(
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_rounded,
            color: AppColors.primary),
        title: const Text('Premium Subscription',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Manage your plan, billing and receipts'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const SubscriptionManagementScreen()),
        ),
      ),
    );
  }

  Widget _buildDevToolsCard(BuildContext context) {
    return AppCard(
      color: Colors.deepPurple.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🛠 Dev Tools (Development Only)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    // Dev shortcut: write directly to the SharedPref keys that
                    // ApiServiceManager.hasPremiumAccess and
                    // ProgressionService.hasPaidPremium actually read. Bypasses
                    // Stripe — useful for local UI testing of premium-only
                    // surfaces without standing up a checkout session.
                    //
                    // NOTE: SubscriptionSyncService will OVERWRITE these keys on
                    // its next backend sync, so the override is ephemeral and
                    // will not corrupt real subscription state on a logged-in
                    // user. (Previously this called a non-canonical method that
                    // wrote to the wrong key, so this button was a silent no-op.)
                    final prefs = await SharedPreferences.getInstance();
                    final fakeStatus = SubscriptionStatus(
                      userId: 'dev_override',
                      tier: SubscriptionTier.premium,
                      status: 'active',
                      currentPeriodEnd:
                          DateTime.now().add(const Duration(days: 365)),
                      cancelAtPeriodEnd: false,
                    );
                    await prefs.setBool('is_paid_premium', true);
                    await prefs.setString(
                      'subscription_status',
                      jsonEncode(fakeStatus.toJson()),
                    );
                    if (context.mounted) {
                      ProviderScope.containerOf(context)
                          .read(subscriptionProvider.notifier)
                          .refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              '✅ Upgraded to Premium (dev only — local override)'),
                          backgroundColor: Colors.deepPurple,
                        ),
                      );
                    }
                  },
                  child: const Text('Force Premium'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    // Dev shortcut: clear the premium-access keys directly.
                    // Same caveat as Force Premium — next backend sync will
                    // overwrite. Also clears the legacy `user_subscription`
                    // key in case stale data is lurking from before MT-104.
                    final prefs = await SharedPreferences.getInstance();
                    final freeStatus = SubscriptionStatus(
                      userId: 'dev_override',
                      tier: SubscriptionTier.free,
                      status: 'inactive',
                      cancelAtPeriodEnd: false,
                    );
                    await prefs.setBool('is_paid_premium', false);
                    await prefs.setString(
                      'subscription_status',
                      jsonEncode(freeStatus.toJson()),
                    );
                    await prefs.remove('user_subscription');
                    if (context.mounted) {
                      ProviderScope.containerOf(context)
                          .read(subscriptionProvider.notifier)
                          .refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('↩ Reset to Free tier')),
                      );
                    }
                  },
                  child: const Text('Reset to Free'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E57C2),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: const Icon(Icons.credit_card),
              label: const Text('💳 Real Stripe Checkout (test card 4242…)'),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () =>
                throw Exception('Test crash for Sentry verification'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[900],
              foregroundColor: Colors.white,
            ),
            child: const Text('Test Crash'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalLinks(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Legal',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                );
              },
              child: const Text('Privacy Policy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen(),
                  ),
                );
              },
              child: const Text('Terms of Service'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildPartnersSection(context),
      ],
    );
  }

  Widget _buildPartnersSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Partners',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () => _openPartnerLink(context),
          child: SvgPicture.network(
            isDark
                ? 'https://eleven-public-cdn.elevenlabs.io/payloadcms/csnjio02mx4-elevenlabs-logo-white.svg'
                : 'https://eleven-public-cdn.elevenlabs.io/payloadcms/rxk2xwmcbb-elevenlabs-logo-black.svg',
            height: 28,
            semanticsLabel: 'ElevenLabs Impact Program',
            placeholderBuilder: (_) => const Text('ElevenLabs Impact Program'),
          ),
        ),
      ],
    );
  }

  /// Opens the ElevenLabs partner page behind a parental gate.
  /// Kids-Category requirement (Apple Guideline 1.3 / 5.1.4): links out of the
  /// app must sit behind a gate a child cannot trivially pass. Reuses the
  /// shared [ParentalGateDialog] (math challenge).
  Future<void> _openPartnerLink(BuildContext context) async {
    final passed = await ParentalGateDialog.show(context);
    if (!passed || !context.mounted) return;
    final uri = Uri.parse('https://elevenlabs.io/impact-program');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the link. Please try again later.'),
        ),
      );
    }
  }
}
