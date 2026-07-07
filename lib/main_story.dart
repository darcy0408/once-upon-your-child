import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/config/environment.dart';
import 'package:story_weaver_app/providers/age_band_provider.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/widgets/story_generation_progress.dart';

import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/wizard_story_screen.dart';
import 'screens/wizard_steps/superhero_entry_screen.dart';
import 'screens/parental_consent_screen.dart';
import 'services/parental_consent_service.dart';
import 'services/superhero_portrait_store.dart';
import 'providers/hero_profile_provider.dart';

import 'achievements_screen.dart' deferred as achievements_screen;
import 'coloring_book_library_screen.dart';
import 'dialogs/upgrade_prompt_dialog.dart';
import 'saved_stories_screen.dart';
import 'story_result_screen.dart';
import 'screens/chronicles_list_screen.dart';
import 'services/isar_service.dart';
import 'services/offline_story_service.dart';
import 'models/local/story_local.dart';
import 'models.dart';
import 'models/achievement.dart';
import 'services/user_identity_service.dart';
import 'multi_character_screen.dart';
import 'offline_stories_screen.dart';
import 'utils/paywall_gate.dart';
import 'premium_upgrade_screen.dart';
import 'screens/subscription_success_screen.dart';
import 'services/achievement_service.dart';
import 'services/api_service_manager.dart';
import 'services/grace_period_service.dart';
import 'services/grace_period_analytics.dart';
import 'subscription_models.dart';
import 'services/subscription_service.dart';
import 'widgets/app_bottom_navigation.dart';
import 'widgets/bedtime_launch_sheet.dart';
import 'services/caregiver_service.dart';
import 'services/child_profile_service.dart';
import 'widgets/child_profile_switcher.dart';
import 'settings_screen.dart' deferred as settings_screen;
import 'screens/life_quest_screen.dart';
import 'screens/adult_meditation_screen.dart';
import 'screens/dev/loading_preview_screen.dart';
import 'widgets/safe_asset_image.dart';
// welcome_screen and wizard_story_screen imported at top of file

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class StoryCreatorApp extends ConsumerWidget {
  const StoryCreatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the current age band — drives the entire visual theme.
    final ageBandTheme = ref.watch(ageBandNotifierProvider);

    return MaterialApp(
      title: Environment.appName,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light(ageBand: ageBandTheme),
      darkTheme: ageBandTheme.preferDarkMode
          ? AppTheme.light(ageBand: ageBandTheme)
          : null,
      home: const _AppEntryPoint(),
      routes: {
        '/subscription-success': (context) => const SubscriptionSuccessScreen(),
        '/story-home': (context) =>
            const StoryScreen(), // Keep old screen accessible
        '/dev/loading-preview': (context) => const LoadingPreviewScreen(),
      },
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Flavor banner disabled — not useful for daily development
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

/// Checks whether onboarding (name + age) is complete and routes accordingly.
/// - First launch: shows [WelcomeScreen]
/// - Returning user: shows [WizardStoryScreen] with name pre-filled
class _AppEntryPoint extends ConsumerStatefulWidget {
  const _AppEntryPoint();

  @override
  ConsumerState<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends ConsumerState<_AppEntryPoint> {
  bool _splashDone = false;
  bool? _onboardingDone; // null = still checking
  bool _needsReConsent = false;
  int _reConsentAge = 0;
  String _savedName = '';
  int? _savedAge;
  List<Character> _savedCharacters = const [];

  // Privacy policy was updated 2026-05-19 (rebrand: "Once Upon a Time" →
  // "Once Upon YOUR Child"; aligned with the canonical brand). Any consent
  // before this date must be refreshed so parents see the new brand and
  // updated data-transparency language.
  static final _reConsentCutoff = DateTime(2026, 5, 19);

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    const service = ParentalConsentService();
    final age = await service.getRecordedAge();
    final prefs = await SharedPreferences.getInstance();
    final savedName = (prefs.getString('user_name') ?? '').trim();

    // For children (under 13), check if their consent predates the last
    // privacy policy update and needs to be refreshed.
    bool reConsent = false;
    if (age != null && age < 13) {
      reConsent = await service.needsReConsent(cutoff: _reConsentCutoff);
      if (reConsent) await service.clearConsent();
    }

    final onboardingDone = age != null && savedName.isNotEmpty && !reConsent;
    // Pre-load saved characters before showing the wizard so HeroCreatorStep's
    // initState can pick the "Welcome back" page synchronously when any exist.
    final characters =
        onboardingDone ? await _preloadSavedCharacters() : const <Character>[];

    if (!mounted) return;
    setState(() {
      _onboardingDone = onboardingDone;
      _savedName = savedName;
      _savedAge = age;
      _needsReConsent = reConsent;
      _reConsentAge = age ?? 0;
      _savedCharacters = characters;
    });
  }

  /// Try the backend, fall back to local Isar (which is SharedPreferences-backed
  /// on web). On API success, mirror the result into local storage so future
  /// refreshes have an offline-friendly snapshot to fall back to.
  Future<List<Character>> _preloadSavedCharacters() async {
    try {
      final api = ApiServiceManager();
      final response = await api.get('/get-characters');
      final List<dynamic> list = response['data'] is List
          ? response['data'] as List<dynamic>
          : (response['characters'] as List<dynamic>? ??
              response['items'] as List<dynamic>? ??
              const []);
      try {
        await IsarService.syncCharactersFromApi(list);
      } catch (_) {
        // Best-effort sync — ignore failures.
      }
      return list
          .map((j) => Character.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      try {
        return await IsarService.getAllCharacters();
      } catch (_) {
        return const [];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show branded splash logo on first launch
    if (!_splashDone) {
      return SplashScreen(
        onComplete: () => setState(() => _splashDone = true),
      );
    }

    // Still reading prefs — minimal loading indicator
    if (_onboardingDone == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF120226),
        body: Center(
          child: Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 48),
        ),
      );
    }

    // Privacy policy updated — returning child users need parent re-consent
    if (_needsReConsent) {
      return Scaffold(
        backgroundColor: const Color(0xFF120226),
        body: SafeArea(
          child: ParentalConsentScreen(
            consentService: const ParentalConsentService(),
            declaredAge: _reConsentAge,
          ),
        ),
      );
    }

    // Onboarding complete — launch the wizard with name & age pre-filled.
    // Propagating the recorded user_age into WizardData ensures the Sprout
    // (age-band) auto-save gate on the story-result screen fires correctly.
    if (_onboardingDone!) {
      final wizardData = WizardData()..characterName = _savedName;
      if (_savedAge != null) {
        wizardData.characterAge = _savedAge!;
      }
      return WizardStoryScreen(
        initialWizardData: wizardData,
        availableCharacters: _savedCharacters,
      );
    }

    // First launch — show welcome screen
    return WelcomeScreen(onComplete: _checkOnboarding);
  }
}

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  static const _quickThemes = [
    {'id': 'vanishing_colors', 'emoji': '🌈', 'label': 'Rainbow Land'},
    {'id': 'crystal_cavern', 'emoji': '💎', 'label': 'Crystal Cave'},
    {'id': 'big_feelings_quest', 'emoji': '🧭', 'label': 'Life Quest'},
    {'id': 'doorway_seasons', 'emoji': '🚪', 'label': 'Magic Door'},
    {'id': 'starship_engineers', 'emoji': '🚀', 'label': 'Space Quest'},
    {'id': 'safe_space', 'emoji': '✨', 'label': 'Surprise Me'},
  ];

  List<ChildProfile> _childProfiles = [];
  String? _activeProfileId;

  List<Character> _characters = [];
  Character? _selectedCharacter;

  // Saved stories, newest-first. Powers the "Continue your story" home card
  // and the Continue/New choice when a character with a recent story is tapped.
  List<StoryLocal> _savedStories = [];

  final bool _interactiveMode = false;
  final bool _isLoading = false;

  // Bottom navigation
  int _selectedTabIndex = 0;
  String? _userId;

  final _subscriptionService = SubscriptionService();
  UserSubscription? _currentSubscription;
  int _remainingStoriesToday = 0;

  final bool _magicPulse = false;
  final _achievementService = AchievementService();
  AchievementSummary? _achievementSummary;
  GracePeriodStatus? _gracePeriodStatus;
  bool _loggedGraceBanner = false;

  final int _currentPhase = 0;
  final int _totalPhases = 3;
  final String _funFact = '';

  // Navigation items
  void _onTabTapped(int index) {
    if (_selectedTabIndex == index) {
      return;
    }
    setState(() {
      _selectedTabIndex = index;
    });

    // Tab layout is now symmetric across all bands:
    //   Adult:  0=Stories, 1=Reflect,   2=Library, 3=Settings
    //   Others: 0=Stories, 1=Feelings,  2=Library, 3=Settings
    final age = _selectedCharacter?.age ?? 8;
    final isAdult = ageBandFromAge(age) == AgeBand.adult;

    const int feelingsIdx = 1; // Reflect for adults, Feelings for others
    const int libraryIdx = 2;
    const int settingsIdx = 3;

    // Handle navigation to different screens
    if (index == 0) {
      // Stories - already on this screen
    } else if (index == feelingsIdx) {
      if (isAdult) {
        Navigator.of(context)
            .push(MaterialPageRoute(
              builder: (_) => const AdultMeditationScreen(),
            ))
            .then((_) => setState(() => _selectedTabIndex = 0));
      } else {
        final charName = _selectedCharacter?.name ?? 'You';
        final charGender = _selectedCharacter?.gender ?? '';
        () async {
          final activeId = await ChildProfileService().getActiveProfileId();
          final grownup =
              await CaregiverService().grownupLabelOrDefault(activeId);
          if (!mounted) return;
          Navigator.of(context)
              .push(MaterialPageRoute(
                builder: (_) => LifeQuestScreen(
                  childAge: age,
                  childName: charName,
                  pronoun: charGender == 'Girl'
                      ? 'she'
                      : charGender == 'Boy'
                          ? 'he'
                          : 'they',
                  pronounCap: charGender == 'Girl'
                      ? 'She'
                      : charGender == 'Boy'
                          ? 'He'
                          : 'They',
                  possessive: charGender == 'Girl'
                      ? 'her'
                      : charGender == 'Boy'
                          ? 'his'
                          : 'their',
                  grownup: grownup,
                ),
              ))
              .then((_) => setState(() => _selectedTabIndex = 0));
        }();
      }
    } else if (index == libraryIdx) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(builder: (_) => const SavedStoriesScreen()),
          )
          .then((_) => setState(() => _selectedTabIndex = 0));
    } else if (index == settingsIdx) {
      settings_screen.loadLibrary().then((_) {
        if (mounted) {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                    builder: (_) => settings_screen.SettingsScreen()),
              )
              .then((_) => setState(() => _selectedTabIndex = 0));
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadProfiles();
    _loadCharacters();
    _loadSavedStories();
    _loadSubscriptionInfo();
    _loadAchievementSummary();
    _refreshGracePeriodStatus();
    _handleInitialRoute();
  }

  Future<void> _loadUserId() async {
    _userId = await UserIdentityService.getOrCreateUserId();
    setState(() {});
  }

  Future<void> _loadProfiles() async {
    final service = ChildProfileService();
    final profiles = await service.loadProfiles();
    final activeId = await service.getActiveProfileId();
    if (mounted) {
      setState(() {
        _childProfiles = profiles;
        _activeProfileId = activeId;
      });
    }
  }

  void _handleInitialRoute() {
    // Handle Stripe success URL routing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      if (uri.fragment == '/subscription-success') {
        Navigator.of(context).pushNamed('/subscription-success');
      }
    });
  }

  Future<void> _loadSubscriptionInfo() async {
    final subscription = await _subscriptionService.getSubscription();
    final remaining = await _subscriptionService.getRemainingStoriesToday();

    if (!mounted) return;

    setState(() {
      _currentSubscription = subscription;
      _remainingStoriesToday = remaining;
    });
    unawaited(_refreshGracePeriodStatus());
  }

  Future<void> _refreshGracePeriodStatus() async {
    final status = await GracePeriodService.getStatus(
      _currentSubscription?.tier.name ?? 'free',
    );
    if (mounted) {
      setState(() {
        _gracePeriodStatus = status;
      });
    }
  }

  Future<void> _loadAchievementSummary() async {
    try {
      final summary = await _achievementService.getSummary();
      if (!mounted) return;
      setState(() {
        _achievementSummary = summary;
      });
    } catch (_) {
      // If achievements fail to load, leave the summary unchanged.
    }
  }

  Future<void> _openAchievementsScreen() async {
    // Lazy load achievements screen
    await achievements_screen.loadLibrary();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => achievements_screen.AchievementsScreen()),
    );
    await _loadAchievementSummary();
  }

  Future<void> _loadCharacters() async {
    try {
      final api = ApiServiceManager();
      final response = await api.get('/get-characters');
      // Accept either: [ ... ]  OR  { "items": [ ... ], "meta": {...} }
      final List<dynamic> list = response['data'] is List
          ? response['data'] as List<dynamic>
          : (response['items'] as List<dynamic>? ?? const []);
      final characters = list
          .map((j) => Character.fromJson(j as Map<String, dynamic>))
          .toList()
          .cast<Character>();

      // Sync characters to local storage for offline access
      try {
        await IsarService.syncCharactersFromApi(list);
      } catch (e) {
        debugPrint('Failed to sync characters to local storage: $e');
      }

      setState(() {
        _characters = characters;
        if (_characters.isNotEmpty) {
          final stillExists =
              _characters.any((c) => c.id == _selectedCharacter?.id);
          if (!stillExists) _selectedCharacter = _characters.first;
        } else {
          _selectedCharacter = null;
        }
        if (_selectedCharacter == null) {/* no-op */}
      });
      return;
    } catch (e) {
      // Network error - fallback to local storage
      debugPrint('API error, falling back to local storage: $e');
      await _loadCharactersFromLocal();
      if (mounted && _characters.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Offline mode - showing saved characters.')),
        );
      }
    }
  }

  /// Load characters from local Isar storage (fallback for offline mode)
  Future<void> _loadCharactersFromLocal() async {
    try {
      final characters = await IsarService.getAllCharacters();

      if (characters.isNotEmpty) {
        setState(() {
          _characters = characters;
          if (_characters.isNotEmpty) {
            final stillExists =
                _characters.any((c) => c.id == _selectedCharacter?.id);
            if (!stillExists) _selectedCharacter = _characters.first;
          } else {
            _selectedCharacter = null;
          }
          if (_selectedCharacter == null) {/* no-op */}
        });
        debugPrint('Loaded ${characters.length} characters from local storage');
      }
    } catch (e) {
      debugPrint('Failed to load characters from local storage: $e');
    }
  }

  /// Home "create" CTA label, calibrated per age band so older readers aren't
  /// addressed with the young-band "Make Magic" wording (Adventurer audit A-006).
  String _homeCtaLabel(AgeBand? band) {
    switch (band) {
      case AgeBand.adventurer:
        return 'Start the Adventure';
      case AgeBand.creator:
      case AgeBand.adolescent:
      case AgeBand.adult:
        return 'Start Story';
      default:
        return 'Make Magic';
    }
  }

  Future<void> _onCreateButtonPressed() async {
    if (_isLoading) return;

    // Navigate to the new Wizard Story Screen
    // This replaces the old legacy quick story flow
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WizardStoryScreen(
          initialCharacter: _selectedCharacter,
          availableCharacters: _characters,
        ),
      ),
    );

    // If wizard returns success or a new character, refresh
    if (result == true || result != null) {
      if (mounted) {
        await _loadCharacters();
        await _loadSubscriptionInfo(); // Refresh limits
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Story Creator',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_currentSubscription != null &&
                _currentSubscription!.isPremium) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentSubscription!.tier.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _currentSubscription!.tier.icon,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentSubscription!.tier.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Stories remaining indicator
          if (_currentSubscription != null &&
              !_currentSubscription!.limits.unlimitedStories)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_stories, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$_remainingStoriesToday left today',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Premium button for free users
          if (_currentSubscription != null && _currentSubscription!.isFree)
            IconButton(
              tooltip: 'Upgrade to Premium',
              icon: const Icon(Icons.star, color: Colors.amber),
              onPressed: () async {
                await showPaywallGated(
                  context: context,
                  showActualPaywall: () async {
                    if (context.mounted) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PremiumUpgradeScreen()),
                      );
                    }
                    return null;
                  },
                );
                await _loadSubscriptionInfo();
              },
            ),
          // Menu for other options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) async {
              switch (value) {
                case 'achievements':
                  _openAchievementsScreen();
                  break;
                case 'offline':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const OfflineStoriesScreen()));
                  break;
                case 'coloring':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ColoringBookLibraryScreen()));
                  break;
                case 'my_stories':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SavedStoriesScreen()));
                  break;
                case 'my_chronicles':
                  if (_selectedCharacter == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Select a character first to view Chronicles.')),
                    );
                  } else if (_selectedCharacter!.age < 11) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Living Chronicles are for readers aged 11 and up.')),
                    );
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChroniclesListScreen(
                              character: _selectedCharacter!,
                              userId: _userId ?? '',
                            )));
                  }
                  break;
                case 'group':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MultiCharacterScreen()));
                  break;
                case 'settings':
                  await settings_screen.loadLibrary();
                  if (context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => settings_screen.SettingsScreen()));
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'achievements',
                child: ListTile(
                  leading: Icon(Icons.emoji_events),
                  title: Text('Achievements'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'offline',
                child: ListTile(
                  leading: Icon(Icons.offline_pin),
                  title: Text('Offline Stories'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'coloring',
                child: ListTile(
                  leading: Icon(Icons.palette),
                  title: Text('Coloring Book'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'my_stories',
                child: ListTile(
                  leading: Icon(Icons.book),
                  title: Text('My Stories'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'my_chronicles',
                child: ListTile(
                  leading: Icon(Icons.menu_book),
                  title: Text('My Chronicles'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'group',
                child: ListTile(
                  leading: Icon(Icons.groups),
                  title: Text('Group Story'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: _onTabTapped,
        userId: _userId,
        childAge: _selectedCharacter?.age ?? 8,
      ),
      body: Builder(
        builder: (context) {
          final band =
              Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  band.gradientStart,
                  band.gradientMid,
                  band.gradientEnd,
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<GracePeriodStatus>(
                    future: GracePeriodService.getStatus(
                        _currentSubscription?.tier.name ?? 'free'),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isInGracePeriod) {
                        if (!_loggedGraceBanner) {
                          _loggedGraceBanner = true;
                          GracePeriodAnalytics.bannerViewed(
                            daysRemaining:
                                snapshot.data!.daysRemainingInGracePeriod,
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GracePeriodBanner(
                            daysRemaining:
                                snapshot.data!.daysRemainingInGracePeriod,
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Grace Period'),
                                  content:
                                      Text(snapshot.data!.usageDescription),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                      child: const Text('Got it'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  if (_achievementSummary != null) ...[
                    _buildAchievementsOverviewCard(),
                    const SizedBox(height: 20),
                  ],
                  _buildSELPacksSection(),
                  const SizedBox(height: 20),
                  if (_childProfiles.length >= 2) ...[
                    _buildProfileSwitcher(),
                    const SizedBox(height: 16),
                  ],
                  _buildCharacterPortraitRow(),
                  _buildJumpBackInRow(),
                  if (_selectedCharacter != null)
                    _ContinueAsHeroChip(character: _selectedCharacter!),
                  const SizedBox(height: 40),
                  if ((_gracePeriodStatus?.shouldShowHardLimit ?? false))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        elevation: 1,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.red.shade50,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            showPaywallGated(
                              context: context,
                              showActualPaywall: () async {
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PremiumUpgradeScreen(),
                                    ),
                                  );
                                }
                                return null;
                              },
                            );
                          },
                          child: ListTile(
                            leading: const Icon(Icons.lock, color: Colors.red),
                            title: const Text(
                              'Story limit reached',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'You\'ve hit this month\'s free limit. Tap to upgrade and keep creating stories.',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  if (_isLoading) ...[
                    StoryGenerationProgress(
                      currentPhase: _currentPhase,
                      totalPhases: _totalPhases,
                      funFact: _funFact,
                    ),
                  ] else ...[
                    AnimatedScale(
                      duration: const Duration(milliseconds: 160),
                      scale: _magicPulse ? 1.05 : 1.0,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome),
                        onPressed:
                            (_gracePeriodStatus?.shouldShowHardLimit ?? false)
                                ? null
                                : () {
                                    _onCreateButtonPressed();
                                  },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 18),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: Theme.of(context)
                                  .extension<AgeBandThemeData>()
                                  ?.primary ??
                              Colors.deepPurpleAccent,
                          shadowColor: (Theme.of(context)
                                      .extension<AgeBandThemeData>()
                                      ?.primary ??
                                  Colors.deepPurpleAccent)
                              .withValues(alpha: 0.6),
                          elevation: 6,
                        ),
                        label: Text(_interactiveMode
                            ? 'Start Interactive Story'
                            : _homeCtaLabel(Theme.of(context)
                                .extension<AgeBandThemeData>()
                                ?.band)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Audio-only / bedtime entry — screen-free story without
                    // the visual wizard. Works with no character selected:
                    // BedtimeWizardScreen asks the age by voice when it's 0.
                    Semantics(
                      button: true,
                      label: band.band.isMature
                          ? 'Voice story, audio only'
                          : 'Bedtime story, no screen, just listening',
                      child: OutlinedButton.icon(
                        icon: Icon(band.band.isMature
                            ? Icons.mic_none_rounded
                            : Icons.bedtime_outlined),
                        onPressed: () => showBedtimeLaunchSheet(
                          context,
                          childName: _selectedCharacter?.name ?? '',
                          childAge: _selectedCharacter?.age ?? 0,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 18),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        label: Text(band.band.isMature
                            ? 'Voice Story — audio only'
                            : 'Bedtime Story 🌙 — no screen, just listening'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Renders the child profile switcher row when 2+ profiles exist.
  Widget _buildProfileSwitcher() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Switch profile',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ),
        ChildProfileSwitcher(
          profiles: _childProfiles,
          activeProfileId: _activeProfileId,
          onProfileSelected: (profile) async {
            final service = ChildProfileService();
            await service.setActiveProfile(profile);
            setState(() => _activeProfileId = profile.id);
          },
          onAddProfile: () {
            Navigator.pushNamed(context, '/manage-profiles')
                .then((_) => _loadProfiles());
          },
        ),
      ],
    );
  }

  Future<void> _loadSavedStories() async {
    try {
      final service = OfflineStoryService(IsarService.instance);
      final stories = await service.getAllStories();
      if (mounted) setState(() => _savedStories = stories);
    } catch (_) {
      // Non-fatal: the Continue affordances simply won't appear.
    }
  }

  /// Newest recent saved story featuring [character], matched by name (saved
  /// stories don't reliably carry a character id).
  StoryLocal? _recentStoryForCharacter(Character character) {
    final target = character.name.trim().toLowerCase();
    if (target.isEmpty) return null;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    for (final story in _savedStories) {
      if (story.createdAt.isBefore(cutoff)) continue;
      final match =
          story.characters.any((c) => c.name.trim().toLowerCase() == target);
      if (match) return story;
    }
    return null;
  }

  /// Tapping a character no longer silently launches a fresh wizard. If the
  /// child has a recent story with this hero, offer Continue vs. New first.
  void _onCharacterTapped(Character character) {
    setState(() => _selectedCharacter = character);
    final recent = _recentStoryForCharacter(character);
    if (recent != null) {
      _showContinueOrNewSheet(character, recent);
    } else {
      _startNewStoryWith(character);
    }
  }

  void _startNewStoryWith(Character character) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WizardStoryScreen(
          initialCharacter: character,
          availableCharacters: _characters,
        ),
      ),
    ).then((_) {
      _loadCharacters();
      _loadSubscriptionInfo();
      _loadSavedStories();
    });
  }

  void _openSavedStory(StoryLocal story) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryResultScreen(
          title: story.title,
          storyText: story.storyText,
          characterName:
              story.characters.isNotEmpty ? story.characters.first.name : null,
          storyId: story.identifier,
          persistedCoverImageBase64: story.coverImageBase64,
          persistedPageIllustrationsJson: story.pageIllustrationsJson,
          practicedFocus: story.practiced,
          // Disclose at the band of the child this story was written for, even
          // if a different profile is active now.
          practicedAge:
              story.characters.isNotEmpty ? story.characters.first.age : null,
        ),
      ),
    ).then((_) => _loadSavedStories());
  }

  /// "Jump back in" shelf for mature bands (Creator / Adolescent / Adult):
  /// a horizontal row of the most recent saved stories so a returning user
  /// can resume without digging into the Library tab. Hidden when there are
  /// no saved stories. Younger bands rely on the per-hero Continue sheet.
  Widget _buildJumpBackInRow() {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    if (band == null || !band.band.isMature || _savedStories.isEmpty) {
      return const SizedBox.shrink();
    }
    final recent = _savedStories.take(8).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Jump back in',
              style: TextStyle(
                color: band.textOnDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: band.uiFontFamily,
              ),
            ),
          ),
          SizedBox(
            height: 152,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _jumpBackCard(recent[i], band),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jumpBackCard(StoryLocal story, AgeBandThemeData band) {
    ImageProvider? cover;
    final raw = story.coverImageBase64;
    if (raw != null && raw.isNotEmpty) {
      try {
        final normalized = raw.contains(',') ? raw.split(',').last : raw;
        cover = MemoryImage(base64Decode(normalized));
      } catch (_) {
        cover = null;
      }
    }
    return GestureDetector(
      onTap: () => _openSavedStory(story),
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: band.surface,
                  image: cover != null
                      ? DecorationImage(image: cover, fit: BoxFit.cover)
                      : null,
                ),
                child: cover == null
                    ? Icon(Icons.auto_stories, color: band.accent, size: 34)
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              story.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: band.textOnDark,
                fontSize: 12,
                height: 1.2,
                fontFamily: band.uiFontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContinueOrNewSheet(Character character, StoryLocal recent) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "${character.name}'s stories",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _sheetChoice(
                icon: Icons.menu_book_rounded,
                color: const Color(0xFF6C3FC7),
                title: 'Continue',
                subtitle: recent.title,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openSavedStory(recent);
                },
              ),
              _sheetChoice(
                icon: Icons.auto_awesome,
                color: const Color(0xFFFF8A00),
                title: 'Start a new story',
                subtitle: 'Make a brand-new adventure',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _startNewStoryWith(character);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetChoice({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// A one-tap card to jump back into the most recent story — so a child who
  /// clicked away from a story isn't stranded.
  /// Renders character portrait cards horizontally.Tapping a card opens the
  /// wizard with that character pre-loaded for a one-tap story.
  Widget _buildCharacterPortraitRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            _characters.isEmpty
                ? 'Create your first hero!'
                : 'Choose your hero',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              // Existing character cards
              ..._characters.map((character) => _CharacterPortraitCard(
                    character: character,
                    isSelected: _selectedCharacter?.id == character.id,
                    onTap: () => _onCharacterTapped(character),
                    onQuickPlay: () => _showQuickStartSheet(character),
                  )),
              // "New Hero" card at the end
              _NewHeroCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const WizardStoryScreen(initialStep: 0),
                    ),
                  ).then((_) => _loadCharacters());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // SEL Story Pack data
  static const List<Map<String, dynamic>> _selPacks = [
    {
      'emoji': '🤝',
      'title': 'Making Friends',
      'subtitle': 'Reach out & connect',
      'lifeChallenge': 'Making New Friends',
      'color': 0xFF7C4DFF,
    },
    {
      'emoji': '😤',
      'title': 'Unfairness',
      'subtitle': 'When things feel wrong',
      'lifeChallenge': 'Handling Big Feelings',
      'color': 0xFFFF6D00,
    },
    {
      'emoji': '🌱',
      'title': 'New Beginnings',
      'subtitle': 'Starting something new',
      'lifeChallenge': 'Dealing with Change',
      'color': 0xFF2E7D32,
    },
    {
      'emoji': '💛',
      'title': 'Life Quest',
      'subtitle': 'Handle what life throws at you',
      'lifeChallenge': 'Handling Big Feelings',
      'color': 0xFFF9A825,
    },
    {
      'emoji': '🦸',
      'title': 'Standing Up',
      'subtitle': 'Courage & confidence',
      'lifeChallenge': 'Building Confidence',
      'color': 0xFF1565C0,
    },
    {
      'emoji': '🏠',
      'title': 'Family',
      'subtitle': 'Together & apart',
      'lifeChallenge': 'Sibling Rivalry',
      'color': 0xFFAD1457,
    },
  ];

  Widget _buildSELPacksSection() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isSprout = band.band == AgeBand.sprout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            '📚 Story Packs',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [
                const Shadow(
                    color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: _selPacks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final pack = _selPacks[index];
              final color = Color(pack['color'] as int);
              return GestureDetector(
                onTap: () {
                  final seed = WizardData()
                    ..lifeChallenge = pack['lifeChallenge'] as String;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WizardStoryScreen(
                        initialWizardData: seed,
                        availableCharacters: _characters,
                      ),
                    ),
                  ).then((_) => _loadCharacters());
                },
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(pack['emoji'] as String,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        (isSprout && pack['title'] == 'Life Quest')
                            ? 'Big Feelings'
                            : pack['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsOverviewCard() {
    final summary = _achievementSummary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    final completionPercent =
        (summary.completionPercent * 100).clamp(0, 100).toStringAsFixed(0);
    final averageProgress =
        (summary.averageProgress * 100).clamp(0, 100).toStringAsFixed(0);

    // Theme the card accents from the active band so it doesn't read as a
    // generic green/white widget on the band-coloured home (A-008). Adventurer
    // and older bands get a "Mission Log / rank" framing instead of the
    // younger "Achievement Journey".
    final band = Theme.of(context).extension<AgeBandThemeData>();
    final accent = band?.primary ?? const Color(0xFF2E7D32);
    final fill = band?.accent ?? Colors.green.shade600;
    final olderFraming =
        band != null && (band.band == AgeBand.adventurer || band.band.isMature);
    final headerTitle = olderFraming ? 'Mission Log' : 'Achievement Journey';

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withValues(alpha: 0.2),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.emoji_events, color: Colors.amber),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.unlockedCount}/${summary.totalCount} unlocked so far',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                if (summary.newCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${summary.newCount} NEW',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: summary.completionPercent.clamp(0.0, 1.0),
                backgroundColor: accent.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(fill),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$completionPercent% badges unlocked • '
              '$averageProgress% average progress',
              style: TextStyle(
                color: accent.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openAchievementsScreen,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View Achievements'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickStartSheet(Character character) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [band.gradientStart, band.gradientEnd],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '✨ Quick Adventure for ${character.name}!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: band.uiFontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Pick a world and go!',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontFamily: band.uiFontFamily,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: _quickThemes.map((theme) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _launchQuickStory(character, theme['id']!);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(band.buttonRadiusBase),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(theme['emoji']!,
                            style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 4),
                        Text(
                          theme['label']!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: band.uiFontFamily,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _launchQuickStory(Character character, String scenarioId) {
    final data = WizardData()
      ..characterId = character.id
      ..characterName = character.name
      ..characterGender = character.gender ?? 'Hero'
      ..characterAge = character.age
      ..selectedScenario = scenarioId
      ..storyLength = 'standard'
      ..includeIllustrations = true;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WizardStoryScreen(
          initialCharacter: character,
          initialWizardData: data,
          initialStep: 1,
          availableCharacters: _characters,
        ),
      ),
    ).then((_) {
      _loadCharacters();
      _loadSubscriptionInfo();
    });
  }
}

// ── Character Portrait Card ────────────────────────────────────────────────

class _CharacterPortraitCard extends StatelessWidget {
  final Character character;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onQuickPlay;

  const _CharacterPortraitCard({
    required this.character,
    required this.isSelected,
    required this.onTap,
    this.onQuickPlay,
  });

  @override
  Widget build(BuildContext context) {
    // Drive the card palette from the active band instead of hard-coded purple
    // so Adventurer (indigo/teal) and the other bands stay visually coherent
    // with the rest of the home screen (A-007).
    final band = Theme.of(context).extension<AgeBandThemeData>();
    final gradStart = band?.primary ?? const Color(0xFF6B3FA0);
    final gradEnd = band?.primaryDark ?? const Color(0xFF3D1166);
    final accent = band?.accent ?? const Color(0xFFFFD700);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 130,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradStart, gradEnd],
              ),
              border: Border.all(
                color: isSelected ? accent : Colors.white24,
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? accent.withAlpha(80)
                      : Colors.black.withAlpha(60),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                // Avatar circle
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? accent : Colors.white30,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(child: _AvatarImage(character: character)),
                ),
                const SizedBox(height: 10),
                // Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    character.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                // Age / role badge
                Text(
                  'Age ${character.age}${character.role.isNotEmpty ? ' · ${character.role}' : ''}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // CTA
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? accent : Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '✨ Adventure',
                    style: TextStyle(
                      color: isSelected ? Colors.black87 : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // ⚡ Quick Play button overlay
          if (onQuickPlay != null)
            Positioned(
              bottom: 8,
              right: 20,
              child: GestureDetector(
                onTap: onQuickPlay,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  final Character character;
  const _AvatarImage({required this.character});

  @override
  Widget build(BuildContext context) {
    final generated = character.generatedAvatar;
    if (generated != null && generated.imageBase64.isNotEmpty) {
      final data = generated.imageBase64;
      if (data.startsWith('assets/')) {
        return SafeAssetImage(data, fit: BoxFit.cover);
      }
      if (data.startsWith('http')) {
        return Image.network(data,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
      }
      try {
        return Image.memory(base64Decode(data.split(',').last),
            fit: BoxFit.cover);
      } catch (_) {}
    }
    if (character.avatar != null) {
      return Image.network(
        character.avatar!.toAvataaarsUrl(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final initials =
        character.name.isNotEmpty ? character.name[0].toUpperCase() : '?';
    return Container(
      color: const Color(0xFF3D1166),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _NewHeroCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewHeroCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withAlpha(20),
          border: Border.all(color: Colors.white38, width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white70, size: 40),
            SizedBox(height: 10),
            Text(
              'New Hero',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Continue-as-hero chip (Superhero Mode D2) ──────────────────────────────
//
// A modest secondary affordance that appears beneath the character row ONLY
// when the active child (a) is in the Explorer (6-8) or Adventurer (9-12)
// band — the only bands with Superhero Mode — AND (b) has a saved superhero
// portrait from a previous session. Tapping it re-enters the existing
// superhero flow via [SuperheroEntryScreen], which routes returning kids to
// the welcome-back screen.
//
// Fail-soft: any missing portrait/profile (or a non-superhero band) renders
// nothing — the chip simply doesn't appear. Built as a small private widget
// so it's trivial to remove if rejected in owner home-screen review.
class _ContinueAsHeroChip extends ConsumerWidget {
  final Character character;

  const _ContinueAsHeroChip({required this.character});

  /// Builds the minimal [WizardData] the superhero flow needs, mirroring the
  /// fields [_launchQuickStory] sets so [SuperheroEntryScreen.resolveCharacterId]
  /// derives the same storage key the portrait/profile was saved under.
  WizardData _wizardDataFor(Character character) => WizardData()
    ..characterId = character.id
    ..characterName = character.name
    ..characterGender = character.gender ?? 'Hero'
    ..characterAge = character.age;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only Explorer (6-8) and Adventurer (9-12) have Superhero Mode.
    final band = ageBandFromAge(character.age);
    if (band != AgeBand.explorer && band != AgeBand.adventurer) {
      return const SizedBox.shrink();
    }

    final wizardData = _wizardDataFor(character);
    final characterId = SuperheroEntryScreen.resolveCharacterId(wizardData);

    return FutureBuilder<String?>(
      future: SuperheroPortraitStore.load(characterId),
      builder: (context, portraitSnap) {
        final portrait = portraitSnap.data;
        // No saved portrait → no chip (also covers the still-loading frame,
        // so nothing flashes in before we know there's a hero to continue).
        if (portrait == null || portrait.isEmpty) {
          return const SizedBox.shrink();
        }

        // Prefer the saved hero name; fall back to a generic label so the
        // chip still works if only the portrait persisted.
        final profile = ref.watch(heroProfileProvider(characterId)).valueOrNull;
        final heroName = (profile?.heroName ?? '').trim();
        final label = heroName.isNotEmpty
            ? 'Continue as $heroName'
            : 'Continue as your superhero';

        final bandTheme = Theme.of(context).extension<AgeBandThemeData>();
        final accent = bandTheme?.primary ?? Colors.deepPurpleAccent;

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SuperheroEntryScreen(
                          wizardData: _wizardDataFor(character)),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeroChipThumb(portrait: portrait, accent: accent),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '🦸 $label',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right,
                          size: 20, color: Colors.white.withAlpha(180)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small circular thumbnail of the saved superhero portrait (a data URI).
/// Falls back to a hero glyph if the data URI can't be decoded.
class _HeroChipThumb extends StatelessWidget {
  final String portrait;
  final Color accent;

  const _HeroChipThumb({required this.portrait, required this.accent});

  @override
  Widget build(BuildContext context) {
    const double size = 36;
    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.35),
          ),
          alignment: Alignment.center,
          child: const Text('🦸', style: TextStyle(fontSize: 18)),
        );

    final commaIdx = portrait.indexOf(',');
    if (!portrait.startsWith('data:') || commaIdx < 0) {
      return fallback();
    }
    try {
      final bytes = base64Decode(portrait.substring(commaIdx + 1));
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    } catch (_) {
      return fallback();
    }
  }
}
