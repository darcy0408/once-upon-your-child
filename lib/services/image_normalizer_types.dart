// Shared types for the image normalizer. No platform dependencies, so both the
// native (image_normalizer_io.dart) and web (image_normalizer_web.dart)
// implementations can import it without pulling in dart:html or dart:io.

import 'dart:typed_data';

/// A picked photo that has been decoded, EXIF-oriented, resized, and
/// re-encoded into a format the backend and Flutter's own `Image.memory` can
/// both handle (JPEG). Returned by `normalizeImageBytes`.
class NormalizedImage {
  const NormalizedImage({required this.bytes, required this.mimeType});

  final Uint8List bytes;

  /// Always a web-safe container ('image/jpeg'). Kept explicit so callers can
  /// label the multipart upload truthfully instead of hardcoding 'photo.jpg'.
  final String mimeType;
}
