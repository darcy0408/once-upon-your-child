// Conditional export: use stub for web, real Isar implementation for mobile/desktop.
// See C:\Users\Darcy\.claude\projects\C--dev-story-weaver-app\memory\isar_web_build_pattern.md
// for why this split exists (Isar 64-bit schema IDs break `flutter build web`).
export 'hero_profile_local_stub.dart'
    if (dart.library.io) 'hero_profile_local_io.dart';
