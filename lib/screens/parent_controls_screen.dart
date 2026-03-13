import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/parental_consent_service.dart';
import '../services/screen_time_service.dart';
import '../theme/app_theme.dart';
import 'byok_setup_wizard.dart';

class ParentControlsScreen extends StatefulWidget {
  const ParentControlsScreen({super.key});

  @override
  State<ParentControlsScreen> createState() => _ParentControlsScreenState();
}

class _ParentControlsScreenState extends State<ParentControlsScreen> {
  final _consentService = const ParentalConsentService();
  static const _bigFeelingsContextOptions = [
    (
      value: 'trouble hearing no',
      label: 'Trouble hearing no',
      emoji: '🚫',
      description: 'Helps stories practice hearing no without exploding.',
    ),
    (
      value: 'friendship hurt',
      label: 'Friendship hurt',
      emoji: '💔',
      description: 'Shapes stories around hurt feelings and reconnecting.',
    ),
    (
      value: 'bedtime worry',
      label: 'Bedtime worry',
      emoji: '🌙',
      description: 'Steers stories toward dark-room comfort and bedtime bravery.',
    ),
    (
      value: 'sibling conflict',
      label: 'Sibling conflict',
      emoji: '🧒',
      description: 'Supports sharing, repair, and calming around sibling friction.',
    ),
    (
      value: 'hard transitions',
      label: 'Hard transitions',
      emoji: '🔄',
      description: 'Supports moving between activities with less overwhelm.',
    ),
    (
      value: 'meltdown when stuck',
      label: 'Meltdown when stuck',
      emoji: '🧩',
      description: 'Helps stories model staying with hard things and trying again.',
    ),
  ];
  bool _allowPhotoAvatar = true;
  bool _loading = true;
  int? _dailyLimitMinutes;
  bool _bedtimeEnabled = false;
  int _bedtimeHour = 20;
  int _bedtimeMinute = 0;
  int _todayUsage = 0;
  String? _bigFeelingsHiddenContext;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final allowPhoto = await _consentService.getAllowPhotoAvatar();
    final limit = await _consentService.getDailyLimitMinutes();
    final bedtimeEnabled = await _consentService.isBedtimeLockoutEnabled();
    final bedtime = await _consentService.getBedtimeLockout();
    final usage = await ScreenTimeService.instance.getTodayUsageMinutes();
    final bigFeelingsHiddenContext =
        await _consentService.getBigFeelingsParentHiddenContext();
    if (!mounted) {
      return;
    }
    setState(() {
      _allowPhotoAvatar = allowPhoto;
      _dailyLimitMinutes = limit;
      _bedtimeEnabled = bedtimeEnabled;
      _bedtimeHour = bedtime.hour;
      _bedtimeMinute = bedtime.minute;
      _todayUsage = usage;
      _bigFeelingsHiddenContext = bigFeelingsHiddenContext;
      _loading = false;
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
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
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
                    subtitle:
                        'Unlock premium AI illustrations & avatar generation',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ByokSetupWizardScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionHeader(title: 'Screen Time'),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.today, color: Color(0xFFFFD700)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Used today: $_todayUsage min'
                            '${_dailyLimitMinutes != null ? " / $_dailyLimitMinutes min" : ""}',
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Daily limit',
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _dailyLimitMinutes,
                            dropdownColor: const Color(0xFF1E0A3C),
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            items: const [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Unlimited'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 15,
                                child: Text('15 min'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 30,
                                child: Text('30 min'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 45,
                                child: Text('45 min'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 60,
                                child: Text('1 hour'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 90,
                                child: Text('1.5 hours'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 120,
                                child: Text('2 hours'),
                              ),
                            ],
                            onChanged: (v) async {
                              await _consentService.setDailyLimitMinutes(v);
                              if (mounted) {
                                setState(() => _dailyLimitMinutes = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ControlTile(
                    title: 'Bedtime lockout',
                    subtitle: _bedtimeEnabled
                        ? 'App locks at ${_bedtimeHour.toString().padLeft(2, '0')}:${_bedtimeMinute.toString().padLeft(2, '0')}. Tap the time to change it.'
                        : 'When enabled, the app will lock after a set bedtime.',
                    value: _bedtimeEnabled,
                    onChanged: (v) async {
                      await _consentService.setBedtimeLockout(
                        enabled: v,
                        hour: _bedtimeHour,
                        minute: _bedtimeMinute,
                      );
                      if (mounted) {
                        setState(() => _bedtimeEnabled = v);
                      }
                    },
                  ),
                  if (_bedtimeEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: _bedtimeHour,
                              minute: _bedtimeMinute,
                            ),
                          );
                          if (picked == null) {
                            return;
                          }
                          await _consentService.setBedtimeLockout(
                            enabled: true,
                            hour: picked.hour,
                            minute: picked.minute,
                          );
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _bedtimeHour = picked.hour;
                            _bedtimeMinute = picked.minute;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Color(0xFFFFD700),
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Bedtime: ${_bedtimeHour.toString().padLeft(2, '0')}:${_bedtimeMinute.toString().padLeft(2, '0')}',
                                style: GoogleFonts.fredoka(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionHeader(title: 'Big Feelings'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Pick one hidden real-life struggle to quietly guide Big Feelings stories. '
                      'Children will not see this setting directly.',
                      style: GoogleFonts.fredoka(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
                        selected: _bigFeelingsHiddenContext == null,
                        selectedColor: const Color(0xFFFFD76A),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _bigFeelingsHiddenContext == null
                              ? const Color(0xFF1A0E3A)
                              : const Color(0xFF2E2158),
                          fontWeight: _bigFeelingsHiddenContext == null
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        onSelected: (_) async {
                          await _consentService
                              .setBigFeelingsParentHiddenContext(null);
                          if (mounted) {
                            setState(() => _bigFeelingsHiddenContext = null);
                          }
                        },
                      ),
                      for (final option in _bigFeelingsContextOptions)
                        ChoiceChip(
                          key: ValueKey(
                            'parent_big_feelings_context_${option.value}',
                          ),
                          avatar: Text(option.emoji),
                          label: Text(option.label),
                          selected: _bigFeelingsHiddenContext == option.value,
                          selectedColor: const Color(0xFFFFD76A),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _bigFeelingsHiddenContext == option.value
                                ? const Color(0xFF1A0E3A)
                                : const Color(0xFF2E2158),
                            fontWeight:
                                _bigFeelingsHiddenContext == option.value
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                          ),
                          onSelected: (_) async {
                            final nextValue =
                                _bigFeelingsHiddenContext == option.value
                                    ? null
                                    : option.value;
                            await _consentService
                                .setBigFeelingsParentHiddenContext(nextValue);
                            if (mounted) {
                              setState(
                                () => _bigFeelingsHiddenContext = nextValue,
                              );
                            }
                          },
                        ),
                    ],
                  ),
                  if (_bigFeelingsHiddenContext != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_moon_rounded,
                            color: Color(0xFFFFD700),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _bigFeelingsContextOptions
                                      .firstWhere(
                                        (option) =>
                                            option.value ==
                                            _bigFeelingsHiddenContext,
                                      )
                                      .description,
                              style: GoogleFonts.fredoka(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'More parental controls coming soon.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fredoka(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
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
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
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
