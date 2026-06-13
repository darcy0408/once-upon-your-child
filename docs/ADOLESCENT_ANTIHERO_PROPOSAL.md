# Adolescent Antihero Mode — Product Proposal & Roadmap

**Band:** Adolescent (15–17) · **Mode:** "Double Life" antihero serialized fiction
**Status of writing:** proposal / decision doc — 2026-06-12
**Branch with shipped work:** `adolescent-antihero-ux` (3 commits, verified)

---

## 1. The thesis (why this band, why now)

The teen interactive-fiction market is split in two, and the middle is empty:

- **Open AI roleplay** (Character.AI, AI Dungeon, Talkie) — extremely sticky, but the harm vector is open-ended, relationship-style chat with romance/sexual content and no age gating. After the *Garcia v. Character Technologies* wrongful-death suit, **Character.AI banned open-ended chat for under-18s entirely (Nov 2025).**
- **Authored visual-novel serials** (Episode, Choices, Chapters, Wattpad/Webtoon) — safe-ish, but the content is *static*, so retention is "notoriously low" and monetization leans on FOMO/gacha and diamond-gating that children's-privacy regulators (UK AADC) now target as dark patterns.

**Nobody offers AI-fresh-every-issue content inside authored guardrails.** Our design — single-player, no stranger chat, parent-gated onboarding, bounded prompt — sidesteps *every* documented Character.AI failure mode while keeping the "new every time" magic that static serials can't match. That's not just compliance; it's the positioning and the marketing line.

> Supporting data: 72% of US teens (13–17) have tried an AI companion, 52% are regular users (Common Sense Media / NORC, n=1,060). But 15–17s trust AI advice *less* and prefer real friendships — i.e. this age wants **entertainment fiction, not a fake friend.** Antihero enjoyment is driven by *identification → liking* via moral disengagement, and **compounds with repeat exposure** (Janicke & Raney) — which is exactly what a serialized, consequence-carrying saga delivers.

---

## 2. Positioning principle: teen autonomy + invisible safety

Two design commitments that everything below must honor:

1. **The teen is the author of their own story.** Autonomy and identity exploration are the core developmental pull at 15–17. The product should feel like *theirs*, not a supervised activity.
2. **Safety is structural, not surveillant.** We are safe because of *what the product can't do* (no open chat, no strangers, bounded prompt, hard content rules already enforced in `prompt_service.py`) — **not** because a parent is watching over the teen's shoulder.

### On the parent question (decision: no content surveillance)
A "what my teen is reading" dashboard was floated in research as a trust feature. **We are cutting it for this band.** Reasons:
- **Product:** teens do not want a parent inside their reading; it breaks commitment #1 and is a fast way to lose them.
- **Legal:** COPPA's verifiable-parental-consent regime is **under-13**. The 15–17 band sits *outside* it, so ongoing parental content-monitoring is **not required**.
- **What we keep:** only the one-time **age assurance** needed for provider-terms compliance (see §6), and the existing account-level setup. No per-story content reporting to parents.

---

## 3. Where we are today (shipped & verified on `adolescent-antihero-ux`)

Three phases already landed, each `flutter analyze`-clean with passing FE+BE tests, and sanity-checked with a real local story generation:

- **Phase 1 — Tone:** dedicated neo-noir codename pool (killed the Explorer "Sir Bounce-a-Lot" pool); Fredoka → Source Sans 3 on the wizard screens; Heart/Paw/Rainbow emblems filtered ("Choose your mark"); Edge name reads as a clean alias.
- **Phase 2 — Paradigm:** the kiddie cape/emblem dress-up replaced by an **Identity step** (what you're hiding / your tell / the line you won't cross), threaded end-to-end to the prompt, which now uses the player's real secret/tell/line instead of inventing them.
- **Phase 3 — Delight:** a **consequence ledger** (`what_it_cost` captured in `saga_state` and carried into the next chapter's continuity); richer "Previously in your saga" recap; dilemma-framed premises.

A real generation confirmed all three identity inputs shape the prose and `what_it_cost` round-trips meaningfully. **This roadmap builds on that scaffolding.**

---

## 4. Second-pass findings (boy + girl walkthrough)

Walked twice. The UI is **identical** for Boy and Girl — gender only flips pronouns in the prose (no pink/blue stereotyping). The remaining issues:

| # | Finding | Severity | Fix |
|---|---------|----------|-----|
| F1 | Gender selector is a binary **"Boy"/"Girl"** toggle defaulting to **Girl**; reads young for 15–17 (Adult band already uses man/woman art), and a non-binary teen has no option. | Med | Relabel pronoun-forward (**He / She / They**) or drop the word; add a neutral option. |
| F2 | **"Hero" language leaks into the *anti*hero band** — "Choose your hero color", "Every hero has one". | Low | Adolescent-only copy swap (cover/edge framing). |
| F3 | The **Creative Brief is a bureaucratic wall** — name + "what your character wants" + 4-card archetype + **4 personality sliders** + companions + setting + genre + mode + duration — and it *competes* with the richer Identity + Edge steps. ~13 taps to first story, introspection asked twice. | Med-High | Collapse the brief for this path (see Phase A). |
| F4 | **Personality sliders feel like RPG filler** for an antihero — the secret/tell/line/Edge define character better. | Med | Hide sliders for this band. |
| F5 | **"Randomize" skips the Identity step** — the one feature that makes the band special is the easiest to bypass. | Low-Med | Have Randomize seed (or prompt) the identity fields too. |

---

## 5. The roadmap

Phased by impact-to-effort. Each phase is independently shippable and verifiable. Effort is rough dev-time, not calendar.

### Phase A — Polish & coherence  *(low effort, do first)*
The cheap wins that remove the last juvenile/redundant edges. Adolescent-scoped, low risk, unit-testable.
- **A1 (F2):** De-"hero" the costume/mark copy.
- **A2 (F1):** Relabel gender selector (He/She/They) + add a neutral/unspecified option; flow the neutral pronoun (they/them) to the backend.
- **A3 (F3/F4):** Collapse the Creative Brief for the antihero path — hide personality sliders + the separate "what your character wants" field; make archetype optional. Target flow: name → gender → (optional archetype) → premise → costume/identity/edge.
- **A4 (F5):** Randomize also seeds the identity fields (random chip per prompt) so the shortcut can't strip the band's signature step.
- *Risk:* low. *Depends on:* nothing. *Verifiable:* analyze + widget tests.

### Phase B — Retention core  *(med effort, highest ROI)*
The two mechanics that turn one-shot stories into a habit. Both leverage existing `saga_state`.
- **B1 — Consequence ledger that *bites* (research #1).** We already *store* `what_it_cost`; make it *return as plot* — past costs/choices resurface as concrete story beats (an ally remembers, a lie collapses). Extend the continuity block + a visible "rap sheet" surface. *Principle:* meaningful consequences drive return; antihero schema compounds across issues.
- **B2 — Cliffhanger + "next issue" cadence (research #2).** We already emit `next_hook`; add a healthy daily "your next issue is ready" rhythm (a ritual, **not** a predatory countdown). *Principle:* Webtoon/Yonder binge loop without the dark pattern.
- *Risk:* med. *Depends on:* A (clean flow). *Verifiable:* BE prompt tests + FE saga tests + a real gen.

### Phase C — Identity & drama  *(med effort)*
- **C1 — Double-life meter (research #3):** track public-persona vs. real-self; choices pull them apart; exposure risk is the drama. Maps onto the secret/tell/line already captured.
- **C2 — Tempting "wrong" choices (research #4):** in-story decision points with no clean-good option, not railroaded onto one "correct" path. (Note: requires a choice mechanic — see open question Q2.)
- *Risk:* med-high (C2 introduces interactivity). *Depends on:* B.

### Phase D — Collection & sharing  *(low-med effort)*
- **D1 — Saga archive as collectible "issue covers" (research #5):** completed issues as a shelf of comic-style covers showing the branch taken. Collect *your earned story* — explicitly **not** gacha.
- **D2 — Shareable "issue cover" image (research #7):** export a cover/quote card to post **off-platform**; zero in-app social graph (AADC-safe).
- *Risk:* low-med. *Depends on:* saga persistence (exists).

### Phase E — Living cast  *(med effort)*
- **E1 — Recurring rival/ally with relationship memory (research #6):** a small persistent ensemble whose stance shifts with your ledger. *Principle:* relationships are a top teen-retention driver — delivered single-player and bounded.
- *Risk:* med. *Depends on:* B1 (ledger).

---

## 6. The real blocker (must resolve before *any* of this ships)

**The Adolescent band cannot legally ship on the current stack.** Gemini's API terms forbid under-18 apps, and ElevenLabs is a second blocker for under-13 (TTS). This is contractual, not a data setting; Vertex does not fix it. The fix (already scoped under MT-137): **route story *text* to the Claude API**, keep Cloudflare for illustrations, and replace/gate ElevenLabs TTS. Until that lands, this entire mode is build-but-don't-launch. Everything in §5 should be developed against that migration, not the Gemini path. *(Cross-ref: `gemini_api_under18_terms_blocker` memory, MT-137.)*

---

## 7. Explicitly out of scope (the "do not build" list)

These are the documented harm/enforcement vectors for minor products — avoiding them is the product's spine:
- ❌ Open-ended free-text chat / any AI "companion" relationship loop
- ❌ In-app contact with other users / any social graph
- ❌ Romance or sexual content
- ❌ FOMO / gacha / loot-box monetization (AADC dark-pattern target)
- ❌ **Ongoing parental content-surveillance** (per §2 — teen autonomy + outside COPPA's under-13 scope)

---

## 8. Recommended sequence & decisions

**Sequence:** A → (MT-137 text-to-Claude migration in parallel) → B → C/D → E.
Phase A is worth doing immediately (cheap, finishes the UX). Phase B is the retention bet and reuses scaffolding we already shipped. C/D/E are the "want-to-return" layer.

**Decisions (resolved 2026-06-12):**
- **D1 (gender):** **He / She / They** labels; "They" is the neutral/non-binary option and flows `they/them` to the backend.
- **D2 (interactivity):** **Do it all** — full interactivity is in scope. Ship *between-issues* consequences first (B1) + an interactive end-of-issue hook, then add *in-story* branching choice points (C2) as a committed later phase, not a deferred maybe.
- **D3 (first build):** **Phase A first as its own chunk, then B1 immediately after** (two clean increments, not one bundled push).

---

*Appendix — research sources: Common Sense Media/NORC teen AI study (via TechCrunch); Janicke & Raney antihero enjoyment model; Garcia v. Character.AI (K-12 Dive, Rolling Stone); Udonis Choices monetization/retention; Episode mechanics; Talkie gacha review; WEBTOON Yonder; Springer adolescent-identity review; IAPP AADC-vs-COPPA. Full citations in session research log.*
