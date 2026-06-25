# Soft-Launch Checklist — Once Upon YOUR Child

**Goal:** open the **kids' bands (Sprout 3-5, Explorer 6-8, Adventurer 9-12)** to a
small, invited group — **free, no payments, no public listing**. This is the
shortest safe path to real users. Everything heavier (teen band, Stripe,
trademark) is deliberately deferred below.

> The hard engineering is already done and verified: backups proven restorable,
> AI providers locked to OpenAI/Cloudflare (Gemini fail-safe), consent
> disclosures synced, security review clean. What's left is mostly Railway clicks.

---

## A. Railway — set values + Deploy  ⏱️ ~15 min  · 🚩 BLOCKING

In Railway → project `radiant-tranquility` → service `story-weaver-app` →
**Variables**. Type the **Name** in one box and the **Value** in the other —
**do not type the `=`**.

| Name | Value | Why |
|------|-------|-----|
| `COPPA_REQUIRE_VERIFIED_CONSENT` | `true` | Turns the under-13 consent gate from "built" to "enforced" — your biggest legal item |
| `DISABLE_GEMINI_IMAGE` | `1` | Belt-and-suspenders: avatars can never fall back to Gemini (forbidden for kids) |

Then click **Deploy**.

**Confirm these are already present (no action if they are):**
- `OPENAI_API_KEY` — story text + avatars (present, since stories work)
- `AZURE_SPEECH_KEY` / `AZURE_SPEECH_REGION` — TTS (present)
- `REDIS_PRIVATE_URL` **or** `REDIS_URL` — the code accepts either ✅
- `CELERY_BROKER_URL` + `CELERY_RESULT_BACKEND` — both same Redis URL ✅ (story worker)
- `CELERY_TASK_ALWAYS_EAGER` — should be `false` or absent (NOT `true`) in prod

---

## B. Continuity — generate + stash the encryption key  ⏱️ ~5 min  · not blocking

Only used once someone saves a BYOK key server-side (not in free mode), but set
it now so it's never a surprise.

1. In a **normal PowerShell window** (not the chat): `python -c "import secrets; print(secrets.token_hex(32))"`
2. Paste that 64-character line into Railway as `ENCRYPTION_KEY`.
3. **Also paste it into a Google Doc** in the account your Google Inactive
   Account Manager is attached to — IAM only hands your sons what's *inside*
   Google, and this key is **not re-issuable** if lost.

---

## C. Verify it works — Claude can do this for you

- Deploy went green · prod `/health` ok · a kids'-band story generates
  end-to-end on the live site · COPPA gate actually blocks under-13.

---

## D. Deliberately deferred — NOT needed for this launch

- **Adolescent 15-17 antihero band** — leave it off; the clinical sign-off only
  matters when you turn it on. Kids' bands don't use that mechanic.
- **Stripe go-live** — skip; this launch is free.
- **Trademark clearance** — skip; no public store listing / paid ads yet.

---

## Already done (no action)

- ✅ Daily Postgres backups → R2, **proven restorable** (restore drill: RTO ~2s)
  + failure alerts
- ✅ Story text on OpenAI GPT-5 mini; illustrations on Cloudflare; avatars on
  OpenAI — Gemini retired from the kids' data path, with a code-level fail-safe
- ✅ Consent screen synced to the privacy policy (correct vendor disclosures)
- ✅ Security review: no critical issues (auth/IDOR, Stripe webhooks, prompt
  injection, child-PII scrubbing, CSP/CORS all solid)
