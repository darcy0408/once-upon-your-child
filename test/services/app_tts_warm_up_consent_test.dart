import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/services/app_tts_service.dart';

/// MT-431: the start-up warm-up pass (up to 40 synthesis requests) must not
/// run before a consent record exists. Before consent only three interface
/// phrases are ever spoken, so warming the wizard vocabulary on every fresh
/// install was vendor spend on every visitor who bounced at the age gate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppTtsService tts;

  setUp(() {
    tts = AppTtsService.forTesting();
  });

  test('with no consent on file the warm-up is held back', () async {
    SharedPreferences.setMockInitialValues({});

    final ran = await tts.warmUpIfConsented(phrases: const []);

    expect(ran, isFalse);
    expect(tts.isWarmUpAwaitingConsent, isTrue,
        reason: 'speak() must know to re-check after consent is recorded');
  });

  test('once consent is recorded the warm-up runs and the hold clears',
      () async {
    SharedPreferences.setMockInitialValues({
      'parental_consent_granted': true,
    });

    final ran = await tts.warmUpIfConsented(phrases: const []);

    expect(ran, isTrue);
    expect(tts.isWarmUpAwaitingConsent, isFalse);
  });

  test('a 13+ self-attestation counts the same as parental consent', () async {
    // Both paths write the same flag through recordConsent(); the method
    // string differs but the warm-up only cares that consent is on file.
    SharedPreferences.setMockInitialValues({
      'parental_consent_granted': true,
      'parental_consent_method': 'self_attested',
    });

    expect(await tts.warmUpIfConsented(phrases: const []), isTrue);
  });
}
