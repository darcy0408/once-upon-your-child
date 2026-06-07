import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/age_band_theme.dart';
import '../../widgets/avatar_loading_bands/sprout_egg_hatch.dart';
import '../../widgets/avatar_loading_bands/explorer_constellation.dart';
import '../../widgets/avatar_loading_bands/adventurer_loot_card.dart';
import '../../widgets/avatar_loading_bands/creator_digital_canvas.dart';
import '../../widgets/avatar_loading_bands/adolescent_holographic_portal.dart';
import '../../widgets/avatar_loading_bands/adult_ink_wash.dart';

/// Dev-only scrub harness for the per-age-band avatar loading animations.
///
/// Lets you drag `progress` 0→1 instantly, auto-play/loop the reveal, swap
/// age bands, and toggle reduce-motion — so you can tune an animation without
/// sitting through a real ~65s generation. Reachable at route
/// `/dev/loading-preview`. Not linked from any user-facing UI.
class LoadingPreviewScreen extends StatefulWidget {
  const LoadingPreviewScreen({super.key});

  @override
  State<LoadingPreviewScreen> createState() => _LoadingPreviewScreenState();
}

class _LoadingPreviewScreenState extends State<LoadingPreviewScreen> {
  double _progress = 0.0;
  AgeBand _band = AgeBand.adventurer;
  bool _playing = false;
  bool _reduceMotion = false;
  int _tapCount = 0;

  // Seconds for a full 0→1 sweep when playing. Faster than the real 65s so
  // tuning is quick; bump to 65 to feel true pacing.
  double _sweepSeconds = 12.0;

  Timer? _timer;
  static const _tick = Duration(milliseconds: 50);

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _timer?.cancel();
    if (_playing) {
      _timer = Timer.periodic(_tick, (_) {
        setState(() {
          final step = _tick.inMilliseconds / (_sweepSeconds * 1000);
          _progress += step;
          if (_progress >= 1.0) _progress = 0.0; // loop
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _bandWidget(double stageSize) {
    switch (_band) {
      case AgeBand.sprout:
        return SproutEggHatch(
          stageSize: stageSize,
          progress: _progress,
          onTap: _onTap,
        );
      case AgeBand.explorer:
        return ExplorerConstellation(
          stageSize: stageSize,
          progress: _progress,
          onTap: _onTap,
        );
      case AgeBand.adventurer:
        return AdventurerLootCard(
          stageSize: stageSize,
          progress: _progress,
          onTap: _onTap,
        );
      case AgeBand.creator:
        return CreatorDigitalCanvas(
          stageSize: stageSize,
          progress: _progress,
          onTap: _onTap,
        );
      case AgeBand.adolescent:
        return AdolescentHolographicPortal(
          stageSize: stageSize,
          progress: _progress,
          onTap: _onTap,
        );
      case AgeBand.adult:
        return AdultInkWash(
          stageSize: stageSize,
          progress: _progress,
        );
    }
  }

  void _onTap() => setState(() => _tapCount++);

  @override
  Widget build(BuildContext context) {
    const stageSize = 280.0;
    final bandTheme = themeForBand(_band);

    // Provide the band's AgeBandThemeData extension so the widgets pick up the
    // right palette/fonts, and override reduce-motion via MediaQuery.
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF101018),
      appBar: AppBar(
        title: const Text('Loading Preview (dev)'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // ── Stage ──
            Expanded(
              child: Center(
                child: Theme(
                  data: Theme.of(context).copyWith(extensions: [bandTheme]),
                  child: MediaQuery(
                    data: mq.copyWith(disableAnimations: _reduceMotion),
                    child: SizedBox(
                      width: stageSize,
                      height: stageSize,
                      child: _bandWidget(stageSize),
                    ),
                  ),
                ),
              ),
            ),

            // ── Controls ──
            Container(
              color: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // progress label + scrub slider
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
                        color: Colors.tealAccent,
                        iconSize: 36,
                        onPressed: _togglePlay,
                      ),
                      Expanded(
                        child: Slider(
                          value: _progress.clamp(0.0, 1.0),
                          onChanged: (v) => setState(() {
                            _progress = v;
                            if (_playing) _togglePlay(); // pause on manual scrub
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${(_progress * 100).round()}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),

                  // band selector + toggles
                  Row(
                    children: [
                      const Text('Band:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      DropdownButton<AgeBand>(
                        value: _band,
                        dropdownColor: const Color(0xFF22223A),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (b) {
                          if (b != null) setState(() => _band = b);
                        },
                        items: AgeBand.values
                            .map((b) => DropdownMenuItem(
                                  value: b,
                                  child: Text(b.name),
                                ))
                            .toList(),
                      ),
                      const Spacer(),
                      const Text('Reduce motion',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Switch(
                        value: _reduceMotion,
                        onChanged: (v) => setState(() => _reduceMotion = v),
                      ),
                    ],
                  ),

                  // sweep speed
                  Row(
                    children: [
                      const Text('Sweep:', style: TextStyle(color: Colors.white70)),
                      Expanded(
                        child: Slider(
                          value: _sweepSeconds,
                          min: 3,
                          max: 65,
                          divisions: 62,
                          label: '${_sweepSeconds.round()}s',
                          onChanged: (v) => setState(() => _sweepSeconds = v),
                        ),
                      ),
                      Text('${_sweepSeconds.round()}s  ·  taps:$_tapCount',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
