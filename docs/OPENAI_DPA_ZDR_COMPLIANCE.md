# OpenAI DPA + Zero Data Retention — Child-Prompt Path Compliance (MT-318)

**Status:** OPEN — owner action required before public launch
**Owner:** Darcy (compliance / contractual — not a code task)
**Created:** 2026-07-02 · **Researched/verified:** 2026-07-03
**Related:** [[coppa_amended_rule_2025]], [[gemini_api_under18_terms_blocker]], [[consent_disclosure_sync]] · `docs/SAFETY_AUDIT_REMEDIATION.md`

---

## 1. Why this exists (the legal frame)

The amended COPPA Rule (effective **2026-06-23**, compliance deadline **2026-04-22**; Fed. Reg. 2025-05904) is interpreted in the FTC preamble so that disclosing a child's personal info to a third party **"to train or otherwise develop artificial intelligence technologies" is never "integral"** to the service → it requires **separate verifiable parental consent (VPC)**.

**BUT** sending a child's story prompt to OpenAI's API is **not a regulated "disclosure"** *if* OpenAI acts as a **pure processor** under the **"support for internal operations" exception (§ 312.2)** — i.e. OpenAI does **not train** on the data and does **not retain** it beyond internal-ops needs.

**Conclusion: the gap is contractual, not code.** OpenAI's API already does not train on API data by default; what remains is to (a) lock that down in a signed DPA, and (b) close the retention grey zone with Zero Data Retention (ZDR). This doc is the owner checklist to do exactly that.

> ⚠️ Do **not** cite the old FTC COPPA FAQ page — it is stale (pre-2025 amendments).

---

## 2. Scope — which traffic is the "child-prompt path"

Verified against the codebase 2026-07-03:

| Path | Prod provider | Endpoint | Sends child data to OpenAI? |
|---|---|---|---|
| **Story text** | `STORY_GEN_PROVIDER` defaults to **`openai`** (`backend/config/__init__.py:146`) | `/v1/chat/completions` (or `/v1/responses`) | **Yes** — prompt includes child's name/traits/feelings |
| **OpenAI story client** | `openai.OpenAI(api_key=...)`, **no custom `base_url`** (`backend/services/openai_story_generator.py:181`) | direct to `api.openai.com` | **Yes — direct relationship with OpenAI** (not proxied) |
| **Avatar / image** | provider default hardened to `openai` ([[consent_disclosure_sync]]) | `/v1/images` | **Yes** — if a child photo/description is sent |

**Key finding:** prod calls **api.openai.com directly** — the DPA/ZDR counterparty is **OpenAI itself**, not OpenRouter. (OpenRouter is only used by the `openrouter` / `auto` providers, which are local/testing, not prod default.)

**Caveats to watch:**
- If `STORY_GEN_PROVIDER` is ever set to **`tiered`**, paid tiers route to **Anthropic (Claude)** — that path would need its *own* DPA/ZDR with Anthropic. Not in scope today (prod = `openai`), but flag it if `tiered` ships.
- If avatar uploads ever move to the **`/v1/files`** endpoint, note that `/v1/files` is **NOT ZDR-eligible** (see §4). Keep image generation on `/v1/images`, which **is** eligible.

---

## 3. Owner action checklist

- [ ] **(A) Execute OpenAI's DPA.** Self-serve form → countersigned PDF returned by email in minutes. Fill legal entity (the LLC — see [[llc_formed]]), signatory name/title/email, billing entity. Form + policy: https://openai.com/policies/data-processing-addendum/
- [ ] **(B) Request Zero Data Retention (ZDR)** for the API org/project that holds `OPENAI_API_KEY`. **Not a self-serve toggle** — must be approved by OpenAI's sales/account team, with acceptance of additional requirements. Contact sales via https://openai.com/enterprise-privacy/
  - Fallback if ZDR isn't granted: request **Modified Abuse Monitoring** (excludes customer content from abuse logs but does not force `store=false`). Weaker than ZDR but removes customer content from the 30-day logs.
- [ ] **(C) VERIFY ZDR is actually live** — do not assume the request = enabled. (Documented failure mode: teams submitted the request, never verified, and ran weeks of prod traffic under default 30-day retention while a DPIA claimed zero.) Confirm in writing from OpenAI which org/project + which endpoints are covered, and that `store` is forced `false`.
- [ ] **(D) Confirm no-training in the contract**, not just the policy page. OpenAI's default (since 2023-03-01) is that API data is **not** used to train/improve models unless you opt in — get this reflected in the executed DPA so it's contractually binding for the child path.
- [ ] **(E) Consent-flow hygiene — never bundle "improve our AI."** Consent-to-operate must **not** be bundled with any "help improve our AI" consent. If we ever disclose child data for AI training (ours or a third party's), it must be a **distinct VPC event** — cleanest is **don't do it at all**. Keep [[consent_disclosure_sync]] (consent screen ↔ PRIVACY_POLICY.md) in sync.
- [ ] **(F) Data minimization.** Independent of the exception, send the **minimum** child PII needed in the prompt. Review the prompt builder so we're not shipping more identifying detail than the story requires.
- [ ] **(G) Confirm consent-to-*collect*.** Consent to collect the prompt in the first place is **independently required** regardless of the OpenAI relationship — this is separate from the processor analysis.

---

## 4. Verified facts (OpenAI, 2026-07-03)

**Default retention:** OpenAI may retain API inputs/outputs for **up to 30 days** for abuse monitoring, then deletes them (unless legally required to retain). This 30-day window is the grey zone that could push the transfer *outside* the § 312.2 internal-ops exception — **ZDR removes it.**

**Training:** As of 2023-03-01, API data is **not** used to train/improve OpenAI models unless you explicitly opt in.

**Modified Abuse Monitoring:** excludes customer content from abuse logs across all endpoints, full platform capability retained. Requires prior approval.

**Zero Data Retention (ZDR):** excludes customer content from abuse logs **AND** treats the `store` parameter as always `false` (prompts/outputs processed in memory, not retained after the request). Requires prior approval + additional requirements.

**ZDR-eligible endpoints** (our story + image paths qualify): `/v1/chat/completions`, `/v1/responses`, `/v1/images`, `/v1/embeddings`, `/v1/audio/*`, `/v1/moderations`, `/v1/completions`, `/v1/realtime`.

**ZDR-EXCLUDED endpoints** (avoid for the child path): `/v1/conversations`, `/v1/assistants`, `/v1/threads`, `/v1/files`, `/v1/fine_tuning/jobs`, `/v1/batches`, `/v1/videos`.

**Safety Retention caveat:** OpenAI reserves the right to make certain models ZDR-ineligible if reasonably necessary to investigate severe-risk activity, with written advance notice.

---

## 5. Why ZDR matters beyond COPPA — the NYT court-order lesson

In *NYT v. OpenAI*, Magistrate Judge Ona T. Wang ordered (2025-05-13) OpenAI to **preserve all output log data indefinitely** — overriding deletion and even user-deleted content.

- **API customers on ZDR were exempted** from that preservation order.
- Default (non-ZDR) API traffic **was** swept into indefinite legal-hold retention during ~May–Sept 2025.
- The indefinite obligation ended **2025-09-26**; a limited April–Sept 2025 historical set is still held, and in **Jan 2026** a judge ordered disclosure of ~200M anonymized conversation records.

**Takeaway:** ZDR is not only the cleanest COPPA fit — it is the concrete mechanism that would have insulated child-prompt data from a third-party legal hold. This strengthens the case for (B)+(C) above.

---

## 6. Adjacent items (referenced so they aren't orphaned)

- **kidSAFE + COPPA Safe Harbor seal** — FTC-approved seal program; get a 2026 price quote.
- **SEL credentialing page** — CASEL/ASCA alignment + one named advisory clinician; see `docs/SEL_FRAMEWORK_ALIGNMENT.md`. Closes our one competitive flank vs. Slumberkins ([[sel_credentialing_gap]]).
- **Own-model training** — training on our OWN internal model is an acknowledged legal gap ("not a safe harbor"); out of scope here but do not treat it as covered by the processor analysis.

---

## Sources
- [OpenAI — Data Processing Addendum](https://openai.com/policies/data-processing-addendum/)
- [OpenAI — Enterprise privacy](https://openai.com/enterprise-privacy/)
- [OpenAI — Data controls in the OpenAI platform](https://developers.openai.com/api/docs/guides/your-data)
- [OpenAI — Response to NYT data demands](https://openai.com/index/response-to-nyt-data-demands/)
- COPPA amended Rule — Fed. Reg. 2025-05904 (effective 2026-06-23; compliance deadline 2026-04-22)
