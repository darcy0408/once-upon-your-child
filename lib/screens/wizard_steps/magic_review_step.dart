import 'package:flutter/material.dart';
import '../../services/api_service_manager.dart';
import '../../services/achievement_service.dart';
import '../../story_result_screen.dart';
import '../../pick_a_path_adventure_screen.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/make_magic_button.dart';
import '../../widgets/character_preview.dart';
import '../wizard_story_screen.dart';
import 'wizard_data_mapper.dart';

/// Step 4: Magic Review & Launch
///
/// Layout:
/// - Character preview at top
/// - Summary cards showing selections
/// - Big "Make Magic" button
/// - Actually triggers story generation
class MagicReviewStep extends StatefulWidget {
  final WizardData wizardData;

  const MagicReviewStep({
    super.key,
    required this.wizardData,
  });

  @override
  State<MagicReviewStep> createState() => _MagicReviewStepState();
}

class _MagicReviewStepState extends State<MagicReviewStep> {
  bool _isGenerating = false;
  String _loadingStatus = 'Making magic...';

  void _launchStoryCreation() async {
    debugPrint('🎯 MagicReviewStep: _launchStoryCreation called');

    if (!widget.wizardData.isComplete) {
      debugPrint('⚠️ Wizard data not complete!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all steps first!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    debugPrint('✅ Wizard data complete, starting story generation');
    setState(() => _isGenerating = true);

    try {
      // 1. Save Character if needed
      await _saveCharacterIfNeeded();

      // Prepared payload using the mapper
      final requestData = WizardDataMapper.mapToStoryRequest(widget.wizardData);

      // 2. CHECK MODE: If Pick-A-Path, skip standard generation and go to interactive screen
      if (widget.wizardData.interactiveMode) {
        debugPrint('🎮 Pick-A-Path mode enabled, routing to PickAPathAdventureScreen');

        if (mounted) {
           // Create a Character object from wizard data
          final character = Character(
            id: widget.wizardData.characterId ?? 'temp-${DateTime.now().millisecondsSinceEpoch}',
            name: widget.wizardData.characterName,
            age: widget.wizardData.characterAge,
            role: widget.wizardData.selectedArchetypeId ?? 'Adventurer',
            gender: widget.wizardData.characterGender,
            personalitySliders: widget.wizardData.personalitySliders,
            // Map simple fields if needed, or rely on defaults
          );

          // Navigate to Pick-A-Path Adventure
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PickAPathAdventureScreen(
                userId: 'guest',  // TODO: Add userId to WizardData if needed
                character: character,
                theme: requestData['theme'] ?? 'Adventure',
                tone: 'whimsical',  // TODO: Add tone selector to wizard if desired
                length: _mapStoryLength(widget.wizardData.storyLength),
                interests: widget.wizardData.selectedEmotionChips.isNotEmpty
                    ? widget.wizardData.selectedEmotionChips
                    : null,
                mustInclude: widget.wizardData.customElements.isNotEmpty
                    ? [widget.wizardData.customElements]
                    : null,
                avoid: widget.wizardData.fears.isNotEmpty
                    ? widget.wizardData.fears
                    : null,
                lifeChallenge: widget.wizardData.lifeChallenge,
                personalitySliders: widget.wizardData.personalitySliders,
              ),
            ),
          );
        }
      } else {
        // 3. STANDARD MODE: Generate story first, then show result
        final result = await ApiServiceManager.generateStory(
          characterName: requestData['character'] ?? 'Hero',
          age: requestData['age'] ?? 5,
          theme: requestData['theme'] ?? 'Magical Adventure',
          companion: requestData['companion'] ?? '',  // Provide empty string if null
          characterDetails: requestData['characterDetails'],
          currentFeeling: requestData['currentFeeling'],
          additionalCharacters: requestData['additionalCharacters'],
          // Story modes from wizard
          includeIllustrations: widget.wizardData.includeIllustrations,
          rhymeTimeMode: widget.wizardData.rhymeTimeMode,
          learningToReadMode: widget.wizardData.learningToReadMode,
          companionPets: requestData['companion_pets'],
          companionCharacters: requestData['companion_characters'],

          storyLength: requestData['storyLength'] ?? 'standard',
          onProgress: (status) {
            if (mounted) setState(() => _loadingStatus = status);
          },
        );
        debugPrint('✨ Story generation complete: ${result.storyText.length > 100 ? result.storyText.substring(0, 100) : result.storyText}...');

        if (mounted) {
          // Navigate to standard story result
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StoryResultScreen(
                title: result.title ?? 'My Magical Story',
                storyText: result.storyText,
                wisdomGem: result.wisdomGem ?? 'You are magic!',
                characterName: requestData['characterName'] ?? widget.wizardData.characterName,
                theme: requestData['theme'],
                characterAge: requestData['age'],
                pages: result.pages,
                adventureSteps: result.adventureSteps,
                // Track this as a new story
                trackStoryCreation: true,
                trackAnalytics: true,
                achievementsService: AchievementService(),
                storyCreatedAt: DateTime.now(),
              ),
            ),
          );
        }
      }

    } catch (e, stack) {
      debugPrint('❌ Error generating story: $e');
      debugPrint('📚 Stack trace: $stack');

      String userMessage = 'Magic needed a recharge';
      if (e.toString().contains('500')) {
        userMessage = 'Server error (500). The backend had trouble generating your story.';
      } else if (e.toString().contains('timeout')) {
        userMessage = 'Story generation timed out. Please try again.';
      } else if (e.toString().contains('Cannot connect') || e.toString().contains('XMLHttpRequest')) {
         // "failed to fetch" often comes up as XMLHttpRequest error in Flutter Web
        userMessage = 'Cannot connect to server. Please check your internet or try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userMessage\n\n${e.toString().length > 100 ? '${e.toString().substring(0, 100)}...' : e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _launchStoryCreation,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _saveCharacterIfNeeded() async {
    
    try {
      final characterDetails = WizardDataMapper.mapToStoryRequest(widget.wizardData)['characterDetails'] as Map<String, dynamic>;
      
      final body = {
        'name': widget.wizardData.characterName,
        'age': widget.wizardData.characterAge,
        'gender': widget.wizardData.characterGender,
        'role': widget.wizardData.selectedArchetypeId, // Ensure role is updated
        'character_type': 'Everyday Kid',
        'character_style': 'Regular Kid',
        'likes': characterDetails['interests'] ?? [],
        'strengths': characterDetails['strengths'] ?? [],
        'pets': widget.wizardData.pets,
        'friends': widget.wizardData.additionalCharacters,
        'avatar': {
          'hairColor': 'Brown',
          'skinTone': 'Light',
        },
        // Include generated avatar if available
        if (widget.wizardData.generatedAvatar != null)
          'avatar_data': widget.wizardData.generatedAvatar!.toJson(),
      };

      final api = ApiServiceManager();
      
      if (widget.wizardData.characterId != null) {
          // UPDATE EXISTING
          debugPrint('🔄 Updating existing character: ${widget.wizardData.characterId}');
          // using PATCH to update only changed fields is safer, but providing all is fine too
          await api.patch('/characters/${widget.wizardData.characterId}', body);
      } else {
          // CREATE NEW
          debugPrint('✨ Creating new character');
          final response = await api.post('/create-character', body);

          if (response.containsKey('character_id')) {
             widget.wizardData.characterId = response['character_id']?.toString();
          } else if (response.containsKey('id')) {
             widget.wizardData.characterId = response['id']?.toString();
          }
      }

    } catch (e) {
      debugPrint('⚠️ Character save/update failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.wizardData;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'Ready for Magic?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Subtitle
            const Text(
              'Review your story setup',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4A4A4A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Character preview (smaller version, forced square for circular display)
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CharacterPreview(
                  generatedAvatar: data.generatedAvatar,
                  placeholderEmoji: _getCharacterEmoji(),
                  showSparkles: true,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Story Settings Section (Magical Card)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                // Gradient background instead of solid white
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.cream.withValues(alpha: 0.7),
                    AppColors.primary.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('⚙️', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Story Settings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: AppSpacing.sm),

                  _buildSwitchTile(
                    '✨ Include Illustrations',
                    'Add beautiful images',
                    data.includeIllustrations,
                    (v) => setState(() => data.includeIllustrations = v),
                  ),
                  _buildSwitchTile(
                    '🎵 Rhyme Time Mode',
                    'Story told in fun rhymes',
                    data.rhymeTimeMode,
                    (v) => setState(() => data.rhymeTimeMode = v),
                  ),
                  _buildSwitchTile(
                    '📚 Learning to Read',
                    'Simple words for early readers',
                    data.learningToReadMode,
                    (v) => setState(() => data.learningToReadMode = v),
                  ),
                  _buildSwitchTile(
                    '🎮 Pick-A-Path Adventure',
                    'Make choices as you go',
                    data.interactiveMode,
                    (v) => setState(() => data.interactiveMode = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Story Length Section
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.cream.withValues(alpha: 0.7),
                    AppColors.gold.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('⏱️', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Story Length',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Choose how long your adventure should be',
                    style: TextStyle(
                      color: Color(0xFF4A4A4A),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Segmented button style selector
                  Row(
                    children: [
                      Expanded(
                        child: _LengthOption(
                          emoji: '⚡',
                          label: 'Quick',
                          subtitle: '5 min',
                          isSelected: data.storyLength == 'quick',
                          onTap: () => setState(() => data.storyLength = 'quick'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _LengthOption(
                          emoji: '📖',
                          label: 'Standard',
                          subtitle: '10 min',
                          isSelected: data.storyLength == 'standard',
                          onTap: () => setState(() => data.storyLength = 'standard'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _LengthOption(
                          emoji: '🏰',
                          label: 'Epic',
                          subtitle: '15 min',
                          isSelected: data.storyLength == 'epic',
                          onTap: () => setState(() => data.storyLength = 'epic'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Custom Elements Section (Free-Form Input)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.cream.withValues(alpha: 0.7),
                    AppColors.primary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('💭', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Your Story Ideas',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Tell me what you want in your story! (Optional)',
                    style: TextStyle(
                      color: Color(0xFF4A4A4A),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    maxLines: 3,
                    onChanged: (value) => setState(() => data.customElements = value),
                    decoration: InputDecoration(
                      hintText: 'Example: I want to meet a talking tree and ride a dragon!',
                      hintStyle: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      filled: true,
                      fillColor: AppColors.cream.withValues(alpha: 0.3), // Magical cream tint instead of white
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (data.customElements.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Great idea! I\'ll make sure to include: "${data.customElements}"',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textDark,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Summary cards header
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                '📋 Story Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _SummaryCard(
              icon: '🦸',
              title: 'Your Hero',
              value: data.characterName.isEmpty 
                  ? 'MISSING NAME (Go back to Step 1)' 
                  : '${data.characterName} (${data.selectedArchetypeId})',
              isError: data.characterName.isEmpty,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),

            _SummaryCard(
              icon: '🎂',
              title: 'Age',
              value: '${data.characterAge} years old',
              color: Colors.orange,
            ),
            const SizedBox(height: AppSpacing.md),

            if (data.pets.isNotEmpty || data.additionalCharacters.isNotEmpty) ...[
              _SummaryCard(
                icon: '👨‍👩‍👧‍👦',
                title: 'Friends & Family',
                value: [
                  ...data.additionalCharacters,
                  ...data.pets.map((p) => '${p['name']} (${p['species']})')
                ].join(', '),
                color: Colors.green,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (data.selectedScenario != null)
              _SummaryCard(
                icon: '📖',
                title: 'Story Theme',
                value: _formatScenario(data.selectedScenario!),
                color: Colors.blue,
              ),
            if (data.selectedEmotionChips.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _SummaryCard(
                icon: '💫',
                title: 'Feelings',
                value: data.selectedEmotionChips.join(', '),
                color: Colors.purple,
              ),
            ],
            if (data.selectedCompanions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _SummaryCard(
                icon: '🐾',
                title: 'Companions',
                value: data.companionNames.isNotEmpty 
                    ? data.companionNames.join(', ')
                    : data.selectedCompanions.join(', '),
                color: Colors.brown,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),

            // Big "Make Magic" button
            Center(
              child: _isGenerating
                  ? Column(
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _loadingStatus,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : MakeMagicButton(
                      onTap: _launchStoryCreation,
                      isEnabled: !_isGenerating && data.isComplete,
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  String _getCharacterEmoji() {
    final archetype = widget.wizardData.selectedArchetypeId ?? '';
    if (archetype.contains('Adventurer')) return '🗺️';
    if (archetype.contains('Thinker')) return '💭';
    if (archetype.contains('Artist')) return '🎨';
    if (archetype.contains('Helper')) return '🤝';
    if (archetype.contains('Athlete')) return '⚡';
    if (archetype.contains('Shy')) return '😊';
    return '👧';
  }

  String _formatScenario(String scenarioId) {
    return scenarioId
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Map wizard story length to Pick-A-Path length
  String _mapStoryLength(String wizardLength) {
    switch (wizardLength) {
      case 'quick':
        return 'short';
      case 'epic':
        return 'long';
      case 'standard':
      default:
        return 'medium';
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final bool isError;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    this.isError = false,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg), // Improved Radius
        border: Border.all(
          color: isError ? AppColors.error : color.withValues(alpha: 0.3),
          width: 2, // Thicker border
        ),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
             // Subtle tint based on the category color
             color.withValues(alpha: 0.15),
             AppColors.cream.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isError ? AppColors.error.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isError ? AppColors.error : AppColors.textDark,
                        fontWeight: isError ? FontWeight.bold : FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Story length selection button
class _LengthOption extends StatelessWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LengthOption({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : AppColors.cream.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.primary.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: TextStyle(
                fontSize: 28,
                shadows: isSelected
                    ? [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ]
                    : [],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? AppColors.textDark : const Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.textDark : const Color(0xFF4A4A4A),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
