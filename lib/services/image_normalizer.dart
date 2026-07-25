// Normalizes a freshly-picked photo into resized, EXIF-oriented JPEG bytes that
// the backend (OpenAI gpt-image accepts png/jpeg/webp only) and Flutter's own
// `Image.memory` can both handle.
//
// The whole point is to accept what the user's phone actually produces — HEIC
// by default on iPhone, multi-megabyte files — and quietly convert it, instead
// of letting a raw HEIC upload surface as a "must be png, jpeg or webp" error
// and render as a grey circle in the preview.
//
// Platform split follows the repo's existing dart:html conditional-import
// idiom (see app_tts_service.dart / web_audio_player.dart): native uses the
// `image` package; web uses a browser <canvas>. Callers just:
//
//   import 'services/image_normalizer.dart';
//   final normalized = await normalizeImageBytes(bytes);
//   if (normalized == null) { /* show a real error */ }
//
// Returns null when the bytes cannot be decoded on this platform (e.g. HEIC on
// a non-Safari browser) — a signal to show an error, never to upload as-is.

export 'image_normalizer_types.dart';
export 'image_normalizer_io.dart'
    if (dart.library.html) 'image_normalizer_web.dart';
