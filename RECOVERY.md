# RECOVERY — Emergency Runbook & Credential Vault Structure

The front door for two situations: **production is down**, or **the founder is
unavailable** and someone has to keep Story Weaver / "Once Upon YOUR Child"
alive. Closes the P0-A bus-factor gaps in [`LAUNCH_READINESS.md`](LAUNCH_READINESS.md)
(continuity audit `audit-reports/13-continuity-20260607.md`).

> **Security:** this file is a *structure and instruction* template. It contains
> **no secret values** and must never contain any. Real credentials live only in
> the vault described in Section 2. Fill the bracketed `[ ]` blanks in your
> private copy, not here.

Owner of record: Darcy (`darcy0408@gmail.com`)
Designated contacts / inheritors: **[your three sons — NAMES / CONTACTS]** — none need to be technical. Name **all three** as access-holders (redundancy: if one is unreachable, the others can act), and pick **one as the lead** for keep/sell/shut-down decisions so a three-way call can't deadlock. Their job is to *hold access* and either keep the bills paid or hand it to a hired developer to run or sell. The app is theirs to inherit (Section 7 letter).
Lead son (decision-maker): **[NAME]**
Vault: **[e.g. 1Password "Story Weaver Continuity" vault — currently does not exist]**
Last reviewed: **[DATE]**

Deeper material lives in the continuity audit's
[`audit-reports/succession-plan-template.md`](audit-reports/succession-plan-template.md)
— the 1-day / 1-week / 1-month / indefinite playbooks, the deploy-from-scratch
runbook, and the quarterly checklist. This file is the crisis index + vault spec;
it does not repeat those.

---

## 1. Emergency quick-actions

### Prod is down
1. Check `https://onceuponyourchild.app` (frontend) and the backend `/health`
   (`https://story-weaver-app-production.up.railway.app/health`).
2. Railway dashboard → project `radiant-tranquility` → the failed service →
   Deployments → Logs. Restart the service (restart policy usually self-heals).
3. Postgres broken? → restore from the latest R2 dump (Section 4).
4. A provider (Gemini/OpenRouter/ElevenLabs) down? Confirm fallbacks engaged in
   Sentry (`static_fallback` signal). If fallbacks are working, **no action** —
   the app degrades, it does not break.
5. Still down → escalate to the authorized second party / successor.

### Locked out of an account
1. Use the recovery email / phone / TOTP-backup recorded in the vault item
   (Section 2) for that account.
2. No vault yet, or no second party? That is the failure this document exists to
   prevent — see Section 3 and fix it **before** an incident.

### Founder unavailable
Go to `succession-plan-template.md` Section 2 and pick the matching scenario
(1 day / 1 week / 1 month / indefinite).

---

## 2. Vault structure (build this — ~1 hour, highest-leverage fix)

Create one vault — **"Story Weaver Continuity"** (1Password, Bitwarden, or
equivalent) — and point a **dead-man's-switch** at your sons so nothing depends on
anyone noticing you're gone:

- **Password-manager Emergency Access** (free in Bitwarden, included in
  1Password): nominate all three sons; if you don't respond within a delay you
  set (e.g. 14 days), access releases to them automatically. None need technical
  skill — only to receive the vault and forward it to a developer they hire.
- **Google Inactive Account Manager** (free, in your Google account): after a
  chosen period of inactivity (3–18 months) Google notifies them (up to 10
  contacts) and can share access or delete the account. Set this up today — it
  needs no one but you.

The incentive is honest: the app and its accounts are **theirs to inherit**
(Section 7). They keep the ~monthly bills paid to hold the asset, or hand it to a
hired developer to run or sell. Then create these vault items.

### 2a. Account logins (one Login item each)
Per item record: login email · password · TOTP/MFA seed · MFA backup codes ·
recovery email/phone · "second party has access? Y/N".

- [ ] GitHub (`darcy0408/story-weaver-app`)
- [ ] Railway (project `radiant-tranquility`)
- [ ] Cloudflare (Pages + R2 + Workers AI) — **concentration risk: holds the frontend AND the only off-Railway backup**
- [ ] Stripe (live)
- [ ] Google AI / Gemini
- [ ] OpenRouter
- [ ] ElevenLabs
- [ ] Replicate
- [ ] Resend (consent email)
- [ ] Firebase / Google
- [ ] Sentry
- [ ] Domain registrar (**[which one? not discoverable from the repo — record it]**)
- [ ] Apple Developer (if/when iOS)
- [ ] Google Play Console (if/when Android)

### 2b. Secret values (Secure Note or Password items)
These are the env vars the app needs. Names below are the exact keys
(`backend/.env.example`, `backend/config/__init__.py`).

| Secret (env var) | Primary location | Re-issue if lost | Vault |
|---|---|---|---|
| `ENCRYPTION_KEY` | **NOT SET in prod yet** (found 2026-06-07; MT-231) | When you set it (before BYOK server-storage launches), back it up the instant you create it — once keys are stored with it, it is NOT re-issuable. | [ ] |
| `JWT_SECRET_KEY` | Railway backend env | Re-generate (`secrets.token_hex(32)`); invalidates all sessions | [ ] |
| `SECRET_KEY` | Railway backend env | Re-generate | [ ] |
| `GEMINI_API_KEY` (+ `_2/_3/_4` rotation) | Railway | Re-issue at Google AI Studio | [ ] |
| `STRIPE_SECRET_KEY` (alias `STRIPE_API_KEY`) | Railway | Roll in Stripe dashboard | [ ] |
| `STRIPE_WEBHOOK_SECRET` | Railway | Re-create webhook endpoint; see `docs/RUNBOOK_STRIPE_WEBHOOK_SECRET_ROTATION.md` | [ ] |
| `STRIPE_PRICE_ID_PREMIUM` / `_FAMILY` | Railway | Read from Stripe products | [ ] |
| `RESEND_API_KEY` + `CONSENT_EMAIL_FROM` | Railway | Re-issue at Resend; domain must stay verified | [ ] |
| `SENTRY_DSN` | Railway / client build | Read from Sentry project settings | [ ] |
| `OPENROUTER_API_KEY` | Railway | Re-issue at OpenRouter (also unblocks the L-AI-01 ToS fix, `STORY_GEN_PROVIDER=openrouter`) | [ ] |
| `ELEVENLABS_API_KEY` / `REPLICATE_API_TOKEN` | Railway | Re-issue at vendor | [ ] |
| `CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_API_TOKEN` | Railway + GH Actions | Re-issue at Cloudflare | [ ] |
| `DATABASE_URL` / `REDIS_URL` | Auto-set by Railway plugins | Recreated with the plugin | n/a |
| Local `backend/.env` (full file) | Dev machine only | — | [ ] copy it |

### 2c. GitHub Actions repo secrets (re-issuable, but record them)
`RAILWAY_TOKEN`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`,
`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_ACCOUNT_ID`,
`DATABASE_PUBLIC_URL`. → [ ]

### 2d. Document items
- [ ] **Android release keystore** `.jks` + `key.properties` passwords —
  **currently does not exist (MT-144). Create it, then store the only off-machine
  copy here.** Without it, no future Play Store update is possible.
  Runbook: `docs/ANDROID_KEYSTORE_RUNBOOK.md` (+ `android/key.properties.example`).
- [ ] Filled copy of `succession-plan-template.md`.
- [ ] This `RECOVERY.md`, filled.

---

## 3. The gaps this closes (status)

| Gap | State today | This kit's fix |
|---|---|---|
| No emergency credential vault | None exists | Section 2 |
| No one can recover access | No designated contact | Your three sons inherit it; grant all three password-manager Emergency Access + Google Inactive Account Manager (Section 2), with one named as lead. Non-technical is fine. |
| `ENCRYPTION_KEY` recoverable only from Railway | Single copy | Vault item 2b |
| Android keystore never created | MT-144 open | Create + store (2d) |
| Restore never tested, no DR runbook | — | Section 4 + drill |
| `docs/env_vars_reference.md` was missing | Broken pointer in `.env.example` | **Fixed** — now written |

---

## 4. Backup & restore drill (do once, record the RTO)

- **Backup:** `postgres-backup.yml` dumps Postgres → Cloudflare R2 daily 09:00
  UTC (RPO ≤ 24h). Confirmed uploading ~31 MB dumps (MT-220). There is **no
  failure alert** — until one exists, eyeball the GitHub Actions "Postgres
  Backup" run list every few days.
- **Restore (untested — prove it):** run **`scripts/restore-drill.ps1`** — it
  downloads the latest dump, restores into a throwaway Docker Postgres, checks
  row counts, and prints the measured RTO. Or manually:
  1. Download the latest `postgres/story-weaver-pg-YYYY-MM-DD.sql.gz` from R2.
  2. `gunzip` it.
  3. `psql "$DATABASE_PUBLIC_URL" < dump.sql` into a **fresh** Postgres (not prod).
  4. Confirm row counts; record the measured restore time as the real RTO: **[ ]**.
- Redis: ephemeral — re-provision, no restore. Stripe: subscription state is
  reconstructable from Stripe. Secrets: only recoverable from the vault.

---

## 5. Minimum viable bus-factor (do this week)

Most of this needs **no other person and no money** — do the no-person items
first; they cover the pre-launch worst case on their own.

No-person, free, today:
1. Turn on **Google Inactive Account Manager** + **password-manager Emergency
   Access**, both pointed at all three sons, with one named lead (Section 2).
2. Confirm **billing auto-renew** is ON for the domain + Railway on a card that
   won't expire — a lapsed bill is what actually kills idle solo projects.
3. Back up `ENCRYPTION_KEY`, `JWT_SECRET_KEY`, `SECRET_KEY`, and `backend/.env`
   into the vault (`ENCRYPTION_KEY` is the one that is **not** re-issuable).
4. Run the restore drill once (Section 4); write down the RTO.
5. Create the Android keystore (MT-144) and store its only off-machine copy.

One conversation, when you're ready:
6. Give your sons the **letter of instruction** (Section 7) and fill the
   top-of-file blanks + `succession-plan-template.md`; store filled copies in the
   vault.

That sequence converts the "unrecoverable / weeks" SPOFs from the continuity
audit into "days". Re-check quarterly (`succession-plan-template.md` Section 5).

---

## 6. Graceful shutdown (if no one continues it)

The honest floor for a children's app: if nobody picks this up, the right outcome
is not to leave kids' data sitting at ten vendors forever — it is a clean
wind-down. Whoever holds access (your sons, or a developer they hire) can run
this; it needs the vault, not deep expertise.

1. **Take the app offline** so no new data is collected: in Cloudflare Pages,
   disable the `onceuponyourchild.app` deployment (or remove the custom domain).
2. **Delete the user data.** With backend access, the data-retention purge already
   exists: it deletes every user's children's data and anonymises the records
   (`backend/services/data_retention.py`, `purge_inactive_accounts`). A developer
   can run it across all accounts; the erasure also best-effort-deletes Stripe
   customers. If the backend is already down, deleting the Railway **Postgres**
   service destroys the live store.
3. **Delete the off-site backups** in Cloudflare R2 (the `postgres/` dumps) so no
   children's data persists there.
4. **Cancel paid subscriptions** in Stripe (refund any active subscribers if
   funds allow) and stop the recurring vendor bills (Railway, Cloudflare,
   ElevenLabs, OpenRouter, Resend, domain).
5. **Revoke API keys** at each provider so nothing can be billed afterward.

This is a legitimate, responsible ending — not a failure. Documenting it is part
of taking children's data seriously.

---

## 7. Letter of instruction (copy out, fill, give to your sons)

Plain-English, no legal jargon. This is not a substitute for a will, but it tells
the people you trust what this is and what to do. Keep the filled copy with the
vault. *(General information, not legal advice — if you later want it formal, a
simple will or a low-cost / legal-aid clinic can do it cheaply.)*

```
To: my sons — [name], [name], and [name]
From: Mom/Dad (Darcy)
Date: [date]

If you're reading this, something has happened to me and I'm trusting the three
of you with a small software business I built: "Once Upon YOUR Child" (a
storytelling app for kids). I'm leaving it to you, together.

WHO DECIDES
- All three of you can get into the accounts (so it never depends on one person
  being reachable). To keep decisions simple, [lead son's name] has the final
  say on whether to keep it, sell it, or shut it down — but talk it over.

WHAT IT IS
- A website/app at onceuponyourchild.app, plus the accounts that run it.
- It may have paying customers and a few dollars of monthly running costs.

HOW TO GET IN
- Open the password vault: [where it is / how the Emergency Access works].
- Everything you need — every login, password, and recovery code — is in there,
  with a file called RECOVERY.md that explains the rest.

YOU HAVE THREE CHOICES — ALL ARE OKAY
1. KEEP IT RUNNING: pay the monthly bills (the vault shows which) and hire a
   developer to maintain it. RECOVERY.md explains the setup so any competent
   developer can take over from the code alone.
2. SELL IT: a working app + domain + customers has value. A developer or a small
   "micro-acquisition" marketplace can help you sell it. Proceeds are yours to
   split.
3. SHUT IT DOWN: if it's not worth the trouble, follow "Graceful shutdown"
   (Section 6 of RECOVERY.md) so the children's data is deleted properly and the
   bills stop. This is a completely fine choice.

WHAT MATTERS MOST
- It handles children's data. If you wind it down, make sure that data is
  actually deleted (Section 6) — that part is important to me.
- Don't feel obligated to keep it alive out of guilt. Keep it only if it's worth
  something to you.

Thank you, all three of you. — [signature]
```

Fill the brackets, store it in the vault, and tell them once that it exists and
where. That single conversation is the whole "second party" plan.
