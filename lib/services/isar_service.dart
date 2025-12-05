// Conditional import: use stub for web, real implementation for mobile
export 'isar_service_stub.dart' if (dart.library.io) 'isar_service_io.dart';
