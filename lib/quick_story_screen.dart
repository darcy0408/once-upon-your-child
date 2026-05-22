// lib/quick_story_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'main_story.dart';
import 'offline_story_cache.dart';
import 'premium_upgrade_screen.dart';
import 'services/api_service_manager.dart';
import 'services/subscription_service.dart';
import 'theme/age_band_theme.dart';
import 'theme/app_theme.dart';
import 'utils/paywall_gate.dart';
import 'widgets/safe_asset_image.dart';
import 'widgets/storybook_page.dart';

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
  String _selectedTheme = 'Adventure'; // Matches first theme in list
  bool _isGenerating = false;
  String? _generatedStory;
  bool _magicPulse = false;

  // Theme data with images
  final List<Map<String, String>> _quickThemes = [
    {
      'name': 'Adventure',
      'image': 'images/themes/adventure.webp',
      'description': 'Mysterious doors and exciting journeys',
    },
    {
      'name': 'Magic',
      'image': 'images/themes/magic.webp',
      'description': 'Sparkling crystals and enchanted caves',
    },
    {
      'name': 'Friendship',
      'image': 'images/themes/friendship.webp',
      'description': 'Rainbow adventures with best friends',
    },
    {
      'name': 'Forest',
      'image': 'images/themes/forest.webp',
      'description': 'Magical mushrooms and woodland wonders',
    },
    {
      'name': 'Animals',
      'image': 'images/themes/animals.webp',
      'description': 'Adorable creatures and sweet companions',
    },
    {
      'name': 'Princess',
      'image': 'images/themes/princess.webp',
      'description': 'Dreamy castles in the clouds',
    },
  ];

  final List<String> _ages = ['4', '5', '6', '7', '8', '9', '10', '11', '12'];

  @override
  void initState() {
    super.initState();
    // Pre-fill with a fun default
    _characterNameController.text = 'Alex';
    _themeController.text = _selectedTheme; // Will be 'Adventure'
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
      _magicPulse = true;
      _generatedStory = null;
    });

    try {
      // Check subscription for story generation
      final subscriptionService = SubscriptionService();
      final canGenerate = await subscriptionService.canCreateStory();

      if (!canGenerate) {
        if (mounted) {
          _showUpgradeDialog();
          setState(() {
            _isGenerating = false;
            _magicPulse = false;
          });
        }
        return;
      }

      // Generate the story
      final subscription = await subscriptionService.getSubscription();

      final storyResult = await ApiServiceManager.generateStory(
        characterName: _characterNameController.text.trim(),
        theme: _selectedTheme,
        age: int.parse(_selectedAge),
        subscriptionTier: subscription.tier.name,
      );

      // Record usage
      await subscriptionService.recordStoryCreation();

      if (mounted) {
        setState(() {
          _generatedStory = storyResult.storyText;
          _isGenerating = false;
          _magicPulse = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate story: $e')),
        );
        setState(() {
          _isGenerating = false;
          _magicPulse = false;
        });
      }
    }
  }

  void _showUpgradeDialog() {
    showPaywallGated(
      context: context,
      showActualPaywall: () => showDialog(
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PremiumUpgradeScreen()),
                );
              },
              child: const Text('Upgrade Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _shareStory() {
    if (_generatedStory == null) return;

    final title = '$_selectedTheme with ${_characterNameController.text}';
    SharePlus.instance.share(
      ShareParams(
        text: '$title\n\n$_generatedStory',
        subject: title,
      ),
    );
  }

  Future<void> _saveStory() async {
    if (_generatedStory == null) return;

    final title = '$_selectedTheme with ${_characterNameController.text}';

    final cached = CachedStory(
      id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      storyText: _generatedStory!,
      characterName: _characterNameController.text,
      theme: _selectedTheme,
      cachedAt: DateTime.now(),
    );

    await OfflineStoryCache().cacheStory(cached);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title saved!')),
      );
    }
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

  Widget _buildThemeCard(Map<String, String> theme, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTheme = theme['name']!;
          _themeController.text = theme['name']!;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              SafeAssetImage(
                theme['image']!,
                fit: BoxFit.cover,
              ),
              // Gradient overlay for text readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme['name']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        theme['description']!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // Selection indicator
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.accent.withValues(alpha: 0.1),
                ],
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
            'Where should we go today?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _quickThemes.length,
            itemBuilder: (context, index) {
              final theme = _quickThemes[index];
              final isSelected = theme['name'] == _selectedTheme;
              return _buildThemeCard(theme, isSelected);
            },
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
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: _magicPulse ? 1.05 : 1.0,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                onPressed: _isGenerating ? null : _generateQuickStory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                  shadowColor: AppColors.primary.withValues(alpha: 0.5),
                ),
                label: _isGenerating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text((Theme.of(context).extension<AgeBandThemeData>()?.band.isMature ?? false) ? 'Creating story...' : 'Making magic...'),
                        ],
                      )
                    : Text(
                        (Theme.of(context).extension<AgeBandThemeData>()?.band.isMature ?? false) ? 'Start Story' : 'Make Magic',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
          color: AppColors.primary.withValues(alpha: 0.1),
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
                      'Age $_selectedAge • Just created',
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
                  onPressed: () => _saveStory(),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StoryBookPage(
              showDecorations: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _generatedStory!,
                  style: AppTextStyles.storyBody,
                ),
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
