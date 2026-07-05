# COPPA Compliance Audit - Story Weaver App

> ⚠️ **SUPERSEDED (2026-07-04).** This document predates the app's move to the
> **amended** COPPA Rule (2025) and claims some gaps that have since been fixed —
> it errs in the *safe* direction but should not be cited as current. For the
> authoritative posture see:
> - **`docs/COPPA_AMENDED_RULE_GAP_ANALYSIS.md`** — amended-Rule requirements + live gap register (G-1…G-12)
> - **`docs/LEGAL_LIABILITY_AUDIT_2026-06-28.md`** — current legal-liability posture + launch-gate flip order
>
> Kept for historical record only.

**Date:** March 15, 2026
**Last Updated:** June 24, 2026 — refreshed the third-party sub-processor list after the AI-provider migration (story text Gemini→OpenAI GPT-5 mini, illustrations→Cloudflare Workers AI, avatars→OpenAI gpt-image-2). Earlier disclosure/sync/deletion fixes recorded below.
**Overall Assessment:** ⚠️ **GOOD FAITH COMPLIANCE** (Launchable with known gap)

## Executive Summary
The Story Weaver app implements the critical features for COPPA compliance (Age Gate, Parental Consent Screen with full Notice to Parents, backend consent sync, Data Deletion). The Privacy Policy now carries a complete third-party sub-processor table that the consent screen mirrors. The one remaining deliberate gap is the **verifiability** of parental consent (an unverified checkbox/attestation today; SMS-OTP or $0.50 Stripe micro-charge planned for v1.1).

---

## COPPA Requirements Checklist

| Requirement | Status | Finding | Recommended Fix |
| :--- | :--- | :--- | :--- |
| **1. Verifiable Parental Consent** | ⚠️ **KNOWN GAP** | Checkbox + clear Notice to Parents disclosure screen. Consent now synced to backend. Email collected optionally. Strict "verifiable" method not yet implemented — planned for v1.1. Risk is low: no ads, minimal data, educational purpose, no data sharing with third parties for commercial use. | v1.1: add $0.50 Stripe verification as optional upgrade path. |
| **2. Notice to Parents** | ✅ **FIXED** | Consent screen shows a dedicated "Notice to Parents & Guardians" disclosure listing what is collected, what is not done, and every third-party sub-processor — OpenAI, Cloudflare Workers AI, Google Gemini, OpenRouter, Replicate, Microsoft (Azure/Edge TTS), ElevenLabs, Stripe, Railway, Firebase/Google Analytics, Sentry, Resend. Kept in sync with the Privacy Policy table (`lib/screens/parental_consent_screen.dart` ↔ `PRIVACY_POLICY.md`). | Keep both lists in sync whenever a provider changes. |
| **3. Data Minimization** | ✅ **PASS** | Data collected is relevant to story personalization (name, age, emotions, traits). Photo avatars (opt-in, off by default) are sent to the active AI image provider (OpenAI gpt-image-2) only to generate the cartoon portrait and are **not stored** on our servers. | Ensure "Additional Characters" and "Pet Photos" are explicitly justified as necessary for the service. |
| **4. Data Retention** | ✅ **PASS** | Privacy Policy states a 2-year inactivity deletion period. | No change needed to policy, but ensure backend cron jobs exist to enforce this. |
| **5. Data Deletion Mechanism** | ✅ **FIXED** | "Delete All My Data" button added to Parent Controls → Data & Privacy section. Calls `DELETE /api/user/<id>/data`. Confirmation dialog, COPPA right-to-erasure language, step-by-step instructions added to Privacy Policy. | No further action needed. |
| **6. Third-Party Disclosure** | ✅ **FIXED** | Privacy Policy carries a full "Sub-processors" table naming every provider in the data path (OpenAI, Cloudflare Workers AI, Replicate, OpenRouter, Google Gemini, Microsoft Azure/Edge, ElevenLabs, Stripe, Railway, Firebase/Google Analytics, Sentry, Resend), with the data category each receives. The consent screen mirrors it. | Keep the two lists synced when a provider changes. |
| **7. No Behavioral Advertising** | ✅ **PASS** | No ad SDKs found. Policy explicitly prohibits behavioral tracking for children. | Maintain current stance. |
| **8. Operator Contact Info** | ⚠️ **NEEDS WORK** | Includes email but lacks a physical address and phone number as typically required by COPPA. | Add a physical business address and phone number to the Privacy Policy. |

---

## Specific Findings

### 1. Parental Consent (Verifiable)
- **Current State:** `lib/screens/parental_consent_screen.dart` uses a checkbox.
- **Issue:** Under COPPA, a checkbox is insufficient for "verifiable" consent when collecting personal information from children under 13.
- **Fix:** Code change required. Implement a more robust verification method. For premium apps, a $0.50 credit card transaction (Stripe) is a common "verifiable" method.
- **2026-04-25 (MT-012):** 13–17 cohort now sees a "Just so you know" parent-awareness acknowledgement dialog before `recordConsent(method: 'self_attested')` fires (`lib/screens/welcome_screen.dart:1147-1191`). Cancelling the dialog returns the user to the age picker without writing a consent record. 18+ skips the dialog entirely. Federal COPPA scope (under-13) is unaffected; this strengthens attestation evidence for the minor-but-not-COPPA-covered tier (relevant to California AADC posture).

### 2. Data Synchronization Gap
- **Current State:** `ParentalConsentService.dart` saves to `SharedPreferences` only.
- **Issue:** The backend has a `ConsentRecord` model and `/api/user/<id>/consent` endpoint, but the frontend never calls it. This means the server has no record of the parent's consent.
- **Fix:** Code change required. Update `ParentalConsentService` to POST consent data to the backend.

### 3. Data Deletion (Right to Erasure)
- **Current State:** `ChildProfileService.dart` has a `deleteProfile` method that only deletes local data.
- **Issue:** Deleting a profile in the app does not remove the character or story data from the Railway-hosted database.
- **Fix:** Code change required. Ensure the `deleteProfile` method (or a new "Delete Account" button) calls the `/api/user/<user_id>/data` endpoint.

---

## Privacy Policy Gaps (`PRIVACY_POLICY.md`)

> **✅ Resolved (June 2026).** Every gap below has been closed — `PRIVACY_POLICY.md` now
> carries a full sub-processor table and step-by-step deletion instructions. Listed here as
> a historical record of what was fixed. **Note the provider names have since changed:**
> story text moved from Gemini to **OpenAI GPT-5 mini**, illustrations to **Cloudflare Workers AI**
> (Flux Schnell), and avatars to **OpenAI gpt-image-2**; photos on the opt-in photo-avatar path
> are uploaded to the image provider transiently (not stored), not "on-device only."

These were the gaps identified against the March 2026 Privacy Policy:

1.  **Third-Party AI Services:** Disclose that child-authored story elements are sent to the AI text provider for processing. *(Now OpenAI GPT-5 mini — resolved.)*
2.  **Voice Data:** Disclose that story text is sent to the TTS provider(s) for text-to-speech. *(Now Azure/Edge/Gemini Flash/ElevenLabs(13+) — resolved.)*
3.  **Payment Data:** Disclose that **Stripe** handles payment information for subscriptions/BYOK. *(Resolved.)*
4.  **Photo/Avatar Data:** State exactly how photo-avatar uploads are handled — sent to the AI image provider (OpenAI gpt-image-2) solely to generate the portrait, not stored, opt-in/off by default. *(Resolved; the old "on-device only" framing is obsolete.)*
5.  **Data Storage:** State that data is stored on secure servers provided by **Railway**. *(Resolved.)*
6.  **Right to Deletion:** Provide step-by-step instructions for a parent to delete their child's data. *(Resolved.)*

---

## Overall Assessment
**Status:** ⚠️ **Good faith compliance — launchable with known gap**

The high-risk issues (no backend consent sync, no deletion UI, unnamed third parties, no Notice to Parents) have been resolved. One known gap remains: strict "verifiable" parental consent (checkbox is not FTC-verifiable). This is a deliberate pragmatic decision given the app's low-risk profile (no ads, no data monetization, minimal collection, educational purpose).

**Remaining open items:**
- Operator physical address and phone number still needed in Privacy Policy (lower priority)
- v1.1: Add verifiable consent — offer parents a choice of two methods:
  1. **SMS OTP** — parent enters phone number, receives a one-time code, enters it in-app. Proves they control a real phone. Requires Twilio or similar (~$0.0075/SMS). One-time setup only, never asked again.
  2. **$0.50 Stripe micro-charge** — parent taps to authorize a nominal charge via Stripe (already integrated). FTC-recognized verifiable method. Can be refunded or kept as nominal fee.

  Both options shown on the consent screen; parent picks whichever is easier. Either one satisfies "verifiable" under COPPA. Implementation: new `VerifyConsentScreen` with method picker → Twilio/Stripe call → backend records `verified: true` on consent record.
