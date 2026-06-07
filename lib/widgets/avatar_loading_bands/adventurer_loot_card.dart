import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/age_band_theme.dart';
import '../../utils/motion_utils.dart';

/// Adventurer (9-12) avatar loading: a "Mythic Card Forge".
///
/// A cosmic loot-crate charges as energy implodes inward (0.0–0.6), bursts
/// with a shockwave (~0.6), then a holographic hero stat-card rises and
/// assembles — HUD art window with a "rendering" silhouette, a rarity badge
/// that locks to LEGENDARY, and stat bars that fill (0.72–1.0).
///
/// Replaces the warm parchment treasure map, which clashed with the band's
/// cool cosmic indigo/teal palette. Speaks loot-box + collectible-card culture
/// this age loves, and turns the ~65s wait into a reward reveal.
class AdventurerLootCard extends StatefulWidget {
  final double stageSize;
  final double progress;
  final VoidCallback onTap;

  const AdventurerLootCard({
    super.key,
    required this.stageSize,
    required this.progress,
    required this.onTap,
  });

  @override
  State<AdventurerLootCard> createState() => _AdventurerLootCardState();
}

// ── Phase thresholds (in terms of `progress`) ──────────────────────────────
const double _kBurstStart = 0.60; // crate cracks / shockwave begins
const double _kCardStart = 0.72; // card begins to rise & assemble

// ── Rarity tiers ───────────────────────────────────────────────────────────
class _Tier {
  final String label;
  final Color color;
  final Color glow;
  const _Tier(this.label, this.color, this.glow);
}

const List<_Tier> _tiers = [
  _Tier('COMMON', Color(0xFFB0BEC5), Color(0xFFCFD8DC)), // slate
  _Tier('RARE', Color(0xFF42A5F5), Color(0xFF82B1FF)), // blue
  _Tier('EPIC', Color(0xFFAB47BC), Color(0xFFCE93D8)), // purple
  _Tier('LEGENDARY', Color(0xFFFFD54F), Color(0xFFFFE082)), // gold
];

// Decorative "forged" stats — not real data; they fill for flavour.
const List<(String, double)> _stats = [
  ('BRAVERY', 0.92),
  ('IMAGINATION', 1.00),
  ('KINDNESS', 0.80),
  ('WITS', 0.86),
];

class _Particle {
  Offset pos;
  Offset vel;
  double life;
  double size;
  double angle;
  double orbit; // starting radius for implosion respawn
  _Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.size,
    required this.angle,
    required this.orbit,
  });
}

class _AdventurerLootCardState extends State<AdventurerLootCard>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl; // crate charge throb
  late final AnimationController _shimmerCtrl; // holo sweep / scan line
  late final AnimationController _particleCtrl; // energy embers tick
  late final AnimationController _tapGlintCtrl; // ring on tap

  final List<_Particle> _particles = [];
  final Random _rng = Random();

  bool _burstKicked = false;

  static const int _particleCount = 22;

  // Fixed star field so the cosmic background doesn't shimmer randomly.
  static const List<Offset> _stars = [
    Offset(0.12, 0.16), Offset(0.28, 0.09), Offset(0.46, 0.20),
    Offset(0.68, 0.12), Offset(0.84, 0.24), Offset(0.91, 0.46),
    Offset(0.08, 0.40), Offset(0.18, 0.62), Offset(0.10, 0.82),
    Offset(0.30, 0.90), Offset(0.52, 0.86), Offset(0.74, 0.92),
    Offset(0.88, 0.74), Offset(0.94, 0.60), Offset(0.40, 0.06),
    Offset(0.60, 0.04),
  ];

  @override
  void initState() {
    super.initState();

    _pulseCtrl =
        AnimationController(duration: const Duration(milliseconds: 1300), vsync: this);
    _shimmerCtrl =
        AnimationController(duration: const Duration(milliseconds: 2200), vsync: this);
    _particleCtrl =
        AnimationController(duration: const Duration(milliseconds: 80), vsync: this)
          ..addListener(_tickParticles);
    _tapGlintCtrl =
        AnimationController(duration: const Duration(milliseconds: 420), vsync: this);

    for (int i = 0; i < _particleCount; i++) {
      final ang = _rng.nextDouble() * 2 * pi;
      final orbit = 0.30 + _rng.nextDouble() * 0.22; // fraction of stage
      _particles.add(_Particle(
        pos: Offset(cos(ang) * orbit, sin(ang) * orbit),
        vel: Offset.zero,
        life: 0.4 + _rng.nextDouble() * 0.6,
        size: 2.0 + _rng.nextDouble() * 3.0,
        angle: ang,
        orbit: orbit,
      ));
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _particleCtrl.dispose();
    _tapGlintCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPrefs.reduceMotion(context)) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0.5;
      _shimmerCtrl.stop();
      _shimmerCtrl.value = 0.0;
      _particleCtrl.stop();
      _particleCtrl.value = 0.0;
    } else {
      if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
      if (!_shimmerCtrl.isAnimating) _shimmerCtrl.repeat();
      if (!_particleCtrl.isAnimating) _particleCtrl.repeat();
    }
  }

  void _tickParticles() {
    if (!mounted) return;
    final s = widget.stageSize;
    final exploded = widget.progress >= _kBurstStart;

    // One-time outward kick at the burst moment.
    if (exploded && !_burstKicked) {
      _burstKicked = true;
      for (final p in _particles) {
        final dir = p.pos == Offset.zero
            ? Offset(cos(p.angle), sin(p.angle))
            : (p.pos / p.pos.distance);
        p.vel = dir * (3.5 + _rng.nextDouble() * 3.0);
        p.life = 1.0;
      }
    }

    setState(() {
      for (final p in _particles) {
        if (!exploded) {
          // Implosion: drift inward toward the crate, respawn at the rim.
          final toCenter = Offset.zero - p.pos; // local coords (center origin)
          final dist = toCenter.distance;
          if (dist < 0.04 * s || p.life <= 0.0) {
            final ang = _rng.nextDouble() * 2 * pi;
            p.angle = ang;
            p.pos = Offset(cos(ang) * p.orbit * s, sin(ang) * p.orbit * s);
            p.life = 0.5 + _rng.nextDouble() * 0.5;
            p.size = 2.0 + _rng.nextDouble() * 3.0;
          } else {
            final step = toCenter / dist * (1.4 + (1.0 - dist / (0.5 * s)) * 2.2);
            p.pos += step;
            p.life -= 0.012;
          }
        } else {
          // Drift / settle after the burst, gentle upward rise around the card.
          p.pos += p.vel;
          p.vel = Offset(p.vel.dx * 0.92, p.vel.dy * 0.92 - 0.04);
          p.life -= 0.02;
          if (p.life <= 0.0) {
            // Re-emit faint embers rising from the card.
            p.pos = Offset((_rng.nextDouble() - 0.5) * 0.42 * s,
                0.30 * s + _rng.nextDouble() * 0.1 * s);
            p.vel = Offset((_rng.nextDouble() - 0.5) * 0.6, -0.6 - _rng.nextDouble());
            p.life = 0.5 + _rng.nextDouble() * 0.5;
            p.size = 1.6 + _rng.nextDouble() * 2.4;
          }
        }
      }
    });
  }

  void _onTap() {
    HapticFeedback.mediumImpact();
    widget.onTap();
    _tapGlintCtrl.forward(from: 0.0);
    // A small charge kick: nudge a few embers inward faster.
    if (widget.progress < _kBurstStart) {
      for (int i = 0; i < 4; i++) {
        final p = _particles[_rng.nextInt(_particles.length)];
        p.life = 1.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MotionPrefs.reduceMotion(context);
    final bt = Theme.of(context).extension<AgeBandThemeData>() ??
        themeForBand(AgeBand.adventurer);
    final size = widget.stageSize;

    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onTap(),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: reduced
                    ? const AlwaysStoppedAnimation(0.0)
                    : Listenable.merge([_pulseCtrl, _shimmerCtrl, _tapGlintCtrl]),
                builder: (_, __) {
                  return CustomPaint(
                    painter: _LootCardPainter(
                      progress: widget.progress,
                      pulse: reduced ? 0.5 : _pulseCtrl.value,
                      shimmer: reduced ? 0.0 : _shimmerCtrl.value,
                      tapGlint: reduced ? 0.0 : _tapGlintCtrl.value,
                      accent: bt.accent, // teal
                      primary: bt.primary, // indigo
                      reduceMotion: reduced,
                    ),
                  );
                },
              ),
            ),
            if (!reduced)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _EmberPainter(
                      particles: _particles,
                      origin: Offset(size / 2, size / 2),
                      color: _tierFor(widget.progress).glow,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// During the "roll", flicker tiers; lock to LEGENDARY once burst begins.
_Tier _tierFor(double progress) {
  if (progress >= _kBurstStart) return _tiers[3];
  // Stepped roll that climbs with progress.
  final idx = (progress / _kBurstStart * 3).clamp(0, 3).floor();
  return _tiers[idx];
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _LootCardPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final double shimmer;
  final double tapGlint;
  final Color accent;
  final Color primary;
  final bool reduceMotion;

  _LootCardPainter({
    required this.progress,
    required this.pulse,
    required this.shimmer,
    required this.tapGlint,
    required this.accent,
    required this.primary,
    required this.reduceMotion,
  });

  double get _chargeT => (progress / _kBurstStart).clamp(0.0, 1.0);
  double get _burstT =>
      ((progress - _kBurstStart) / 0.16).clamp(0.0, 1.0);
  double get _cardT => ((progress - _kCardStart) / (1.0 - _kCardStart)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    final crateAlpha = (1.0 - _cardT * 1.4).clamp(0.0, 1.0);
    if (crateAlpha > 0.0) _drawCrate(canvas, size, crateAlpha);
    if (_burstT > 0.0 && _cardT < 1.0) _drawShockwave(canvas, size);
    if (_cardT > 0.0) _drawCard(canvas, size);
    // "LEGENDARY!" pop rides over the burst and fades as the card takes over.
    if (_burstT > 0.0 && _cardT < 0.55) _drawRarityPop(canvas, size);
    _drawVignette(canvas, size);
  }

  // ── Cosmic background ──────────────────────────────────────────────────
  void _drawBackground(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.0, -0.1),
          radius: 1.25,
          colors: [
            Color(0xFF1A1A4E), // dark indigo centre
            Color(0xFF12123A),
            Color(0xFF0D0D2B), // near-black navy edges
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Star field — twinkle tied to shimmer phase.
    for (int i = 0; i < _AdventurerLootCardState._stars.length; i++) {
      final st = _AdventurerLootCardState._stars[i];
      final tw = reduceMotion
          ? 0.5
          : (0.4 + 0.6 * (0.5 + 0.5 * sin((shimmer * 2 * pi) + i)));
      canvas.drawCircle(
        Offset(st.dx * size.width, st.dy * size.height),
        1.1 + (i % 3) * 0.5,
        Paint()..color = Colors.white.withValues(alpha: 0.10 + tw * 0.22),
      );
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = accent.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ── Loot crate (charging → cracking) ───────────────────────────────────
  void _drawCrate(Canvas canvas, Size size, double alpha) {
    final c = Offset(size.width / 2, size.height / 2);
    final tier = _tierFor(progress);
    final r = size.width * 0.16;
    final throb = reduceMotion ? 0.0 : (pulse - 0.5) * 2; // -1..1
    final charge = _chargeT;

    canvas.save();
    canvas.translate(c.dx, c.dy);

    // Charge halo — grows & brightens with progress + throb.
    final haloR = r * (1.7 + charge * 0.8 + throb * 0.12 * charge);
    canvas.drawCircle(
      Offset.zero,
      haloR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tier.glow.withValues(alpha: (0.10 + charge * 0.35) * alpha),
            tier.glow.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: haloR))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Charge ring (the "meter") sweeping around the crate.
    final ringRect = Rect.fromCircle(center: Offset.zero, radius: r * 1.45);
    canvas.drawArc(
      ringRect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
    canvas.drawArc(
      ringRect,
      -pi / 2,
      2 * pi * charge,
      false,
      Paint()
        ..color = tier.color.withValues(alpha: 0.95 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // The crate — an isometric-ish gem/cube.
    final faceTop = Paint()..color = primary.withValues(alpha: 0.95 * alpha);
    final faceL = Paint()..color = const Color(0xFF1A237E).withValues(alpha: 0.95 * alpha);
    final faceR = Paint()..color = const Color(0xFF3949AB).withValues(alpha: 0.95 * alpha);
    final edge = Paint()
      ..color = tier.color.withValues(alpha: 0.9 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // Top rhombus
    final top = Path()
      ..moveTo(0, -r)
      ..lineTo(r, -r * 0.45)
      ..lineTo(0, r * 0.1)
      ..lineTo(-r, -r * 0.45)
      ..close();
    // Left face
    final left = Path()
      ..moveTo(-r, -r * 0.45)
      ..lineTo(0, r * 0.1)
      ..lineTo(0, r)
      ..lineTo(-r, r * 0.45)
      ..close();
    // Right face
    final right = Path()
      ..moveTo(r, -r * 0.45)
      ..lineTo(0, r * 0.1)
      ..lineTo(0, r)
      ..lineTo(r, r * 0.45)
      ..close();
    canvas.drawPath(left, faceL);
    canvas.drawPath(right, faceR);
    canvas.drawPath(top, faceTop);
    canvas.drawPath(top, edge);
    canvas.drawPath(left, edge);
    canvas.drawPath(right, edge);

    // Glowing seams that widen as it nears the burst (cracks of light).
    final crack = (charge - 0.5).clamp(0.0, 1.0) / 0.5; // 0 after 50%→1
    if (crack > 0.0) {
      final crackPaint = Paint()
        ..color = tier.glow.withValues(alpha: (0.5 + 0.5 * (reduceMotion ? 1 : pulse)) * crack * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + crack * 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, crack * 2);
      canvas.drawLine(const Offset(0, -1), Offset(0, r * 0.95), crackPaint);
      canvas.drawLine(Offset(-r * 0.5, -r * 0.22), Offset(r * 0.5, -r * 0.22), crackPaint);
    }

    // Tap glint ring.
    if (tapGlint > 0.0) {
      canvas.drawCircle(
        Offset.zero,
        r * (1.2 + tapGlint * 1.4),
        Paint()
          ..color = accent.withValues(alpha: (1 - tapGlint) * 0.8 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - tapGlint),
      );
    }

    canvas.restore();
  }

  // ── Burst shockwave ────────────────────────────────────────────────────
  void _drawShockwave(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final tier = _tiers[3];
    final t = _burstT;
    // Bright flash early, expanding ring after.
    final flashA = (1.0 - t) * 0.6;
    if (flashA > 0.0) {
      canvas.drawCircle(
        c,
        size.width * (0.1 + t * 0.4),
        Paint()
          ..color = Colors.white.withValues(alpha: flashA)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    for (int i = 0; i < 3; i++) {
      final rt = (t - i * 0.11).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      canvas.drawCircle(
        c,
        size.width * (0.12 + rt * 0.52),
        Paint()
          ..color = tier.glow.withValues(alpha: (1 - rt) * 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0 * (1 - rt)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  // ── "LEGENDARY!" reveal pop ─────────────────────────────────────────────
  void _drawRarityPop(Canvas canvas, Size size) {
    // Sit high, clear of the crate's gold burst glow.
    final c = Offset(size.width / 2, size.height * 0.26);
    final tier = _tiers[3];
    // Scale in fast on burst, hold, then fade as the card rises.
    final pop = Curves.easeOutBack.transform((_burstT * 1.6).clamp(0.0, 1.0));
    final fade = (1.0 - (_cardT / 0.55)).clamp(0.0, 1.0);
    if (fade <= 0) return;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(0.6 + 0.4 * pop);

    final tp = TextPainter(
      text: TextSpan(
        text: 'LEGENDARY!',
        style: TextStyle(
          color: tier.glow.withValues(alpha: fade),
          fontSize: size.width * 0.105,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          fontFamily: 'Bitter',
          shadows: [
            // Dark halo first so the gold reads on any background.
            Shadow(color: Colors.black.withValues(alpha: 0.85 * fade), blurRadius: 16),
            Shadow(color: tier.color.withValues(alpha: 0.9 * fade), blurRadius: 12),
            Shadow(color: tier.glow.withValues(alpha: 0.6 * fade), blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Dark backing pill for guaranteed contrast.
    final pillW = tp.width + size.width * 0.06;
    final pillH = tp.height + size.height * 0.02;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: pillW, height: pillH),
        Radius.circular(pillH / 2),
      ),
      Paint()
        ..color = const Color(0xFF0A0A20).withValues(alpha: 0.55 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  // ── Holographic hero stat-card ─────────────────────────────────────────
  void _drawCard(Canvas canvas, Size size) {
    final t = Curves.easeOutBack.transform(_cardT.clamp(0.0, 1.0));
    final tier = _tiers[3]; // LEGENDARY
    final cardW = size.width * 0.62;
    final cardH = size.height * 0.84;
    final c = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    final scale = 0.55 + 0.45 * t;
    canvas.scale(scale, scale);
    // Slight rise as it assembles.
    canvas.translate(0, (1 - _cardT) * size.height * 0.06 / scale);

    final rect = Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    // Card body — dark holo with tier sheen.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B1B47).withValues(alpha: _cardT),
            const Color(0xFF12123A).withValues(alpha: _cardT),
          ],
        ).createShader(rect),
    );

    // Holographic sweep across the whole card.
    if (!reduceMotion) {
      final sweepX = (-1.0 + 2.0 * shimmer) * cardW;
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTWH(sweepX - cardW * 0.18, -cardH / 2, cardW * 0.36, cardH),
        Paint()
          ..shader = LinearGradient(
            colors: [
              accent.withValues(alpha: 0.0),
              accent.withValues(alpha: 0.18 * _cardT),
              accent.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(sweepX - cardW * 0.18, -cardH / 2, cardW * 0.36, cardH)),
      );
      canvas.restore();
    }

    // Tier-coloured border (double).
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = tier.color.withValues(alpha: 0.9 * _cardT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(11)),
      Paint()
        ..color = tier.glow.withValues(alpha: 0.35 * _cardT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final pad = cardW * 0.09;
    final innerLeft = -cardW / 2 + pad;
    final innerRight = cardW / 2 - pad;
    final innerW = innerRight - innerLeft;

    // ── Rarity banner ──
    final bannerTop = -cardH / 2 + pad * 0.7;
    _text(canvas, tier.label,
        Offset(0, bannerTop + 7),
        color: tier.glow.withValues(alpha: _cardT),
        size: cardW * 0.115, weight: FontWeight.w800, letter: 2.0, center: true);
    _text(canvas, 'HERO CARD',
        Offset(0, bannerTop + 7 + cardW * 0.115),
        color: accent.withValues(alpha: 0.7 * _cardT),
        size: cardW * 0.052, weight: FontWeight.w600, letter: 3.0, center: true);

    // ── Art window with rendering silhouette ──
    final winTop = bannerTop + cardW * 0.24;
    final winH = cardH * 0.40;
    final winRect = Rect.fromLTRB(innerLeft, winTop, innerRight, winTop + winH);
    final winRR = RRect.fromRectAndRadius(winRect, const Radius.circular(8));
    canvas.drawRRect(
      winRR,
      Paint()..color = const Color(0xFF0A0A22).withValues(alpha: _cardT),
    );
    canvas.save();
    canvas.clipRRect(winRR);

    // Silhouette bust — gently pulses so the "rendering" feels alive.
    final cx = winRect.center.dx;
    final bustBase = winRect.bottom;
    final headR = winH * 0.20;
    final headC = Offset(cx, winTop + winH * 0.40);
    final sPulse = reduceMotion ? 1.0 : (0.82 + 0.18 * pulse);
    // Soft breathing glow behind the head.
    if (!reduceMotion) {
      canvas.drawCircle(
        headC,
        headR * (1.5 + 0.25 * pulse),
        Paint()
          ..color = accent.withValues(alpha: 0.18 * _cardT * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    final sil = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primary.withValues(alpha: 0.55 * _cardT * sPulse),
          accent.withValues(alpha: 0.30 * _cardT * sPulse),
        ],
      ).createShader(winRect);
    canvas.drawCircle(headC, headR, sil);
    final shoulders = Path()
      ..moveTo(cx - headR * 2.1, bustBase)
      ..cubicTo(cx - headR * 2.0, bustBase - winH * 0.30,
          cx - headR * 1.1, headC.dy + headR * 0.6, cx, headC.dy + headR * 0.6)
      ..cubicTo(cx + headR * 1.1, headC.dy + headR * 0.6,
          cx + headR * 2.0, bustBase - winH * 0.30, cx + headR * 2.1, bustBase)
      ..close();
    canvas.drawPath(shoulders, sil);

    // Moving scan line (the "rendering" feel).
    if (!reduceMotion) {
      final scanY = winTop + winH * shimmer;
      canvas.drawLine(
        Offset(winRect.left, scanY),
        Offset(winRect.right, scanY),
        Paint()
          ..color = accent.withValues(alpha: 0.85 * _cardT)
          ..strokeWidth = 1.6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    // Faint scan rows.
    final rowPaint = Paint()..color = accent.withValues(alpha: 0.06 * _cardT);
    for (double y = winTop + 4; y < winTop + winH; y += 5) {
      canvas.drawRect(Rect.fromLTWH(winRect.left, y, winRect.width, 1.2), rowPaint);
    }
    canvas.restore();

    // HUD reticle corner brackets on the art window.
    final bracket = Paint()
      ..color = tier.color.withValues(alpha: 0.9 * _cardT)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    const bl = 9.0;
    for (final corner in [
      (winRect.topLeft, 1.0, 1.0),
      (winRect.topRight, -1.0, 1.0),
      (winRect.bottomLeft, 1.0, -1.0),
      (winRect.bottomRight, -1.0, -1.0),
    ]) {
      final o = corner.$1;
      final sx = corner.$2;
      final sy = corner.$3;
      canvas.drawLine(o, o + Offset(bl * sx, 0), bracket);
      canvas.drawLine(o, o + Offset(0, bl * sy), bracket);
    }

    // ── Stat bars ──
    final statsTop = winRect.bottom + cardH * 0.055;
    final barH = cardH * 0.028;
    final gap = cardH * 0.052;
    for (int i = 0; i < _stats.length; i++) {
      final (label, target) = _stats[i];
      final y = statsTop + i * gap;
      // Staggered fill.
      final fill = ((_cardT - i * 0.12) / 0.55).clamp(0.0, 1.0) * target;

      _text(canvas, label, Offset(innerLeft, y),
          color: Colors.white.withValues(alpha: 0.90 * _cardT),
          size: cardW * 0.048, weight: FontWeight.w800, letter: 0.8);

      final trackY = y + cardW * 0.058;
      final track = RRect.fromRectAndRadius(
        Rect.fromLTWH(innerLeft, trackY, innerW, barH),
        Radius.circular(barH / 2),
      );
      canvas.drawRRect(track, Paint()..color = Colors.white.withValues(alpha: 0.08 * _cardT));
      if (fill > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(innerLeft, trackY, innerW * fill, barH),
            Radius.circular(barH / 2),
          ),
          Paint()
            ..shader = LinearGradient(
              colors: [tier.color, tier.glow],
            ).createShader(Rect.fromLTWH(innerLeft, trackY, innerW, barH)),
        );
      }
    }

    canvas.restore();

    // Corner rarity gem (drawn unscaled-ish via same transform end).
  }

  void _text(Canvas canvas, String s, Offset at,
      {required Color color,
      required double size,
      FontWeight weight = FontWeight.normal,
      double letter = 0.0,
      bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: letter,
          fontFamily: 'Bitter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? at.dx - tp.width / 2 : at.dx;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  void _drawVignette(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [Colors.transparent, const Color(0xFF05050F).withValues(alpha: 0.5)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LootCardPainter old) =>
      old.progress != progress ||
      old.pulse != pulse ||
      old.shimmer != shimmer ||
      old.tapGlint != tapGlint;
}

// ---------------------------------------------------------------------------
// Ember particles
// ---------------------------------------------------------------------------

class _EmberPainter extends CustomPainter {
  final List<_Particle> particles;
  final Offset origin; // stage center; particle pos is center-origin
  final Color color;

  _EmberPainter({required this.particles, required this.origin, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.life <= 0.0) continue;
      final alpha = (p.life * 0.8).clamp(0.0, 1.0);
      final s = p.size * (0.5 + p.life * 0.5);
      final pos = origin + p.pos;
      canvas.drawCircle(
        pos,
        s,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      canvas.drawCircle(pos, s * 0.5, Paint()..color = Colors.white.withValues(alpha: alpha * 0.8));
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => true;
}
