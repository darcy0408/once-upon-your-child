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
import '../data/life_quest_data.dart';
import '../services/app_tts_service.dart';

/// Open the sheet modally. Resolves when the kid taps Done (or dismisses).
///
/// [buddy] is the Sprout-band animal friend that should "guide" the practice.
/// When set, the breathing figure is rendered as the buddy's portrait scaling
/// in/out instead of the abstract orb, and a per-buddy pep-talk replaces the
/// generic intro tagline. Older bands pass null and get the original orb.
class CopingPracticeSheet {
  static Future<void> show(
    BuildContext context, {
    required CopingTechnique technique,
    bool ttsEnabled = true,
    SproutFriend? buddy,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => _PracticeScreen(
          technique: technique,
          ttsEnabled: ttsEnabled,
          buddy: buddy,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

/// Asset path / display name / pep-talk lookup for the SproutFriend buddy.
/// Inlined here (not shared with life_quest_screen) because the mapping is
/// tiny and keeping it local avoids a new shared file just for 4 strings.
String _buddyAssetPath(SproutFriend f) {
  switch (f) {
    case SproutFriend.pup:   return 'assets/images/feelings/sprout/happy.png';
    case SproutFriend.bunny: return 'assets/images/feelings/sprout/sad.png';
    case SproutFriend.lion:  return 'assets/images/feelings/sprout/mad.png';
    case SproutFriend.mouse: return 'assets/images/feelings/sprout/scared.png';
  }
}

String _buddyDisplayName(SproutFriend f) {
  switch (f) {
    case SproutFriend.pup:   return 'Sunny Pup';
    case SproutFriend.bunny: return 'Rainy Bunny';
    case SproutFriend.lion:  return 'Roary Lion';
    case SproutFriend.mouse: return 'Shy Mouse';
  }
}

/// One-line pep-talk shown on the intro frame and spoken on practice start
/// when a buddy is present. Tone matches each animal's emotional family.
String _buddyPepTalk(SproutFriend f) {
  switch (f) {
    case SproutFriend.pup:
      return 'Sunny Pup wants to breathe with you!';
    case SproutFriend.bunny:
      return 'Rainy Bunny will breathe through the sad with you.';
    case SproutFriend.lion:
      return 'Roary Lion will huff the angries out with you!';
    case SproutFriend.mouse:
      return 'Shy Mouse will breathe brave-breaths with you.';
  }
}

enum _Frame { intro, practice, done }

class _PracticeScreen extends StatefulWidget {
  final CopingTechnique technique;
  final bool ttsEnabled;
  final SproutFriend? buddy;

  const _PracticeScreen({
    required this.technique,
    required this.ttsEnabled,
    this.buddy,
  });

  @override
  State<_PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<_PracticeScreen> {
  _Frame _frame = _Frame.intro;
  int _stepIndex = 0;
  int _cycle = 1;
  Timer? _stepTimer;

  CopingTechnique get _t => widget.technique;
  CopingStep get _currentStep => _t.steps[_stepIndex];

  Color get _accent => Color(_t.colorSeed);

  @override
  void dispose() {
    _stepTimer?.cancel();
    AppTtsService.instance.stop();
    super.dispose();
  }

  // Scale targets per action. The TweenAnimationBuilder in _buildPractice
  // reads these to drive the orb size from begin → end across the step's
  // duration. Picked for visible breath: ~0.45 (small) ↔ 1.0 (full).
  double _beginScaleFor(CopingAction action) {
    switch (action) {
      case CopingAction.breatheIn:
        return 0.45;
      case CopingAction.breatheOut:
        return 1.0;
      case CopingAction.hold:
        return 1.0;
      case CopingAction.prompt:
        return 0.55;
    }
  }

  double _endScaleFor(CopingAction action) {
    switch (action) {
      case CopingAction.breatheIn:
        return 1.0;
      case CopingAction.breatheOut:
        return 0.45;
      case CopingAction.hold:
        return 1.0;
      case CopingAction.prompt:
        return 0.55;
    }
  }

  void _start() {
    setState(() {
      _frame = _Frame.practice;
      _stepIndex = 0;
      _cycle = 1;
    });
    _scheduleAdvance();
    _maybeSpeakStep();
  }

  void _maybeSpeakStep() {
    if (!widget.ttsEnabled) return;
    final step = _currentStep;
    final spoken = step.cue == null ? step.label : '${step.label}. ${step.cue}';
    AppTtsService.instance.speak(spoken, rateScale: 0.85);
  }

  void _scheduleAdvance() {
    _stepTimer?.cancel();
    _stepTimer = Timer(_currentStep.duration, _advance);
  }

  void _advance() {
    if (!mounted) return;
    final isLastStep = _stepIndex == _t.steps.length - 1;
    if (!isLastStep) {
      setState(() => _stepIndex++);
      _scheduleAdvance();
      _maybeSpeakStep();
      return;
    }
    // Finished the cycle — repeat or finish.
    if (_cycle < _t.cycles) {
      setState(() {
        _cycle++;
        _stepIndex = 0;
      });
      _scheduleAdvance();
      _maybeSpeakStep();
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
    final buddy = widget.buddy;
    return Column(
      children: [
        _topBar(label: 'Try this', showClose: true),
        const SizedBox(height: 20),
        if (buddy != null)
          // Buddy portrait — clipped to a soft circle with an accent halo so
          // the rectangular cartoon background blends into the practice sheet.
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accent.withAlpha(140),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                _buddyAssetPath(buddy),
                fit: BoxFit.cover,
              ),
            ),
          )
        else
          Text(_t.emoji, style: const TextStyle(fontSize: 80)),
        const SizedBox(height: 12),
        Text(
          buddy != null ? _buddyDisplayName(buddy) : _t.name,
          style: GoogleFonts.fredoka(
            color: _accent,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          buddy != null ? _buddyPepTalk(buddy) : _t.tagline,
          textAlign: TextAlign.center,
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
    final beginScale = _beginScaleFor(step.action);
    final endScale = _endScaleFor(step.action);
    return Column(
      children: [
        _topBar(
          label: '${_t.name}  •  Round $_cycle / ${_t.cycles}',
          showClose: true,
        ),
        const Spacer(),
        // Animated orb — scales with the breath. The ValueKey forces a fresh
        // TweenAnimationBuilder mount whenever the step (or cycle) changes,
        // so the tween restarts at `beginScale` and animates to `endScale`
        // over the step's full duration.
        TweenAnimationBuilder<double>(
          key: ValueKey('orb-c$_cycle-s$_stepIndex'),
          tween: Tween<double>(begin: beginScale, end: endScale),
          duration: step.duration,
          curve: Curves.easeInOut,
          builder: (_, scale, __) {
            // Map scale [0.45..1.0] → glow blur for a subtle "breath aura."
            final glow = 60.0 + ((scale - 0.45) / 0.55) * 90.0;
            final buddy = widget.buddy;
            return SizedBox(
              width: 220,
              height: 220,
              child: Center(
                child: Container(
                  width: 200 * scale,
                  height: 200 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: buddy == null
                        ? RadialGradient(
                            colors: [
                              _accent.withAlpha(220),
                              _accent.withAlpha(90),
                            ],
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withAlpha(140),
                        blurRadius: glow,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: buddy != null
                      ? ClipOval(
                          child: Image.asset(
                            _buddyAssetPath(buddy),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Text(
                            _t.emoji,
                            style: TextStyle(fontSize: 64 * scale),
                          ),
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
