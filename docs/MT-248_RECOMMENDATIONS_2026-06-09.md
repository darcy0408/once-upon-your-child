# MT-248 — Launch-Gate Research & Recommendations (2026-06-09)

**Author:** session [autonomous research, ~2hr block]
**Status:** Research complete + Chunk A locally validated. Decisions below need owner sign-off; two items need counsel.
**Scope:** The two contractual launch-gates that bar shipping the kids app on its current AI stack — (1) Gemini for story text, (2) Gemini Flash TTS + ElevenLabs for narration/voice.

---

## TL;DR — recommendations

1. **Story text → Claude.** The migration is ~80% built (MT-171's `STORY_GEN_PROVIDER` flag). Claude Haiku 4.5 is already wired as the paid model. **Validated locally today: 49/49 unit tests pass + a real Claude-via-OpenRouter generation produced clean, child-safe output in 2.4s.**
2. **Go DIRECT to the Anthropic API, not via OpenRouter** — *recommended*. OpenRouter works technically and is cheaper to ship, but for a kids app whose entire value prop is contractual/safety cleanliness, the direct relationship removes a real ambiguity (see §2) for marginal cost. This is the one place I'd spend extra effort.
3. **TTS: drop Gemini Flash TTS, remove/hard-gate ElevenLabs, replace Edge TTS.** Edge TTS is **not** commercially licensed (Microsoft's own guidance). Move to **Azure AI Speech** (same neural voices, licensed, real-time = no data retention).
4. **Highest COPPA exposure is NOT TTS output — it's the `/tts/transcribe` STT endpoint** that records children's voices via ElevenLabs. That's a direct ElevenLabs ToS violation today and the most sensitive COPPA surface. Treat it as P0.
5. **Two counsel questions gate the build** (§6). Get provisional answers before writing the direct-Anthropic integration, because the answer to Q1 decides OpenRouter-vs-direct.

---

## 1. The blockers — confirmed with primary sources

### Gemini (story text + Flash TTS) — HARD prohibition
Gemini API Additional Terms:
> "You also will not use the Services as part of a website, application, or other service... that is directed towards or is likely to be accessed by individuals under the age of 18."
> "...for developers building with Google AI models for professional or business purposes, **not for consumer use**."

Two independent bars: (a) under-18 directed/accessed, (b) consumer use. A kids storytelling app fails both. **Vertex AI does not fix it** (same GCP Generative AI terms — confirmed in prior research, MT-137). Source: https://ai.google.dev/gemini-api/terms

### ElevenLabs (premium voice + STT) — second blocker
> "...strictly prohibited from uploading, transmitting, emailing, or otherwise making **Voice Data from children under the age of 18** available to the service."
> ElevenReader "is not designed for, or directed at, individuals under the age of 18."

The `/tts/transcribe` endpoint (STT of a child speaking) = making under-18 voice data available to ElevenLabs = direct violation. The TTS-output side is less explicit but the child-voice-data prohibition + the "not directed at under-18" framing make ElevenLabs unsafe for this app overall. Sources: https://elevenlabs.io/terms-of-use , https://elevenlabs.io/use-policy

---

## 2. Story text — the real decision: OpenRouter vs. direct Anthropic

### Anthropic permits child-directed apps (the green path)
Anthropic's API baseline is 18+, BUT they run an explicit **"Organizations Serving Minors"** program. Requirements:
- Age-verification appropriate to the product
- Content moderation / filtering for inappropriate content
- COPPA (and other child-protection law) compliance, **documented publicly**
- Disclose to users they're interacting with an **AI**, not a human
- Anthropic **audits apps** for compliance and may **suspend/terminate accounts** that violate it

Source: https://support.claude.com/en/articles/9307344-responsible-use-of-anthropic-s-models-guidelines-for-organizations-serving-minors

### The OpenRouter wrinkle (why I lean direct)
OpenRouter itself only requires age 13+ — fine. **But** its ToS says:
> "You [must] comply with the applicable terms for each Model ('Model Terms')... You are solely responsible for reviewing the Model Terms applicable to each Model."

So using Claude via OpenRouter **still binds you to Anthropic's terms** — OpenRouter doesn't shield you. And Anthropic's enforcement (audit/suspend) attaches to **accounts**. If you're under OpenRouter's account, there's no direct Anthropic relationship for Anthropic's minors program to attach to, audit, or bless. Neither Anthropic's nor OpenRouter's docs explicitly say "reseller access qualifies for the minors program." That's an unresolved ambiguity. Source: https://openrouter.ai/terms

**My read:** OpenRouter→Claude *with the safeguards in place* is *probably* compliant with Anthropic's Usage Policy, but it carries avoidable ambiguity for a launch whose whole point is being squarely, demonstrably compliant. A direct Anthropic API account:
- puts you unambiguously inside the Organizations-Serving-Minors program
- gives you the direct relationship their audit/enforcement model assumes
- avoids inheriting OpenRouter's own data-flow/training defaults
- costs marginally more eng effort (a new provider in the existing abstraction) and similar/lower per-token cost (no OpenRouter margin)

`backend/.env` already has `OPENROUTER_API_KEY` but **no `ANTHROPIC_API_KEY`** — direct path needs an Anthropic key + a `claude-direct` provider branch alongside the existing `openrouter`/`gemini` modes.

### What's already built (MT-171) — and validated today
- `STORY_GEN_PROVIDER` flag (`backend/config/__init__.py:141`, resolver `tasks/story_tasks.py:133`, wired `app.py:461`); modes `gemini` (current prod default) / `openrouter` / `auto`.
- Paid/premium/family/BYOK → `anthropic/claude-haiku-4.5`; free → `meta-llama/llama-3.3-70b-instruct`; hard fallback → `meta-llama/llama-3.2-3b-instruct:free`.
- `backend/services/openrouter_story_generator.py` is self-contained; tier resolution, Claude content-block flattening, content-filter handling, 429 backoff all present.
- **Today's validation:** `test_story_gen_provider_flag.py` + `test_story_model_tier_selection.py` = **49 passed**; a live `user_tier='premium'` generation returned a correct child-safe story via `anthropic/claude-haiku-4.5` in 2.4s.

If counsel says OpenRouter is fine, **shipping story text = flip `STORY_GEN_PROVIDER=openrouter` in Railway.** If counsel wants direct, it's a moderate add (new provider branch) — but the orchestration, prompts, and tests already exist to model it on.

---

## 3. Free tier — Llama note
Free tier uses Llama 3.3 70B (Meta). Meta's Acceptable Use Policy does **not** bar minors using the model; it bars child *exploitation/harm* and requires age-gating obscene material — neither applies to a safe kids' story app. So Llama is contractually OK. Two caveats:
- The `:free` hard-fallback route hits an unstable pool that historically may train on inputs; keep it as crash-fallback only, and prefer routing kids' PII away from it.
- If going **direct Anthropic** for paid, decide whether free tier also goes to a small Claude (e.g. Haiku) for one clean provider, vs. keeping Llama via a separate licensed host. Simpler stack = one provider.

---

## 4. TTS — drop Gemini/ElevenLabs, replace Edge TTS

Current chain (`backend/routes/tts_routes.py`): **Gemini Flash TTS → Edge TTS (free)**, with **ElevenLabs** opt-in premium, and `/tts/transcribe` STT via ElevenLabs.

- **Gemini Flash TTS** — same under-18 bar as story text. Remove.
- **ElevenLabs** — remove or hard-gate (see §1). The STT/transcribe path is the urgent one.
- **Edge TTS** — the `edge-tts` lib is an *unofficial* wrapper of Edge's "Read aloud" endpoint. Microsoft's own Q&A: commercial use without an Azure subscription **violates Microsoft's ToS**; they direct commercial users to **Azure AI Speech**. So the current "free fallback" is not viable for a commercial launch. Sources: https://github.com/rany2/edge-tts , https://learn.microsoft.com/en-us/answers/questions/2088770/are-opensource-edge-tts-free-for-commercial-use

### Recommended TTS: Azure AI Speech
- **Same neural voices** as Edge "Read aloud" → minimal audible change from today's fallback.
- **Real-time TTS does not retain audio/data** → strong COPPA posture; not used to train Microsoft models.
- Licensed, billed per character; can even run in-container for full data control.
- Source: https://azure.microsoft.com/en-us/pricing/details/speech/

On-device `flutter_tts` already exists as the final client fallback, so the chain becomes **Azure AI Speech → on-device flutter_tts**. Premium multi-voice/dialogue (the only thing ElevenLabs uniquely did) can be approximated with Azure SSML multi-voice if needed post-launch.

---

## 5. COPPA reframe (important for prioritization)
- **TTS output** (text→audio) does **not** collect children's personal info → low COPPA risk; it's mainly a licensing/ToS question (hence Azure over Edge).
- **STT** (`/tts/transcribe`, recording a child's voice) **does** collect children's data → high COPPA risk **and** the active ElevenLabs violation. FTC has a narrow exception: audio collected *solely* to convert to text and *immediately deleted* needs no separate parental consent — but you must actually meet "solely + immediately deleted," and not send it to a vendor that bars under-18 voice data. **Action: audit what `/tts/transcribe` does with the audio and which UX surfaces it; this is the P0 of the TTS work.**

---

## 6. Counsel / owner questions (gating)
1. **(Gates build path)** Does accessing Claude **via OpenRouter** qualify us for Anthropic's Organizations-Serving-Minors program, or do we need a **direct** Anthropic API agreement? → decides §2.
2. **(Gates STT)** Does `/tts/transcribe`'s handling of a child's recorded voice qualify for the FTC "solely-to-transcribe, immediately-deleted" exception, or do we need verifiable parental consent? And is the feature worth keeping at launch?
3. (Owner) Confirm we will publish a COPPA-compliance statement (Anthropic requires it documented publicly).
4. (Owner) Eyeball the *live* GCP "Generative AI Services → Age Restrictions" clause to confirm wording (prior research couldn't render the live page).

---

## 7. Chunked plan
- **Chunk 0 (owner+counsel, BLOCKS rest):** resolve Q1 + Q2.
- **Chunk A (small, mostly done):** if OpenRouter approved → flip `STORY_GEN_PROVIDER=openrouter` in a Railway preview, run suite + multi-band live smoke. If direct required → add `claude-direct` provider branch (Anthropic SDK + key), mirror existing tests.
- **Chunk B (medium):** TTS — remove Gemini Flash TTS, hard-gate/remove ElevenLabs (esp. `/tts/transcribe`), wire Azure AI Speech, chain → Azure → on-device.
- **Chunk C (cleanup):** once A proven in prod, delete dead Gemini story-text path (`story_generation_service.py` Gemini calls) and Gemini TTS code.

## 8. Evidence gaps (didn't fully verify)
- Exact Azure AI Speech neural-TTS price/char and whether a kids-app-specific term exists (got the pricing page + COPPA-favorable retention behavior, not a signed-off per-char number).
- Whether OpenRouter, with account-level "no-train / ZDR-only" settings, fully satisfies COPPA "service provider" contract requirements (likely yes with settings, but unconfirmed by counsel).
- Live GCP age-restriction clause wording (Q4).

---

### Sources
- Anthropic minors program: https://support.claude.com/en/articles/9307344-responsible-use-of-anthropic-s-models-guidelines-for-organizations-serving-minors
- Anthropic usage policy: https://www.anthropic.com/news/updating-our-usage-policy
- Gemini API terms: https://ai.google.dev/gemini-api/terms
- OpenRouter terms: https://openrouter.ai/terms · logging/ZDR: https://openrouter.ai/docs/guides/privacy/logging
- Meta Llama 3.3 use policy: https://www.llama.com/llama3_3/use-policy/ (and llama3_1, llama3_2 variants)
- ElevenLabs terms / use policy: https://elevenlabs.io/terms-of-use · https://elevenlabs.io/use-policy
- Edge TTS commercial-use risk: https://learn.microsoft.com/en-us/answers/questions/2088770/are-opensource-edge-tts-free-for-commercial-use · https://github.com/rany2/edge-tts
- Azure AI Speech pricing: https://azure.microsoft.com/en-us/pricing/details/speech/
- FTC COPPA FAQ: https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions · voice exception: https://www.fenwick.com/insights/publications/ftcs-new-coppa-guidance-on-recording-childrens-voices-five-tips-for-app-developers-and-toymakers-to-comply
