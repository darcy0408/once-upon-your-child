# Succession & Continuity Plan — Once Upon YOUR Child (Story Weaver)

Purpose: let a competent successor — or a recovered Darcy after a long break —
resume operating this product within days, not weeks. This is a resilience
document: fill the bracketed blanks, store the filled copy in a secure shared
vault (not in this repo), and review it quarterly.

Owner of record: Darcy (`darcy0408@gmail.com`)
Last reviewed: [DATE]
Vault location (filled copy + recovery codes): [e.g. 1Password "Story Weaver Continuity" vault]
Authorized second party (the trusted person who can recover access): [NAME / RELATIONSHIP / CONTACT]

---

## 0. Read-me-first (the 60-second map)

- Frontend: Flutter web on Cloudflare Pages (`onceuponyourchild.app`).
- Backend: Flask/gunicorn on Railway project `radiant-tranquility`
  (`36b27716-089f-4441-9b9d-af942a6df7aa`), service `story-weaver-app`.
- Workers: Celery worker `lovely-perfection` + dedicated `celery-beat` + Redis,
  all on the same Railway project.
- Database: Postgres on Railway (`cfbe4566-c0c2-4261-adc9-97654a8970f5`).
- Off-Railway backup: daily `pg_dump` to Cloudflare R2 (GitHub Action
  `postgres-backup.yml`, 09:00 UTC).
- Payments: Stripe (live). Subscriptions: Stripe is the source of truth.
- AI: Google Gemini (story+image) with OpenRouter / Cloudflare Workers AI /
  Replicate fallbacks; ElevenLabs -> Gemini -> Edge -> on-device TTS.

In-repo orientation files: `README.md`, `docs/PROJECT_STATUS.md`,
`TEAM_COORDINATION.md`, `docs/WORKTREE_WORKFLOW.md`, `railway.toml`,
`backend/.env.example`, `.github/workflows/`.

---

## 1. Credential & access inventory (fill, then store in the vault)

For each, record: account login email, MFA method, recovery email/phone, and
whether the authorized second party has access. NEVER store the values in this
repo; store them in the vault.

| Account | Login email | MFA | Recovery | 2nd party? |
|---|---|---|---|---|
| GitHub (darcy0408/story-weaver-app) | [ ] | [ ] | [ ] | [ ] |
| Railway (radiant-tranquility) | [ ] | [ ] | [ ] | [ ] |
| Cloudflare (Pages + R2 + Workers AI) | [ ] | [ ] | [ ] | [ ] |
| Stripe (live) | [ ] | [ ] | [ ] | [ ] |
| Google AI / Gemini | [ ] | [ ] | [ ] | [ ] |
| OpenRouter | [ ] | [ ] | [ ] | [ ] |
| ElevenLabs | [ ] | [ ] | [ ] | [ ] |
| Replicate | [ ] | [ ] | [ ] | [ ] |
| Resend (consent email) | [ ] | [ ] | [ ] | [ ] |
| Firebase | [ ] | [ ] | [ ] | [ ] |
| Sentry | [ ] | [ ] | [ ] | [ ] |
| Domain registrar | [ ] | [ ] | [ ] | [ ] |
| Apple Developer | [ ] | [ ] | [ ] | [ ] |
| Google Play Console | [ ] | [ ] | [ ] | [ ] |

Secrets that exist ONLY off-platform (record where each backup copy lives):

- `ENCRYPTION_KEY` (encrypts stored BYOK keys) — Railway env. Vault copy: [ ]
- `JWT_SECRET_KEY`, `SECRET_KEY` — Railway env. Vault copy: [ ]
- Android release keystore `.jks` + `key.properties` passwords — MUST be backed
  up off the dev machine. Vault copy: [ ] (currently NOT created — MT-144 open)
- Local `backend/.env` contents — Vault copy: [ ]
- GitHub Actions repo secrets (RAILWAY_TOKEN, CLOUDFLARE_API_TOKEN,
  CLOUDFLARE_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET,
  R2_ACCOUNT_ID, DATABASE_PUBLIC_URL) — re-issuable from each vendor. Vault: [ ]

---

## 2. Scenario playbooks

### 2a. Darcy unavailable 1 DAY (planned or minor)

What breaks: nothing automatically. The stack self-heals — Railway restarts on
failure, fallbacks cover provider blips. No action needed unless an alert fires.

Second party needs: read access to Sentry + Railway dashboards to confirm green.
Action: acknowledge any P1 alert (payment failure, full outage); otherwise wait.

### 2b. Darcy unavailable 1 WEEK

What keeps running: story generation, payments, backups, retention purge — all
automated. What degrades: nothing time-critical within a week.
What needs a human:

- A failed nightly Postgres backup (no failure alert exists today — check the
  GitHub Actions "Postgres Backup" run list every few days).
- A Stripe webhook failure (log-only today — check Stripe dashboard for failed
  events).
- A provider outage that exhausts all fallbacks (Sentry `static_fallback`).

Second party needs: Sentry + Railway + Stripe + GitHub Actions read access, and
this document. They do NOT need to deploy.

### 2c. Darcy unavailable 1 MONTH

Everything in 2b, plus:

- Renew the domain if it lapses (check registrar auto-renew NOW so it can't).
- Rotate any key that hits a provider expiry/quota.
- Triage the manual-task backlog only if a launch deadline depends on it.

Second party needs: the full vault, ability to log into each vendor, and the
deploy runbook (Section 3). A competent engineer can hold steady state with
read access alone; changes require the vault.

### 2d. Darcy unavailable INDEFINITELY (handover to a successor)

The successor must be able to (a) keep prod alive, (b) deploy fixes, (c) restore
from backup, (d) own the vendor relationships. Steps:

1. Transfer ownership of the GitHub repo (ideally to an org), Railway project,
   Cloudflare account, Stripe account, and the domain. Each is a per-vendor
   transfer — start them in parallel.
2. Hand over the vault (Section 1) and verify every login + MFA works.
3. Hand over the Android keystore `.jks` and its passwords — without these, no
   future Play Store update is possible.
4. Walk the deploy runbook (Section 3) end to end once on a no-op change.
5. Run the restore drill (Section 4) once to prove data recoverability.

---

## 3. Deploy-from-scratch runbook (new engineer, repo only)

Goal: stand the whole stack back up from the repo + the vault.

1. Provision Railway project; add Postgres + Redis plugins (DATABASE_URL and
   REDIS_URL auto-set).
2. Backend service from `Dockerfile`; start command per `railway.toml`
   (`gunicorn wsgi:app --bind 0.0.0.0:$PORT --timeout 120 --workers 2`).
3. Celery worker service from `Dockerfile.worker`
   (`celery -A backend.celery_config.celery worker --pool=solo`).
4. Celery-beat as its OWN service from `Dockerfile.worker`
   (`celery ... beat`). Beat is NOT embedded in the worker (`-B` is
   incompatible with `--pool=solo`) — without a separate beat service the daily
   COPPA retention purge never fires.
5. Set Redis URLs on worker + beat via Railway `${{Redis.REDIS_URL}}` (these are
   commented placeholders in `railway.toml` — they MUST be set in the UI).
6. Set backend env from `backend/.env.example`: required `GEMINI_API_KEY`,
   `JWT_SECRET_KEY`, `SECRET_KEY`, `ENCRYPTION_KEY`; recommended Stripe/Sentry/
   Resend/Cloudflare/OpenRouter keys. Prod fails loud if required secrets are
   absent (`backend/config/__init__.py`).
7. Frontend: Cloudflare Pages "Direct Upload" project named
   `once-upon-your-child`; add repo secrets `CLOUDFLARE_API_TOKEN` +
   `CLOUDFLARE_ACCOUNT_ID`; add custom domain `onceuponyourchild.app`; CI deploys
   `build/web` on push to `main` (`.github/workflows/cicd.yml`).
8. Re-add all GitHub Actions repo secrets (Section 1) so CI + backup work.
9. Stripe: set live keys, `STRIPE_WEBHOOK_SECRET`, price IDs; point the webhook
   endpoint at the backend. Rotation steps: `docs/RUNBOOK_STRIPE_WEBHOOK_SECRET_ROTATION.md`.
10. Verify `/health`; run an end-to-end story generation.

Undocumented manual steps to capture as you go (these are NOT in the repo today):
Cloudflare Pages project creation, R2 bucket + token creation, Stripe webhook
endpoint wiring, domain DNS cutover, and the Android keystore creation.

---

## 4. Backup & disaster recovery

- Backup: `postgres-backup.yml` dumps Postgres to R2 daily at 09:00 UTC
  (RPO up to 24h). Verified to upload ~31 MB dumps (MT-220).
- RESTORE IS NOT DOCUMENTED OR TESTED. Do a drill: download the latest
  `postgres/story-weaver-pg-YYYY-MM-DD.sql.gz` from R2, `gunzip`, and
  `psql "$DATABASE_PUBLIC_URL" < dump.sql` into a fresh Postgres; confirm row
  counts. Record the measured restore time here as the real RTO: [ ].
- Redis: ephemeral; re-provision and reconnect. No restore needed.
- Stripe: subscription state is reconstructable from Stripe itself.
- Secrets: only recoverable from the vault — see Section 1.

"Prod down, founder unreachable" runbook for the second party:

1. Check `https://onceuponyourchild.app` and the backend `/health`.
2. Railway dashboard -> service -> Deployments -> Logs; restart the failed
   service (restart policy usually self-heals).
3. If Postgres is the problem, restore from the latest R2 dump (above).
4. If a provider is down, confirm fallbacks engaged in Sentry; no action if so.
5. Escalate to the successor named at the top of this document.

---

## 5. Quarterly resilience checklist

- [ ] Vault current; every login + MFA verified working.
- [ ] Android keystore exists AND is backed up off the dev machine.
- [ ] Domain auto-renew on; expiry > 60 days out.
- [ ] Restore drill run in the last 90 days; RTO recorded.
- [ ] At least one authorized second party has working access to each
      Critical account.
- [ ] This document and `docs/PROJECT_STATUS.md` updated.
