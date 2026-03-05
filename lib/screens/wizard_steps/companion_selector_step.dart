import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pill_button.dart';

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
  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _initTts();
    
    // Sync with existing wizard data
    _selectedCompanions.addAll(widget.wizardData.selectedCompanions);
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _tts.stop();
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

    final customPets = widget.wizardData.pets.map((pet) {
      final name = pet['name']!;
      return Companion(
        id: name,
        emoji: _getEmojiForSpecies(pet['species']),
        name: name,
        color: AppColors.primary,
        greeting: pet['personality']?.isNotEmpty == true ? pet['personality']! : 'I am your ${pet['species']}!',
        description: 'Your faithful ${pet['species']} companion',
        generatedAvatar: widget.wizardData.petAvatars[name],
      );
    }).toList();

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

  Widget _audioPrompt(String text) {
    return IconButton(
      icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFFFD700), size: 32),
      onPressed: () => _tts.speak(text),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                _audioPrompt("Choose a travel buddy"),
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
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final companion = _savedCharacterCompanions[index];
                  final isSelected = _selectedCompanions.contains(companion.id);
                  return _CompanionCard(
                    companion: companion,
                    isSelected: isSelected,
                    onTap: () => _toggleCompanion(companion),
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
                  onPressed: widget.onNext,
                  child: Text(
                    'Go Solo (Be Brave!)',
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
    required this.id, required this.emoji, required this.name, required this.color,
    required this.greeting, this.description = '', this.imagePath, this.character, this.generatedAvatar,
  });
}

class _CompanionCard extends StatelessWidget {
  final Companion companion;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isMagical;

  const _CompanionCard({required this.companion, required this.isSelected, required this.onTap, this.isMagical = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withAlpha(20) : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? const Color(0xFFFFD700) : const Color(0xFFD4A0FF).withAlpha(80), width: isSelected ? 3 : 1.5),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFFD700).withAlpha(80), blurRadius: 20)] : null,
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
                      Text(companion.name, style: GoogleFonts.fredoka(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(companion.description, style: GoogleFonts.quicksand(color: Colors.white.withAlpha(180), fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            if (isSelected) Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle), child: const Icon(Icons.check, color: Color(0xFF3B2363), size: 20))),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (companion.generatedAvatar != null) {
      return Image.memory(base64Decode(companion.generatedAvatar!.imageBase64.split(',').last), height: 120, fit: BoxFit.cover);
    }
    if (companion.character?.generatedAvatar != null) {
      final b64 = companion.character!.generatedAvatar!.imageBase64;
      if (b64.startsWith('assets/')) return Image.asset(b64, height: 120, fit: BoxFit.cover);
      return Image.memory(base64Decode(b64.split(',').last), height: 120, fit: BoxFit.cover);
    }
    if (companion.imagePath != null) return Image.asset(companion.imagePath!, height: 120, fit: BoxFit.cover);
    return Container(height: 120, color: Colors.white.withAlpha(10), child: Center(child: Text(companion.emoji, style: const TextStyle(fontSize: 50))));
  }
}
