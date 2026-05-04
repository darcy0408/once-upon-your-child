import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/motion_utils.dart';
import 'safe_asset_image.dart';

/// A magical loading view with a central weaving "loom" animation,
/// orbiting sparkles, rotating flavor messages, and layered aura glows.
///
/// For sprout band: shows a bouncing companion + star constellation countdown.
class MagicalLoadingView extends StatefulWidget {
  final String status;
  final VoidCallback? onCancel;
  /// Path to companion image (asset or URL). Shown bouncing for sprout band.
  final String? companionImagePath;
  /// When true, shows the child-friendly star constellation instead of the loom.
  final bool isSproutBand;

  const MagicalLoadingView({
    super.key,
    required this.status,
    this.onCancel,
    this.companionImagePath,
    this.isSproutBand = false,
  });

  @override
  State<MagicalLoadingView> createState() => _MagicalLoadingViewState();
}

class _MagicalLoadingViewState extends State<MagicalLoadingView>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  late final AnimationController _weaveController;
  // Sprout: companion bounce
  AnimationController? _bounceController;
  // Sprout: constellation countdown
  int _starsLit = 0;
  Timer? _constellationTimer;

  final List<_Sparkle> _sparkles = <_Sparkle>[];
  final Random _random = Random();

  int _tapCount = 0;
  final List<Offset> _burstPositions = [];

  // Mini-game: drifting tap-targets that earn points when caught.
  final List<_TapTarget> _tapTargets = [];
  Timer? _targetSpawnTimer;

  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  static const List<String> _phaseMessages = <String>[
    'Your hero is lacing up their boots...',
    'The adventure map is being drawn...',
    'Something magical is about to happen...',
    'Gathering courage and a sprinkle of wonder...',
    'Your world is coming to life...',
    'Writing the first exciting scene...',
    'Adding plot twists and surprises...',
    'Making sure the magic is just right...',
    'Your story is almost ready to tell...',
    'The adventure begins very soon...',
    'Sprinkling in some extra magic...',
  ];

  static const List<String> _adventureSteps = [
    'Entering your world',
    'Finding your hero',
    'Writing the story',
    'Almost ready!',
  ];

  Timer? _messageTimer;
  Timer? _stepTimer;
  int _messageIndex = 0;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _weaveController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });

    // A lightweight particle field: orbit + drift + twinkle.
    for (int i = 0; i < 22; i++) {
      _sparkles.add(
        _Sparkle(
          angle: _random.nextDouble() * 2 * pi,
          distance: 42.0 + _random.nextDouble() * 50.0,
          size: 3.0 + _random.nextDouble() * 7.0,
          speed: 0.5 + _random.nextDouble() * 1.5,
          twinklePhase: _random.nextDouble() * 2 * pi,
          twinkleSpeed: 0.8 + _random.nextDouble() * 2.4,
          driftPhase: _random.nextDouble() * 2 * pi,
          driftSpeed: 0.15 + _random.nextDouble() * 0.9,
        ),
      );
    }

    // Mini-game: spawn drifting tap-targets. Sprout band gets a softer
    // cadence (slower spawn, longer-lived stars) tuned for little fingers.
    final spawnIntervalMs = widget.isSproutBand ? 2800 : 2000;
    final maxTargetsLive = 3;
    final baseTtlMs = widget.isSproutBand ? 4000 : 2400;
    _targetSpawnTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        final now = DateTime.now();
        _tapTargets.removeWhere((t) => t.isExpired);
        final shouldSpawn = _tapTargets.isEmpty ||
            (_tapTargets.length < maxTargetsLive &&
                now.difference(_tapTargets.last.born).inMilliseconds >=
                    spawnIntervalMs);
        if (shouldSpawn) {
          _tapTargets.add(_TapTarget(
            x: 0.1 + _random.nextDouble() * 0.8,
            y: 0.1 + _random.nextDouble() * 0.8,
            born: now,
            ttlMs: baseTtlMs + _random.nextInt(1200),
          ));
        }
      });
    });

    // Rotate flavor messages independent of backend status updates.
    _messageTimer = Timer.periodic(const Duration(milliseconds: 4200), (_) {
      if (!mounted) return;
      setState(
          () => _messageIndex = (_messageIndex + 1) % _phaseMessages.length);
    });

    // Advance progress steps every ~3s (4 steps over ~12s expected wait)
    _stepTimer = Timer.periodic(const Duration(milliseconds: 3100), (_) {
      if (!mounted) return;
      setState(() {
        if (_stepIndex < _adventureSteps.length - 1) _stepIndex++;
      });
    });

    if (widget.isSproutBand) {
      // Companion bounce: continuous hop cycle
      _bounceController = AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      )..repeat(reverse: true);

      // Star constellation: light 1 star every 4s (5 stars over 20s)
      _constellationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        setState(() {
          if (_starsLit < 5) _starsLit++;
        });
      });
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _stepTimer?.cancel();
    _targetSpawnTimer?.cancel();
    _constellationTimer?.cancel();
    _elapsedTimer?.cancel();
    _pulseController.dispose();
    _rotationController.dispose();
    _weaveController.dispose();
    _bounceController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final stageSize = (screenWidth * 0.42).clamp(150.0, 210.0);
    final panelWidth = screenWidth.clamp(280.0, 460.0);
    final reduced = MotionPrefs.reduceMotion(context);
    final particles = MotionPrefs.showParticles(context);
    final intensity = MotionPrefs.sparkleIntensity(context);
    final particleCount = (22 * intensity).round();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: panelWidth),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0E36), // deep navy-purple — matches brand dark
              Color(0xFF2C1B47), // rich purple — brand mid
              Color(0xFF1A0E36),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 26,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.14),
              blurRadius: 34,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isSproutBand) ...[
              _buildSproutLoadingContent(),
            ] else if (reduced) ...[
              // Static fallback for reduced-motion users
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  if (!mounted) return;
                  HapticFeedback.lightImpact();
                  setState(() {
                    _tapCount++;
                    _burstPositions.add(details.localPosition);
                    if (_burstPositions.length > 6) _burstPositions.removeAt(0);
                  });
                },
                child: SizedBox(
                  height: stageSize,
                  width: stageSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Icon(
                              Icons.auto_awesome,
                              size: 36,
                              color: AppColors.primary.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                      ..._burstPositions.map((pos) => Positioned(
                            left: pos.dx - 20,
                            top: pos.dy - 20,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(pos),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 600),
                              builder: (_, t, __) => Opacity(
                                opacity: (1 - t).clamp(0.0, 1.0),
                                child: Container(
                                  width: 40 * (1 + t),
                                  height: 40 * (1 + t),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.gold
                                        .withValues(alpha: 0.4 * (1 - t)),
                                  ),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ] else ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  if (!mounted) return;
                  HapticFeedback.lightImpact();
                  setState(() {
                    _tapCount++;
                    _burstPositions.add(details.localPosition);
                    if (_burstPositions.length > 6) _burstPositions.removeAt(0);
                  });
                  _pulseController.forward(from: 0.0);
                },
                child: SizedBox(
                  height: stageSize,
                  width: stageSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Layered aura (3 gradient layers)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return _AuraHalo(
                            size: stageSize,
                            t: _pulseController.value,
                            primary: AppColors.gold,
                            secondary: AppColors.primary,
                            tertiary: const Color(0xFF80DEEA),
                          );
                        },
                      ),

                      // Rotating magical ring
                      AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          final ringSize = stageSize * 0.80;
                          return Transform.rotate(
                            angle: _rotationController.value * 2 * pi,
                            child: Container(
                              width: ringSize,
                              height: ringSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.28),
                                  width: 2,
                                ),
                                gradient: SweepGradient(
                                  colors: [
                                    AppColors.gold.withValues(alpha: 0.0),
                                    AppColors.gold.withValues(alpha: 0.55),
                                    AppColors.gold.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Central "magic loom" weaving animation
                      AnimatedBuilder(
                        animation: Listenable.merge(
                            [_weaveController, _pulseController]),
                        builder: (context, child) {
                          final loomSize = stageSize * 0.60;
                          final pulse = _pulseController.value;
                          return Transform.scale(
                            scale: 0.98 + (pulse * 0.04),
                            child: CustomPaint(
                              size: Size.square(loomSize),
                              painter: _MagicLoomPainter(
                                phase: _weaveController.value,
                                glow: AppColors.gold,
                                accent: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),

                      // Center sigil
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulse = _pulseController.value;
                          final sigilSize = stageSize * 0.34;
                          return Transform.scale(
                            scale: 1.0 + (pulse * 0.08),
                            child: Container(
                              width: sigilSize,
                              height: sigilSize,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.30 * pulse),
                                    blurRadius: 20 * pulse,
                                    spreadRadius: 5 * pulse,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 36,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),

                      // Orbiting sparkles (respects particle prefs + intensity)
                      if (particles)
                        ..._sparkles.take(particleCount).map((sparkle) {
                          return _AnimatedSparkle(
                            controller: _rotationController,
                            twinkleController: _weaveController,
                            sparkle: sparkle,
                          );
                        }),

                      // Mini-game: drifting tap targets
                      ..._tapTargets.where((t) => !t.isExpired).map((target) {
                        final age = target.ageMs;
                        final ttl = target.ttlMs;
                        // Fade in over 300ms, fade out over last 400ms
                        final opacity = age < 300
                            ? (age / 300.0).clamp(0.0, 1.0)
                            : age > ttl - 400
                                ? ((ttl - age) / 400.0).clamp(0.0, 1.0)
                                : 1.0;
                        return Positioned(
                          left: target.x * stageSize - 22,
                          top: target.y * stageSize - 22,
                          child: GestureDetector(
                            onTap: () {
                              if (!mounted) return;
                              setState(() {
                                _tapTargets.remove(target);
                                _tapCount++;
                                _burstPositions.add(Offset(
                                  target.x * stageSize,
                                  target.y * stageSize,
                                ));
                                if (_burstPositions.length > 6) {
                                  _burstPositions.removeAt(0);
                                }
                              });
                            },
                            child: Opacity(
                              opacity: opacity,
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(target.born),
                                tween: Tween(begin: 0.8, end: 1.2),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeInOut,
                                builder: (_, scale, __) => Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.gold
                                          .withValues(alpha: 0.18),
                                      border: Border.all(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.75),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.gold
                                              .withValues(alpha: 0.45),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.auto_awesome,
                                        color: AppColors.gold,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      // Tap burst overlays
                      ..._burstPositions.map((pos) => Positioned(
                            left: pos.dx - 20,
                            top: pos.dy - 20,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(pos),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 600),
                              builder: (_, t, __) => Opacity(
                                opacity: (1 - t).clamp(0.0, 1.0),
                                child: Container(
                                  width: 40 * (1 + t),
                                  height: 40 * (1 + t),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.gold
                                        .withValues(alpha: 0.4 * (1 - t)),
                                  ),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Quicksand',
                  ),
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              opacity: _elapsedSeconds >= 10 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 600),
              child: Text(
                _elapsedSeconds >= 90
                    ? 'Taking a little longer than usual — almost there! ✨'
                    : '${_elapsedSeconds}s',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _elapsedSeconds >= 90 ? 12 : 11,
                  color: _elapsedSeconds >= 90
                      ? AppColors.gold
                      : Colors.white38,
                  fontStyle: _elapsedSeconds >= 90
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.36),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.58),
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
                    _phaseMessages[_messageIndex],
                    key: ValueKey<int>(_messageIndex),
                    textAlign: TextAlign.center,
                    softWrap: true,
                    maxLines: 3,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
            // ── Adventure progress steps ──────────────────────────────────
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: List.generate(_adventureSteps.length, (i) {
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
                            ? AppColors.gold
                            : Colors.white.withValues(alpha: 0.3),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.7),
                                    blurRadius: 8)
                              ]
                            : [],
                      ),
                      child: done
                          ? const Icon(Icons.check,
                              size: 8, color: Colors.black)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _adventureSteps[i],
                      style: TextStyle(
                        fontSize: 9,
                        color: active
                            ? AppColors.gold
                            : done
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.35),
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
            if (_tapCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _tapCount == 1
                        ? '✨ 1 sparkle!'
                        : _tapCount < 5
                            ? '✨ $_tapCount sparkles!'
                            : _tapCount < 10
                                ? '🌟 $_tapCount sparkles! Keep going!'
                                : _tapCount < 20
                                    ? '💫 $_tapCount sparkles! You\'re magic!'
                                    : '🌈 $_tapCount sparkles! You ARE the magic!',
                    key: ValueKey(_tapCount),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (_tapCount == 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.isSproutBand
                      ? 'Tap the stars! 🌟'
                      : 'Catch the sparkles! ✨',
                  style: TextStyle(color: Colors.purple.shade300, fontSize: 12),
                ),
              ),
            if (widget.onCancel != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Sprout-specific loading UI: bouncing companion centered on a tappable
  /// star-catcher stage, with the 5-star constellation countdown below.
  Widget _buildSproutLoadingContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final stageSize = (screenWidth * 0.62).clamp(220.0, 280.0);
    const targetSize = 60.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (!mounted) return;
            HapticFeedback.lightImpact();
            setState(() {
              _tapCount++;
              _burstPositions.add(details.localPosition);
              if (_burstPositions.length > 6) _burstPositions.removeAt(0);
            });
          },
          child: SizedBox(
            height: stageSize,
            width: stageSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Bouncing companion — centerpiece of the stage
                if (_bounceController != null)
                  AnimatedBuilder(
                    animation: _bounceController!,
                    builder: (context, _) {
                      final hop = -18.0 * _bounceController!.value;
                      return Transform.translate(
                        offset: Offset(0, hop),
                        child: ClipOval(
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: widget.companionImagePath != null
                                ? _loadCompanionImage(
                                    widget.companionImagePath!)
                                : const ColoredBox(
                                    color: Color(0xFF3A1060),
                                    child: Icon(Icons.auto_awesome,
                                        size: 64, color: Color(0xFF9E6CFF)),
                                  ),
                          ),
                        ),
                      );
                    },
                  )
                else
                  const Icon(Icons.auto_awesome,
                      size: 64, color: Color(0xFF9E6CFF)),

                // Drifting tap targets — bigger and brighter for little fingers
                ..._tapTargets.where((t) => !t.isExpired).map((target) {
                  final age = target.ageMs;
                  final ttl = target.ttlMs;
                  final opacity = age < 300
                      ? (age / 300.0).clamp(0.0, 1.0)
                      : age > ttl - 400
                          ? ((ttl - age) / 400.0).clamp(0.0, 1.0)
                          : 1.0;
                  return Positioned(
                    left: target.x * stageSize - targetSize / 2,
                    top: target.y * stageSize - targetSize / 2,
                    child: GestureDetector(
                      onTap: () {
                        if (!mounted) return;
                        HapticFeedback.lightImpact();
                        setState(() {
                          _tapTargets.remove(target);
                          _tapCount++;
                          _burstPositions.add(Offset(
                            target.x * stageSize,
                            target.y * stageSize,
                          ));
                          if (_burstPositions.length > 6) {
                            _burstPositions.removeAt(0);
                          }
                        });
                      },
                      child: Opacity(
                        opacity: opacity,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(target.born),
                          tween: Tween(begin: 0.85, end: 1.15),
                          duration: const Duration(milliseconds: 850),
                          curve: Curves.easeInOut,
                          builder: (_, scale, __) => Transform.scale(
                            scale: scale,
                            child: Container(
                              width: targetSize,
                              height: targetSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    AppColors.gold.withValues(alpha: 0.20),
                                border: Border.all(
                                  color:
                                      AppColors.gold.withValues(alpha: 0.85),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.gold
                                        .withValues(alpha: 0.5),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.star_rounded,
                                  color: AppColors.gold,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Tap burst overlays — feedback for both free-form taps and
                // successful star catches.
                ..._burstPositions.map((pos) => Positioned(
                      left: pos.dx - 25,
                      top: pos.dy - 25,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(pos),
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        builder: (_, t, __) => Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: Container(
                            width: 50 * (1 + t),
                            height: 50 * (1 + t),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.gold
                                  .withValues(alpha: 0.45 * (1 - t)),
                            ),
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 5-star constellation countdown
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final isLit = i < _starsLit;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Icon(
                  isLit ? Icons.star_rounded : Icons.star_outline_rounded,
                  key: ValueKey(isLit),
                  size: 36,
                  color: isLit
                      ? const Color(0xFFFFD700)
                      : const Color(0xFFB0A0CC),
                  shadows: isLit
                      ? [
                          const Shadow(
                            color: Color(0xFFFFD700),
                            blurRadius: 12,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _loadCompanionImage(String path) {
    if (path.startsWith('assets/')) {
      return SafeAssetImage(path,
          fit: BoxFit.cover,
          placeholder: const Icon(Icons.auto_awesome, size: 64, color: Color(0xFF9E6CFF)));
    }
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.auto_awesome, size: 64, color: Color(0xFF9E6CFF)));
    }
    return const Icon(Icons.auto_awesome, size: 64, color: Color(0xFF9E6CFF));
  }
}

class _Sparkle {
  final double angle;
  final double distance;
  final double size;
  final double speed;
  final double twinklePhase;
  final double twinkleSpeed;
  final double driftPhase;
  final double driftSpeed;

  _Sparkle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
    required this.twinklePhase,
    required this.twinkleSpeed,
    required this.driftPhase,
    required this.driftSpeed,
  });
}

class _AnimatedSparkle extends StatelessWidget {
  final AnimationController controller;
  final AnimationController twinkleController;
  final _Sparkle sparkle;

  const _AnimatedSparkle({
    required this.controller,
    required this.twinkleController,
    required this.sparkle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, twinkleController]),
      builder: (context, child) {
        final orbitAngle =
            sparkle.angle + (controller.value * 2 * pi * sparkle.speed);
        final drift = 1.0 +
            (0.07 *
                sin((controller.value * 2 * pi * sparkle.driftSpeed) +
                    sparkle.driftPhase));
        final dx = cos(orbitAngle) * sparkle.distance * drift;
        final dy = sin(orbitAngle) * sparkle.distance * drift;

        final tw = 0.5 +
            0.5 *
                sin((twinkleController.value * 2 * pi * sparkle.twinkleSpeed) +
                    sparkle.twinklePhase);
        final opacity = (0.18 + (0.82 * tw)).clamp(0.0, 1.0);
        final s = sparkle.size * (0.80 + (0.45 * tw));

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: opacity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: AppColors.gold.withValues(alpha: 0.45),
                  size: s * 1.55,
                ),
                Icon(
                  Icons.star_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: s,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuraHalo extends StatelessWidget {
  final double size;
  final double t;
  final Color primary;
  final Color secondary;
  final Color tertiary;

  const _AuraHalo({
    required this.size,
    required this.t,
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  @override
  Widget build(BuildContext context) {
    final s1 = size * (0.95 + (0.04 * t));
    final s2 = size * (0.78 + (0.03 * (1 - t)));
    final s3 = size * (0.62 + (0.02 * t));

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: s1,
          height: s1,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                tertiary.withValues(alpha: 0.0),
                tertiary.withValues(alpha: 0.10 + (0.06 * t)),
                Colors.transparent,
              ],
              stops: const [0.0, 0.65, 1.0],
            ),
          ),
        ),
        Container(
          width: s2,
          height: s2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                secondary.withValues(alpha: 0.12 + (0.06 * t)),
                primary.withValues(alpha: 0.10 + (0.08 * t)),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Container(
          width: s3,
          height: s3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                primary.withValues(alpha: 0.16 + (0.08 * t)),
                Colors.white.withValues(alpha: 0.06 + (0.04 * t)),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _MagicLoomPainter extends CustomPainter {
  final double phase; // 0..1
  final Color glow;
  final Color accent;

  _MagicLoomPainter({
    required this.phase,
    required this.glow,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.46;

    // Soft glow backplate
    final back = Paint()
      ..color = glow.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, r * 0.92, back);

    // Loom frame ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.05).clamp(3.0, 7.0)
      ..shader = SweepGradient(
        colors: [
          glow.withValues(alpha: 0.0),
          glow.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.25),
          glow.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 0.65, 1.0],
        transform: GradientRotation(phase * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, ring);

    // Warp threads (vertical)
    final warpPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (size.width * 0.012).clamp(1.0, 2.4)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.0),
          accent.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.25),
          accent.withValues(alpha: 0.25),
          accent.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.18, 0.5, 0.82, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));

    final left = center.dx - (r * 0.72);
    final right = center.dx + (r * 0.72);
    final top = center.dy - (r * 0.70);
    final bottom = center.dy + (r * 0.70);

    const threadCount = 9;
    for (int i = 0; i < threadCount; i++) {
      final x = left + (i / (threadCount - 1)) * (right - left);
      final wobble = 1.0 + 0.03 * sin((phase * 2 * pi) + i * 0.7);
      canvas.drawLine(Offset(x, top), Offset(x, bottom * wobble), warpPaint);
    }

    // Weft thread (horizontal wave moving downward)
    final weftY = top + (phase * (bottom - top));
    final weft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (size.width * 0.020).clamp(1.4, 3.2)
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          glow.withValues(alpha: 0.0),
          glow.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.5),
          glow.withValues(alpha: 0.65),
          glow.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(left, weftY - 20, right - left, 40));

    final path = Path();
    const segments = 18;
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = left + t * (right - left);
      final wave = sin((t * 2 * pi * 2) + (phase * 2 * pi * 1.3)) * (r * 0.08);
      final y = weftY + wave;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, weft);

    // Small glints on the ring
    final glint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;
    final a1 = (phase * 2 * pi);
    final a2 = a1 + pi * 0.78;
    canvas.drawCircle(center + Offset(cos(a1), sin(a1)) * r,
        (size.width * 0.02).clamp(1.2, 3.0), glint);
    canvas.drawCircle(center + Offset(cos(a2), sin(a2)) * r,
        (size.width * 0.015).clamp(1.0, 2.6), glint);
  }

  @override
  bool shouldRepaint(covariant _MagicLoomPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.glow != glow ||
        oldDelegate.accent != accent;
  }
}

/// A drifting sparkle target that the user can tap to earn points.
/// Position is expressed as fractions of the stage area (0..1).
class _TapTarget {
  final double x;
  final double y;
  final DateTime born;
  final int ttlMs; // How long before auto-expiry (ms)

  _TapTarget({
    required this.x,
    required this.y,
    required this.born,
    required this.ttlMs,
  });

  int get ageMs => DateTime.now().difference(born).inMilliseconds;
  bool get isExpired => ageMs >= ttlMs;
}
