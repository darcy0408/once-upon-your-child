# Toolchain Fix Research

Date: 2026-05-27
Status: Research only — actionable hypothesis for a future session
Context: `dart run build_runner build` precompile fails because analyzer 6.3.0
(the project's current override) is API-incompatible with `analyzer_plugin
0.11.x`, which is pulled transitively by `riverpod_generator →
riverpod_analyzer_utils → custom_lint_core`.

## The previously-missed lead

The session attempted to fix this by *upgrading* the chain (custom_lint to
0.7.x, analyzer to 7.x, etc.) and hit walls. The opposite direction was not
tried: **downgrade analyzer to match what `analyzer_plugin 0.11.x` was
actually written for.**

Verified facts (pub.dev pubspec data):

| Package version | Declared `analyzer` constraint |
|-----------------|-------------------------------|
| `analyzer_plugin 0.11.0` | `^4.1.0` |
| `analyzer_plugin 0.11.2` | `^5.0.0` |

`analyzer_plugin 0.11.x` was never written for analyzer 6.x. The 6.3.0 pin
overrides the constraint, but the API surface drift between analyzer 5 and 6
includes the very symbols that fail to compile:

- `Element.enclosingElement3` — present in analyzer 5.x, removed/renamed in 6.x
- `NamedType.name` — present in analyzer 5.x, renamed to `NamedType.name2` in 6.x

The override has been forcing a version mismatch the whole time. The other
generators in the chain *also* accept analyzer 5.x:

| Package | Declared `analyzer` constraint | Accepts 5.x? |
|---------|--------------------------------|--------------|
| `riverpod_generator 2.4.0` | `>=5.12.0 <7.0.0` | yes |
| `isar_generator 3.1.0+1` | `>=4.6.0 <6.0.0` | yes |
| `analyzer_plugin 0.11.2` | `^5.0.0` | yes |
| `custom_lint_core 0.6.3` (last working) | follows analyzer_plugin | yes |

**Intersection: analyzer 5.12.x or later in the 5.x line** satisfies every
declared constraint without any override stretching.

## Hypothesis to test next session

**Change `pubspec.yaml` dependency_overrides from:**
```yaml
analyzer: 6.3.0
```
**to:**
```yaml
analyzer: ^5.12.0
```

Then run:
```powershell
dart pub upgrade
dart run build_runner build --delete-conflicting-outputs
```

If this works, `build_runner` precompiles cleanly because every dep is now
within its declared constraint range. No more API mismatch.

## What this would unblock

- `build_runner` regen — directly resolves the issue PERF-08's `@Index`
  annotations have been waiting on. They'd activate as soon as
  `story_local_io.g.dart` is regenerated.
- Future codegen for any `@riverpod` or Isar model change without the
  drop-deps-and-restore dance.
- The a11y `custom_lint` plugin could optionally be re-wired (Option-1
  edits could be reverted) because `custom_lint_core 0.6.3` works against
  analyzer 5.x cleanly. The Option-1 reduction is still a sensible default
  — fewer deps is better — but the choice would no longer be forced.

## What could still go wrong

1. **flutter_lints / SDK floor.** `flutter_lints 6.0.0` may require a
   newer analyzer minimum. Verify; if so, drop flutter_lints to a version
   compatible with analyzer 5.x.
2. **Other transitive packages.** Some flutter packages newer than the
   current lock may declare `analyzer >=6.0.0` and refuse to coexist. The
   `pub upgrade` step will surface any such conflict immediately.
3. **build_runner itself.** build_runner 2.4.13 may require analyzer 6+.
   If so, pin to an older build_runner that matches the 5.x era (likely
   2.4.5 or earlier).
4. **`flutter analyze` behavior.** flutter analyze uses the analyzer that
   ships with the Flutter SDK, not the pinned one — so this fix only
   affects `dart run build_runner`. `flutter analyze` will keep working
   regardless.

## Plan B if the analyzer-5 pin doesn't resolve

The version-pinning trail is then likely exhausted. The remaining options:

- **Replace isar_generator** with Isar 4 (alpha at time of writing) or
  migrate to another local DB (Drift, Hive, sqflite). Large effort.
- **Drop riverpod_generator** — manage providers manually without the
  `@riverpod` annotation. Means rewriting every annotated provider in
  `lib/providers/`. Medium-large effort.
- **Wait for `isar_generator` 3.x to ship an analyzer-7+ update** — but
  isar 3.x hasn't shipped since 2023, so this is unlikely.

## Effort estimate

- Hypothesis test (analyzer 5.12 pin): ~15 minutes. Fast win or fast
  rejection.
- If it works: ~30 minutes total including verifying `flutter build`,
  `flutter analyze`, and a full `build_runner` regen pass.
- If it doesn't, Plan B becomes a real project (multi-day).

## Files involved in the test

- `pubspec.yaml` — change one line in `dependency_overrides`.
- `pubspec.lock` — `pub upgrade` will rewrite.

That's it. The fix, if the hypothesis holds, is genuinely one-line.
