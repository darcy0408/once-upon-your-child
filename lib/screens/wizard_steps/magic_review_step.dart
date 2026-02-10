import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/achievement_service.dart';
import 'package:story_weaver_app/story_result_screen.dart';
import 'package:story_weaver_app/pick_a_path_adventure_screen.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/widgets/make_magic_button.dart';
import 'package:story_weaver_app/widgets/magic_orb.dart';
import 'package:story_weaver_app/widgets/magical_loading_view.dart';
import 'package:story_weaver_app/data/scenario_data.dart';
import 'package:story_weaver_app/data/companion_data.dart';
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
  String _loadingStatus = 'Creating your story...';

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
      if (e.toString().contains('500')) {
        userMessage = 'Server error. The magic faded.';
      } else if (e.toString().contains('timeout')) {
        userMessage = 'Story took too long.';
      }
      
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
    final screenWidth = MediaQuery.of(context).size.width;
    final orbSize = (screenWidth - 64).clamp(180.0, 250.0);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
        child: Column(
          children: [
            // 1. Crystal progress orbs
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ProgressCrystal(icon: Icons.check_rounded),
                SizedBox(width: 10),
                _ProgressCrystal(icon: Icons.check_rounded),
                SizedBox(width: 10),
                _ProgressCrystal(icon: Icons.check_rounded),
                SizedBox(width: 10),
                _ProgressCrystal(icon: Icons.auto_awesome),
              ],
            ),
            const SizedBox(height: 18),

            // 2. Vision Orb + circular side avatars
            SizedBox(
              height: 290,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Orb aura
                  Container(
                    width: orbSize + 18,
                    height: orbSize + 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFEEA8).withValues(alpha: 0.25),
                          const Color(0xFFE985FF).withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),

                  // Center crystal orb
                  MagicOrbWidget(
                    imagePath: _scenarioImage,
                    size: orbSize,
                    glowColor: AppColors.gold,
                    label: _scenarioLabel,
                  ),

                  // Hero avatar
                  Positioned(
                    left: 10,
                    bottom: 30,
                    child: _FloatingBubble(
                      delay: 0,
                      child: _AuraCircle(
                        size: 88,
                        auraColor: const Color(0xFFFFD9A6),
                        child: _HeroAvatar(generatedAvatar: data.generatedAvatar),
                      ),
                    ),
                  ),

                  // Companion avatar
                  if (data.selectedCompanions.isNotEmpty)
                    Positioned(
                      right: 10,
                      bottom: 30,
                      child: _FloatingBubble(
                        delay: 1.4,
                        child: _AuraCircle(
                          size: 88,
                          auraColor: const Color(0xFFF3AEFF),
                          child: _CompanionAvatar(
                            companionImage: _companionImage,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 3. Crystal mode orbs
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 12,
              children: [
                _CrystalModeOrb(
                  icon: Icons.auto_stories_rounded,
                  label: 'Tales',
                  isActive: data.includeIllustrations,
                  onTap: () => setState(() => data.includeIllustrations = !data.includeIllustrations),
                ),
                _CrystalModeOrb(
                  icon: Icons.music_note_rounded,
                  label: 'Rhyme',
                  isActive: data.rhymeTimeMode,
                  onTap: () => setState(() {
                    data.rhymeTimeMode = !data.rhymeTimeMode;
                    if (data.rhymeTimeMode) {
                      data.learningToReadMode = false;
                      data.interactiveMode = false;
                    }
                  }),
                ),
                _CrystalModeOrb(
                  icon: Icons.menu_book_rounded,
                  label: 'Spellbound Reading',
                  isActive: data.learningToReadMode,
                  onTap: () => setState(() {
                    data.learningToReadMode = !data.learningToReadMode;
                    if (data.learningToReadMode) {
                      data.rhymeTimeMode = false;
                      data.interactiveMode = false;
                    }
                  }),
                ),
                _CrystalModeOrb(
                  icon: Icons.alt_route_rounded,
                  label: 'Pick Your Path',
                  isActive: data.interactiveMode,
                  onTap: () => setState(() {
                    data.interactiveMode = !data.interactiveMode;
                    if (data.interactiveMode) {
                      data.rhymeTimeMode = false;
                      data.learningToReadMode = false;
                    }
                  }),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 4. Floating story-length crystals
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 14,
              children: [
                _LengthCrystal(
                  label: 'Quick',
                  val: 'quick',
                  current: data.storyLength,
                  onTap: (v) => setState(() => data.storyLength = v),
                  crystalColors: const [Color(0xFF8EEDFF), Color(0xFFB5F7FF), Color(0xFFE8FEFF)],
                ),
                _LengthCrystal(
                  label: 'Classic',
                  val: 'standard',
                  current: data.storyLength,
                  onTap: (v) => setState(() => data.storyLength = v),
                  crystalColors: const [Color(0xFFFFD65C), Color(0xFFFFEBA5), Color(0xFFFFF7D6)],
                ),
                _LengthCrystal(
                  label: 'Epic',
                  val: 'epic',
                  current: data.storyLength,
                  onTap: (v) => setState(() => data.storyLength = v),
                  crystalColors: const [Color(0xFF9E6CFF), Color(0xFFCBB1FF), Color(0xFFE5DAFF)],
                ),
              ],
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

class _ProgressCrystal extends StatelessWidget {
  final IconData icon;

  const _ProgressCrystal({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFE8D6FF), Color(0xFF9E75E0), Color(0xFF6A3AA9)],
          stops: [0.1, 0.65, 1.0],
        ),
        border: Border.all(color: const Color(0xFFE6D9FF), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x66A65BFF), blurRadius: 12, spreadRadius: 1),
          BoxShadow(color: Color(0x55FFD878), blurRadius: 16, spreadRadius: -2),
        ],
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}

class _AuraCircle extends StatelessWidget {
  final double size;
  final Color auraColor;
  final Widget child;

  const _AuraCircle({
    required this.size,
    required this.auraColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: auraColor.withValues(alpha: 0.55),
            blurRadius: 26,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFFFE4B8).withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  final GeneratedAvatar? generatedAvatar;

  const _HeroAvatar({required this.generatedAvatar});

  @override
  Widget build(BuildContext context) {
    if (generatedAvatar == null) {
      return const _GradientSphereFallback(
        child: Icon(Icons.face_rounded, color: Colors.white, size: 32),
      );
    }

    final imageData = generatedAvatar!.imageBase64;
    final isUrl = imageData.startsWith('http://') || imageData.startsWith('https://');
    final isAsset = imageData.startsWith('assets/');

    return ClipOval(
      child: isAsset
          ? Image.asset(
              imageData,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _GradientSphereFallback(
                child: Icon(Icons.face_rounded, color: Colors.white, size: 32),
              ),
            )
          : isUrl
              ? Image.network(
                  imageData,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _GradientSphereFallback(
                    child: Icon(Icons.face_rounded, color: Colors.white, size: 32),
                  ),
                )
              : Image.memory(
                  base64Decode(imageData.split(',').last),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _GradientSphereFallback(
                    child: Icon(Icons.face_rounded, color: Colors.white, size: 32),
                  ),
                ),
    );
  }
}

class _CompanionAvatar extends StatelessWidget {
  final String? companionImage;

  const _CompanionAvatar({
    required this.companionImage,
  });

  @override
  Widget build(BuildContext context) {
    if (companionImage == null) {
      return const _GradientSphereFallback(
        child: Icon(Icons.pets_rounded, color: Colors.white, size: 30),
      );
    }

    return ClipOval(
      child: Image.asset(
        companionImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _GradientSphereFallback(
          child: Icon(Icons.pets_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

class _GradientSphereFallback extends StatelessWidget {
  final Widget child;

  const _GradientSphereFallback({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFFFFF3D6), Color(0xFFEAA6FF), Color(0xFFAA7CEB)],
          stops: [0.1, 0.6, 1.0],
        ),
      ),
      child: Center(child: child),
    );
  }
}

class _CrystalModeOrb extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CrystalModeOrb({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const inactiveText = Color(0xFF2F2748);
    final activeGlow = const Color(0xFFE28EFF);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: isActive ? 1.1 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFEFE6FF), Color(0xFFB6A8F8), Color(0xFF7A5CC8)],
                    stops: [0.08, 0.62, 1.0],
                  ),
                  border: Border.all(
                    color: isActive ? const Color(0xFFFFE8A0) : const Color(0xFFC8B3F3),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isActive ? activeGlow : const Color(0xFF9D8CEB)).withValues(alpha: 0.55),
                      blurRadius: isActive ? 24 : 14,
                      spreadRadius: isActive ? 3 : 0,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFE9B0).withValues(alpha: isActive ? 0.55 : 0.25),
                      blurRadius: isActive ? 18 : 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : inactiveText,
                  size: 29,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 1.1,
                color: const Color(0xFF2D2148),
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _LengthCrystal extends StatelessWidget {
  final String label;
  final String val;
  final String current;
  final Function(String) onTap;
  final List<Color> crystalColors;

  const _LengthCrystal({
    required this.label,
    required this.val,
    required this.current,
    required this.onTap,
    required this.crystalColors,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = val == current;
    return GestureDetector(
      onTap: () => onTap(val),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        scale: isSelected ? 1.1 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 92,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: crystalColors,
              stops: const [0.08, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: isSelected ? Colors.white : const Color(0xCCFFFFFF),
              width: isSelected ? 2.2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: crystalColors[0].withValues(alpha: isSelected ? 0.7 : 0.35),
                blurRadius: isSelected ? 24 : 12,
                spreadRadius: isSelected ? 4 : 0,
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF2A2040),
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              fontSize: 18,
              shadows: isSelected
                  ? const [
                      Shadow(
                        color: Color(0x66FFFFFF),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
