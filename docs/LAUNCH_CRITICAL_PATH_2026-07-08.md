# Launch Critical Path — 2026-07-08 (reconciliation)

**Why this exists:** the owner lifted the launch pause on 2026-07-08. Before
touching any production config, this doc verifies every P0 gate from
`docs/LAUNCH_CRITICAL_PATH_2026-07-06.md` and `LAUNCH_READINESS.md` (07-03)
against **live Railway config + current code**, not doc text — both priors
explicitly warned their own lists rot within 48 hours, and ~15 PRs landed
between 07-06 and today. Verified via direct Railway CLI query (values not
printed, presence/state only) + 3 parallel code-verification passes,
2026-07-08.

**Bottom line:** no P0 gate is 100% code-and-ops-done, but the code side is
in much better shape than either prior doc knew. Two genuinely open code
gaps were found that neither doc had (or had mis-stated). Everything else
remaining is owner action — env flips, a pre-flight query, and three
external/contractual items that were already open and still are.

---

## Already CLOSED — verified today, don't re-open

| Item | Evidence |
|---|---|
| `ENCRYPTION_KEY` set in prod | Railway CLI, presence-checked. Contradicts LAUNCH_READINESS.md gate #6 ("not set at all today") — that was true 07-03, false now. MT-238 marked done. |
| `DISABLE_GEMINI_IMAGE=1` set in prod | Railway CLI. Gate #5 from the 07-03 doc — closed. |
| `ALLOW_DIRECT_GEMINI_IMAGE` unset in prod | Railway CLI — confirmed correct (stays unset). |
| `_kSkipEmailConsent` flip | `lib/screens/parental_consent_screen.dart:28` — `const bool _kSkipEmailConsent = !kReleaseMode;` — already `false` in any real release build automatically. Not a manual flip; verify the Cloudflare Pages build uses `--release` (standard, near-certain) and drop this as a separate gate. |
| Crisis detection on all free-text fields | PR #388 (merged 07-06) added `_crisis_guard()` covering `custom_elements`, `hero_secret/tell/line`, `therapeutic_prompt` on `/generate-story` and `/generate-antihero-crux` (`backend/routes/story_routes.py:379-400, 825-836, 1223-1234`). Was open in the 07-06 doc; closed since. |
| Consent-forgery holes (verified-consent + age-redeclaration bypass) | PR #387 (merged 07-06) forces `POST /consent` to `verified=False` unconditionally, locks `PATCH /age` against upward re-declaration. This was the code prerequisite blocking MT-166's flip — now satisfied. |
| Antihero red-team findings F-1..F-8 | PR #390 (07-07) found them, PR #402 (07-08) fixed all: real server-side age gate (`ANTIHERO_CRUX_ENABLED`, defaults OFF), egress scrub, grooming screen (`confidant_screen.py`), trusted-adult mandate, broadened crisis-net + Childhelp hotline. Ledger flipped in #404. |
| Async 202 story-delivery path | PR #393 (07-07) — a launch blocker (mature-band stories that overran the sync window silently never completed) that **neither prior doc knew existed**. MT-335, done. |
| Stripe webhook idempotency | Real dedup table + unique constraint since **2026-05-17** (`backend/routes/webhook_handler.py:152-223`) — the 07-06 doc mislisted this as an open "go-live check." It's done and has been for weeks. |
| G-7 unconsented-contact deletion job | Already exists: `purge_unconsented_parent_contact` (`backend/services/data_retention.py:414`). The gap register the 07-06 doc pointed at was wrong. |

---

## Genuinely OPEN — code (new findings, neither prior doc had these right)

| # | Gate | Evidence | Recommendation |
|---|---|---|---|
| C1 | **Photo-avatar opt-in not enforced** | `backend/routes/avatar_routes.py` never checks `allow_photo_avatar` (`consent_record.py:41`) before generating a photo avatar. All 6 avatar endpoints gate only on "consent exists," not on the specific photo-avatar flag. An under-13 whose parent declined photo-avatar consent (but granted general consent) can still get one generated. | Fix before real users — this breaks a promise the consent screen makes. Small, isolated (mirror the pattern `require_parental_consent` already uses). |
| C2 | **Child/companion PII logged at INFO in Celery worker** | `backend/tasks/story_tasks.py:1749` logs the full rhyme-time prompt *before* the real-name scrub at :1792; `:1815-1817` and `:1578-1579` log companion names/ages at INFO, unscrubbed. Root Flask logger is WARNING (`app.py:22-23`) but the Celery worker process has no explicit level override — INFO suppression is a deploy-config assumption, not guaranteed. | Fix before real users — Railway log retention would otherwise hold child PII. Cheap (redact or demote to DEBUG). |

---

## Genuinely OPEN — owner/external (unchanged or newly sequenced)

| # | Gate | Status | Action |
|---|---|---|---|
| O1 | `COPPA_REQUIRE_VERIFIED_CONSENT=true` | Unset on Railway. Code prereq (consent-forgery) now closed via #387 — **ready to flip**. | MT-166. |
| O2 | `ENFORCE_RESOLVED_AGE=true` | Unset on Railway. Prerequisite PR #361 already merged — **ready to flip**. | MT-310 item 3. |
| O3 | `COPPA_REQUIRE_CURRENT_POLICY_VERSION=true` | Unset on Railway. `CURRENT_POLICY_VERSION=2` still (not bumped). **NOT ready to blind-flip** — run the prod Postgres pre-flight count of consent rows with version `NULL`/`<2` first so the re-prompt wave size is known. | MT-174 item 4. |
| O4 | Privacy Policy v3 publish + version bump to 3 | Draft complete: `docs/PRIVACY_POLICY_V3_DRAFT.md` (added 07-07) has the retention table (G-4), both R-2 sentences (G-7), and the identifiers paragraph (G-8) the old gap register wanted. Live `PRIVACY_POLICY.md` still v2. Needs owner/counsel review + publish. **Sequence after O3** to avoid two re-prompt waves. | MT-330. |
| O5 | OpenAI DPA + confirm Zero Data Retention | Still open, `docs/OPENAI_DPA_ZDR_COMPLIANCE.md` unchanged, no completion markers. Contractual, owner-only. | MT-318. |
| O6 | Clinical sign-off, adolescent antihero band | Still open (MT-266c). Note: even with #402's real server-side gate landed, `ANTIHERO_CRUX_ENABLED` defaults OFF — the band stays off until the clinician signs AND the owner flips the flag. Packet ready: `docs/CLINICAL_REVIEW_ADOLESCENT_ANTIHERO.md`. | MT-266. |
| O7 | External legal review — COPPA consent mechanics + retention/deletion completeness | Still open, unchanged. | Route per `docs/SAFETY_AUDIT_REMEDIATION.md`. |
| O8 | Advisory clinician naming + kidSAFE quote | Still open (MT-320); outreach sent, no reply as of 07-07. **Not a launch gate** — trust/positioning only. | MT-320. |
| O9 | Azure Speech free→Pay-As-You-Go | Trial lapses ~2026-07-14. Calendar reminder set 2026-07-09. Hard date. | MT-259. |

---

## Not a launch gate but worth knowing

- **MT-350** (filed 07-08, PR #408 audit): IAP receipt verification backend is a stub (`NotImplementedError`) — real gap for the **mobile-store track (L4)**, not the web/Stripe launch. Doesn't block L1/L2.

---

## Recommended order

1. **C1 + C2** (photo-avatar opt-in, PII log redaction) — small, isolated, code-only. Do before inviting any real user, regardless of launch tier.
2. **O1, O2** — flip now, code prereqs are satisfied.
3. **O3's pre-flight query**, then flip O3.
4. **O4** — publish v3 after O3 settles.
5. **O5, O6, O7, O8** run in parallel — all external/owner, no code dependency, no blocking order between them.
6. **O9** — hard deadline, do independent of the above, before 07-14.

Kids' soft launch (L1, free/invited) is realistically gated on C1+C2+O1+O2 only
— all cheap. Public monetized launch (L2) additionally wants O3-O5. Teen band
(L3) additionally wants O6. Nothing here blocks starting L1 prep immediately.

---

## Maintenance

This doc will rot too. When a row here clears, update it **and** the matching
MT in `docs/MANUAL_TASKS.md` in the same session — three trackers (07-03,
07-06, 07-08) have now each gone stale within days because parallel sessions
ship faster than docs update.
