# Privacy Policy v3 — Draft Additions (G-4, G-7, G-8, G-10)

**Status:** DRAFT — not published. Route past counsel with the external-review batch
(per `docs/COPPA_AMENDED_RULE_GAP_ANALYSIS.md` Part 3 sequencing, step 4).
**Drafted:** 2026-07-07 (Fable session). **Closes (when published):** G-4 (retention
schedule), G-7 (direct-notice statements), G-8 (identifiers enumeration), G-10
(biometric-category language).

**Publish procedure (do these together, AFTER the §2b.6 flip in
`docs/LAUNCH_CRITICAL_PATH_2026-07-06.md` has settled):**

1. Apply the three sections below to `PRIVACY_POLICY.md` as described in each
   "Placement" note.
2. Mirror the two G-7 statements onto the consent screen (short versions provided
   in §2b below) — policy and consent screen are duplicate disclosures that must
   not drift (policy is source of truth).
3. Bump `CURRENT_POLICY_VERSION` to 3 in `backend/models/consent_record.py`.
4. Update the Effective Date at the top of `PRIVACY_POLICY.md`.

Every timeline below is the **verified current behavior of the code as of
2026-07-07** (`backend/services/data_retention.py`, `backend/tasks/retention_tasks.py`,
`.github/workflows/postgres-backup.yml`) — nothing here is aspirational. If an env
var override changes a window in prod, update the table before publishing.

---

## 1. Data Retention Schedule (G-4)

**Placement:** replaces the existing "Data Retention" section of `PRIVACY_POLICY.md`
in its entirety.

---

## Data Retention Schedule

We keep personal information only as long as we need it to run the app, and we
delete it on a schedule. We never keep children's personal information
indefinitely. The table below lists each kind of data we hold, why we collect it,
why we keep it, and when it is deleted.

| What we hold | Why we collect it | Why we keep it | When it is deleted |
|---|---|---|---|
| **Account & profile data** (parent/guardian email, username, age range, preferences) | To create and secure your family's account | Needed for sign-in, parental controls, and required parental notices for as long as you use the app | Deleted when you delete your account; deleted automatically after **2 years** with no activity |
| **Characters & avatars** (character names, customization choices, the cartoon avatar image) | To create your child's personalized characters | Kept so your child's characters persist between stories | Deleted when you delete your account or the character; deleted automatically after **2 years** of account inactivity |
| **Stories & story inputs** (story text, themes, goals, any "big feelings" text, optional parent-provided context) | To generate and save your child's personalized stories | Kept so your family can re-read saved stories | Same as above — account deletion or the **2-year** inactivity purge |
| **Child photos** (optional photo-avatar feature) | To generate a cartoon avatar, only if a parent opts in | **Not kept.** The photo passes through our system to the AI image provider and is never stored on our servers | Never stored; it exists only for the moments needed to generate the avatar |
| **Parental consent records** (who consented, when, to which policy version) | Federal law (COPPA) requires verifiable parental consent | Kept as proof that consent was given, for as long as the account exists | Deleted when you delete your account |
| **Consent verification codes** (the emailed code, stored only in scrambled/hashed form) | To verify a consent email round-trip | Only needed during verification | Expire after **15 minutes**; removed with the account on deletion |
| **Parent email from an unfinished consent request** | To send the consent verification email | Only needed while the consent request is pending | If consent is not completed within **30 days**, the email address is automatically deleted |
| **Cached story illustrations** (a shared image cache; entries are keyed by story details, not by account, and use a stand-in token instead of your child's real name) | To avoid regenerating identical illustrations (keeps the app fast and affordable) | An image is useful only while stories that use it are being read | Any cached image not used for **365 days** is automatically deleted |
| **Payment information** | To process subscriptions | Handled by Stripe — we never store full card details on our servers | Our subscription records are removed with account deletion; Stripe's retention is governed by Stripe's own policy |
| **Crash & error diagnostics** (technical error reports, scrubbed of message content) | To find and fix bugs | Only useful while recent | Retained by our error-monitoring service (Sentry) for its standard **90-day** window, then deleted |
| **Encrypted backups** (a rolling copy of our database) | To recover from data loss or disaster | A short backup history is required to restore service after a failure | Each backup is automatically deleted after **30 days** |

**How deletion works.** When you delete your account (Parent Controls → Data &
Privacy → Delete All My Data, or by emailing us), your child's stories,
characters, consent records, and profile data are deleted immediately and your
account is anonymized. Because our encrypted backups roll over every 30 days,
deleted data also disappears from all backups within **30 days** of your deletion
request. Backups are used only for disaster recovery — we do not read individual
accounts back out of them.

---

## 2. Direct-notice statements (G-7) — policy text + consent-screen mirror

### 2a. Policy text

**Placement:** add both paragraphs to the end of the "Children's Privacy" section
of `PRIVACY_POLICY.md`.

> **Consent to collection is separate from consent to sharing.** Under COPPA you
> may consent to our collecting and using your child's information without also
> consenting to its disclosure to outside parties. We do not disclose your
> child's personal information to outside parties at all, with one narrow
> exception that is integral to making the app work: the service providers listed
> in the Third-Party Services section (for example, the AI provider that writes
> the story text). These providers act only on our instructions, receive only the
> minimum data needed for their task, and are prohibited from using it for their
> own purposes, including training their AI models. If we ever wanted to share
> your child's information in any other way, we would ask for your separate
> consent first.
>
> **If you don't finish giving consent, we delete your contact information.** If
> you begin the parental-consent process but do not complete it within a
> reasonable time, we delete the contact information we collected from you to
> obtain consent: specifically, a parent email address captured for consent
> verification is automatically deleted after **30 days** if consent has not been
> verified.

### 2b. Consent-screen mirror (short versions — keep in sync with 2a)

**Placement:** consent screen, alongside the existing vendor-list disclosure.
Policy is source of truth; these are condensed, not different.

> Your consent covers our collection and use of your child's information, and
> sharing it **only** with the service providers that make the app work (listed
> below) — they may not use it for anything else, including AI training. We never
> share it with anyone else without asking you separately.

> If you don't complete this consent within 30 days, we automatically delete the
> email address you gave us for it.

---

## 3. Identifiers we create and why (G-8)

**Placement:** new subsection in `PRIVACY_POLICY.md`, immediately after the
"Cookies and Tracking" section.

---

### Identifiers We Create and Why

Before any account is set up — and before parental consent — the app creates a
small number of random identifiers so it can function at all. COPPA permits this
only for "support for internal operations," and requires us to tell you exactly
what those operations are. Here is the complete list:

- **An account identifier** (a random ID like `anon_…`): keeps your child signed
  in and connects them to their own stories and characters, and to nothing else.
- **A device installation identifier** (a random ID created on your device):
  lets the app remember its own settings and sync subscription status.
- **Crash-report identifiers**: let our error-monitoring service group technical
  error reports about the same bug together.

These identifiers are random — they contain no personal information — and we use
them **only** for the purposes above: keeping your child signed in, syncing your
subscription, monitoring errors and stability, and protecting against abuse. We
do **not** use them to build a profile of your child, to target advertising (we
show no ads), to track your child across other apps or websites, or to make any
inference about your child's behavior. Usage analytics are switched off entirely
for all users under 18, regardless of consent.

---

## 4. Biometric-category language (G-10) — one-sentence addition

**Placement:** append to the existing "Photo avatars (optional)" paragraph in the
Third-Party Services section of `PRIVACY_POLICY.md`. `[legal]` — sanity-check this
sentence with counsel; it is deliberately conservative.

> Because a photo of your child's face is sensitive (COPPA treats face imagery as
> biometric-category personal information), this feature is off by default, works
> only with your explicit opt-in, and the photo is never stored, never used to
> identify your child, and never used for any purpose other than generating that
> one cartoon avatar.

---

## Open items before publish (owner / counsel)

- [ ] Counsel review of §2a wording ("integral to the service" framing) and §4 `[legal]`
- [ ] Confirm no prod env var overrides the coded defaults (`DATA_RETENTION_INACTIVE_DAYS`,
      `ILLUSTRATION_CACHE_RETENTION_DAYS`, `UNCONSENTED_CONTACT_MAX_DAYS`) — table says 730/365/30
- [ ] G-3 dependency: §2a's "prohibited from using it … including training their AI models"
      must be contractually true before publish — i.e., the OpenAI DPA + ZDR (MT-318) is
      **executed first**. The sentence is the whole point of that paperwork; do not publish v3 ahead of it
- [ ] Sequencing: publish only after the `COPPA_REQUIRE_CURRENT_POLICY_VERSION` flip has
      settled (avoid two re-prompt waves) — then bump `CURRENT_POLICY_VERSION` to 3
