# Task 1 — Playwright Band 6 Re-verification (BUG-001)

**Model:** Sonnet
**Estimated effort:** 20–40 min

## Background

On 2026-04-20c, a Playwright QA sweep found **BUG-001**: the Adult band (Band 6) was blocked from creating a story because `_handleContinue()` in `lib/screens/wizard_steps/hero_creator_step.dart` required an avatar, but the mature-band form (`CreativeBriefWidget`) has no avatar UI. Every new adult user hit *"Please choose a look for your character first"* and could not proceed.

**Fix shipped in commit `73ee489` (on `main`):** skip the avatar gate when `AgeBand.isMature` is true (creator / adolescent / adult).

The fix has **not yet been verified end-to-end** against the live Railway build because the Playwright MCP lockfile required a Claude Code restart during the previous session.

Claude Code has since restarted, so Playwright MCP should be available.

## Your job

Re-run the Band 6 happy path via Playwright MCP and confirm the fix works in production.

## Target

- **URL:** `https://grand-light-production-68d9.up.railway.app`
- **Viewport:** 1400 × 900
- **Band:** Adult (18+)

## Happy path to execute

1. Navigate to the target URL.
2. Clear any prior state if a previous session is cached (consider an incognito-like fresh context).
3. Pass the COPPA age gate with **age 21** (or any 18+) to land in Adult band.
4. Open the story creation wizard.
5. In Hero Creator, fill in character name + age, and select a gender (Boy or Girl) via the `GenderImageButton`. **Do not** attempt to generate an avatar — the whole point is that mature bands don't expose one.
6. Tap **Continue**.

## Pass criteria

- ✅ No *"Please choose a look for your character first"* error banner.
- ✅ Wizard advances past Hero Creator to the next step.
- ✅ Full happy path through to `POST /generate-story` returning **200**.

## Fail criteria

- ❌ The banner still appears.
- ❌ Wizard stays stuck on Hero Creator.
- ❌ `/generate-story` returns non-200, or `CORS` / `403` errors appear.

## Reference files

- `lib/screens/wizard_steps/hero_creator_step.dart` — fix site (search for `isMatureBand`).
- `lib/theme/age_band_theme.dart:574` — `AgeBand.isMature` definition.
- `docs/QA_PLAYWRIGHT_REPORT_2026-04-20.md` — prior QA report format to mirror.
- `TEAM_COORDINATION.md` §2026-04-20c — previous session log with fix details.

## Deliverable

1. Append a **2026-04-21** entry to `TEAM_COORDINATION.md` — sub-section "BUG-001 re-verification". State pass/fail, the `/generate-story` status code, any console errors.
2. If PASS: mark BUG-001 as verified in place. If FAIL: open a new bug with root cause hypothesis.
3. Commit with `docs(team): log 2026-04-21 BUG-001 re-verification — <pass|fail>`.

## Notes

- If Playwright MCP still hits the Windows lockfile, see `memory/reference_playwright_mcp_lockfile.md` for recovery steps (another Claude Code restart may be needed).
- BUG-002 (TTS 429 backoff) and BUG-003 (Stripe anon guard) were also fixed analytically but not Playwright-verified. If you have time, spot-check: no TTS 429 storm in network log, no 403 on `/api/stripe/subscription-status/anon_*`.
