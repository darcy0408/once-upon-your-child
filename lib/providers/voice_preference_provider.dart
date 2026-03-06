import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/elevenlabs_voice.dart';

part 'voice_preference_provider.g.dart';

/// Persists and exposes the user's selected ElevenLabs voice ID.
/// Defaults to Rachel (warm female, great for kids) on first launch.
@riverpod
class VoicePreferenceNotifier extends _$VoicePreferenceNotifier {
  @override
  String build() {
    _load();
    return ElevenLabsVoice.defaultVoiceId;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ElevenLabsVoice.prefsKey);
    if (saved != null && ElevenLabsVoice.byId(saved) != null) {
      state = saved;
    }
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
