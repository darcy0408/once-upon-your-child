import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/widgets/story_generation_progress.dart';
import 'package:story_weaver_app/widgets/user_friendly_error_dialog.dart';

import 'achievements_screen.dart' deferred as achievements_screen;
import 'avatar_models.dart';
import 'character_creation_screen_enhanced.dart';
import 'character_edit_screen_enhanced.dart';
import 'character_evolution.dart';
import 'coloring_book_library_screen.dart';
import 'config/environment.dart';
import 'customizable_avatar_widget.dart';
import 'dialogs/upgrade_prompt_dialog.dart';
import 'feelings_corner_screen.dart';
import 'interactive_story_screen.dart';
import 'saved_stories_screen.dart';
import 'services/isar_service.dart';
import 'services/offline_story_service.dart';
import 'models/local/story_local.dart';
import 'models.dart';
import 'models/achievement.dart';
import 'services/user_identity_service.dart';
import 'services/feature_unlock_service.dart';
import 'models/story_generation_result.dart';
import 'multi_character_screen.dart';
import 'offline_stories_screen.dart';
import 'paywall_dialog.dart';
import 'pre_story_feelings_dialog.dart';
import 'premium_upgrade_screen.dart';
import 'screens/subscription_success_screen.dart';
import 'services/achievement_service.dart';
import 'services/api_service_manager.dart';
import 'services/grace_period_service.dart';
import 'services/grace_period_analytics.dart';
import 'services/progression_service.dart';
import 'services/story_complexity_service.dart';
import 'story_intent_card.dart';
import 'story_result_screen.dart';
import 'subscription_models.dart';
import 'subscription_service.dart';
import 'therapeutic_customization_screen.dart';
import 'therapeutic_models.dart';
import 'widgets/app_bottom_navigation.dart';
import 'settings_screen.dart' deferred as settings_screen;
import 'screens/wizard_story_screen.dart';


class StoryCreatorApp extends StatelessWidget {
  const StoryCreatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Story Creator',
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF2E7D32), // Dark jungle green
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF81C784),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WizardStoryScreen(), // Go directly to wizard
      routes: {
        '/subscription-success': (context) => const SubscriptionSuccessScreen(),
        '/story-home': (context) => const StoryScreen(), // Keep old screen accessible
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  _StoryScreenState createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  List<Character> _characters = [];
  Character? _selectedCharacter;
  final Set<String> _additionalCharacterIds = {};

  String _selectedTheme = 'Adventure';
  String _selectedCompanion = 'None';
  bool _interactiveMode = false;
  bool _isLoading = false;

  // Bottom navigation
  int _selectedTabIndex = 0;
  String? _userId;

  final _subscriptionService = SubscriptionService();
  UserSubscription? _currentSubscription;
  int _remainingStoriesToday = 0;
  TherapeuticStoryCustomization? _therapeuticCustomization;

  bool _rhymeTimeMode = false;
  bool _learningToReadMode = false;
  bool _includeIllustrations = false;
  final _progressionService = ProgressionService();
  int _storiesCreated = 0;
  bool _hasRhymeTime = false;
  bool _magicPulse = false;
  final _achievementService = AchievementService();
  AchievementSummary? _achievementSummary;
  final _random = Random();
  GracePeriodStatus? _gracePeriodStatus;
  bool _loggedGraceBanner = false;

  // Story intent (merged theme + therapeutic customization)
  StoryIntentData? _storyIntent;


  int _currentPhase = 0;
  final int _totalPhases = 3;
  String _funFact = '';

  final List<String> _funFacts = [
    'The world\'s oldest known story is the Epic of Gilgamesh, written over 4,000 years ago!',
    'Reading for just 6 minutes a day can reduce stress by up to 68%.',
    'The word "story" comes from the Latin word "historia," which means "history" or "narrative."',
    'The shortest story ever written is "For sale: baby shoes, never worn."',
    'The human brain is wired for stories. We remember facts 6 to 7 times more easily when they are part of a story.',
  ];

  // Navigation items
  void _onTabTapped(int index) {
    if (_selectedTabIndex == index) {
      return;
    }
    setState(() {
      _selectedTabIndex = index;
    });

    // Handle navigation to different screens
    switch (index) {
      case 0: // Stories - already on this screen
        break;
      case 1: // Characters
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SavedStoriesScreen()),
        ).then((_) => setState(() => _selectedTabIndex = 0));
        break;
      case 2: // Feelings Corner
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FeelingsCornerScreen(
              characterAge: _selectedCharacter?.age,
            ),
          ),
        ).then((_) => setState(() => _selectedTabIndex = 0));
        break;
      case 3: // Settings
        settings_screen.loadLibrary().then((_) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => settings_screen.SettingsScreen()),
            ).then((_) => setState(() => _selectedTabIndex = 0));
          }
        });
        break;
    }
  }


  final List<Map<String, String>> _companions = const [
    {'name': 'None', 'image': 'assets/images/none.png'},
    {'name': 'Loyal Dog', 'image': 'assets/images/dog.png'},
    {'name': 'Mysterious Cat', 'image': 'assets/images/cat.png'},
    {'name': 'Mischievous Fairy', 'image': 'assets/images/fairy.png'},
    {'name': 'Tiny Dragon', 'image': 'assets/images/dragon.png'},
    {'name': 'Wise Owl', 'image': 'assets/images/owl.png'},
    {'name': 'Gallant Horse', 'image': 'assets/images/horse.png'},
    {'name': 'Robot Sidekick', 'image': 'assets/images/robot.png'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadCharacters();
    _loadSubscriptionInfo();
    _loadAchievementSummary();
    _refreshGracePeriodStatus();
    _handleInitialRoute();
  }

  Future<void> _loadUserId() async {
    _userId = await UserIdentityService.getOrCreateUserId();
    setState(() {});
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
    final progress = await _progressionService.getUserProgress();
    final hasRhyme = await _progressionService.hasAccessToFeature(
      UnlockableFeatures.rhymeTimeMode,
    );

    if (!mounted) return;

    setState(() {
      _currentSubscription = subscription;
      _remainingStoriesToday = remaining;
      _storiesCreated = progress.storiesCreated;
      _hasRhymeTime = hasRhyme;
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

  bool get _canUseLearningToReadMode => _selectedCharacter != null;

  Future<void> _openAchievementsScreen() async {
    // Lazy load achievements screen
    await achievements_screen.loadLibrary();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => achievements_screen.AchievementsScreen()),
    );
    await _loadAchievementSummary();
  }

  Future<void> _loadCharacters() async {
    final url = Uri.parse('${Environment.backendUrl}/get-characters');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Accept either: [ ... ]  OR  { "items": [ ... ], "meta": {...} }
        final List list =
            (decoded is List) ? decoded : (decoded['items'] as List);
        final characters =
            list.map((j) => Character.fromJson(j)).toList().cast<Character>();

        setState(() {
          _characters = characters;
          if (_characters.isNotEmpty) {
            final stillExists =
                _characters.any((c) => c.id == _selectedCharacter?.id);
            if (!stillExists) _selectedCharacter = _characters.first;
          } else {
            _selectedCharacter = null;
          }
          if (_selectedCharacter == null) {
            _learningToReadMode = false;
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to load characters (${response.statusCode}).')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching characters.')),
        );
      }
    }
  }

  Future<bool> _validateStoryCreationPreconditions() async {
    if (_selectedCharacter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a character!')),
      );
      return false;
    }

    final canCreate = await _subscriptionService.canCreateStory();
    if (!canCreate) {
      final remaining = await _subscriptionService.getRemainingStoriesToday();
      final remainingMonth =
          await _subscriptionService.getRemainingStoriesThisMonth();
      if (!mounted) return false;

      final upgraded = await PaywallDialog.showStoryLimitDialog(
        context,
        remainingToday: remaining,
        remainingMonth: remainingMonth,
      );
      if (upgraded) {
        await _loadSubscriptionInfo();
      }
      return false;
    }

    if (_additionalCharacterIds.isNotEmpty) {
      final hasMultiChar =
          await _subscriptionService.hasFeature('multi_character_stories');
      if (!hasMultiChar) {
        if (!mounted) return false;
        await PaywallDialog.showFeatureLockedDialog(
          context,
          featureName: 'Multi-Character Stories',
          description: 'Include siblings and friends in stories together!',
        );
        return false;
      }
    }

    final themeAvailable =
        await _subscriptionService.isThemeAvailable(_selectedTheme);
    if (!themeAvailable) {
      if (!mounted) return false;
      await PaywallDialog.showContentLockedDialog(
        context,
        contentType: 'Theme',
        contentName: _selectedTheme,
      );
      return false;
    }

    if (_selectedCompanion != 'None') {
      final companionAvailable =
          await _subscriptionService.isCompanionAvailable(_selectedCompanion);
      if (!companionAvailable) {
        if (!mounted) return false;
        await PaywallDialog.showContentLockedDialog(
          context,
          contentType: 'Companion',
          contentName: _selectedCompanion,
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _createStory({bool guidedByFeeling = false}) async {
    final allowed = await _validateStoryCreationPreconditions();
    if (!allowed) return;

    final gracePeriodStatus = await GracePeriodService.getStatus(
      _currentSubscription?.tier.name ?? 'free',
    );
    if (mounted) {
      setState(() {
        _gracePeriodStatus = gracePeriodStatus;
      });
    }

    if (gracePeriodStatus.shouldShowHardLimit) {
      if (!mounted) return;
      GracePeriodAnalytics.hardLimitReached(
        used: gracePeriodStatus.storiesUsed,
        limit: gracePeriodStatus.storiesLimit,
        accountAgeDays: gracePeriodStatus.accountAgeDays,
      );
      await showDialog(
        context: context,
        builder: (context) => UpgradePromptDialog(
          isSoftPrompt: false,
          storiesUsed: gracePeriodStatus.storiesUsed,
          storiesLimit: gracePeriodStatus.storiesLimit,
          accountAgeDays: gracePeriodStatus.accountAgeDays,
        ),
      );
      return;
    }

    if (gracePeriodStatus.shouldShowSoftPrompt) {
      if (!mounted) return;
      GracePeriodAnalytics.softPromptShown(
        used: gracePeriodStatus.storiesUsed,
        limit: gracePeriodStatus.storiesLimit,
        accountAgeDays: gracePeriodStatus.accountAgeDays,
      );
      unawaited(
        showDialog(
          context: context,
          builder: (context) => UpgradePromptDialog(
            isSoftPrompt: true,
            storiesUsed: gracePeriodStatus.storiesUsed,
            storiesLimit: gracePeriodStatus.storiesLimit,
            accountAgeDays: gracePeriodStatus.accountAgeDays,
            daysRemainingInGracePeriod:
                gracePeriodStatus.daysRemainingInGracePeriod,
          ),
        ),
      );
    }

    // Start loading state
    _startProgress();

    // Get all selected characters
    final List<Character> allSelectedCharacters = [
      _selectedCharacter!,
      ..._characters.where((c) => _additionalCharacterIds.contains(c.id)),
    ];

    // Define story parameters
    final theme = _selectedTheme;
    final mode = _interactiveMode ? 'interactive' : 'standard';
    final prompt = 'Create a story for ${_selectedCharacter!.name} with theme $theme';
    final ageGroup = StoryComplexityService.getAgeGroup(_selectedCharacter!.age).name;

    try {
      if (mounted) {
        setState(() {
          _currentPhase = 0;
          _funFact = _funFacts[_random.nextInt(_funFacts.length)];
        });
      }

      if (mounted) {
        setState(() => _currentPhase = 1);
      }
      // Generate story
      final storyResult = await _generateStory(
        prompt: prompt,
        characterName: _selectedCharacter!.name,
        ageGroup: ageGroup,
        theme: theme,
        mode: mode,
        allCharacters: allSelectedCharacters,
      );

      if (mounted) {
        setState(() => _currentPhase = 2);
      }

      if (!mounted) return;

      // TODO: Consider adding feelings check earlier in the process (before story generation)
      // Removed the post-story feelings popup as it was disruptive to UX

      // Generate title and wisdom gem
      final story = storyResult.storyText;
      final backendTitle = storyResult.title?.trim();
      final backendWisdom = storyResult.wisdomGem?.trim();

      final String title = (backendTitle != null && backendTitle.isNotEmpty)
          ? backendTitle
          : (_additionalCharacterIds.isEmpty
              ? '${_selectedCharacter!.name}\'s $_selectedTheme Adventure'
              : _generateMultiCharacterTitle());

      final String wisdomGem = (backendWisdom != null && backendWisdom.isNotEmpty)
          ? backendWisdom
          : (_additionalCharacterIds.isEmpty
              ? 'Every adventure makes us stronger and wiser.'
              : 'Together, we are stronger than we are alone.');

      final storyTimestamp = DateTime.now();

      // Save the story locally with all characters used
      final saved = SavedStory(
        title: title,
        storyText: story,
        theme: _selectedTheme,
        characters: allSelectedCharacters,
        createdAt: storyTimestamp,
        isInteractive: false,
        wisdomGem: wisdomGem,
      );
      
      // Save to Isar for Library visibility
      final storyLocal = StoryLocal.fromSavedStory(saved);
      await OfflineStoryService(IsarService.instance).saveStory(storyLocal);

      // Update character evolution (no feelings data for now)
      await _updateCharacterEvolution(allSelectedCharacters, _therapeuticCustomization, null);

      // Record story creation for usage tracking
      await _subscriptionService.recordStoryCreation();
      if (_currentSubscription?.tier.name == 'free' || _currentSubscription == null) {
        await GracePeriodService.incrementStoryCount();
      }
      await _loadSubscriptionInfo(); // Refresh remaining count
      unawaited(_refreshGracePeriodStatus());

      // Increment feature unlock counter
      await FeatureUnlockService().incrementStoriesCreated(_userId);

      if (!mounted) return;

    // Navigate to result screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryResultScreen(
          title: title,
            storyText: story,
            wisdomGem: wisdomGem,
            characterName: _selectedCharacter?.name,
            storyId: saved.id,
            theme: _selectedTheme,
            characterId: _selectedCharacter?.id,
            achievementsService: _achievementService,
            storyCreatedAt: storyTimestamp,
            trackStoryCreation: true,
            isInteractive: _interactiveMode,
            isRhyming: _rhymeTimeMode,
            backendIllustrations: storyResult.illustrations,
            subscription: _currentSubscription,
            asyncIllustrations: storyResult.asyncIllustrations,
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Story generation error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        await _showStoryErrorDialog(e);
      }
    } finally {
      _stopProgress();
    }
  }

  Future<void> _startInteractiveStory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final allowed = await _validateStoryCreationPreconditions();
    if (!allowed) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    final bool? storySaved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InteractiveStoryScreen(
          character: _selectedCharacter!,
          theme: _selectedTheme,
          companion: _selectedCompanion != 'None' ? _selectedCompanion : null,
        ),
      ),
    );

    if (storySaved == true) {
      await _loadSubscriptionInfo();
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

  Future<StoryGenerationResult> _generateStory({
    required String prompt,
    required String characterName,
    required String ageGroup,
    required String theme,
    required String mode,
    required List<Character> allCharacters,
  }) async {
    return await ApiServiceManager.generateStory(
      characterName: characterName,
      theme: theme,
      age: _selectedCharacter!.age,
      companion: _selectedCharacter != null && _additionalCharacterIds.isNotEmpty
          ? _additionalCharacterIds.first
          : null,
      characterDetails: {
        'name': _selectedCharacter!.name,
        'age': _selectedCharacter!.age,
        'gender': _selectedCharacter!.gender,
      },
      additionalCharacters: allCharacters.skip(1).map((c) => c.name).toList(),
      rhymeTimeMode: _rhymeTimeMode,
      learningToReadMode: _learningToReadMode,
      includeIllustrations: _includeIllustrations,
      subscriptionTier:
          (_currentSubscription?.tier ?? SubscriptionTier.free).name,
      currentFeeling: null, // Could be added later
    );
  }





  void _startProgress() {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _currentPhase = 0;
        _funFact = _funFacts[_random.nextInt(_funFacts.length)];
      });
    }
  }

  void _stopProgress() {
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showStoryErrorDialog(dynamic error) {
    return showDialog(
      context: context,
      builder: (dialogContext) => UserFriendlyErrorDialog(
        error: error,
        onRetry: () {
          Navigator.of(dialogContext).pop();
          _onCreateButtonPressed(); // Retry the last story creation
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
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
                  color: Colors.white.withOpacity(0.2),
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
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PremiumUpgradeScreen()),
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
                case 'feelings':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FeelingsCornerScreen(
                            characterAge: _selectedCharacter?.age,
                          )));
                  break;
                case 'my_stories':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SavedStoriesScreen()));
                  break;
                case 'group':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MultiCharacterScreen()));
                  break;
                case 'settings':
                  await settings_screen.loadLibrary();
                  if (mounted) {
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
                value: 'feelings',
                child: ListTile(
                  leading: Icon(Icons.favorite),
                  title: Text('Feelings Corner'),
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
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF81C784), // Light green
              const Color(0xFF66BB6A), // Medium green
              const Color(0xFF4CAF50), // Vibrant green
              const Color(0xFFAED581), // Light lime green
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
                        daysRemaining: snapshot.data!.daysRemainingInGracePeriod,
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GracePeriodBanner(
                        daysRemaining: snapshot
                            .data!.daysRemainingInGracePeriod,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Grace Period'),
                              content: Text(snapshot.data!.usageDescription),
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
              _buildSectionCard(
                  'Choose Main Character', _buildCharacterSelector()),
              const SizedBox(height: 20),
              if (_selectedCharacter != null)
                _buildSectionCard('Add Friends/Siblings (Optional)',
                    _buildAdditionalCharactersSelector()),
              if (_selectedCharacter != null &&
                  _additionalCharacterIds.isNotEmpty)
                const SizedBox(height: 20),

              StoryIntentCard(
                initialData: _storyIntent,
                onIntentChanged: (intent) {
                  setState(() {
                    _storyIntent = intent;

                    if (intent.supportFocuses.isNotEmpty ||
                        intent.situation != null ||
                        intent.storyElements.isNotEmpty ||
                        intent.message != null) {

                      final wishes = intent.storyElements.map((e) => StoryWish(
                        description: 'Include $e',
                        type: WishType.other,
                      )).toList();

                      TherapeuticGoal? primaryGoal;
                      for (final goal in TherapeuticGoal.values) {
                        if (intent.supportFocuses.contains(goal.displayName)) {
                          primaryGoal = goal;
                          break;
                        }
                      }

                      _therapeuticCustomization = TherapeuticStoryCustomization(
                        primaryGoal: primaryGoal,
                        wishes: wishes,
                        specificSituation: intent.situation,
                        copingStrategiesToHighlight: intent.supportFocuses,
                        desiredLesson: intent.message,
                      );
                    } else {
                      _therapeuticCustomization = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  title: const Text(
                    'Interactive Story Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Make choices that change the story!',
                  ),
                  value: _interactiveMode,
                  thumbColor: WidgetStateProperty.all<Color>(Colors.purple),
                  secondary: const Icon(Icons.alt_route, color: Colors.purple),
                  onChanged: (value) {
                    setState(() => _interactiveMode = value);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: const Text(
                    'Easy Readers: Learn to Read Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_canUseLearningToReadMode
                      ? '50-100 word rhyming story for early readers (all ages)'
                      : 'Select a character to enable this mode'),
                  value:
                      _canUseLearningToReadMode ? _learningToReadMode : false,
                  thumbColor: WidgetStateProperty.all<Color>(Colors.blue),
                  secondary: const Icon(Icons.menu_book, color: Colors.blue),
                  onChanged: _canUseLearningToReadMode
                      ? (value) {
                          setState(() {
                            _learningToReadMode = value;
                            if (value) {
                              _rhymeTimeMode = false;
                              _includeIllustrations = true;
                            }
                          });
                        }
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: const Text(
                    'Include Illustrations',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _learningToReadMode
                        ? 'Enabled automatically for Learn to Read stories'
                        : 'Generate colorful images with your story',
                  ),
                  value:
                      _learningToReadMode ? true : _includeIllustrations,
                  thumbColor: WidgetStateProperty.all<Color>(Colors.teal),
                  secondary: const Icon(Icons.brush, color: Colors.teal),
                  onChanged: _learningToReadMode
                      ? null
                      : (value) {
                          setState(() {
                            _includeIllustrations = value;
                          });
                        },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text(
                          'Rhyme Time Mode',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_hasRhymeTime) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.lock, size: 18, color: Colors.orange),
                      ],
                    ],
                  ),
                  subtitle: Text(_hasRhymeTime
                      ? 'Silly rhyming stories with playful verses!'
                      : 'Unlock at 0 stories! ($_storiesCreated/0)'),
                  value: _rhymeTimeMode && _hasRhymeTime,
                  thumbColor: WidgetStateProperty.all<Color>(Colors.orange),
                  secondary: const Icon(Icons.music_note, color: Colors.orange),
                  onChanged: _hasRhymeTime ? (value) {
                    setState(() => _rhymeTimeMode = value);
                  } : null,
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                  'Choose a Companion (Optional)', _buildCompanionSelector()),
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PremiumUpgradeScreen(),
                          ),
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
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
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
                    onPressed: (_gracePeriodStatus?.shouldShowHardLimit ?? false)
                        ? null
                        : () {
                            _onCreateButtonPressed();
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: Colors.deepPurpleAccent,
                      shadowColor: Colors.deepPurpleAccent.withOpacity(0.6),
                      elevation: 6,
                    ),
                    label: Text(_interactiveMode
                        ? 'Start Interactive Story'
                        : 'Make Magic'),
                  ),
                ),
                if (!_interactiveMode) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: (_gracePeriodStatus?.shouldShowHardLimit ?? false)
                        ? null
                        : () async {
                            await _createStory(guidedByFeeling: true);
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.deepPurple),
                      foregroundColor: Colors.deepPurple,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Create Story About a Feeling'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Card _buildSectionCard(String title, Widget content) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withOpacity(0.95), // Semi-transparent white
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
                        color: const Color(0xFF81C784).withOpacity(0.5), // Light green border
            width: 2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
                            Colors.white.withOpacity(0.95),
                            const Color(0xFFF1F8E9).withOpacity(0.95), // Very light green tint
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF4CAF50).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🍃', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32), // Dark green text
                      ),
                    ),
                  ),
                  const Text('🌿', style: TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterSelector() {
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: [
        ..._characters.map((c) => _buildCharacterCard(c)),
        _buildAddCharacterCard(),
      ],
    );
  }

  Widget _buildCharacterCard(Character character) {
    final isSelected = _selectedCharacter?.id == character.id;

    return SizedBox(
      width: 104,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedCharacter = character;
                });
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 140, minWidth: 104),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected ? Colors.deepPurple.shade50 : Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    _buildCharacterAvatar(character, size: 64),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        character.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.deepPurple : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: PopupMenuButton<String>(
                tooltip: 'Character options',
                onSelected: (value) {
                  if (value == 'edit') {
                    _editCharacter(character);
                  } else if (value == 'delete') {
                    _deleteCharacter(character.id, character.name);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Character'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.more_vert, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCharacterCard() {
    return GestureDetector(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => const CharacterCreationScreenEnhanced()),
          );
          await _loadCharacters();
          await _loadAchievementSummary();
        },
        child: Container(
          width: 96,
          constraints: const BoxConstraints(minHeight: 130, minWidth: 96),
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors.deepPurple, width: 2, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(12),
            color: Colors.deepPurple.shade50,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 30, color: Colors.deepPurple),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'Add\nCharacter',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
  }

  Widget _buildCharacterAvatar(Character character, {double size = 40}) {
    final avatar = _characterToAvatar(character);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomizableAvatarWidget(
        avatar: avatar,
        size: size - 8,
        customSeed: character.id,
      ),
    );
  }

  CharacterAvatar _characterToAvatar(Character character) {
    if (character.avatar != null) {
      return character.avatar!;
    }

    final skinColor = _mapSkinToneToAvatar(character.skinTone, character.id);
    final hairStyle = _mapHairStyleToAvatar(character.hairstyle);
    final hairColor = _mapHairColorToAvatar(character.hair);
    final clothingStyle = _mapClothingStyle(character.characterStyle);
    final clothingColor = _mapClothingColor(character.characterStyle);
    final eyeType = _mapEmotionToEye(character.currentEmotionCore);
    final mouthType = _mapEmotionToMouth(character.currentEmotionCore);

    return CharacterAvatar(
      skinColor: skinColor,
      hairStyle: hairStyle,
      hairColor: hairColor,
      eyeType: eyeType,
      mouthType: mouthType,
      clothingStyle: clothingStyle,
      clothingColor: clothingColor,
    );
  }

  String _mapSkinToneToAvatar(String? input, String characterId) {
    final tone = input?.toLowerCase().trim() ?? '';
    if (tone.contains('very ') && tone.contains('fair')) return 'Light';
    if (tone.contains('fair')) return 'Pale';
    if (tone.contains('tan') || tone.contains('olive')) return 'Tanned';
    if (tone.contains('yellow') || tone.contains('gold')) return 'Yellow';
    if (tone.contains('dark') && tone.contains('brown')) return 'DarkBrown';
    if (tone.contains('brown')) return 'Brown';
    if (tone.contains('black') || tone.contains('deep')) return 'Black';

    // Avoid randomizing skin tone when data is missing; default to a light neutral base
    return 'Light';
  }

  String _mapHairStyleToAvatar(String? style) {
    final value = style?.toLowerCase().trim() ?? '';
    if (value.contains('braid')) return 'LongHairBraids';
    if (value.contains('ponytail')) return 'LongHairPonytail';
    if (value.contains('bun')) return 'LongHairBun';
    if (value.contains('curly') && value.contains('short')) {
      return 'ShortHairShortCurly';
    }
    if (value.contains('curly')) return 'LongHairCurly';
    if (value.contains('wavy') && value.contains('short')) {
      return 'ShortHairShortWaved';
    }
    if (value.contains('wavy') || value.contains('long')) {
      return 'LongHairStraight';
    }
    if (value.contains('hijab')) return 'Hijab';
    if (value.contains('hat') || value.contains('cap')) return 'Hat';
    return 'ShortHairShortFlat';
  }

  String _mapHairColorToAvatar(String? hair) {
    final value = hair?.toLowerCase() ?? '';
    if (value.contains('platinum')) return 'Platinum';
    if (value.contains('blond')) return 'Blonde';
    if (value.contains('gold')) return 'BlondeGolden';
    if (value.contains('bronze')) return 'Brown';
    if (value.contains('auburn')) return 'Auburn';
    if (value.contains('red') || value.contains('ginger')) return 'Red';
    if (value.contains('pink')) return 'PastelPink';
    if (value.contains('silver') ||
        value.contains('gray') ||
        value.contains('grey')) {
      return 'SilverGray';
    }
    if (value.contains('purple')) return 'PastelPink';
    if (value.contains('blue')) return 'SilverGray';
    if (value.contains('black')) return 'Black';
    if (value.contains('brown')) return 'Brown';
    return 'Brown';
  }

  String _mapClothingStyle(String? style) {
    final value = style?.toLowerCase() ?? '';
    if (value.contains('dress')) return 'BlazerShirt';
    if (value.contains('fancy') || value.contains('formal')) {
      return 'BlazerSweater';
    }
    if (value.contains('sport')) return 'Overall';
    if (value.contains('hoodie') || value.contains('casual')) {
      return 'Hoodie';
    }
    return 'ShirtCrewNeck';
  }

  String _mapClothingColor(String? style) {
    final value = style?.toLowerCase() ?? '';
    if (value.contains('forest') || value.contains('jungle')) {
      return 'Green01';
    }
    if (value.contains('sunset') || value.contains('orange')) {
      return 'PastelOrange';
    }
    if (value.contains('ocean') || value.contains('water')) return 'Blue02';
    if (value.contains('star') || value.contains('bright')) return 'Yellow';
    return 'Blue03';
  }

  String _mapEmotionToEye(String? emotionCore) {
    final value = emotionCore?.toLowerCase() ?? '';
    if (value.contains('joy') || value.contains('happy')) return 'Happy';
    if (value.contains('sad') || value.contains('fear')) return 'Dizzy';
    if (value.contains('surprise')) return 'Surprised';
    if (value.contains('anger')) return 'EyeRoll';
    return 'Default';
  }

  String _mapEmotionToMouth(String? emotionCore) {
    final value = emotionCore?.toLowerCase() ?? '';
    if (value.contains('joy') || value.contains('happy')) return 'Smile';
    if (value.contains('sad') || value.contains('fear')) return 'Concerned';
    if (value.contains('surprise')) return 'Twinkle';
    if (value.contains('anger')) return 'Serious';
    return 'Smile';
  }

  Future<void> _editCharacter(Character character) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CharacterEditScreenEnhanced(character: character),
      ),
    );
    if (mounted) {
      await _loadCharacters();
    }
  }

  Future<void> _deleteCharacter(
      String characterId, String characterName) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Character'),
        content: Text(
            'Are you sure you want to delete $characterName? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Delete from backend
    try {
      final response = await http.delete(
        Uri.parse('${Environment.backendUrl}/characters/$characterId'),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$characterName deleted successfully')),
          );
        }
        // Reload characters
        await _loadCharacters();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete character')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting character')),
        );
      }
    }
  }


  Widget _buildCompanionSelector() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _companions.length,
        itemBuilder: (context, index) {
          final companion = _companions[index];
          final bool isSelected = _selectedCompanion == companion['name'];

          return GestureDetector(
            onTap: () =>
                setState(() => _selectedCompanion = companion['name']!),
            child: Card(
              elevation: isSelected ? 6 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? Colors.deepPurple : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Container(
                width: 120,
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Image.asset(
                        companion['image']!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.pets,
                            size: 40, color: Colors.deepPurple),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      companion['name']!,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _generateMultiCharacterTitle() {
    final others = _characters
        .where((c) => _additionalCharacterIds.contains(c.id))
        .map((c) => c.name)
        .toList();

    if (others.isEmpty) {
      return 'A $_selectedTheme Adventure with ${_selectedCharacter!.name}';
    }

    return 'A $_selectedTheme Adventure with ${_selectedCharacter!.name} & ${others.join(", ")}';
  }

  Widget _buildAdditionalCharactersSelector() {
    final availableCharacters =
        _characters.where((c) => c.id != _selectedCharacter?.id).toList();

    if (availableCharacters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'No other characters available. Create more characters to add friends or siblings!',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: availableCharacters.map((c) {
        final isSelected = _additionalCharacterIds.contains(c.id);
        return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _additionalCharacterIds.remove(c.id);
                } else {
                  _additionalCharacterIds.add(c.id);
                }
              });
            },
            child: Container(
              width: 88,
              constraints: const BoxConstraints(minHeight: 118, minWidth: 88),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.green : Colors.grey.shade300,
                  width: isSelected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? Colors.green.shade50 : Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      _buildCharacterAvatar(c, size: 52),
                      if (isSelected)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      c.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color:
                            isSelected ? Colors.green.shade700 : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
      }).toList(),
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

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withOpacity(0.95),
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
                    color: Colors.amber.withOpacity(0.2),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.emoji_events, color: Colors.amber),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Achievement Journey',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.unlockedCount}/${summary.totalCount} unlocked so far',
                        style: TextStyle(
                          color:
                              Colors.green.shade900.withOpacity(0.75),
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
                backgroundColor: Colors.green.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.green.shade600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$completionPercent% badges unlocked • '
              '$averageProgress% average progress',
              style: TextStyle(
                color: Colors.green.shade900.withOpacity(0.7),
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


  /// Update character evolution based on therapeutic story elements
  Future<void> _updateCharacterEvolution(
    List<Character> characters,
    TherapeuticStoryCustomization? therapeuticCustomization,
    CurrentFeeling? currentFeeling,
  ) async {
    if (therapeuticCustomization == null && currentFeeling == null) return;

    final prefs = await SharedPreferences.getInstance();
    const String evolutionKey = 'character_evolution_data';

    for (final character in characters) {
      try {
        // Get existing evolution data
        final String? existingDataJson = prefs.getString('$evolutionKey-${character.id}');
        CharacterEvolution oldEvolution;
        if (existingDataJson != null) {
          oldEvolution = CharacterEvolution.fromJson(json.decode(existingDataJson));
        } else {
          oldEvolution = CharacterEvolution(
            characterId: character.id,
            therapeuticProgress: {},
            emotionMastery: {},
            milestones: [],
            evolvedTraits: {},
            lastUpdated: DateTime.now(),
          );
        }

        int totalProgressIncrease = 0;
        String milestoneDescription = "Completed a story";
        final newTherapeuticProgress = Map<TherapeuticGoal, int>.from(oldEvolution.therapeuticProgress);
        final newEmotionMastery = Map<String, int>.from(oldEvolution.emotionMastery);
        final newMilestones = List<CharacterMilestone>.from(oldEvolution.milestones);

        // Update based on primary therapeutic goal
        if (therapeuticCustomization?.primaryGoal != null) {
          final goal = therapeuticCustomization!.primaryGoal!;
          final currentProgress = newTherapeuticProgress[goal] ?? 0;
          final progressIncrease = 5;
          newTherapeuticProgress[goal] = (currentProgress + progressIncrease).clamp(0, 100);
          totalProgressIncrease += progressIncrease;
          milestoneDescription += " focusing on ${goal.displayName}";
        }

        // Update based on emotions explored
        if (currentFeeling != null && currentFeeling.selectedFeeling.tertiary.isNotEmpty) {
          final emotionId = currentFeeling.selectedFeeling.tertiary;
          final currentMastery = newEmotionMastery[emotionId] ?? 0;
          final progressIncrease = 3;
          newEmotionMastery[emotionId] = (currentMastery + progressIncrease).clamp(0, 100);
          totalProgressIncrease += progressIncrease;
          milestoneDescription += " exploring the feeling of $emotionId";
        }

        // Additional progress for coping strategies
        if (therapeuticCustomization?.copingStrategiesToHighlight.isNotEmpty ?? false) {
          final progressIncrease = 2;
          totalProgressIncrease += progressIncrease;
          milestoneDescription += " using coping strategies";
          if (therapeuticCustomization!.primaryGoal != null) {
            final goal = therapeuticCustomization.primaryGoal!;
            final currentProgress = newTherapeuticProgress[goal] ?? 0;
            newTherapeuticProgress[goal] = (currentProgress + progressIncrease).clamp(0, 100);
          }
        }

        // Progress for custom therapeutic wishes
        if (therapeuticCustomization?.wishes.isNotEmpty ?? false) {
          final progressIncrease = therapeuticCustomization!.wishes.length;
          totalProgressIncrease += progressIncrease;
          milestoneDescription += " and fulfilling wishes";
           if (therapeuticCustomization.primaryGoal != null) {
            final goal = therapeuticCustomization.primaryGoal!;
            final currentProgress = newTherapeuticProgress[goal] ?? 0;
            newTherapeuticProgress[goal] = (currentProgress + progressIncrease).clamp(0, 100);
          }
        }

        // Add a milestone for this story
        if (totalProgressIncrease > 0) {
          final milestone = CharacterMilestone(
            id: 'story-${DateTime.now().millisecondsSinceEpoch}',
            title: 'New Story Completed!',
            description: milestoneDescription,
            goal: therapeuticCustomization?.primaryGoal,
            emotionId: currentFeeling?.selectedFeeling.tertiary,
            achievedAt: DateTime.now(),
            progressIncrease: totalProgressIncrease,
          );
          newMilestones.add(milestone);
        }

        final newEvolution = CharacterEvolution(
          characterId: oldEvolution.characterId,
          therapeuticProgress: newTherapeuticProgress,
          emotionMastery: newEmotionMastery,
          milestones: newMilestones,
          evolvedTraits: oldEvolution.evolvedTraits, // Not changing traits here
          lastUpdated: DateTime.now(),
        );

        // Save updated evolution data
        await prefs.setString('$evolutionKey-${character.id}', json.encode(newEvolution.toJson()));

      } catch (e) {
        debugPrint('Error updating character evolution: $e');
      }
    }
  }
}
