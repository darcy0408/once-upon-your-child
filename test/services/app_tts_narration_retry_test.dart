import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/services/app_tts_service.dart';
import 'package:story_weaver_app/services/tts_api_service.dart';

/// MT-432: a single transient narration failure (a 503 from the provider
/// chain, a network blip) used to drop that utterance straight to the robotic
/// on-device voice. The backend now gets exactly one more chance first;
/// failures the server has typed as non-transient do not get a retry.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppTtsService tts;

  final audio = TtsSynthesisResult(
    audioBytes: Uint8List.fromList([1, 2, 3]),
    wordTimestamps: const [],
  );

  setUp(() {
    tts = AppTtsService.forTesting();
  });

  Future<TtsSynthesisResult?> call(
    List<Future<TtsSynthesisResult?> Function()> script,
    List<int> calls, {
    bool Function()? stillWanted,
  }) {
    return tts.synthesizeWithOneRetry(
      'Who is coming with you?',
      voiceId: 'v',
      speed: 0.85,
      stillWanted: stillWanted,
      attempt: () {
        final i = calls.length;
        calls.add(i);
        return script[i]();
      },
    );
  }

  test('a transient miss is retried once and the retry wins', () async {
    final calls = <int>[];
    final result = await call([
      () async => null,
      () async => audio,
    ], calls);

    expect(result, same(audio));
    expect(calls.length, 2);
  });

  test('a first-time success is not retried', () async {
    final calls = <int>[];
    final result = await call([() async => audio], calls);

    expect(result, same(audio));
    expect(calls.length, 1);
  });

  test('two misses in a row give up after the single retry', () async {
    final calls = <int>[];
    final result = await call([
      () async => null,
      () async => null,
    ], calls);

    expect(result, isNull);
    expect(calls.length, 2, reason: 'one retry, never a loop');
  });

  test('empty audio counts as a miss', () async {
    final calls = <int>[];
    final empty = TtsSynthesisResult(
      audioBytes: Uint8List(0),
      wordTimestamps: const [],
    );
    final result = await call([
      () async => empty,
      () async => audio,
    ], calls);

    expect(result, same(audio));
    expect(calls.length, 2);
  });

  test('typed server failures are not retried', () async {
    final calls = <int>[];
    await expectLater(
      call([() async => throw TtsRateLimitException()], calls),
      throwsA(isA<TtsRateLimitException>()),
    );
    expect(calls.length, 1);

    calls.clear();
    await expectLater(
      call([
        () async => throw TtsQuotaExceededException(
              dailyLimit: 50,
              synthesesUsed: 50,
            ),
      ], calls),
      throwsA(isA<TtsQuotaExceededException>()),
    );
    expect(calls.length, 1);
  });

  test('a superseded utterance skips the retry', () async {
    final calls = <int>[];
    final result = await call(
      [() async => null, () async => audio],
      calls,
      stillWanted: () => false,
    );

    expect(result, isNull);
    expect(calls.length, 1, reason: 'stop() or a newer speak() won');
  });
}
