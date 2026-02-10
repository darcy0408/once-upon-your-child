import 'package:flutter/material.dart';
import '../../services/api_service_manager.dart';
import '../../services/achievement_service.dart';
import '../../story_result_screen.dart';
import '../../pick_a_path_adventure_screen.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/make_magic_button.dart';
import '../../widgets/character_preview.dart';
import '../../widgets/magic_orb.dart';
import '../../widgets/magical_loading_view.dart';
import '../wizard_story_screen.dart';
import '../../data/scenario_data.dart';
import '../../data/companion_data.dart';
import 'wizard_data_mapper.dart';

/// Step 4: Magic Review & Launch (Vision Orb Edition)
///
/// Design:
/// - "Vision Orb" centering the experience
/// - Floating elements for Hero and Companion
/// - Settings as magical toggles
/// - "Whisper" input for custom ideas
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
  String _loadingStatus = 'Casting spell...';

  // Helper to get scenario image
  String get _scenarioImage {
    if (widget.wizardData.selectedScenario != null) {
      final scenario = ScenarioData.getById(widget.wizardData.selectedScenario!);
      if (scenario != null) {
        // Ensure path has assets/ prefix if missing
        if (!scenario.illustration.startsWith('assets/')) {
          return 'assets/${scenario.illustration}';
        }
        return scenario.illustration;
      }
    }
    return 'assets/images/scenarios/magic_door.png'; // Fallback
  }

  // Helper to get companion image
  String? get _companionImage {
    if (widget.wizardData.selectedCompanions.isNotEmpty) {
      // Prioritize the first selected companion
      final firstComp = widget.wizardData.selectedCompanions.first;
      // Check if it's a magical companion
      try {
        final magicComp = magicCompanions.firstWhere((c) => c.id == firstComp);
        // Map ID to asset path (assuming convention or look up if path added to data)
        // Since companion_data doesn't have imagePath in this version of the file I read,
        // I'll map it manually based on known assets.
        return 'assets/images/companions/${magicComp.id}.jpg';
      } catch (_) {
        // Not a magic companion, might be a pet or friend
        // Return null to show emoji fallback
        return null;
      }
    }
    return null;
  }

  String get _companionEmoji {
    if (widget.wizardData.selectedCompanions.isNotEmpty) {
       final firstComp = widget.wizardData.selectedCompanions.first;
       // Try magic companions
       try {
         return magicCompanions.firstWhere((c) => c.id == firstComp).emoji;
       } catch (_) {
         return '🐾'; // Default
       }
    }
    return '❓';
  }

  // Helper to get scenario name
  String get _scenarioLabel {
    if (widget.wizardData.selectedScenario != null) {
      final scenario = ScenarioData.getById(widget.wizardData.selectedScenario!);
      if (scenario != null) return scenario.title;
    }
    return 'Magical Adventure';
  }

  void _launchStoryCreation() async {
    debugPrint('🎯 MagicReviewStep: _launchStoryCreation called');

    if (!widget.wizardData.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all steps first!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // 1. Save Character if needed
      await _saveCharacterIfNeeded();

      // Prepared payload using the mapper
      final requestData = WizardDataMapper.mapToStoryRequest(widget.wizardData);

      // 2. CHECK MODE: If Pick-A-Path, skip standard generation
      if (widget.wizardData.interactiveMode) {
        if (mounted) {
           // Create a Character object from wizard data
          final character = Character(
            id: widget.wizardData.characterId ?? 'temp-${DateTime.now().millisecondsSinceEpoch}',
            name: widget.wizardData.characterName,
            age: widget.wizardData.characterAge,
            role: widget.wizardData.selectedArchetypeId ?? 'Adventurer',
            gender: widget.wizardData.characterGender,
            personalitySliders: widget.wizardData.personalitySliders,
          );

          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PickAPathAdventureScreen(
                userId: 'guest',
                character: character,
                theme: requestData['theme'] ?? 'Adventure',
                tone: 'whimsical',
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
        // 3. STANDARD MODE: Generate story
        final result = await ApiServiceManager.generateStory(
          characterName: requestData['character'] ?? 'Hero',
          age: requestData['age'] ?? 5,
          theme: requestData['theme'] ?? 'Magical Adventure',
          companion: requestData['companion'] ?? '',
          characterDetails: requestData['characterDetails'],
          currentFeeling: requestData['currentFeeling'],
          additionalCharacters: requestData['additionalCharacters'],
          includeIllustrations: widget.wizardData.includeIllustrations,
          rhymeTimeMode: widget.wizardData.rhymeTimeMode,
          learningToReadMode: widget.wizardData.learningToReadMode,
          companionPets: requestData['companion_pets'],
          companionCharacters: requestData['companion_characters'],
          storyLength: requestData['storyLength'] ?? 'standard',
          customElements: requestData['customElements'] ?? '',
          onProgress: (status) {
            if (mounted) setState(() => _loadingStatus = status);
          },
        );

        if (mounted) {
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
                trackStoryCreation: true,
                trackAnalytics: true,
                achievementsService: AchievementService(),
                storyCreatedAt: DateTime.now(),
                isRhyming: widget.wizardData.rhymeTimeMode,
                isLearningToReadMode: widget.wizardData.learningToReadMode,
              ),
            ),
          );
        }
      }

    } catch (e) {
      debugPrint('❌ Error generating story: $e');
      String userMessage = 'Magic needed a recharge';
      if (e.toString().contains('500')) userMessage = 'Server error. The magic faded.';
      else if (e.toString().contains('timeout')) userMessage = 'Story took too long.';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userMessage\nTry again?'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _launchStoryCreation),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveCharacterIfNeeded() async {
    try {
      final characterDetails = WizardDataMapper.mapToStoryRequest(widget.wizardData)['characterDetails'] as Map<String, dynamic>;
      final body = {
        'name': widget.wizardData.characterName,
        'age': widget.wizardData.characterAge,
        'gender': widget.wizardData.characterGender,
        'role': widget.wizardData.selectedArchetypeId,
        'character_type': 'Everyday Kid',
        'character_style': 'Regular Kid',
        'likes': characterDetails['interests'] ?? [],
        'strengths': characterDetails['strengths'] ?? [],
        'pets': widget.wizardData.pets,
        'friends': widget.wizardData.additionalCharacters,
        'avatar': {'hairColor': 'Brown', 'skinTone': 'Light'},
        if (widget.wizardData.generatedAvatar != null)
          'avatar_data': widget.wizardData.generatedAvatar!.toJson(),
      };

      final api = ApiServiceManager();
      if (widget.wizardData.characterId != null) {
          await api.patch('/characters/${widget.wizardData.characterId}', body);
      } else {
          final response = await api.post('/create-character', body);
          if (response.containsKey('character_id')) {
             widget.wizardData.characterId = response['character_id']?.toString();
          } else if (response.containsKey('id')) {
             widget.wizardData.characterId = response['id']?.toString();
          }
      }
    } catch (e) {
      debugPrint('⚠️ Character save failed: $e');
    }
  }

  String _mapStoryLength(String wizardLength) {
    switch (wizardLength) {
      case 'quick': return 'short';
      case 'epic': return 'long';
      default: return 'medium';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.wizardData;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
        child: Column(
          children: [
            // 1. Magical Header
            Text(
              'Gaze into the Future...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
              textAlign: TextAlign.center,
            ),
            Text(
              'for ${data.characterName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 2. Vision Orb Section
            SizedBox(
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Center Orb
                  MagicOrbWidget(
                    imagePath: _scenarioImage,
                    size: 220,
                    glowColor: AppColors.gold,
                    label: _scenarioLabel,
                  ),

                  // Floating Hero (Left)
                  Positioned(
                    left: 0,
                    bottom: 20,
                    child: _FloatingBubble(
                      delay: 0,
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: CharacterPreview(
                          generatedAvatar: data.generatedAvatar,
                          placeholderEmoji: '👤',
                          showSparkles: false, // Orb has sparkles
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),

                  // Floating Companion (Right)
                  if (data.selectedCompanions.isNotEmpty)
                    Positioned(
                      right: 0,
                      bottom: 20,
                      child: _FloatingBubble(
                        delay: 1.5, // Offset animation
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _companionImage != null
                                ? Image.asset(_companionImage!, fit: BoxFit.cover)
                                : Container(
                                    color: AppColors.surface,
                                    child: Center(
                                      child: Text(
                                        _companionEmoji,
                                        style: const TextStyle(fontSize: 32),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 3. Magic Settings Ring (Toggle Pills)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MagicToggle(
                    icon: Icons.image,
                    label: 'Pics',
                    isActive: data.includeIllustrations,
                    onTap: () => setState(() => data.includeIllustrations = !data.includeIllustrations),
                  ),
                  const SizedBox(width: 12),
                  _MagicToggle(
                    icon: Icons.music_note,
                    label: 'Rhyme',
                    isActive: data.rhymeTimeMode,
                    onTap: () => setState(() {
                      data.rhymeTimeMode = !data.rhymeTimeMode;
                      if(data.rhymeTimeMode) {
                        data.learningToReadMode = false;
                        data.interactiveMode = false;
                      }
                    }),
                  ),
                  const SizedBox(width: 12),
                  _MagicToggle(
                    icon: Icons.menu_book,
                    label: 'Read for Fun',
                    isActive: data.learningToReadMode,
                    onTap: () => setState(() {
                      data.learningToReadMode = !data.learningToReadMode;
                      if(data.learningToReadMode) {
                        data.rhymeTimeMode = false;
                        data.interactiveMode = false;
                      }
                    }),
                  ),
                  const SizedBox(width: 12),
                  _MagicToggle(
                    icon: Icons.alt_route,
                    label: 'Pick Your Path',
                    isActive: data.interactiveMode,
                    onTap: () => setState(() {
                      data.interactiveMode = !data.interactiveMode;
                      if(data.interactiveMode) {
                        data.rhymeTimeMode = false;
                        data.learningToReadMode = false;
                      }
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 4. Length Selector (Clean)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  _LengthPill(label: 'Quick', val: 'quick', current: data.storyLength, onTap: (v) => setState(() => data.storyLength = v)),
                  _LengthPill(label: 'Standard', val: 'standard', current: data.storyLength, onTap: (v) => setState(() => data.storyLength = v)),
                  _LengthPill(label: 'Epic', val: 'epic', current: data.storyLength, onTap: (v) => setState(() => data.storyLength = v)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 5. Whisper Input (Custom)
            Stack(
              children: [
                TextField(
                  maxLines: 3,
                  onChanged: (value) => setState(() => data.customElements = value),
                  decoration: InputDecoration(
                    hintText: 'Whisper a wish to the orb...\n(e.g., "I want to ride a giant eagle")',
                    hintStyle: TextStyle(
                      color: AppColors.textDark.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                    ),
                    filled: true,
                    fillColor: AppColors.primary.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
                const Positioned(
                  right: 12,
                  bottom: 12,
                  child: Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 6. Cast Spell Button
            Center(
              child: _isGenerating
                  ? MagicalLoadingView(
                      status: _loadingStatus,
                      onCancel: () => setState(() => _isGenerating = false),
                    )
                  : MakeMagicButton(
                      onTap: _launchStoryCreation,
                      isEnabled: !_isGenerating && data.isComplete,
                      label: 'Make Some Magic', // Thematic label
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// --- Helper Widgets ---

class _FloatingBubble extends StatefulWidget {
  final Widget child;
  final double delay;

  const _FloatingBubble({required this.child, this.delay = 0});

  @override
  State<_FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<_FloatingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Add delay by starting at different value if needed, or using a listener
    // Simple offset logic:
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _controller.forward(); 
    });

    _animation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: widget.child,
        );
      },
    );
  }
}

class _MagicToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MagicToggle({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isActive ? AppColors.primary.withValues(alpha: 0.4) : Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isActive ? AppColors.gold : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? Colors.white : Colors.grey, size: 24),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LengthPill extends StatelessWidget {
  final String label;
  final String val;
  final String current;
  final Function(String) onTap;

  const _LengthPill({
    required this.label,
    required this.val,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = val == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
