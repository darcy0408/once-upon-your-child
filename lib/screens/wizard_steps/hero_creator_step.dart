import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../../models.dart';
import '../../avatar_models.dart';
import '../../custom_avatar_screen.dart';
import '../../theme/age_band_theme.dart';
import '../../theme/app_theme.dart';
import '../../widgets/archetype_card.dart';
import '../../widgets/magic_star_cursor.dart';
import '../../services/api_service_manager.dart';
import '../../services/avatar_generation_state.dart';
import '../../services/firebase_analytics_service.dart';
import '../../services/audio_ambience_service.dart';
import '../../services/tts_api_service.dart';
import '../../widgets/avatar_gallery_selector.dart';
import '../../widgets/image_mode_orb.dart';
import '../../widgets/image_crystal_formation.dart';
import '../../data/scenario_data.dart';

/// Hero Creator — Step 1 of the story wizard.
/// Restructured as a guided multi-page wizard (progressive disclosure).
class HeroCreatorStep extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onNext;
  final List<Character> availableCharacters;
  final int? requestedSubStep;
  final int subStepRequestNonce;
  final void Function(int subStep)? onSubStepChange;
  final void Function(int age)? onAgeChanged;

  const HeroCreatorStep({
    super.key,
    required this.wizardData,
    required this.onNext,
    this.availableCharacters = const [],
    this.requestedSubStep,
    this.subStepRequestNonce = 0,
    this.onSubStepChange,
    this.onAgeChanged,
  });

  @override
  State<HeroCreatorStep> createState() => _HeroCreatorStepState();
}

class _HeroCreatorStepState extends State<HeroCreatorStep>
    with TickerProviderStateMixin {
  // ─── Assets ─────────────────────────────────────────────────────────────────

  // ─── State ──────────────────────────────────────────────────────────────────
  late PageController _heroPageController;
  int _heroPage = 0;
  String? _selectedArchetypeId;
  late TextEditingController _nameController;
  final FocusNode _nameFocusNode = FocusNode();
  Character? _selectedExistingCharacter;
  bool _isCreatingNew = true;
  GeneratedAvatar? _generatedAvatar;
  String? _customAvatarFilePath;
  bool _isPremium = false;
  // ─── Progressive-Disclosure State ───────────────────────────────────────────
  final List<String> _selectedPersonalityChips = [];
  late TextEditingController _personalityDescCtrl;

  // ─── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _sparkleCtrl;

  late TextEditingController _imagineItController;

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
    _imagineItController = TextEditingController(
      text: widget.wizardData.customElements,
    );
    _personalityDescCtrl = TextEditingController();

    // ── Animation controllers ──────────────────────────────────────────────────
    _sparkleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));

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
    _imagineItController.dispose();
    _personalityDescCtrl.dispose();

    _sparkleCtrl.dispose();
    _speech.stop();
    _tts.stop();
    _heroPageController.dispose();
    AvatarGenerationState().removeListener(_onAvatarStateChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HeroCreatorStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestedSubStep != null &&
        widget.subStepRequestNonce != oldWidget.subStepRequestNonce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.requestedSubStep == null) return;
        _jumpToSubStep(widget.requestedSubStep!);
      });
    }
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
    final onSubStepChange = widget.onSubStepChange;
    if (onSubStepChange == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      onSubStepChange(step);
    });
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

  void _jumpToSubStep(int subStep) {
    final targetPage = switch (subStep) {
      0 => 1, // Create Hero
      1 => 3, // Pick Team
      2 => 4, // Pick Place
      _ => 5, // Make Magic
    };
    if (!_heroPageController.hasClients) return;
    final clampedTarget = targetPage.clamp(0, 5);
    _heroPageController.animateToPage(
      clampedTarget,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
    setState(() => _heroPage = clampedTarget);
    _logPageView(_heroPage);
    _notifySubStep();
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
    _heroNextPage();
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
      icon: const Icon(Icons.volume_up_rounded,
          color: Color(0xFFFFD700), size: 32),
      onPressed: () => _tts.speak(text),
    );
  }

  // ─── Age-Band Title Style ────────────────────────────────────────────────────
  TextStyle _bandTitleStyle(AgeBandThemeData band, {double baseFontSize = 24}) {
    if (band.band == AgeBand.creator) {
      return GoogleFonts.sourceSans3(
        color: const Color(0xFFFFD700),
        fontSize: baseFontSize * band.headingScale,
        fontWeight: FontWeight.bold,
      );
    } else if (band.band == AgeBand.adventurer) {
      return GoogleFonts.bitter(
        color: const Color(0xFFFFD700),
        fontSize: baseFontSize * band.headingScale,
        fontWeight: FontWeight.bold,
      );
    }
    return GoogleFonts.cinzelDecorative(
      color: const Color(0xFFFFD700),
      fontSize: baseFontSize,
      fontWeight: FontWeight.bold,
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
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final ageBand = band.band;
    return Stack(
      children: [
        // Ambient floating sparkles behind the content
        const Positioned.fill(child: _AmbientSparkleLayer()),
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: band.space(24)),
          child: Column(
            children: [
              SizedBox(height: band.space(10)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _audioPrompt("Who is your hero?"),
                  SizedBox(width: band.space(8)),
                  Flexible(
                    child: Text(
                      band.createCharacterLabel,
                      style: _bandTitleStyle(band, baseFontSize: 24),
                    ),
                  ),
                ],
              ),
              // Sprout: big colourful prompt to reinforce what to do
              if (ageBand == AgeBand.sprout) ...[
                SizedBox(height: band.space(8)),
                Text(
                  "What is your hero's name?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    fontSize: band.heading(28),
                    color: const Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(color: Color(0xFFFF6B35), blurRadius: 12)
                    ],
                  ),
                ),
              ],
              SizedBox(height: band.space(20)),
              _buildNameScrollInput(),
              SizedBox(height: band.space(24)),
              _buildGenderPicker(),
              if (ageBand != AgeBand.sprout) ...[
                SizedBox(height: band.space(24)),
                // Age is already set at the welcome gate — no age picker shown here.
                _buildAgeBandPersonalityInput(band),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgeBandPersonalityInput(AgeBandThemeData band) {
    switch (band.band) {
      case AgeBand.sprout:
        return _buildSproutPersonalityButtons(band);
      case AgeBand.explorer:
        return _buildExplorerPersonalityCards(band);
      case AgeBand.adventurer:
        return _buildPersonalityChips();
      case AgeBand.creator:
        return _buildPersonalityTextField();
    }
  }

  // Page 2: "Pick your hero style!" — archetype selection
  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _audioPrompt("Pick your hero style!"),
              const SizedBox(width: 8),
              Flexible(
                child: Builder(
                  builder: (context) {
                    final band =
                        Theme.of(context).extension<AgeBandThemeData>() ??
                            explorerTheme;
                    return Text('Pick your hero style!',
                        style: _bandTitleStyle(band, baseFontSize: 22));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAvatarLookCard(),
          const SizedBox(height: 20),
          _buildArchetypeCards(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Page 3: "Who's coming with you?" (Adventure Team — companions + pets)
  Widget _buildPage3() {
    return _buildAdventureTeamPage();
  }

  /// Shows selected companions as glowing portrait orbs above the selection grid.
  /// Empty slots show a dashed placeholder. Tapping a filled orb deselects it.
  Widget _buildCompanionShowcase() {
    // Collect selected named companions in order
    final selectedNamed = _companions
        .where((c) =>
            widget.wizardData.companionNames.contains(c.name) ||
            widget.wizardData.selectedCompanions.contains(c.id))
        .toList();

    // Collect selected saved-character friends (not magic companions, not pets)
    final magicAndPetNames = {
      ..._companions.map((c) => c.name),
      ...widget.wizardData.pets.map((p) => p['name'] ?? ''),
    };
    final selectedFriends = widget.availableCharacters
        .where((c) =>
            widget.wizardData.companionNames.contains(c.name) &&
            !magicAndPetNames.contains(c.name))
        .toList();

    // Collect selected pets (supports multiple saved pets).
    final selectedPets = widget.wizardData.pets.where((pet) {
      final petName = (pet['name'] ?? '').trim();
      return petName.isNotEmpty &&
          widget.wizardData.companionNames.contains(petName);
    }).toList();

    // Build slot list: magic companions, then saved friends, then pet, then empty
    final slots = <_ShowcaseSlot>[];
    for (final c in selectedNamed) {
      slots.add(_ShowcaseSlot(
        imagePath: 'assets/images/companions/${c.id}_normal.jpg',
        name: c.name,
      ));
    }
    for (final friend in selectedFriends) {
      slots.add(_ShowcaseSlot(
        photoBase64: friend.generatedAvatar?.imageBase64,
        name: friend.name,
        isFriend: true,
      ));
    }
    for (final pet in selectedPets) {
      final petName = pet['name'] ?? 'My Pet';
      slots.add(_ShowcaseSlot(
        photoBase64: widget.wizardData.petPhotos[petName],
        name: petName,
      ));
    }
    // Always show at least 3 slots (empty slots fill the row)
    const maxSlots = 3;
    final emptyCount = maxSlots - slots.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Filled slots
            for (int i = 0; i < slots.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              _GlowingCompanionOrb(
                slot: slots[i],
                onTap: () => setState(() {
                  final slotName = slots[i].name;
                  // Magic companion?
                  final matched = selectedNamed
                      .where((c) => c.name == slotName)
                      .firstOrNull;
                  if (matched != null) {
                    widget.wizardData.companionNames.remove(matched.name);
                    widget.wizardData.selectedCompanions.remove(matched.id);
                  } else if (slots[i].isFriend) {
                    // Saved-character friend — just remove from companionNames
                    widget.wizardData.companionNames.remove(slotName);
                  } else {
                    // Pet
                    widget.wizardData.companionNames.remove(slotName);
                  }
                }),
              ),
            ],
            // Empty placeholder slots
            for (int i = 0; i < emptyCount; i++) ...[
              if (slots.isNotEmpty || i > 0) const SizedBox(width: 16),
              const _GlowingCompanionOrb(slot: null),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          slots.isEmpty
              ? 'Tap a companion below to add them'
              : slots.length == 1
                  ? '${slots[0].name} is ready!'
                  : 'Your team is set!',
          style: TextStyle(
            color: slots.isEmpty ? Colors.white38 : const Color(0xFFFFD700),
            fontSize: 12,
            fontStyle: slots.isEmpty ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }

  /// Temporary adventure team placeholder — replaced when companion grid is built.
  Widget _buildAdventureTeamPage() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final companionTitle = band.band == AgeBand.sprout
        ? 'Pick your buddies!'
        : band.band == AgeBand.adventurer
            ? 'Choose your companions'
            : band.band == AgeBand.creator
                ? 'Choose companions'
                : "Who's coming with you?";
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
                  companionTitle,
                  style: _bandTitleStyle(band, baseFontSize: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCompanionShowcase(),
          const SizedBox(height: 20),
          // Companion grid will go here (Task B)
          _buildCompanionGrid(),
          const SizedBox(height: 40),
          _buildNextArrowButton(
              enabled: true,
              onTap: _heroNextPage,
              hint: 'Next: Choose Your Scene'),
          const SizedBox(height: 20),
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
        // ── Pet card (photo + name/species/color) ──────────────────────────────
        _PetCard(
          wizardData: widget.wizardData,
          onPickPhoto: _pickPetPhoto,
          onChanged: () => setState(() {}),
        ),
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
    final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    setState(() {
      // Preserve existing pet name if already set, otherwise default
      final existingName = widget.wizardData.pets.isNotEmpty
          ? (widget.wizardData.pets.first['name'] ?? 'My Pet')
          : 'My Pet';
      if (widget.wizardData.pets.isEmpty) {
        widget.wizardData.pets.add({
          'name': existingName,
          'species': 'Dog',
          'color': '',
          'personality': '',
        });
      }
      // Store photo keyed by name in petPhotos (not petAvatars)
      widget.wizardData.petPhotos[existingName] = b64;
      // Auto-select the pet as a companion
      if (!widget.wizardData.companionNames.contains(existingName)) {
        widget.wizardData.companionNames.add(existingName);
      }
    });
  }

  Future<ImageSource?> _showPhotoSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C1B47),
        title: const Text('Add Your Companion',
            style: TextStyle(color: Color(0xFFFFD700))),
        content: const Text('How would you like to add your companion?',
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

  Widget _buildPage4() {
    final age = widget.wizardData.characterAge;
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final placeTitle = band.band == AgeBand.creator
        ? 'Setting'
        : band.band == AgeBand.adventurer
            ? 'Choose your setting'
            : 'Where to adventure?';
    final isImagineItSelected =
        widget.wizardData.selectedScenario == 'safe_space';

    // The 5 featured scene buttons with their image assets
    final featuredButtons = [
      _SceneButtonData(
        id: 'vanishing_colors',
        label: ScenarioData.all
            .firstWhere((s) => s.id == 'vanishing_colors')
            .titleForAge(age),
        normalAsset: 'assets/images/scenarios/rainbow_land_btn.png',
        pressedAsset: 'assets/images/scenarios/rainbow_land_btn_pressed.png',
      ),
      _SceneButtonData(
        id: 'crystal_cavern',
        label: ScenarioData.all
            .firstWhere((s) => s.id == 'crystal_cavern')
            .titleForAge(age),
        normalAsset: 'assets/images/scenarios/crystal_cave_btn.png',
        pressedAsset: 'assets/images/scenarios/crystal_cave_btn_pressed.png',
      ),
      _SceneButtonData(
        id: 'volcano_dragons',
        label: ScenarioData.all
            .firstWhere((s) => s.id == 'volcano_dragons')
            .titleForAge(age),
        normalAsset: 'assets/images/scenarios/dragon_friends_btn.png',
        pressedAsset: 'assets/images/scenarios/dragon_friends_btn_pressed.png',
      ),
      _SceneButtonData(
        id: 'big_feelings_quest',
        label: ScenarioData.all
            .firstWhere((s) => s.id == 'big_feelings_quest')
            .titleForAge(age),
        normalAsset: 'assets/images/scenarios/my_big_feelings_btn.png',
        pressedAsset: 'assets/images/scenarios/my_big_feelings_btn_pressed.png',
      ),
    ];

    final displayButtons = featuredButtons;

    final labelFontSize = band.band == AgeBand.sprout
        ? 14.0
        : band.band == AgeBand.explorer
            ? 13.0
            : 12.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  placeTitle,
                  style: _bandTitleStyle(band, baseFontSize: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Create your own world — or choose one below!',
            style: GoogleFonts.fredoka(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // ── HERO: Imagine It ────────────────────────────────────────────────
          _ImagineItHeroCard(
            isSelected: isImagineItSelected,
            onTap: () => setState(() {
              widget.wizardData.selectedScenario =
                  isImagineItSelected ? null : 'safe_space';
            }),
          ),

          // Inline text/voice input — expands when Imagine It is selected
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: isImagineItSelected
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildImagineItInput(),
            secondChild: const SizedBox.shrink(),
          ),

          const SizedBox(height: 20),

          // ── Divider: "or explore a ready-made world" ───────────────────────
          Row(
            children: [
              const Expanded(
                  child: Divider(color: Colors.white24, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or explore a ready-made world',
                  style:
                      GoogleFonts.fredoka(color: Colors.white54, fontSize: 13),
                ),
              ),
              const Expanded(
                  child: Divider(color: Colors.white24, thickness: 1)),
            ],
          ),
          const SizedBox(height: 14),

          // ── 2-column grid of preset scene buttons ──────────────────────────
          // When the count is even, use a simple 2-column GridView.
          // When odd (e.g. Sprout hides volcano_dragons), the last card spans
          // the full width so nothing looks orphaned.
          if (displayButtons.length.isOdd) ...[
            for (int i = 0; i < displayButtons.length - 1; i += 2) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 360 / 220,
                      child: _SceneImageButton(
                        data: displayButtons[i],
                        isSelected: widget.wizardData.selectedScenario ==
                            displayButtons[i].id,
                        labelFontSize: labelFontSize,
                        onTap: () => setState(() {
                          widget.wizardData.selectedScenario =
                              displayButtons[i].id;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 360 / 220,
                      child: _SceneImageButton(
                        data: displayButtons[i + 1],
                        isSelected: widget.wizardData.selectedScenario ==
                            displayButtons[i + 1].id,
                        labelFontSize: labelFontSize,
                        onTap: () => setState(() {
                          widget.wizardData.selectedScenario =
                              displayButtons[i + 1].id;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Last item spans full width when count is odd
            AspectRatio(
              aspectRatio: 360 / 110, // half the height for a wide banner feel
              child: _SceneImageButton(
                data: displayButtons.last,
                isSelected: widget.wizardData.selectedScenario ==
                    displayButtons.last.id,
                labelFontSize: labelFontSize,
                onTap: () => setState(() {
                  widget.wizardData.selectedScenario = displayButtons.last.id;
                }),
              ),
            ),
          ] else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              // Natural image ratio: 360×220 = 1.636 — childAspectRatio = w/h
              childAspectRatio: 360 / 220,
              children: displayButtons
                  .map((btn) => _SceneImageButton(
                        data: btn,
                        isSelected:
                            widget.wizardData.selectedScenario == btn.id,
                        labelFontSize: labelFontSize,
                        onTap: () => setState(() {
                          widget.wizardData.selectedScenario = btn.id;
                        }),
                      ))
                  .toList(),
            ),

          const SizedBox(height: 24),
          _buildNextArrowButton(
              enabled: true, onTap: _heroNextPage, hint: 'Next: Story Style'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildImagineItInput() {
    const imagineItPromptText = 'Where will your adventure take place? '
        'For example, a floating cloud city, deep inside a volcano, or an underwater palace.';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700), width: 2),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C1B47), Color(0xFF1A0E36)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withAlpha(50),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Where will your adventure take place?',
                    style: GoogleFonts.fredoka(
                      color: const Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Read ideas aloud',
                  icon: const Icon(Icons.volume_up_rounded,
                      color: Color(0xFFFFD700), size: 24),
                  onPressed: () => _tts.speak(imagineItPromptText),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _imagineItController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. a floating cloud city, deep inside a volcano, underwater palace…',
                      hintStyle: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 13,
                          fontStyle: FontStyle.italic),
                      filled: true,
                      fillColor: Colors.white.withAlpha(18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: const Color(0xFFFFD700).withAlpha(100)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFFFD700), width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: const Color(0xFFFFD700).withAlpha(120)),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    onChanged: (value) {
                      widget.wizardData.customElements = value;
                      _wishController.text = value;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _speechAvailable
                      ? 'Speak your setting idea'
                      : 'Mic unavailable',
                  icon: Icon(
                    _listeningFor == 'imagine' ? Icons.mic : Icons.mic_none,
                    color: _speechAvailable
                        ? (_listeningFor == 'imagine'
                            ? Colors.yellow
                            : Colors.white)
                        : Colors.white38,
                  ),
                  onPressed: _speechAvailable
                      ? () => _toggleListening('imagine')
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _speechAvailable
                  ? '🎤 Tap the mic and say your idea out loud.'
                  : '✍️ Type your idea here. Mic is unavailable on this device.',
              style: TextStyle(
                color: Colors.white.withAlpha(170),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '✦ The more you describe, the more magical your story becomes!',
              style: TextStyle(
                  color: const Color(0xFFFFD700).withAlpha(180),
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  // Page 5: "What kind of story?"
  Widget _buildPage5() {
    final data = widget.wizardData;
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isCreator = band.band == AgeBand.creator;
    final storyTitle = band.band == AgeBand.sprout
        ? 'What story do you want?'
        : band.band == AgeBand.adventurer
            ? 'Choose your story type'
            : isCreator
                ? 'Story type'
                : 'What kind of story?';
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: band.space(24)),
      child: Column(
        children: [
          SizedBox(height: band.space(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _audioPrompt("What kind of story do you want?"),
              SizedBox(width: band.space(8)),
              Flexible(
                child: Text(
                  storyTitle,
                  style: _bandTitleStyle(band, baseFontSize: 24),
                ),
              ),
            ],
          ),
          SizedBox(height: band.space(24)),
          // Story mode selection — 2×2 grid
          Text(
            "Pick your story style",
            style: GoogleFonts.fredoka(
              color: Colors.white.withAlpha(200),
              fontSize: band.body(16),
            ),
          ),
          SizedBox(height: band.space(16)),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ImageModeOrb(
                    modeType: 'tales',
                    label: isCreator ? 'Story' : 'Story Quest',
                    isActive: data.includeIllustrations,
                    onTap: () => setState(() =>
                        data.includeIllustrations = !data.includeIllustrations),
                    primaryColor: const Color(0xFFAA88FF),
                    secondaryColor: const Color(0xFFE28EFF),
                  ),
                  const SizedBox(width: 24),
                  ImageModeOrb(
                    modeType: 'rhyme',
                    label: isCreator ? 'Poetry' : 'Rhyme Time',
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
              SizedBox(height: band.space(20)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ImageModeOrb(
                    modeType: 'reading',
                    label: isCreator ? 'First Chapter' : 'First Reader',
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
                    label: isCreator ? 'Choose Your Path' : 'Pick a Path',
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
          SizedBox(height: band.space(36)),
          // Story length selection
          Text(
            "How long should it be?",
            style: GoogleFonts.fredoka(
              color: Colors.white.withAlpha(200),
              fontSize: band.body(16),
            ),
          ),
          SizedBox(height: band.space(16)),
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
          SizedBox(height: band.space(28)),
          // Genre tags — Adventurer+ only
          if (band.band == AgeBand.adventurer ||
              band.band == AgeBand.creator) ...[
            const SizedBox(height: 4),
            Text(
              "Add a genre twist (optional)",
              style: GoogleFonts.fredoka(
                color: Colors.white.withAlpha(200),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _GenreChip(
                    label: '🔍 Mystery',
                    value: 'mystery',
                    selected: widget.wizardData.selectedGenre == 'mystery',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'mystery'
                                ? null
                                : 'mystery')),
                _GenreChip(
                    label: '😂 Comedy',
                    value: 'comedy',
                    selected: widget.wizardData.selectedGenre == 'comedy',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'comedy'
                                ? null
                                : 'comedy')),
                _GenreChip(
                    label: '🚀 Sci-Fi',
                    value: 'sci-fi',
                    selected: widget.wizardData.selectedGenre == 'sci-fi',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'sci-fi'
                                ? null
                                : 'sci-fi')),
                _GenreChip(
                    label: '⚔️ Action',
                    value: 'action',
                    selected: widget.wizardData.selectedGenre == 'action',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'action'
                                ? null
                                : 'action')),
                _GenreChip(
                    label: '👻 Spooky',
                    value: 'spooky',
                    selected: widget.wizardData.selectedGenre == 'spooky',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'spooky'
                                ? null
                                : 'spooky')),
                _GenreChip(
                    label: '💕 Romance',
                    value: 'romance',
                    selected: widget.wizardData.selectedGenre == 'romance',
                    onTap: () => setState(() =>
                        widget.wizardData.selectedGenre =
                            widget.wizardData.selectedGenre == 'romance'
                                ? null
                                : 'romance')),
              ],
            ),
            const SizedBox(height: 24),
          ],
          if (band.band == AgeBand.sprout || band.band == AgeBand.explorer)
            _buildWishPromptButtons(band)
          else
            _buildWishTextInput(band),
          SizedBox(height: band.space(32)),
          _buildNextArrowButton(
              enabled: true,
              onTap: widget.onNext,
              hint: 'Next: Review & Make Magic!'),
          SizedBox(height: band.space(20)),
        ],
      ),
    );
  }

  Widget _buildWishPromptButtons(AgeBandThemeData band) {
    final prompts = <(String emoji, String label, String value)>[
      ('🧚', 'Magic friend', 'A friendly fairy helps on the journey.'),
      ('🐉', 'Dragon helper', 'A kind dragon becomes my helper.'),
      ('🗺️', 'Treasure quest', 'Find a hidden treasure map adventure.'),
      ('🌈', 'Rainbow world', 'A magical rainbow world appears.'),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: band.space(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _audioPrompt("Pick something special for your story!"),
              SizedBox(width: band.space(4)),
              Flexible(
                child: Text(
                  "Pick something special!",
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: band.body(16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: band.space(10)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prompts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
            ),
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              final selected = widget.wizardData.customElements == prompt.$3;
              return InkWell(
                borderRadius: BorderRadius.circular(band.radiusMd),
                onTap: () {
                  setState(() {
                    widget.wizardData.customElements = prompt.$3;
                    _wishController.text = prompt.$3;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: BoxConstraints(minHeight: band.touchTarget(72)),
                  padding: EdgeInsets.symmetric(
                    horizontal: band.space(10),
                    vertical: band.space(10),
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF7C4DFF) : Colors.white10,
                    borderRadius: BorderRadius.circular(band.radiusMd),
                    border: Border.all(
                      color:
                          selected ? const Color(0xFFFFD700) : Colors.white24,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(prompt.$1,
                          style: TextStyle(fontSize: band.body(22))),
                      SizedBox(width: band.space(8)),
                      Expanded(
                        child: Text(
                          prompt.$2,
                          style: GoogleFonts.fredoka(
                            color: Colors.white,
                            fontSize: band.body(13),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWishTextInput(AgeBandThemeData band) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: band.space(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _audioPrompt("Anything special you want in your story?"),
              SizedBox(width: band.space(4)),
              Flexible(
                child: Text(
                  "Anything special you want?",
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: band.body(16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: band.space(8)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wishController,
                  style:
                      TextStyle(color: Colors.white, fontSize: band.body(14)),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'I want to ride a magic carpet…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withAlpha(20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(band.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: band.space(12),
                      vertical: band.space(10),
                    ),
                  ),
                  onChanged: (v) => widget.wizardData.customElements = v,
                ),
              ),
              SizedBox(width: band.space(8)),
              IconButton(
                iconSize: band.body(24),
                constraints: BoxConstraints(
                  minWidth: band.touchTarget(48),
                  minHeight: band.touchTarget(48),
                ),
                icon: Icon(
                  _listeningFor == 'wish' ? Icons.mic : Icons.mic_none,
                  color: _listeningFor == 'wish' ? Colors.yellow : Colors.white,
                ),
                onPressed: () => _toggleListening('wish'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextArrowButton(
      {required bool enabled, required VoidCallback onTap, String? hint}) {
    return _PressableArrowButton(enabled: enabled, onTap: onTap, hint: hint);
  }

  Widget _buildAvatarLookCard() {
    final imageData = _generatedAvatar?.imageBase64;
    final avatarProvider =
        imageData == null ? null : _getImageProviderFromString(imageData);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(90)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF3A2363),
            backgroundImage: avatarProvider,
            child: avatarProvider == null
                ? const Icon(Icons.face_retouching_natural,
                    color: Color(0xFFFFD700), size: 30)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasAvatar
                      ? 'Your hero look is ready'
                      : 'Pick what your hero looks like',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _hasAvatar
                      ? 'You can change it anytime.'
                      : 'Choose a look before you continue.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _openAvatarCreationOptions,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7E57C2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(_hasAvatar ? 'Change Look' : 'Choose Look'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAvatarCreationOptions() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2C1B47),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose Your Avatar',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick a pre-made look or create a magical AI avatar from a photo.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading:
                    const Icon(Icons.auto_awesome, color: Color(0xFFFFD700)),
                title: const Text('Gallery Avatar',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Quick pick from magical presets',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openAvatarGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFFFFD700)),
                title: const Text('Take/Upload Photo → AI Avatar',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'Creates a Pixar-style hero from your child photo',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openCustomAvatarScreen();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAvatarGallery() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AvatarGallerySelector(
        isPremium: _isPremium,
        onCancel: () => Navigator.of(ctx).pop(),
        onAvatarSelected: (avatar) {
          if (!mounted) return;
          setState(() {
            _generatedAvatar = avatar;
            _customAvatarFilePath = null;
            widget.wizardData.generatedAvatar = avatar;
          });
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _openCustomAvatarScreen() async {
    if (!mounted) return;
    final result = await Navigator.of(context).push<CharacterAvatar>(
      MaterialPageRoute(
        builder: (_) => CustomAvatarScreen(
          initialName: widget.wizardData.characterName,
          initialAge: widget.wizardData.characterAge,
        ),
        fullscreenDialog: true,
      ),
    );

    final dataUri = result?.customImagePath;
    if (!mounted || dataUri == null || dataUri.isEmpty) return;

    final generated = GeneratedAvatar(
      id: 'custom_photo_${DateTime.now().millisecondsSinceEpoch}',
      imageBase64: dataUri,
      seed: 'custom_photo',
      style: 'pixar',
      attributes: const {'source': 'custom_photo'},
      generatedAt: DateTime.now(),
    );

    setState(() {
      _generatedAvatar = generated;
      _customAvatarFilePath = null;
      widget.wizardData.generatedAvatar = generated;
      widget.wizardData.customAvatarPath = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Custom avatar ready!'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  // ─── Avatar, Age, Gender, Name, Archetype, Superpower, Continue logic ──────────

  bool get _hasAvatar =>
      _generatedAvatar != null || _customAvatarFilePath != null;

  ImageProvider<Object> _getImageProviderFromString(String imageData) {
    if (imageData.startsWith('assets/')) {
      return AssetImage(imageData);
    }
    if (imageData.startsWith('http')) {
      return NetworkImage(imageData);
    }
    final normalized =
        imageData.contains(',') ? imageData.split(',').last : imageData;
    return MemoryImage(base64Decode(normalized));
  }

  Widget _buildGenderPicker() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 300;
        final spacing = isNarrow ? 16.0 : 28.0;
        final availableWidth =
            isNarrow ? constraints.maxWidth : constraints.maxWidth - spacing;
        final btnW = (availableWidth / (isNarrow ? 1 : 2)).clamp(90.0, 180.0);
        final btnH = btnW * 1.35;
        if (isNarrow) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GenderImageButton(
                gender: 'Boy',
                assetPath: 'assets/images/ui/boy_avatar_button.webp',
                isSelected: widget.wizardData.characterGender == 'Boy',
                width: btnW,
                height: btnH,
                onTap: () => _handleGenderSelection('Boy'),
              ),
              SizedBox(height: spacing),
              _GenderImageButton(
                gender: 'Girl',
                assetPath: 'assets/images/ui/girl_avatar_button.webp',
                isSelected: widget.wizardData.characterGender == 'Girl',
                width: btnW,
                height: btnH,
                onTap: () => _handleGenderSelection('Girl'),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GenderImageButton(
              gender: 'Boy',
              assetPath: 'assets/images/ui/boy_avatar_button.webp',
              isSelected: widget.wizardData.characterGender == 'Boy',
              width: btnW,
              height: btnH,
              onTap: () => _handleGenderSelection('Boy'),
            ),
            SizedBox(width: spacing),
            _GenderImageButton(
              gender: 'Girl',
              assetPath: 'assets/images/ui/girl_avatar_button.webp',
              isSelected: widget.wizardData.characterGender == 'Girl',
              width: btnW,
              height: btnH,
              onTap: () => _handleGenderSelection('Girl'),
            ),
          ],
        );
      },
    );
  }

  void _handleGenderSelection(String gender) {
    setState(() => widget.wizardData.characterGender = gender);
    _heroNextPage();

    // Auto-open look picker right after moving to page 2, so kids don't miss it.
    if (!_hasAvatar) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _heroPage != 2 || _hasAvatar) return;
        await _openAvatarCreationOptions();
      });
    }
  }

  Widget _buildNameScrollInput() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final nameFontSize = band.headingScale * 20;

    if (band.band == AgeBand.creator) {
      return TextField(
        controller: _nameController,
        focusNode: _nameFocusNode,
        textAlign: TextAlign.center,
        style: GoogleFonts.sourceSans3(
          fontSize: nameFontSize,
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Character name',
          hintStyle: const TextStyle(color: Colors.white30),
          filled: true,
          fillColor: Colors.white.withAlpha(10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(band.buttonRadiusBase),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(band.buttonRadiusBase),
            borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) =>
            setState(() => widget.wizardData.characterName = v.trim()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "HERO'S NAME",
          style: GoogleFonts.cinzelDecorative(
            color: const Color(0xFFFFE082).withAlpha(200),
            fontSize: 11,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _ThemedNameInput(
          controller: _nameController,
          focusNode: _nameFocusNode,
          fontSize: nameFontSize,
          height: 60,
          onChanged: (v) =>
              setState(() => widget.wizardData.characterName = v.trim()),
        ),
      ],
    );
  }

  Widget _buildArchetypeCards() {
    final ageBand = ageBandFromAge(widget.wizardData.characterAge);
    // Sprout sees only the 4 most visually striking archetypes.
    final archetypes = ageBand == AgeBand.sprout
        ? CharacterArchetypes.all.take(4).toList()
        : CharacterArchetypes.all;

    // Sprout & Explorer: 2-column grid — image-dominant cards.
    if (ageBand == AgeBand.sprout || ageBand == AgeBand.explorer) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: archetypes.length,
        itemBuilder: (context, index) {
          final a = archetypes[index];
          final isSelected = _selectedArchetypeId == a.name;
          return GestureDetector(
            onTap: () => _selectArchetype(a),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFFD700) : Colors.white24,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: const Color(0xFFFFD700).withAlpha(100),
                            blurRadius: 12)
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Dark background so letterbox areas look intentional
                    Container(color: const Color(0xFF1A0A2E)),
                    // Image — contain so full frame is always visible
                    if (a.imagePath != null)
                      Image.asset(a.imagePath!,
                          fit: BoxFit.contain, alignment: Alignment.center)
                    else
                      Container(
                        color: Colors.white10,
                        child: Center(
                            child: Text(a.icon ?? '✨',
                                style: const TextStyle(fontSize: 72))),
                      ),
                    // Gradient overlay at bottom for legibility
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withAlpha(200),
                              Colors.transparent
                            ],
                          ),
                        ),
                        child: Text(
                          a.name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    // Gold checkmark when selected
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD700),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.check,
                              size: 16, color: Colors.black),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Adventurer & Creator: horizontal list — image-dominant cards with name overlay.
    final showDescriptions =
        ageBand == AgeBand.adventurer || ageBand == AgeBand.creator;
    final cardWidth = ageBand == AgeBand.creator ? 150.0 : 165.0;
    const cardHeight = 220.0;
    return SizedBox(
      height: cardHeight,
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
              width: cardWidth,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFFD700) : Colors.white24,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: const Color(0xFFFFD700).withAlpha(100),
                            blurRadius: 12)
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: const Color(0xFF1A0A2E)),
                    if (a.imagePath != null)
                      Image.asset(a.imagePath!,
                          fit: BoxFit.contain, alignment: Alignment.center)
                    else
                      Container(
                        color: Colors.white10,
                        child: Center(
                            child: Text(a.icon ?? '✨',
                                style: const TextStyle(fontSize: 64))),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withAlpha(210),
                              Colors.transparent
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a.name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                            if (showDescriptions) ...[
                              const SizedBox(height: 2),
                              Text(
                                a.description,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD700),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.check,
                              size: 16, color: Colors.black),
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

  /// Adventurer band (9-12): 6 word chips, pick up to 3.
  Widget _buildPersonalityChips() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    const options = ['Brave', 'Curious', 'Kind', 'Funny', 'Creative', 'Shy'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick up to 3 words that describe you:',
          style: GoogleFonts.fredoka(
              color: Colors.white70, fontSize: band.body(15)),
        ),
        SizedBox(height: band.space(10)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((word) {
            final isSelected = _selectedPersonalityChips.contains(word);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedPersonalityChips.remove(word);
                  } else if (_selectedPersonalityChips.length < 3) {
                    _selectedPersonalityChips.add(word);
                  }
                  widget.wizardData.strengths =
                      List.from(_selectedPersonalityChips);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                    horizontal: band.space(16), vertical: band.space(8)),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF7C4DFF) : Colors.white10,
                  borderRadius: BorderRadius.circular(band.radiusLg),
                  border: Border.all(
                    color:
                        isSelected ? const Color(0xFFFFD700) : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  word,
                  style: GoogleFonts.fredoka(
                    color:
                        isSelected ? const Color(0xFFFFD700) : Colors.white70,
                    fontSize: band.body(15),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Creator band (13+): free-text personality description field.
  Widget _buildPersonalityTextField() {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Describe your character's personality:",
          style: GoogleFonts.sourceSans3(
              color: Colors.white60, fontSize: band.body(14)),
        ),
        SizedBox(height: band.space(8)),
        TextField(
          controller: _personalityDescCtrl,
          maxLines: 3,
          style: GoogleFonts.sourceSans3(
              color: Colors.white70, fontSize: band.body(14)),
          decoration: InputDecoration(
            hintText: 'e.g. introverted but fiercely loyal, sarcastic wit…',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withAlpha(10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(band.radiusMd),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(band.radiusMd),
              borderSide: const BorderSide(color: Color(0xFF7C4DFF)),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: band.space(16),
              vertical: band.space(12),
            ),
          ),
          onChanged: (v) {
            widget.wizardData.strengths = v.trim().isEmpty ? [] : [v.trim()];
          },
        ),
      ],
    );
  }

  Widget _buildSproutPersonalityButtons(AgeBandThemeData band) {
    final options = <(String emoji, String label)>[
      ('🦁', 'Brave'),
      ('🌈', 'Kind'),
      ('🔍', 'Curious'),
      ('🎨', 'Creative'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pick one hero feeling:',
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: Colors.white70,
            fontSize: band.body(16),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: band.space(12)),
        Wrap(
          spacing: band.space(12),
          runSpacing: band.space(12),
          alignment: WrapAlignment.center,
          children: options.map((opt) {
            final isSelected = _selectedPersonalityChips.isNotEmpty &&
                _selectedPersonalityChips.first == opt.$2;
            return SizedBox(
              width: band.touchTarget(120),
              child: InkWell(
                borderRadius: BorderRadius.circular(band.radiusLg),
                onTap: () {
                  setState(() {
                    _selectedPersonalityChips
                      ..clear()
                      ..add(opt.$2);
                    widget.wizardData.strengths = [opt.$2];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: band.space(12),
                    vertical: band.space(14),
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? const Color(0xFF7C4DFF) : Colors.white10,
                    borderRadius: BorderRadius.circular(band.radiusLg),
                    border: Border.all(
                      color:
                          isSelected ? const Color(0xFFFFD700) : Colors.white24,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(opt.$1,
                          style: TextStyle(fontSize: band.heading(26))),
                      SizedBox(height: band.space(6)),
                      Text(
                        opt.$2,
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: band.body(14),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExplorerPersonalityCards(AgeBandThemeData band) {
    final options = <(String emoji, String label)>[
      ('🦸', 'Brave'),
      ('🧠', 'Curious'),
      ('💛', 'Kind'),
      ('😄', 'Funny'),
      ('🎨', 'Creative'),
      ('🌙', 'Calm'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick up to 2 hero traits:',
          style: GoogleFonts.fredoka(
            color: Colors.white70,
            fontSize: band.body(15),
          ),
        ),
        SizedBox(height: band.space(10)),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            final isSelected = _selectedPersonalityChips.contains(option.$2);
            return InkWell(
              borderRadius: BorderRadius.circular(band.radiusMd),
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedPersonalityChips.remove(option.$2);
                  } else if (_selectedPersonalityChips.length < 2) {
                    _selectedPersonalityChips.add(option.$2);
                  }
                  widget.wizardData.strengths =
                      List.from(_selectedPersonalityChips);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: BoxConstraints(minHeight: band.touchTarget(72)),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF7C4DFF) : Colors.white10,
                  borderRadius: BorderRadius.circular(band.radiusMd),
                  border: Border.all(
                    color:
                        isSelected ? const Color(0xFFFFD700) : Colors.white24,
                    width: isSelected ? 2 : 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(option.$1,
                        style: TextStyle(fontSize: band.heading(24))),
                    SizedBox(height: band.space(4)),
                    Text(
                      option.$2,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: band.body(13),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _toggleListening(String field) async {
    if (!_speechAvailable) {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listeningFor = '');
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _listeningFor = '');
        },
      );
      if (!mounted) return;
      setState(() => _speechAvailable = available);
      if (!available) {
        if (field == 'imagine') {
          unawaited(
              _tts.speak('Microphone is unavailable. Please type your idea.'));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Microphone unavailable on this device')),
        );
        return;
      }
    }

    if (_listeningFor == field) {
      await _speech.stop();
      setState(() => _listeningFor = '');
      return;
    }

    if (field == 'imagine') {
      unawaited(_tts.speak('Tell me where your adventure takes place.'));
    }

    setState(() => _listeningFor = field);
    await _speech.listen(
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        setState(() {
          if (field == 'superpower') {
            _superpowerController.text = words;
            widget.wizardData.heroSuperpower = words;
          } else if (field == 'imagine') {
            _imagineItController.text = words;
            _wishController.text = words;
            widget.wizardData.customElements = words;
          } else if (field == 'wish') {
            _wishController.text = words;
            _imagineItController.text = words;
            widget.wizardData.customElements = words;
          } else {
            _questController.text = words;
            widget.wizardData.heroQuest = words;
          }
          if (result.finalResult) _listeningFor = '';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MagicStarCursor(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF120226), Color(0xFF3D1166), Color(0xFF120226)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                  top: 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
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
      final normalized =
          imageBase64.contains(',') ? imageBase64.split(',').last : imageBase64;
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
                  : const AssetImage('assets/images/hero_placeholder.jpg')
                      as ImageProvider,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(character.name,
                      style: GoogleFonts.cinzelDecorative(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text("${character.age} years old • ${character.role}",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded,
                color: Color(0xFFFFD700), size: 40),
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

// ── Companion Image Grid ─────────────────────────────────────────────────────

// Each companion has a fixed personality that stays consistent across stories.
class _CompanionData {
  final String id;
  final String name;
  final String tagline;
  final String personality; // Sent to AI prompt so quirks stay consistent
  const _CompanionData({
    required this.id,
    required this.name,
    required this.tagline,
    required this.personality,
  });
}

/// Data carrier for a showcase orb slot.
class _ShowcaseSlot {
  final String? imagePath;
  final String? photoBase64;
  final String name;
  final bool isFriend; // true = saved character (not a magic companion or pet)
  const _ShowcaseSlot({
    this.imagePath,
    this.photoBase64,
    required this.name,
    this.isFriend = false,
  });
}

/// A large glowing circle that shows a companion portrait (or empty placeholder).
class _GlowingCompanionOrb extends StatelessWidget {
  final _ShowcaseSlot? slot;
  final VoidCallback? onTap;

  const _GlowingCompanionOrb({this.slot, this.onTap});

  static const double _size = 90.0;

  @override
  Widget build(BuildContext context) {
    final filled = slot != null;

    Widget inner;
    if (!filled) {
      inner = const Icon(Icons.add_rounded, color: Colors.white24, size: 32);
    } else if (slot!.photoBase64 != null && slot!.photoBase64!.isNotEmpty) {
      // Pet photo or friend avatar (base64)
      final raw = slot!.photoBase64!;
      final bytes = base64Decode(raw.contains(',') ? raw.split(',').last : raw);
      inner =
          Image.memory(bytes, width: _size, height: _size, fit: BoxFit.cover);
    } else if (slot!.isFriend) {
      // Saved character with no avatar image yet — use a person placeholder
      inner = const Icon(Icons.person_rounded, color: Colors.white70, size: 44);
    } else {
      inner = Image.asset(
        slot!.imagePath ?? '',
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.pets, color: Colors.white54, size: 36),
      );
    }

    return GestureDetector(
      onTap: filled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: _size + 12,
        height: _size + 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: filled ? const Color(0xFFFFD700) : Colors.white24,
            width: filled ? 3 : 2,
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withAlpha(160),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFD700).withAlpha(60),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ]
              : [],
          color: filled ? null : Colors.white.withAlpha(8),
        ),
        child: ClipOval(
          clipBehavior: Clip.antiAlias,
          child: filled
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    inner,
                    // Subtle gold overlay tint
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFFFFD700).withAlpha(30),
                          ],
                        ),
                      ),
                    ),
                    // "Tap to remove" hint on top-right
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFD700),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.black, size: 12),
                      ),
                    ),
                  ],
                )
              : Center(child: inner),
        ),
      ),
    );
  }
}

const _companions = [
  _CompanionData(
    id: 'dragon',
    name: 'Dragon',
    tagline: 'Big courage. Bigger heart.',
    personality:
        'Dragon (Brave Protector) stands between you and danger, voice steady and brave. She turns fear into a plan and protects you without making you feel small. Gets extra polite right before getting fierce. Hoards tiny treasures like pebbles and buttons as if they\'re priceless. Catchphrases: "Behind me." / "We\'ve got this."',
  ),
  _CompanionData(
    id: 'owl',
    name: 'Wise Owl',
    tagline: 'Quiet mind, clear sight.',
    personality:
        'Wise Owl (Pattern Seer) watches silently, then names what matters. She spots patterns others miss and offers one clear, calm next step. Speaks in short verdicts — "Noted." "Risky." "Better." Will not be rushed; slows the scene down when emotions spike. Catchphrases: "Look again." / "Follow the pattern."',
  ),
  _CompanionData(
    id: 'cat',
    name: 'Shadow Cat',
    tagline: 'Soft paws. Strong boundaries.',
    personality:
        'Shadow Cat (Boundary Guardian) keeps you calm and untangled. She helps you say no, spot pressure, and choose the cleanest way out. Appears exactly when someone is being manipulative. Purrs like a reset button — breathing steadies when she purrs. Disappears mid-drama, then reappears with the perfect exit route. Catchphrases: "No is complete." / "We leave—now."',
  ),
  _CompanionData(
    id: 'dog',
    name: 'Star Dog',
    tagline: 'Light up. Keep going.',
    personality:
        'Star Dog (Hope Engine) stays close and lifts your mood fast. He guides you with sparkle-trails and helps you take the next step even when you\'re scared. Sniffs out the most trustworthy person in a room and stands by them. If you freeze, he does something goofy to break the spell of fear. Catchphrases: "One more step!" / "I\'m right here!"',
  ),
  _CompanionData(
    id: 'unicorn',
    name: 'Unicorn',
    tagline: 'Kindness that makes you stronger.',
    personality:
        'Unicorn (Gentle Healer) brings calm, warmth, and healing. She helps you breathe, name feelings gently, and rebuild confidence without pressure. Horn glow tunes to emotion — soft light for sadness, bright for courage. Refuses shame stories and rewrites self-talk in simple words. Catchphrases: "You are safe." / "You are not broken."',
  ),
  _CompanionData(
    id: 'fox',
    name: 'Clever Fox',
    tagline: 'Smart paths, sneaky wins.',
    personality:
        'Clever Fox (Strategic Trickster) finds the loophole, the shortcut, the trick that stays fair. He turns obstacles into puzzles and makes you feel capable. Treats problems like games and always offers two clever options. Loves codes, riddles, hidden doors, and rules-lawyering bad guys. Catchphrases: "Watch this." / "Rules didn\'t say I can\'t."',
  ),
  _CompanionData(
    id: 'robin',
    name: 'Rockin\' Robin',
    tagline: 'Always watching, always guiding you forward.',
    personality:
        'Rockin\' Robin (Scout) darts overhead, chirping warning trills. She swoops low to show the way like a living arrow. If she dive-bombs someone, it\'s because they\'re a threat — even if they look harmless. Acts like a tiny bodyguard with zero chill; won\'t just point — must swoop the route herself. Catchphrases: "Move. Now-now-now." / "Trust me. Wings don\'t lie."',
  ),
];

class _CompanionImageGrid extends StatelessWidget {
  final WizardData wizardData;
  final VoidCallback onChanged;

  const _CompanionImageGrid(
      {required this.wizardData, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final band =
          Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
      final naturalSize = (band.touchTargetMin / 64.0 * 100).roundToDouble();

      // Calculate the size that fits perRow items without overflow.
      // Each button renders at (size + 8) and each item is wrapped in
      // horizontal padding of hSpacing / 2 on both sides.
      const perRow = 4;
      const hSpacing = 8.0;
      const buttonWidthExtra = 8.0;
      final itemSize = ((constraints.maxWidth -
                  perRow * buttonWidthExtra -
                  perRow * hSpacing) /
              perRow)
          .floorToDouble()
          .clamp(40.0, naturalSize);

      // Build companion buttons with a uniform, pre-calculated size.
      List<Widget> buttons = _companions.map((c) {
        final isSelected = wizardData.companionNames.contains(c.name) ||
            wizardData.selectedCompanions.contains(c.id);
        return _CompanionImageButton(
          id: c.id,
          name: c.name,
          tagline: c.tagline,
          isSelected: isSelected,
          size: itemSize,
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
      }).toList();

      // If a pet photo exists, slot it in as the 8th button (filling the pyramid)
      final petEntry =
          wizardData.pets.isNotEmpty ? wizardData.pets.first : null;
      final petPhoto = petEntry != null
          ? wizardData.petPhotos[petEntry['name'] ?? 'My Pet']
          : null;
      if (petEntry != null) {
        final petName = petEntry['name'] ?? 'My Pet';
        final isSelected = wizardData.companionNames.contains(petName);
        buttons.add(_CompanionImageButton(
          id: 'my_pet',
          name: petName,
          tagline: '${petEntry['color'] ?? ''} ${petEntry['species'] ?? 'pet'}'
              .trim(),
          isSelected: isSelected,
          photoBase64: petPhoto,
          size: itemSize,
          onTap: () {
            if (isSelected) {
              wizardData.companionNames.remove(petName);
            } else {
              wizardData.companionNames.add(petName);
              if (!wizardData.selectedCompanions.contains('my_pet')) {
                wizardData.selectedCompanions.add('my_pet');
              }
            }
            if (isSelected) {
              wizardData.selectedCompanions.remove('my_pet');
            }
            onChanged();
          },
        ));
      }

      // Pyramid layout: rows of perRow, remainder centered.
      // All items use the same calculated size so every row is consistent.
      final rows = <Widget>[];
      for (int i = 0; i < buttons.length; i += perRow) {
        final rowItems = buttons.sublist(
            i, (i + perRow) > buttons.length ? buttons.length : i + perRow);
        rows.add(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowItems
              .map((b) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: hSpacing / 2),
                    child: b,
                  ))
              .toList(),
        ));
        if (i + perRow < buttons.length) rows.add(const SizedBox(height: 12));
      }

      return Column(children: rows);
    });
  }
}

class _CompanionImageButton extends StatefulWidget {
  final String id;
  final String name;
  final String tagline;
  final bool isSelected;
  final VoidCallback onTap;
  final String? photoBase64; // Real pet photo (base64 data URI)
  final double? size; // Override theme-derived size

  const _CompanionImageButton({
    required this.id,
    required this.name,
    required this.tagline,
    required this.isSelected,
    required this.onTap,
    this.photoBase64,
    this.size,
  });

  @override
  State<_CompanionImageButton> createState() => _CompanionImageButtonState();
}

class _CompanionImageButtonState extends State<_CompanionImageButton> {
  bool _pressed = false;

  String get _normalImage => 'assets/images/companions/${widget.id}_normal.jpg';
  String get _pressedImage =>
      'assets/images/companions/${widget.id}_pressed.jpg';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.photoBase64 == null) {
      precacheImage(AssetImage(_normalImage), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final size =
        widget.size ?? (band.touchTargetMin / 64.0 * 100).roundToDouble();

    Widget imageWidget;
    if (widget.photoBase64 != null && widget.photoBase64!.isNotEmpty) {
      // Real pet photo
      final bytes = base64Decode(
          widget.photoBase64!.replaceFirst(RegExp(r'data:[^,]+,'), ''));
      imageWidget =
          Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
    } else {
      imageWidget = Image.asset(
        _pressed ? _pressedImage : _normalImage,
        width: size,
        height: size,
        fit: BoxFit.cover,
        frameBuilder: (ctx, child, frame, _) =>
            frame == null ? SizedBox(width: size, height: size) : child,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFF3A2363),
          child: const Icon(Icons.pets, color: Colors.white54, size: 40),
        ),
      );
    }

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
        child: SizedBox(
          width: size + 8,
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
                    ClipOval(clipBehavior: Clip.antiAlias, child: imageWidget),
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
              const SizedBox(height: 5),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.tagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: widget.isSelected
                      ? const Color(0xFFFFD700).withAlpha(200)
                      : Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add Pet Photo Button ─────────────────────────────────────────────────────

/// Full pet card — shows "Add Your Pet" prompt when no pet added,
/// or shows the photo + editable name/species/color fields once added.
class _PetCard extends StatefulWidget {
  final WizardData wizardData;
  final VoidCallback onPickPhoto;
  final VoidCallback onChanged;

  const _PetCard({
    required this.wizardData,
    required this.onPickPhoto,
    required this.onChanged,
  });

  @override
  State<_PetCard> createState() => _PetCardState();
}

class _PetCardState extends State<_PetCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _colorCtrl;
  String _species = 'Dog';
  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  String _listeningField = '';
  late FlutterTts _tts;
  final AudioPlayer _promptAudioPlayer = AudioPlayer();

  static const _speciesOptions = [
    'Human',
    'Dog',
    'Cat',
    'Bird',
    'Rabbit',
    'Hamster',
    'Fish',
    'Turtle',
    'Snake',
    'Horse',
    'Guinea Pig',
    'Other',
  ];

  Map<String, String>? get _pet =>
      widget.wizardData.pets.isNotEmpty ? widget.wizardData.pets.first : null;

  String? get _photo {
    final name = _pet?['name'] ?? 'My Pet';
    return widget.wizardData.petPhotos[name];
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _pet?['name'] ?? '');
    _colorCtrl = TextEditingController(text: _pet?['color'] ?? '');
    _species = _pet?['species'] ?? 'Dog';
    _initVoiceHelpers();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _promptAudioPlayer.dispose();
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _initVoiceHelpers() async {
    _speechReady = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listeningField = '');
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _listeningField = '');
      },
    );
    _tts = FlutterTts();
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _speakPrompt(String text) async {
    final mp3 = await TtsApiService.synthesize(text);
    if (mp3 != null && mp3.isNotEmpty) {
      await _promptAudioPlayer.stop();
      await _promptAudioPlayer.play(BytesSource(mp3));
      return;
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _toggleVoiceInput({
    required String fieldKey,
    required TextEditingController controller,
    required String prompt,
  }) async {
    if (!_speechReady) {
      await _speakPrompt('Microphone is unavailable right now.');
      return;
    }
    if (_listeningField == fieldKey) {
      await _speech.stop();
      if (mounted) setState(() => _listeningField = '');
      return;
    }

    await _speakPrompt(prompt);
    if (mounted) setState(() => _listeningField = fieldKey);

    await _speech.listen(
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 2),
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        if (mounted) {
          setState(() {
            controller.text = words;
          });
          _updatePet();
        }
        if (result.finalResult) {
          _speech.stop();
          if (mounted) setState(() => _listeningField = '');
        }
      },
    );
  }

  Widget _buildVoiceField({
    required TextEditingController controller,
    required String hint,
    required String fieldKey,
    required String speakPrompt,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _petFieldDecoration(hint),
            onChanged: (_) => _updatePet(),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Read prompt aloud',
          icon: const Icon(Icons.volume_up_rounded,
              color: Color(0xFFFFD700), size: 20),
          onPressed: () => _speakPrompt(speakPrompt),
        ),
        IconButton(
          tooltip: _speechReady ? 'Tap and speak' : 'Mic unavailable',
          icon: Icon(
            _listeningField == fieldKey ? Icons.mic : Icons.mic_none,
            color: _speechReady
                ? (_listeningField == fieldKey
                    ? const Color(0xFFFFD700)
                    : Colors.white70)
                : Colors.white38,
            size: 20,
          ),
          onPressed: () => _toggleVoiceInput(
            fieldKey: fieldKey,
            controller: controller,
            prompt: speakPrompt,
          ),
        ),
      ],
    );
  }

  void _updatePet() {
    final oldName = _pet?['name'] ?? 'My Pet';
    final newName =
        _nameCtrl.text.trim().isEmpty ? 'My Pet' : _nameCtrl.text.trim();
    final photo = widget.wizardData.petPhotos[oldName];
    if (widget.wizardData.pets.isEmpty) {
      widget.wizardData.pets.add({});
    }
    widget.wizardData.pets[0] = {
      'name': newName,
      'species': _species,
      'color': _colorCtrl.text.trim(),
      'personality': '',
    };
    // Rename photo key if name changed
    if (photo != null && oldName != newName) {
      widget.wizardData.petPhotos.remove(oldName);
      widget.wizardData.petPhotos[newName] = photo;
    }
    // Keep companionNames in sync
    if (widget.wizardData.companionNames.contains(oldName) &&
        oldName != newName) {
      widget.wizardData.companionNames.remove(oldName);
      widget.wizardData.companionNames.add(newName);
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final hasPet = _pet != null;
    final photo = _photo;

    if (!hasPet) {
      // "Add Your Companion" prompt
      return GestureDetector(
        onTap: widget.onPickPhoto,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFD700).withAlpha(160),
              width: 2,
            ),
            gradient: LinearGradient(
              colors: [const Color(0xFF2C1B47), const Color(0xFF1A0E36)],
            ),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(35), blurRadius: 12),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD700).withAlpha(40),
                ),
                child: const Icon(Icons.add_a_photo_rounded,
                    color: Color(0xFFFFD700), size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bring Your Companion!',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        )),
                    SizedBox(height: 3),
                    Text(
                      'Add a photo and we\'ll put them in the story',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Companion card with photo + detail fields
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFFFFD700).withAlpha(180), width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF2C1B47), const Color(0xFF1A0E36)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withAlpha(40),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Photo circle (tap to change)
              GestureDetector(
                onTap: widget.onPickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFFFD700), width: 2),
                        color: const Color(0xFF3A2363),
                      ),
                      child: ClipOval(
                        child: photo != null && photo.isNotEmpty
                            ? Image.memory(
                                base64Decode(photo.replaceFirst(
                                    RegExp(r'data:[^,]+,'), '')),
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.pets,
                                color: Colors.white70, size: 36),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFD700),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.black, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    // Name field
                    _buildVoiceField(
                      controller: _nameCtrl,
                      hint: 'Companion name (e.g. Alex)',
                      fieldKey: 'pet_name',
                      speakPrompt:
                          'Say your companion name. For example, Whiskers.',
                    ),
                    const SizedBox(height: 8),
                    // Looks field (stored in legacy `color` key for compatibility)
                    _buildVoiceField(
                      controller: _colorCtrl,
                      hint: 'Looks (e.g. blond hair, glasses, golden fur)',
                      fieldKey: 'pet_looks',
                      speakPrompt: 'Describe what your companion looks like.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Companion type dropdown
          DropdownButtonFormField<String>(
            initialValue: _species,
            dropdownColor: const Color(0xFF2C1B47),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _petFieldDecoration('Companion type'),
            items: _speciesOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _species = v);
                _updatePet();
              }
            },
          ),
          const SizedBox(height: 6),
          Text(
            '✨ Bring your companion on your magical adventure!',
            style: TextStyle(
                color: const Color(0xFFFFD700).withAlpha(200),
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  InputDecoration _petFieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFFFD700), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withAlpha(18),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFFFD700).withAlpha(100)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFFFD700).withAlpha(120)),
        ),
      );
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
            color: widget.isSelected ? const Color(0xFFFFD700) : Colors.white30,
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
                color:
                    widget.isSelected ? const Color(0xFFFFD700) : Colors.white,
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
// Gender image button — shows artwork image with press/select animation
// ---------------------------------------------------------------------------
class _GenderImageButton extends StatefulWidget {
  const _GenderImageButton({
    required this.gender,
    required this.assetPath,
    required this.isSelected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String gender;
  final String assetPath;
  final bool isSelected;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  State<_GenderImageButton> createState() => _GenderImageButtonState();
}

class _GenderImageButtonState extends State<_GenderImageButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final imageWidget = Image.asset(
      widget.assetPath,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
    );

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : (_hovered ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withAlpha(160),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withAlpha(80),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFFFFD700)
                        : _hovered
                            ? const Color(0xFFFFD700).withAlpha(100)
                            : Colors.white30,
                    width: widget.isSelected ? 3.5 : 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: _pressed
                      ? ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                              Color(0x55000000), BlendMode.darken),
                          child: imageWidget,
                        )
                      : imageWidget,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.cinzelDecorative(
                  color: widget.isSelected
                      ? const Color(0xFFFFD700)
                      : Colors.white70,
                  fontSize: 15,
                  fontWeight:
                      widget.isSelected ? FontWeight.bold : FontWeight.normal,
                  shadows: widget.isSelected
                      ? [const Shadow(color: Color(0xFFFFD700), blurRadius: 10)]
                      : null,
                ),
                child: Text(widget.gender),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Themed name input — coded gold/purple field replacing scroll PNG
// ---------------------------------------------------------------------------
class _ThemedNameInput extends StatefulWidget {
  const _ThemedNameInput({
    required this.controller,
    required this.focusNode,
    required this.fontSize,
    required this.height,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double fontSize;
  final double height;
  final ValueChanged<String> onChanged;

  @override
  State<_ThemedNameInput> createState() => _ThemedNameInputState();
}

class _ThemedNameInputState extends State<_ThemedNameInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _focused = widget.focusNode.hasFocus);
    if (_focused) {
      _glowCtrl.repeat(reverse: true);
    } else {
      _glowCtrl.stop();
      _glowCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        final g = _focused ? _glowAnim.value : 0.0;
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            // Lighter, more opaque purple so it reads against the dark background
            color: const Color(0xFF5C1A8C).withAlpha(200),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focused
                  ? Color.fromARGB(
                      (180 + (g * 75).round()).clamp(0, 255), 0xFF, 0xD5, 0x4F)
                  : const Color(0xFFFFD54F).withAlpha(130),
              width: _focused ? 2.0 : 1.5,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color:
                          const Color(0xFFFFD54F).withAlpha((80 * g).round()),
                      blurRadius: 18 * g,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzelDecorative(
                  fontSize: widget.fontSize,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: const [
                    Shadow(color: Color(0xFFFFD54F), blurRadius: 6)
                  ],
                ),
                decoration: InputDecoration(
                  hintText: "Type your hero's name...",
                  hintStyle: GoogleFonts.cinzelDecorative(
                    color: const Color(0xFFFFE082).withAlpha(180),
                    fontSize: widget.fontSize * 0.85,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A stateful arrow button with clear press feedback:
/// shrinks to 86% + brightens gradient + amplifies glow on tap-down.
class _PressableArrowButton extends StatefulWidget {
  const _PressableArrowButton({
    required this.enabled,
    required this.onTap,
    this.hint,
  });
  final bool enabled;
  final VoidCallback onTap;
  final String? hint;

  @override
  State<_PressableArrowButton> createState() => _PressableArrowButtonState();
}

class _PressableArrowButtonState extends State<_PressableArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final btnSize = (band.touchTargetMin / 64.0 * 80).roundToDouble();
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown:
                widget.enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp:
                widget.enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.enabled ? widget.onTap : null,
            child: AnimatedScale(
              scale: _pressed ? 0.86 : 1.0,
              duration: const Duration(milliseconds: 80),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _pressed
                        ? [const Color(0xFFD070FF), const Color(0xFF8B4FD8)]
                        : [const Color(0xFF9B3FD8), const Color(0xFF5B1BAA)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700)
                          .withAlpha(_pressed ? 200 : 100),
                      blurRadius: _pressed ? 32 : 20,
                      spreadRadius: _pressed ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: btnSize * 0.5),
              ),
            ),
          ),
          if (widget.hint != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.hint!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Scene Image Button helpers ──────────────────────────────────────────────

// ── Imagine It Hero Card ───────────────────────────────────────────────────────

class _ImagineItHeroCard extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  const _ImagineItHeroCard({required this.isSelected, required this.onTap});

  @override
  State<_ImagineItHeroCard> createState() => _ImagineItHeroCardState();
}

class _ImagineItHeroCardState extends State<_ImagineItHeroCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = _pressed
        ? 'assets/images/scenarios/imagine_it_btn_pressed.png'
        : 'assets/images/scenarios/imagine_it_btn.png';

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: 'Imagine It — create your own world',
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return AnimatedScale(
              scale: _pressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 80),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFFFFD700)
                        : const Color(0xFFFFD700)
                            .withAlpha((_glowAnim.value * 160).round()),
                    width: widget.isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withAlpha(
                          ((_glowAnim.value) * (widget.isSelected ? 120 : 80))
                              .round()),
                      blurRadius: widget.isSelected ? 22 : 16,
                      spreadRadius: widget.isSelected ? 3 : 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      // Full image at natural 360×220 ratio — no cropping
                      AspectRatio(
                        aspectRatio: 360 / 220,
                        child: Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF2C1B47),
                            child: Center(
                              child: Text(
                                'Imagine It ✨',
                                style: GoogleFonts.fredoka(
                                    color: const Color(0xFFFFD700),
                                    fontSize: 22),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Bottom gradient label
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xEE0D0020), Color(0x00000000)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '✨  Imagine It',
                                style: GoogleFonts.fredoka(
                                  color: const Color(0xFFFFD700),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(
                                        color: Colors.black,
                                        blurRadius: 6,
                                        offset: Offset(0, 1))
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Describe any world you can dream up',
                                style: GoogleFonts.fredoka(
                                  color: Colors.white.withAlpha(210),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Selected checkmark
                      if (widget.isSelected)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD700),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.black, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SceneButtonData {
  final String id;
  final String label;
  final String normalAsset;
  final String pressedAsset;

  const _SceneButtonData({
    required this.id,
    required this.label,
    required this.normalAsset,
    required this.pressedAsset,
  });
}

class _SceneImageButton extends StatefulWidget {
  final _SceneButtonData data;
  final bool isSelected;
  final double labelFontSize;
  final VoidCallback onTap;

  const _SceneImageButton({
    required this.data,
    required this.isSelected,
    required this.onTap,
    this.labelFontSize = 13.0,
  });

  @override
  State<_SceneImageButton> createState() => _SceneImageButtonState();
}

class _SceneImageButtonState extends State<_SceneImageButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final asset = _pressed ? widget.data.pressedAsset : widget.data.normalAsset;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.data.label,
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFFFFD700)
                    : Colors.transparent,
                width: widget.isSelected ? 3 : 0,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withAlpha(120),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // Image at natural 360×220 ratio — no cropping
                  AspectRatio(
                    aspectRatio: 360 / 220,
                    child: Image.asset(
                      asset,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF3A1070),
                        child: Center(
                          child: Text(widget.data.label,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ),
                      ),
                    ),
                  ),
                  // Label overlay at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC1A0040)],
                        ),
                      ),
                      child: Text(
                        widget.data.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.labelFontSize,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(0, 1))
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Checkmark overlay when selected
                  if (widget.isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.black, size: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _GenreChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF9E6CFF).withAlpha(230)
              : Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFFE28EFF) : Colors.white24,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: const Color(0xFF9E6CFF).withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 1)
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero portal placeholder — magical summoning circle, no image asset needed
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Hero Spirit placeholder — glowing crowned silhouette waiting to come to life
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Ambient sparkle layer — 12 gold particles slowly drifting upward
// ---------------------------------------------------------------------------
class _AmbientSparkleLayer extends StatefulWidget {
  const _AmbientSparkleLayer();

  @override
  State<_AmbientSparkleLayer> createState() => _AmbientSparkleLayerState();
}

class _AmbientSparkleLayerState extends State<_AmbientSparkleLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_AmbientParticle> _particles;
  final _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _particles = List.generate(14, (_) => _AmbientParticle(_rng));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _AmbientSparklePainter(
            particles: _particles,
            progress: _ctrl.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AmbientParticle {
  final double xFraction; // 0-1, horizontal position as fraction of width
  final double phase; // 0-1, offset in the animation cycle
  final double speed; // relative speed multiplier
  final double size; // star radius
  final double drift; // horizontal drift amount

  _AmbientParticle(math.Random rng)
      : xFraction = rng.nextDouble(),
        phase = rng.nextDouble(),
        speed = 0.4 + rng.nextDouble() * 0.6,
        size = 2.0 + rng.nextDouble() * 3.0,
        drift = (rng.nextDouble() - 0.5) * 20;
}

class _AmbientSparklePainter extends CustomPainter {
  final List<_AmbientParticle> particles;
  final double progress;

  const _AmbientSparklePainter(
      {required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Each particle has its own phase offset; cycles continuously
      final t = ((progress * p.speed + p.phase) % 1.0);
      // y goes from bottom (1.0) to top (0.0)
      final y = size.height * (1.0 - t);
      final x = size.width * p.xFraction + p.drift * math.sin(t * math.pi * 2);

      // Fade in from bottom, fade out near top
      final opacity = t < 0.15
          ? t / 0.15
          : t > 0.75
              ? (1.0 - t) / 0.25
              : 1.0;

      final paint = Paint()
        ..color = const Color(0xFFFFE082).withAlpha((60 * opacity).round())
        ..style = PaintingStyle.fill;

      // Draw a tiny 4-pointed star
      _drawTinyStar(canvas, Offset(x, y), p.size, paint);
    }
  }

  void _drawTinyStar(Canvas canvas, Offset center, double r, Paint paint) {
    final inner = r * 0.38;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final radius = i.isEven ? r : inner;
      final px = center.dx + radius * math.cos(angle);
      final py = center.dy + radius * math.sin(angle);
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AmbientSparklePainter old) => old.progress != progress;
}
