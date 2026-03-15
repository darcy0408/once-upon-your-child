import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service_manager.dart';
import '../services/child_profile_service.dart';
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
  final _api = ApiServiceManager();
  final _hiddenNoteController = TextEditingController();

  static const _feelingOptions = [
    (
      value: 'frustrated',
      label: 'Frustrated',
      emoji: '😤',
      description: 'Help stories name frustration without shame.',
    ),
    (
      value: 'worried',
      label: 'Worried',
      emoji: '😟',
      description: 'Shape stories around worry, safety, and calm support.',
    ),
    (
      value: 'sad',
      label: 'Sad',
      emoji: '😢',
      description: 'Guide stories toward comfort, connection, and repair.',
    ),
    (
      value: 'angry',
      label: 'Angry',
      emoji: '😠',
      description:
          'Support pause, choice, and warm repair after a tough moment.',
    ),
    (
      value: 'embarrassed',
      label: 'Embarrassed',
      emoji: '🫣',
      description: 'Keep the story gentle around mistakes and recovery.',
    ),
  ];
  static const _triggerOptions = [
    (
      value: 'a limit is set',
      label: 'Hearing no',
      emoji: '🚫',
      description:
          'Use stories to practice hearing no, calming down, and recovering without a blowup.',
    ),
    (
      value: 'a sibling conflict starts',
      label: 'Sibling conflict',
      emoji: '🧒',
      description:
          'Focus stories on sibling friction, shared space, and calmer re-entry.',
    ),
    (
      value: 'a friendship bump happens',
      label: 'Friendship hurt',
      emoji: '💔',
      description:
          'Steer stories toward hurt feelings, repair, and reconnecting with another child.',
    ),
    (
      value: 'nighttime feels uncertain',
      label: 'Bedtime worry',
      emoji: '🌙',
      description:
          'Shape stories around nighttime fear, comfort, and small brave bedtime steps.',
    ),
    (
      value: 'a transition happens',
      label: 'Hard transitions',
      emoji: '🔄',
      description:
          'Support transitions between activities with less resistance, panic, or overwhelm.',
    ),
    (
      value: 'meltdown when stuck',
      label: 'Meltdown when stuck',
      emoji: '🧩',
      description:
          'Use stories to model frustration tolerance, help-seeking, and trying again after getting stuck.',
    ),
  ];
  static const _bodySignalOptions = [
    (
      value: 'a hot face',
      label: 'Hot face',
      emoji: '🥵',
      description: 'Useful when feelings rise fast and show in the face.',
    ),
    (
      value: 'a tight tummy',
      label: 'Tight tummy',
      emoji: '🫶',
      description: 'Helps the story notice body clues before reaction.',
    ),
    (
      value: 'fast feet and hands',
      label: 'Fast body',
      emoji: '🏃',
      description: 'Good for impulsive movement when the feeling surges.',
    ),
    (
      value: 'a quick heartbeat',
      label: 'Fast heart',
      emoji: '💓',
      description: 'Useful for worry, fear, and social stress moments.',
    ),
  ];
  static const _copingToolOptions = [
    (
      value: 'dragon breaths',
      label: 'Dragon breaths',
      emoji: '🐉',
      description: 'Use slow breathing as an early reset tool.',
    ),
    (
      value: 'a quiet pause',
      label: 'Quiet pause',
      emoji: '🌬️',
      description: 'Create a little space before the next choice.',
    ),
    (
      value: 'asking for help',
      label: 'Ask for help',
      emoji: '🙋',
      description: 'Model support-seeking as a strength, not a failure.',
    ),
    (
      value: 'gentle try-again words',
      label: 'Try-again words',
      emoji: '💬',
      description: 'Help the story move from rupture toward repair.',
    ),
  ];
  static const _repairGoalOptions = [
    (
      value: 'say sorry simply',
      label: 'Say sorry',
      emoji: '🫶',
      description:
          'Guides stories toward naming the bump and apologizing simply.',
    ),
    (
      value: 'help fix what happened',
      label: 'Help fix',
      emoji: '🛠️',
      description:
          'Pushes the story toward rebuilding, cleaning up, or making things right.',
    ),
    (
      value: 'use gentle words',
      label: 'Gentle words',
      emoji: '💬',
      description: 'Encourages softer re-entry after yelling or grabbing.',
    ),
    (
      value: 'try again with warmth',
      label: 'Try again',
      emoji: '🔁',
      description:
          'Keeps the repair beat focused on a fresh start without shame.',
    ),
  ];
  bool _allowPhotoAvatar = true;
  bool _loading = true;
  int? _dailyLimitMinutes;
  bool _bedtimeEnabled = false;
  int _bedtimeHour = 20;
  int _bedtimeMinute = 0;
  int _todayUsage = 0;
  String? _activeProfileId;
  String? _activeProfileName;
  bool _bigFeelingsExpanded = false;
  bool _bigFeelingsSaving = false;
  String? _hiddenFeeling;
  String? _hiddenTrigger;
  String? _hiddenBodySignal;
  String? _hiddenCopingTool;
  String? _hiddenRepairGoal;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _hiddenNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final allowPhoto = await _consentService.getAllowPhotoAvatar();
    final limit = await _consentService.getDailyLimitMinutes();
    final bedtimeEnabled = await _consentService.isBedtimeLockoutEnabled();
    final bedtime = await _consentService.getBedtimeLockout();
    final usage = await ScreenTimeService.instance.getTodayUsageMinutes();
    final childProfileService = ChildProfileService();
    final activeProfileId = await childProfileService.getActiveProfileId();
    String? activeProfileName;
    Map<String, dynamic>? hiddenContext;
    if (activeProfileId != null) {
      final profiles = await childProfileService.loadProfiles();
      for (final profile in profiles) {
        if (profile.id == activeProfileId) {
          activeProfileName = profile.name;
          break;
        }
      }
      hiddenContext = await _loadHiddenContext(activeProfileId);
    }
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
      _activeProfileId = activeProfileId;
      _activeProfileName = activeProfileName;
      _hiddenFeeling = hiddenContext?['feeling']?.toString();
      _hiddenTrigger = hiddenContext?['trigger']?.toString();
      _hiddenBodySignal = hiddenContext?['body_signal']?.toString();
      _hiddenCopingTool = hiddenContext?['coping_tool']?.toString();
      _hiddenRepairGoal = hiddenContext?['repair_goal']?.toString();
      _hiddenNoteController.text =
          hiddenContext?['parent_hidden_context']?.toString() ?? '';
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _loadHiddenContext(String profileId) async {
    try {
      final response =
          await _api.get('/child-profiles/$profileId/parent-hidden-context');
      final data = response['parent_hidden_context'];
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  bool get _canSaveBigFeelings =>
      _activeProfileId != null &&
      _hiddenFeeling != null &&
      _hiddenTrigger != null &&
      _hiddenBodySignal != null &&
      _hiddenCopingTool != null &&
      _hiddenRepairGoal != null;

  Future<void> _saveBigFeelingsGuidance() async {
    final profileId = _activeProfileId;
    if (!_canSaveBigFeelings || profileId == null) {
      return;
    }
    setState(() => _bigFeelingsSaving = true);
    try {
      await _api.put('/child-profiles/$profileId/parent-hidden-context', {
        'feeling': _hiddenFeeling,
        'trigger': _hiddenTrigger,
        'body_signal': _hiddenBodySignal,
        'coping_tool': _hiddenCopingTool,
        'repair_goal': _hiddenRepairGoal,
        'parent_hidden_context': _hiddenNoteController.text.trim(),
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Big Feelings guidance saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save guidance: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _bigFeelingsSaving = false);
      }
    }
  }

  String _profileLabel() {
    if (_activeProfileName == null || _activeProfileName!.isEmpty) {
      return 'No active child profile selected.';
    }
    return 'Saved privately for $_activeProfileName only. Your child will never see these notes directly.';
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
                  const _SectionHeader(title: 'Big Feelings Guidance'),
                  GestureDetector(
                    onTap: () => setState(
                      () => _bigFeelingsExpanded = !_bigFeelingsExpanded,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.shield_moon_rounded,
                                color: Color(0xFFFFD700),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Shape the story quietly',
                                  style: GoogleFonts.fredoka(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                _bigFeelingsExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _profileLabel(),
                            style: GoogleFonts.fredoka(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          if (_bigFeelingsExpanded) ...[
                            const SizedBox(height: AppSpacing.md),
                            _buildChoiceGroup(
                              title: 'Feeling',
                              options: _feelingOptions,
                              selectedValue: _hiddenFeeling,
                              onSelected: (value) =>
                                  setState(() => _hiddenFeeling = value),
                            ),
                            _buildChoiceGroup(
                              title: 'Trigger',
                              options: _triggerOptions,
                              selectedValue: _hiddenTrigger,
                              onSelected: (value) =>
                                  setState(() => _hiddenTrigger = value),
                            ),
                            _buildChoiceGroup(
                              title: 'Body signal',
                              options: _bodySignalOptions,
                              selectedValue: _hiddenBodySignal,
                              onSelected: (value) =>
                                  setState(() => _hiddenBodySignal = value),
                            ),
                            _buildChoiceGroup(
                              title: 'Coping tool',
                              options: _copingToolOptions,
                              selectedValue: _hiddenCopingTool,
                              onSelected: (value) =>
                                  setState(() => _hiddenCopingTool = value),
                            ),
                            _buildChoiceGroup(
                              title: 'Repair goal',
                              options: _repairGoalOptions,
                              selectedValue: _hiddenRepairGoal,
                              onSelected: (value) =>
                                  setState(() => _hiddenRepairGoal = value),
                            ),
                            TextField(
                              controller: _hiddenNoteController,
                              maxLength: 280,
                              style: GoogleFonts.fredoka(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Optional private note',
                                labelStyle:
                                    GoogleFonts.fredoka(color: Colors.white70),
                                hintText:
                                    'Keep this general and free of names or other identifying details.',
                                hintStyle:
                                    GoogleFonts.fredoka(color: Colors.white38),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    _bigFeelingsSaving || !_canSaveBigFeelings
                                        ? null
                                        : _saveBigFeelingsGuidance,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD76A),
                                  foregroundColor: const Color(0xFF1A0E3A),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md,
                                  ),
                                ),
                                child: _bigFeelingsSaving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF1A0E3A),
                                        ),
                                      )
                                    : Text(
                                        'Save Big Feelings Guidance',
                                        style: GoogleFonts.fredoka(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
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

  Widget _buildChoiceGroup({
    required String title,
    required List<
            ({String value, String label, String emoji, String description})>
        options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    ({
      String value,
      String label,
      String emoji,
      String description
    })? selectedOption;
    for (final option in options) {
      if (option.value == selectedValue) {
        selectedOption = option;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.fredoka(
              color: const Color(0xFFFFD700),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in options)
                ChoiceChip(
                  key: ValueKey('${title}_${option.value}'),
                  avatar: Text(option.emoji),
                  label: Text(option.label),
                  selected: selectedValue == option.value,
                  selectedColor: const Color(0xFFFFD76A),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selectedValue == option.value
                        ? const Color(0xFF1A0E3A)
                        : const Color(0xFF2E2158),
                    fontWeight: selectedValue == option.value
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  onSelected: (_) => onSelected(option.value),
                ),
            ],
          ),
          if (selectedOption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              selectedOption.description,
              style: GoogleFonts.fredoka(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
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
