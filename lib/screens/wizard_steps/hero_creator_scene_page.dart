import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models.dart';
import '../../theme/age_band_theme.dart';
import '../../data/scenario_data.dart';
import '../../widgets/hero_creator/scene_widgets.dart';
import '../../widgets/hero_creator/hero_input_widgets.dart';
import 'imagine_it_screen.dart';

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
    required this.onChanged,
    required this.onContinue,
    required this.onSceneTap,
    required this.onSpeakForSprout,
  });

  final WizardData wizardData;
  final TextEditingController imagineItController;
  final TextEditingController wishController;
  final VoidCallback onChanged;
  final VoidCallback onContinue;
  final void Function(String id) onSceneTap;
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
        normalAsset: 'assets/images/scenarios/rainbow_land_btn.webp',
        pressedAsset: 'assets/images/scenarios/rainbow_land_btn_pressed.webp',
        thematicQuestion: thematicQuestionFor('vanishing_colors'),
      ),
      SceneButtonData(
        id: 'crystal_cavern',
        label: scenarioById('crystal_cavern')?.titleForAge(age) ?? 'Crystal Cavern',
        normalAsset: band.band == AgeBand.sprout
            ? 'assets/images/ui/sprout/tiles/ocean.webp'
            : 'assets/images/scenarios/crystal_cave_btn.webp',
        pressedAsset: band.band == AgeBand.sprout
            ? 'assets/images/ui/sprout/tiles/ocean.webp'
            : 'assets/images/scenarios/crystal_cave_btn_pressed.webp',
        thematicQuestion: thematicQuestionFor('crystal_cavern'),
      ),
      SceneButtonData(
        id: 'volcano_dragons',
        label: scenarioById('volcano_dragons')?.titleForAge(age) ?? 'Volcano Dragons',
        normalAsset: 'assets/images/scenarios/dragon_friends_btn.webp',
        pressedAsset: 'assets/images/scenarios/dragon_friends_btn_pressed.webp',
        thematicQuestion: thematicQuestionFor('volcano_dragons'),
      ),
      // Big Feelings tile is shown for ALL bands. Tapping it opens the cloud
      // picker for younger bands / badge grid for adventurer+, then runs an
      // emotion-focused story. The dedicated My Quests / Big Feelings bottom-
      // nav tab is the *practice* surface (toolbox + standalone quests with
      // coping breaks) — the scene-picker tile is the *story-from-feeling*
      // entry. Different paths, both useful.
      SceneButtonData(
        id: 'big_feelings_quest',
        label: scenarioById('big_feelings_quest')?.titleForAge(age) ?? 'Life Quest',
        normalAsset: 'assets/images/scenarios/my_big_feelings_btn.webp',
        pressedAsset: 'assets/images/scenarios/my_big_feelings_btn_pressed.webp',
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
              onTap: () => _openImagineIt(context),
            ),
            if (isImagineItSelected)
              _ImagineItSelectionPreview(
                description: wizardData.customElements,
                onEdit: () => _openImagineIt(context),
                onClear: () {
                  wizardData.selectedScenario = null;
                  wizardData.customElements = '';
                  imagineItController.clear();
                  wishController.clear();
                  onChanged();
                },
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
              onTap: () => _openImagineIt(context),
            ),
            if (isImagineItSelected)
              _ImagineItSelectionPreview(
                description: wizardData.customElements,
                onEdit: () => _openImagineIt(context),
                onClear: () {
                  wizardData.selectedScenario = null;
                  wizardData.customElements = '';
                  imagineItController.clear();
                  wishController.clear();
                  onChanged();
                },
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

  Future<void> _openImagineIt(BuildContext context) async {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Theme(
          data: Theme.of(context),
          child: ImagineItScreen(
            wizardData: wizardData,
            imagineItController: imagineItController,
            wishController: wishController,
          ),
        ),
      ),
    );
    if (saved == true && band?.band == AgeBand.sprout) {
      unawaited(onSpeakForSprout('Great idea! Tap next when you are ready.'));
    }
    onChanged();
  }
}

/// Compact preview shown in the scene picker once the user has saved an
/// "Imagine It" world. Replaces the old inline form.
class _ImagineItSelectionPreview extends StatelessWidget {
  final String description;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  const _ImagineItSelectionPreview({
    required this.description,
    required this.onEdit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD700);
    final text = description.trim().isEmpty
        ? 'Tap to describe your world'
        : description.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withAlpha(140), width: 1.5),
          color: Colors.white.withAlpha(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('✨', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit, color: gold, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}
