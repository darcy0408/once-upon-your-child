import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/archetype_card.dart';
import '../../widgets/character_preview.dart';
import '../../widgets/pill_button.dart';
import '../wizard_story_screen.dart';
import '../../services/api_service_manager.dart';
import '../../models/generated_avatar.dart';
import '../../widgets/avatar_gallery_selector.dart';
import '../../services/avatar_generation_state.dart';

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
  late TextEditingController _nameController;
  Character? _selectedExistingCharacter;
  bool _isCreatingNew = true; // Toggle between creating new vs selecting existing
  GeneratedAvatar? _generatedAvatar; // AI-generated avatar

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wizardData.characterName);

    // Listen for completed avatar from background generation
    AvatarGenerationState().addListener(_onAvatarStateChanged);

    // If wizard data already has a characterId, try to find and select it
    if (widget.wizardData.characterId != null && widget.availableCharacters.isNotEmpty) {
      _selectedExistingCharacter = widget.availableCharacters.firstWhere(
        (c) => c.id == widget.wizardData.characterId,
        orElse: () => widget.availableCharacters.first,
      );
      if (_selectedExistingCharacter != null) {
        _isCreatingNew = false;
        _loadExistingCharacter(_selectedExistingCharacter!);
      }
    } else if (widget.availableCharacters.isNotEmpty) {
      // Default to selecting existing if user has characters
      _isCreatingNew = false;
    }
  }

  void _onAvatarStateChanged() {
    final state = AvatarGenerationState();

    // If avatar completed and not already consumed, apply it
    if (state.completedAvatar != null && _generatedAvatar == null) {
      setState(() {
        _generatedAvatar = state.completedAvatar;
        widget.wizardData.generatedAvatar = state.completedAvatar;
      });

      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Your avatar is ready!'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Consume the avatar so it doesn't get applied again
      state.consumeAvatar();
    }
  }

  @override
  void didUpdateWidget(HeroCreatorStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If characters loaded and we were in "create new" mode without explicit selection
    // AND the user hasn't typed anything yet, switch to "My Heroes"
    if (widget.availableCharacters.isNotEmpty &&
        oldWidget.availableCharacters.isEmpty &&
        _isCreatingNew &&
        widget.wizardData.characterId == null &&
        _nameController.text.isEmpty) {
      setState(() {
        _isCreatingNew = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    AvatarGenerationState().removeListener(_onAvatarStateChanged);
    super.dispose();
  }

  void _loadExistingCharacter(Character character) {
    try {
      setState(() {
        _isCreatingNew = false;
        _selectedExistingCharacter = character;
        widget.wizardData.characterId = character.id;
        widget.wizardData.characterName = character.name;
        widget.wizardData.characterAge = character.age;
        widget.wizardData.characterGender = character.gender ?? 'Girl';
        widget.wizardData.selectedArchetypeId = character.role;
        _selectedArchetypeId = character.role;
        _nameController.text = character.name;

        // Load existing pets with validation
        if (character.pets != null) {
          final safePets = <Map<String, String>>[];
          for (var p in character.pets!) {
            try {
               // Ensure p is a map and convert contents to strings safely
               safePets.add(Map<String, String>.from(p));
                         } catch (e) {
              debugPrint('Warning: Skipping invalid pet data: $p ($e)');
            }
          }
          widget.wizardData.pets = safePets;
        }

        // Load friends with validation
        if (character.friends != null) {
           widget.wizardData.additionalCharacters = [];
           for (var f in character.friends!) {
             widget.wizardData.additionalCharacters.add(f);
                      }
        }

        if (character.personalitySliders != null) {
        widget.wizardData.personalitySliders = Map<String, int>.from(character.personalitySliders!);
      }

      // Set emoji based on role
      if (character.role.contains('Adventurer')) {
        _characterEmoji = '🗺️';
      } else if (character.role.contains('Thinker')) {
        _characterEmoji = '💭';
      } else if (character.role.contains('Artist')) {
        _characterEmoji = '🎨';
      } else if (character.role.contains('Helper')) {
        _characterEmoji = '🤝';
      } else if (character.role.contains('Athlete')) {
        _characterEmoji = '⚡';
      } else {
        _characterEmoji = '👧';
      }
      });
    } catch (e, stack) {
      debugPrint('❌ Error loading character: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load character: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Auto-save the character when pets are modified
  Future<void> _autoSaveCharacter() async {
    // Only auto-save if we have a character ID (existing character)
    if (widget.wizardData.characterId == null) {
      debugPrint('[Hero Creator] Skipping auto-save - no character ID yet');
      return;
    }

    try {
      debugPrint('[Hero Creator] Auto-saving character pets...');
      final body = {
        'name': widget.wizardData.characterName,
        'age': widget.wizardData.characterAge,
        'gender': widget.wizardData.characterGender,
        'role': widget.wizardData.selectedArchetypeId,
        'pets': widget.wizardData.pets,
        'friends': widget.wizardData.additionalCharacters,
      };

      final api = ApiServiceManager();
      await api.patch('/characters/${widget.wizardData.characterId}', body);
      debugPrint('[Hero Creator] Auto-save successful - pets saved!');
    } catch (e) {
      debugPrint('[Hero Creator] Auto-save failed: $e');
    }
  }

  void _switchToNewCharacter() {
    setState(() {
      _isCreatingNew = true;
      _selectedExistingCharacter = null;
      widget.wizardData.characterId = null;
      widget.wizardData.characterName = '';
      widget.wizardData.characterAge = 8;
      _selectedArchetypeId = null;
      _nameController.clear();
      _characterEmoji = '👧';
      widget.wizardData.pets = [];
      widget.wizardData.additionalCharacters = [];
    });
  }



  void _selectArchetype(ArchetypeData archetype) {
    setState(() {
      _selectedArchetypeId = archetype.name;
      _characterEmoji = archetype.icon ?? '✨';

      // Auto-fill wizard data with archetype
      widget.wizardData.selectedArchetypeId = archetype.name;
      widget.wizardData.personalitySliders = Map<String, int>.from(archetype.attributes);
      // Ensure default age is set if 0 or uninitialized
      if (widget.wizardData.characterAge < 1) {
        widget.wizardData.characterAge = 5;
      }
      // widget.wizardData.characterName = archetype.name.replaceAll('The ', ''); // User requested to remove this
    });
  }

  void _showAvatarCreator() {
    debugPrint('🎨 Opening avatar gallery for ${widget.wizardData.characterName}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AvatarGallerySelector(
        onCancel: () {
          debugPrint('❌ Avatar selection cancelled');
          Navigator.pop(context);
        },
        onAvatarSelected: (avatar) {
          debugPrint('✅ Avatar selected from gallery');
          setState(() {
            _generatedAvatar = avatar;
            widget.wizardData.generatedAvatar = avatar; // Save to wizard data
          });
          Navigator.pop(context);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar selected! It will appear in your stories!'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _saveCharacterDraft() async {
    if (!_isCreatingNew || !_canContinue) {
      return true;
    }

    try {
      final body = {
        'name': widget.wizardData.characterName,
        'age': widget.wizardData.characterAge,
        'gender': widget.wizardData.characterGender,
        'role': widget.wizardData.selectedArchetypeId,
        'character_type': 'Everyday Kid',
        'character_style': 'Regular Kid',
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
      return true;
    } catch (e) {
      debugPrint('⚠️ Character save failed in Hero Creator: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save character: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _handleContinue() async {
    final ok = await _saveCharacterDraft();
    if (ok) {
      widget.onNext();
    }
  }

  Widget _buildAvatarThumb(Character character, {required bool isSelected}) {
    const size = 64.0;
    final borderColor = isSelected ? AppColors.gold : AppColors.primary.withAlpha(100);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: isSelected ? 3 : 2),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.gold.withAlpha(128),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: _buildAvatarImage(character),
      ),
    );
  }

  Widget _buildAvatarImage(Character character) {
    final generated = character.generatedAvatar;
    if (generated != null && generated.imageBase64.isNotEmpty) {
      final data = generated.imageBase64;
      final isUrl = data.startsWith('http://') || data.startsWith('https://');
      final isAsset = data.startsWith('assets/');
      if (isAsset) {
        return Image.asset(data, fit: BoxFit.cover);
      }
      if (isUrl) {
        return Image.network(data, fit: BoxFit.cover);
      }
      try {
        return Image.memory(base64Decode(data.split(',').last), fit: BoxFit.cover);
      } catch (_) {
        return _buildAvatarEmoji(character);
      }
    }

    if (character.avatar != null) {
      return Image.network(
        character.avatar!.toAvataaarsUrl(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAvatarEmoji(character),
      );
    }

    return _buildAvatarEmoji(character);
  }

  Widget _buildAvatarEmoji(Character character) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Text(
          _getEmojiForCharacter(character),
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }

  bool get _canContinue => _selectedArchetypeId != null && widget.wizardData.characterName.trim().isNotEmpty;

  String _getEmojiForCharacter(Character character) {
    final role = character.role;
    if (role.contains('Adventurer')) return '🗺️';
    if (role.contains('Thinker')) return '💭';
    if (role.contains('Artist')) return '🎨';
    if (role.contains('Helper')) return '🤝';
    if (role.contains('Athlete')) return '⚡';
    if (role.contains('Shy')) return '😊';
    // Default based on gender
    if (character.gender == 'Boy') return '👦';
    return '👧';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top 40%: Character Preview
        Expanded(
          flex: 2,
          child: CharacterPreview(
            generatedAvatar: _generatedAvatar,
            placeholderEmoji: _characterEmoji,
            showSparkles: true,
          ),
        ),

        // Bottom 60%: Archetype Selection
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,

              vertical: AppSpacing.md, // Reduced from XL
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    _isCreatingNew ? 'Create a Character' : 'Select Your Hero',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Saved Characters Section (if any exist)
                  if (widget.availableCharacters.isNotEmpty) ...[
                    Text(
                      'Choose your hero or create a new one',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textDark.withAlpha(179),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        itemCount: widget.availableCharacters.length + 1,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          if (index == widget.availableCharacters.length) {
                            final isSelected = _isCreatingNew;
                            return GestureDetector(
                              onTap: _switchToNewCharacter,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? AppColors.gold : AppColors.primary.withAlpha(100),
                                        width: isSelected ? 3 : 2,
                                      ),
                                      color: AppColors.surface,
                                    ),
                                    child: const Icon(Icons.add, color: AppColors.primary, size: 28),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create New',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final character = widget.availableCharacters[index];
                          final isSelected = _selectedExistingCharacter?.id == character.id && !_isCreatingNew;

                          return GestureDetector(
                            onTap: () => _loadExistingCharacter(character),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildAvatarThumb(character, isSelected: isSelected),
                                const SizedBox(height: 8),
                                Text(
                                  character.name,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Character Name (only editable when creating new)
                  if (_isCreatingNew)
                    TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Hero Name', 
                      hintText: 'e.g. Vivian or Lydia',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    ),
                    onChanged: (v) {
                      setState(() {
                         widget.wizardData.characterName = v;
                      });
                    },
                  ),
                  if (_isCreatingNew)
                    const SizedBox(height: 24),

                  // Subtitle (only for new characters)
                  if (_isCreatingNew)
                    Text(
                      'Then, choose an archetype to start',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textDark.withAlpha(179), // 70% opacity
                          ),
                      textAlign: TextAlign.center,
                    ),
                  if (_isCreatingNew)
                    const SizedBox(height: 12),

                  // Archetype cards (horizontal scroll) - only for new characters
                  if (_isCreatingNew)
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
                          imagePath: archetype.imagePath,
                          name: archetype.name,
                          description: archetype.description,
                          specialAbility: archetype.specialAbility,
                          traits: archetype.traits,
                          isSelected: isSelected,
                          onUseTemplate: () => _selectArchetype(archetype),
                        );
                      },
                    ),
                  ),
                  if (_isCreatingNew)
                    const SizedBox(height: 16),

                  // Name & Age Section (show if creating new and archetype selected, or if existing character selected)
                  if (_canContinue || !_isCreatingNew) ...[
                    // Gender Selection - responsive layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 320;
                        return Row(
                          children: [
                            Text('Gender:', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SegmentedButton<String>(
                                segments: [
                                  ButtonSegment(
                                    value: 'Girl',
                                    label: Text('Girl', style: TextStyle(fontSize: isNarrow ? 12 : 14)),
                                  ),
                                  ButtonSegment(
                                    value: 'Boy',
                                    label: Text('Boy', style: TextStyle(fontSize: isNarrow ? 12 : 14)),
                                  ),
                                ],
                                selected: {widget.wizardData.characterGender},
                                onSelectionChanged: (Set<String> newSelection) {
                                  setState(() {
                                    widget.wizardData.characterGender = newSelection.first;
                                  });
                                },
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Age Picker
                    _ImprovedAgePicker(
                      label: 'Hero Age',
                      age: widget.wizardData.characterAge,
                      minAge: 1,
                      maxAge: 99,
                      onAgeChanged: (newAge) {
                        setState(() {
                          widget.wizardData.characterAge = newAge;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Create Avatar Button
                    if (widget.wizardData.characterName.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showAvatarCreator(),
                          icon: Icon(
                            _generatedAvatar != null ? Icons.edit : Icons.face,
                            color: const Color(0xFFFFD93D),
                          ),
                          label: Text(
                            _generatedAvatar != null
                                ? 'Change Avatar'
                                : 'Create Magic Avatar',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFFFFD93D), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],

                  // Custom Pets Section (only when creating a new character)
                  if (_isCreatingNew && _canContinue)
                     _PetsSection(
                        wizardData: widget.wizardData,
                        onUpdate: () => setState(() {}),
                        onAutoSave: _autoSaveCharacter,
                     ),

                  if (_isCreatingNew && _canContinue)
                     const SizedBox(height: 16),

// Siblings section removed per user request

                  if (_canContinue || !_isCreatingNew)
                     const SizedBox(height: 16),

                  // Continue button
                  if (_canContinue || (!_isCreatingNew && _selectedExistingCharacter != null))
                    AnimatedOpacity(
                      opacity: _canContinue ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: PillButton(
                        emoji: '➡️',
                        label: 'Continue',
                        onTap: _handleContinue,
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
  final VoidCallback onAutoSave;

  const _PetsSection({
    required this.wizardData,
    required this.onUpdate,
    required this.onAutoSave,
  });

  void _showAddPetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final colorController = TextEditingController();
    String species = 'Dog';
    String gender = 'Boy';
    String personality = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFF8E1),
                    Color(0xFFF3E5F5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.gold.withAlpha(140), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withAlpha(120),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pets, color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Add Your Pet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.pets, size: 18, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Pet Name',
                        hintText: 'e.g. Spot',
                        prefixIcon: Icon(Icons.badge),
                      ),
                      onChanged: (v) {
                        setState(() {}); // Rebuild to update button state
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: species,
                      items: ['Dog', 'Cat', 'Bird', 'Hamster', 'Fish', 'Bunny', 'Reptile', 'Other']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                         if (v != null) setState(() => species = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Species',
                        prefixIcon: Icon(Icons.pets),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: gender,
                      items: ['Boy', 'Girl']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                         if (v != null) setState(() => gender = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.favorite),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: colorController,
                      decoration: const InputDecoration(
                        labelText: 'Color / Looks',
                        hintText: 'e.g. Black with white paws',
                        prefixIcon: Icon(Icons.palette),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Personality / Fun Fact',
                        hintText: 'e.g. Loves to chase tails',
                        prefixIcon: Icon(Icons.auto_awesome),
                      ),
                      onChanged: (v) => personality = v,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton.icon(
                          onPressed: nameController.text.trim().isEmpty
                              ? null
                              : () {
                                  wizardData.pets.add({
                                    'name': nameController.text.trim(),
                                    'species': species,
                                    'gender': gender,
                                    'color': colorController.text.trim(),
                                    'personality': personality,
                                  });
                                  onUpdate();
                                  Navigator.pop(context);
                                  // Auto-save the character with the new pet
                                  onAutoSave();
                                },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Add Pet'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
                   // Auto-save the character with updated pets
                   onAutoSave();
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



/// Improved Age Picker Widget
///
/// Features:
/// - Large, clickable age display
/// - Direct text input field
/// - Scrollable wheel picker
/// - Better visual feedback
class _ImprovedAgePicker extends StatefulWidget {
  final String label;
  final int age;
  final int minAge;
  final int maxAge;
  final ValueChanged<int> onAgeChanged;

  const _ImprovedAgePicker({
    required this.label,
    required this.age,
    required this.minAge,
    required this.maxAge,
    required this.onAgeChanged,
  });

  @override
  State<_ImprovedAgePicker> createState() => _ImprovedAgePickerState();
}

class _ImprovedAgePickerState extends State<_ImprovedAgePicker> {
  late TextEditingController _textController;
  late FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.age.toString());
    _scrollController = FixedExtentScrollController(
      initialItem: widget.age - widget.minAge,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateAge(int newAge) {
    if (newAge >= widget.minAge && newAge <= widget.maxAge) {
      widget.onAgeChanged(newAge);
      _textController.text = newAge.toString();
    }
  }

  void _showQuickEditDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: widget.age.toString());
        return AlertDialog(
          title: Text('Enter ${widget.label}'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Age',
              hintText: '${widget.minAge}-${widget.maxAge}',
              border: const OutlineInputBorder(),
              suffixText: 'years',
            ),
            autofocus: true,
            onSubmitted: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null) {
                _updateAge(parsed);
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text);
                if (parsed != null) {
                  _updateAge(parsed);
                  Navigator.pop(context);
                }
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 300;
        final showWheelPicker = constraints.maxWidth >= 280;

        return Row(
          children: [
            // Label
            Text(
              widget.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isNarrow ? 13 : 14,
                color: AppColors.textDark,
              ),
            ),

            const Spacer(),

            // Clickable age display
            GestureDetector(
              onTap: _showQuickEditDialog,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 8 : 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.age}',
                      style: TextStyle(
                        fontSize: isNarrow ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      'yrs',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 12, color: AppColors.textLight),
                  ],
                ),
              ),
            ),

            // Compact wheel picker - only show if we have space
            if (showWheelPicker) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: isNarrow ? 50 : 60,
                height: 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.primary.withAlpha(26),
                  ),
                  child: Stack(
                    children: [
                      // Selection indicator
                      Positioned(
                        top: 28,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(51),
                            border: const Border(
                              top: BorderSide(color: AppColors.primary, width: 1),
                              bottom: BorderSide(color: AppColors.primary, width: 1),
                            ),
                          ),
                        ),
                      ),
                      // Wheel picker
                      CupertinoPicker(
                        scrollController: _scrollController,
                        itemExtent: 24,
                        onSelectedItemChanged: (index) {
                          _updateAge(index + widget.minAge);
                        },
                        children: List.generate(
                          widget.maxAge - widget.minAge + 1,
                          (index) => Center(
                            child: Text(
                              '${index + widget.minAge}',
                              style: TextStyle(
                                fontSize: isNarrow ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

