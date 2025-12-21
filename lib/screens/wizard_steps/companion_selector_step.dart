import 'package:flutter/material.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pill_button.dart';
import '../wizard_story_screen.dart';
import '../../data/companion_data.dart';

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
      if (char.role != null && char.role!.isNotEmpty && char.role != 'Hero') {
        description = char.role!;
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
      ),
      Companion(
        id: 'owl',
        emoji: '🦉',
        name: 'a wise owl',
        color: AppColors.owlBlue,
        greeting: 'Let\'s be wise together!',
        description: '✨ Can see through time to show what will happen',
      ),
      Companion(
        id: 'cat',
        emoji: '🐱',
        name: 'a shadow cat',
        color: AppColors.catPurple,
        greeting: 'Meow! I\'m ready!',
        description: '✨ Walks through walls and brings things from dreams',
      ),
      Companion(
        id: 'dog',
        emoji: '🐕',
        name: 'a star dog',
        color: AppColors.dogBrown,
        greeting: 'I\'ll be your best friend!',
        description: '✨ Barks constellations into existence to guide the way',
      ),
      Companion(
        id: 'unicorn',
        emoji: '🦄',
        name: 'a magic unicorn',
        color: AppColors.primaryLight,
        greeting: 'Let\'s make magic!',
        description: '✨ Creates bridges made of starlight and moonbeams',
      ),
      Companion(
        id: 'fox',
        emoji: '🦊',
        name: 'a clever fox',
        color: AppColors.gold,
        greeting: 'Ready for clever fun!',
        description: '✨ Transforms into any shape to solve impossible puzzles',
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

  // Combined list for general display if needed, though we split them in UI
  List<Companion> get _companions => [..._savedCharacterCompanions, ..._magicalCompanions];

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
  
  List<Companion> get _allCompanions => _companions; // Alias for internal use if needed

  void _selectAll() {
    setState(() {
      final allCompanions = _allCompanions;
      if (_selectedCompanions.length == allCompanions.length) {
        // Deselect all
        _selectedCompanions.clear();
        widget.wizardData.selectedCompanions.clear();
        widget.wizardData.companionNames.clear();
      } else {
        // Select all
        _selectedCompanions.clear();
        widget.wizardData.selectedCompanions.clear();
        widget.wizardData.companionNames.clear();

        for (var c in allCompanions) {
          _selectedCompanions.add(c.id);
          widget.wizardData.selectedCompanions.add(c.id);
          widget.wizardData.companionNames.add(c.name);
        }
      }
    });
  }

  bool get _canContinue => true; // Optional step

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
                    color: AppColors.textDark.withOpacity(0.7),
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
            }).toList(),

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
                  onPressed: widget.onNext,
                  child: Text(
                    'Go Solo (Be Brave!)',
                    style: TextStyle(
                      color: AppColors.textDark.withOpacity(0.6),
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

  Companion({
    required this.id,
    required this.emoji,
    required this.name,
    required this.color,
    required this.greeting,
    this.description = '',
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
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected 
                ? Colors.white.withValues(alpha: 0.85) 
                : Colors.white.withValues(alpha: 0.5), // Glassmorphic base
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.goldLight.withValues(alpha: 0.4),
                      Colors.white.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.6),
                      Colors.white.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.6),
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Avatar / Emoji
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withValues(alpha: 0.9) 
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Center(
                  child: Text(
                    companion.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companion.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isMagical)
                          const Icon(Icons.auto_awesome, size: 14, color: AppColors.purple),
                        if (isMagical) const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            companion.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textDark.withOpacity(0.7),
                                  fontStyle: FontStyle.italic,
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

              // Selection Checkmark
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
