// Native (Android / iOS / desktop) implementation of the platform text scale.
//
// Flutter already reports the operating system's font-size setting through
// `MediaQuery.textScalerOf(context)` on these platforms, and main_story.dart
// multiplies that inherited factor in. Returning anything but 1.0 here would
// apply the user's preference twice.

/// Always 1.0 on native — the OS scale arrives via MediaQuery instead.
double readPlatformTextScale() => 1.0;

/// No-op on native; exists so tests can share one API with the web build.
void resetPlatformTextScaleCache() {}
