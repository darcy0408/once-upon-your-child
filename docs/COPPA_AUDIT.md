# COPPA Compliance Audit - Story Weaver App

**Date:** March 15, 2026
**Overall Assessment:** ⚠️ **NEEDS FIXES FIRST** (Not safe to launch)

## Executive Summary
The Story Weaver app currently implements several critical features for COPPA compliance (Age Gate, Parental Consent Screen, Data Deletion backend), but there are significant gaps in the **verifiability** of parental consent and the **synchronization** of consent/deletion data with the backend. Additionally, the Privacy Policy lacks explicit disclosures for third-party service providers (AI, Voice, Payments).

---

## COPPA Requirements Checklist

| Requirement | Status | Finding | Recommended Fix |
| :--- | :--- | :--- | :--- |
| **1. Verifiable Parental Consent** | ❌ **FAIL** | Consent is gathered via a simple checkbox for under-13 users. This does not meet COPPA's "verifiable" standard. Consent is also stored only locally. | Implement a verifiable method (e.g., credit card transaction, ID verification, or email-plus-plus). Sync consent to backend. |
| **2. Notice to Parents** | ⚠️ **NEEDS WORK** | Privacy Policy provides general notice but is not specifically presented as a "Notice to Parents" during the consent flow. | Update the consent flow to display a clear, concise "Notice to Parents" before the consent action. |
| **3. Data Minimization** | ✅ **PASS** | Data collected is relevant to story personalization (name, age, emotions, traits). Photo avatars are processed on-device. | Ensure "Additional Characters" and "Pet Photos" are explicitly justified as necessary for the service. |
| **4. Data Retention** | ✅ **PASS** | Privacy Policy states a 2-year inactivity deletion period. | No change needed to policy, but ensure backend cron jobs exist to enforce this. |
| **5. Data Deletion Mechanism** | ⚠️ **NEEDS WORK** | Backend has a deletion API, but there is no user-facing "Delete My Account/Data" button in the Parent Controls UI. | Add a prominent "Delete All My Data" button in the Parent Controls screen that calls the backend DELETE endpoint. |
| **6. Third-Party Disclosure** | ❌ **FAIL** | Privacy Policy mentions "service providers" but does not name Google Gemini, ElevenLabs, or Stripe. | Explicitly name these providers and what data they receive in the Privacy Policy. |
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
**Status:** 🛑 **Needs fixes first**

Story Weaver is not currently COPPA-compliant. The lack of verifiable parental consent and the failure to sync consent/deletion to the backend are high-risk issues. These must be addressed before public launch.
