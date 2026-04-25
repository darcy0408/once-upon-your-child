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
- **MT-005** [done] BUG-001 browser confirm (created by c29c) — `POST /generate-story → 200` confirmed, story rendered, no avatar gate banner. (closed by QA-2026-04-24)
- **MT-006** [open] Fix Recent Sessions table insertion order (created by a488) — the marker comment sits at the *bottom* of the table body and the awk inserts *above* it, so new rows accumulate newest-at-bottom despite the marker saying "most recent at top". Fix: move the marker to sit immediately after the `|---|---|...|` separator row, and flip the awk in `close-session.md` so it prints the matched line first then the new row (insert *after* the marker). Existing rows can stay where they are — Date/Time columns still make order readable. Purely cosmetic.
- **MT-007** [open] Verify BYOK wizard on production web (created by d1c2) — open BYOK wizard, paste a real `AIza…` key, confirm text is visible (white on dark card `0xFF120226`), tap Finish, confirm key saves correctly, then tap "Full illustrations" elsewhere and confirm wizard does NOT relaunch at step 0. Changes in `62b09a6`; backend proxy validation in `b8f8009` (`api_key_routes.py:142`).
- **MT-008** [done] Visual confirm archetype image grid for mature bands (created by 8a9d) — 2×2 image grid confirmed for Adult, Adolescent, Creator; gold border on tap confirmed for all 3 bands. (closed by QA-2026-04-24)
- **MT-009** [done] Verify BUG-003 fix in production (created by c4ea) — zero `subscription-status/anon_*` calls observed across all phases; anon guard working. (closed by QA-2026-04-24)
- **MT-010** [open] Investigate stale-JWT 403 for real user (created by c4ea) — during BUG-002 TTS session, saw Stripe 403 for `user_c4b28920-cdb0-495d-ba08-db4197a09369` (non-anon). Backend returns 403 instead of 401 for expired/invalid JWT. Check auth middleware — should return 401 so Flutter can trigger re-auth rather than silently failing.

- **MT-011** [done] BUG-002 TTS backoff runtime verification (created by 2571) — backoff curve confirmed active (no storm, dedup working); retry cap >4 per phrase still hit. Retry cap fix (`_maxPrewarmRetries = 4` in `app_tts_service.dart:~147`) tracked as separate follow-up. (closed by QA-2026-04-24)
- **MT-012** [open] Age-gate consolidation audit (created by 7df8) — `welcome_screen.dart` and `age_gate_screen.dart` diverge in behavior; users aged 13–17 on the welcome path may not record COPPA consent correctly. Assign to Opus — risky refactor touching compliance logic. Entry point: `lib/screens/welcome_screen.dart:998` (`_handleContinue`) and `lib/screens/age_gate_screen.dart`. Prior session notes flagged this as highest remaining HIGH item.

- **MT-013** [open] BUG-002 retry cap code fix (created by QA-2026-04-24) — add `const _maxPrewarmRetries = 4;` guard to `_prewarm()` loop in `lib/services/app_tts_service.dart:~147`. ~5-minute change. Runtime QA confirmed backoff works but bursts hit 4–5 retries vs ≤4 target; hard cap is the missing piece.
- **MT-014** [open] MT-007 BYOK runtime verify (created by QA-2026-04-24) — code fix confirmed correct (`_showKey=true`, white text on `0xFF120226`). Darcy needs to test manually with a real `AIza…` key on a BYOK-subscribed account: paste key, tap Finish, confirm `POST /api/user/settings/validate-api-key → 200`, then trigger "Full illustrations" and confirm wizard does NOT relaunch.

## Closed tasks

<!-- Sessions move tasks here when status flips to `done` or `wontfix`. Most recent at top. -->
- **MT-005** [done] Verify gender picker images in Railway across all 6 bands (created by 247a) — all 6 bands confirmed: Sprout (chibi), Explorer (child), Adventurer (silhouette), Creator (teen), Adolescent (png), Adult (portrait). (closed by QA-2026-04-24)
- **MT-011** [open] Decide fate of `test_archetypes.mjs` at repo root (created by 8972) — one-off Playwright script verifying archetype images across Adult/Adolescent/Creator bands. If reusable, move to `tools/` or `test/e2e/` and commit. Otherwise delete. Has been untracked since at least 2026-04-21.
