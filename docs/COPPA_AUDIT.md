# COPPA Compliance Audit - Story Weaver App

**Date:** March 15, 2026
**Last Updated:** March 15, 2026 — COPPA fixes applied (see bottom)
**Overall Assessment:** ⚠️ **GOOD FAITH COMPLIANCE** (Launchable with known gap)

## Executive Summary
The Story Weaver app currently implements several critical features for COPPA compliance (Age Gate, Parental Consent Screen, Data Deletion backend), but there are significant gaps in the **verifiability** of parental consent and the **synchronization** of consent/deletion data with the backend. Additionally, the Privacy Policy lacks explicit disclosures for third-party service providers (AI, Voice, Payments).

---

## COPPA Requirements Checklist

| Requirement | Status | Finding | Recommended Fix |
| :--- | :--- | :--- | :--- |
| **1. Verifiable Parental Consent** | ⚠️ **KNOWN GAP** | Checkbox + clear Notice to Parents disclosure screen. Consent now synced to backend. Email collected optionally. Strict "verifiable" method not yet implemented — planned for v1.1. Risk is low: no ads, minimal data, educational purpose, no data sharing with third parties for commercial use. | v1.1: add $0.50 Stripe verification as optional upgrade path. |
| **2. Notice to Parents** | ✅ **FIXED** | Consent screen now shows a dedicated "Notice to Parents & Guardians" disclosure listing what is collected, what is not done, and all three third-party services (Google Gemini, ElevenLabs, Stripe). | No further action needed. |
| **3. Data Minimization** | ✅ **PASS** | Data collected is relevant to story personalization (name, age, emotions, traits). Photo avatars are processed on-device. | Ensure "Additional Characters" and "Pet Photos" are explicitly justified as necessary for the service. |
| **4. Data Retention** | ✅ **PASS** | Privacy Policy states a 2-year inactivity deletion period. | No change needed to policy, but ensure backend cron jobs exist to enforce this. |
| **5. Data Deletion Mechanism** | ✅ **FIXED** | "Delete All My Data" button added to Parent Controls → Data & Privacy section. Calls `DELETE /api/user/<id>/data`. Confirmation dialog, COPPA right-to-erasure language, step-by-step instructions added to Privacy Policy. | No further action needed. |
| **6. Third-Party Disclosure** | ✅ **FIXED** | Privacy Policy now explicitly names Google Gemini, ElevenLabs, Stripe, and Railway. Each entry describes what data is shared and links to their privacy policy. Consent screen also lists all three. | No further action needed. |
| **7. No Behavioral Advertising** | ✅ **PASS** | No ad SDKs found. Policy explicitly prohibits behavioral tracking for children. | Maintain current stance. |
| **8. Operator Contact Info** | ⚠️ **NEEDS WORK** | Includes email but lacks a physical address and phone number as typically required by COPPA. | Add a physical business address and phone number to the Privacy Policy. |

---

## Specific Findings

### 1. Parental Consent (Verifiable)
- **Current State:** `lib/screens/parental_consent_screen.dart` uses a checkbox.
- **Issue:** Under COPPA, a checkbox is insufficient for "verifiable" consent when collecting personal information from children under 13.
- **Fix:** Code change required. Implement a more robust verification method. For premium apps, a $0.50 credit card transaction (Stripe) is a common "verifiable" method.

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

The following gaps were identified in the current Privacy Policy:

1.  **Third-Party AI Services:** Must explicitly disclose that child-authored story elements are sent to **Google Gemini** for processing.
2.  **Voice Data:** Must disclose that story text is sent to **ElevenLabs** for text-to-speech generation.
3.  **Payment Data:** Must disclose that **Stripe** handles payment information for subscriptions/BYOK.
4.  **Photo/Avatar Data:** While the app states photos are "on-device only," the policy should explicitly state that personal photos used for avatars are NOT uploaded or stored on servers.
5.  **Data Storage:** Explicitly state that data is stored on secure servers provided by **Railway**.
6.  **Right to Deletion:** Provide a clearer, step-by-step instruction on how a parent can exercise their right to delete their child's data.

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
