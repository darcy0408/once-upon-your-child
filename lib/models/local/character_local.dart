// Conditional export: use stub for web, real implementation for mobile
export 'character_local_stub.dart'
    if (dart.library.io) 'character_local_io.dart';
