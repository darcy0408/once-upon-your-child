import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models.dart';
import '../../theme/age_band_theme.dart';
import '../../data/scenario_data.dart';
import '../../character_traits_data.dart';
import '../../widgets/archetype_card.dart';
import '../../widgets/hero_creator/genre_chip.dart';
import '../../widgets/hero_creator/hero_input_widgets.dart';
import '../../widgets/safe_asset_image.dart';

/// The Creative Brief form shown to mature-band users (creator / adolescent / adult)
/// instead of the step-by-step wizard PageView.
///
/// All mutations go directly to [wizardData] (passed by reference).
/// [onChanged] wraps the parent's setState so the widget rebuilds with fresh data.
class CreativeBriefWidget extends StatelessWidget {
  const CreativeBriefWidget({
    super.key,
    required this.wizardData,
    required this.availableCharacters,
    required this.briefScrollController,
    required this.briefCharacterKey,
    required this.briefCompanionsKey,
    required this.briefWorldKey,
    required this.briefConfigKey,
    required this.briefCharacterController,
    required this.briefCompanionsController,
    required this.briefWorldController,
    required this.briefConfigController,
    required this.nameController,
    required this.characterDesireController,
    required this.imagineItController,
    required this.wishController,
    required this.selectedArchetypeId,
    required this.onChanged,
    required this.onContinue,
    required this.onLoadCharacter,
    required this.onSelectArchetype,
    required this.companionShowcase,
    required this.companionGrid,
  });

  final WizardData wizardData;
  final List<Character> availableCharacters;
  final ScrollController briefScrollController;
  final GlobalKey briefCharacterKey;
  final GlobalKey briefCompanionsKey;
  final GlobalKey briefWorldKey;
  final GlobalKey briefConfigKey;
  final ExpansibleController briefCharacterController;
  final ExpansibleController briefCompanionsController;
  final ExpansibleController briefWorldController;
  final ExpansibleController briefConfigController;
  final TextEditingController nameController;
  final TextEditingController characterDesireController;
  final TextEditingController imagineItController;
  final TextEditingController wishController;
  final String? selectedArchetypeId;
  final VoidCallback onChanged;
  final VoidCallback onContinue;
  final void Function(Character character) onLoadCharacter;
  final void Function(ArchetypeData archetype) onSelectArchetype;
  final Widget companionShowcase;
  final Widget companionGrid;

  // ── helpers ────────────────────────────────────────────────────────────────

  ImageProvider<Object> _getAvatarProvider(String imageBase64) {
    if (imageBase64.startsWith('assets/')) return AssetImage(imageBase64);
    if (imageBase64.startsWith('http')) return NetworkImage(imageBase64);
    try {
      final normalized =
          imageBase64.contains(',') ? imageBase64.split(',').last : imageBase64;
      return MemoryImage(base64Decode(normalized));
    } catch (_) {
      return const AssetImage('assets/images/hero_placeholder.jpg');
    }
  }

  static String _lengthToLabel(String length) => switch (length) {
        'quick' => 'Short',
        'epic' => 'Long',
        _ => 'Medium',
      };

  static String _labelToLength(String label) => switch (label) {
        'Short' => 'quick',
        'Long' => 'epic',
        _ => 'standard',
      };

  // ── section builders ───────────────────────────────────────────────────────

  Widget _buildBriefHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Build Your Story',
          style: GoogleFonts.sourceSans3(
            color: const Color(0xFFFFD700),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Shape your story.',
          style: GoogleFonts.sourceSans3(
            color: Colors.white70,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFFFFD700), thickness: 2, endIndent: 200),
      ],
    );
  }

  Widget _buildBriefSection(
    BuildContext context,
    String title,
    Widget content, {
    bool initiallyExpanded = false,
    bool optional = false,
    Key? sectionKey,
    ExpansibleController? tileController,
  }) {
    return Theme(
      key: sectionKey,
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        controller: tileController,
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16),
        title: Row(
          children: [
            Text(
              title.toUpperCase(),
              style: GoogleFonts.sourceSans3(
                color: const Color(0xFFFFD700).withAlpha(180),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            if (optional) ...[
              const SizedBox(width: 6),
              Text(
                'optional',
                style: GoogleFonts.sourceSans3(
                  color: Colors.white30,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
        iconColor: const Color(0xFFFFD700),
        collapsedIconColor: Colors.white30,
        children: [content],
      ),
    );
  }

  Widget _buildRestoreCharacterSection(BuildContext context) {
    if (availableCharacters.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          'RESTORE PREVIOUS CHARACTER',
          style: GoogleFonts.sourceSans3(
            color: const Color(0xFFFFD700),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        subtitle: Text(
          'Load an existing hero profile',
          style: TextStyle(
              color: Colors.white.withAlpha(80), fontSize: 10, height: 1.5),
        ),
        iconColor: const Color(0xFFFFD700),
        collapsedIconColor: const Color(0xFFFFD700),
        children: availableCharacters.map((char) {
          final avatarData = char.generatedAvatar?.imageBase64;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF3A2363),
              backgroundImage: avatarData != null
                  ? _getAvatarProvider(avatarData)
                  : const AssetImage('assets/images/hero_placeholder.jpg')
                      as ImageProvider,
            ),
            title: Text(char.name,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text(char.role,
                style: TextStyle(
                    color: Colors.white.withAlpha(100), fontSize: 11)),
            trailing: const Icon(Icons.file_upload_outlined,
                color: Color(0xFFFFD700), size: 18),
            onTap: () => onLoadCharacter(char),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBriefGenderSelector(AgeBandThemeData band) {
    final ageBand = band.band;

    final String boyAsset;
    final String girlAsset;
    switch (ageBand) {
      case AgeBand.adolescent:
        boyAsset = 'assets/images/archetypes/adolescent/master_creator_boy.webp';
        girlAsset = 'assets/images/archetypes/adolescent/master_creator_girl.webp';
        break;
      case AgeBand.adult:
        boyAsset = 'assets/images/ui/adult/man_character_white.webp';
        girlAsset = 'assets/images/ui/adult/woman_character_white.webp';
        break;
      case AgeBand.creator:
        // Bug fix: both genders previously pointed at one generic image
        // (creator_white.webp), so the picker showed the same figure twice
        // (read as two girls). Use the dedicated older-silhouette Creator
        // gender art that already exists alongside the other bands'.
        boyAsset = 'assets/images/ui/gender/gender_creator_boy.webp';
        girlAsset = 'assets/images/ui/gender/gender_creator_girl.webp';
        break;
      case AgeBand.sprout:
      case AgeBand.explorer:
      case AgeBand.adventurer:
        boyAsset = 'assets/images/ui/creator/creator_white.webp';
        girlAsset = 'assets/images/ui/creator/creator_white.webp';
    }

    final gender = wizardData.characterGender;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHARACTER GENDER',
          style: GoogleFonts.sourceSans3(
            color: Colors.white.withAlpha(100),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GenderImageButton(
              gender: 'Boy',
              assetPath: boyAsset,
              isSelected: gender == 'Boy',
              width: 96,
              height: 120,
              onTap: () {
                wizardData.characterGender = 'Boy';
                onChanged();
              },
            ),
            const SizedBox(width: 32),
            GenderImageButton(
              gender: 'Girl',
              assetPath: girlAsset,
              isSelected: gender == 'Girl',
              width: 96,
              height: 120,
              onTap: () {
                wizardData.characterGender = 'Girl';
                onChanged();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBriefIdentityInputs(BuildContext context, AgeBandThemeData band) {
    final ageBand = ageBandFromAge(wizardData.characterAge);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          style: GoogleFonts.sourceSans3(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            labelText: 'PROTAGONIST NAME',
            labelStyle: GoogleFonts.sourceSans3(
                color: const Color(0xFFFFD700), fontSize: 10),
            hintText: 'Enter name...',
            hintStyle: TextStyle(color: Colors.white.withAlpha(40)),
            // Disable the global light-teal fill so the white input text shows
            // on this dark screen (underline-only field by design).
            filled: false,
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withAlpha(40))),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFFFD700))),
          ),
          onChanged: (v) => wizardData.characterName = v,
        ),
        if (ageBand.isMature) ...[
          const SizedBox(height: 20),
          Text(
            'What does your character want more than anything?',
            style: GoogleFonts.bitter(
              color: Colors.white54,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'What your character wants',
            textField: true,
            child: TextField(
            controller: characterDesireController,
            style: GoogleFonts.sourceSans3(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'e.g. to prove themselves, to reconnect with family',
              hintStyle: TextStyle(
                  color: Colors.white.withAlpha(35), fontSize: 14),
              // Disable the global light-teal fill so the white input text shows
              // on this dark screen (underline-only field by design).
              filled: false,
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withAlpha(30))),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7C4DFF))),
            ),
            onChanged: (v) =>
                wizardData.characterDesire = v.trim().isEmpty ? null : v,
          ),
          ),
        ],
        const SizedBox(height: 12),
        _buildBriefGenderSelector(band),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            text: 'CORE ARCHETYPE',
            style: GoogleFonts.sourceSans3(
                color: Colors.white.withAlpha(100),
                fontSize: 10,
                fontWeight: FontWeight.bold),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final band = ageBandFromAge(wizardData.characterAge);
          final gender = wizardData.characterGender;
          final archetypes = CharacterArchetypes.forBand(band);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: archetypes.length,
            itemBuilder: (_, index) {
              final archetype = archetypes[index];
              final isSelected = selectedArchetypeId == archetype.name;
              final imagePath = archetype.imagePathForBand(
                band,
                gender: gender.isNotEmpty ? gender : null,
              );
              return GestureDetector(
                onTap: () => onSelectArchetype(archetype),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFD700)
                          : Colors.white.withAlpha(40),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(
                            color: const Color(0xFFFFD700).withAlpha(80),
                            blurRadius: 10,
                          )]
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: const Color(0xFF1A0A2E)),
                        if (imagePath != null)
                          SafeAssetImage(
                            imagePath,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            placeholder: Center(
                              child: Text(archetype.icon ?? '✨',
                                  style: const TextStyle(fontSize: 48)),
                            ),
                          )
                        else
                          Center(
                            child: Text(archetype.icon ?? '✨',
                                style: const TextStyle(fontSize: 48)),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withAlpha(200),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Text(
                              archetype.nameForAge(wizardData.characterAge),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sourceSans3(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFD700),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.check,
                                  size: 14, color: Colors.black),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildBriefPersonalitySliders(BuildContext context) {
    final sliders = wizardData.personalitySliders;
    final age = wizardData.characterAge;

    PersonalitySliderDefinition def(String key) =>
        CharacterTraitsData.personalitySliders.firstWhere(
          (s) => s.key == key,
          orElse: () => CharacterTraitsData.personalitySliders.first,
        );

    return Column(
      children: [
        _buildBriefSlider(
          context,
          'Energy Level',
          def('expressiveness').leftLabelForAge(age),
          def('expressiveness').rightLabelForAge(age),
          'expressiveness',
          sliders,
        ),
        _buildBriefSlider(
          context,
          'Social Style',
          def('sociability').leftLabelForAge(age),
          def('sociability').rightLabelForAge(age),
          'sociability',
          sliders,
        ),
        _buildBriefSlider(
          context,
          'CONSTRUCTIVE LOGIC',
          def('problem_solving').leftLabelForAge(age),
          def('problem_solving').rightLabelForAge(age),
          'problem_solving',
          sliders,
        ),
        _buildBriefSlider(
          context,
          'ADVENTURE TOLERANCE',
          def('adventure').leftLabelForAge(age),
          def('adventure').rightLabelForAge(age),
          'adventure',
          sliders,
        ),
      ],
    );
  }

  Widget _buildBriefSlider(
    BuildContext context,
    String label,
    String left,
    String right,
    String key,
    Map<String, int> sliders,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.sourceSans3(
                  color: Colors.white.withAlpha(80),
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text(left,
                  style: GoogleFonts.sourceSans3(
                      color: Colors.white70, fontSize: 10)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFFFD700),
                    inactiveTrackColor: Colors.white12,
                    thumbColor: const Color(0xFFFFD700),
                    overlayColor: const Color(0xFFFFD700).withAlpha(32),
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: (sliders[key] ?? 50).toDouble(),
                    min: 0,
                    max: 100,
                    onChanged: (v) {
                      sliders[key] = v.round();
                      onChanged();
                    },
                  ),
                ),
              ),
              Text(right,
                  style: GoogleFonts.sourceSans3(
                      color: Colors.white70, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBriefCompanionsInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CAST',
          style: GoogleFonts.sourceSans3(
              color: Colors.white.withAlpha(100),
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        companionShowcase,
        const SizedBox(height: 16),
        companionGrid,
      ],
    );
  }

  Widget _buildBriefWorldInputs(BuildContext context, AgeBandThemeData band) {
    final scenarios =
        ScenarioData.all.where((s) => s.id != 'safe_space').toList();
    final isCustom = wizardData.selectedScenario == 'safe_space';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRIMARY SETTING',
          style: GoogleFonts.sourceSans3(
              color: Colors.white.withAlpha(100),
              fontSize: 10,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...scenarios.map((s) {
              final isSelected = wizardData.selectedScenario == s.id;
              return ChoiceChip(
                label: Text(s.titleForBand(band.band).toUpperCase()),
                selected: isSelected,
                onSelected: (v) {
                  wizardData.selectedScenario = v ? s.id : null;
                  onChanged();
                },
                color: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFFFFD700).withAlpha(40);
                  }
                  return const Color(0xFF1A0A2E);
                }),
                labelStyle: GoogleFonts.sourceSans3(
                  color: isSelected ? const Color(0xFFFFD700) : Colors.white70,
                  fontSize: 10,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFFFD700)
                            : Colors.white.withAlpha(40))),
              );
            }),
            ChoiceChip(
              label: Text('✏️ MY OWN IDEA',
                  style: GoogleFonts.sourceSans3(
                    color: isCustom ? const Color(0xFFFFD700) : Colors.white70,
                    fontSize: 10,
                  )),
              selected: isCustom,
              onSelected: (v) {
                wizardData.selectedScenario = v ? 'safe_space' : null;
                onChanged();
              },
              color: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFFFFD700).withAlpha(40);
                }
                return const Color(0xFF1A0A2E);
              }),
              labelStyle: GoogleFonts.sourceSans3(
                color: isCustom ? const Color(0xFFFFD700) : Colors.white70,
                fontSize: 10,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                      color: isCustom
                          ? const Color(0xFFFFD700)
                          : Colors.white.withAlpha(40))),
            ),
          ],
        ),
        if (isCustom) ...[
          const SizedBox(height: 16),
          Semantics(
            label: 'Describe your world or premise',
            textField: true,
            child: TextField(
            controller: imagineItController,
            maxLines: 2,
            style: GoogleFonts.sourceSans3(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Type anything — e.g. ride a magic carpet, win the lottery, pull off a daring heist...',
              hintStyle: TextStyle(
                  color: Colors.white.withAlpha(40),
                  fontStyle: FontStyle.italic),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) {
              wizardData.customElements = v;
              wishController.text = v;
            },
          ),
          ),
        ],
      ],
    );
  }

  Widget _buildBriefConfigInputs(BuildContext context, AgeBandThemeData band) {
    final showGenreChips = band.band.isMature;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showGenreChips) ...[
          Text(
            'GENRE',
            style: GoogleFonts.sourceSans3(
                color: Colors.white.withAlpha(100),
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GenreChip(
                  label: '🔍 Mystery',
                  value: 'mystery',
                  selected: wizardData.selectedGenre == 'mystery',
                  onTap: () {
                    wizardData.selectedGenre =
                        wizardData.selectedGenre == 'mystery' ? null : 'mystery';
                    onChanged();
                  }),
              GenreChip(
                  label: '👻 Horror',
                  value: 'horror',
                  selected: wizardData.selectedGenre == 'horror',
                  onTap: () {
                    wizardData.selectedGenre =
                        wizardData.selectedGenre == 'horror' ? null : 'horror';
                    onChanged();
                  }),
              GenreChip(
                  label: '🤝 Friendship',
                  value: 'friendship',
                  selected: wizardData.selectedGenre == 'friendship',
                  onTap: () {
                    wizardData.selectedGenre =
                        wizardData.selectedGenre == 'friendship'
                            ? null
                            : 'friendship';
                    onChanged();
                  }),
              GenreChip(
                  label: '🚀 Sci-Fi',
                  value: 'sci-fi',
                  selected: wizardData.selectedGenre == 'sci-fi',
                  onTap: () {
                    wizardData.selectedGenre =
                        wizardData.selectedGenre == 'sci-fi' ? null : 'sci-fi';
                    onChanged();
                  }),
              GenreChip(
                  label: '🏚️ Dystopia',
                  value: 'dystopia',
                  selected: wizardData.selectedGenre == 'dystopia',
                  onTap: () {
                    wizardData.selectedGenre =
                        wizardData.selectedGenre == 'dystopia'
                            ? null
                            : 'dystopia';
                    onChanged();
                  }),
              GenreChip(
                  label: '📖 Literary',
                  value: 'literary',
                  selected: wizardData.selectedGenre == 'literary',
                  onTap: () {
                    wizardData.selectedGenre =
                        wizardData.selectedGenre == 'literary'
                            ? null
                            : 'literary';
                    onChanged();
                  }),
              GenreChip(
                  label: '😂 Comedy',
                  value: 'comedy',
                  selected: wizardData.selectedGenre == 'comedy',
                  onTap: () {
                    wizardData.selectedGenre =
                        wizardData.selectedGenre == 'comedy' ? null : 'comedy';
                    onChanged();
                  }),
              GenreChip(
                  label: '⚔️ Action',
                  value: 'action',
                  selected: wizardData.selectedGenre == 'action',
                  onTap: () {
                    wizardData.selectedGenre =
                        wizardData.selectedGenre == 'action' ? null : 'action';
                    onChanged();
                  }),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Expanded(
              child: _buildBriefDropdown(
                context,
                'NARRATIVE MODE',
                wizardData.interactiveMode
                    ? 'Interactive'
                    : (wizardData.rhymeTimeMode ? 'Poetry' : 'Standard View'),
                ['Standard View', 'Interactive', 'Poetry'],
                (v) {
                  wizardData.interactiveMode = v == 'Interactive';
                  wizardData.rhymeTimeMode = v == 'Poetry';
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBriefDropdown(
                context,
                'TARGET DURATION',
                _lengthToLabel(wizardData.storyLength),
                ['Short', 'Medium', 'Long'],
                (v) {
                  wizardData.storyLength = _labelToLength(v!);
                  onChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBriefDropdown(
    BuildContext context,
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onValueChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.sourceSans3(
                color: Colors.white.withAlpha(80),
                fontSize: 9,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(value) ? value : options.first,
              dropdownColor: const Color(0xFF2C1B47),
              isExpanded: true,
              style:
                  GoogleFonts.sourceSans3(color: Colors.white, fontSize: 12),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Color(0xFFFFD700), size: 18),
              onChanged: onValueChanged,
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    return SingleChildScrollView(
      controller: briefScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBriefHeader(),
          const SizedBox(height: 16),
          _buildRestoreCharacterSection(context),
          const SizedBox(height: 16),
          _buildBriefSection(
            context,
            'Character & Role',
            _buildBriefIdentityInputs(context, band),
            initiallyExpanded: true,
            sectionKey: briefCharacterKey,
            tileController: briefCharacterController,
          ),
          _buildBriefSection(
            context,
            'Personality',
            _buildBriefPersonalitySliders(context),
            optional: true,
          ),
          _buildBriefSection(
            context,
            'Cast & Companions',
            _buildBriefCompanionsInputs(),
            optional: true,
            sectionKey: briefCompanionsKey,
            tileController: briefCompanionsController,
          ),
          _buildBriefSection(
            context,
            'World & Setting',
            _buildBriefWorldInputs(context, band),
            optional: true,
            sectionKey: briefWorldKey,
            tileController: briefWorldController,
          ),
          _buildBriefSection(
            context,
            'Story Options',
            _buildBriefConfigInputs(context, band),
            optional: true,
            sectionKey: briefConfigKey,
            tileController: briefConfigController,
          ),
          const SizedBox(height: 48),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: Text(
                  'Create Story',
                  style: GoogleFonts.sourceSans3(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
