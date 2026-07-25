import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/elevenlabs_voice.dart';
import 'package:story_weaver_app/services/app_tts_service.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

/// Voice resolution before an age has been declared.
///
/// The welcome teaser and the name prompt are both spoken before the age
/// picker is ever shown. A hard-coded `?? 7` fallback used to resolve those
/// utterances to the explorer band's Gigi — which the backend synthesizes as
/// Azure `en-US-AnaNeural`, a child voice — so first launch greeted whoever
/// was holding the phone, parent included, in the voice of a 7-year-old.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppTtsService tts;

  setUp(() {
    tts = AppTtsService.forTesting();
  });

  test('with no declared age, resolves to the neutral adult narrator', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await tts.resolveVoiceId(), ElevenLabsVoice.defaultVoiceId);
  });

  test('with no declared age, does not resolve to a child voice', () async {
    SharedPreferences.setMockInitialValues({});

    final resolved = await tts.resolveVoiceId();

    expect(
      resolved,
      isNot(ElevenLabsVoice.defaultVoiceIdForBand(AgeBand.sprout)),
      reason: 'sprout/explorer share Gigi, which maps to Azure en-US-AnaNeural',
    );
    expect(resolved, isNot(ElevenLabsVoice.defaultVoiceIdForBand(AgeBand.explorer)));
  });

  test('once an age is declared, the band voice takes over', () async {
    SharedPreferences.setMockInitialValues({'user_age': 4});

    expect(
      await tts.resolveVoiceId(),
      ElevenLabsVoice.defaultVoiceIdForBand(AgeBand.sprout),
      reason: 'a declared 4-year-old should still get the childlike voice',
    );
  });

  test('an explicit saved voice override still wins over both', () async {
    final override = ElevenLabsVoice.defaultVoiceIdForBand(AgeBand.adult);
    SharedPreferences.setMockInitialValues({
      ElevenLabsVoice.prefsKey: override,
      'user_age': 4,
    });

    expect(await tts.resolveVoiceId(), override);
  });
}
