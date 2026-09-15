import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/screens/bedtime_tap_gate.dart';

/// MT-430: a chip tap made while the question is still being narrated must
/// be the answer, not dropped. The wizard arms the gate before it speaks,
/// then reads `answer` once narration ends (or races it against the mic).
void main() {
  group('BedtimeTapGate', () {
    test('a tap that lands before the flow waits is kept', () async {
      final gate = BedtimeTapGate();
      gate.arm();
      // Child taps while the question is still being read aloud.
      expect(gate.offer('Moon Owl'), isTrue);
      expect(gate.hasAnswer, isTrue);
      // Narration ends; the flow now asks for the answer.
      expect(await gate.answer, 'Moon Owl');
    });

    test('arming again does not discard a tap already taken', () async {
      final gate = BedtimeTapGate();
      gate.arm();
      gate.offer('Brave');
      // The listen step arms again before racing the mic.
      gate.arm();
      expect(await gate.answer, 'Brave');
    });

    test('a tap is refused when no question is open', () {
      final gate = BedtimeTapGate();
      expect(gate.offer('Moon Owl'), isFalse);
      expect(gate.hasAnswer, isFalse);
    });

    test('a second tap on another chip is refused, first answer stands',
        () async {
      final gate = BedtimeTapGate();
      gate.arm();
      expect(gate.offer('Moon Owl'), isTrue);
      expect(gate.offer('Dragon'), isFalse);
      expect(await gate.answer, 'Moon Owl');
    });

    test('reading the answer arms the gate when nobody has yet', () async {
      final gate = BedtimeTapGate();
      final pending = gate.answer;
      expect(gate.offer('Forest'), isTrue);
      expect(await pending, 'Forest');
    });

    test('the no-mic wait resolves at once when the tap already landed',
        () async {
      final gate = BedtimeTapGate();
      gate.arm();
      gate.offer('Sleepy');
      final answer = await gate.answer
          .timeout(const Duration(milliseconds: 1), onTimeout: () => '');
      expect(answer, 'Sleepy');
    });

    test('the no-mic wait times out to empty when nobody taps', () async {
      final gate = BedtimeTapGate();
      gate.arm();
      final answer = await gate.answer
          .timeout(const Duration(milliseconds: 1), onTimeout: () => '');
      expect(answer, '');
    });

    test('reset forgets the previous question entirely', () async {
      final gate = BedtimeTapGate();
      gate.arm();
      gate.offer('Moon Owl');
      gate.reset();
      expect(gate.hasAnswer, isFalse);
      expect(gate.offer('Dragon'), isFalse);
      gate.arm();
      expect(gate.offer('Dragon'), isTrue);
      expect(await gate.answer, 'Dragon');
    });
  });
}
