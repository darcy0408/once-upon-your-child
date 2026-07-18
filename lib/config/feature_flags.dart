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

  /// PERF-01 — render the streamed partial story text (a readable-prose view
  /// emitted by the backend as the model writes) inside the loading view, so
  /// a child starts READING the opening of their story ~3-5s in instead of
  /// staring at a spinner for the full generation.
  ///
  /// Trade-off to be aware of: the streamed text is PRE-moderation /
  /// pre-validation model output. The prompt stack carries multiple safety
  /// layers, but the post-generation moderation pass has not run yet when
  /// this text appears. Flip to `false` to kill the preview (the honest
  /// progress bar — driven only by the text's LENGTH — keeps working either
  /// way). Skipped for the Sprout (3-5) band regardless: pre-readers get the
  /// star-catcher stage, not text.
  static const bool partialStoryPreviewEnabled = true;
}
