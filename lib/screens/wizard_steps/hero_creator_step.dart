import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/archetype_card.dart';
import '../../widgets/character_preview.dart';
import '../../widgets/pill_button.dart';
import '../wizard_story_screen.dart';

/// Step 1: The Hero Creator
///
/// Layout:
/// - Top 50%: Large character preview with sparkles
/// - Bottom 50%: Archetype selection cards in horizontal scroll
/// - Continue button appears when archetype selected
class HeroCreatorStep extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onNext;
  final List<Character> availableCharacters;

  const HeroCreatorStep({
    super.key,
    required this.wizardData,
    required this.onNext,
    this.availableCharacters = const [],
  });

  @override
  State<HeroCreatorStep> createState() => _HeroCreatorStepState();
}

class _HeroCreatorStepState extends State<HeroCreatorStep> {
  String? _selectedArchetypeId;
  String _characterEmoji = '👧';

  void _selectArchetype(ArchetypeData archetype) {
    setState(() {
      _selectedArchetypeId = archetype.name;
      _characterEmoji = archetype.icon;

      // Auto-fill wizard data with archetype
      widget.wizardData.selectedArchetypeId = archetype.name;
      widget.wizardData.personalitySliders = Map.from(archetype.attributes);
      // Ensure default age is set if 0 or uninitialized
      if (widget.wizardData.characterAge < 1) {
        widget.wizardData.characterAge = 5; 
      }
      // widget.wizardData.characterName = archetype.name.replaceAll('The ', ''); // User requested to remove this
    });
  }

  bool get _canContinue => _selectedArchetypeId != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top 50%: Character Preview
        Expanded(
          child: CharacterPreview(
            placeholderEmoji: _characterEmoji,
            showSparkles: true,
          ),
        ),

        // Bottom 50%: Archetype Selection
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    'Create a Character',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Subtitle
                  Text(
                    'Choose an archetype to start',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textDark.withAlpha(179), // 70% opacity
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Archetype cards (horizontal scroll)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 200,
                      maxHeight: 240,
                    ),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      itemCount: CharacterArchetypes.all.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final archetype = CharacterArchetypes.all[index];
                        final isSelected = _selectedArchetypeId == archetype.name;

                        return ArchetypeCard(
                          icon: archetype.icon,
                          name: archetype.name,
                          description: archetype.description,
                          traits: archetype.traits,
                          isSelected: isSelected,
                          onUseTemplate: () => _selectArchetype(archetype),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),


                  const SizedBox(height: AppSpacing.xl),

                  // Name & Age Section
                  if (_canContinue) ...[
                    // Character Name
                    TextField(
                      controller: TextEditingController(text: widget.wizardData.characterName)
                        ..selection = TextSelection.fromPosition(TextPosition(offset: widget.wizardData.characterName.length)),
                      decoration: const InputDecoration(
                        labelText: 'Hero Name', 
                        hintText: 'e.g. Vivian or Lydia',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      onChanged: (v) {
                        widget.wizardData.characterName = v;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Gender Selection
                    Row(
                      children: [
                        Text('Gender:', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(width: AppSpacing.md),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Girl', label: Text('Girl'), icon: Icon(Icons.female)),
                            ButtonSegment(value: 'Boy', label: Text('Boy'), icon: Icon(Icons.male)),
                          ],
                          selected: {widget.wizardData.characterGender},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              widget.wizardData.characterGender = newSelection.first;
                            });
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Age Slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text('Age: ${widget.wizardData.characterAge}', 
                              style: Theme.of(context).textTheme.titleSmall),
                         const SizedBox(height: 8),
                         SizedBox(
                           height: 120,
                           child: CupertinoPicker(
                             itemExtent: 32,
                             onSelectedItemChanged: (index) {
                               setState(() {
                                 widget.wizardData.characterAge = index + 1;
                               });
                             },
                             scrollController: FixedExtentScrollController(initialItem: widget.wizardData.characterAge - 1),
                             children: List.generate(100, (index) => Center(
                               child: Text(
                                 '${index + 1}',
                                 style: const TextStyle(fontSize: 20, color: AppColors.textDark),
                               ),
                             )),
                           ),
                         ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Custom Pets Section
                  if (_canContinue)
                     _PetsSection(
                        wizardData: widget.wizardData,
                        onUpdate: () => setState(() {}),
                     ),
                  
                  if (_canContinue)
                     const SizedBox(height: AppSpacing.xl),

                  // Siblings/Friends Section
                  if (_canContinue)
                     _SiblingsSection(
                        wizardData: widget.wizardData,
                        onUpdate: () => setState(() {}),
                        availableCharacters: widget.availableCharacters
                            .where((c) => c.name != widget.wizardData.characterName)
                            .toList(),
                     ),

                  if (_canContinue)
                     const SizedBox(height: AppSpacing.xl),

                  // Continue button (only shown when archetype selected)
                  if (_canContinue)
                    AnimatedOpacity(
                      opacity: _canContinue ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: PillButton(
                        emoji: '➡️',
                        label: 'Continue',
                        onTap: widget.onNext,
                        variant: PillButtonVariant.purple,
                        isSelected: true,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PetsSection extends StatelessWidget {
  final WizardData wizardData;
  final VoidCallback onUpdate;

  const _PetsSection({required this.wizardData, required this.onUpdate});

  void _showAddPetDialog(BuildContext context) {
    final nameController = TextEditingController();
    String species = 'Dog';
    String personality = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Your Pet 🐾'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Pet Name', hintText: 'e.g. Spot'),
                  onChanged: (v) {
                    setState(() {}); // Rebuild to update button state
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: species,
                  items: ['Dog', 'Cat', 'Bird', 'Hamster', 'Fish', 'Bunny', 'Reptile', 'Other']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                     if (v != null) setState(() => species = v);
                  },
                  decoration: const InputDecoration(labelText: 'Species'),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'Personality / Fun Fact', 
                      hintText: 'e.g. Loves to chase tails'),
                  onChanged: (v) => personality = v,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: nameController.text.trim().isEmpty 
                    ? null 
                    : () {
                        wizardData.pets.add({
                          'name': nameController.text.trim(),
                          'species': species,
                          'personality': personality,
                        });
                        onUpdate();
                        Navigator.pop(context);
                      },
                child: const Text('Add Pet'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Pets',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
            ),
            TextButton.icon(
              onPressed: () => _showAddPetDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Pet'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        if (wizardData.pets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No pets added yet. Add one to join the adventure!',
              style: TextStyle(color: AppColors.textDark.withAlpha(128), fontStyle: FontStyle.italic, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: wizardData.pets.map((pet) {
              return Chip(
                avatar: Text(_getEmojiForSpecies(pet['species'])),
                label: Text(pet['name'] ?? ''),
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.primary.withAlpha(50)),
                onDeleted: () {
                   wizardData.pets.remove(pet);
                   onUpdate();
                },
              );
            }).toList(),
          ),
      ],
    );
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

}

class _SiblingsSection extends StatelessWidget {
  final WizardData wizardData;
  final VoidCallback onUpdate;
  final List<Character> availableCharacters;

  const _SiblingsSection({
    required this.wizardData,
    required this.onUpdate,
    this.availableCharacters = const [],
  });

  void _showAddDialog(BuildContext context) {
    String name = '';
    String role = 'Friend';
    int age = wizardData.characterAge;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Friend or Sibling 👫'),
            content: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 TextField(
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Sam'),
                  onChanged: (v) => name = v,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  items: ['Friend', 'Brother', 'Sister', 'Cousin', 'Classmate', 'Neighbor']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => role = v!),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 12),
                // Age selector with both wheel and direct input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Age:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Direct age input
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Type age',
                              hintText: '1-99',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null && parsed >= 1 && parsed <= 99) {
                                setState(() => age = parsed);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text('or scroll →'),
                        const SizedBox(width: 8),
                        // Wheel picker with visible border
                        Container(
                          width: 80,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary, width: 2),
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.surface.withAlpha(128),
                          ),
                          child: Stack(
                            children: [
                              // Selection indicator line
                              Positioned(
                                top: 40,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(51),
                                    border: Border(
                                      top: BorderSide(color: AppColors.primary, width: 2),
                                      bottom: BorderSide(color: AppColors.primary, width: 2),
                                    ),
                                  ),
                                ),
                             SizedBox(
                         height: 100,
                         child: CupertinoPicker(
                           itemExtent: 32,
                           scrollController: FixedExtentScrollController(initialItem: age - 1),
                           onSelectedItemChanged: (index) {
                             setState(() => age = index + 1);
                           },
                           children: List.generate(100, (index) => Center(
                             child: Text(
                               '${index + 1}',
                               style: const TextStyle(fontSize: 18, color: AppColors.textDark),
                             ),
                           )),
                         ),
                       ),     ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Selected: $age years old',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
               ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (name.isNotEmpty) {
                     // Format: "Name (Role, Age)"
                     wizardData.additionalCharacters.add('$name ($role, $age)');
                     onUpdate();
                     Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _addExistingCharacter(Character character) {
    wizardData.additionalCharacters.add('${character.name} (${character.role}, ${character.age})');
    onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Friends & Siblings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                 // Existing Character Dropdown (Popup Menu)
                 if (availableCharacters.isNotEmpty)
                   PopupMenuButton<Character>(
                     icon: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
                     tooltip: 'Add existing character',
                     onSelected: _addExistingCharacter,
                     itemBuilder: (context) {
                       return availableCharacters
                        .where((c) => !wizardData.additionalCharacters.any((added) => added.startsWith(c.name)))
                        .map((c) => PopupMenuItem(
                           value: c,
                           child: Text('${c.name} (${c.role})'),
                        )).toList();
                     },
                   ),
                 
                 TextButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create New'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
        if (wizardData.additionalCharacters.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Who else is in the story? Add friends or siblings.',
              style: TextStyle(color: AppColors.textDark.withAlpha(128), fontStyle: FontStyle.italic, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: wizardData.additionalCharacters.map((name) {
              return Chip(
                avatar: const Text('👤'),
                label: Text(name),
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.primary.withAlpha(50)),
                onDeleted: () {
                   wizardData.additionalCharacters.remove(name);
                   onUpdate();
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}

