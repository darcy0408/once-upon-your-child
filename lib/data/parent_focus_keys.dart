// Canonical parent-selectable focus keys (MT-254).
//
// This is the SINGLE SOURCE OF TRUTH for the `value` a parent picks in the
// Big Feelings panel. That value is:
//   • written to ParentHiddenContext (`trigger`, comma-joined),
//   • echoed back by the backend as the story's `practiced` field, and
//   • used by the child-facing Story Notes disclosure to name what was practiced.
//
// Two maps must cover exactly these keys or the feature drifts:
//   • `_triggerData` in lib/screens/parent_controls_screen.dart (parent picker)
//   • `_focusCopy`   in lib/models/story_notes.dart            (child disclosure)
//
// A drift between them fails SOFT — an unknown `practiced` value degrades the
// disclosure to generic copy instead of naming the focus — which is exactly the
// kind of silent values-regression the guard test in
// test/models/story_notes_test.dart exists to catch. Add a new focus HERE first,
// then to both maps.
//
// WARNING: these strings are persisted (DB `trigger`/`practiced`). Never edit an
// existing value — only add. Renaming orphans every saved selection in the wild.
class ParentFocusKeys {
  ParentFocusKeys._();

  static const limitSet = 'a limit is set';
  static const siblingConflict = 'a sibling conflict starts';
  static const friendshipBump = 'a friendship bump happens';
  static const nighttimeUncertain = 'nighttime feels uncertain';
  static const transition = 'a transition happens';
  static const meltdownWhenStuck = 'meltdown when stuck';

  /// Every canonical key, for iteration and drift checks.
  static const all = <String>[
    limitSet,
    siblingConflict,
    friendshipBump,
    nighttimeUncertain,
    transition,
    meltdownWhenStuck,
  ];
}
