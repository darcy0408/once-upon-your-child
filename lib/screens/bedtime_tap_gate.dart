import 'dart:async';

/// Collects a chip-tap answer to one bedtime-wizard question.
///
/// The gate is armed as soon as the chips appear — *before* the question is
/// narrated — so a tap that lands while the app is still talking is kept
/// instead of thrown away (MT-430). Young children tap the instant a chip
/// shows up; the old flow only started listening for taps after narration
/// finished, echoed the early tap on screen, and then improvised a different
/// story.
///
/// One gate serves one question: [arm] before speaking, [offer] from the
/// chip handler, [answer] wherever the flow waits for a reply, and [reset]
/// once the question is settled so the next one starts clean.
class BedtimeTapGate {
  Completer<String>? _completer;

  Completer<String> _arm() => _completer ??= Completer<String>();

  /// Start accepting a tap. Safe to call repeatedly: a pending gate stays
  /// pending and a tap already taken is kept until [reset].
  void arm() => _arm();

  /// Whether a tap has already been taken since the last [reset].
  bool get hasAnswer => _completer?.isCompleted ?? false;

  /// Record a tap. Returns false — and changes nothing — when the gate is not
  /// armed or an answer was already taken, so callers can avoid echoing a tap
  /// that will not be honoured.
  bool offer(String option) {
    final c = _completer;
    if (c == null || c.isCompleted) return false;
    c.complete(option);
    return true;
  }

  /// The tap for the current question. Resolves immediately if it already
  /// landed, otherwise when it does. Arms the gate if nobody has yet.
  Future<String> get answer => _arm().future;

  /// Forget the current question's tap so the next question starts clean.
  void reset() => _completer = null;
}
