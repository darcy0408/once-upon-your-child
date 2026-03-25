import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/elevenlabs_voice.dart';
import 'age_band_provider.dart';

part 'voice_preference_provider.g.dart';

/// Persists and exposes the user's selected ElevenLabs voice ID.
/// Defaults to an age-band-appropriate voice on first launch.
/// A user's explicit choice always takes priority over the band default.
@riverpod
class VoicePreferenceNotifier extends _$VoicePreferenceNotifier {
  @override
  String build() {
    final band = ref.watch(ageBandNotifierProvider).band;
    _loadSavedPreference();
    return ElevenLabsVoice.defaultVoiceIdForBand(band);
  }

  Future<void> _loadSavedPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ElevenLabsVoice.prefsKey);
    if (saved != null && ElevenLabsVoice.byId(saved) != null) {
      state = saved;
    }
    // If no explicit preference saved, state already holds the band default
    // set in build() — no update needed.
  }

  Future<void> setVoice(String voiceId) async {
    state = voiceId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ElevenLabsVoice.prefsKey, voiceId);
  }

  ElevenLabsVoice get currentVoice =>
      ElevenLabsVoice.byId(state) ??
      ElevenLabsVoice.curated.first;
}
