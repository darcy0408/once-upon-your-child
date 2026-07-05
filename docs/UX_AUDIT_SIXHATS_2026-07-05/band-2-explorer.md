# Six Hats UX Audit — Band 2: Explorer (6–8)

**Run:** prod, fresh anon, age 7, "Zoe", Girl, The Brave Explorer, Ember, Cave Full of Crystals, Story Quest, wish skipped. 17 screens.
**Consent chain:** identical to Sprout — findings there apply (ElevenLabs block, Gemini BYOK promo, Shape-the-stories dead end). Not repeated.

## Developmental frame
Early readers: short sentences OK, icons still carry weight. Better motor precision; can scroll but doesn't *expect* to have to. Wants to feel "big kid" — babyish art reads as insult. Reading practice is a core product value at this band.

## Screen-by-screen

### Wizard p1 — "CREATE YOUR HERO!" (labeled progress: Pick Hero / Pick Team / Pick Place / Make Magic!)
- **Yellow:** Text labels on progress dots — right call for early readers. Name pre-filled; "Hi Zoe!" personal.
- **Black:** Girl pre-selected by default (same as Sprout — P2). Explorer gender art (blue boy w/ star shirt, pink-haired girl) is the committed set; owner considered swapping for "cooler" versions — never landed (2026-07-05 session).
- **Blue:** **Right**. Playground 9/10.

### Avatar modal — "Choose Your Look"
- **Black:** **Pool is not gender-aware — confirmed across bands.** Boy pick (Sprout run): 7♀/1♂. Girl pick (this run): 6♀/2♂. The pool just skews girl regardless of pick; boys always hunt. P1.
- **Yellow:** Avatar art quality high, ethnically diverse; "150 characters to discover" + Shuffle is good replay bait.
- **Green:** Weight pool by pick (~6 of 8 match), keep 2 opposite for freedom.

### Archetype — "PICK YOUR ARCHETYPE!"
- **Black:** "Archetype" above a 7-year-old's reading level too (P2, shared with Sprout — print what the TTS says).
- **Yellow:** Ornate gold-frame girl-variant art ("The Brave Explorer", "The Art Wizard") is band-perfect; distinct from Sprout's chibi and it *feels* older.
- **Blue:** **Right**. Playground 9/10.

### Team page — "PICK YOUR FRIENDS!" (3 slots)
- **Yellow:** 3-slot team = age-right step-up from Sprout's single buddy. Personality copy sings ("Loud warning system. Always on your side."). "Ember is ready!" slot feedback is great.
- **Black:**
  1. **P1 — Next button below the fold.** After picking a companion, no forward affordance is visible in-viewport; a 7yo may not scroll. (MT-279 gave Explorer single-tap-advance on *some* pages; team + scene still require a hidden Next.)
  2. P2 — "Add from Photo" shown even when the parent photo toggle is off (default) — child taps into a dead end or a parent gate; hide when disabled.
  3. P3 — secondary options pile up (Add from Photo / Add My Pet / Add a Grown-up / real-pet banner / Go Solo): 5 side paths vs 4 main choices.
- **Green:** Float a sticky "Next →" pill that appears (with a pop) the moment slot 1 fills; collapse the three "Add …" buttons into one "+ Add your own" sheet.

### Scene — "WHERE TO ADVENTURE?"
- **Black:**
  1. **P1 (= MT-268, confirmed live):** "Rainbow World" tile is the identical kawaii-bunny candy art served to 3-year-olds; visibly babyish next to "Cave Full of Crystals". The good `scenes/explorer/` art remains orphaned.
  2. P1 — Next below the fold again (same pattern as team page).
  3. P3 — "Imagine It" free-form tile art is markedly girl-coded (pink pastel bedroom) for a both-genders feature.
- **Yellow:** "Pick a world or make your own!" copy is exactly band-level; Crystal Cave art is aspirational without being scary.

### Story style — "WHAT KIND OF STORY?" + wish panel
- **White:** 4 tiles: Story Quest (pre-selected), Rhyme Time, **Pick a Path**, Easy Reader. Below: "What do you want to do? Pick a wish for your story — or skip it!" tiles + Next.
- **Black:**
  1. **P2 — wish tiles render as large near-empty purple slabs** with a tiny label ("Do real magic", "Outsmart the villain") — art missing/unloaded; looks broken and wastes a full viewport.
  2. P3 — Superhero Mode (extended to Explorer per Phase 6) not visible on this page — verify where it surfaces (may be intentional).
- **Yellow:** Pick a Path + Easy Reader at this band = exactly right menu. "…or skip it!" reduces pressure.

### Review — "YOUR ADVENTURE AWAITS!"
- **Yellow:** Orb shows the child's actual avatar + scene label (MT-262 fix confirmed live); length pills (Short tale / Story time / Big adventure) are a nice, comprehensible size control; ornate MAKE MAGIC button is a moment.
- **Black:** **P1 — summary row says "Picture tale" after the child picked "Story Quest"** (label mismatch, MT-278 class) — and it foreshadowed the reader bug below.

### Generation + Reader — "Sing, Little Crystal" (10 pages)
- **Yellow:** Scene fidelity worked this run (crystal cave story for crystal cave pick). Per-illustration "AI" badges are honest. Manual "Love it" (vs Sprout auto-save) is the right ≥6 behavior.
- **Black:**
  1. **P0 — no readable story text in the reader.** Every page is a pure illustration panel; a 7-year-old READER gets nothing to read, and Easy Reader/Read-Along value is invisible. Coupled with the review's "Picture tale" label, likely the picture-book mode was applied despite the Story Quest pick — one root cause, two symptoms. (Verify `magic_review_step`/`wizard_data_mapper` story-type mapping for Explorer.)
  2. **P0 (shared with Sprout) — hero look mutates every page:** brown-hair/yellow-dress p1 → orange-hair/purple-skirt p2 → green-top/pink-pants p3. Ember (picked companion) absent entirely.
  3. P3 — tapping the page art flips forward with no visible "back" affordance until hover; kids will overshoot.
- **Green:** Fix the mode mapping first (it may also explain Sprout's caption-only pages); then prompt-anchor hero/companion appearance per the Sprout P0.

## Action Plan (Explorer)

| Priority | Screen | Issue | Change | Effort |
|---|---|---|---|---|
| P0 | Reader | No story text for a reading band; "Picture tale" served for "Story Quest" pick | Fix story-type mapping Explorer→quest; ensure text pages render | M |
| P0 | Reader | Hero mutates per page; companion absent | Same prompt-anchoring fix as Sprout P0 | M |
| P1 | Team + Scene | Next button below fold | Sticky Next pill appears on selection | S |
| P1 | Scene | Babyish shared Rainbow World art (MT-268) | Generate scenarios/explorer/ set (blocked on Imagen, owner) | M |
| P1 | Avatar modal | Pool not gender-aware (6–7♀ of 8 either way) | Weight pool by pick | S |
| P2 | Story style | Wish tiles are empty purple slabs | Add art or compact to chips | S |
| P2 | Team | "Add from Photo" visible while parent toggle off | Hide when disabled | S |
| P2 | Wizard p1 | Girl pre-selected | No default | S |
| P3 | Scene | "Imagine It" art girl-coded | Neutral dreamscape art | S |
| P3 | Reader | Tap = forward only | Left-third tap = back | S |

**Simplify:** collapse 3 "Add…" companion buttons into one sheet; wish tiles → chip row.
**Combine:** selection + Next (sticky pill on select = one continuous gesture).
**Elevate:** Read-along karaoke highlight as the *default* Explorer text mode (it exists — surface it); companion reaction sound when slotted ("Ember is ready!" + a tiny roar).
