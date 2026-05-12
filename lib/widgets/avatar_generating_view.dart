import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/age_band_theme.dart';
import '../theme/app_theme.dart';
import 'avatar_loading_bands/sprout_egg_hatch.dart';
import 'avatar_loading_bands/explorer_constellation.dart';
import 'avatar_loading_bands/adventurer_treasure_map.dart';
import 'avatar_loading_bands/creator_digital_canvas.dart';
import 'avatar_loading_bands/adolescent_holographic_portal.dart';
import 'avatar_loading_bands/adult_ink_wash.dart';

/// Age-band-specific loading animation shown during avatar generation (~60s).
///
/// Delegates the central animation to a band-specific child widget while
/// providing shared chrome: progress steps, rotating messages, cancel button.
class AvatarGeneratingView extends StatefulWidget {
  final AgeBand ageBand;
  final String status;
  final VoidCallback onCancel;
  final String? companionImagePath;

  const AvatarGeneratingView({
    super.key,
    required this.ageBand,
    required this.status,
    required this.onCancel,
    this.companionImagePath,
  });

  @override
  State<AvatarGeneratingView> createState() => _AvatarGeneratingViewState();
}

class _AvatarGeneratingViewState extends State<AvatarGeneratingView> {
  int _messageIndex = 0;
  int _stepIndex = 0;
  int _tapCount = 0;
  Timer? _messageTimer;
  Timer? _stepTimer;

  // Progress value driven by timer (0.0 → 1.0 over ~60s)
  double _progress = 0.0;
  Timer? _progressTimer;

  static const _stepInterval = Duration(seconds: 15);
  static const _messageInterval = Duration(milliseconds: 5000);

  // ── Per-band step labels ─────────────────────────────────────────────────
  static const Map<AgeBand, List<String>> _stepLabels = {
    AgeBand.sprout: [
      'Getting ready',
      'Drawing you',
      'Adding colors',
      'Almost done!',
    ],
    AgeBand.explorer: [
      'Preparing the spell',
      'Painting your hero',
      'Adding sparkles',
      'Almost ready!',
    ],
    AgeBand.adventurer: [
      'Analyzing reference',
      'Sketching character',
      'Rendering details',
      'Finalizing',
    ],
    AgeBand.creator: [
      'Processing',
      'Generating',
      'Refining',
      'Finishing',
    ],
    AgeBand.adolescent: [
      'Processing',
      'Generating',
      'Refining',
      'Finishing',
    ],
    AgeBand.adult: [
      'Processing',
      'Generating',
      'Refining',
      'Finishing',
    ],
  };

  // ── Per-band flavor messages ─────────────────────────────────────────────
  static const Map<AgeBand, List<String>> _flavorMessages = {
    AgeBand.sprout: [
      'Tap the egg to help it hatch!',
      'Egg-cellent! Something magical is inside...',
      'Yolks! Your hero is almost ready!',
      'Shhh... the egg is wiggling!',
      'Crack, crack, crack — keep tapping!',
      'This egg is egg-stra special!',
      'What\'s inside? A surprise hero!',
      'Sunny side up — almost hatched!',
      'Don\'t be a chicken, give it a tap!',
      'Egg-straordinary things take time...',
      'Shell we keep going? Yes!',
      'The egg says: tap me some more!',
    ],
    AgeBand.explorer: [
      'Casting the avatar spell...',
      'The magic paintbrush is working...',
      'Mixing enchanted colors...',
      'Your hero is taking shape...',
      'Sprinkling in sparkle dust...',
      'Weaving star-thread magic...',
      'The constellation is forming...',
      'Almost ready to shine!',
    ],
    AgeBand.adventurer: [
      'Charting the course...',
      'The ink is flowing...',
      'Marking the landmarks...',
      'Your avatar is materializing...',
      'Fine-tuning the details...',
      'Mapping the final features...',
      'The quest nears its end...',
      'X marks the spot!',
    ],
    AgeBand.creator: [
      'Processing your design...',
      'Applying style transfer...',
      'Rendering at full resolution...',
      'Optimizing the output...',
      'Composing the final piece...',
      'Refining edge detail...',
      'Nearly rendered...',
      'Applying finishing passes...',
    ],
    AgeBand.adolescent: [
      'Generating...',
      'Rendering your character...',
      'Processing details...',
      'Almost there...',
      'Compiling output...',
      'Resolving final layers...',
    ],
    AgeBand.adult: [
      'Creating your avatar...',
      'Rendering...',
      'Applying finishing touches...',
      'Nearly complete...',
      'Refining the portrait...',
      'Final brush strokes...',
    ],
  };

  List<String> get _steps =>
      _stepLabels[widget.ageBand] ?? _stepLabels[AgeBand.adult]!;
  List<String> get _messages =>
      _flavorMessages[widget.ageBand] ?? _flavorMessages[AgeBand.adult]!;

  @override
  void initState() {
    super.initState();

    _messageTimer = Timer.periodic(_messageInterval, (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
    });

    _stepTimer = Timer.periodic(_stepInterval, (_) {
      if (!mounted) return;
      setState(() {
        if (_stepIndex < _steps.length - 1) _stepIndex++;
      });
    });

    // Smooth progress: update every 500ms over ~65s
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {
        _progress = (_progress + 0.5 / 65.0).clamp(0.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _stepTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _onBandTap() {
    setState(() => _tapCount++);
  }

  String _tapCounterText() {
    if (widget.ageBand == AgeBand.sprout) {
      if (_tapCount == 1) return '1 crack!';
      if (_tapCount < 5) return '$_tapCount cracks!';
      if (_tapCount < 10) return '$_tapCount cracks! Keep tapping!';
      if (_tapCount < 20) return '$_tapCount cracks! Almost hatched!';
      return '$_tapCount cracks! Egg-stra magic!';
    }
    if (_tapCount == 1) return '1 sparkle!';
    if (_tapCount < 5) return '$_tapCount sparkles!';
    if (_tapCount < 10) return '$_tapCount sparkles! Keep going!';
    if (_tapCount < 20) return '$_tapCount sparkles! You\'re magic!';
    return '$_tapCount sparkles! You ARE the magic!';
  }

  @override
  Widget build(BuildContext context) {
    final bt = Theme.of(context).extension<AgeBandThemeData>() ??
        themeForBand(widget.ageBand);
    final screenWidth = MediaQuery.of(context).size.width;
    final stageSize = (screenWidth * 0.50).clamp(180.0, 280.0);
    final panelWidth = screenWidth.clamp(280.0, 460.0);
    final isYoung = widget.ageBand == AgeBand.sprout ||
        widget.ageBand == AgeBand.explorer ||
        widget.ageBand == AgeBand.adventurer;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: panelWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Central animation area ───────────────────────────────
              Semantics(
                label:
                    'Avatar generation in progress. Step ${_stepIndex + 1} of ${_steps.length}: ${_steps[_stepIndex]}',
                liveRegion: true,
                child: SizedBox(
                  width: stageSize,
                  height: stageSize,
                  child: _buildBandAnimation(bt, stageSize),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Status text ─────────────────────────────────────────
              Text(
                widget.status,
                textAlign: TextAlign.center,
                style: GoogleFonts.getFont(
                  bt.uiFontFamily,
                  color: bt.accent,
                  fontSize: 20 * bt.headingScale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Flavor message panel ────────────────────────────────
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: bt.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(bt.cardRadiusBase),
                  border: Border.all(
                    color: bt.accent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 650),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: Center(
                    child: Text(
                      _messages[_messageIndex],
                      key: ValueKey<int>(_messageIndex),
                      textAlign: TextAlign.center,
                      softWrap: true,
                      maxLines: 3,
                      style: GoogleFonts.getFont(
                        bt.uiFontFamily,
                        color: bt.textOnDark.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        fontSize: 14 * bt.bodyScale,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Progress steps ──────────────────────────────────────
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: List.generate(_steps.length, (i) {
                  final done = i < _stepIndex;
                  final active = i == _stepIndex;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: active ? 14 : 10,
                        height: active ? 14 : 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done || active
                              ? bt.accent
                              : bt.textOnDark.withValues(alpha: 0.3),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: bt.accent.withValues(alpha: 0.7),
                                    blurRadius: 8,
                                  )
                                ]
                              : [],
                        ),
                        child: done
                            ? Icon(Icons.check,
                                size: 8,
                                color: bt.preferDarkMode
                                    ? Colors.black
                                    : Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _steps[i],
                        style: GoogleFonts.getFont(
                          bt.uiFontFamily,
                          fontSize: 9 * bt.bodyScale,
                          color: active
                              ? bt.accent
                              : done
                                  ? bt.textOnDark.withValues(alpha: 0.7)
                                  : bt.textOnDark.withValues(alpha: 0.35),
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }),
              ),

              // ── Tap counter (young bands only) ─────────────────────
              if (isYoung && _tapCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _tapCounterText(),
                      key: ValueKey(_tapCount),
                      style: GoogleFonts.getFont(
                        bt.uiFontFamily,
                        color: bt.accent,
                        fontSize: 13 * bt.bodyScale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // ── Cancel button ───────────────────────────────────────
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: widget.onCancel,
                child: Text(
                  (widget.ageBand == AgeBand.sprout ||
                          widget.ageBand == AgeBand.explorer)
                      ? 'Go Back'
                      : 'Cancel',
                  style: GoogleFonts.getFont(
                    bt.uiFontFamily,
                    color: bt.textOnDark.withValues(alpha: 0.6),
                    fontSize: 14 * bt.bodyScale,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBandAnimation(AgeBandThemeData bt, double stageSize) {
    switch (widget.ageBand) {
      case AgeBand.sprout:
        return SproutEggHatch(
          stageSize: stageSize,
          progress: _progress,
          onTap: _onBandTap,
          companionImagePath: widget.companionImagePath,
        );
      case AgeBand.explorer:
        return ExplorerConstellation(
          stageSize: stageSize,
          progress: _progress,
          onTap: _onBandTap,
        );
      case AgeBand.adventurer:
        return AdventurerTreasureMap(
          stageSize: stageSize,
          progress: _progress,
          onTap: _onBandTap,
        );
      case AgeBand.creator:
        return CreatorDigitalCanvas(
          stageSize: stageSize,
          progress: _progress,
          onTap: _onBandTap,
        );
      case AgeBand.adolescent:
        return AdolescentHolographicPortal(
          stageSize: stageSize,
          progress: _progress,
          onTap: _onBandTap,
        );
      case AgeBand.adult:
        return AdultInkWash(
          stageSize: stageSize,
          progress: _progress,
        );
    }
  }
}
