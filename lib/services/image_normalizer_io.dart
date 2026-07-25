// Native (iOS / Android / desktop) image normalizer.
//
// On these platforms image_picker's `imageQuality` argument already re-encodes
// HEIC -> JPEG at the picker level, so the bytes reaching here are normally
// already a decodable format. This pass is the safety net that also applies
// EXIF orientation and enforces a max dimension, and it fails closed: if the
// `image` package cannot decode the bytes (an unsupported container we can't
// convert on-device), it returns null so the caller can show a real error
// instead of uploading something the backend / OpenAI will reject.

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'image_normalizer_types.dart';

Future<NormalizedImage?> normalizeImageBytes(
  Uint8List bytes, {
  int maxDimension = 1024,
  int quality = 85,
}) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // Phone photos routinely carry an EXIF orientation flag rather than storing
  // pixels upright; bake it in so the avatar isn't sideways.
  final oriented = img.bakeOrientation(decoded);

  final longestSide =
      oriented.width >= oriented.height ? oriented.width : oriented.height;
  final resized = longestSide > maxDimension
      ? (oriented.width >= oriented.height
          ? img.copyResize(oriented, width: maxDimension)
          : img.copyResize(oriented, height: maxDimension))
      : oriented;

  final jpg = img.encodeJpg(resized, quality: quality);
  return NormalizedImage(
    bytes: Uint8List.fromList(jpg),
    mimeType: 'image/jpeg',
  );
}
