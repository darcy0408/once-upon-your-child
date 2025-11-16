import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'storage_service.dart';
import 'story_result_screen.dart';
import 'saved_stories_screen.dart';
import 'models.dart';
import 'multi_character_screen.dart';
import 'character_creation_screen_enhanced.dart';
import 'character_edit_screen_enhanced.dart';
import 'subscription_service.dart';
import 'subscription_models.dart';
import 'paywall_dialog.dart';
import 'premium_upgrade_screen.dart';
import 'interactive_story_screen.dart';
import 'therapeutic_customization_screen.dart';
import 'therapeutic_models.dart';
import 'character_evolution.dart';
import 'story_intent_card.dart';
import 'offline_stories_screen.dart';
import 'coloring_book_library_screen.dart';
import 'emotions_screen.dart';
import 'customizable_avatar_widget.dart';
import 'avatar_models.dart';
import 'settings_screen.dart';
import 'services/api_service_manager.dart';
import 'services/progression_service.dart';
import 'achievements_screen.dart';
import 'models/achievement.dart';
import 'services/achievement_service.dart';
import 'pre_story_feelings_dialog.dart';
import 'config/environment.dart';


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
      home: const StoryScreen(),
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

  final _subscriptionService = SubscriptionService();
  UserSubscription? _currentSubscription;
  int _remainingStoriesToday = 0;
  TherapeuticStoryCustomization? _therapeuticCustomization;

  bool _rhymeTimeMode = false;
  bool _learningToReadMode = false;
  final _progressionService = ProgressionService();
  int _storiesCreated = 0;
  bool _hasRhymeTime = false;
  final _achievementService = AchievementService();
  AchievementSummary? _achievementSummary;

  // Story intent (merged theme + therapeutic customization)
  StoryIntentData? _storyIntent;

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
    _loadCharacters();
    _loadSubscriptionInfo();
    _loadAchievementSummary();
  }

  Future<void> _loadSubscriptionInfo() async {
    final subscription = await _subscriptionService.getSubscription();
    final remaining = await _subscriptionService.getRemainingStoriesToday();
    final progress = await _progressionService.getUserProgress();
    final hasRhyme = await _progressionService.hasAccessToFeature(
      UnlockableFeatures.rhymeTimeMode,
    );

    if (mounted) {
      setState(() {
        _currentSubscription = subscription;
        _remainingStoriesToday = remaining;
        _storiesCreated = progress.storiesCreated;
        _hasRhymeTime = hasRhyme;
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

  bool get _canUseLearningToReadMode {
    final age = _selectedCharacter?.age;
    if (age == null) return false;
    return _isLearningToReadAge(age);
  }

  bool _isLearningToReadAge(int age) => age >= 4 && age <= 7;

  Future<void> _openAchievementsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AchievementsScreen()),
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
          if (_selectedCharacter == null ||
              !_isLearningToReadAge(_selectedCharacter!.age)) {
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
    final navContext = context;

    if (_selectedCharacter == null) {
      ScaffoldMessenger.of(navContext).showSnackBar(
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
        navContext,
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
          navContext,
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
        navContext,
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
          navContext,
          contentType: 'Companion',
          contentName: _selectedCompanion,
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _createStory() async {
    final navContext = context;
    final allowed = await _validateStoryCreationPreconditions();
    if (!allowed) return;

    if (_learningToReadMode && !_canUseLearningToReadMode) {
      if (!mounted) return;
      ScaffoldMessenger.of(navContext).showSnackBar(
        const SnackBar(
          content: Text('Learning to Read Mode is only available for ages 4-7.'),
        ),
      );
      setState(() => _learningToReadMode = false);
      return;
    }

    // SHOW FEELINGS CHECK-IN DIALOG (skippable)
    final CurrentFeeling? currentFeeling = await PreStoryFeelingsDialog.show(
      context: navContext,
      characterName: _selectedCharacter!.name,
    );

    // Get all selected characters
    final List<Character> allSelectedCharacters = [
      _selectedCharacter!,
      ..._characters.where((c) => _additionalCharacterIds.contains(c.id)),
    ];

    setState(() => _isLoading = true);

    try {
      // Prepare character details
      final characterDetails = {
        'fears': _selectedCharacter!.fears,
        'strengths': _selectedCharacter!.strengths,
        'likes': _selectedCharacter!.likes,
        'dislikes': _selectedCharacter!.dislikes,
        'comfort_item': _selectedCharacter!.comfortItem ?? '',
        'personality_traits': _selectedCharacter!.personalityTraits,
        'personality_sliders': _selectedCharacter!.personalitySliders,
      };

      // Generate additional character names list if any
      final List<String>? additionalCharacterNames =
          _additionalCharacterIds.isEmpty
              ? null
              : _characters
                  .where((c) => _additionalCharacterIds.contains(c.id))
                  .map((c) => c.name)
                  .toList();

      // Prepare current feeling data for API (can be null if skipped)
      final Map<String, dynamic>? currentFeelingData =
          currentFeeling?.toJson();

      // Record emotion check-in if provided
            if (currentFeeling != null) {
            }
      // Use ApiServiceManager to generate story (handles backend vs direct API)
      final String storyText = await ApiServiceManager.generateStory(
        characterName: _selectedCharacter!.name,
        theme: _selectedTheme,
        age: _selectedCharacter!.age,
        companion: _selectedCompanion,
        characterDetails: characterDetails,
        additionalCharacters: additionalCharacterNames,
        rhymeTimeMode: _rhymeTimeMode,
        learningToReadMode: _learningToReadMode,
        currentFeeling: currentFeelingData,
      );

      if (!navContext.mounted) return;

      // Generate title and wisdom gem
      final String title = _additionalCharacterIds.isEmpty
          ? '${_selectedCharacter!.name}\'s ${_selectedTheme} Adventure'
          : _generateMultiCharacterTitle();

      final String wisdomGem = _additionalCharacterIds.isEmpty
          ? 'Every adventure makes us stronger and wiser.'
          : 'Together, we are stronger than we are alone.';

      final storyTimestamp = DateTime.now();

      // Save the story locally with all characters used
      final saved = SavedStory(
        title: title,
        storyText: storyText,
        theme: _selectedTheme,
        characters: allSelectedCharacters,
        createdAt: storyTimestamp,
        isInteractive: false,
        wisdomGem: wisdomGem,
      );
      await StorageService().saveStory(saved);

      // Update character evolution based on therapeutic elements
      await _updateCharacterEvolution(allSelectedCharacters, _therapeuticCustomization);

      // Record story creation for usage tracking
      await _subscriptionService.recordStoryCreation();
      await _loadSubscriptionInfo(); // Refresh remaining count

      if (!navContext.mounted) return;

      // Navigate to result screen
      await Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => StoryResultScreen(
            title: title,
            storyText: storyText,
            wisdomGem: wisdomGem,
            characterName: _selectedCharacter?.name,
            storyId: saved.id,
            theme: _selectedTheme,
            characterId: _selectedCharacter?.id,
            achievementsService: _achievementService,
            storyCreatedAt: storyTimestamp,
            trackStoryCreation: true,
          ),
        ),
      );
      if (mounted) {
        await _loadAchievementSummary();
      }
    } catch (e, stackTrace) {
      print('Story generation error: $e');
      print(stackTrace);
      final message = _storyGenerationErrorMessage(e);
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    if (_interactiveMode) {
      await _startInteractiveStory();
    } else {
      await _createStory();
    }
  }

  String _storyGenerationErrorMessage(Object error) {
    if (error is SocketException) {
      return 'Check your internet connection and try again.';
    } else if (error is TimeoutException) {
      return 'This is taking longer than usual. Try again?';
    } else if (error is HttpException) {
      return 'Our story engine is taking a break. Try again soon!';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final newAchievementCount = _achievementSummary?.newCount ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Story Creator'),
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
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PremiumUpgradeScreen()),
                );
                await _loadSubscriptionInfo();
              },
            ),
          // Achievements
          IconButton(
            tooltip: 'Achievements',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.emoji_events),
                if (newAchievementCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$newAchievementCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _openAchievementsScreen,
          ),
          // Offline Stories
          IconButton(
            tooltip: 'Offline Stories',
            icon: const Icon(Icons.offline_pin),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OfflineStoriesScreen()),
              );
            },
          ),
          // Coloring Book
          IconButton(
            tooltip: 'Coloring Book',
            icon: const Icon(Icons.palette),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ColoringBookLibraryScreen()),
              );
            },
          ),
          // Feelings Helper
          IconButton(
            tooltip: 'Feelings Helper',
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EmotionsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'My stories',
            icon: const Icon(Icons.book),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedStoriesScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Group Story',
            icon: const Icon(Icons.groups),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MultiCharacterScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
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
              // Story Intent Card (merged theme + support focus)
              StoryIntentCard(
                initialData: _storyIntent,
                onIntentChanged: (intent) {
                  setState(() {
                    _storyIntent = intent;
                    // Update theme for backward compatibility with API
                    if (intent.narrativeStyle != null) {
                      _selectedTheme = intent.narrativeStyle!;
                    }
                    // Convert support focuses to therapeutic customization if present
                    if (intent.supportFocuses.isNotEmpty ||
                        intent.situation != null ||
                        intent.desiredOutcome != null ||
                        intent.message != null) {
                      // Combine situation and desired outcome
                      String? fullSituation;
                      if (intent.situation != null &&
                          intent.desiredOutcome != null) {
                        fullSituation =
                            '${intent.situation}\n\nDesired outcome: ${intent.desiredOutcome}';
                      } else {
                        fullSituation =
                            intent.situation ?? intent.desiredOutcome;
                      }

                      _therapeuticCustomization = TherapeuticStoryCustomization(
                        primaryGoal: null,
                        wishes: const [],
                        specificSituation: fullSituation,
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
                  activeColor: Colors.purple,
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
                    'Learning to Read Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_canUseLearningToReadMode
                      ? '50-100 word rhyming story for early readers (ages 4-7)'
                      : _selectedCharacter == null
                          ? 'Select a character (ages 4-7) to enable this mode'
                          : 'Only available when the character is ages 4-7.'),
                  value: _learningToReadMode && _canUseLearningToReadMode,
                  activeColor: Colors.blue,
                  secondary: const Icon(Icons.menu_book, color: Colors.blue),
                  onChanged: _canUseLearningToReadMode
                      ? (value) {
                          setState(() {
                            _learningToReadMode = value;
                            if (value) {
                              _rhymeTimeMode = false;
                            }
                          });
                        }
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: Row(
                    children: [
                      const Text('Rhyme Time Mode', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  activeColor: Colors.orange,
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
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () async {
                        await _onCreateButtonPressed();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      child: Text(_interactiveMode
                          ? 'Start Interactive Story'
                          : 'Create My Story!'),
                    ),
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
      color: Colors.white.withValues(alpha: 0.95), // Semi-transparent white
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF81C784)
                .withValues(alpha: 0.5), // Light green border
            width: 2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              const Color(0xFFF1F8E9)
                  .withValues(alpha: 0.95), // Very light green tint
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
                          const Color(0xFF4CAF50).withValues(alpha: 0.2),
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
      width: 92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedCharacter = character;
                if (!_isLearningToReadAge(character.age)) {
                  _learningToReadMode = false;
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                  width: isSelected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? Colors.deepPurple.shade50 : Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  _buildCharacterAvatar(character, size: 56),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      character.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.deepPurple : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
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
        width: 80,
        decoration: BoxDecoration(
          border: Border.all(
              color: Colors.deepPurple, width: 2, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
          color: Colors.deepPurple.shade50,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 30, color: Colors.deepPurple),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Add\nCharacter',
                style: TextStyle(
                    fontSize: 11,
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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomizableAvatarWidget(
        avatar: avatar,
        size: size - 8,
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

    const fallback = [
      'Light',
      'Pale',
      'Tanned',
      'Yellow',
      'Brown',
      'DarkBrown',
      'Black'
    ];
    final index = characterId.hashCode.abs() % fallback.length;
    return fallback[index];
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
    if (value.contains('auburn')) return 'Auburn';
    if (value.contains('red') || value.contains('ginger')) return 'Red';
    if (value.contains('pink')) return 'PastelPink';
    if (value.contains('silver') ||
        value.contains('gray') ||
        value.contains('grey')) return 'SilverGray';
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
    if (value.contains('forest') || value.contains('jungle')) return 'Green01';
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

  Widget _buildThemeSelector() {
    final themes = [
      'Adventure',
      'Friendship',
      'Magic',
      'Dragons',
      'Castles',
      'Unicorns',
      'Space',
      'Ocean'
    ];
    return Wrap(
      spacing: 8.0,
      children: themes
          .map((theme) => ChoiceChip(
                label: Text(theme),
                selected: _selectedTheme == theme,
                onSelected: (isSelected) {
                  setState(() {
                    if (isSelected) _selectedTheme = theme;
                  });
                },
              ))
          .toList(),
    );
  }

  Widget _buildCompanionSelector() {
    return SizedBox(
      height: 120,
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
                width: 110,
                padding: const EdgeInsets.all(8.0),
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
      return 'A ${_selectedTheme} Adventure with ${_selectedCharacter!.name}';
    }

    return 'A ${_selectedTheme} Adventure with ${_selectedCharacter!.name} & ${others.join(", ")}';
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
            width: 70,
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
                const SizedBox(height: 8),
                Stack(
                  children: [
                    _buildCharacterAvatar(c, size: 45),
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
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 11,
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
                              Colors.green.shade900.withValues(alpha: 0.75),
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
                color: Colors.green.shade900.withValues(alpha: 0.7),
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

  Widget _buildTherapeuticCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.deepPurple, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Therapeutic Story Customization',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'FREE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Create therapeutic stories to help with emotions, challenges, and growth',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            if (_therapeuticCustomization != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _therapeuticCustomization!.primaryGoal?.icon ??
                              Icons.auto_awesome,
                          size: 20,
                          color:
                              _therapeuticCustomization!.primaryGoal?.color ??
                                  Colors.deepPurple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _therapeuticCustomization!
                                    .primaryGoal?.displayName ??
                                'Custom',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() => _therapeuticCustomization = null);
                          },
                        ),
                      ],
                    ),
                    if (_therapeuticCustomization!.wishes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_therapeuticCustomization!.wishes.length} wish${_therapeuticCustomization!.wishes.length == 1 ? "" : "es"} added',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              onPressed: () async {
                final customization = await Navigator.of(context)
                    .push<TherapeuticStoryCustomization>(
                  MaterialPageRoute(
                    builder: (_) => const TherapeuticCustomizationScreen(),
                  ),
                );
                if (customization != null && mounted) {
                  setState(() => _therapeuticCustomization = customization);
                }
              },
              icon: Icon(
                  _therapeuticCustomization != null ? Icons.edit : Icons.add),
              label: Text(_therapeuticCustomization != null
                  ? 'Edit Customization'
                  : 'Customize Story'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
