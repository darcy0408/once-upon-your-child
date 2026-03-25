import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../theme/age_band_theme.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/magic_ear_button.dart';

/// Step 3: The Adventure Team Selector
/// Updated with audio prompts and consistent typography for young children.
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
  final Set<String> _selectedCompanions = {};
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Sync with existing wizard data
    _selectedCompanions.addAll(widget.wizardData.selectedCompanions);
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<Companion> get _savedCharacterCompanions {
    return widget.savedCharacters.where((char) {
      return char.name != widget.wizardData.characterName;
    }).map((char) {
      String description = '${char.age} years old';
      if (char.role.isNotEmpty && char.role != 'Hero') {
        description = char.role;
      } else if (char.personalityTraits?.isNotEmpty == true) {
        description = char.personalityTraits!.join(', ');
      } else {
        description = 'Age ${char.age}';
      }

      return Companion(
        id: 'character_${char.id}',
        emoji: _getEmojiForAge(char.age),
        name: char.name,
        color: AppColors.gold,
        greeting: 'Let\'s have an adventure!',
        description: description,
        character: char,
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
    final band = Theme.of(context).extension<AgeBandThemeData>()?.band ?? AgeBand.explorer;

    final List<Companion> defaultCompanions;
    switch (band) {
      case AgeBand.sprout:
        defaultCompanions = [
          Companion(
            id: 'fluffy_dragon',
            emoji: '🐉',
            name: 'Fluffy Dragon',
            color: const Color(0xFFFF7043),
            greeting: 'Achoo! ...That was a hug-sneeze. It means I love you.',
            description: 'His roars come out as sparkly sneezes and his hugs wrap around you like a warm blanket with wings.',
            imagePath: 'assets/images/companions/sprout/fluffy_dragon.png',
          ),
          Companion(
            id: 'magic_bunny',
            emoji: '🐰',
            name: 'Magic Bunny',
            color: const Color(0xFFEC407A),
            greeting: 'Boing! Watch this!',
            description: 'Boing-hops through moonbeams that turn into rainbow puddles. She never, ever hops away from you.',
            imagePath: 'assets/images/companions/sprout/magic_bunny.png',
          ),
          Companion(
            id: 'shining_puppy',
            emoji: '🐕',
            name: 'Shining Puppy',
            color: const Color(0xFFFFCA28),
            greeting: 'WoofwoofWOOF! *tail spinning*',
            description: 'Her tail starts glowing the second she sees you. First into every dark place, last to leave.',
            imagePath: 'assets/images/companions/sprout/shining_puppy.png',
          ),
          Companion(
            id: 'robin',
            emoji: '🐦',
            name: 'Robin',
            color: const Color(0xFFE53935),
            greeting: 'CHIRP CHIRP! ...You\'re safe. I checked.',
            description: 'Very small, very loud, completely sure you need protecting. She brings tiny gifts and reports on everything.',
            imagePath: 'assets/images/companions/sprout/robin.png',
          ),
        ];
        break;
      case AgeBand.explorer:
        defaultCompanions = [
          Companion(
            id: 'ember_dragon',
            emoji: '🐉',
            name: 'Ember Dragon',
            color: const Color(0xFFFF7043),
            greeting: 'Your idea? Brilliant. Best one in a hundred years.',
            description: 'Breathes rainbow fire that paints shimmering paths — and uses it even when unnecessary. Treats every one of your ideas like brilliant.',
            imagePath: 'assets/images/companions/explorer/ember_dragon.png',
          ),
          Companion(
            id: 'moon_owl',
            emoji: '🦉',
            name: 'Moon Owl',
            color: const Color(0xFF5C6BC0),
            greeting: 'The moon shows me something. What do you see in it?',
            description: 'Reads the future in moonlight reflections. Almost always answers with the question you actually needed.',
            imagePath: 'assets/images/companions/explorer/moon_owl.png',
          ),
          Companion(
            id: 'star_fox',
            emoji: '🦊',
            name: 'Star Fox',
            color: const Color(0xFFFFCA28),
            greeting: 'Follow the trail. I know exactly where we\'re going.',
            description: 'Leaves stardust trails just long enough to follow home. Has opinions about which way is best and admits when he\'s wrong.',
            imagePath: 'assets/images/companions/explorer/star_fox.png',
          ),
          Companion(
            id: 'robin',
            emoji: '🐦',
            name: 'Robin',
            color: const Color(0xFFE53935),
            greeting: 'Three chirps: stop. One whistle: safe. Two clicks: run. Ready?',
            description: 'Has a very clear warning system and has launched herself at harmless pinecones. Checks you\'re okay before she\'d ever admit she was worried.',
            imagePath: 'assets/images/companions/explorer/robin.png',
          ),
        ];
        break;
      case AgeBand.adventurer:
        defaultCompanions = [
          Companion(
            id: 'thunder_wolf',
            emoji: '🐺',
            name: 'Thunder Wolf',
            color: const Color(0xFF5C6BC0),
            greeting: 'Pack moves together. I\'ve got your left side.',
            description: 'Runs ahead to scout, always circles back. Will howl the honest truth before letting you walk into something unprepared.',
            imagePath: 'assets/images/companions/adventurer/thunder_wolf.png',
          ),
          Companion(
            id: 'shadow_panther',
            emoji: '🐈‍⬛',
            name: 'Shadow Panther',
            color: const Color(0xFF7E57C2),
            greeting: 'I noticed something. Want to hear it?',
            description: 'Moves silently and sees everything. When she decides you\'re worth trusting, her eyes catch the light gold.',
            imagePath: 'assets/images/companions/adventurer/shadow_panther.png',
          ),
          Companion(
            id: 'crystal_phoenix',
            emoji: '🦅',
            name: 'Crystal Phoenix',
            color: const Color(0xFFFFCA28),
            greeting: 'I\'ve been here before. Different shape, same fire.',
            description: 'Falls apart and comes back, every time. Carries old scars like proof. Not afraid of the hard parts.',
            imagePath: 'assets/images/companions/adventurer/crystal_phoenix.png',
          ),
          Companion(
            id: 'robin',
            emoji: '🐦',
            name: 'Robin',
            color: const Color(0xFFE53935),
            greeting: '*three sharp chirps* — wait. One long note. Safe to come.',
            description: 'Very low threshold for danger. Loud, fearless, sometimes wrong, never slower for it. Brings gifts when the danger clears.',
            imagePath: 'assets/images/companions/adventurer/robin.png',
          ),
        ];
        break;
      case AgeBand.creator:
        defaultCompanions = [
          Companion(
            id: 'thunder_wolf',
            emoji: '🐺',
            name: 'Thunder Wolf',
            color: const Color(0xFF5C6BC0),
            greeting: 'I know what you\'re building. I want to help.',
            description: 'Thinks in systems and loyalty. Will push back on bad ideas, but never on you.',
            imagePath: 'assets/images/companions/creator/thunder_wolf.png',
          ),
          Companion(
            id: 'shadow_panther',
            emoji: '🐈‍⬛',
            name: 'Shadow Panther',
            color: const Color(0xFF7E57C2),
            greeting: 'Something feels off. Give me a minute.',
            description: 'Has begun walking beside you instead of always in the shadows. Catches the things you almost missed.',
            imagePath: 'assets/images/companions/creator/shadow_panther.png',
          ),
          Companion(
            id: 'crystal_phoenix',
            emoji: '🦅',
            name: 'Crystal Phoenix',
            color: const Color(0xFFFFCA28),
            greeting: 'That version didn\'t work. Good. Now we know.',
            description: 'Transforms failure into fuel without making it a lesson. The comeback is always more interesting than the fall.',
            imagePath: 'assets/images/companions/creator/crystal_phoenix.png',
          ),
          Companion(
            id: 'robin',
            emoji: '🐦',
            name: 'Robin',
            color: const Color(0xFFE53935),
            greeting: 'I have a new sound for this. You\'ll know it when you need it.',
            description: 'Louder than you remember and you\'ve stopped being surprised. Strong opinions, follows your lead anyway.',
            imagePath: 'assets/images/companions/creator/robin.png',
          ),
        ];
        break;
      case AgeBand.adolescent:
        defaultCompanions = [
          Companion(
            id: 'thunder_wolf',
            emoji: '🐺',
            name: 'Thunder Wolf',
            color: const Color(0xFF5C6BC0),
            greeting: 'I\'m already moving. Redirect me if I\'m wrong.',
            description: 'Three moves ahead, says difficult things directly. Chosen you as his person — not something he does lightly.',
            imagePath: 'assets/images/companions/adolescent/thunder_wolf.png',
          ),
          Companion(
            id: 'shadow_panther',
            emoji: '🐈‍⬛',
            name: 'Shadow Panther',
            color: const Color(0xFF7E57C2),
            greeting: 'That\'s not actually what you believe, is it?',
            description: 'Reads you as closely as she reads rooms. Her loyalty was built deliberately, and she knows exactly when.',
            imagePath: 'assets/images/companions/adolescent/shadow_panther.png',
          ),
          Companion(
            id: 'crystal_phoenix',
            emoji: '🦅',
            name: 'Crystal Phoenix',
            color: const Color(0xFFFFCA28),
            greeting: 'I\'ve burned down before. The next version was better.',
            description: 'Proof that reinvention is survivable. Doesn\'t romanticize the hard parts — just lived through them and kept going.',
            imagePath: 'assets/images/companions/adolescent/crystal_phoenix.png',
          ),
          Companion(
            id: 'robin',
            emoji: '🐦',
            name: 'Robin',
            color: const Color(0xFFE53935),
            greeting: 'I\'m watching you more than the path right now. You okay?',
            description: 'Not calmer, but more precise. Watches you more than she scouts the path these days.',
            imagePath: 'assets/images/companions/adolescent/robin.png',
          ),
        ];
        break;
      case AgeBand.adult:
        defaultCompanions = [
          Companion(
            id: 'thunder_wolf',
            emoji: '🐺',
            name: 'Thunder Wolf',
            color: const Color(0xFF5C6BC0),
            greeting: 'Wind\'s coming from the east. Here\'s what I see.',
            description: 'Not here to protect you — here to run the same storm. Chosen family, not assigned companion.',
            imagePath: 'assets/images/companions/adult/thunder_wolf.png',
          ),
          Companion(
            id: 'shadow_panther',
            emoji: '🐈‍⬛',
            name: 'Shadow Panther',
            color: const Color(0xFF7E57C2),
            greeting: 'The thing no one\'s saying — it\'s this.',
            description: 'Names what everyone else avoids. Comfortable with discomfort. Honest about what she doesn\'t know.',
            imagePath: 'assets/images/companions/adult/shadow_panther.png',
          ),
          Companion(
            id: 'crystal_phoenix',
            emoji: '🦅',
            name: 'Crystal Phoenix',
            color: const Color(0xFFFFCA28),
            greeting: 'I stopped counting the times. It\'s not the point.',
            description: 'Has outlasted every certainty it once held. The fire isn\'t dramatic anymore — just steady. Still warm.',
            imagePath: 'assets/images/companions/adult/crystal_phoenix.png',
          ),
          Companion(
            id: 'robin',
            emoji: '🐦',
            name: 'Robin',
            color: const Color(0xFFE53935),
            greeting: 'I know. I know. I still had to check.',
            description: 'Still the same bird — loud, loyal, occasionally wrong. Her gifts are better now because she\'s learned what you need.',
            imagePath: 'assets/images/companions/adult/robin.png',
          ),
        ];
        break;
    }

    final customPets = widget.wizardData.pets.map((pet) {
      final name = pet['name']!;
      return Companion(
        id: name,
        emoji: _getEmojiForSpecies(pet['species']),
        name: name,
        color: AppColors.primary,
        greeting: pet['personality']?.isNotEmpty == true
            ? pet['personality']!
            : 'I am your ${pet['species']}!',
        description: 'Your faithful ${pet['species']} companion',
        generatedAvatar: widget.wizardData.petAvatars[name],
      );
    }).toList();

    // Generic "Bring Your Pet" card — shown when no pet has been added yet
    final yourPetCard = Companion(
      id: 'your_pet',
      emoji: '🐾',
      name: 'Your Pet',
      color: const Color(0xFF8D6E63),
      greeting: 'Add a photo and I\'ll become part of the story!',
      description: 'Bring your real pet along. Add their name, species, and a photo to create their storybook character.',
    );

    return [...customPets, ...defaultCompanions, yourPetCard];
  }

  String _getEmojiForSpecies(String? species) {
    switch (species) {
      case 'Dog':
        return '🐕';
      case 'Cat':
        return '🐱';
      case 'Bird':
        return '🐦';
      case 'Hamster':
        return '🐹';
      case 'Fish':
        return '🐠';
      case 'Bunny':
        return '🐰';
      case 'Reptile':
        return '🦎';
      default:
        return '🐾';
    }
  }

  void _toggleCompanion(Companion companion) {
    // "Your Pet" card is a prompt to add a pet, not a selectable companion
    if (companion.id == 'your_pet') {
      _showAddPetDialog();
      return;
    }
    setState(() {
      if (_selectedCompanions.contains(companion.id)) {
        _selectedCompanions.remove(companion.id);
        widget.wizardData.selectedCompanions.remove(companion.id);
        widget.wizardData.companionNames.remove(companion.name);
      } else {
        _selectedCompanions.add(companion.id);
        if (!widget.wizardData.selectedCompanions.contains(companion.id)) {
          widget.wizardData.selectedCompanions.add(companion.id);
          widget.wizardData.companionNames.add(companion.name);
        }
      }
    });
  }

  void _showAddPetDialog() {
    final nameCtrl = TextEditingController();
    String selectedSpecies = 'Dog';
    const species = ['Dog', 'Cat', 'Bird', 'Bunny', 'Hamster', 'Fish', 'Reptile', 'Other'];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Your Pet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pet\'s name',
                  hintText: 'e.g. Biscuit',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSpecies,
                decoration: const InputDecoration(labelText: 'Type of animal'),
                items: species
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedSpecies = v ?? 'Dog'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  widget.wizardData.pets.add({
                    'name': name,
                    'species': selectedSpecies,
                    'personality': '',
                  });
                  // _magicalCompanions is a getter that rebuilds automatically
                  // Auto-select the new pet
                  _selectedCompanions.add(name);
                  widget.wizardData.selectedCompanions.add(name);
                  widget.wizardData.companionNames.add(name);
                });
              },
              child: const Text('Add to Story'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _audioPrompt() {
    return MagicEarButton(
      spokenText: _buildCompanionSpokenText(),
    );
  }

  String _buildCompanionSpokenText() {
    final names = _magicalCompanions.map((c) => c.name).join(', ');
    final age = widget.wizardData.characterAge;
    final band = ageBandFromAge(age <= 0 ? 8 : age);
    final prompt = band.isMature
        ? 'Choose a companion to join your story. Options: $names.'
        : age <= 8
            ? 'Pick a friend to come along! You can choose $names.'
            : 'Pick your companions! Tap one to bring them along. You can choose $names.';
    return prompt;
  }

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _audioPrompt(),
                const SizedBox(width: 8),
                Text(
                  'Choose a Travel Buddy',
                  style: GoogleFonts.cinzelDecorative(
                    color: const Color(0xFFFFD700),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Who will join you on this adventure?',
              style: GoogleFonts.quicksand(
                color: Colors.white.withAlpha(200),
                fontSize: 16,
                fontWeight: FontWeight.w500,
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
                style: GoogleFonts.fredoka(
                  color: const Color(0xFFD4A0FF),
                  fontSize: 18,
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
                  final isSelected = _selectedCompanions.contains(companion.id);
                  return _CompanionCard(
                    companion: companion,
                    isSelected: isSelected,
                    onTap: () => _toggleCompanion(companion),
                    customName: widget.wizardData.companionCustomNames[companion.id],
                    onNameChanged: (name) => setState(() {
                      widget.wizardData.companionCustomNames[companion.id] = name;
                    }),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // 2. Magical Creatures
            Text(
              'Magical Creatures',
              style: GoogleFonts.fredoka(
                color: const Color(0xFFD4A0FF),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ..._magicalCompanions.map((creature) {
              final isSelected = _selectedCompanions.contains(creature.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _CompanionCard(
                  companion: creature,
                  isSelected: isSelected,
                  onTap: () => _toggleCompanion(creature),
                  isMagical: true,
                  customName: widget.wizardData.companionCustomNames[creature.id],
                  onNameChanged: (name) => setState(() {
                    widget.wizardData.companionCustomNames[creature.id] = name;
                  }),
                ),
              );
            }),

            const SizedBox(height: AppSpacing.xxl),

            // Navigation
            if (_selectedCompanions.isNotEmpty)
              Center(
                child: PillButton(
                  emoji: '✨',
                  label: band.companionCTALabel,
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
                    band.band.isMature ? 'Skip' : 'Go Solo',
                    style: GoogleFonts.quicksand(
                      color: Colors.white.withAlpha(150),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
  final Character? character;
  final GeneratedAvatar? generatedAvatar;

  Companion({
    required this.id,
    required this.emoji,
    required this.name,
    required this.color,
    required this.greeting,
    this.description = '',
    this.imagePath,
    this.character,
    this.generatedAvatar,
  });
}

class _CompanionCard extends StatefulWidget {
  final Companion companion;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isMagical;
  final String? customName;
  final ValueChanged<String>? onNameChanged;

  const _CompanionCard({
    required this.companion,
    required this.isSelected,
    required this.onTap,
    this.isMagical = false,
    this.customName,
    this.onNameChanged,
  });

  @override
  State<_CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<_CompanionCard> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
        text: widget.customName ?? widget.companion.name);
  }

  @override
  void didUpdateWidget(_CompanionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSelected && oldWidget.isSelected) {
      _nameController.text = widget.customName ?? widget.companion.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.isSelected,
      label:
          'Companion: ${widget.companion.name}. ${widget.companion.description}. ${widget.isSelected ? 'Selected' : 'Double tap to select'}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white.withAlpha(20)
                : Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFD4A0FF).withAlpha(80),
                width: widget.isSelected ? 3 : 1.5),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                        color: const Color(0xFFFFD700).withAlpha(80),
                        blurRadius: 20)
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBackground(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.companion.name,
                            style: GoogleFonts.fredoka(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(widget.companion.description,
                            style: GoogleFonts.quicksand(
                                color: Colors.white.withAlpha(180),
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        // Greeting speech bubble + naming field when selected
                        if (widget.isSelected) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFFFFD700).withAlpha(120)),
                            ),
                            child: Text(
                              '"${widget.companion.greeting}"',
                              style: GoogleFonts.quicksand(
                                color: const Color(0xFFFFD700),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {}, // absorb tap to prevent card deselect
                            child: TextField(
                              controller: _nameController,
                              onChanged: widget.onNameChanged,
                              style: GoogleFonts.quicksand(
                                  color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Companion\'s name',
                                labelStyle: TextStyle(
                                    color: Colors.white.withAlpha(150),
                                    fontSize: 12),
                                filled: true,
                                fillColor: Colors.white.withAlpha(15),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.white.withAlpha(60)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFFFD700)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.isSelected)
                Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Color(0xFFFFD700), shape: BoxShape.circle),
                        child: const Icon(Icons.check,
                            color: Color(0xFF3B2363), size: 20))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (widget.companion.generatedAvatar != null) {
      return Image.memory(
          base64Decode(
              widget.companion.generatedAvatar!.imageBase64.split(',').last),
          height: 120,
          fit: BoxFit.cover);
    }
    if (widget.companion.character?.generatedAvatar != null) {
      final b64 = widget.companion.character!.generatedAvatar!.imageBase64;
      if (b64.startsWith('assets/')) {
        return Image.asset(b64, height: 120, fit: BoxFit.cover);
      }
      return Image.memory(base64Decode(b64.split(',').last),
          height: 120, fit: BoxFit.cover);
    }
    if (widget.companion.imagePath != null) {
      return Image.asset(widget.companion.imagePath!,
          height: 120, fit: BoxFit.cover);
    }
    return Container(
        height: 120,
        color: Colors.white.withAlpha(10),
        child: Center(
            child: Text(widget.companion.emoji,
                style: const TextStyle(fontSize: 50))));
  }
}
