import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models.dart';
import '../../theme/age_band_theme.dart';
import '../../data/scenario_data.dart';
import '../../widgets/hero_creator/scene_widgets.dart';
import '../../widgets/hero_creator/hero_input_widgets.dart';

/// Page 5 of the Hero Creator wizard — scene / setting selection.
///
/// All mutations go directly to [wizardData] (passed by reference).
/// [onChanged] wraps the parent's setState so the page rebuilds with fresh data.
class HeroScenePage extends StatelessWidget {
  const HeroScenePage({
    super.key,
    required this.wizardData,
    required this.imagineItController,
    required this.wishController,
    required this.listeningFor,
    required this.speechAvailable,
    required this.onChanged,
    required this.onContinue,
    required this.onSceneTap,
    required this.onToggleListening,
    required this.onSpeakForSprout,
  });

  final WizardData wizardData;
  final TextEditingController imagineItController;
  final TextEditingController wishController;
  final String listeningFor;
  final bool speechAvailable;
  final VoidCallback onChanged;
  final VoidCallback onContinue;
  final void Function(String id) onSceneTap;
  final void Function(String field) onToggleListening;
  final Future<void> Function(String text) onSpeakForSprout;

  // ── helpers ────────────────────────────────────────────────────────────────

  TextStyle _bandTitleStyle(AgeBandThemeData band, {double baseFontSize = 24}) {
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

  Widget _buildImagineItInput(BuildContext context, AgeBandThemeData band) {
    final isSprout = band.band == AgeBand.sprout;
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
                    isSprout
                        ? 'Where do you want to go? Tell us!'
                        : 'Where will your adventure take place?',
                    style: GoogleFonts.fredoka(
                      color: const Color(0xFFFFD700),
                      fontSize: isSprout ? 18 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (isSprout) ...[
              const SizedBox(height: 6),
              Text(
                speechAvailable
                    ? '🎤 Tap the mic and say it out loud!'
                    : '✍️ Have a grown-up type your idea here.',
                style: GoogleFonts.fredoka(
                  color: Colors.white.withAlpha(220),
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: imagineItController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: isSprout
                          ? 'e.g. under the sea, up in the clouds, a magic forest…'
                          : 'e.g. a floating cloud city, deep inside a volcano, underwater palace…',
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
                      wizardData.customElements = value;
                      wishController.text = value;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: speechAvailable
                      ? 'Speak your setting idea'
                      : 'Mic unavailable',
                  iconSize: isSprout ? 32 : 24,
                  icon: Icon(
                    listeningFor == 'imagine' ? Icons.mic : Icons.mic_none,
                    color: speechAvailable
                        ? (listeningFor == 'imagine'
                            ? Colors.yellow
                            : Colors.white)
                        : Colors.white38,
                  ),
                  onPressed: speechAvailable
                      ? () => onToggleListening('imagine')
                      : null,
                ),
              ],
            ),
            if (!isSprout) ...[
              const SizedBox(height: 6),
              Text(
                speechAvailable
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
          ],
        ),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final age = wizardData.characterAge;
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final placeTitle = band.band == AgeBand.creator
        ? 'Setting'
        : band.band == AgeBand.adventurer
            ? 'Choose your setting'
            : band.band == AgeBand.sprout
                ? 'Where should we go?'
                : 'Where to adventure?';
    final isImagineItSelected = wizardData.selectedScenario == 'safe_space';

    final isCreator = band.band == AgeBand.creator;
    final isAdult = band.band == AgeBand.adult;

    ScenarioCard? scenarioById(String id) {
      try {
        return ScenarioData.all.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }

    String? thematicQuestionFor(String id) {
      final s = scenarioById(id);
      if (isAdult) return s?.adultThematicQuestion;
      if (isCreator) return s?.creatorThematicQuestion;
      return null;
    }

    final featuredButtons = [
      SceneButtonData(
        id: 'vanishing_colors',
        label: scenarioById('vanishing_colors')?.titleForAge(age) ?? 'Vanishing Colors',
        normalAsset: 'assets/images/scenarios/rainbow_land_btn.png',
        pressedAsset: 'assets/images/scenarios/rainbow_land_btn_pressed.png',
        thematicQuestion: thematicQuestionFor('vanishing_colors'),
      ),
      SceneButtonData(
        id: 'crystal_cavern',
        label: scenarioById('crystal_cavern')?.titleForAge(age) ?? 'Crystal Cavern',
        normalAsset: 'assets/images/scenarios/crystal_cave_btn.png',
        pressedAsset: 'assets/images/scenarios/crystal_cave_btn_pressed.png',
        thematicQuestion: thematicQuestionFor('crystal_cavern'),
      ),
      SceneButtonData(
        id: 'volcano_dragons',
        label: scenarioById('volcano_dragons')?.titleForAge(age) ?? 'Volcano Dragons',
        normalAsset: 'assets/images/scenarios/dragon_friends_btn.png',
        pressedAsset: 'assets/images/scenarios/dragon_friends_btn_pressed.png',
        thematicQuestion: thematicQuestionFor('volcano_dragons'),
      ),
      SceneButtonData(
        id: 'big_feelings_quest',
        label: scenarioById('big_feelings_quest')?.titleForAge(age) ?? 'Life Quest',
        normalAsset: 'assets/images/scenarios/my_big_feelings_btn.png',
        pressedAsset: 'assets/images/scenarios/my_big_feelings_btn_pressed.png',
        thematicQuestion: thematicQuestionFor('big_feelings_quest'),
      ),
    ];

    final displayButtons = featuredButtons;

    final labelFontSize =
        band.band == AgeBand.sprout || band.band == AgeBand.explorer
            ? 14.0
            : 12.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            placeTitle,
            textAlign: TextAlign.center,
            style: _bandTitleStyle(band, baseFontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            band.band == AgeBand.sprout
                ? 'Tap a picture to pick where the story goes!'
                : band.band == AgeBand.explorer
                    ? 'Pick a world or make your own!'
                    : band.band == AgeBand.creator
                        ? 'Start from your imagination — or choose a world below'
                        : 'Create your own world — or choose one below!',
            style: GoogleFonts.sourceSans3(color: Colors.white60, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // ── Imagine It spotlight (Creator band: shown FIRST above preset grid) ──
          if (isCreator) ...[
            ImagineItHeroCard(
              isSelected: isImagineItSelected,
              onTap: () {
                wizardData.selectedScenario =
                    isImagineItSelected ? null : 'safe_space';
                if (isImagineItSelected) wizardData.customElements = '';
                onChanged();
              },
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              crossFadeState: isImagineItSelected
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: _buildImagineItInput(context, band),
              secondChild: const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),
          ],

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
                      child: SceneImageButton(
                        data: displayButtons[i],
                        isSelected:
                            wizardData.selectedScenario == displayButtons[i].id,
                        labelFontSize: labelFontSize,
                        showThematicQuestion: isCreator,
                        onTap: () => onSceneTap(displayButtons[i].id),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 360 / 220,
                      child: SceneImageButton(
                        data: displayButtons[i + 1],
                        isSelected: wizardData.selectedScenario ==
                            displayButtons[i + 1].id,
                        labelFontSize: labelFontSize,
                        showThematicQuestion: isCreator,
                        onTap: () => onSceneTap(displayButtons[i + 1].id),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Last item spans full width when count is odd
            AspectRatio(
              aspectRatio: 360 / 110,
              child: SceneImageButton(
                data: displayButtons.last,
                isSelected: wizardData.selectedScenario == displayButtons.last.id,
                labelFontSize: labelFontSize,
                showThematicQuestion: isCreator,
                onTap: () => onSceneTap(displayButtons.last.id),
              ),
            ),
          ] else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 360 / 220,
              children: displayButtons
                  .map((btn) => SceneImageButton(
                        data: btn,
                        isSelected: wizardData.selectedScenario == btn.id,
                        labelFontSize: labelFontSize,
                        showThematicQuestion: isCreator,
                        onTap: () => onSceneTap(btn.id),
                      ))
                  .toList(),
            ),

          const SizedBox(height: 20),

          // ── Make One Up — shown below preset scenes (non-Creator bands only;
          //    Creator band shows it above the grid as a spotlight) ──
          if (!isCreator) ...[
            ImagineItHeroCard(
              isSelected: isImagineItSelected,
              onTap: () {
                wizardData.selectedScenario =
                    isImagineItSelected ? null : 'safe_space';
                if (isImagineItSelected) wizardData.customElements = '';
                onChanged();
                if (band.band == AgeBand.sprout && !isImagineItSelected) {
                  unawaited(onSpeakForSprout('Tap a picture to pick your world!'));
                }
              },
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              crossFadeState: isImagineItSelected
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: _buildImagineItInput(context, band),
              secondChild: const SizedBox.shrink(),
            ),
          ],

          const SizedBox(height: 24),
          PressableArrowButton(
              enabled: true, onTap: onContinue, hint: 'Next: Story Style'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
