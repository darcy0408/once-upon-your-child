// Web-only TTS audio player that bypasses the `audioplayers` package.
//
// `audioplayers` converts BytesSource to a data: URI and connects it to a Web
// AudioContext with crossOrigin='anonymous'. In Chrome this prevents the
// loadeddata event from firing, causing the 30-second preparationTimeout to
// expire. Using a plain HTMLAudioElement with a blob URL avoids both the
// AudioContext suspension issue and the CORS/data-URI problem.
//
// Selected by the conditional import in app_tts_service.dart:
//   import 'web_audio_player_stub.dart' if (dart.library.html) 'web_audio_player.dart';

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

html.AudioElement? _current;
String? _currentBlobUrl;

/// Stops any audio currently playing via [playAudioBytesOnWeb].
void stopWebAudio() {
  _current?.pause();
  _current = null;
  if (_currentBlobUrl != null) {
    html.Url.revokeObjectUrl(_currentBlobUrl!);
    _currentBlobUrl = null;
  }
}

/// Plays [bytes] (MP3) via a plain HTML AudioElement + blob URL.
/// Throws if the browser rejects playback (e.g. autoplay policy) so the
/// caller's catch block can fall back to device TTS.
Future<void> playAudioBytesOnWeb(
  Uint8List bytes, {
  bool awaitCompletion = false,
}) async {
  stopWebAudio();

  final blob = html.Blob([bytes], 'audio/mpeg');
  final url = html.Url.createObjectUrl(blob);
  _currentBlobUrl = url;

  final audio = html.AudioElement()..src = url;
  _current = audio;

  try {
    await audio.play();
    if (awaitCompletion) {
      await audio.onEnded.first.timeout(const Duration(seconds: 120));
    }
  } finally {
    // Only clean up if this element is still the active one (not replaced by a
    // subsequent call to stopWebAudio / playAudioBytesOnWeb).
    if (identical(_current, audio)) {
      _current = null;
      html.Url.revokeObjectUrl(url);
      _currentBlobUrl = null;
    }
  }
}
