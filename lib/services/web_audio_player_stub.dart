// Stub for non-web platforms. The real implementation lives in
// web_audio_player.dart and is selected via conditional import.

import 'dart:typed_data';

// ignore: avoid_classes_with_only_static_members
void stopWebAudio() {}

Future<void> playAudioBytesOnWeb(
  Uint8List bytes, {
  bool awaitCompletion = false,
}) async {}
