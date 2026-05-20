import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service_manager.dart';
import '../services/caregiver_service.dart';
import '../services/child_profile_service.dart';
import '../services/parental_consent_service.dart';
import '../services/privacy_service.dart';
import '../services/screen_time_service.dart';
import '../settings_screen.dart';
import '../subscription_screen.dart';
import '../theme/app_theme.dart';
import 'byok_setup_wizard.dart';
import 'wizard_story_screen.dart';

class ParentControlsScreen extends StatefulWidget {
  /// Set [openBigFeelings] to open the Big Feelings section immediately
  /// (e.g. when launched from the onboarding flow right after consent).
  /// Set [skipMathGate] when the caller has already verified the parent
  /// (e.g. immediately after the COPPA consent screen).
  /// Set [isOnboarding] to show a prominent "Start the adventure" button
  /// at the bottom so parents know how to hand the device back to their child.
  const ParentControlsScreen({
    super.key,
    this.openBigFeelings = false,
    this.skipMathGate = false,
    this.isOnboarding = false,
  });

  final bool openBigFeelings;
  final bool skipMathGate;
  final bool isOnboarding;

  @override
  State<ParentControlsScreen> createState() => _ParentControlsScreenState();
}

class _ParentControlsScreenState extends State<ParentControlsScreen> {
  final _consentService = const ParentalConsentService();
  final _api = ApiServiceManager();
  final _mathController = TextEditingController();

  // ── Trigger-centric data model ────────────────────────────────────────────

  static const _copingMeta = <String, ({String label, String emoji})>{
    'dragon breaths': (label: 'Dragon breaths', emoji: '🐉'),
    'a quiet pause': (label: 'Quiet pause', emoji: '🌬️'),
    'asking for help': (label: 'Ask for help', emoji: '🙋'),
    'gentle try-again words': (label: 'Try-again words', emoji: '💬'),
  };

  static const _repairMeta = <String, ({String label, String emoji})>{
    'say sorry simply': (label: 'Say sorry', emoji: '🫶'),
    'help fix what happened': (label: 'Help fix', emoji: '🛠️'),
    'use gentle words': (label: 'Gentle words', emoji: '💬'),
    'try again with warmth': (label: 'Try again', emoji: '🔁'),
  };

  static const _triggerData = <
      ({
        String value,
        String label,
        String emoji,
        String description,
        List<String> defaultCoping,
        List<String> defaultRepair,
      })>[
    (
      value: 'a limit is set',
      label: 'Hearing no',
      emoji: '🚫',
      description:
          'Practice hearing no, calming down, and recovering without a blowup.',
      defaultCoping: ['dragon breaths', 'a quiet pause'],
      defaultRepair: ['try again with warmth'],
    ),
    (
      value: 'a sibling conflict starts',
      label: 'Sibling conflict',
      emoji: '🧒',
      description: 'Sibling friction, sharing space, and calmer re-entry.',
      defaultCoping: ['a quiet pause', 'gentle try-again words'],
      defaultRepair: ['say sorry simply', 'use gentle words'],
    ),
    (
      value: 'a friendship bump happens',
      label: 'Friendship hurt',
      emoji: '💔',
      description: 'Navigate hurt feelings, repair, and reconnecting.',
      defaultCoping: ['asking for help', 'a quiet pause'],
      defaultRepair: ['use gentle words'],
    ),
    (
      value: 'nighttime feels uncertain',
      label: 'Bedtime worry',
      emoji: '🌙',
      description: 'Comfort around nighttime fear and small brave steps.',
      defaultCoping: ['dragon breaths', 'a quiet pause'],
      defaultRepair: ['try again with warmth'],
    ),
    (
      value: 'a transition happens',
      label: 'Hard transitions',
      emoji: '🔄',
      description: 'Smoother switches between activities with less overwhelm.',
      defaultCoping: ['dragon breaths', 'gentle try-again words'],
      defaultRepair: ['try again with warmth'],
    ),
    (
      value: 'meltdown when stuck',
      label: 'Meltdown when stuck',
      emoji: '🧩',
      description: 'Frustration tolerance, help-seeking, and trying again.',
      defaultCoping: ['dragon breaths', 'asking for help'],
      defaultRepair: ['help fix what happened', 'try again with warmth'],
    ),
  ];

  // ── State ─────────────────────────────────────────────────────────────────

  bool _allowPhotoAvatar = false; // CMP-8: fail safe until the real value loads
  bool _hasApiKey = false;
  bool _loading = true;
  bool _deletingData = false;
  bool _exportingData = false;
  bool _analyticsEnabled = false;
  bool _analyticsAgeAllowed = false; // analytics toggle usable only for age >= 13
  int? _dailyLimitMinutes;
  bool _bedtimeEnabled = false;
  int _bedtimeHour = 20;
  int _bedtimeMinute = 0;
  int _todayUsage = 0;
  String? _activeProfileId;
  String? _activeProfileName;

  // Family / Caregivers
  final _caregiverService = CaregiverService();
  CaregiverInfo _caregivers = CaregiverInfo.empty;
  bool _familyExpanded = false;
  final _customCaregiverController = TextEditingController();

  // Big Feelings
  bool _bigFeelingsExpanded = false;
  bool _mathGateUnlocked = false;
  int _mathA = 0;
  int _mathB = 0;
  bool _mathWrong = false;
  Set<String> _selectedTriggers = {};
  Map<String, Set<String>> _copingSelections = {};
  Map<String, Set<String>> _repairSelections = {};
  String? _expandedTrigger;
  Timer? _autoSaveTimer;
  bool _autoSaving = false;

  @override
  void initState() {
    super.initState();
    _generateMathProblem();
    if (widget.openBigFeelings) _bigFeelingsExpanded = true;
    if (widget.skipMathGate) _mathGateUnlocked = true;
    _loadSettings();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _mathController.dispose();
    _customCaregiverController.dispose();
    super.dispose();
  }

  void _generateMathProblem() {
    final rng = Random();
    _mathA = rng.nextInt(6) + 4; // 4–9
    _mathB = rng.nextInt(6) + 4; // 4–9
  }

  Future<void> _loadSettings() async {
    final hasKey = await ApiServiceManager.isUsingOwnApiKey();
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
    if (!mounted) return;

    // Parse saved trigger/coping/repair from comma-separated strings.
    final savedTriggers = _splitSaved(hiddenContext?['trigger']);
    final savedCoping = _splitSaved(hiddenContext?['coping_tool']);
    final savedRepair = _splitSaved(hiddenContext?['repair_goal']);

    // Build per-trigger selections from the saved flat sets.
    final copingSelections = <String, Set<String>>{};
    final repairSelections = <String, Set<String>>{};
    for (final t in _triggerData) {
      if (savedTriggers.contains(t.value)) {
        // Use saved coping/repair if any overlap with this trigger's defaults;
        // fall back to defaults if the saved set is empty.
        final coping = savedCoping.intersection(Set.from(t.defaultCoping));
        copingSelections[t.value] =
            coping.isNotEmpty ? coping : Set.from(t.defaultCoping);
        final repair = savedRepair.intersection(Set.from(t.defaultRepair));
        repairSelections[t.value] =
            repair.isNotEmpty ? repair : Set.from(t.defaultRepair);
      }
    }

    final caregivers = await _caregiverService.load(activeProfileId);
    final recordedAge = await _consentService.getRecordedAge();

    setState(() {
      _hasApiKey = hasKey;
      _allowPhotoAvatar = allowPhoto;
      _dailyLimitMinutes = limit;
      _bedtimeEnabled = bedtimeEnabled;
      _bedtimeHour = bedtime.hour;
      _bedtimeMinute = bedtime.minute;
      _todayUsage = usage;
      _activeProfileId = activeProfileId;
      _activeProfileName = activeProfileName;
      _selectedTriggers = savedTriggers;
      _copingSelections = copingSelections;
      _repairSelections = repairSelections;
      _caregivers = caregivers;
      _analyticsEnabled = PrivacyService.isAnalyticsEnabled;
      // COPPA: analytics is never collected for under-13s — the toggle is
      // disabled for them so a parent cannot enable it.
      _analyticsAgeAllowed = recordedAge != null && recordedAge >= 13;
      _loading = false;
    });
  }

  // ── Family / Caregivers ────────────────────────────────────────────────────

  /// The chip presets shown on the Family panel. "Other..." opens a free-text
  /// field so culturally-specific labels (Tata, Abuela, Yia Yia, etc.) work.
  static const _caregiverPresets = <String>[
    'Mommy', 'Mama', 'Mom', 'Mum',
    'Daddy', 'Dada', 'Papa', 'Pa', 'Dad',
    'Grandma', 'Nana', 'Granny',
    'Grandpa', 'Granddad', 'Pop-Pop',
    'Auntie', 'Uncle',
  ];

  Future<void> _setPrimaryCaregiver(String? value) async {
    final id = _activeProfileId;
    if (id == null) return;
    final next = (value == null || value.trim().isEmpty)
        ? _caregivers.copyWith(clearPrimary: true)
        : _caregivers.copyWith(primary: value.trim());
    await _caregiverService.save(id, next);
    if (!mounted) return;
    setState(() => _caregivers = next);
  }

  Set<String> _splitSaved(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return {};
    return raw.toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
  }

  Future<Map<String, dynamic>?> _loadHiddenContext(String profileId) async {
    try {
      final response =
          await _api.get('/child-profiles/$profileId/parent-hidden-context');
      final data = response['parent_hidden_context'];
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    return null;
  }

  /// Called after any selection change — debounces and auto-saves.
  void _debouncedSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 900), _saveToApi);
  }

  Future<void> _saveToApi() async {
    final profileId = _activeProfileId;
    if (profileId == null || _selectedTriggers.isEmpty) return;

    // Collect all selected coping/repair tools across triggers (union).
    final allCoping = <String>{};
    final allRepair = <String>{};
    for (final trigger in _selectedTriggers) {
      allCoping.addAll(_copingSelections[trigger] ?? {});
      allRepair.addAll(_repairSelections[trigger] ?? {});
    }

    if (!mounted) return;
    setState(() => _autoSaving = true);
    try {
      await _api.put('/child-profiles/$profileId/parent-hidden-context', {
        'trigger': _selectedTriggers.join(', '),
        'coping_tool': allCoping.join(', '),
        'repair_goal': allRepair.join(', '),
      });
    } catch (_) {}
    if (mounted) setState(() => _autoSaving = false);
  }

  String _privacyNote() {
    if (_activeProfileName == null || _activeProfileName!.isEmpty) return '';
    return 'Saved privately for $_activeProfileName only. Your child will never see these choices.';
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
                        'Photos are sent securely to the avatar provider and used only to generate the cartoon image.',
                    value: _allowPhotoAvatar,
                    onChanged: (v) async {
                      await _consentService.setAllowPhotoAvatar(v);
                      if (mounted) setState(() => _allowPhotoAvatar = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionHeader(title: '🔑  Unlock Premium Features — Free'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Connect a free Google Gemini API key to unlock '
                      'premium AI illustrations and personalised avatars. '
                      'Google offers a generous free tier — most families '
                      'never pay a cent, though very heavy use could incur '
                      'small charges on your Google account.',
                      style: GoogleFonts.fredoka(
                          color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  _ActionTile(
                    icon: _hasApiKey
                        ? Icons.check_circle_rounded
                        : Icons.vpn_key_rounded,
                    title: _hasApiKey
                        ? 'API key connected'
                        : 'Connect your free API key',
                    subtitle: _hasApiKey
                        ? 'Tap to update or remove your Gemini key'
                        : 'Takes 2 minutes — unlock premium illustrations & avatars',
                    onTap: () async {
                      final result = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => const ByokSetupWizardScreen(),
                        ),
                      );
                      if (result != null && result.isNotEmpty && context.mounted) {
                        setState(() => _hasApiKey = true);
                        await ProviderScope.containerOf(context)
                            .read(settingsProvider.notifier)
                            .reload();
                      }
                    },
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
                        ? 'App locks at ${_formatBedtime(_bedtimeHour, _bedtimeMinute)}. Tap the time to change it.'
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
                                'Bedtime: ${_formatBedtime(_bedtimeHour, _bedtimeMinute)}',
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
                  _buildFamilySection(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildBigFeelingsSection(),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionHeader(title: 'Subscription'),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E57C2).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF7E57C2).withAlpha(80)),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Subscription',
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Upgrade to Premium for unlimited stories, premium narration, and AI illustrations.',
                          style: GoogleFonts.fredoka(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E57C2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                            label: const Text(
                              'Manage Subscription',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionHeader(title: 'Data & Privacy'),
                  // PP-9: analytics opt-out. Analytics is only ever ON for a
                  // declared age >= 13 with consent — this toggle lets a
                  // parent withdraw at any time (GDPR Art. 7(3)).
                  _ControlTile(
                    title: 'Allow anonymous usage analytics',
                    subtitle:
                        'Helps us improve the app. You can turn this off at '
                        'any time. Analytics is never collected for children '
                        'under 13.',
                    value: _analyticsEnabled,
                    // COPPA: for under-13 the switch is disabled (null) so a
                    // parent cannot enable analytics for a child's account.
                    onChanged: _analyticsAgeAllowed
                        ? (v) async {
                            await PrivacyService.setAnalyticsConsent(v);
                            if (mounted) setState(() => _analyticsEnabled = v);
                          }
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // PP-8: surface the backend data-export endpoint (GDPR
                  // Art. 20 / COPPA right to access).
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download my child\'s data',
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Export a copy of your child\'s profile, characters, '
                          'stories, and consent records as a JSON file you can '
                          'save or share.',
                          style: GoogleFonts.fredoka(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _exportingData ? null : _exportData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7E57C2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _exportingData
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded),
                            label: Text(
                              _exportingData
                                  ? 'Preparing export…'
                                  : 'Download my child\'s data',
                              style: GoogleFonts.fredoka(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withAlpha(80)),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete All My Data',
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Permanently deletes your child\'s stories, characters '
                          'and profile data and anonymizes your account so it can '
                          'no longer be identified. '
                          'You may exercise this right at any time under COPPA.',
                          style: GoogleFonts.fredoka(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _deletingData ? null : _deleteAllData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _deletingData
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Delete All My Data',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (widget.isOnboarding)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Start the adventure →',
                          style: GoogleFonts.fredoka(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
      ),
    );
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
          'This permanently deletes your child\'s stories, characters and '
          'profile data and anonymizes your account so it can no longer be '
          'identified. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingData = true);
    try {
      final userId = await _api.getUserId();
      if (userId != null) {
        await _api.delete('/api/user/$userId/data');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete data: $error')),
      );
    } finally {
      if (mounted) setState(() => _deletingData = false);
    }
  }

  /// PP-8 — surfaces the backend `GET /api/user/<id>/export` endpoint
  /// (GDPR Art. 20 / COPPA right to access). Mirrors the [_deleteAllData]
  /// pattern: resolve the user id, call the backend, then deliver the result.
  /// The export JSON is written to a temp file and handed to the OS share
  /// sheet so the parent can save it anywhere (Files, email, cloud).
  Future<void> _exportData() async {
    setState(() => _exportingData = true);
    try {
      final userId = await _api.getUserId();
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No account found to export.')),
        );
        return;
      }
      final export = await _api.get('/api/user/$userId/export');
      final jsonText =
          const JsonEncoder.withIndent('  ').convert(export);

      if (kIsWeb) {
        // path_provider/share file delivery is unavailable on web — show the
        // export so the parent can still copy it.
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Your data export'),
            content: SingleChildScrollView(
              child: SelectableText(jsonText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/storyweaver_export_${userId.substring(0, userId.length < 8 ? userId.length : 8)}.json',
      );
      await file.writeAsString(jsonText);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Once Upon YOUR Child — my child\'s data export',
          text: 'Your child\'s data export from Once Upon YOUR Child.',
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data export ready to save or share.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export data: $error')),
      );
    } finally {
      if (mounted) setState(() => _exportingData = false);
    }
  }

  /// Formats a 24-hour hour/minute pair as 12-hour AM/PM, e.g. "8:30 PM".
  String _formatBedtime(int hour, int minute) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  // ── Life Quests section (parent-facing trigger config) ──────────────────────

  Widget _buildFamilySection() {
    final hasProfile = _activeProfileId != null;
    final primary = _caregivers.primary;
    final isCustom = primary != null &&
        primary.isNotEmpty &&
        !_caregiverPresets.contains(primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        GestureDetector(
          onTap: () =>
              setState(() => _familyExpanded = !_familyExpanded),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(Icons.family_restroom_rounded,
                    color: Color(0xFFFFD700)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family',
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        hasProfile
                            ? (primary == null || primary.isEmpty
                                ? 'Stories say "your grown-up". Tap to personalise.'
                                : 'Stories will say "$primary".')
                            : 'Create a character first to enable this.',
                        style: GoogleFonts.fredoka(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _familyExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        if (_familyExpanded) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick the name your child uses for their main grown-up. '
                  'Stories will say it instead of "your grown-up". '
                  'Stays on this device — never uploaded.',
                  style: GoogleFonts.fredoka(
                      color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!hasProfile)
                  Text(
                    'Make a character first.',
                    style: GoogleFonts.fredoka(
                        color: Colors.white54, fontSize: 13),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in _caregiverPresets)
                        _CaregiverChip(
                          label: preset,
                          selected: primary == preset,
                          onTap: () => _setPrimaryCaregiver(preset),
                        ),
                      _CaregiverChip(
                        label: 'Other…',
                        selected: isCustom,
                        onTap: () async {
                          final value = await _promptCustomCaregiver(
                            initial: isCustom ? primary : null,
                          );
                          if (value != null) {
                            await _setPrimaryCaregiver(value);
                          }
                        },
                      ),
                    ],
                  ),
                  if (isCustom)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        'Using "$primary".',
                        style: GoogleFonts.fredoka(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  if (primary != null && primary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: TextButton.icon(
                        onPressed: () => _setPrimaryCaregiver(null),
                        icon: const Icon(Icons.close,
                            size: 16, color: Colors.white54),
                        label: Text(
                          'Clear (use "your grown-up")',
                          style: GoogleFonts.fredoka(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<String?> _promptCustomCaregiver({String? initial}) async {
    _customCaregiverController.text = initial ?? '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E0A3C),
        title: Text(
          'Custom name',
          style: GoogleFonts.fredoka(color: Colors.white, fontSize: 18),
        ),
        content: TextField(
          controller: _customCaregiverController,
          autofocus: true,
          maxLength: 24,
          style: GoogleFonts.fredoka(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Tata, Abuela, Yia Yia',
            hintStyle: GoogleFonts.fredoka(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFFD700)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.fredoka(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              final value = _customCaregiverController.text.trim();
              Navigator.of(ctx).pop(value.isEmpty ? null : value);
            },
            child: Text(
              'Use this',
              style: GoogleFonts.fredoka(color: const Color(0xFFFFD700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigFeelingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row (always visible, collapses/expands the section)
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
            child: Row(
              children: [
                const Icon(Icons.shield_moon_rounded,
                    color: Color(0xFFFFD700)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My child could use some help with...',
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_activeProfileId == null)
                        Text(
                          'Create a character first to enable this.',
                          style: GoogleFonts.fredoka(
                              color: Colors.white54, fontSize: 13),
                        )
                      else if (_selectedTriggers.isNotEmpty)
                        Text(
                          '${_selectedTriggers.length} area${_selectedTriggers.length == 1 ? '' : 's'} selected'
                          '${_autoSaving ? ' \u2022 saving...' : ''}',
                          style: GoogleFonts.fredoka(
                              color: Colors.white54, fontSize: 13),
                        )
                      else
                        Text(
                          'Stories will gently work on what you pick.',
                          style: GoogleFonts.fredoka(
                              color: Colors.white54, fontSize: 13),
                        ),
                    ],
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
          ),
        ),

        if (_bigFeelingsExpanded) ...[
          const SizedBox(height: AppSpacing.sm),

          // Gate: no profile
          if (_activeProfileId == null)
            _buildNoProfileState()

          // Gate: math verification
          else if (!_mathGateUnlocked)
            _buildMathGate()

          // Trigger cards
          else
            _buildTriggerCards(),
        ],
      ],
    );
  }

  Future<void> _goToCharacterCreation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WizardStoryScreen(initialStep: 0),
      ),
    );
    if (mounted) _loadSettings();
  }

  Widget _buildNoProfileState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _goToCharacterCreation,
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: Color(0xFFFFD700), size: 36),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No child profile active',
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Start a story to create a character, then return here via the Parent button to shape their stories.',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: _goToCharacterCreation,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFFFFD700), size: 18),
                const SizedBox(width: 6),
                Text(
                  'Create a character',
                  style: GoogleFonts.fredoka(
                    color: const Color(0xFFFFD700),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFFFFD700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMathGate() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Parent verification',
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Solve this to continue (keeps little eyes out).',
            style: GoogleFonts.fredoka(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '$_mathA \u00d7 $_mathB = ',
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _mathController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.fredoka(
                      color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _mathWrong
                            ? Colors.redAccent
                            : Colors.white38,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFFFFD700)),
                    ),
                  ),
                  onSubmitted: (_) => _checkMath(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                onPressed: _checkMath,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD76A),
                  foregroundColor: const Color(0xFF1A0E3A),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 10),
                ),
                child: Text('Unlock',
                    style: GoogleFonts.fredoka(
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (_mathWrong) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Not quite -- try again.',
              style: GoogleFonts.fredoka(
                  color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  void _checkMath() {
    final answer = int.tryParse(_mathController.text.trim());
    if (answer == _mathA * _mathB) {
      setState(() {
        _mathGateUnlocked = true;
        _mathWrong = false;
      });
    } else {
      setState(() => _mathWrong = true);
    }
  }

  Widget _buildTriggerCards() {
    final privacyNote = _privacyNote();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (privacyNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              privacyNote,
              style:
                  GoogleFonts.fredoka(color: Colors.white54, fontSize: 12),
            ),
          ),

        // Trigger cards (multi-select)
        for (final trigger in _triggerData) ...[
          _buildTriggerCard(trigger),
          const SizedBox(height: AppSpacing.sm),
        ],

      ],
    );
  }

  Widget _buildTriggerCard(
      ({
        String value,
        String label,
        String emoji,
        String description,
        List<String> defaultCoping,
        List<String> defaultRepair,
      }) trigger) {
    final isSelected = _selectedTriggers.contains(trigger.value);
    final isExpanded = _expandedTrigger == trigger.value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFFD76A).withAlpha(28)
            : Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFFD76A).withAlpha(120)
              : Colors.white24,
        ),
      ),
      child: Column(
        children: [
          // Card header — tap to select/deselect
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedTriggers.remove(trigger.value);
                  _copingSelections.remove(trigger.value);
                  _repairSelections.remove(trigger.value);
                  if (_expandedTrigger == trigger.value) {
                    _expandedTrigger = null;
                  }
                } else {
                  _selectedTriggers.add(trigger.value);
                  _copingSelections[trigger.value] =
                      Set.from(trigger.defaultCoping);
                  _repairSelections[trigger.value] =
                      Set.from(trigger.defaultRepair);
                  _expandedTrigger = trigger.value;
                }
              });
              _debouncedSave();
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Text(trigger.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trigger.label,
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          trigger.description,
                          style: GoogleFonts.fredoka(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    GestureDetector(
                      onTap: () => setState(
                        () => _expandedTrigger =
                            isExpanded ? null : trigger.value,
                      ),
                      child: Icon(
                        isExpanded
                            ? Icons.expand_less
                            : Icons.tune_rounded,
                        color: const Color(0xFFFFD700),
                        size: 20,
                      ),
                    )
                  else
                    const Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),

          // Expanded coping/repair customisation
          if (isSelected && isExpanded) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stories will practice:',
                    style: GoogleFonts.fredoka(
                        color: const Color(0xFFFFD700), fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildToolChips(
                    allTools: _copingMeta,
                    selected: _copingSelections[trigger.value] ?? {},
                    onToggle: (tool, on) {
                      setState(() {
                        final set = _copingSelections.putIfAbsent(
                            trigger.value, () => {});
                        on ? set.add(tool) : set.remove(tool);
                      });
                      _debouncedSave();
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Working toward:',
                    style: GoogleFonts.fredoka(
                        color: const Color(0xFFFFD700), fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildToolChips(
                    allTools: _repairMeta,
                    selected: _repairSelections[trigger.value] ?? {},
                    onToggle: (tool, on) {
                      setState(() {
                        final set = _repairSelections.putIfAbsent(
                            trigger.value, () => {});
                        on ? set.add(tool) : set.remove(tool);
                      });
                      _debouncedSave();
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolChips({
    required Map<String, ({String label, String emoji})> allTools,
    required Set<String> selected,
    required void Function(String tool, bool on) onToggle,
  }) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final entry in allTools.entries)
          FilterChip(
            label: Text('${entry.value.emoji}  ${entry.value.label}'),
            selected: selected.contains(entry.key),
            onSelected: (on) => onToggle(entry.key, on),
            selectedColor: const Color(0xFFFFD76A).withAlpha(200),
            backgroundColor: Colors.white.withAlpha(18),
            checkmarkColor: const Color(0xFF1A0E3A),
            labelStyle: GoogleFonts.fredoka(
              color: selected.contains(entry.key)
                  ? const Color(0xFF1A0E3A)
                  : Colors.white70,
              fontSize: 13,
            ),
            side: BorderSide(
              color: selected.contains(entry.key)
                  ? const Color(0xFFFFD76A)
                  : Colors.white24,
            ),
          ),
      ],
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
  /// Null disables the switch (e.g. analytics toggle for an under-13 account).
  final ValueChanged<bool>? onChanged;

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

class _CaregiverChip extends StatelessWidget {
  const _CaregiverChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFD700).withAlpha(38)
              : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFFD700) : Colors.white24,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.fredoka(
            color: selected ? const Color(0xFFFFD700) : Colors.white,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
