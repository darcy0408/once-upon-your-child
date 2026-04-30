// Conditional export: web gets the plain stub (no Isar), native gets the
// Isar-annotated collection. Keeps the JS-incompatible 64-bit ID literals
// in the generated `.g.dart` out of the web build.
export 'avatar_cache_entry_stub.dart'
    if (dart.library.io) 'avatar_cache_entry_io.dart';
