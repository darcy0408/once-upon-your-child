// lib/widgets/coping_practice_sheet.dart
//
// Guided animated practice sheet for a CopingTechnique. Used by both the
// Coping Toolbox tile and the in-story "Try it with [hero]!" break.
//
// Three frames: Intro (description + "Let's go!"), Practice (animated orb +
// step label, cycle counter), Done ("You did it!" + practice-again / done).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/coping_techniques.dart';
import '../services/app_tts_service.dart';

/// Open the sheet modally. Resolves when the kid taps Done (or dismisses).
class CopingPracticeSheet {
  static Future<void> show(
    BuildContext context, {
    required CopingTechnique technique,
    bool ttsEnabled = true,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => _PracticeScreen(
          technique: technique,
          ttsEnabled: ttsEnabled,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

enum _Frame { intro, practice, done }

class _PracticeScreen extends StatefulWidget {
  final CopingTechnique technique;
  final bool ttsEnabled;

  const _PracticeScreen({
    required this.technique,
    required this.ttsEnabled,
  });

  @override
  State<_PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<_PracticeScreen>
    with SingleTickerProviderStateMixin {
  _Frame _frame = _Frame.intro;
  int _stepIndex = 0;
  int _cycle = 1;
  Timer? _stepTimer;
  late final AnimationController _orbController;

  CopingTechnique get _t => widget.technique;
  CopingStep get _currentStep => _t.steps[_stepIndex];

  Color get _accent => Color(_t.colorSeed);

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _orbController.dispose();
    AppTtsService.instance.stop();
    super.dispose();
  }

  void _start() {
    setState(() {
      _frame = _Frame.practice;
      _stepIndex = 0;
      _cycle = 1;
    });
    _runStep();
  }

  void _runStep() {
    final step = _currentStep;
    // Drive the orb animation per action.
    _orbController.duration = step.duration;
    switch (step.action) {
      case CopingAction.breatheIn:
        _orbController.forward(from: 0);
        break;
      case CopingAction.breatheOut:
        _orbController.reverse(from: 1);
        break;
      case CopingAction.hold:
        // Pause animation at full size to suggest "hold the breath."
        _orbController.value = 1;
        break;
      case CopingAction.prompt:
        // Grounding step — orb stays gently visible at half scale.
        _orbController.value = 0.55;
        break;
    }
    // Speak the step label so non-readers can follow along.
    if (widget.ttsEnabled) {
      final spoken = step.cue == null ? step.label : '${step.label}. ${step.cue}';
      AppTtsService.instance.speak(spoken, rateScale: 0.85);
    }
    _stepTimer?.cancel();
    _stepTimer = Timer(step.duration, _advance);
  }

  void _advance() {
    if (!mounted) return;
    final isLastStep = _stepIndex == _t.steps.length - 1;
    if (!isLastStep) {
      setState(() => _stepIndex++);
      _runStep();
      return;
    }
    // Finished the cycle — repeat or finish.
    if (_cycle < _t.cycles) {
      setState(() {
        _cycle++;
        _stepIndex = 0;
      });
      _runStep();
      return;
    }
    setState(() => _frame = _Frame.done);
    AppTtsService.instance.speak('You did it! Nice work.', rateScale: 0.85);
  }

  void _practiceAgain() {
    AppTtsService.instance.stop();
    _start();
  }

  void _done() {
    AppTtsService.instance.stop();
    Navigator.of(context).pop();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A0E36),
              _accent.withAlpha(60),
              const Color(0xFF0F061E),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: switch (_frame) {
            _Frame.intro => _buildIntro(),
            _Frame.practice => _buildPractice(),
            _Frame.done => _buildDone(),
          },
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      children: [
        _topBar(label: 'Try this', showClose: true),
        const SizedBox(height: 20),
        Text(_t.emoji, style: const TextStyle(fontSize: 80)),
        const SizedBox(height: 12),
        Text(
          _t.name,
          style: GoogleFonts.fredoka(
            color: _accent,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _t.tagline,
          style: GoogleFonts.fredoka(
            color: Colors.white70,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _t.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: Colors.white.withAlpha(220),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          child: ElevatedButton(
            onPressed: _start,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 64),
              shape: const StadiumBorder(),
              elevation: 6,
            ),
            child: Text(
              "Let's go! ✨",
              style: GoogleFonts.fredoka(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPractice() {
    final step = _currentStep;
    return Column(
      children: [
        _topBar(
          label: '${_t.name}  •  Round $_cycle / ${_t.cycles}',
          showClose: true,
        ),
        const Spacer(),
        // Animated orb — scales with the breath.
        AnimatedBuilder(
          animation: _orbController,
          builder: (_, __) {
            // Map controller [0..1] → scale [0.45..1.0] for visible breath.
            final scale = 0.45 + (_orbController.value * 0.55);
            final glow = (60 + _orbController.value * 90).toDouble();
            return Container(
              width: 220,
              height: 220,
              alignment: Alignment.center,
              child: Container(
                width: 200 * scale,
                height: 200 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withAlpha(220),
                      _accent.withAlpha(90),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withAlpha(140),
                      blurRadius: glow,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _t.emoji,
                    style: TextStyle(fontSize: 64 * scale),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 36),
        Text(
          step.label,
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (step.cue != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              step.cue!,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ],
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: TextButton(
            onPressed: _done,
            child: Text(
              'Done early',
              style: GoogleFonts.fredoka(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Column(
      children: [
        _topBar(label: 'Nice work', showClose: false),
        const Spacer(),
        const Text('🌟', style: TextStyle(fontSize: 96)),
        const SizedBox(height: 16),
        Text(
          'You did it!',
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text(
            'Big feelings get smaller when you breathe through them.\n'
            'You can come back to this anytime.',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
          child: OutlinedButton.icon(
            onPressed: _practiceAgain,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Practice again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: _accent.withAlpha(180), width: 1.5),
              minimumSize: const Size(double.infinity, 56),
              shape: const StadiumBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          child: ElevatedButton.icon(
            onPressed: _done,
            icon: const Icon(Icons.check_rounded, size: 22),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 64),
              shape: const StadiumBorder(),
              elevation: 6,
              textStyle: GoogleFonts.fredoka(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar({required String label, required bool showClose}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: showClose
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: _done,
                  )
                : null,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
