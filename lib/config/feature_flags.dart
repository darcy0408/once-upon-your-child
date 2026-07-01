/// Compile-time feature flags.
///
/// These are plain `const` toggles (no remote config) so a disabled feature is
/// tree-shaken out of release builds and can never change behavior at runtime.
/// Flip a flag to `true` and rebuild to enable the feature.
class FeatureFlags {
  const FeatureFlags._();

  /// MT-258 — the Adolescent (15-17) interactive "Crux Choice" antihero flow.
  ///
  /// When `false` (default), the adolescent antihero path uses the existing
  /// single-shot `generateStory` call unchanged. When `true`, that path splits
  /// into the two-call crux flow (setup + choice -> resolution). Kept OFF until
  /// the flow is verified end-to-end against prod (design doc phase 5).
  static const bool cruxChoiceEnabled = false;
}
