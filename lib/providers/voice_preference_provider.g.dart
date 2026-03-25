// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_preference_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$voicePreferenceNotifierHash() =>
    r'bafe897a407d578178c8eeaa7d67d9fa97f5930c';

/// Persists and exposes the user's selected ElevenLabs voice ID.
/// Defaults to an age-band-appropriate voice on first launch.
/// A user's explicit choice always takes priority over the band default.
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
