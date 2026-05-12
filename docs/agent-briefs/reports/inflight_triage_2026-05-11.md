# In-Flight Triage — 2026-05-11

## Brief vs reality
The brief lists `hero_creator_step.dart`, `imagine_it_screen.dart`, `story_result_screen.dart`, and `pubspec.lock` as the four files to triage. **These are all clean now** — they were committed between when the brief was authored and now (see commits `8bcfcd29`, `265c9a9f`, `b3973e12`, `01859be6`, `8ca74b0c`, etc.). The session prompt's `gitStatus` block was also a stale snapshot.

The **actual** uncommitted set right now is three different files (plus the harness lock):
```
M backend/gemini_image_generator.py
M backend/services/story_service.py
M lib/widgets/avatar_generating_view.dart
?? .claude/scheduled_tasks.lock   (harness scratch, ignore)
```
This report triages the actually-modified files, since that is what the developer needs to decide on.

## Recommended action
**Commit all three** as two separate commits — they are coherent, complete-looking, and each addresses a known-bad UX symptom. Suggested groupings at the bottom. None of them should be discarded; nothing needs a stash.

## Per-file findings

### backend/gemini_image_generator.py
- **Diff size:** 23 lines (+22 −1), one localized hunk at lines 241–265
- **What it changes:** Adds a sanitization pass on `scene_description` before it is interpolated into the Imagen prompt. Strips `*asterisk emphasis*` and lowercases ALL-CAPS onomatopoeia (`TINKLE TINKLE`, `STOMP-STOMP`) because Imagen treats those as "render this as visible text in the image" and produces gibberish words like "Willihrs litte leokied" / "Playbinbe". Also rewrites the prompt's leading paragraph from a single line ("SCENE (must be depicted literally)") into a much stronger ABSOLUTE-RULE block that explicitly says "ZERO readable text… no signs, no scrolls, no labels…" and re-frames quoted/capitalized words as sounds, not text.
- **Looks like:** **Commit-as-is**
- **Why:** Self-contained, the comment is a complete debugging story (symptom → cause → fix), `_re_visual` is locally aliased so it doesn't shadow the module's `re`, the existing "No text or words in the image" line at L286 already establishes the intent so this is a strengthening pass, not a contradiction. No tests reference these prompt strings (no `backend/tests/**/*gemini*` exists). Consistent with the team pattern of fixing Imagen text-rendering issues observed in recent illustration work.
- **Coupled to:** None of the other two. Pure backend illustration prompt change.

### backend/services/story_service.py
- **Diff size:** 53 lines (+45 −8), two hunks
- **What it changes:**
  1. **Lines 513–527 (`sprout_page_rule`):** Tightens the Sprout (≤5) page-count rule from "HARD MIN 5 pages, no max" to "between 8 and 12 pages (HARD MIN 8, HARD MAX 12)". The comment explains the regression: without a ceiling, models pad to 15+ pages, which is too long for a 3yo's attention span.
  2. **Lines 815–850 (`_safe_extract_title_and_gem` fallback):** Inserts a new "regex salvage" tier between the strict JSON-decode path and the dump-raw-text fallback. When the model emits malformed JSON, instead of dumping the entire raw response (with `image_prompt:` blobs and field names visible to the reader) as one giant page, it pulls `"text": "..."` strings out by regex, json-decodes each one independently to restore escapes, and returns them as proper pages. Only triggers when ≥2 `text` fields are recovered; otherwise falls through to the original raw-text fallback.
- **Looks like:** **Commit-as-is** (could split into two commits if you want clean history — see groupings below)
- **Why:**
  - The page-count tightening continues a clear arc (`e3e33a99 fix(sprout): tighten LTR validator…`, `add7e31b fix(sprout): rebalance non-LTR pages…`) and the comment naturally extends the existing comment block.
  - The regex salvage path is shape-compatible with the existing fallback: it returns the same 5-tuple `(title, None, body, pages, post_story={})` that the other two `return` statements at lines 855/859 use, and that callers in `backend/tasks/story_tasks.py:601,781` and `backend/tests/quality/run_story_quality.py:303` unpack as `title, _, story_body, pages, post_story`.
  - `import re` is already at module level (line 3), so the salvage code is just using the existing import — no new top-level deps.
  - Recent commit `4648d3ed fix(story-service): restore green test suite — word-range hyphen + delimiter test` shows the developer recently went through the test suite for this file, suggesting this work was the next step after that cleanup.
  - No existing test asserts the old "AT LEAST 5 pages" wording, so the prompt rewrite won't break tests (verified via `grep AT LEAST 5 pages` — zero hits across the repo).
- **Coupled to:** None of the other two. Pure backend story-generation change.

### lib/widgets/avatar_generating_view.dart
- **Diff size:** 45 lines (+28 −17), two hunks
- **What it changes:**
  1. **Lines 92–105 (`_flavorMessages[AgeBand.sprout]`):** Replaces the generic "Picking the perfect colors / Adding a sprinkle of magic" Sprout flavor strings with twelve egg-themed pun lines ("Tap the egg to help it hatch!", "Egg-cellent!", "Yolks!", "Sunny side up — almost hatched!", etc.). All other age-band flavor lists are untouched.
  2. **Lines 197–209 / 370–381 (`_tapCounterText`):** Refactors the inline nested-ternary tap-counter text into a method, and gives the Sprout band its own copy ("$N cracks!" instead of "$N sparkles!"). Other bands keep the existing sparkles wording.
- **Looks like:** **Commit-as-is**
- **Why:** The Sprout band already imports and uses `sprout_egg_hatch.dart` (line 8), so the new copy aligns the loading-screen text with the actual visual (an egg you tap to hatch). Previously the visual said "egg" and the text said "sparkles" — small but real UX inconsistency. The ternary-to-method refactor is mechanical and the only behavior change is the per-band branch. `flutter analyze lib/widgets/avatar_generating_view.dart` returns "No issues found!". No widget test asserts the old "$N sparkles!" string (only `loading_overlay_test.dart` uses a local `tapCount` int, unrelated).
- **Coupled to:** None of the other two. Pure Flutter copy/refactor change.

### pubspec.lock
- **Notable bumps:** N/A — `pubspec.lock` is **clean** in the current working tree. The brief's mention of it modified was based on the stale snapshot. `git status` confirms it is unchanged.

## Analyze findings
- `flutter analyze lib/widgets/avatar_generating_view.dart` → **clean** (no issues).
- Full project `flutter analyze` → 6 pre-existing issues, **none** in any of the three uncommitted files:
  - `lib/screens/byok_setup_wizard.dart:598` (use_build_context_synchronously, info)
  - `lib/screens/welcome_screen.dart:812 / 818 / 1007 / 1088` (4× unused_element / unused_element_parameter, warnings)
  - `lib/story_result_screen.dart:1044` (`_averageWordsPerPage` unused, warning — pre-existing in the committed file)
- Backend Python files were not analyzed (no equivalent linter invocation in scope), but spot-check shows imports are present and tuple shapes are consistent.

## Suggested commit groupings

Three independent areas, no cross-file coupling. Cleanest history is three small commits; minimum is two (combining the story_service hunks). All are appropriate to ship now.

- `fix(image-gen): strip ALL-CAPS onomatopoeia + asterisks from Imagen scene prompts` — `backend/gemini_image_generator.py`. Body: "Imagen renders capitalized SFX cues as visible text in the image, producing gibberish words. Lowercase loud words and remove `*emphasis*` before substitution; strengthen the no-text rule in the prompt header."

- `fix(sprout): cap page count at 8–12 + regex-salvage malformed story JSON` — `backend/services/story_service.py`. Or split into two: `fix(sprout): tighten page-count band to 8–12` and `fix(story-parser): regex-salvage malformed JSON instead of dumping raw text`.

- `chore(avatar-loading): align Sprout copy with egg-hatch visual` — `lib/widgets/avatar_generating_view.dart`. Body: "Sprout band shows an egg-hatch animation but the loading text said 'sparkles'. Switch to egg/crack puns and extract the tap-counter text into a per-band method."

Note: the harness file `.claude/scheduled_tasks.lock` is untracked scratch — leave it alone, never commit it.

## Other files relevant to the developer
- `C:\dev\story-weaver-app\docs\sessions\2026-05-11-1557-08f3.md` — most recent close-session record; useful context but unrelated to these three files.
- `C:\dev\story-weaver-app\docs\sessions\2026-05-11-1228-d6a5.md` — describes the earlier in-flight files that have since been committed.
