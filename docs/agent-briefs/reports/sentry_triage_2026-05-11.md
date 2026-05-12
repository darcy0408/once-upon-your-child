# Sentry Triage — 2026-05-11

## TL;DR
- Total unresolved (last 14 days): **1** (Flutter: 1, Backend: 0)
- Total unresolved (all time, all ages): **1** — same single issue
- Sentry org has **only one project** (`story-weaver`, platform: javascript). No separate Python backend project is registered. Either the Railway backend is not wired to Sentry, or its DSN points at a different org we cannot see.
- Top cluster: **other / dev-tooling noise** (1 issue, 0 users impacted)
- Critical now: **Nothing critical.** The only open issue is a dev-environment-only error from Flutter's `dwds` (Dart Web Debug Service) injected client. Real user impact is zero.

## Top 5 issues — fix first

### 1. TypeError: Cannot read properties of null (reading 'removeChild')
- **Cluster:** other (dev tooling / Flutter web hot-reload)
- **Impact:** 33 events, **0 users**, first seen 2026-03-07, last seen 2026-05-11 04:36 UTC
- **Status:** unresolved, substatus: **regressed**
- **Environment:** `development` (every event tagged `environment:development`)
- **Release:** `story_weaver_app@1.0.0+1`
- **Top frame (first-party):** `main.dart.js:71:22 (HTMLDocument.<anonymous>)`
- **Origin frames (third-party, Flutter web dev server):** `/dwds/src/injected/client.js` — Dart Web Debug Service injected client
- **Mechanism:** `auto.browser.global_handlers.onerror`, `handled: no`
- **Seer proposed fix:** ❌ Unavailable — Seer API returned **HTTP 402: "No budget for Seer Autofix"**. Top up the Seer budget at https://story-weaver.sentry.io/settings/billing/ to re-enable automated analysis on this report.
- **Manual hypothesis:** `dwds` (Dart Web Debug Service) injects a client script into the page when running `flutter run -d chrome` / dev web build. When the page tears down (hot restart, tab close, navigation) `dwds`' communication channel calls `removeChild` on a DOM node whose parent has already been detached. This is a **known class of dev-time noise from the Flutter web tooling**, not a production bug. Recommended action is to **filter `environment:development` out of the Sentry project's inbound filters / SDK `beforeSend`** rather than to "fix" the code.
- **Sentry link:** https://story-weaver.sentry.io/issues/STORY-WEAVER-5
- **Trace:** `ff7d371c369e4924b5fc2647caf4ce3c`

### 2–5. (none)
No other unresolved issues in the org. Cannot populate slots 2–5.

## By cluster

### Avatar
*(no Sentry issues)*

### Image-gen (Flux Schnell / Gemini Image / OpenRouter routing)
*(no Sentry issues)*

### Stripe
*(no Sentry issues — the known-broken checkout flow that omits `user_id` is not throwing telemetry; it silently no-ops in webhooks)*

### Prefetch (per-page illustration prefetcher)
*(no Sentry issues — the recently added failure circuit-breaker may already be suppressing what would have been errors)*

### BYOK premium tier
*(no Sentry issues)*

### Other
- **STORY-WEAVER-5** — 33 events — `main.dart.js:71` / `dwds/src/injected/client.js` — Flutter web dev-tooling `removeChild` on null parent; dev-only.

## Noise / low priority
- **STORY-WEAVER-5** qualifies — 0 user impact, dev environment, third-party origin. Suggested actions:
  1. Add an inbound filter in Sentry: drop events where `environment:development`, OR
  2. In `lib/main.dart` Sentry init, set `options.environment` strictly and add a `beforeSend` that returns `null` when `event.tags['mechanism'] == 'auto.browser.global_handlers.onerror'` AND the top frame matches `dwds/src/injected/client.js`, OR
  3. Resolve and archive in Sentry, accept that it will regress on every dev session.

## Coverage gaps to flag

These are not in the report's required schema but matter for next steps:

1. **Backend not visible.** The brief assumes a Python backend on Railway also reports to Sentry. The `story-weaver` org has exactly one project, platform `javascript` (Flutter web). Confirm whether:
   - The Railway backend has `sentry-sdk` initialized and pointed at a DSN, AND
   - That DSN belongs to this `story-weaver` org (and therefore should be visible here), or to a different account.
2. **Mobile coverage unclear.** The single project's platform is `javascript`, but the release pattern `com.storyweaver.story_weaver_app@1.0.0+1` (visible via `find_releases`) suggests a native Android/iOS build artifact also reports to the same project. Worth verifying `sentry_flutter` is initialized on mobile builds and that crashes flow to the same project.
3. **Seer budget exhausted.** No automated root-cause analysis available until the budget is replenished. This report's hypothesis on STORY-WEAVER-5 is manual.
4. **Very low event volume overall.** 1 issue / 33 events in 14 days is suspiciously quiet for an app with multiple in-flight risky changes (avatar, image-gen, Stripe). Either:
   - The app has very few real users right now (consistent with solo-dev pre-launch state), OR
   - Errors are being swallowed before they reach Sentry (try/catch without `Sentry.captureException`, or `sentry_flutter` not initialized on all entry points).
