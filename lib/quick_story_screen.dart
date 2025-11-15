// lib/quick_story_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'main_story.dart';
import 'models.dart';
import 'services/api_service_manager.dart';
import 'services/subscription_service.dart';
import 'widgets/app_button.dart';
import 'widgets/app_card.dart';
import 'theme/app_theme.dart';

class QuickStoryScreen extends StatefulWidget {
  const QuickStoryScreen({super.key});

  @override
  State<QuickStoryScreen> createState() => _QuickStoryScreenState();
}

class _QuickStoryScreenState extends State<QuickStoryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _characterNameController = TextEditingController();
  final TextEditingController _themeController = TextEditingController();

  String _selectedAge = '6';
  String _selectedTheme = 'Adventure';
  bool _isGenerating = false;
  String? _generatedStory;

  final List<String> _quickThemes = [
    'Adventure',
    'Friendship',
    'Magic',
    'Animals',
    'Space',
    'Pirates',
    'Princess',
    'Superhero',
    'Underwater',
    'Forest',
  ];

  final List<String> _ages = ['4', '5', '6', '7', '8', '9', '10', '11', '12'];

  @override
  void initState() {
    super.initState();
    // Pre-fill with a fun default
    _characterNameController.text = 'Alex';
    _themeController.text = _selectedTheme;
  }

  @override
  void dispose() {
    _characterNameController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  Future<void> _generateQuickStory() async {
    if (_characterNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a character name')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedStory = null;
    });

    try {
      // Check subscription for story generation
      final subscriptionService = SubscriptionService();
      final canGenerate = await subscriptionService.canGenerateStory();

      if (!canGenerate) {
        if (mounted) {
          _showUpgradeDialog();
        }
        return;
      }

      // Generate the story
      final story = await ApiServiceManager.generateStory(
        characterName: _characterNameController.text.trim(),
        theme: _selectedTheme,
        age: int.parse(_selectedAge),
      );

      // Record usage
      await subscriptionService.recordStoryCreation();

      if (mounted) {
        setState(() {
          _generatedStory = story;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate story: $e')),
        );
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Unlimited Stories'),
        content: const Text(
          'Create unlimited magical stories with premium features like character evolution and therapeutic activities.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to subscription screen
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  void _shareStory() {
    if (_generatedStory == null) return;

    // TODO: Implement sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing feature coming soon!')),
    );
  }

  void _saveStory() {
    if (_generatedStory == null) return;

    // Create a basic saved story
    final savedStory = SavedStory(
      title: '$_selectedTheme with ${_characterNameController.text}',
      storyText: _generatedStory!,
      theme: _selectedTheme,
      characters: [
        Character(
          id: 'quick_${_characterNameController.text}',
          name: _characterNameController.text,
          age: int.parse(_selectedAge),
          gender: 'neutral',
          appearance: {},
          personality: [],
          abilities: [],
        ),
      ],
      createdAt: DateTime.now(),
      isInteractive: false,
    );

    // TODO: Save to storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story saved!')),
    );
  }

  void _createAnotherStory() {
    setState(() {
      _generatedStory = null;
      _isGenerating = false;
    });
  }

  void _exploreAdvancedFeatures() {
    // Navigate to main app with all features
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const StoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Story'),
        backgroundColor: AppColors.primary,
        actions: [
          TextButton(
            onPressed: _exploreAdvancedFeatures,
            child: const Text(
              'Advanced',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _generatedStory != null
          ? _buildStoryView()
          : _buildStoryCreator(),
    );
  }

  Widget _buildStoryCreator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.1), AppColors.accent.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.auto_stories,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create a Magical Story',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Just pick a character and theme - we\'ll do the rest!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Character Name
          const Text(
            'Character Name',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _characterNameController,
            decoration: InputDecoration(
              hintText: 'Enter a name (e.g., Emma, Max, Luna)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),

          const SizedBox(height: 24),

          // Age Selection
          const Text(
            'Age',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAge,
                isExpanded: true,
                items: _ages.map((age) {
                  return DropdownMenuItem(
                    value: age,
                    child: Text('$age years old'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAge = value!;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Theme Selection
          const Text(
            'Story Theme',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickThemes.map((theme) {
              final isSelected = theme == _selectedTheme;
              return FilterChip(
                label: Text(theme),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedTheme = theme;
                    _themeController.text = theme;
                  });
                },
                backgroundColor: Colors.grey.shade100,
                selectedColor: AppColors.primary.withOpacity(0.2),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Custom Theme Option
          TextField(
            controller: _themeController,
            decoration: InputDecoration(
              hintText: 'Or create your own theme...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: const Icon(Icons.edit),
            ),
            onChanged: (value) {
              setState(() {
                _selectedTheme = value;
              });
            },
          ),

          const SizedBox(height: 32),

          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generateQuickStory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isGenerating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Creating your story...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_stories),
                        SizedBox(width: 8),
                        Text('Create Story'),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Advanced Features Hint
          Center(
            child: TextButton(
              onPressed: _exploreAdvancedFeatures,
              child: Text(
                'Want character evolution, emotions, and more?',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryView() {
    return Column(
      children: [
        // Story Header
        Container(
          padding: const EdgeInsets.all(20),
          color: AppColors.primary.withOpacity(0.1),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Text(
                  _characterNameController.text.isNotEmpty
                      ? _characterNameController.text[0].toUpperCase()
                      : 'A',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_selectedTheme with ${_characterNameController.text}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Age ${_selectedAge} • Just created',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Action Buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveStory,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareStory,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Story Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(
              _generatedStory!,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        ),

        // Bottom Actions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _createAnotherStory,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Create Another'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _exploreAdvancedFeatures,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Explore More'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}