# Red Hat — Intuition & Risk Signals

Story Weaver security audit, 2026-05-16. Gut-level signals — code smells, blurred trust boundaries, "feels wrong" patterns. Not all are confirmed vulnerabilities; several were later confirmed in the Black Hat pass.

## Strongest signals

- **Marketing copy outran engineering.** "Your key/photo never leaves your device — we never see it" appears in the privacy policy, the consent screen, the kid-summary screen, and the BYOK wizard — and the network code contradicts all of it. Privacy claims read as written by product without engineering verification. Treat every privacy assertion in the app as unverified until code-checked. → confirmed C-1, H-5.

- **Two of everything.** Two auth stacks (`PyJWT` vs `flask_jwt_extended`, differing claim names and blocklist handling); two quota systems (Redis daily vs DB `*_this_month` columns) measuring the same thing; two "am I in prod?" signals (`RAILWAY_ENVIRONMENT` vs `FLASK_ENV`); historically two `SubscriptionService` classes. Each pair is a classic "fixed it in one place, not the other" defect source. → confirmed M-1, M-17.

- **"Fail open" is the house style.** `ai_quota.py` returns `allowed=True` on any Redis error; `moderate_story_content` returns `(True,"")` on any exception; JWT revocation silently no-ops if Redis is down. The controls protecting cost and child safety switch themselves off exactly when infrastructure is unhealthy. → confirmed M-2, M-4.

- **The highest-consequence surface is the least-guarded.** The custom-avatar flow combines a real minor's uploaded photo with unvalidated free text, yet `validate_prompt_safety` is wired only to the *non-photo* avatar path. → confirmed C-3.

- **Allowlist-by-omission.** `sanitize_story_request` protects a named set of fields; any field not on the list is unprotected by default. `worldBible`/`conflictHook`/`sensoryPalette` already slipped through. New free-text fields will too. → confirmed H-4.

## Other signals

- Test scaffolding ships to production: `/setup-test-account` and `generate-avatar-mock` sit on always-registered blueprints. → confirmed H-1.
- Interactive story mode was clearly retrofitted — it got keyword filtering but never the LLM classifier or the prompt sanitizer the main path has. Uneven safety coverage between story modes. → confirmed H-3, M-4.
- Tier label and paid price are decoupled in the Stripe flow — the webhook trusts a metadata string over the money actually charged. Works today only because one route keeps them in lockstep. → confirmed H-2.
- Client counters that only ratchet up — `FeatureUnlockService` adopts the backend count only if it is *higher*, never lower. The server can grant but never revoke. → confirmed M-8.
- Boot-time DDL — raw `ALTER TABLE` auto-migrations run at every worker boot, swallowing all errors as "non-fatal." Schema drift can pass silently.
- `_resolve_age` caps maturity only for accounts flagged under-13; a 13–17 account self-declares any age in the request body. → confirmed M-6.
- Out-of-order Stripe webhook delivery is unhandled — `past_due`/`active`/`canceled` applied blindly in arrival order with no timestamp guard. → related M-3.
- `delete_user_data` anonymizes the account but does not revoke outstanding 24h JWTs — a "deleted" account keeps working.
- `_avatar_generate_counts` is an unbounded in-process dict on `current_app`, never pruned — slow memory growth.
- Real child first names + emotional/therapeutic data flow to four external APIs with no pseudonymization. → confirmed M-7.
- Consent screen is heavily gamified with child-directed TTS coaching ("Ask a grown-up to unlock your magical adventure!") — blurs the line between child UX and a parent-only legal gate. Regulators view this unfavorably.
- Onboarding appears skipped in `main.dart` (`build` returns `StoryCreatorApp()` directly); the consent flow lives downstream — verify no build variant lands a child in story creation without passing the gate.

## Housekeeping smells
- `saved_stories_screen.dart.temp` — stale backup source committed to the tree.
- `nixpacks.toml` + Dockerfile `CMD` + `railway.toml` startCommand — three sources of truth for how the backend boots; `nixpacks` sets `--log-level debug`.
- `.gitignore` is 277 lines of accreted patterns — easy for a future `.env`-like file to slip through; the gitleaks hook is the real backstop.
- `requirements.in` has bare `Pillow` with no version floor — only the lockfile pins it.
- Dependabot config comments say "PAUSED" — automated dependency updates may not be running.
- `celery_config.py` silently falls back to an in-process `memory://` broker if `REDIS_URL` is unset — a misconfigured deploy would run with no real broker and no error.
