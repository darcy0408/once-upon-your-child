# Manual Tasks

Single global backlog of items only Darcy can resolve (production verification, browser-only tests, deletes, decisions, credential steps, restarts).

**Append-only with monotonic IDs.** Sessions add new tasks at the bottom and close existing ones in place. Never renumber.

## Status legend

- `open`     — waiting for Darcy
- `done`     — completed (note the closing session ID)
- `wontfix`  — superseded, no longer relevant, or rejected
- `blocked`  — waiting on something other than Darcy (note what)

## How sessions update this file

When closing a session:

1. **Closing existing tasks**: find each `MT-NNNN` you resolved, change `open` → `done`, append `(closed by <session-id>)` to the line.
2. **Adding new tasks**: append at the bottom under `## Open tasks`. Look at the last 10 open tasks first to avoid dupes — if your task already exists, reference its existing ID in your session record instead of adding a new one.
3. **ID generation**: take the highest existing `MT-NNNN`, add 1. Pad to 3 digits.

## Open tasks

<!-- New tasks appended below. Format: `- **MT-NNN** [open] description (created by <session-id>) — context.` -->
- **MT-002** [open] Archive or migrate the 11 legacy SESSION CLOSE blocks in TEAM_COORDINATION.md (created by a488) — they sit below the new Recent Sessions table and inflate the file (~4.5k lines). Either move to `docs/archive/TEAM_COORDINATION_pre-2026-04-22.md` or convert each into a `docs/sessions/<date>-<time>-<id>.md` retro-record. Low priority — fine to leave for now; revisit when the file becomes painful to scroll.
- **MT-001** [open] Clean ~70 untracked PNG screenshots from repo root (created by a488) — `after-*.png`, `hat-*.png`, `verify-*.png`, `bug001-*.png`, `byok-*.png`, `coppa-gate.png`, `fresh-landing.png`, etc. Either `git clean -f` after backing up anything to keep, or add a glob pattern to `.gitignore` (e.g. `/*.png`) so future QA artefacts don't pollute the repo root. Confirmed across multiple session-close logs as a recurring noise source.
- **MT-003** [open] Smoke-test BUG-012 error responses (created by 76e3) — hit `/tts/synthesize` and `/generate-story` with bad inputs; confirm JSON responses show `STORY_FAILED`/`TTS_FAILED` codes and friendly copy, not raw Python exception text (commit `d081266`).
- **MT-004** [open] Flutter error string grep for BUG-012 follow-up (created by 76e3) — run `grep -r "Story generation failed\|Synthesis failed\|Transcription failed" lib/` and update any Flutter UI copy that pattern-matches old error strings now superseded by structured codes from `d081266`.
- **MT-005** [open] BUG-001 browser confirm (created by c29c) — open production in incognito, select 18+ age band, enter a name, tap any archetype card, tap "Create Story". Verify it advances past Hero Creator. Code is correct (`GestureDetector` + `onTap` at `lib/screens/wizard_steps/hero_creator_creative_brief.dart:368`); this is final confirmation to formally close BUG-001.

## Closed tasks

<!-- Sessions move tasks here when status flips to `done` or `wontfix`. Most recent at top. -->
