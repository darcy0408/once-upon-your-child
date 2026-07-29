# Visual audit at phone width — wizard, reader, Pick-a-Path, Bedtime Mode

**Date:** 2026-07-29
**Method:** live production app (`onceuponyourchild.app` / `once-upon-your-child.pages.dev`, same build), driven with Playwright at a 360×740 viewport via synthetic pointer events. Every screen was rendered and looked at, not code-read. One single-shot story and one two-turn interactive adventure were generated against prod (adult band, anonymous user) as part of the walkthrough.
**Coverage:** the four surfaces named by the owner, **adult (18+) band only**. The under-13 variants sit behind the COPPA email-verification wall and are audited separately once a verification code is available. Screens NOT covered: Hero Saga, coloring, library, chronicles, young-band everything.
**Companion audits:** `audit_report.md` (2026-07-18, code-reading — found zero visual bugs by construction), `audit-reports/ux-walkthrough-20260715.md`.

## Confirmed fixed in prod (from the 2026-07-25 + 2026-07-28 fixes)

- Bedtime voice chips are solid indigo and readable — single-chip and 4-chip layouts both verified (this was the owner's "invisible white blocks" screenshot). "Exit Bedtime Mode" legible.
- Pick-a-Path prose renders white-on-dark, readable.
- Adult wizard + review step ("Ready to begin?") clean and readable at 360px; hint text at the new `hintOnDark`.
- Voice Story Settings sheet (bedtime launch) clean.

## New findings, ranked

### P0

**F1 — Pick-a-Path choice buttons truncate to one unreadable line (8+/adult path).**
All three choices render single-line with ellipsis: *"Step into the library's doorway and ask the arc…"*. The user cannot read what they are choosing — on both the first segment and after a continue. The ≤7 path wraps (`pick_a_path_adventure_screen.dart:1318` has no maxLines), so the truncation lives in the older-band choice widget — locate before fixing. This is the owner's original screenshot bug, still live.

**F2 — Adult single-shot story ignored the hero's name (n=1, verify prompt intent before fixing).**
Wizard: name "Darcy", archetype Kinetic Specialist; review card confirmed "Darcy / The Lightning Runner". Generated story: protagonist **"Rin"**, Darcy never mentioned. The interactive path used "Darcy" correctly moments later, so this is specific to the adult single-shot prompt/path. Personalization is the entire product promise. Could conceivably be a deliberate adult-band "literary" choice — check `prompt_service` adult builder before treating as a bug, but the review step promising "Darcy" makes the current behavior wrong either way.

**F3 — Create Story with a missing required field silently scroll-jumps to top; required selection is silently reset.**
Reproduced twice: with CORE ARCHETYPE unset, tapping Create Story scrolls to the form top with **no error message, no field highlight**. Feels exactly like "the button is broken." Compounding it: "New Story with Darcy" (post-story reset) preserves name/gender but silently clears the archetype, so the second story always trips this. Fix = visible validation error + scroll to the *offending field* + don't clear the archetype on reset.

### P1

**F4 — Raw "Choices: 1) … 2) … 3) …" leaked into interactive prose.**
Turn 2's story body ended with the literal choice list, which then ALSO rendered as buttons — the same text twice, once as unformatted prose. PR #454-class leak on the interactive continue path; the single-shot stripper (`_strip_attempt_labels` family) evidently doesn't cover the interactive segment builder's choice block.

**F5 — Consent "Send Verification Email" gives zero feedback on failure.**
Observed via a CORS-blocked request (localhost origin), but the code path is the same for any network failure a real parent hits: the button does nothing — no spinner, no error, no retry hint. This is the single most critical funnel step in the app (COPPA consent). Success does navigate to "Check your email", so only the failure branch is silent.

**F6 — Reader pager arrows/counter are phantom UI (MT-381a confirmed live at 18+).**
Tapping → advanced the label "1/12" → "2/12 Page 2" while the visible content did not change; the story actually reads by scrolling, and the counter still said 2/12 at the end card. Ship-blocker-adjacent for perceived quality: the visible control does nothing.

**F7 — End-of-story rating renders 4 of 5 stars pre-filled with no user input.**
Either a default rating is being persisted (data corruption for any rating analytics) or the empty state renders as 4 stars (looks rated). Check which; both are wrong.

### P2

- **F8** — End card is cream parchment + gold stars inside the dark adult theme (MT-381f/MT-388 confirmed live at 18+).
- **F9** — Loading screen at 18+: kid-purple card inside navy adult theme, headline "Your adventure is being written…" is low-contrast purple-on-purple, and "Catch the sparkles! ✨" shows for a band whose `particleCount == 0` — there are no sparkles to catch (MT-388 confirmed; the contrast point is new).
- **F10** — Duplicate CTA stacks at story end: end card has New Story with Darcy / Start Fresh / My Chronicles; the persistent footer below repeats New Story with Darcy / Start Fresh. Two identical actions visible twice on one 360px screen.
- **F11** — Interactive screen has no leave guard and no resume: the top-left back arrow silently discards a mid-adventure (two turns lost). MT-382b's missing-resume confirmed; the missing guard is the sharper half.
- **F12** — Interactive top-bar title truncates to "The …" at 360px — effectively no title.
- **F13** — Hero creator preselects **Girl** before any input (seen in the owner's screenshot too, so it's a default, not a tap). Verify intent; an unselected default is the neutral choice.
- **F14** — Bedtime at 18+ offers kid companions (Thunder Wolf, Crystal Phoenix…). Band-appropriateness; arguably fine for bedtime, noting for the MT-388 chrome pass.

## Standing caveats

- Adult band only; every finding needs a young-band recheck once consent is passable (F1's younger sibling path *wraps*, for instance).
- Single generation per path — F2 and F7 are n=1 observations.
- TTS/audio behavior not audited (no audio assertions in this harness).
