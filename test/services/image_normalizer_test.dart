// Exercises the native (io) image normalizer. On the flutter_test VM the
// conditional import in image_normalizer.dart resolves to the `package:image`
// implementation, so this covers the path used on iOS/Android/desktop.
//
// The web/canvas path (image_normalizer_web.dart) needs a real browser and is
// verified by hand on device — it cannot run here.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:story_weaver_app/services/image_normalizer.dart';

Uint8List _pngBytes(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 168, 207));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('downscales an oversized image so its longest side fits maxDimension',
      () async {
    final result = await normalizeImageBytes(
      _pngBytes(2000, 1000),
      maxDimension: 1024,
    );

    expect(result, isNotNull);
    expect(result!.mimeType, 'image/jpeg');

    final decoded = img.decodeImage(result.bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1024); // longest side clamped
    expect(decoded.height, 512); // aspect ratio preserved
  });

  test('re-encodes a small image to JPEG without upscaling', () async {
    final result = await normalizeImageBytes(
      _pngBytes(300, 300),
      maxDimension: 1024,
    );

    expect(result, isNotNull);
    expect(result!.mimeType, 'image/jpeg');

    final decoded = img.decodeImage(result.bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 300); // unchanged — never enlarged
    expect(decoded.height, 300);
    // Output must be a real JPEG, not the PNG that went in.
    expect(img.findFormatForData(result.bytes), img.ImageFormat.jpg);
  });

  test('returns null for bytes it cannot decode (fail closed)', () async {
    // Not any known image container — the caller must show an error rather
    // than upload this. Mirrors what an undecodable HEIC would do on-device.
    final garbage = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final result = await normalizeImageBytes(garbage);
    expect(result, isNull);
  });
}
