// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_preference_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$voicePreferenceNotifierHash() =>
    r'327af81c3c16da47468cfa7a51c61335e8a18b21';

/// Persists and exposes the user's selected ElevenLabs voice ID.
/// Defaults to Rachel (warm female, great for kids) on first launch.
///
/// Copied from [VoicePreferenceNotifier].
@ProviderFor(VoicePreferenceNotifier)
final voicePreferenceNotifierProvider =
    AutoDisposeNotifierProvider<VoicePreferenceNotifier, String>.internal(
  VoicePreferenceNotifier.new,
  name: r'voicePreferenceNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$voicePreferenceNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VoicePreferenceNotifier = AutoDisposeNotifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
