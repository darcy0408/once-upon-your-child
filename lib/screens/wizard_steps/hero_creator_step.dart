import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../../models.dart';
import '../../avatar_models.dart';
import '../../custom_avatar_screen.dart';
import '../../theme/age_band_theme.dart';
import '../../theme/app_theme.dart';
import '../../widgets/archetype_card.dart';
import '../../widgets/magic_star_cursor.dart';
import '../../widgets/avatar_gallery_selector.dart';
import '../../services/api_service_manager.dart';
import '../../services/avatar_generation_state.dart';
import '../../services/firebase_analytics_service.dart';
import '../../services/audio_ambience_service.dart';
import '../../widgets/image_mode_orb.dart';
import '../../widgets/image_crystal_formation.dart';
import '../../data/scenario_data.dart';
import 'custom_pet_avatar_screen.dart';

/// Hero Creator — Step 1 of the story wizard.
/// Restructured as a guided multi-page wizard (progressive disclosure).
class HeroCreatorStep extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onNext;
  final List<Character> availableCharacters;
  final void Function(int subStep)? onSubStepChange;

  const HeroCreatorStep({
    super.key,
    required this.wizardData,
    required this.onNext,
    this.availableCharacters = const [],
    this.onSubStepChange,
  });

  @override
  State<HeroCreatorStep> createState() => _HeroCreatorStepState();
}

class _HeroCreatorStepState extends State<HeroCreatorStep>
    with TickerProviderStateMixin {
  // ─── Assets ─────────────────────────────────────────────────────────────────
  static const _placeholderAsset = 'assets/images/hero_placeholder.jpg';

  // ─── State ──────────────────────────────────────────────────────────────────
  late PageController _heroPageController;
  int _heroPage = 0;
  String? _selectedArchetypeId;
  late TextEditingController _nameController;
  final FocusNode _nameFocusNode = FocusNode();
  Character? _selectedExistingCharacter;
  bool _isContinuePressed = false;
  bool _isContinueHovered = false;
  bool _isCreateAvatarPressed = false;
  bool _isCreatingNew = true;
  GeneratedAvatar? _generatedAvatar;
  String? _customAvatarFilePath;
  bool _isPremium = false;

  // ─── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _floatCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _sparkleCtrl;
  late Animation<double> _floatAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _sparkleAnim;

  // ─── Voice & Audio ───────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  String _listeningFor = '';
  late TextEditingController _superpowerController;
  late TextEditingController _questController;
  late TextEditingController _wishController;
  late FlutterTts _tts;

  // ─── Analytics Helpers ──────────────────────────────────────────────────────
  void _logPageView(int pageIndex) {
    FirebaseAnalyticsService.logEvent('hero_creator_page_view', {
      'page_number': pageIndex,
      'is_creating_new': _isCreatingNew,
      'character_name_length': widget.wizardData.characterName.length,
      'has_archetype': _selectedArchetypeId != null,
      'has_avatar': _hasAvatar,
    });
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    
    // Determine initial page
    if (widget.availableCharacters.isNotEmpty) {
      _heroPage = 0;
    } else {
      _heroPage = 1;
    }
    _heroPageController = PageController(initialPage: _heroPage);
    _logPageView(_heroPage);

    if (widget.wizardData.characterAge < 3 ||
        widget.wizardData.characterAge > 99) {
      widget.wizardData.characterAge = 7;
    }
    if (widget.wizardData.characterGender.isEmpty) {
      widget.wizardData.characterGender = 'Girl';
    }
    _nameController = TextEditingController(
      text: widget.wizardData.characterName,
    );
    _superpowerController = TextEditingController(
      text: widget.wizardData.heroSuperpower ?? '',
    );
    _questController = TextEditingController(
      text: widget.wizardData.heroQuest ?? '',
    );
    _wishController = TextEditingController(
      text: widget.wizardData.customElements,
    );

    // ── Animation controllers ──────────────────────────────────────────────────
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -5.0, end: 5.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _sparkleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _sparkleAnim =
        CurvedAnimation(parent: _sparkleCtrl, curve: Curves.easeOut);

    // ── Speech & TTS ──────────────────────────────────────────────────────────
    _speech.initialize().then((available) {
      if (mounted) setState(() => _speechAvailable = available);
    });
    _tts = FlutterTts();
    _initTts();

    AvatarGenerationState().addListener(_onAvatarStateChanged);
    ApiServiceManager.hasPremiumAccess().then((premium) {
      if (mounted) setState(() => _isPremium = premium);
    });

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
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _superpowerController.dispose();
    _questController.dispose();
    _wishController.dispose();
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    _sparkleCtrl.dispose();
    _speech.stop();
    _tts.stop();
    _heroPageController.dispose();
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
        _sparkleCtrl.forward(from: 0);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✨ Your avatar is ready!'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 3),
        ));
      }
      state.consumeAvatar();
    }
  }

  // ─── Navigation Helpers ──────────────────────────────────────────────────────
  void _notifySubStep() {
    final int step;
    if (_heroPage < 3) {
      step = 0; // Create Hero
    } else if (_heroPage == 3) {
      step = 1; // Pick Team
    } else if (_heroPage == 4) {
      step = 2; // Pick Place
    } else {
      step = 3; // Make Magic
    }
    widget.onSubStepChange?.call(step);
  }

  void _heroNextPage() {
    if (_heroPage < 5) {
      _triggerPageCelebration();
      _heroPageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _heroPage++);
      _logPageView(_heroPage);
      _notifySubStep();
    }
  }

  /// Plays shimmer chime + shows a brief star-burst particle overlay.
  void _triggerPageCelebration() {
    AudioAmbienceService().playSfx('sounds/magical_shimmer.mp3');
    _showStarBurst();
  }

  void _showStarBurst() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _StarBurstOverlay(
        onComplete: () {
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  void _heroPrevPage() {
    if (_heroPage > 0) {
      _heroPageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _heroPage--);
      _logPageView(_heroPage);
      _notifySubStep();
    }
  }

  // ─── Character helpers ────────────────────────────────────────────────────────
  void _loadExistingCharacter(Character character) {
    try {
      FirebaseAnalyticsService.logEvent('hero_creator_select_character', {
        'character_id': character.id,
        'character_role': character.role,
        'character_age': character.age,
      });
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
            try {
              safePets.add(Map<String, String>.from(p));
            } catch (_) {}
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
    FirebaseAnalyticsService.logEvent('hero_creator_create_new', {});
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
      // Reset personality to defaults
      widget.wizardData.personalitySliders = {
        'energy': 50,
        'sociability': 50,
        'creativity': 50,
        'confidence': 50,
        'empathy': 50,
        'adventurousness': 50,
      };
    });
    _heroNextPage();
  }

  void _selectArchetype(ArchetypeData archetype) {
    setState(() {
      _selectedArchetypeId = archetype.name;
      widget.wizardData.selectedArchetypeId = archetype.name;
      widget.wizardData.personalitySliders =
          Map<String, int>.from(archetype.attributes);
      // Auto-set superpower from archetype's special ability
      widget.wizardData.heroSuperpower = archetype.specialAbility;
      if (widget.wizardData.characterAge < 1) {
        widget.wizardData.characterAge = 5;
      }
    });
  }

  Future<bool> _saveCharacterDraft() async {
    if (!_isCreatingNew) return true;
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
        'personality_sliders': widget.wizardData.personalitySliders,
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
    if (ok) {
      FirebaseAnalyticsService.logEvent('hero_creator_complete', {
        'is_creating_new': _isCreatingNew,
        'has_avatar': _hasAvatar,
        'archetype': _selectedArchetypeId,
      });
      widget.onNext();
    }
  }

  // ─── TTS Helper ─────────────────────────────────────────────────────────────
  Widget _audioPrompt(String text) {
    return IconButton(
      icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFFFD700), size: 32),
      onPressed: () => _tts.speak(text),
    );
  }

  // ─── Page Builders ──────────────────────────────────────────────────────────

  // Page 0: Welcome / Returning User Choice
  Widget _buildPage0() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _audioPrompt("Welcome back!"),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "Welcome back!",
                style: GoogleFonts.cinzelDecorative(
                  color: const Color(0xFFFFD700),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: widget.availableCharacters.length,
            itemBuilder: (context, index) {
              final char = widget.availableCharacters[index];
              return _CharacterChoiceCard(
                character: char,
                onTap: () {
                  _loadExistingCharacter(char);
                  _handleContinue();
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildCreateNewHeroButton(),
        ),
      ],
    );
  }

  Widget _buildCreateNewHeroButton() {
    return ElevatedButton(
      onPressed: _switchToNewCharacter,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9B3FD8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 8,
        shadowColor: const Color(0xFFFFD700).withAlpha(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle_outline, size: 24),
          const SizedBox(width: 12),
          Text(
            "Create a New Hero",
            style: GoogleFonts.cinzelDecorative(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Page 1: "Who is your hero?"
  Widget _buildPage1() {
    final nameNotEmpty = _nameController.text.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _audioPrompt("Who is your hero?"),
              const SizedBox(width: 8),
              Flexible(
                child: Builder(
                  builder: (context) {
                    return Text(
                      'Create Your Hero',
                      style: GoogleFonts.cinzelDecorative(
                        color: const Color(0xFFFFD700),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildNameScrollInput(),
          const SizedBox(height: 24),
          _buildGenderPicker(),
          const SizedBox(height: 24),
          _buildAgePicker(),
          const SizedBox(height: 40),
          _buildNextArrowButton(enabled: nameNotEmpty, onTap: _heroNextPage),
        ],
      ),
    );
  }

  // Page 2: "What does your hero look like?"
  Widget _buildPage2() {
    final canGoNext = _selectedArchetypeId != null || _hasAvatar;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _audioPrompt("What does your hero look like?"),
              const SizedBox(width: 8),
              Flexible(
                child: Builder(
                  builder: (context) {
                    final band = Theme.of(context).extension<AgeBandThemeData>();
                    final label = band != null && band.band != AgeBand.explorer
                        ? 'What does your ${band.heroLabel.toLowerCase()} look like?'
                        : 'What does your hero look like?';
                    return Text(
                      label,
                      style: GoogleFonts.cinzelDecorative(
                        color: const Color(0xFFFFD700),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAvatarSection(),
          const SizedBox(height: 10),
          if (_hasAvatar) _buildEditAvatarButton() else _buildCreateAvatarButton(),
          const SizedBox(height: 24),
          _buildArchetypeCards(),
          const SizedBox(height: 40),
          _buildNextArrowButton(enabled: canGoNext, onTap: _heroNextPage),
        ],
      ),
    );
  }

  // Page 3: "Who's coming with you?" (Adventure Team — companions + pets)
  // NOTE: This page is built in _buildCompanionPage() — see Task B.
  // Placeholder until companion grid is implemented.
  Widget _buildPage3() {
    return _buildAdventureTeamPage();
  }

  /// Temporary adventure team placeholder — replaced when companion grid is built.
  Widget _buildAdventureTeamPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _audioPrompt("Who's coming with you?"),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "Who's Coming With You?",
                  style: GoogleFonts.cinzelDecorative(
                    color: const Color(0xFFFFD700),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Show archetype power confirmation if selected
          if (_selectedArchetypeId != null) _buildArchetypePowerBadge(),
          const SizedBox(height: 24),
          // Companion grid will go here (Task B)
          _buildCompanionGrid(),
          const SizedBox(height: 40),
          _buildNextArrowButton(enabled: true, onTap: _heroNextPage),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Shows a confirmation badge for the selected archetype's special ability.
  Widget _buildArchetypePowerBadge() {
    final archetype = CharacterArchetypes.all
        .where((a) => a.name == _selectedArchetypeId)
        .firstOrNull;
    if (archetype == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withAlpha(30),
            const Color(0xFF9E6CFF).withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Hero Type:',
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (archetype.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    archetype.imagePath!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Text('⚡', style: TextStyle(fontSize: 28)),
                  ),
                )
              else
                const Text('⚡', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      archetype.name,
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      archetype.specialAbility,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Companion selection grid — 7 magical creatures + saved friends + pet management.
  Widget _buildCompanionGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pick your adventure team:',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 12),
        // ── Saved characters as friends ──────────────────────────────────────
        if (widget.availableCharacters.isNotEmpty) ...[
          const Text(
            'Your Friends:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.availableCharacters
                .where((c) => c.name != widget.wizardData.characterName)
                .map((c) {
              final isSelected =
                  widget.wizardData.companionNames.contains(c.name);
              return _FriendChipButton(
                character: c,
                isSelected: isSelected,
                onTap: () => setState(() {
                  if (isSelected) {
                    widget.wizardData.companionNames.remove(c.name);
                    widget.wizardData.selectedCompanions.remove(c.name);
                  } else {
                    widget.wizardData.companionNames.add(c.name);
                    widget.wizardData.selectedCompanions.add(c.name);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        // ── Image-based companion grid ────────────────────────────────────────
        _CompanionImageGrid(
          wizardData: widget.wizardData,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        // ── Add pet photo button ──────────────────────────────────────────────
        _AddPetPhotoButton(onTap: _pickPetPhoto),
        const SizedBox(height: 12),
        // Pets from character profile
        if (widget.wizardData.pets.isNotEmpty) ...[
          const Text(
            'Your pets:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.wizardData.pets.map((pet) {
              final petName = pet['name'] ?? 'Pet';
              final isSelected =
                  widget.wizardData.companionNames.contains(petName);
              return _chipButton(
                label: '🐾 $petName',
                selected: isSelected,
                onTap: () => setState(() {
                  if (isSelected) {
                    widget.wizardData.companionNames.remove(petName);
                  } else {
                    widget.wizardData.companionNames.add(petName);
                  }
                }),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        // Go Solo option
        TextButton.icon(
          onPressed: () => setState(() {
            widget.wizardData.companionNames.clear();
            widget.wizardData.selectedCompanions.clear();
          }),
          icon: const Icon(Icons.person, color: Colors.white54, size: 18),
          label: const Text(
            'Go Solo — no companions',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Future<void> _pickPetPhoto() async {
    final source = await _showPhotoSourceDialog();
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: source, maxWidth: 800, imageQuality: 75);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    setState(() {
      widget.wizardData.pets
          .add({'name': 'My Pet', 'species': 'Pet', 'personality': ''});
      widget.wizardData.petAvatars['My Pet'] = GeneratedAvatar(
        id: 'pet_photo_${DateTime.now().millisecondsSinceEpoch}',
        imageBase64: 'data:image/jpeg;base64,$b64',
        seed: 'photo',
        style: 'photo',
        attributes: const {},
        generatedAt: DateTime.now(),
      );
      widget.wizardData.companionNames.add('My Pet');
    });
  }

  Future<ImageSource?> _showPhotoSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C1B47),
        title: const Text('Add Your Pet',
            style: TextStyle(color: Color(0xFFFFD700))),
        content: const Text('How would you like to add your pet?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt, color: Color(0xFFD4A0FF)),
            label: const Text('Take Photo',
                style: TextStyle(color: Color(0xFFD4A0FF))),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library, color: Color(0xFFD4A0FF)),
            label: const Text('Choose from Gallery',
                style: TextStyle(color: Color(0xFFD4A0FF))),
          ),
        ],
      ),
    );
  }

  // Page 4: "Where will your adventure happen?" (Scene selection)
  static const List<String> _curatedSceneIds = [
    'volcano_dragons',
    'crystal_cavern',
    'vanishing_colors',
    'big_feelings_quest',
    'safe_space',
  ];

  Widget _buildPage4() {
    final age = widget.wizardData.characterAge;
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;

    // Sprout/Explorer bands get 5 curated scenes; Adventurer/Creator get all
    final showAll = band.band == AgeBand.adventurer || band.band == AgeBand.creator;
    final scenes = showAll
        ? ScenarioData.all
        : ScenarioData.all.where((s) => _curatedSceneIds.contains(s.id)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _audioPrompt("Where will your adventure happen?"),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "Where to adventure?",
                  style: GoogleFonts.cinzelDecorative(
                    color: const Color(0xFFFFD700),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Pick a world — or skip and let the magic decide!",
            style: GoogleFonts.fredoka(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ...scenes.map((scene) {
            final isSelected = widget.wizardData.selectedScenario == scene.id;
            return GestureDetector(
              onTap: () => setState(() {
                widget.wizardData.selectedScenario =
                    isSelected ? null : scene.id;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6B3FA0).withAlpha(220)
                      : Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFFD700)
                        : const Color(0xFFD4A0FF).withAlpha(80),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Text(scene.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scene.titleForAge(age),
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            scene.descriptionForAge(age),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFFFFD700), size: 22),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          _buildNextArrowButton(enabled: true, onTap: _heroNextPage),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Page 5: "What kind of story?"
  Widget _buildPage5() {
    final data = widget.wizardData;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _audioPrompt("What kind of story do you want?"),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "What kind of story?",
                  style: GoogleFonts.cinzelDecorative(
                    color: const Color(0xFFFFD700),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Story mode selection — 2×2 grid
          Text(
            "Pick your story style",
            style: GoogleFonts.fredoka(
              color: Colors.white.withAlpha(200),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ImageModeOrb(
                    modeType: 'tales',
                    label: 'Story Quest',
                    isActive: data.includeIllustrations,
                    onTap: () => setState(() => data.includeIllustrations = !data.includeIllustrations),
                    primaryColor: const Color(0xFFAA88FF),
                    secondaryColor: const Color(0xFFE28EFF),
                  ),
                  const SizedBox(width: 24),
                  ImageModeOrb(
                    modeType: 'rhyme',
                    label: 'Rhyme Time',
                    isActive: data.rhymeTimeMode,
                    onTap: () => setState(() {
                      data.rhymeTimeMode = !data.rhymeTimeMode;
                      if (data.rhymeTimeMode) {
                        data.learningToReadMode = false;
                        data.interactiveMode = false;
                      }
                    }),
                    primaryColor: const Color(0xFF00D4DD),
                    secondaryColor: const Color(0xFF7FDDFF),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ImageModeOrb(
                    modeType: 'reading',
                    label: 'First Reader',
                    isActive: data.learningToReadMode,
                    onTap: () => setState(() {
                      data.learningToReadMode = !data.learningToReadMode;
                      if (data.learningToReadMode) {
                        data.rhymeTimeMode = false;
                        data.interactiveMode = false;
                      }
                    }),
                    primaryColor: const Color(0xFFB88AFF),
                    secondaryColor: const Color(0xFFFF9ECC),
                  ),
                  const SizedBox(width: 24),
                  ImageModeOrb(
                    modeType: 'pickpath',
                    label: 'Pick a Path',
                    isActive: data.interactiveMode,
                    onTap: () => setState(() {
                      data.interactiveMode = !data.interactiveMode;
                      if (data.interactiveMode) {
                        data.rhymeTimeMode = false;
                        data.learningToReadMode = false;
                      }
                    }),
                    primaryColor: const Color(0xFF9E6CFF),
                    secondaryColor: const Color(0xFFFFB3E6),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 36),
          // Story length selection
          Text(
            "How long should it be?",
            style: GoogleFonts.fredoka(
              color: Colors.white.withAlpha(200),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ImageCrystalFormation(
                  type: 'quick',
                  label: 'Quick',
                  isSelected: data.storyLength == 'quick',
                  onTap: () => setState(() => data.storyLength = 'quick'),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: ImageCrystalFormation(
                  type: 'classic',
                  label: 'Classic',
                  isSelected: data.storyLength == 'standard',
                  onTap: () => setState(() => data.storyLength = 'standard'),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: ImageCrystalFormation(
                  type: 'epic',
                  label: 'Epic',
                  isSelected: data.storyLength == 'epic',
                  onTap: () => setState(() => data.storyLength = 'epic'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Wish field — "Anything special you want in your story?"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _audioPrompt("Anything special you want in your story?"),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "Anything special you want?",
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _wishController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'I want to ride a magic carpet…',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withAlpha(20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) =>
                            widget.wizardData.customElements = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _listeningFor == 'wish' ? Icons.mic : Icons.mic_none,
                        color: _listeningFor == 'wish'
                            ? Colors.yellow
                            : Colors.white,
                      ),
                      onPressed: () => _toggleListening('wish'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildNextArrowButton(enabled: true, onTap: _heroNextPage),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNextArrowButton({required bool enabled, required VoidCallback onTap}) {
    return _PressableArrowButton(enabled: enabled, onTap: onTap);
  }

  // ─── Personality Pairs ──────────────────────────────────────────────────────
  Widget _buildPersonalityPairs() {
    return Column(
      children: [
        _PersonalityPair(
          leftLabel: "Brave",
          leftIcon: Icons.pets, // Lion-like
          rightLabel: "Careful",
          rightIcon: Icons.visibility, // Cat-like
          sliderKey: "confidence",
          currentValue: widget.wizardData.personalitySliders['confidence'] ?? 50,
          onChanged: (val) => setState(() => widget.wizardData.personalitySliders['confidence'] = val),
        ),
        const SizedBox(height: 12),
        _PersonalityPair(
          leftLabel: "Loud and Silly",
          leftIcon: Icons.campaign,
          rightLabel: "Quiet and Thoughtful",
          rightIcon: Icons.menu_book,
          sliderKey: "energy",
          currentValue: widget.wizardData.personalitySliders['energy'] ?? 50,
          onChanged: (val) => setState(() => widget.wizardData.personalitySliders['energy'] = val),
        ),
        const SizedBox(height: 12),
        _PersonalityPair(
          leftLabel: "Team Player",
          leftIcon: Icons.groups,
          rightLabel: "Solo Explorer",
          rightIcon: Icons.explore,
          sliderKey: "sociability",
          currentValue: widget.wizardData.personalitySliders['sociability'] ?? 50,
          onChanged: (val) => setState(() => widget.wizardData.personalitySliders['sociability'] = val),
        ),
        const SizedBox(height: 12),
        _PersonalityPair(
          leftLabel: "Creative Dreamer",
          leftIcon: Icons.brush,
          rightLabel: "Practical Thinker",
          rightIcon: Icons.build,
          sliderKey: "creativity",
          currentValue: widget.wizardData.personalitySliders['creativity'] ?? 50,
          onChanged: (val) => setState(() => widget.wizardData.personalitySliders['creativity'] = val),
        ),
        const SizedBox(height: 12),
        _PersonalityPair(
          leftLabel: "Homebody",
          leftIcon: Icons.home,
          rightLabel: "Adventurer",
          rightIcon: Icons.rocket_launch,
          sliderKey: "adventurousness",
          currentValue: widget.wizardData.personalitySliders['adventurousness'] ?? 50,
          onChanged: (val) => setState(() => widget.wizardData.personalitySliders['adventurousness'] = val),
        ),
      ],
    );
  }

  // ─── Avatar, Age, Gender, Name, Archetype, Superpower, Continue logic ──────────

  Future<void> _openAvatarCreation() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2C1B47), Color(0xFF4A1A72)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Choose Your Avatar',
              style: GoogleFonts.cinzelDecorative(
                color: const Color(0xFFFFD700),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _AvatarOptionTile(
              icon: Icons.auto_awesome,
              title: 'Browse Character Gallery',
              subtitle: 'Pick from 94 pre-made heroes & heroines',
              onTap: () {
                Navigator.pop(context);
                _openAvatarGallery();
              },
            ),
            const SizedBox(height: 8),
            _AvatarOptionTile(
              icon: Icons.tune_rounded,
              title: 'Build Your Look',
              subtitle: 'See heroes that match your character\'s age & vibe',
              onTap: () {
                Navigator.pop(context);
                _openAvatarGallery(preFilter: true);
              },
            ),
            const SizedBox(height: 8),
            _AvatarOptionTile(
              icon: Icons.camera_alt_rounded,
              title: 'Upload Photo → AI Avatar',
              subtitle: _isPremium
                  ? 'Turn a photo into a magical storybook avatar'
                  : '⭐ Premium — upgrade to unlock',
              onTap: _isPremium
                  ? () {
                      Navigator.pop(context);
                      _openCustomAvatarScreen();
                    }
                  : null,
            ),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _openAvatarGallery({bool preFilter = false}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AvatarGallerySelector(
        isPremium: _isPremium,
        onAvatarSelected: (avatar) {
          if (mounted) {
            setState(() {
              _generatedAvatar = avatar;
              _customAvatarFilePath = null;
              widget.wizardData.generatedAvatar = avatar;
              widget.wizardData.customAvatarPath = avatar.imageBase64;
            });
            _sparkleCtrl.forward(from: 0);
          }
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _openCustomAvatarScreen() async {
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

  bool get _hasAvatar =>
      _generatedAvatar != null || _customAvatarFilePath != null;

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
      if (data.startsWith('assets/')) return Image.asset(data, fit: BoxFit.cover);
      if (data.startsWith('http')) return Image.network(data, fit: BoxFit.cover);
      try {
        return Image.memory(base64Decode(data.split(',').last), fit: BoxFit.cover);
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
            gradient: RadialGradient(colors: [Color(0xFF7B4BAA), Color(0xFF2D0A4E)]),
          ),
        ),
      );

  Widget _buildAvatarSection() {
    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (ctx, child) => Transform.translate(
        offset: Offset(0, _floatAnim.value),
        child: child,
      ),
      child: AnimatedBuilder(
        animation: _glowCtrl,
        builder: (ctx, child) {
          final g = _glowAnim.value;
          return GestureDetector(
            onTap: _openAvatarCreation,
            child: SizedBox(
              width: 172,
              height: 172,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 172,
                    height: 172,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromARGB((g * 160).round(), 0xFF, 0xD7, 0x00),
                          blurRadius: 28 + g * 18,
                          spreadRadius: g * 6,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 148,
                    height: 148,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Stack(
                      children: [
                        ClipOval(
                          child: SizedBox(width: 148, height: 148, child: _buildAvatarContent()),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Color.fromARGB((g * 200).round(), 0xD4, 0xA0, 0xFF),
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSparkleOverlay(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSparkleOverlay() {
    const radius = 86.0;
    const count = 8;
    final sparkleChars = ['✦', '★', '✧', '✦', '★', '✧', '✦', '★'];
    return AnimatedBuilder(
      animation: _sparkleAnim,
      builder: (ctx, _) {
        final t = _sparkleAnim.value;
        if (t == 0) return const SizedBox.shrink();
        return SizedBox(
          width: 172,
          height: 172,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(count, (i) {
              final angle = (i / count) * math.pi * 2;
              final delay = i / count;
              final progress = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
              final dist = progress * radius;
              final opacity = progress < 0.6 ? progress / 0.6 : (1.0 - progress) / 0.4;
              final scale = 0.4 + progress * 1.0;
              final x = 86 + math.cos(angle) * dist;
              final y = 86 + math.sin(angle) * dist;
              return Positioned(
                left: x - 10,
                top: y - 10,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Text(
                      sparkleChars[i],
                      style: TextStyle(
                        fontSize: 16,
                        color: i.isEven ? const Color(0xFFFFD700) : const Color(0xFFD4A0FF),
                        shadows: const [Shadow(color: Color(0xFFFFD700), blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildAgePicker() {
    return Column(
      children: [
        // Tap-to-type age input — tapping the number opens keyboard
        GestureDetector(
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (ctx) {
                final ctrl = TextEditingController(text: '${widget.wizardData.characterAge}');
                return AlertDialog(
                  backgroundColor: const Color(0xFF2A1060),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text('How old is your hero?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzelDecorative(color: const Color(0xFFFFD700), fontSize: 16)),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.cinzelDecorative(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '7',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    onSubmitted: (v) {
                      final n = int.tryParse(v);
                      if (n != null) {
                        setState(() => widget.wizardData.characterAge = n.clamp(3, 99));
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        final n = int.tryParse(ctrl.text);
                        if (n != null) {
                          setState(() => widget.wizardData.characterAge = n.clamp(3, 99));
                        }
                        Navigator.pop(ctx);
                      },
                      child: Text('Done',
                          style: GoogleFonts.fredoka(color: const Color(0xFFFFD700), fontSize: 18)),
                    ),
                  ],
                );
              },
            );
          },
          child: Column(
            children: [
              Text(
                '${widget.wizardData.characterAge}',
                style: GoogleFonts.cinzelDecorative(
                  color: const Color(0xFFFFD700),
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Color(0xFFFFD700), blurRadius: 16)],
                ),
              ),
              Text(
                'Tap to change age',
                style: GoogleFonts.cinzelDecorative(
                  color: Colors.white.withAlpha(160),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AgeStepButton(
              icon: Icons.remove_rounded,
              size: 40,
              onTap: () => setState(() =>
                  widget.wizardData.characterAge =
                      (widget.wizardData.characterAge - 1).clamp(3, 99)),
            ),
            const SizedBox(width: 24),
            _AgeStepButton(
              icon: Icons.add_rounded,
              size: 40,
              onTap: () => setState(() =>
                  widget.wizardData.characterAge =
                      (widget.wizardData.characterAge + 1).clamp(3, 99)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildGenderImageButton(
          normalImage: 'assets/images/ui/boy_normal.png',
          hoverImage: 'assets/images/ui/boy_hover.png',
          pressedImage: 'assets/images/ui/boy_pressed.png',
          label: 'Boy',
          gender: 'Boy',
        ),
        const SizedBox(width: 40),
        _buildGenderImageButton(
          normalImage: 'assets/images/ui/girl_normal.png',
          hoverImage: 'assets/images/ui/girl_hover.png',
          pressedImage: 'assets/images/ui/girl_pressed.png',
          label: 'Girl',
          gender: 'Girl',
        ),
      ],
    );
  }

  Widget _buildGenderImageButton({
    required String normalImage,
    required String hoverImage,
    required String pressedImage,
    required String label,
    required String gender,
  }) {
    final isSelected = widget.wizardData.characterGender == gender;
    return _GenderImageButton(
      normalImage: normalImage,
      hoverImage: hoverImage,
      pressedImage: pressedImage,
      label: label,
      isSelected: isSelected,
      onTap: () => setState(() => widget.wizardData.characterGender = gender),
    );
  }

  Widget _buildNameScrollInput() {
    return SizedBox(
      height: 100,
      child: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/ui/scroll_name_input.png', fit: BoxFit.fill)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 42),
              child: TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzelDecorative(fontSize: 20, color: const Color(0xFF3A1C00), fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: "Hero's Name",
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => widget.wizardData.characterName = v.trim()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchetypeCards() {
    final archetypes = CharacterArchetypes.all;
    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: archetypes.length,
        itemBuilder: (context, index) {
          final a = archetypes[index];
          final isSelected = _selectedArchetypeId == a.name;
          return GestureDetector(
            onTap: () => _selectArchetype(a),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 160,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: isSelected ? [const Color(0xFF9B3FD8), const Color(0xFFFFD700).withAlpha(60)] : [Colors.white10, Colors.white10]),
                border: Border.all(color: isSelected ? const Color(0xFFFFD700) : Colors.white24, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (a.imagePath != null) Image.asset(a.imagePath!, height: 120, fit: BoxFit.contain) else Text(a.icon ?? '✨', style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text(a.name, textAlign: TextAlign.center, style: GoogleFonts.fredoka(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateAvatarButton() {
    return GestureDetector(
      onTap: _openAvatarCreation,
      child: Image.asset('assets/images/ui/create_avatar_btn.png', height: 70, fit: BoxFit.contain),
    );
  }

  Widget _buildEditAvatarButton() => TextButton.icon(
        onPressed: _openAvatarCreation,
        icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFD4A0FF)),
        label: Text('Change Avatar', style: GoogleFonts.cinzelDecorative(color: const Color(0xFFD4A0FF), fontSize: 12)),
      );

  void _toggleListening(String field) async {
    if (!_speechAvailable) return;
    if (_listeningFor == field) {
      await _speech.stop();
      setState(() => _listeningFor = '');
      return;
    }
    setState(() => _listeningFor = field);
    await _speech.listen(onResult: (result) {
      if (!mounted) return;
      setState(() {
        if (field == 'superpower') {
          _superpowerController.text = result.recognizedWords;
          widget.wizardData.heroSuperpower = result.recognizedWords.isEmpty ? null : result.recognizedWords;
        } else if (field == 'wish') {
          _wishController.text = result.recognizedWords;
          widget.wizardData.customElements = result.recognizedWords;
        } else {
          _questController.text = result.recognizedWords;
          widget.wizardData.heroQuest = result.recognizedWords.isEmpty ? null : result.recognizedWords;
        }
        if (result.finalResult) _listeningFor = '';
      });
    });
  }

  Widget _buildSuperpowerSection() {
    final name = widget.wizardData.characterName.isNotEmpty ? widget.wizardData.characterName : 'your hero';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _superpowerLabel('⚡ What is $name\'s superpower?'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: HeroCreatorStepData.superpowers.map((entry) {
            final (label, value) = entry;
            final selected = widget.wizardData.heroSuperpower == value;
            return _chipButton(label: label, selected: selected, onTap: () => setState(() {
              widget.wizardData.heroSuperpower = selected ? null : value;
              _superpowerController.text = selected ? '' : value;
            }));
          }).toList(),
        ),
        const SizedBox(height: 10),
        _buildVoiceInput(controller: _superpowerController, hint: 'Speak your own…', field: 'superpower', onChanged: (v) => widget.wizardData.heroSuperpower = v.trim().isEmpty ? null : v.trim()),
        const SizedBox(height: 20),
        _superpowerLabel('🗺️ What is $name\'s quest?'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: HeroCreatorStepData.quests.map((entry) {
            final (label, value) = entry;
            final selected = widget.wizardData.heroQuest == value;
            return _chipButton(label: label, selected: selected, onTap: () => setState(() {
              widget.wizardData.heroQuest = selected ? null : value;
              _questController.text = selected ? '' : value;
            }));
          }).toList(),
        ),
        const SizedBox(height: 10),
        _buildVoiceInput(controller: _questController, hint: 'Speak your own…', field: 'quest', onChanged: (v) => widget.wizardData.heroQuest = v.trim().isEmpty ? null : v.trim()),
      ],
    );
  }

  Widget _superpowerLabel(String text) => Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Color(0xFFFFD700), blurRadius: 6)]));

  Widget _chipButton({required String label, required bool selected, required VoidCallback onTap}) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: selected ? const Color(0xFFFFD700).withAlpha(60) : Colors.white10, border: Border.all(color: selected ? const Color(0xFFFFD700) : Colors.white24), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 13, color: selected ? const Color(0xFFFFD700) : Colors.white)),
    ),
  );

  Widget _buildVoiceInput({required TextEditingController controller, required String hint, required String field, required void Function(String) onChanged}) {
    final isListening = _listeningFor == field;
    return Row(
      children: [
        Expanded(child: TextField(controller: controller, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onChanged: onChanged)),
        const SizedBox(width: 8),
        IconButton(icon: Icon(isListening ? Icons.mic : Icons.mic_none, color: isListening ? Colors.yellow : Colors.white), onPressed: () => _toggleListening(field)),
      ],
    );
  }

  Widget _buildContinueButton() => GestureDetector(
        onTapDown: (_) => setState(() => _isContinuePressed = true),
        onTapUp: (_) => setState(() => _isContinuePressed = false),
        onTapCancel: () => setState(() => _isContinuePressed = false),
        onTap: _handleContinue,
        child: AnimatedScale(
          scale: _isContinuePressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: Image.asset(
            _isContinuePressed
                ? 'assets/images/ui/continue_btn_pressed.png'
                : 'assets/images/ui/continue_normal.png',
            height: 70, width: double.infinity, fit: BoxFit.contain,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MagicStarCursor(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF120226), Color(0xFF3D1166), Color(0xFF120226)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              PageView(
                controller: _heroPageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPage0(),
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                  _buildPage4(),
                  _buildPage5(),
                ],
              ),
              if (_heroPage > 0)
                Positioned(
                  top: 10, left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: _heroPrevPage,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Support Widgets ──────────────────────────────────────────────────────────

class _CharacterChoiceCard extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;

  const _CharacterChoiceCard({required this.character, required this.onTap});

  ImageProvider<Object> _getAvatarProvider(String imageBase64) {
    if (imageBase64.startsWith('assets/')) {
      return AssetImage(imageBase64);
    }
    if (imageBase64.startsWith('http')) {
      return NetworkImage(imageBase64);
    }
    try {
      final normalized = imageBase64.contains(',') ? imageBase64.split(',').last : imageBase64;
      return MemoryImage(base64Decode(normalized));
    } catch (_) {
      return const AssetImage('assets/images/hero_placeholder.jpg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarData = character.generatedAvatar?.imageBase64;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD4A0FF).withAlpha(100)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: const Color(0xFF3A2363),
              backgroundImage: avatarData != null
                ? _getAvatarProvider(avatarData)
                : const AssetImage('assets/images/hero_placeholder.jpg') as ImageProvider,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(character.name, style: GoogleFonts.cinzelDecorative(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("${character.age} years old • ${character.role}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFFD700), size: 40),
          ],
        ),
      ),
    );
  }
}

class _PersonalityPair extends StatelessWidget {
  final String leftLabel;
  final IconData leftIcon;
  final String rightLabel;
  final IconData rightIcon;
  final String sliderKey;
  final int currentValue;
  final ValueChanged<int> onChanged;

  const _PersonalityPair({
    required this.leftLabel,
    required this.leftIcon,
    required this.rightLabel,
    required this.rightIcon,
    required this.sliderKey,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLeft = currentValue < 50;
    final bool isRight = currentValue > 50;

    return Row(
      children: [
        Expanded(child: _buildChoice(label: leftLabel, icon: leftIcon, isSelected: isLeft, value: 25)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text("or", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
        ),
        Expanded(child: _buildChoice(label: rightLabel, icon: rightIcon, isSelected: isRight, value: 75)),
      ],
    );
  }

  Widget _buildChoice({required String label, required IconData icon, required bool isSelected, required int value}) {
    return GestureDetector(
      onTap: () => onChanged(isSelected ? 50 : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD700).withAlpha(40) : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? const Color(0xFFFFD700) : Colors.white24, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFFD700).withAlpha(60), blurRadius: 10)] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFFFD700) : Colors.white70, size: 28),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? const Color(0xFFFFD700) : Colors.white, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ─── Section Classes (Move static data here) ──────────────────────────────────
class HeroCreatorStepData {
  static const superpowers = [
    ('⚡ Brave Heart', 'Brave Heart'),
    ('💛 Kindness Magic', 'Kindness Magic'),
    ('🧠 Problem-Solver Brain', 'Problem-Solver Brain'),
    ('🤝 Helping Hands', 'Helping Hands'),
    ('🌟 Creative Spark', 'Creative Spark'),
    ('👂 Super Listener', 'Super Listener'),
  ];
  static const quests = [
    ('🤝 Making new friends', 'Making new friends'),
    ('🌊 Taming big feelings', 'Taming big feelings'),
    ('🦁 Being brave when scared', 'Being brave when scared'),
    ('🎁 Sharing and taking turns', 'Sharing and taking turns'),
    ('🌱 Trying something new', 'Trying something new'),
    ("🦸 Standing up for what's right", "Standing up for what's right"),
  ];
}

class _AgeStepButton extends StatefulWidget {
  final IconData icon; final VoidCallback onTap; final double size;
  const _AgeStepButton({required this.icon, required this.onTap, this.size = 52});
  @override State<_AgeStepButton> createState() => _AgeStepButtonState();
}
class _AgeStepButtonState extends State<_AgeStepButton> {
  bool _pressed = false;
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true), onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); }, onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(scale: _pressed ? 0.88 : 1.0, duration: const Duration(milliseconds: 100), child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [const Color(0xFF5B1BAA), const Color(0xFF9B3FD8)]), boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withAlpha(180), blurRadius: 22)]), child: Icon(widget.icon, color: const Color(0xFFFFE066), size: widget.size * 0.5))),
    );
  }
}

class _AvatarOptionTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback? onTap;
  const _AvatarOptionTile({required this.icon, required this.title, required this.subtitle, this.onTap});
  @override Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return Opacity(opacity: isDisabled ? 0.45 : 1.0, child: Material(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(16), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFD700).withAlpha(40), border: Border.all(color: const Color(0xFFFFD700).withAlpha(150), width: 1.5)), child: Icon(icon, color: const Color(0xFFFFD700), size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13))])), const Icon(Icons.chevron_right, color: Colors.white54, size: 20)])))));
  }
}

class _PetsSection extends StatelessWidget {
  final WizardData wizardData; final VoidCallback onUpdate;
  const _PetsSection({required this.wizardData, required this.onUpdate});

  @override Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Adventure Team', style: GoogleFonts.cinzelDecorative(color: const Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(height: 80, child: ListView(scrollDirection: Axis.horizontal, children: [
          GestureDetector(onTap: () => _showAddPetDialog(context), child: Container(width: 70, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFD700).withAlpha(150), width: 2), gradient: const LinearGradient(colors: [Color(0xFF5B1BAA), Color(0xFF2D0A4E)])), child: const Icon(Icons.add, color: Color(0xFFFFD700), size: 30))),
          ...wizardData.pets.map((pet) => _buildPetCircle(context, pet)),
        ])),
      ],
    );
  }

  Widget _buildPetCircle(BuildContext context, Map<String, String> pet) {
    final name = pet['name'] ?? '';
    final avatar = wizardData.petAvatars[name];
    final photo = wizardData.petPhotos[name];
    Widget petImage;
    if (avatar != null) {
      petImage = Image.memory(base64Decode(avatar.imageBase64.split(',').last), fit: BoxFit.cover);
    } else if (photo != null) {
      petImage = Image.memory(base64Decode(photo), fit: BoxFit.cover);
    } else {
      petImage = Center(child: Text(_getEmojiForSpecies(pet['species']), style: const TextStyle(fontSize: 30)));
    }
    return Container(width: 70, margin: const EdgeInsets.only(right: 12), child: Column(children: [Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFD700), width: 2)), child: ClipOval(child: petImage)), const SizedBox(height: 4), Text(name, style: const TextStyle(color: Colors.white, fontSize: 10), overflow: TextOverflow.ellipsis)]));
  }

  void _showAddPetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final breedController = TextEditingController();
    String species = 'Dog';
    String? pickedPhotoBase64;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final selectedPreviewImage = _PetsSection._speciesImageAssets[species];

          Future<void> pickPhoto() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
            if (picked != null) {
              final bytes = await picked.readAsBytes();
              setState(() => pickedPhotoBase64 = base64Encode(bytes));
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF120226), Color(0xFF3D1166)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD700).withAlpha(150), width: 2),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Add a Magical Pet', style: GoogleFonts.cinzelDecorative(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700)), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Center(child: GestureDetector(onTap: pickPhoto, child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: pickedPhotoBase64 != null ? const Color(0xFFD4A0FF) : const Color(0xFFFFD700), width: 2.5)), child: ClipOval(child: pickedPhotoBase64 != null ? Image.memory(base64Decode(pickedPhotoBase64!), fit: BoxFit.cover) : selectedPreviewImage != null ? Image.asset(selectedPreviewImage, fit: BoxFit.cover) : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_rounded, color: const Color(0xFFD4A0FF), size: 30), Text('Add Photo', style: TextStyle(color: const Color(0xFFD4A0FF), fontSize: 10))]))))),
                    const SizedBox(height: 16),
                    TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: _petFieldDecoration(labelText: 'Pet Name', hintText: 'e.g. Luna')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(value: species, dropdownColor: const Color(0xFF2A0A4E), style: const TextStyle(color: Colors.white), items: _speciesOptions.map((s) => DropdownMenuItem(value: s, child: Text('${_getEmojiForSpecies(s)} $s'))).toList(), onChanged: (v) { if (v != null) setState(() => species = v); }, decoration: _petFieldDecoration(labelText: 'Species')),
                    const SizedBox(height: 12),
                    TextField(controller: breedController, style: const TextStyle(color: Colors.white), decoration: _petFieldDecoration(labelText: 'Breed / Appearance', hintText: 'e.g. Golden Retriever')),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;
                        final result = await Navigator.push<GeneratedAvatar>(context, MaterialPageRoute(builder: (_) => CustomPetAvatarScreen(petName: nameController.text.trim(), species: species, breedDescription: breedController.text.trim(), ownerFavoriteColor: wizardData.favoriteColor)));
                        if (result != null) {
                          wizardData.pets.add({'name': nameController.text.trim(), 'species': species, 'breed': breedController.text.trim()});
                          wizardData.petAvatars[nameController.text.trim()] = result;
                          onUpdate(); if (context.mounted) Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Make Pet Magical ✨'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFFD700), side: const BorderSide(color: Color(0xFFFFD700))),
                    ),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
                      ElevatedButton(onPressed: () {
                        if (nameController.text.trim().isNotEmpty) {
                          final petName = nameController.text.trim();
                          wizardData.pets.add({'name': petName, 'species': species, 'breed': breedController.text.trim()});
                          if (pickedPhotoBase64 != null) wizardData.petPhotos[petName] = pickedPhotoBase64!;
                          onUpdate(); Navigator.pop(context);
                        }
                      }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B3FD8), foregroundColor: Colors.white), child: const Text('Add Pet'))
                    ]),
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
      labelText: labelText, hintText: hintText, labelStyle: const TextStyle(color: Color(0xFFFFD700)), hintStyle: const TextStyle(color: Colors.white38),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFFFD700).withAlpha(100))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2)),
      filled: true, fillColor: Colors.white10,
    );
  }

  static const List<String> _speciesOptions = ['Dog', 'Cat', 'Bird', 'Hamster', 'Fish', 'Bunny', 'Reptile', 'Other'];
  static const Map<String, String> _speciesImageAssets = {
    'Fish': 'assets/images/companions/fish.png', 'Bunny': 'assets/images/companions/bunny.png', 'Hamster': 'assets/images/companions/hamster.png', 'Reptile': 'assets/images/companions/reptile.png',
  };

  String _getEmojiForSpecies(String? species) {
    switch (species) {
      case 'Dog': return '🐕'; case 'Cat': return '🐱'; case 'Bird': return '🐦'; case 'Hamster': return '🐹'; case 'Fish': return '🐠'; case 'Bunny': return '🐰'; case 'Reptile': return '🦎'; default: return '🐾';
    }
  }
}

/// Lightweight companion descriptor used for the adventure team grid on Page 3.
class _QuickCompanion {
  final String id;
  final String emoji;
  final String name;

  const _QuickCompanion({
    required this.id,
    required this.emoji,
    required this.name,
  });
}

// ── Companion Image Grid ─────────────────────────────────────────────────────

const _companions = [
  (id: 'dragon', name: 'Dragon'),
  (id: 'owl', name: 'Wise Owl'),
  (id: 'cat', name: 'Shadow Cat'),
  (id: 'dog', name: 'Star Dog'),
  (id: 'unicorn', name: 'Unicorn'),
  (id: 'fox', name: 'Clever Fox'),
  (id: 'robin', name: 'Rockin\' Robin'),
];

class _CompanionImageGrid extends StatelessWidget {
  final WizardData wizardData;
  final VoidCallback onChanged;

  const _CompanionImageGrid({required this.wizardData, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _companions.map((c) {
        final isSelected = wizardData.companionNames.contains(c.name);
        return _CompanionImageButton(
          id: c.id,
          name: c.name,
          isSelected: isSelected,
          onTap: () {
            if (isSelected) {
              wizardData.companionNames.remove(c.name);
              wizardData.selectedCompanions.remove(c.id);
            } else {
              wizardData.companionNames.add(c.name);
              wizardData.selectedCompanions.add(c.id);
            }
            onChanged();
          },
        );
      }).toList(),
    );
  }
}

class _CompanionImageButton extends StatefulWidget {
  final String id;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompanionImageButton({
    required this.id,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CompanionImageButton> createState() => _CompanionImageButtonState();
}

class _CompanionImageButtonState extends State<_CompanionImageButton> {
  bool _pressed = false;

  String get _normalImage =>
      'assets/images/companions/${widget.id}_normal.jpg';
  String get _pressedImage =>
      'assets/images/companions/${widget.id}_pressed.jpg';

  @override
  Widget build(BuildContext context) {
    const double size = 100;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isSelected
                      ? const Color(0xFFFFD700)
                      : Colors.white24,
                  width: widget.isSelected ? 3 : 1.5,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withAlpha(120),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: Stack(
                children: [
                  ClipOval(
                    child: Image.asset(
                      _pressed ? _pressedImage : _normalImage,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: size,
                        height: size,
                        color: const Color(0xFF3A2363),
                        child: const Icon(Icons.pets,
                            color: Colors.white54, size: 40),
                      ),
                    ),
                  ),
                  if (widget.isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFD700),
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.black, size: 14),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: widget.isSelected
                    ? const Color(0xFFFFD700)
                    : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Pet Photo Button ─────────────────────────────────────────────────────

class _AddPetPhotoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPetPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4A0FF).withAlpha(150),
            width: 1.5,
            // dashed effect approximated via low opacity + style
          ),
          color: Colors.white.withAlpha(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4A0FF).withAlpha(40),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFFD4A0FF), size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Your Pet',
                  style: TextStyle(
                    color: Color(0xFFD4A0FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '(tap to snap or pick photo)',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Friend Chip Button ────────────────────────────────────────────────────────

class _FriendChipButton extends StatefulWidget {
  final Character character;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendChipButton({
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FriendChipButton> createState() => _FriendChipButtonState();
}

class _FriendChipButtonState extends State<_FriendChipButton> {
  ImageProvider<Object>? _getAvatarProvider() {
    final img = widget.character.generatedAvatar?.imageBase64;
    if (img == null) return null;
    if (img.startsWith('assets/')) return AssetImage(img);
    if (img.startsWith('http')) return NetworkImage(img);
    try {
      final normalized = img.contains(',') ? img.split(',').last : img;
      return MemoryImage(base64Decode(normalized));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _getAvatarProvider();
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: widget.isSelected
                ? const Color(0xFFFFD700)
                : Colors.white30,
            width: widget.isSelected ? 2 : 1,
          ),
          color: widget.isSelected
              ? const Color(0xFFFFD700).withAlpha(20)
              : Colors.white10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF3A2363),
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Text(
                      widget.character.name.isNotEmpty
                          ? widget.character.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              widget.character.name,
              style: TextStyle(
                color: widget.isSelected
                    ? const Color(0xFFFFD700)
                    : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _StarBurstOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const _StarBurstOverlay({required this.onComplete});

  @override
  State<_StarBurstOverlay> createState() => _StarBurstOverlayState();
}

class _StarBurstOverlayState extends State<_StarBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_StarParticle> _particles;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward().then((_) => widget.onComplete());

    _particles = List.generate(22, (_) => _StarParticle(_rng));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            children: _particles.map((p) {
              final t = _ctrl.value;
              final x = size.width / 2 + p.dx * t * 220;
              final y = size.height / 2 + p.dy * t * 260 + 120 * t * t;
              final opacity = (1.0 - t * 1.4).clamp(0.0, 1.0);
              final scale = (1.0 - t * 0.6).clamp(0.1, 1.0);
              return Positioned(
                left: x - 10,
                top: y - 10,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Text(
                      p.emoji,
                      style: TextStyle(fontSize: 18 + p.size),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _StarParticle {
  final double dx;
  final double dy;
  final double size;
  final String emoji;

  static const _emojis = ['⭐', '✨', '🌟', '💫', '🔮', '🪄', '💜', '⚡'];

  _StarParticle(math.Random rng)
      : dx = (rng.nextDouble() * 2 - 1),
        dy = (rng.nextDouble() * 2 - 1),
        size = rng.nextDouble() * 8,
        emoji = _emojis[rng.nextInt(_emojis.length)];
}

// ---------------------------------------------------------------------------
// Gender image button — normal / hover / pressed states + selection glow
// ---------------------------------------------------------------------------
class _GenderImageButton extends StatefulWidget {
  const _GenderImageButton({
    required this.normalImage,
    required this.hoverImage,
    required this.pressedImage,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String normalImage;
  final String hoverImage;
  final String pressedImage;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_GenderImageButton> createState() => _GenderImageButtonState();
}

class _GenderImageButtonState extends State<_GenderImageButton> {
  bool _hovered = false;
  bool _pressed = false;

  String get _imagePath {
    if (_pressed || widget.isSelected) return widget.pressedImage;
    if (_hovered) return widget.hoverImage;
    return widget.normalImage;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withAlpha(180),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _pressed ? 0.92 : (_hovered ? 1.05 : 1.0),
                duration: const Duration(milliseconds: 120),
                child: Image.asset(
                  _imagePath,
                  width: 108,
                  height: 108,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: GoogleFonts.cinzelDecorative(
                  color: widget.isSelected
                      ? const Color(0xFFFFD700)
                      : Colors.white60,
                  fontSize: 13,
                  fontWeight: widget.isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stateful arrow button with clear press feedback:
/// shrinks to 86% + brightens gradient + amplifies glow on tap-down.
class _PressableArrowButton extends StatefulWidget {
  const _PressableArrowButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PressableArrowButton> createState() => _PressableArrowButtonState();
}

class _PressableArrowButtonState extends State<_PressableArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed ? 0.86 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _pressed
                    ? [const Color(0xFFD070FF), const Color(0xFF8B4FD8)]
                    : [const Color(0xFF9B3FD8), const Color(0xFF5B1BAA)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(_pressed ? 200 : 100),
                  blurRadius: _pressed ? 32 : 20,
                  spreadRadius: _pressed ? 4 : 0,
                ),
              ],
            ),
            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }
}
