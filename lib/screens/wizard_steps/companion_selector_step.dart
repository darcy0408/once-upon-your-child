import 'package:flutter/material.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pill_button.dart';

/// Step 3: The Adventure Team Selector
///
/// Layout:
/// - Shows saved characters (friends/family) at top
/// - Grid of magical creature companions below
/// - Multi-select: can choose characters + magical companions
/// - Each companion has animation on tap
/// - Selected companions get gold glowing aura
/// - Continue button
class CompanionSelectorStep extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onNext;
  final List<Character> savedCharacters;

  const CompanionSelectorStep({
    super.key,
    required this.wizardData,
    required this.onNext,
    this.savedCharacters = const [],
  });

  @override
  State<CompanionSelectorStep> createState() => _CompanionSelectorStepState();
}

class _CompanionSelectorStepState extends State<CompanionSelectorStep> {
  // Use a Set for multi-selection
  final Set<String> _selectedCompanions = {};
  final bool _isLoading = false; // Added state variable

  List<Companion> get _savedCharacterCompanions {
    // Convert saved characters to companions (friends/family)
    return widget.savedCharacters.where((char) {
      // Don't include the main character as a companion
      return char.name != widget.wizardData.characterName;
    }).map((char) {
      // Show personalized description based on character's actual data
      String description = '${char.age} years old';

      // Only show data that was actually entered by the user
      if (char.role.isNotEmpty && char.role != 'Hero') {
        description = char.role;
      } else if (char.personalityTraits?.isNotEmpty == true) {
        description = char.personalityTraits!.join(', ');
      } else {
        // Just show age if no other data was entered
        description = 'Age ${char.age}';
      }

      return Companion(
        id: 'character_${char.id}',
        emoji: _getEmojiForAge(char.age),
        name: char.name,
        color: AppColors.gold,
        greeting: 'Let\'s have an adventure!',
        description: description,
      );
    }).toList();
  }

  String _getEmojiForAge(int age) {
    if (age <= 5) return '👶';
    if (age <= 12) return '🧒';
    if (age <= 18) return '👦';
    if (age <= 60) return '👨';
    return '👴';
  }

  List<Companion> get _magicalCompanions {
    final defaultCompanions = [
      Companion(
        id: 'dragon',
        emoji: '🐉',
        name: 'a tiny dragon',
        color: AppColors.dragonOrange,
        greeting: 'I\'m ready to help!',
        description: '✨ Breathes rainbow fire that reveals hidden paths',
        imagePath: 'assets/images/companions/dragon.jpg',
      ),
      Companion(
        id: 'owl',
        emoji: '🦉',
        name: 'a wise owl',
        color: AppColors.owlBlue,
        greeting: 'Let\'s be wise together!',
        description: '✨ Can see through time to show what will happen',
        imagePath: 'assets/images/companions/owl.jpg',
      ),
      Companion(
        id: 'cat',
        emoji: '🐱',
        name: 'a shadow cat',
        color: AppColors.catPurple,
        greeting: 'Meow! I\'m ready!',
        description: '✨ Walks through walls and brings things from dreams',
        imagePath: 'assets/images/companions/cat.jpg',
      ),
      Companion(
        id: 'dog',
        emoji: '🐕',
        name: 'a star dog',
        color: AppColors.dogBrown,
        greeting: 'I\'ll be your best friend!',
        description: '✨ Barks constellations into existence to guide the way',
        imagePath: 'assets/images/companions/dog.jpg',
      ),
      Companion(
        id: 'unicorn',
        emoji: '🦄',
        name: 'a magic unicorn',
        color: AppColors.primaryLight,
        greeting: 'Let\'s make magic!',
        description: '✨ Creates bridges made of starlight and moonbeams',
        imagePath: 'assets/images/companions/unicorn.jpg',
      ),
      Companion(
        id: 'fox',
        emoji: '🦊',
        name: 'a clever fox',
        color: AppColors.gold,
        greeting: 'Ready for clever fun!',
        description: '✨ Transforms into any shape to solve impossible puzzles',
        imagePath: 'assets/images/companions/fox.jpg',
      ),
      Companion(
        id: 'robin',
        emoji: '🐦',
        name: 'a rockin\' robin',
        color: AppColors.dragonOrange,
        greeting: 'Let\'s rock and roll!',
        description: '✨ Plays magical music that makes everyone dance with joy',
        imagePath: 'assets/images/companions/robin.jpg',
      ),
    ];

    final customPets = widget.wizardData.pets.map((pet) => Companion(
      id: pet['name']!,
      emoji: _getEmojiForSpecies(pet['species']),
      name: pet['name']!,
      color: AppColors.primary,
      greeting: pet['personality']?.isNotEmpty == true ? pet['personality']! : 'I am your ${pet['species']}!',
      description: 'Your faithful ${pet['species']} companion',
    )).toList();

    return [...customPets, ...defaultCompanions];
  }

  String _getEmojiForSpecies(String? species) {
    switch (species) {
      case 'Dog': return '🐕';
      case 'Cat': return '🐱';
      case 'Bird': return '🐦';
      case 'Hamster': return '🐹';
      case 'Fish': return '🐠';
      case 'Bunny': return '🐰';
      case 'Reptile': return '🦎';
      default: return '🐾';
    }
  }

  void _toggleCompanion(Companion companion) {
    setState(() {
      if (_selectedCompanions.contains(companion.id)) {
        _selectedCompanions.remove(companion.id);
        
        // Remove from wizardData
        widget.wizardData.selectedCompanions.remove(companion.id);
        if (widget.wizardData.companionNames.contains(companion.name)) {
             widget.wizardData.companionNames.remove(companion.name);
        }
      } else {
        _selectedCompanions.add(companion.id);
        
        // Add to wizardData
        if (!widget.wizardData.selectedCompanions.contains(companion.id)) {
            widget.wizardData.selectedCompanions.add(companion.id);
            widget.wizardData.companionNames.add(companion.name);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging for missing companions
    if (_savedCharacterCompanions.isEmpty && widget.savedCharacters.isNotEmpty) {
      debugPrint('🔍 CompanionSelectorStep: Received ${widget.savedCharacters.length} saved characters');
      debugPrint('🔍 CompanionSelectorStep: Showing ${_savedCharacterCompanions.length} companions after filtering');
      debugPrint('⚠️ WARNING: Characters hidden by filter! Current Hero: ${widget.wizardData.characterName}');
      for(var c in widget.savedCharacters) {
         debugPrint('   - Hidden Candidate: ${c.name}, ID: ${c.id}');
      }
    } else if (widget.savedCharacters.isNotEmpty) {
       debugPrint('✅ CompanionSelectorStep: Showing ${_savedCharacterCompanions.length}/${widget.savedCharacters.length} characters.');
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'Choose a Travel Buddy',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Who will join you on this adventure?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textDark.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // 1. Saved Characters (Friends)
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_savedCharacterCompanions.isNotEmpty) ...[ 
              Text(
                'Your Friends',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _savedCharacterCompanions.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final companion = _savedCharacterCompanions[index];
                  final isSelected =
                      _selectedCompanions.contains(companion.id); // Fixed: set contains check
                  return _CompanionCard(
                    companion: companion,
                    isSelected: isSelected,
                    onTap: () => _toggleCompanion(companion),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // 2. Magical Creatures (Presets)
            Text(
              'Magical Creatures',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            ..._magicalCompanions.map((creature) {
              final isSelected =
                  _selectedCompanions.contains(creature.id); // Fixed: set contains check
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _CompanionCard(
                  companion: creature,
                  isSelected: isSelected,
                  onTap: () => _toggleCompanion(creature),
                  isMagical: true,
                ),
              );
            }),

            const SizedBox(height: AppSpacing.xxl),

            // Navigation
            if (_selectedCompanions.isNotEmpty)
              Center(
                child: PillButton(
                  emoji: '✨',
                  label: 'Gather Party!',
                  onTap: widget.onNext,
                  variant: PillButtonVariant.purple,
                  isSelected: true,
                ),
              )
            else
              Center(
                child: TextButton(
                  key: const Key('go_solo_button'),
                  onPressed: widget.onNext,
                  child: Text(
                    'Go Solo (Be Brave!)',
                    style: TextStyle(
                      color: AppColors.textDark.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class Companion {
  final String id;
  final String emoji;
  final String name;
  final Color color;
  final String greeting;
  final String description;
  final String? imagePath;

  Companion({
    required this.id,
    required this.emoji,
    required this.name,
    required this.color,
    required this.greeting,
    this.description = '',
    this.imagePath,
  });
}

class _CompanionCard extends StatelessWidget {
  final Companion companion;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isMagical;

  const _CompanionCard({
    required this.companion,
    required this.isSelected,
    required this.onTap,
    this.isMagical = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = companion.imagePath != null;
    final isGlowing = isSelected || isMagical;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Select ${companion.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.6),
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      blurRadius: 22,
                      spreadRadius: 3,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: isGlowing
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: isGlowing ? 14 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl - 2),
            child: Stack(
              children: [
                // Background image or gradient
                if (hasImage)
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: Image.asset(
                      companion.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: companion.color.withValues(alpha: 0.2),
                          child: Center(
                            child: Text(
                              companion.emoji,
                              style: const TextStyle(fontSize: 48),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.35),
                          companion.color.withValues(alpha: 0.25),
                          AppColors.primaryLight.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        companion.emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                if (isMagical)
                  Positioned.fill(
                    child: Opacity(
                      opacity: isSelected ? 0.28 : 0.18,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              AppColors.goldLight,
                              Colors.transparent,
                            ],
                            radius: 1.2,
                            center: Alignment(-0.6, -0.8),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Gradient overlay for text readability
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          companion.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  const Shadow(
                                    blurRadius: 4,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (isMagical)
                              const Icon(Icons.auto_awesome, size: 12, color: AppColors.gold),
                            if (isMagical) const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                companion.description,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Selection indicator overlay
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 18),
                    ),
                  ),
                if (isSelected)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: AppColors.gold.withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
