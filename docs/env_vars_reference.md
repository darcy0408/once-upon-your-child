# Environment Variables Reference

Authoritative list of the environment variables the backend reads, where to set
them, and how to obtain each. Referenced from `backend/.env.example` (which has
the same variables with inline comments). Resolution lives in
`backend/config/__init__.py`.

- **Local dev:** put them in `backend/.env` (gitignored).
- **Production:** set them in Railway → service `story-weaver-app` → **Variables**.
- **CI / backups:** a few live in GitHub → Settings → Secrets and variables → Actions (see the bottom table).
- Back up the production values to the continuity vault — see [`../RECOVERY.md`](../RECOVERY.md) §2.

Tiers: 🔴 Critical (app won't boot/work) · 🟡 Recommended (a feature degrades without it) · 🟢 Optional (sensible default exists).

## 🔴 Critical

| Variable | Purpose | How to get it |
|---|---|---|
| `JWT_SECRET_KEY` | Signs auth tokens. | `python -c "import secrets; print(secrets.token_hex(32))"` |
| `SECRET_KEY` | Flask session/CSRF secret. | same generator as above |
| `GEMINI_API_KEY` | Story + image generation (Google Gemini). | Google AI Studio → API keys |
| `DATABASE_URL` | Postgres connection. | **Auto-set** by the Railway Postgres plugin |
| `FLASK_ENV` / `ENV` / `FLASK_CONFIG` | Selects the config class (development/production/testing). | set to `production` in Railway |

## 🟡 Recommended

| Variable | Purpose | How to get it |
|---|---|---|
| `ENCRYPTION_KEY` | Encrypts a user's BYOK Gemini key when stored server-side (`encryption_utils.py`). **Currently UNSET in prod — server-side BYOK key-save errors until set (MT-238).** | `python -c "import secrets; print(secrets.token_hex(32))"`; set in Railway and back it up the instant you create it (not re-issuable once keys are stored with it) |
| `STRIPE_SECRET_KEY` (alias `STRIPE_API_KEY`) | Payments. | Stripe dashboard → API keys (`sk_live_…`) |
| `STRIPE_WEBHOOK_SECRET` | Verifies Stripe webhooks. | Stripe → Webhooks → signing secret (`whsec_…`); rotation: `docs/RUNBOOK_STRIPE_WEBHOOK_SECRET_ROTATION.md` |
| `STRIPE_PRICE_ID_PREMIUM`, `STRIPE_PRICE_ID_FAMILY` | Subscription price IDs. | Stripe → Products |
| `REDIS_URL` | Celery broker / rate limiting. | **Auto-set** by the Railway Redis plugin |
| `SENTRY_DSN` | Crash reporting. | Sentry → project settings |
| `OPENROUTER_API_KEY` | Image-gen + the ToS-compliant story-text path (`STORY_GEN_PROVIDER=openrouter`, MT-171/L-AI-01). | openrouter.ai → keys |
| `RESEND_API_KEY` + `CONSENT_EMAIL_FROM` | Sends the under-13 COPPA parental-consent email. **Without it, under-13 signups can't complete.** | resend.com → API keys; `CONSENT_EMAIL_FROM` must use a Resend-verified domain |
| `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN` | Workers AI (default Flux Schnell illustration provider). | dash.cloudflare.com → My Profile → API Tokens → Workers AI template |
| `ELEVENLABS_API_KEY` | TTS narration (top tier of the fallback chain). | elevenlabs.io |
| `REPLICATE_API_TOKEN` | Avatar gen + Flux Schnell illustration fallback. | replicate.com |

## 🟢 Optional (defaults exist)

Model + provider: `GEMINI_MODEL` (`gemini-2.0-flash`), `GEMINI_MODEL_FREE`,
`STORY_GEN_PROVIDER` (`gemini`|`openrouter`|`auto`), `OPENROUTER_PAID_MODEL`,
`OPENROUTER_FREE_MODEL`.

Timeouts: `SYNC_STORY_TIMEOUT_SECONDS`, `SYNC_STORY_TIMEOUT_PER_COMPANION_SECONDS`,
`SYNC_STORY_TIMEOUT_MAX_EXTRA_SECONDS`, `GEMINI_REQUEST_TIMEOUT_SECONDS`,
`GEMINI_IMAGE_REQUEST_TIMEOUT_SECONDS`, `AVATAR_PHOTO_ANALYSIS_TIMEOUT_SECONDS`.

Kill-switches / toggles: `CLOUDFLARE_FLUX_DISABLED`, `FLUX_SCHNELL_DISABLED`,
`DISABLE_GEMINI_IMAGE`, `TTS_DISABLED`, `MOCK_TESTING_MODE`.

Billing / compliance: `STRIPE_TRIAL_DAYS` (14), `COPPA_REQUIRE_VERIFIED_CONSENT`
(false in tester phase; set **true** for launch — CMP-2/MT-166),
`COPPA_REQUIRE_CURRENT_POLICY_VERSION` (false; CMP-10),
`DATA_RETENTION_INACTIVE_DAYS` (730 — auto-purge window; needs Celery beat).

## Dev / tooling only (present in Railway, not app-critical)

`GITHUB_API_KEY`, `CONTEXT7_API_KEY` (MCP/dev tooling), `DEBUG`.

## GitHub Actions secrets (CI + backups)

Set in **Settings → Secrets and variables → Actions**. Used by
`postgres-backup.yml` and the deploy/CI workflows:

`DATABASE_PUBLIC_URL`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`,
`R2_BUCKET`, `RAILWAY_TOKEN`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

> Note: this file documents variable **names and sources only** — never commit
> actual values. Production values belong in Railway + the continuity vault.
