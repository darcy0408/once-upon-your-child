// Reads the text-scaling preference the user has already set on their device,
// so the app can honour it without anyone opening an in-app setting.
//
// Why this exists: Flutter's web engine renders text into a <canvas> via
// CanvasKit and never consults the browser's font-size setting, so
// `MediaQuery.textScalerOf(context)` is always exactly 1.0 on web no matter
// what the user has chosen in Chrome or in Android's display settings. Every
// other app on the phone grows its text; this one did not, which is the whole
// complaint. On native platforms Flutter *does* surface the OS scale through
// MediaQuery already, so the io implementation returns 1.0 and lets the
// existing MediaQuery value do the work — never scale twice.

export 'platform_text_scale_io.dart'
    if (dart.library.html) 'platform_text_scale_web.dart';
