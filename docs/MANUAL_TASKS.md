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
- **MT-006** [open] Fix Recent Sessions table insertion order (created by a488) — the marker comment sits at the *bottom* of the table body and the awk inserts *above* it, so new rows accumulate newest-at-bottom despite the marker saying "most recent at top". Fix: move the marker to sit immediately after the `|---|---|...|` separator row, and flip the awk in `close-session.md` so it prints the matched line first then the new row (insert *after* the marker). Existing rows can stay where they are — Date/Time columns still make order readable. Purely cosmetic.
- **MT-007** [open] Verify BYOK wizard on production web (created by d1c2) — open BYOK wizard, paste a real `AIza…` key, confirm text is visible (white on dark card `0xFF120226`), tap Finish, confirm key saves correctly, then tap "Full illustrations" elsewhere and confirm wizard does NOT relaunch at step 0. Changes in `62b09a6`; backend proxy validation in `b8f8009` (`api_key_routes.py:142`).
- **MT-008** [open] Visual confirm archetype image grid for mature bands (created by 8a9d) — open app in incognito, select age 18+ (adult), 15–17 (adolescent), and 12–14 (creator) in turn. After entering name, scroll to CORE ARCHETYPE section in the brief. Confirm 2×2 image grid appears (not text chips), images match selected gender, and gold border appears on tap. Playwright blocked (lockfile); code verified with `flutter analyze` only. Commit `aac7a5d`.
- **MT-009** [open] Verify BUG-003 fix in production (created by c4ea) — open production in incognito (no account), reach the subscription screen or trigger any subscription check. Confirm no 403 errors appear in DevTools Network tab. Fix is `StripeService.getSubscriptionStatus()` early-return for `anon_` users (`lib/services/stripe_service.dart`), deployed in commit `6d71454` / Railway deployment `b33e04b9`.
- **MT-010** [open] Investigate stale-JWT 403 for real user (created by c4ea) — during BUG-002 TTS session, saw Stripe 403 for `user_c4b28920-cdb0-495d-ba08-db4197a09369` (non-anon). Backend returns 403 instead of 401 for expired/invalid JWT. Check auth middleware — should return 401 so Flutter can trigger re-auth rather than silently failing.

- **MT-011** [open] BUG-002 TTS backoff runtime verification (created by 2571) — fresh Claude Code instance required (so --isolated in .mcp.json activates). Follow docs/briefings/TASK3_BUG002_TTS_FRESH_SESSION.md: age 8 Explorer band, network-filter /tts/, wait 60 s, verify 429 count bounded (<=4 per phrase) and retry spacing shows backoff curve (~2 s, ~4 s, ~8 s). Manual fallback: Chrome DevTools Network tab. BUG-001 browser confirm already tracked as MT-005.
- **MT-012** [open] Age-gate consolidation audit (created by 7df8) — `welcome_screen.dart` and `age_gate_screen.dart` diverge in behavior; users aged 13–17 on the welcome path may not record COPPA consent correctly. Assign to Opus — risky refactor touching compliance logic. Entry point: `lib/screens/welcome_screen.dart:998` (`_handleContinue`) and `lib/screens/age_gate_screen.dart`. Prior session notes flagged this as highest remaining HIGH item.

## Closed tasks

<!-- Sessions move tasks here when status flips to `done` or `wontfix`. Most recent at top. -->
- **MT-005** [open] Verify gender picker images in Railway across all 6 bands (created by 247a) — after deploy, open the adult wizard (and at least one younger band) and confirm the correct Boy/Girl placeholder art shows at each age band. Sprout should show chibi characters; explorer chibi girl; adventurer silhouette kids; creator teen silhouettes; adolescent cyberpunk girl + blue teen boy; adult dark silhouettes. Commit bf94b8b.
- **MT-011** [open] Decide fate of `test_archetypes.mjs` at repo root (created by 8972) — one-off Playwright script verifying archetype images across Adult/Adolescent/Creator bands. If reusable, move to `tools/` or `test/e2e/` and commit. Otherwise delete. Has been untracked since at least 2026-04-21.
