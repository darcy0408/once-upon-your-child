# Brief: Triage In-Flight Uncommitted Work

You are a read-only audit agent. Your job is to figure out what the developer was in the middle of doing across four uncommitted files, and produce a short report that lets them either resume, merge, or discard.

## Required tools
- File read access to `C:\dev\story-weaver-app`
- `git` (for diffs and history)
- File write access to `docs/agent-briefs/reports/`

## Worktree note
You can run from the main repo (`C:\dev\story-weaver-app`) since you are READ-ONLY. Do not write to any `lib/` or `test/` file. Only write your report to `docs/agent-briefs/reports/`.

## Files to triage

```
M lib/screens/wizard_steps/hero_creator_step.dart
M lib/screens/wizard_steps/imagine_it_screen.dart
M lib/story_result_screen.dart
M pubspec.lock
```

`pubspec.lock` is a generated file — note any noteworthy package version bumps but don't analyze it deeply.

## Steps

1. **For each `lib/` file**, run `git diff <file>` and read the change. Then read the surrounding context (the function/class containing the change) so you understand what the change is trying to do.

2. **Cross-reference recent commits** with `git log --oneline -20` to see if these changes look like the start of an in-progress feature, a half-revert, or stale leftovers. Look at `docs/sessions/` (the most recent 2–3 files) for what the dev was working on last.

3. **Check related memory entries** at `C:\Users\Darcy\.claude\projects\C--dev-story-weaver-app\memory\MEMORY.md` for any entries that reference these files or the features they touch (per_page_illustration, story result, hero creator, imagine_it, image generation, premium tiers).

4. **For each file, classify** as one of:
   - **Resume** — clearly in-progress work, has a coherent direction, just needs more time
   - **Stash** — non-trivial change but ambiguous intent; recommend `git stash` for safekeeping
   - **Discard** — looks like accidental edit, debugging leftover, or stale
   - **Commit-as-is** — looks complete, just was never committed

5. **Check for hidden coupling**: do the changes in `imagine_it_screen.dart` depend on changes in `hero_creator_step.dart`? Are they part of one logical change? If so, recommend committing together or not at all.

6. **Run `flutter analyze`** on the working tree (read-only operation) and capture any errors/warnings the in-flight changes introduce.

## Output

Write `docs/agent-briefs/reports/inflight_triage_<YYYY-MM-DD>.md` with this structure:

```markdown
# In-Flight Triage — <date>

## Recommended action
<One-line: "Commit X and Y together; stash Z; pubspec.lock is just dependency bumps">

## Per-file findings

### lib/screens/wizard_steps/hero_creator_step.dart
- **Diff size:** N lines (+A −B)
- **What it changes:** <one-paragraph plain-English summary>
- **Looks like:** <Resume / Stash / Discard / Commit-as-is>
- **Why:** <evidence — recent commits, session notes, code coherence>
- **Coupled to:** <other files in this list, or none>

### lib/screens/wizard_steps/imagine_it_screen.dart
... (same structure)

### lib/story_result_screen.dart
... (same structure)

### pubspec.lock
- **Notable bumps:** <list any package version changes worth flagging, or "none — routine">

## Analyze findings
<paste any errors/warnings from `flutter analyze` that come from these files; "clean" if none>

## Suggested commit groupings (if any are commit-as-is or resume-and-commit)
<bullet list of suggested commits with title + files>
```

Keep the whole report under 400 lines. Be specific about line numbers when something is unusual.

## Hard constraints — do NOT
- Do NOT modify any `lib/`, `test/`, or `pubspec*` file.
- Do NOT run `git add`, `git commit`, `git stash`, or any state-changing git command.
- Do NOT delete files (including the smoke_*.png debug screenshots in the repo root).
- Do NOT write anything to memory.
- Stay under 400 lines in the final report.

## Hand-off
After writing the report:
```
In-flight triage complete. Report: docs/agent-briefs/reports/inflight_triage_<date>.md
Recommended action: <paste one-liner from report>
```
