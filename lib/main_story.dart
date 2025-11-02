import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'storage_service.dart';
import 'story_result_screen.dart';
import 'saved_stories_screen.dart';
import 'models.dart';
import 'multi_character_screen.dart';
import 'character_creation_screen_enhanced.dart';
import 'interactive_story_screen.dart';
import 'adventure_map_screen.dart';
import 'subscription_service.dart';
import 'subscription_models.dart';
import 'paywall_dialog.dart';
import 'premium_upgrade_screen.dart';
import 'therapeutic_customization_screen.dart';
import 'therapeutic_models.dart';
import 'story_intent_card.dart';
import 'reading_dashboard_screen.dart';
import 'offline_stories_screen.dart';
import 'coloring_book_library_screen.dart';
import 'superhero_builder_screen.dart';
import 'reading_unlocks_screen.dart';
import 'emotions_screen.dart';
import 'unlock_all_for_testing.dart';

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
  bool _isLoading = false;
  bool _isInteractiveMode = false;

  final _subscriptionService = SubscriptionService();
  UserSubscription? _currentSubscription;
  int _remainingStoriesToday = 0;
  TherapeuticStoryCustomization? _therapeuticCustomization;

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
  }

  Future<void> _loadSubscriptionInfo() async {
    final subscription = await _subscriptionService.getSubscription();
    final remaining = await _subscriptionService.getRemainingStoriesToday();

    if (mounted) {
      setState(() {
        _currentSubscription = subscription;
        _remainingStoriesToday = remaining;
      });
    }
  }

  Future<void> _loadCharacters() async {
    final url = Uri.parse('http://127.0.0.1:5000/get-characters');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Accept either: [ ... ]  OR  { "items": [ ... ], "meta": {...} }
        final List list = (decoded is List) ? decoded : (decoded['items'] as List);
        final characters = list.map((j) => Character.fromJson(j)).toList().cast<Character>();

        setState(() {
          _characters = characters;
          if (_characters.isNotEmpty) {
            final stillExists = _characters.any((c) => c.id == _selectedCharacter?.id);
            if (!stillExists) _selectedCharacter = _characters.first;
          } else {
            _selectedCharacter = null;
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load characters (${response.statusCode}).')),
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

  Future<void> _createStory() async {
    final navContext = context;
    if (_selectedCharacter == null) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        const SnackBar(content: Text('Please choose a character!')),
      );
      return;
    }

    // Check if user can create a story
    final canCreate = await _subscriptionService.canCreateStory();
    if (!canCreate) {
      final remaining = await _subscriptionService.getRemainingStoriesToday();
      final remainingMonth = await _subscriptionService.getRemainingStoriesThisMonth();
      final upgraded = await PaywallDialog.showStoryLimitDialog(
        navContext,
        remainingToday: remaining,
        remainingMonth: remainingMonth,
      );
      if (upgraded) {
        await _loadSubscriptionInfo();
      }
      return;
    }

    // Check if interactive mode is available
    if (_isInteractiveMode) {
      final hasInteractive = await _subscriptionService.hasFeature('interactive_stories');
      if (!hasInteractive) {
        await PaywallDialog.showFeatureLockedDialog(
          navContext,
          featureName: 'Interactive Stories',
          description: 'Create choose-your-own-adventure stories where kids make choices that affect the outcome!',
        );
        return;
      }
    }

    // Check if multi-character is available
    if (_additionalCharacterIds.isNotEmpty) {
      final hasMultiChar = await _subscriptionService.hasFeature('multi_character_stories');
      if (!hasMultiChar) {
        await PaywallDialog.showFeatureLockedDialog(
          navContext,
          featureName: 'Multi-Character Stories',
          description: 'Include siblings and friends in stories together!',
        );
        return;
      }
    }

    // Check if theme is available
    final themeAvailable = await _subscriptionService.isThemeAvailable(_selectedTheme);
    if (!themeAvailable) {
      await PaywallDialog.showContentLockedDialog(
        navContext,
        contentType: 'Theme',
        contentName: _selectedTheme,
      );
      return;
    }

    // Check if companion is available
    if (_selectedCompanion != 'None') {
      final companionAvailable = await _subscriptionService.isCompanionAvailable(_selectedCompanion);
      if (!companionAvailable) {
        await PaywallDialog.showContentLockedDialog(
          navContext,
          contentType: 'Companion',
          contentName: _selectedCompanion,
        );
        return;
      }
    }

    // Get all selected characters
    final List<Character> allSelectedCharacters = [
      _selectedCharacter!,
      ..._characters.where((c) => _additionalCharacterIds.contains(c.id)),
    ];

    // If interactive mode, navigate to interactive story screen
    if (_isInteractiveMode) {
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => InteractiveStoryScreen(
            title: 'Choose Your Adventure',
            characterName: _selectedCharacter!.name,
            theme: _selectedTheme,
            companion: _selectedCompanion,
            additionalCharacters: allSelectedCharacters.skip(1).toList(),
            characterId: _selectedCharacter!.id,
            therapeuticCustomization: _therapeuticCustomization,
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Use multi-character endpoint if additional characters are selected
    final String apiUrl = _additionalCharacterIds.isEmpty
        ? 'http://127.0.0.1:5000/generate-story'
        : 'http://127.0.0.1:5000/generate-multi-character-story';

    final Map<String, dynamic> requestBody = _additionalCharacterIds.isEmpty
        ? {
            'character': _selectedCharacter!.name,
            'theme': _selectedTheme,
            'companion': _selectedCompanion,
            if (_therapeuticCustomization != null)
              'therapeutic_prompt': _therapeuticCustomization!.toPromptAddition(),
          }
        : {
            'character_ids': [_selectedCharacter!.id, ..._additionalCharacterIds.toList()],
            'main_character_id': _selectedCharacter!.id,
            'theme': _selectedTheme,
            'companion': _selectedCompanion,
            if (_therapeuticCustomization != null)
              'therapeutic_prompt': _therapeuticCustomization!.toPromptAddition(),
          };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(requestBody),
      );

      if (!navContext.mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Handle different response formats (single vs multi-character)
        final String title = _additionalCharacterIds.isEmpty
            ? (data['title'] ?? 'Your Story') as String
            : _generateMultiCharacterTitle();

        final String storyText = _additionalCharacterIds.isEmpty
            ? (data['story_text'] ?? '') as String
            : (data['story'] ?? '') as String;

        final String wisdomGem = _additionalCharacterIds.isEmpty
            ? (data['wisdom_gem'] ?? '') as String
            : 'Together, we are stronger than we are alone.';

        // Save the story locally with all characters used
        final saved = SavedStory(
          title: title,
          storyText: storyText,
          theme: _selectedTheme,
          characters: allSelectedCharacters,
          createdAt: DateTime.now(),
          isInteractive: false,
          wisdomGem: wisdomGem,
        );
        await StorageService().saveStory(saved);

        // Record story creation for usage tracking
        await _subscriptionService.recordStoryCreation();
        await _loadSubscriptionInfo(); // Refresh remaining count

        if (!navContext.mounted) return;

        // Navigate to result screen
        Navigator.of(navContext).push(
          MaterialPageRoute(
            builder: (_) => StoryResultScreen(
              title: title,
              storyText: storyText,
              wisdomGem: wisdomGem,
              characterName: _selectedCharacter?.name,
              storyId: saved.id,
              theme: _selectedTheme,
              characterId: _selectedCharacter?.id,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(navContext).showSnackBar(
          const SnackBar(content: Text('Error: Could not get a story from the server.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        const SnackBar(content: Text('Network Error: Could not connect to the server.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Story Creator'),
            if (_currentSubscription != null && _currentSubscription!.isPremium) ...[
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
          // Debug button to activate Isabela tester
          IconButton(
            tooltip: 'Activate Isabela Tester (Debug)',
            icon: const Icon(Icons.science, color: Colors.amber),
            onPressed: () async {
              await unlockAllFeaturesForTesting();
              await _loadSubscriptionInfo();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Isabela Tester Activated! All features unlocked.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          // Stories remaining indicator
          if (_currentSubscription != null && !_currentSubscription!.limits.unlimitedStories)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  MaterialPageRoute(builder: (_) => const PremiumUpgradeScreen()),
                );
                await _loadSubscriptionInfo();
              },
            ),
          // Reading Dashboard
          IconButton(
            tooltip: 'Reading Progress',
            icon: const Icon(Icons.auto_stories),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReadingDashboardScreen()),
              );
            },
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
                MaterialPageRoute(builder: (_) => const ColoringBookLibraryScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Adventure Map',
            icon: const Icon(Icons.map),
            onPressed: () async {
              final selectedTheme = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => AdventureMapScreen(
                    selectedCharacter: _selectedCharacter,
                  ),
                ),
              );
              // If a theme was selected from the map, update the current theme
              if (selectedTheme != null && mounted) {
                setState(() => _selectedTheme = selectedTheme);
              }
            },
          ),
          // Superhero Builder
          IconButton(
            tooltip: 'Superhero Builder',
            icon: const Icon(Icons.shield),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SuperheroBuilderScreen()),
              );
            },
          ),
          // Reading Unlocks
          IconButton(
            tooltip: 'Reading Unlocks',
            icon: const Icon(Icons.stars),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReadingUnlocksScreen()),
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
            _buildSectionCard('Choose Main Character', _buildCharacterSelector()),
            const SizedBox(height: 20),
            if (_selectedCharacter != null)
              _buildSectionCard('Add Friends/Siblings (Optional)', _buildAdditionalCharactersSelector()),
            if (_selectedCharacter != null && _additionalCharacterIds.isNotEmpty)
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
                    if (intent.situation != null && intent.desiredOutcome != null) {
                      fullSituation = '${intent.situation}\n\nDesired outcome: ${intent.desiredOutcome}';
                    } else {
                      fullSituation = intent.situation ?? intent.desiredOutcome;
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
            _buildSectionCard('Choose a Companion (Optional)', _buildCompanionSelector()),
            const SizedBox(height: 20),
            _buildSectionCard('Story Mode', _buildStoryModeSelector()),
            const SizedBox(height: 40),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _createStory,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Create My Story!'),
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
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
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

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCharacter = character);
      },
      onLongPress: () => _editCharacter(character),
      child: Container(
        width: 80,
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
            const SizedBox(height: 8),
            _buildCharacterAvatar(character, size: 50),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                character.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.deepPurple : Colors.black87,
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
  }

  Widget _buildAddCharacterCard() {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const CharacterCreationScreenEnhanced()),
        );
        _loadCharacters();
      },
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.deepPurple, width: 2, style: BorderStyle.solid),
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
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepPurple),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getSkinToneColor(character),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _CharacterAvatarPainter(
          hairColor: _getHairColor(character.hair),
          eyeColor: _getEyeColor(character.eyes),
          skinTone: _getSkinToneColor(character),
          age: character.age,
          gender: character.gender,
        ),
      ),
    );
  }

  Color _getSkinToneColor(Character character) {
    // Generate different skin tones based on character ID for variety
    final tones = [
      const Color(0xFFFFDBAC), // Light
      const Color(0xFFF1C27D), // Tan
      const Color(0xFFE0AC69), // Medium
      const Color(0xFFC68642), // Brown
      const Color(0xFF8D5524), // Dark brown
    ];
    final hash = character.id.hashCode;
    return tones[hash.abs() % tones.length];
  }

  Color _getHairColor(String? hair) {
    if (hair == null) return Colors.brown.shade800;

    final hairLower = hair.toLowerCase();
    if (hairLower.contains('blond') || hairLower.contains('yellow')) return Colors.amber.shade700;
    if (hairLower.contains('black')) return Colors.black;
    if (hairLower.contains('brown')) return Colors.brown.shade800;
    if (hairLower.contains('red') || hairLower.contains('ginger')) return Colors.red.shade900;
    if (hairLower.contains('auburn')) return const Color(0xFF8B4513);
    if (hairLower.contains('white') || hairLower.contains('gray') || hairLower.contains('grey')) return Colors.grey.shade300;
    if (hairLower.contains('pink')) return Colors.pink.shade300;
    if (hairLower.contains('blue')) return Colors.blue.shade400;
    if (hairLower.contains('green')) return Colors.green.shade400;
    if (hairLower.contains('purple')) return Colors.purple.shade400;

    return Colors.brown.shade800; // Default
  }

  Color _getEyeColor(String? eyes) {
    if (eyes == null) return Colors.brown.shade700;

    final eyesLower = eyes.toLowerCase();
    if (eyesLower.contains('blue')) return Colors.blue.shade700;
    if (eyesLower.contains('green')) return Colors.green.shade700;
    if (eyesLower.contains('brown')) return Colors.brown.shade700;
    if (eyesLower.contains('hazel')) return const Color(0xFF8E7618);
    if (eyesLower.contains('amber') || eyesLower.contains('gold')) return Colors.amber.shade800;
    if (eyesLower.contains('gray') || eyesLower.contains('grey')) return Colors.grey.shade600;
    if (eyesLower.contains('purple') || eyesLower.contains('violet')) return Colors.purple.shade700;

    return Colors.brown.shade700; // Default
  }

  Color _getAvatarColor(Character character) {
    // Generate color based on character properties
    final colors = [
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];

    // Use character ID to consistently pick a color
    final hash = character.id.hashCode;
    return colors[hash.abs() % colors.length];
  }

  Future<void> _editCharacter(Character character) async {
    // TODO: Navigate to edit screen with delete option
    // For now, show a dialog
    final shouldEdit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${character.name}'),
        content: const Text('Character editing coming soon! You can change hair, outfit, and delete characters here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(true);
              await _deleteCharacter(character.id, character.name);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCharacter(String characterId, String characterName) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Character'),
        content: Text('Are you sure you want to delete $characterName? This cannot be undone.'),
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
        Uri.parse('http://127.0.0.1:5000/delete-character/$characterId'),
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
      'Adventure', 'Friendship', 'Magic', 'Dragons',
      'Castles', 'Unicorns', 'Space', 'Ocean'
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
            onTap: () => setState(() => _selectedCompanion = companion['name']!),
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
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.pets, size: 40, color: Colors.deepPurple),
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
    final availableCharacters = _characters
        .where((c) => c.id != _selectedCharacter?.id)
        .toList();

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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.green.shade700 : Colors.black87,
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

  Widget _buildStoryModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text(
            'Interactive Mode',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _isInteractiveMode
                ? 'Make choices that affect the story'
                : 'Traditional story format',
            style: const TextStyle(fontSize: 12),
          ),
          value: _isInteractiveMode,
          activeColor: const Color(0xFF4CAF50), // Jungle green
          onChanged: (value) {
            setState(() => _isInteractiveMode = value);
          },
        ),
        if (_isInteractiveMode)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 8.0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You\'ll make choices that change how the story unfolds!',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2E7D32), // Dark jungle green
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          _therapeuticCustomization!.primaryGoal?.icon ?? Icons.auto_awesome,
                          size: 20,
                          color: _therapeuticCustomization!.primaryGoal?.color ?? Colors.deepPurple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _therapeuticCustomization!.primaryGoal?.displayName ?? 'Custom',
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
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              onPressed: () async {
                final customization = await Navigator.of(context).push<TherapeuticStoryCustomization>(
                  MaterialPageRoute(
                    builder: (_) => const TherapeuticCustomizationScreen(),
                  ),
                );
                if (customization != null && mounted) {
                  setState(() => _therapeuticCustomization = customization);
                }
              },
              icon: Icon(_therapeuticCustomization != null ? Icons.edit : Icons.add),
              label: Text(_therapeuticCustomization != null ? 'Edit Customization' : 'Customize Story'),
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

// Custom painter for character avatars
class _CharacterAvatarPainter extends CustomPainter {
  final Color hairColor;
  final Color eyeColor;
  final Color skinTone;
  final int age;
  final String? gender;

  _CharacterAvatarPainter({
    required this.hairColor,
    required this.eyeColor,
    required this.skinTone,
    required this.age,
    this.gender,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw hair (top half of circle)
    final hairPaint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.fill;

    // Hair as arc on top
    final hairPath = Path();
    hairPath.addArc(
      Rect.fromCircle(center: center, radius: radius * 0.9),
      -3.14159 * 0.8, // Start angle (top left)
      3.14159 * 1.6,  // Sweep angle (across top)
    );
    canvas.drawPath(hairPath, hairPaint);

    // Draw eyes
    final eyePaint = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.fill;

    final leftEyeCenter = Offset(center.dx - radius * 0.3, center.dy - radius * 0.1);
    final rightEyeCenter = Offset(center.dx + radius * 0.3, center.dy - radius * 0.1);
    final eyeRadius = radius * 0.15;

    // Eye whites
    final eyeWhitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(leftEyeCenter, eyeRadius, eyeWhitePaint);
    canvas.drawCircle(rightEyeCenter, eyeRadius, eyeWhitePaint);

    // Pupils
    canvas.drawCircle(leftEyeCenter, eyeRadius * 0.6, eyePaint);
    canvas.drawCircle(rightEyeCenter, eyeRadius * 0.6, eyePaint);

    // Draw smile
    final smilePaint = Paint()
      ..color = Colors.brown.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.08
      ..strokeCap = StrokeCap.round;

    final smilePath = Path();
    smilePath.addArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.2),
        width: radius * 0.8,
        height: radius * 0.6,
      ),
      0,
      3.14159,
    );
    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  bool shouldRepaint(_CharacterAvatarPainter oldDelegate) {
    return hairColor != oldDelegate.hairColor ||
        eyeColor != oldDelegate.eyeColor ||
        skinTone != oldDelegate.skinTone;
  }
}
