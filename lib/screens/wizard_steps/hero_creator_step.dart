import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import '../../models.dart';
import '../../avatar_models.dart';
import '../../custom_avatar_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/archetype_card.dart';
import '../../services/api_service_manager.dart';
import '../../services/avatar_generation_state.dart';
import 'custom_pet_avatar_screen.dart';

/// Hero Creator — Step 1 of the story wizard.
///
/// Screen layout (top → bottom):
///   1. Existing-character thumbnails (only when saved characters exist)
///   2. Circular avatar preview + +/− Hero Age picker
///   3. Hero / Heroine gender orbs
///   4. Magical parchment scroll name-entry
///   5. Horizontal archetype selection cards
///   6. "Create Your Avatar" image button
///   7. "Continue" button (visible once name + archetype chosen)
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
  // ─── Assets ─────────────────────────────────────────────────────────────────
  static const _placeholderAsset = 'assets/images/character_placeholder.png';

  // ─── State ──────────────────────────────────────────────────────────────────
  String? _selectedArchetypeId;
  late TextEditingController _nameController;
  Character? _selectedExistingCharacter;
  bool _isContinuePressed     = false;
  bool _isCreateAvatarPressed = false;
  bool _isCreatingNew         = true;
  GeneratedAvatar? _generatedAvatar;
  String? _customAvatarFilePath; // local file path from CustomAvatarScreen

  // ─── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.wizardData.characterAge < 3 ||
        widget.wizardData.characterAge > 99) {
      widget.wizardData.characterAge = 7;
    }
    // Default gender if empty
    if (widget.wizardData.characterGender.isEmpty) {
      widget.wizardData.characterGender = 'Girl';
    }
    _nameController = TextEditingController(
      text: widget.wizardData.characterName,
    );
    AvatarGenerationState().addListener(_onAvatarStateChanged);

    if (widget.wizardData.characterId != null &&
        widget.availableCharacters.isNotEmpty) {
      _selectedExistingCharacter = widget.availableCharacters.firstWhere(
        (c) => c.id == widget.wizardData.characterId,
        orElse: () => widget.availableCharacters.first,
      );
      if (_selectedExistingCharacter != null) {
        _isCreatingNew = false;
        _loadExistingCharacter(_selectedExistingCharacter!);
      }
    } else if (widget.availableCharacters.isNotEmpty) {
      _isCreatingNew = false;
    }
  }

  @override
  void didUpdateWidget(HeroCreatorStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.availableCharacters.isNotEmpty &&
        oldWidget.availableCharacters.isEmpty &&
        _isCreatingNew &&
        widget.wizardData.characterId == null &&
        _nameController.text.isEmpty) {
      setState(() => _isCreatingNew = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    AvatarGenerationState().removeListener(_onAvatarStateChanged);
    super.dispose();
  }

  // ─── Avatar state listener ───────────────────────────────────────────────────
  void _onAvatarStateChanged() {
    final state = AvatarGenerationState();
    if (state.completedAvatar != null && _generatedAvatar == null) {
      if (mounted) {
        setState(() {
          _generatedAvatar = state.completedAvatar;
          widget.wizardData.generatedAvatar = state.completedAvatar;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✨ Your avatar is ready!'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 3),
        ));
      }
      state.consumeAvatar();
    }
  }

  // ─── Character helpers ────────────────────────────────────────────────────────
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
        _generatedAvatar = character.generatedAvatar;
        widget.wizardData.generatedAvatar = character.generatedAvatar;
        if (character.pets != null) {
          final safePets = <Map<String, String>>[];
          for (final p in character.pets!) {
            try { safePets.add(Map<String, String>.from(p)); } catch (_) {}
          }
          widget.wizardData.pets = safePets;
        }
        if (character.friends != null) {
          widget.wizardData.additionalCharacters = [...character.friends!];
        }
        if (character.personalitySliders != null) {
          widget.wizardData.personalitySliders =
              Map<String, int>.from(character.personalitySliders!);
        }
      });
    } catch (e, stack) {
      debugPrint('❌ Error loading character: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load character: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _switchToNewCharacter() {
    setState(() {
      _isCreatingNew = true;
      _selectedExistingCharacter = null;
      _generatedAvatar = null;
      widget.wizardData.generatedAvatar = null;
      widget.wizardData.characterId = null;
      widget.wizardData.characterName = '';
      widget.wizardData.characterAge = 7;
      _selectedArchetypeId = null;
      _nameController.clear();
      widget.wizardData.pets = [];
      widget.wizardData.additionalCharacters = [];
    });
  }

  void _selectArchetype(ArchetypeData archetype) {
    setState(() {
      _selectedArchetypeId = archetype.name;
      _generatedAvatar = null;
      widget.wizardData.generatedAvatar = null;
      widget.wizardData.selectedArchetypeId = archetype.name;
      widget.wizardData.personalitySliders =
          Map<String, int>.from(archetype.attributes);
      if (widget.wizardData.characterAge < 1) {
        widget.wizardData.characterAge = 5;
      }
    });
  }

  Future<bool> _saveCharacterDraft() async {
    if (!_isCreatingNew || !_canContinue) return true;
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
      debugPrint('⚠️ Character save failed: $e');
      final isLocal = e.toString().contains('Cannot reach the local backend');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isLocal
              ? 'Avatar selected. Could not sync right now.'
              : 'Could not save character: $e'),
          backgroundColor: isLocal ? AppColors.gold : AppColors.error,
        ));
      }
      return isLocal;
    }
  }

  Future<void> _handleContinue() async {
    final ok = await _saveCharacterDraft();
    if (ok) widget.onNext();
  }

  Future<void> _openAvatarCreation() async {
    final result = await Navigator.push<CharacterAvatar>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomAvatarScreen(
          initialName: widget.wizardData.characterName.isNotEmpty
              ? widget.wizardData.characterName
              : null,
          initialAge: widget.wizardData.characterAge > 0
              ? widget.wizardData.characterAge
              : null,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null && result.customImagePath != null) {
      setState(() {
        _customAvatarFilePath = result.customImagePath;
        widget.wizardData.customAvatarPath = result.customImagePath;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✨ Avatar created! It will appear in your story.'),
        backgroundColor: Color(0xFF4CAF50),
        duration: Duration(seconds: 3),
      ));
    }
  }

  bool get _canContinue =>
      _selectedArchetypeId != null &&
      widget.wizardData.characterName.trim().isNotEmpty;

  // ─── Avatar image content ────────────────────────────────────────────────────
  Widget _buildAvatarContent() {
    if (_customAvatarFilePath != null) {
      return Image.file(
        File(_customAvatarFilePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderWidget(),
      );
    }
    if (_generatedAvatar != null) {
      final data = _generatedAvatar!.imageBase64;
      if (data.startsWith('assets/')) {
        return Image.asset(data, fit: BoxFit.cover);
      }
      if (data.startsWith('http')) {
        return Image.network(data, fit: BoxFit.cover);
      }
      try {
        return Image.memory(
          base64Decode(data.split(',').last),
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }
    return _placeholderWidget();
  }

  Widget _placeholderWidget() => Image.asset(
    _placeholderAsset,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFF7B4BAA), Color(0xFF2D0A4E)],
        ),
      ),
    ),
  );

  // ─── SECTION: Avatar + Age picker ───────────────────────────────────────────
  Widget _buildAvatarSection() {
    return Column(
      children: [
        // Avatar circle with a golden glow ring
        GestureDetector(
          onTap: _openAvatarCreation,
          child: Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD700), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(120),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFF9B3FD8).withAlpha(80),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipOval(child: _buildAvatarContent()),
          ),
        ),
        const SizedBox(height: 14),
        // +/− Hero Age picker
        _buildAgePicker(),
      ],
    );
  }

  Widget _buildAgePicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _AgeStepButton(
          icon: Icons.remove_rounded,
          onTap: () => setState(() {
            widget.wizardData.characterAge =
                (widget.wizardData.characterAge - 1).clamp(3, 99);
          }),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                '${widget.wizardData.characterAge}',
                style: GoogleFonts.cinzelDecorative(
                  color: const Color(0xFFFFD700),
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(color: Color(0xFFFFD700), blurRadius: 12),
                  ],
                ),
              ),
              Text(
                'Hero Age',
                style: GoogleFonts.cinzelDecorative(
                  color: Colors.white.withAlpha(200),
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        _AgeStepButton(
          icon: Icons.add_rounded,
          onTap: () => setState(() {
            widget.wizardData.characterAge =
                (widget.wizardData.characterAge + 1).clamp(3, 99);
          }),
        ),
      ],
    );
  }

  // ─── SECTION: Gender picker orbs ─────────────────────────────────────────────
  Widget _buildGenderPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildGenderOrb(
          imagePath: 'assets/images/ui/hero_icon.png',
          label: 'Hero',
          gender: 'Boy',
        ),
        const SizedBox(width: 32),
        _buildGenderOrb(
          imagePath: 'assets/images/ui/heroine_icon.png',
          label: 'Heroine',
          gender: 'Girl',
        ),
      ],
    );
  }

  Widget _buildGenderOrb({
    required String imagePath,
    required String label,
    required String gender,
  }) {
    final isSelected = widget.wizardData.characterGender == gender;
    return GestureDetector(
      onTap: () => setState(() => widget.wizardData.characterGender = gender),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 92,
            height: 92,
            decoration: isSelected
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withAlpha(180),
                        blurRadius: 22,
                        spreadRadius: 4,
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 3,
                    ),
                  )
                : BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(60),
                        blurRadius: 8,
                      ),
                    ],
                  ),
            child: ClipOval(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.cinzelDecorative(
              color: isSelected
                  ? const Color(0xFFFFD700)
                  : Colors.white.withAlpha(160),
              fontSize: 12,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECTION: Scroll name field ───────────────────────────────────────────────
  Widget _buildNameScrollInput() {
    return SizedBox(
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Scroll background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/ui/magical_scroll_bg.png',
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => _fallbackNameBox(),
            ),
          ),
          // Text input centered over the scroll's flat middle area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 76),
            child: TextField(
              controller: _nameController,
              inputFormatters: [
                LengthLimitingTextInputFormatter(24),
                _SafeNameFormatter(),
              ],
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.cinzelDecorative(
                fontSize: 17,
                color: const Color(0xFF3A1C00),
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: "Write your hero's name",
                hintStyle: GoogleFonts.cinzelDecorative(
                  fontSize: 13,
                  color: const Color(0x993A1C00),
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4),
              ),
              onChanged: (v) =>
                  setState(() => widget.wizardData.characterName = v.trim()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackNameBox() => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF9EEC8), Color(0xFFEDD89A), Color(0xFFF5E4B0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFD700), width: 2),
    ),
  );

  // ─── SECTION: Archetype cards ─────────────────────────────────────────────────
  Widget _buildArchetypeCards() {
    final archetypes = CharacterArchetypes.all;
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: archetypes.length,
        itemBuilder: (context, index) {
          final a = archetypes[index];
          final isSelected = _selectedArchetypeId == a.name;
          return GestureDetector(
            onTap: () => _selectArchetype(a),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isSelected ? 155 : 128,
              margin: EdgeInsets.symmetric(
                horizontal: 5,
                vertical: isSelected ? 0 : 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: isSelected
                      ? [
                          const Color(0xFF9B3FD8).withAlpha(190),
                          const Color(0xFFFFD700).withAlpha(65),
                        ]
                      : [
                          Colors.white.withAlpha(20),
                          const Color(0xFF9B3FD8).withAlpha(50),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFFD700)
                      : const Color(0xFFFFD700).withAlpha(80),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withAlpha(130),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: const Color(0xFF9B3FD8).withAlpha(100),
                          blurRadius: 16,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Elaborately framed archetype image
                    _buildArchetypeImage(a, isSelected),
                    const SizedBox(height: 7),
                    Text(
                      a.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: isSelected ? 13 : 11,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.description,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.comicNeue(
                        color: Colors.white.withAlpha(190),
                        fontSize: 9,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArchetypeImage(ArchetypeData a, bool isSelected) {
    final imgSize = isSelected ? 110.0 : 90.0;
    Widget imageWidget;

    if (a.imagePath != null) {
      imageWidget = Image.asset(
        a.imagePath!,
        width: imgSize,
        height: imgSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Text(
          a.icon ?? '✨',
          style: TextStyle(fontSize: isSelected ? 52 : 42),
        ),
      );
    } else {
      imageWidget = Text(
        a.icon ?? '✨',
        style: TextStyle(fontSize: isSelected ? 52 : 42),
      );
    }

    // Decorative gold frame around the image
    return Container(
      width: imgSize,
      height: imgSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFFD700)
              : const Color(0xFFFFD700).withAlpha(120),
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFFFD700).withAlpha(160)
                : const Color(0xFFFFD700).withAlpha(60),
            blurRadius: isSelected ? 16 : 8,
            spreadRadius: isSelected ? 2 : 0,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageWidget,
          ),
          // Inner golden shimmer overlay on selection
          if (isSelected)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD700).withAlpha(50),
                      Colors.transparent,
                      const Color(0xFF9B3FD8).withAlpha(30),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          // Corner sparkle accents
          Positioned(
            top: 3,
            left: 3,
            child: _cornerGem(isSelected),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: _cornerGem(isSelected),
          ),
          Positioned(
            bottom: 3,
            left: 3,
            child: _cornerGem(isSelected),
          ),
          Positioned(
            bottom: 3,
            right: 3,
            child: _cornerGem(isSelected),
          ),
        ],
      ),
    );
  }

  Widget _cornerGem(bool bright) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: bright
          ? const Color(0xFFFFD700)
          : const Color(0xFFFFD700).withAlpha(120),
      boxShadow: bright
          ? [
              BoxShadow(
                color: const Color(0xFFFFD700).withAlpha(200),
                blurRadius: 6,
              ),
            ]
          : null,
    ),
  );

  // ─── SECTION: Create Your Avatar image button ─────────────────────────────────
  Widget _buildCreateAvatarButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isCreateAvatarPressed = true),
      onTapUp: (_) => setState(() => _isCreateAvatarPressed = false),
      onTapCancel: () => setState(() => _isCreateAvatarPressed = false),
      onTap: _openAvatarCreation,
      child: AnimatedScale(
        scale: _isCreateAvatarPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Image.asset(
          'assets/images/ui/create_magic_btn.png',
          height: 80,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallbackAvatarButton(),
        ),
      ),
    );
  }

  // Flutter-native fallback if image fails
  Widget _buildFallbackAvatarButton() => Container(
    height: 62,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(31),
      gradient: const LinearGradient(
        colors: [Color(0xFF5B1BAA), Color(0xFF9B3FD8), Color(0xFF5B1BAA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: const Color(0xFFFFD700), width: 2),
    ),
    child: Center(
      child: Text(
        'Create Magic Avatar',
        style: GoogleFonts.cinzelDecorative(
          color: const Color(0xFFFFE066),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  // ─── SECTION: Continue button ─────────────────────────────────────────────────
  Widget _buildContinueButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isContinuePressed = true),
      onTapUp: (_) => setState(() => _isContinuePressed = false),
      onTapCancel: () => setState(() => _isContinuePressed = false),
      onTap: _handleContinue,
      child: AnimatedScale(
        scale: _isContinuePressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(31),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF5B1BAA),
                Color(0xFF9B3FD8),
                Color(0xFF5B1BAA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFFFD700), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withAlpha(100),
                blurRadius: 16,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(0xFF9B3FD8).withAlpha(80),
                blurRadius: 24,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'Continue',
              style: GoogleFonts.cinzelDecorative(
                color: const Color(0xFFFFE066),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Existing character row ────────────────────────────────────────────────────
  Widget _buildExistingCharactersRow() {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.availableCharacters.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == widget.availableCharacters.length) {
            return GestureDetector(
              onTap: _switchToNewCharacter,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3A2363),
                  border: Border.all(
                    color: _isCreatingNew
                        ? const Color(0xFFF8D27E)
                        : Colors.white54,
                    width: _isCreatingNew ? 3 : 1.5,
                  ),
                  boxShadow: _isCreatingNew
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withAlpha(80),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            );
          }
          final char = widget.availableCharacters[index];
          final sel =
              _selectedExistingCharacter?.id == char.id && !_isCreatingNew;
          return GestureDetector(
            onTap: () => _loadExistingCharacter(char),
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? const Color(0xFFF8D27E) : Colors.white54,
                  width: sel ? 3 : 1.5,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withAlpha(128),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: Image.asset(
                  _placeholderAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF3A2363),
                    child: Center(
                      child: Text(
                        char.name.isNotEmpty
                            ? char.name[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final hPad = w < 760 ? 16.0 : 28.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF120226),
            Color(0xFF3D1166),
            Color(0xFF4A1A72),
            Color(0xFF2A0A4E),
            Color(0xFF120226),
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Existing characters row (only when characters are saved)
              if (widget.availableCharacters.isNotEmpty) ...[
                _buildExistingCharactersRow(),
                const SizedBox(height: 10),
              ],

              // ── Avatar + Hero Age picker ───────────────────────────────────
              Center(child: _buildAvatarSection()),
              const SizedBox(height: 20),

              // ── Hero / Heroine gender picker ───────────────────────────────
              _buildGenderPicker(),
              const SizedBox(height: 20),

              // ── Magical scroll name field (create-new only) ────────────────
              if (_isCreatingNew) ...[
                _buildNameScrollInput(),
                const SizedBox(height: 20),
              ],

              // ── Archetype cards ────────────────────────────────────────────
              _buildArchetypeCards(),
              const SizedBox(height: 20),

              // ── Pets Section ───────────────────────────────────────────────
              if (_isCreatingNew && _canContinue) ...[
                _PetsSection(
                  wizardData: widget.wizardData,
                  onUpdate: () => setState(() {}),
                ),
                const SizedBox(height: 20),
              ],

              // ── Create Your Avatar button (image) ─────────────────────────
              _buildCreateAvatarButton(),
              const SizedBox(height: 14),

              // ── Continue (gated until name + archetype chosen) ─────────────
              if (_canContinue ||
                  (!_isCreatingNew && _selectedExistingCharacter != null))
                _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetsSection extends StatelessWidget {
  final WizardData wizardData;
  final VoidCallback onUpdate;

  static const List<String> _speciesOptions = [
    'Dog',
    'Cat',
    'Bird',
    'Hamster',
    'Fish',
    'Bunny',
    'Reptile',
    'Other',
  ];

  static const Map<String, String> _speciesImageAssets = {
    'Fish': 'assets/images/companions/fish.png',
    'Bunny': 'assets/images/companions/bunny.png',
    'Hamster': 'assets/images/companions/hamster.png',
    'Reptile': 'assets/images/companions/reptile.png',
  };

  const _PetsSection({
    required this.wizardData,
    required this.onUpdate,
  });

  void _showAddPetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final breedController = TextEditingController();
    String species = 'Dog';
    String gender = 'Boy';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final selectedPreviewImage = _speciesImageAssets[species];

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF120226), Color(0xFF3D1166)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD700).withAlpha(150), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9B3FD8).withAlpha(100),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Summon a Magical Pet',
                      style: GoogleFonts.cinzelDecorative(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFD700),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (selectedPreviewImage != null)
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFD700), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withAlpha(100),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              selectedPreviewImage,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _petFieldDecoration(
                        labelText: 'Pet Name',
                        hintText: 'e.g. Luna',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: species,
                      dropdownColor: const Color(0xFF2A0A4E),
                      style: const TextStyle(color: Colors.white),
                      items: _speciesOptions
                          .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('${_getEmojiForSpecies(s)} $s')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => species = v);
                      },
                      decoration: _petFieldDecoration(labelText: 'Species'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: breedController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _petFieldDecoration(
                        labelText: 'Breed / Appearance',
                        hintText: 'e.g. Golden Retriever, fluffy white cat',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: gender,
                      dropdownColor: const Color(0xFF2A0A4E),
                      style: const TextStyle(color: Colors.white),
                      items: ['Boy', 'Girl']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => gender = v);
                      },
                      decoration: _petFieldDecoration(labelText: 'Gender'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (nameController.text.trim().isNotEmpty) {
                              wizardData.pets.add({
                                'name': nameController.text.trim(),
                                'species': species,
                                'gender': gender,
                                'breed': breedController.text.trim(),
                              });
                              onUpdate();
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B3FD8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Add Pet'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _petFieldDecoration({required String labelText, String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: Color(0xFFFFD700)),
      hintStyle: const TextStyle(color: Colors.white38),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: const Color(0xFFFFD700).withAlpha(100)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
      ),
      filled: true,
      fillColor: Colors.white.withAlpha(10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Your Adventure Team',
            style: GoogleFonts.cinzelDecorative(
              color: const Color(0xFFFFD700),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add Pet Button
              GestureDetector(
                onTap: () => _showAddPetDialog(context),
                child: Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD700).withAlpha(150), width: 2),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5B1BAA), Color(0xFF2D0A4E)],
                    ),
                  ),
                  child: const Icon(Icons.add, color: Color(0xFFFFD700), size: 30),
                ),
              ),
              // Current Pets
              ...wizardData.pets.map((pet) {
                final name = pet['name'] ?? '';
                final species = pet['species'] ?? 'Other';
                final avatar = wizardData.petAvatars[name];

                return GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push<GeneratedAvatar>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomPetAvatarScreen(
                          petName: name,
                          species: species,
                          breedDescription: pet['breed'] ?? species,
                          ownerFavoriteColor: 'Blue', // Default for now
                        ),
                      ),
                    );
                    if (result != null) {
                      wizardData.petAvatars[name] = result;
                      onUpdate();
                    }
                  },
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: avatar != null 
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFFFFD700).withAlpha(100), 
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: avatar != null
                                    ? const Color(0xFFFFD700).withAlpha(150)
                                    : const Color(0xFF9B3FD8).withAlpha(80),
                                blurRadius: avatar != null ? 12 : 8,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatar != null
                                ? Image.memory(
                                    base64Decode(avatar.imageBase64.split(',').last),
                                    fit: BoxFit.cover,
                                  )
                                : Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Text(
                                        _getEmojiForSpecies(species),
                                        style: const TextStyle(fontSize: 30),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF9B3FD8),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
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

// ─── Age step button ──────────────────────────────────────────────────────────
class _AgeStepButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AgeStepButton({required this.icon, required this.onTap});

  @override
  State<_AgeStepButton> createState() => _AgeStepButtonState();
}

class _AgeStepButtonState extends State<_AgeStepButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: _pressed
                  ? [const Color(0xFF3A0A7A), const Color(0xFF6B2BAA)]
                  : [const Color(0xFF5B1BAA), const Color(0xFF9B3FD8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFFFD700),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withAlpha(100),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: const Color(0xFFFFE066),
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ─── Name input formatter ──────────────────────────────────────────────────────
class _SafeNameFormatter extends TextInputFormatter {
  const _SafeNameFormatter();

  static const Set<String> _blockedWords = {
    'damn', 'hell', 'stupid', 'idiot', 'dumb', 'hate',
  };

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text
        .replaceAll(RegExp(r"[^a-zA-Z0-9 '\\-]"), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trimLeft();
    if (cleaned.isEmpty) return const TextEditingValue();

    final safeWords = cleaned
        .split(' ')
        .where((w) => !_blockedWords.contains(w.toLowerCase()))
        .toList();
    final safeText = safeWords.join(' ');
    return TextEditingValue(
      text: safeText,
      selection: TextSelection.collapsed(offset: safeText.length),
    );
  }
}
