// Web / PWA image normalizer.
//
// image_picker_for_web ignores `imageQuality` and `maxWidth`, so on the web
// build (including the installed PWA) the picker hands back the phone's raw
// bytes — often HEIC, and often several megabytes. The Dart `image` package
// has no HEIC decoder, so we lean on the browser instead: an <img> element
// decodes the file (Safari, the browser this matters most for, decodes HEIC
// natively), we draw it to a <canvas> at a bounded size, and re-encode to JPEG
// via toDataUrl.
//
// Browsers apply EXIF orientation when rendering an <img>, so the canvas draw
// is already upright — no orientation handling needed here.
//
// If the browser can't decode the file (e.g. HEIC on a non-Safari browser),
// the <img> onError fires and we return null so the caller shows a real error
// rather than a silently broken avatar.

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'image_normalizer_types.dart';

Future<NormalizedImage?> normalizeImageBytes(
  Uint8List bytes, {
  int maxDimension = 1024,
  int quality = 85,
}) async {
  final blob = html.Blob(<Uint8List>[bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final image = html.ImageElement();
    final loaded = Completer<bool>();
    image.onLoad.listen((_) {
      if (!loaded.isCompleted) loaded.complete(true);
    });
    image.onError.listen((_) {
      if (!loaded.isCompleted) loaded.complete(false);
    });
    image.src = url;

    final ok = await loaded.future;
    if (!ok) return null;

    final naturalW = image.naturalWidth;
    final naturalH = image.naturalHeight;
    if (naturalW == 0 || naturalH == 0) return null;

    final longestSide = naturalW >= naturalH ? naturalW : naturalH;
    final scale = longestSide > maxDimension ? maxDimension / longestSide : 1.0;
    final targetW = (naturalW * scale).round();
    final targetH = (naturalH * scale).round();

    final canvas = html.CanvasElement(width: targetW, height: targetH);
    final ctx = canvas.context2D;
    ctx.drawImageScaled(image, 0, 0, targetW, targetH);

    // Same-origin blob source -> canvas is not tainted, so toDataUrl works.
    final dataUrl = canvas.toDataUrl('image/jpeg', quality / 100);
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex < 0) return null;
    final base64Part = dataUrl.substring(commaIndex + 1);
    final out = base64Decode(base64Part);

    return NormalizedImage(bytes: out, mimeType: 'image/jpeg');
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
