import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models.dart';
import '../../theme/age_band_theme.dart';
import '../../widgets/image_mode_orb.dart';
import '../../widgets/hero_creator/genre_chip.dart';
import '../../widgets/hero_creator/hero_input_widgets.dart';

/// Page 6 of the Hero Creator wizard — story type / mode selection.
///
/// All mutations go directly to [wizardData] (passed by reference).
/// [onChanged] wraps the parent's setState so the page rebuilds with fresh data.
class HeroStoryTypePage extends StatelessWidget {
  const HeroStoryTypePage({
    super.key,
    required this.wizardData,
    required this.wishController,
    required this.listeningFor,
    required this.speechAvailable,
    required this.onChanged,
    required this.onContinue,
    required this.onToggleListening,
    this.onSpeakForSprout,
    this.illustrationsEnabled = true,
  });

  final WizardData wizardData;
  final TextEditingController wishController;
  final String listeningFor;
  final bool speechAvailable;
  final VoidCallback onChanged;
  final VoidCallback onContinue;
  final void Function(String field) onToggleListening;
  /// Optional Sprout TTS callback — when provided, card taps speak the label
  /// aloud so non-readers get audio confirmation of their selection.
  final Future<void> Function(String text)? onSpeakForSprout;
  /// Whether the current user can generate illustrations (premium or BYOK).
  /// When false, story-type labels avoid promising pictures.
  final bool illustrationsEnabled;

  // ── helpers ────────────────────────────────────────────────────────────────

  TextStyle _bandTitleStyle(AgeBandThemeData band, {double baseFontSize = 24}) {
    if (band.band == AgeBand.sprout) {
      return GoogleFonts.fredoka(
        color: const Color(0xFFFFD700),
        fontSize: 28,
        fontWeight: FontWeight.bold,
      );
    }
    if (band.band.isMature) {
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

  Widget _buildSproutModeCard({
    required String emoji,
    required String label,
    required String description,
    required String mode,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        onSpeakForSprout?.call(label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white24,
            width: isSelected ? 3 : 1.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    accentColor.withAlpha(70),
                    accentColor.withAlpha(35),
                  ]
                : [
                    Colors.white.withAlpha(18),
                    Colors.white.withAlpha(10),
                  ],
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withAlpha(90),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.15 : 1.0,
              child: Text(emoji, style: const TextStyle(fontSize: 44)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.fredoka(
                      color: Colors.white.withAlpha(200),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Icon(Icons.check_circle_rounded,
                      key: const ValueKey('check'), color: accentColor, size: 32)
                  : Icon(Icons.circle_outlined,
                      key: const ValueKey('empty'),
                      color: Colors.white30,
                      size: 32),
            ),
          ],
        ),
      ),
    );
  }

  String _getReadingLabel(AgeBand band) {
    switch (band) {
      case AgeBand.sprout:
        return 'Listen & Learn';
      case AgeBand.explorer:
        return 'Easy Reader';
      case AgeBand.adventurer:
        return 'Chapter Reader';
      case AgeBand.creator:
      case AgeBand.adolescent:
      case AgeBand.adult:
        return 'First Chapter';
    }
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
          Text(
            "Pick something special!",
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: band.body(16),
              fontWeight: FontWeight.w600,
            ),
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
              final selected = wizardData.customElements == prompt.$3;
              return InkWell(
                borderRadius: BorderRadius.circular(band.radiusMd),
                onTap: () {
                  wizardData.customElements = prompt.$3;
                  wishController.text = prompt.$3;
                  onChanged();
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
          Text(
            "Anything special you want?",
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: band.body(16),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: band.space(8)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: wishController,
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
                  onChanged: (v) => wizardData.customElements = v,
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
                  listeningFor == 'wish' ? Icons.mic : Icons.mic_none,
                  color: listeningFor == 'wish' ? Colors.yellow : Colors.white,
                ),
                onPressed: () => onToggleListening('wish'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final data = wizardData;
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final isCreator = band.band.isMature;
    String selectedMode = 'tales';
    if (data.interactiveMode) {
      selectedMode = 'pickpath';
    } else if (data.learningToReadMode) {
      selectedMode = 'reading';
    } else if (data.rhymeTimeMode) {
      selectedMode = 'rhyme';
    }

    void setStoryMode(String mode) {
      data.includeIllustrations = mode == 'tales';
      data.rhymeTimeMode = mode == 'rhyme';
      data.learningToReadMode = mode == 'reading';
      data.interactiveMode = mode == 'pickpath';
    }

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
          Text(
            storyTitle,
            textAlign: TextAlign.center,
            style: _bandTitleStyle(band, baseFontSize: 24),
          ),
          SizedBox(height: band.space(24)),
          Text(
            band.band == AgeBand.sprout
                ? 'Pick the one you like! 👇'
                : 'Pick your story style',
            style: GoogleFonts.fredoka(
              color: Colors.white.withAlpha(200),
              fontSize: band.band == AgeBand.sprout ? 17 : band.body(16),
            ),
          ),
          SizedBox(height: band.space(16)),
          if (band.band == AgeBand.sprout)
            Column(
              children: [
                _buildSproutModeCard(
                  emoji: '✨',
                  label: 'Story Quest',
                  description: illustrationsEnabled
                      ? 'A story with pictures!'
                      : 'A magical adventure story!',
                  mode: 'tales',
                  isSelected: selectedMode == 'tales',
                  accentColor: const Color(0xFFAA88FF),
                  onTap: () {
                    setStoryMode('tales');
                    onChanged();
                  },
                ),
                const SizedBox(height: 14),
                _buildSproutModeCard(
                  emoji: '🎵',
                  label: 'Rhyme Time',
                  description: 'Silly songs and rhymes!',
                  mode: 'rhyme',
                  isSelected: selectedMode == 'rhyme',
                  accentColor: const Color(0xFF00D4DD),
                  onTap: () {
                    setStoryMode('rhyme');
                    onChanged();
                  },
                ),
                const SizedBox(height: 14),
                _buildSproutModeCard(
                  emoji: '👂',
                  label: 'Listen & Learn',
                  description: 'Easy words to say along!',
                  mode: 'reading',
                  isSelected: selectedMode == 'reading',
                  accentColor: const Color(0xFFFF9ECC),
                  onTap: () {
                    setStoryMode('reading');
                    onChanged();
                  },
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ImageModeOrb(
                        modeType: 'tales',
                        label: isCreator ? 'Story' : 'Story Quest',
                        subtitle: isCreator
                            ? (illustrationsEnabled
                                ? 'Illustrated narrative'
                                : 'Narrative story')
                            : (illustrationsEnabled
                                ? 'An illustrated adventure'
                                : 'An epic adventure'),
                        isActive: selectedMode == 'tales',
                        onTap: () {
                          setStoryMode('tales');
                          onChanged();
                        },
                        primaryColor: const Color(0xFFAA88FF),
                        secondaryColor: const Color(0xFFE28EFF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ImageModeOrb(
                        modeType: 'rhyme',
                        label: data.characterAge >= 11 ? 'Poetry' : 'Rhyme Time',
                        subtitle: isCreator
                            ? 'Verse and rhythm'
                            : 'A story in rhymes',
                        isActive: selectedMode == 'rhyme',
                        onTap: () {
                          setStoryMode('rhyme');
                          onChanged();
                        },
                        primaryColor: const Color(0xFF00D4DD),
                        secondaryColor: const Color(0xFF7FDDFF),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: band.space(12)),
                Row(
                  children: [
                    Expanded(
                      child: ImageModeOrb(
                        modeType: 'pickpath',
                        label: isCreator ? 'Choose Your Path' : 'Pick a Path',
                        subtitle: isCreator
                            ? 'Branch the narrative'
                            : 'You choose what happens!',
                        isActive: selectedMode == 'pickpath',
                        onTap: () {
                          setStoryMode('pickpath');
                          onChanged();
                        },
                        primaryColor: const Color(0xFF9E6CFF),
                        secondaryColor: const Color(0xFFFFB3E6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (data.characterAge < 9)
                      Expanded(
                        child: ImageModeOrb(
                          modeType: 'reading',
                          label: _getReadingLabel(band.band),
                          subtitle: 'Chapter-style reading',
                          isActive: selectedMode == 'reading',
                          onTap: () {
                            setStoryMode('reading');
                            onChanged();
                          },
                          primaryColor: const Color(0xFFB88AFF),
                          secondaryColor: const Color(0xFFFF9ECC),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          SizedBox(height: band.space(12)),
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
                GenreChip(
                    label: '🔍 Mystery',
                    value: 'mystery',
                    selected: wizardData.selectedGenre == 'mystery',
                    onTap: () {
                      wizardData.selectedGenre =
                          wizardData.selectedGenre == 'mystery'
                              ? null
                              : 'mystery';
                      onChanged();
                    }),
                GenreChip(
                    label: '😂 Comedy',
                    value: 'comedy',
                    selected: wizardData.selectedGenre == 'comedy',
                    onTap: () {
                      wizardData.selectedGenre =
                          wizardData.selectedGenre == 'comedy'
                              ? null
                              : 'comedy';
                      onChanged();
                    }),
                GenreChip(
                    label: '🚀 Sci-Fi',
                    value: 'sci-fi',
                    selected: wizardData.selectedGenre == 'sci-fi',
                    onTap: () {
                      wizardData.selectedGenre =
                          wizardData.selectedGenre == 'sci-fi'
                              ? null
                              : 'sci-fi';
                      onChanged();
                    }),
                GenreChip(
                    label: '⚔️ Action',
                    value: 'action',
                    selected: wizardData.selectedGenre == 'action',
                    onTap: () {
                      wizardData.selectedGenre =
                          wizardData.selectedGenre == 'action'
                              ? null
                              : 'action';
                      onChanged();
                    }),
                GenreChip(
                    label: '👻 Spooky',
                    value: 'spooky',
                    selected: wizardData.selectedGenre == 'spooky',
                    onTap: () {
                      wizardData.selectedGenre =
                          wizardData.selectedGenre == 'spooky'
                              ? null
                              : 'spooky';
                      onChanged();
                    }),
                GenreChip(
                    label: '💕 Romance',
                    value: 'romance',
                    selected: wizardData.selectedGenre == 'romance',
                    onTap: () {
                      wizardData.selectedGenre =
                          wizardData.selectedGenre == 'romance'
                              ? null
                              : 'romance';
                      onChanged();
                    }),
              ],
            ),
            const SizedBox(height: 24),
          ],
          if (band.band == AgeBand.explorer)
            _buildWishPromptButtons(band)
          else if (band.band != AgeBand.sprout)
            _buildWishTextInput(band),
          SizedBox(height: band.space(32)),
          PressableArrowButton(
              enabled: true,
              onTap: onContinue,
              hint: band.wizardNextHint),
          SizedBox(height: band.space(20)),
        ],
      ),
    );
  }
}
