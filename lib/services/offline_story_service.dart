// Conditional export: use stub for web, real implementation for mobile
export 'offline_story_service_stub.dart'
    if (dart.library.io) 'offline_story_service_io.dart';
