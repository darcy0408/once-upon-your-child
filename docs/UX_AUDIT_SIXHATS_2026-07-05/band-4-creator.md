# Six Hats UX Audit — Band 4: Creator (12–14)

**Run:** prod, fresh anon, "Max", 12–14 pill, Boy, Kinetic Specialist, solo cast, own-world setting, Medium, illustrated story. 11 screens.

## Developmental frame
Full literacy, aggressive skimming, near-adult motor. Rejects anything babyish; wants authorship, control, and respect. Peer-shareability is the retention currency.

## Screen-by-screen highlights

### Age gate → consent
- **Black:** P2 — the 12–14 pill must (correctly) route via full parental consent (a 12yo may be in it), but the consent screens keep **little-kid tone + styling**: "Time to get a grown-up!" with bubbly font for someone who may be 14. Add a band-aware variant ("A parent or guardian needs to approve this account").
- **Blue:** Legally right, tonally wrong. Complexity **Right**.

### Creative Brief — "Build Your Story"
- **Yellow:** The dark editorial brief is the correct interaction model for this band: PROTAGONIST NAME, "What does your character want more than anything?" desire field, required core + collapsed optional sections (PERSONALITY / CAST & COMPANIONS / WORLD & SETTING / STORY OPTIONS), full-width "Create Story". Fast path for skimmers, depth for authors.
- **Black:**
  1. **P1 — gender cards broken: Boy and Girl cards show the IDENTICAL girl image, composited over a raw transparency checkerboard.** This is the exact thing PR #312 claimed to fix (MT-304 item 2 device-verify) — regression or failed fix. Looks broken and undermines the "sophisticated" promise of the band. (`hero_creator_creative_brief.dart` asset switch / `gender_creator_*.webp` contents.)
  2. P3 — archetype display-name drift: card says "Kinetic Specialist", Story Pitch says "The Lightning Runner".
- **Blue:** **Right** otherwise. Playground 8/10.

### Story Pitch (review)
- **Yellow:** Clean summary card (name + archetype subtitle + Setting/Cast/Format rows, each re-rollable), Short/Medium/Long, "Your story, your way", Start Writing. Respectful, fast.
- **Black:** P2 — "Format: Illustrated story" is the silent default; this is almost certainly the same default that surfaces as "Picture tale" in younger bands' reviews (one mapping/label root cause — fix once).

### Generation
- **Black:** P3 — "Catch the sparkles! ✨" + "Something magical is about to happen…" copy reads young for a 13yo. Band-tone the status lines ("Drafting… / Building your world…").
- **Yellow:** Staged progress + visible elapsed seconds + Cancel = right for the band.

### Reader — "the stardust race at dawn" (13 pages)
- **Yellow:** Single-page editorial layout; **hero name rendered as gold highlight chips** in the text (subtle, classy); prose quality genuinely strong for the band ("Max thought through the scene like a coach plans plays"); Re-read / Remix / Save / Share action row — Remix is the retention feature this band wants.
- **Black:**
  1. P2 — page card scrolls *internally* (illustration up top, text below) with no scroll affordance; pill says "Page 2" while the viewport still shows only the same illustration. Add a fade/chevron cue. (Same structure explains Explorer's "missing text" — there it's a P1 because 6–8s won't discover inner scroll at all.)
  2. P3 — AI-gibberish text baked into illustration signage ("HORTIDIN'S SAIP BAKERY") — add the textless-art rule (already used for scene tiles) to story-illustration prompts.
  3. P3 — title lowercase ("the stardust race at dawn") — if unintentional, title-case it; if noir styling, make it consistent (other bands are Title Case).
  4. P2 — verify Share gating on child accounts (12–13 are still minors under COPPA consent here).

## Action Plan (Creator)

| Priority | Screen | Issue | Change | Effort |
|---|---|---|---|---|
| P1 | Creative Brief | Boy/Girl cards identical + checkerboard (regression vs #312) | Fix asset contents/compositing; verify on prod | S |
| P2 | Consent | Little-kid tone for 12–14 | Band-aware consent copy variant | S |
| P2 | Story Pitch | "Illustrated story" default = cross-band "Picture tale" label root | One mapping fix (shared) | S |
| P2 | Reader | Inner-scroll text with no affordance | Fade/chevron cue at card bottom | S |
| P2 | Reader | Share gating unverified | Verify + gate | S |
| P3 | Generation | Young copy ("magical", sparkles) | Band-toned status lines | S |
| P3 | Reader | AI text in illustrations | Textless rule in illust. prompts | S |
| P3 | Brief/Pitch | Archetype name drift | Single display name | S |

**Elevate:** the desire field ("what does your character want more than anything?") is the best writing-craft prompt in the app — surface its payoff by echoing the desire in the Story Pitch ("A story about wanting to prove yourself"); export/share-as-PDF (parent-gated) would make Creator stories feel like *published work* — the authorship pride loop.
