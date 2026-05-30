# Adventurer (Ages 9–12) UX + Age-Appropriateness Audit — 2026-05-29

Third band in the per-band sweep, after `SPROUT_UX_AUDIT_2026-05-04.md` (3–5) and the
Explorer (6–8) pass. Method: code walkthrough of every Adventurer-conditional surface —
theme, home screen, full creation wizard, delight widgets, and backend content
calibration — judged against what a literate, genre-aware, gaming-fluent 9–12-year-old
actually wants. Band boundary confirmed at `lib/providers/age_band_provider.dart:31-38`
(`age <= 11` → Adventurer; 12 → Creator).

## Summary

**Adventurer has the strongest *intentional* design of any band so far.** The cosmic
indigo/teal palette, the Bitter slab-serif "book" typography, the reduced sparkle (0.3 vs
Explorer's 1.0), the RPG **Mission Briefing** review screen, the treasure-map loading
animation, the walnut-leather open-book frame (MT-099), and the genuinely sophisticated
9–12 Big Feelings rules all say *"you're not a little kid anymore"* — exactly right for
this age. When the band is specialised, it's specialised *well*.

**The problems are two kinds of leakage, not absent intent:**

1. **Younger-band content leaking up.** Pick a non-standard story mode and the
   sophistication evaporates. A 9-year-old who taps **Superhero** gets a story built from
   the *3–5-year-old* template — 130 words, preschool vocabulary, "Sock Goblin" villains.
   Rhyme Time and Learning-to-Read collapse 7→12 into one template. This is the most
   damaging finding in the audit: the app promises maturity, then hands a capable reader a
   toddler story.

2. **Generic treatment leaking through.** Several high-traffic surfaces ignore the band
   system entirely — the home CTA literally says **"Make Magic"** (the young-band string),
   the character cards and achievements card are hard-coded purple/green, and the scene
   picker shows a 10-year-old the same bare tile a 7-year-old sees. The 9–12-year-old keeps
   bumping into moments that feel one or two bands too young.

A 9–12-year-old would **love** the Mission Briefing, the treasure map, and the book frame.
They would be **annoyed** every time they hit "Make Magic," an undifferentiated Pick-a-Path,
or a personality they can't tune — and **actively let down** the first time they try
Superhero mode. The fixes are mostly cheap (string/colour/grouping) except the two content
gaps (Superhero tier, word-count truth), which are real work.

A dedicated **[Annoyances & Friction](#annoyances--friction-per-your-ask)** section collects
the "this would bug a 10-year-old" findings in one place, per request.

---

## Findings

### CONTENT / AGE-APPROPRIATENESS (backend)

#### A-001 — Superhero mode serves 9–12 the 3–5 (Sprout) story template ⛔
**Where:** `backend/services/prompt_versioning.py:83-87`; template body `backend/services/prompt_service.py` (T6 superhero-sprout block); matrix `backend/data/superhero_matrix.py`
**Issue:** Routing is `if 6 <= age <= 8 → T7_SUPERHERO_EXPLORER; else → T6_SUPERHERO_SPROUT`. There is **no Adventurer branch**, and `superhero_matrix.py` only defines Sprout and Explorer tiers. So ages 9–12 fall through to the **Sprout** template: ~130-word cap, "ONLY very simple words a 3–5 year old knows," 3–7-word sentences, "Sock Goblin / Bedtime Bandit" villains. There is no `test_superhero_matrix_adventurer.py`, confirming the tier was never built.
**Impact:** **Critical.** A 9–12-year-old picking the most aspirational mode in the app receives a story calibrated *four grades* below them. This is the single worst age-appropriateness break in the band — and superheroes are squarely in this age's wheelhouse.
**Recommendation:** Add an Adventurer superhero tier (T8): real stakes, a genuine antagonist with a motive, 900–1800 words, Grade 3–4 vocab, powers with cost/limits. At minimum, route 9–12 to the Explorer tier (T7) as a stopgap so they at least get the 6–8 treatment, not the 3–5 one.
**Effort:** M (stopgap reroute: S; full tier + matrix + tests: M–L)

#### A-002 — Three-way word-count contradiction; the "400-word max" is a live truncation risk
**Where:** `backend/services/prompt_service.py:179-187` (250–400 max), `lib/services/story_complexity_service.dart:51-60` (`minWords:250, maxWords:400`), vs the authoritative `backend/services/story_service.py:57-68` `"8-10"` band (`regular medium 1200–1800`, long `1800–2400`). Test `tests/test_age_calibration.py` asserts age-10 prompts contain `"1200-1800 words"`.
**Issue:** Standard generation correctly uses the 1200–1800 AGE_CONSTRAINTS, but two other layers still declare a hard **250–400-word ceiling** for 9–12, with copy like "STOP at 400 words maximum." Today that's mostly dead/legacy, but it's a landmine: any validation, fallback, or legacy path that reads `_get_age_guidelines()` or `StoryComplexityService` would either reject or truncate a correct 1500-word Adventurer story to a third of its length.
**Impact:** High (correctness/consistency). A 9–12-year-old getting a story chopped at 400 words would feel cheated.
**Recommendation:** Make 1200–1800/1800–2400 the single source of truth. Update or delete the `prompt_service.py` cap and the Dart `AgeGroup` for 9–12 so all three agree.
**Effort:** S

#### A-003 — Rhyme Time gives age 9 and age 12 the identical generic instruction
**Where:** `backend/services/prompt_service.py` `_get_rhyme_time_instructions(age)` (the `age` param is accepted but never branched on)
**Issue:** One template for everyone: "AABB or ABAB… keep it silly and fun." The age-appropriateness test suite (`backend/tests/unit/test_story_age_appropriateness_suite.py`) *expects* a "ballad-style rhyming story / no sing-song bouncy limericks / ABCB ballad scheme" for age 10 — but the code never emits it. Test is aspirational; code is generic.
**Impact:** Medium. "Silly bouncy rhymes" is an Explorer register; a 10–12-year-old wants ballad/narrative verse, not nursery rhyme.
**Recommendation:** Branch `_get_rhyme_time_instructions` by band; give 9–12 a ballad/couplet register. Closes the gap the test already documents.
**Effort:** S

#### A-004 — Learning-to-Read collapses ages 7–12 into one limerick template
**Where:** `backend/services/prompt_versioning.py:90-94` (`7 <= age <= 12 → T2_LTR_LIMERICK`)
**Issue:** A 7-year-old and a 12-year-old get the same limerick LTR structure. (Mitigated by the frontend hiding the "Learning to Read" orb for age 9+ — see A-011 context — so this is mostly unreachable from the wizard, but still reachable via other entry points and inconsistent.)
**Impact:** Low–Medium (low reach, but inconsistent calibration).
**Recommendation:** Either confirm LTR is intentionally Explorer-and-below and gate it off entirely for 9+, or add an Adventurer LTR register. Don't leave it half-wired.
**Effort:** S

#### A-005 — Content moderation has no Adventurer tier — and it can strip the genre twists the wizard just sold
**Where:** `backend/utils/content_moderator.py:93-100` (`age <= 12 → "a child aged 8-12"`) and rule block ~226-231
**Issue:** 9–12 is lumped with age 8 under one "child aged 8-12" label, with a vague "content that would be frightening or harmful for {age_label}" rule. Meanwhile the wizard actively offers 9–12 a **Spooky / Action / Mystery** genre twist (A-013). There's no moderation headroom that says "mild peril and spooky atmosphere are *fine* for 9–12" — so the moderator can flag/soften exactly the content the genre chip promised.
**Impact:** Medium. Promise/delivery mismatch: pick "👻 Spooky," get something de-fanged. Frustrating and confusing.
**Recommendation:** Add a 9–12 moderation tier that explicitly permits mild supernatural tension, suspense, and non-graphic peril while still blocking gore/sexual content/self-harm. Align the allowance with the genres the UI sells.
**Effort:** M

> ✅ **Well-calibrated already (keep):** Standard-mode `"8-10"` constraints (Grade 3–4 vocab, 12–20-word sentences, two-step plot, "show competing feelings," "hero can be wrong and correct themselves") are genuinely 9–12-grade. The interactive **Big Feelings 9–12 rules** (`backend/services/interactive_adventure_prompt_builder.py`, ~814-825 — "humiliated, overwhelmed, resentful… never therapeutic-sounding… repair should feel brave and credible, not neat or instant") are the best age-tuned content in the codebase. Don't touch these.

---

### THEME / HOME SCREEN (frontend)

#### A-006 — The home "Make Magic" CTA treats a 12-year-old like a 6-year-old
**Where:** `lib/main_story.dart:902` — `band.isMature ? 'Start Story' : 'Make Magic'`; `isMature` is Creator/Adolescent/Adult only (`lib/theme/age_band_theme.dart:576-588`), so Adventurer falls to the young string. Button colour is hard-coded `Colors.deepPurpleAccent` (`main_story.dart:895`), not the band's indigo/teal.
**Issue:** The single most-tapped button on the home screen says "Make Magic" — the same whimsical string a Sprout/Explorer sees. Adventurer's whole theme works to shed the "magic" register (teal not gold, sparkle 0.3, Bitter serif), and then the primary CTA undoes it. The binary `isMature` grouping has no slot for the "bridge" band.
**Impact:** High (it's the hero action, seen every session). Reads as babyish.
**Recommendation:** Give Adventurer its own CTA string — "Start the Adventure" / "Begin the Quest" — and theme the button with `band.primary`/`band.accent`. Cheapest: add an Adventurer case rather than overloading `isMature`.
**Effort:** S

#### A-007 — Saved-character cards and quick-play orb ignore the band palette
**Where:** `lib/main_story.dart` `_CharacterPortraitCard` (~1535-1667): hard-coded gradient `[0xFF6B3FA0, 0xFF3D1166]`, gold selection border, hard-coded `0xFF7C3AED` quick-play bolt, hard-coded "✨ Adventure" CTA text.
**Issue:** The character row — a focal, identity-laden surface for this age — renders in generic Explorer-ish purple regardless of band. Adventurer's indigo/teal never appears here.
**Impact:** Medium. Visual incoherence with the rest of the (well-themed) Adventurer home.
**Recommendation:** Drive the gradient/border/orb from `band.primary`/`band.accent`/`band.gradient*`.
**Effort:** M

#### A-008 — Achievements card is hard-coded white/green, outside the theme system entirely
**Where:** `lib/main_story.dart` `_buildAchievementsOverviewCard` (~1302-1407)
**Issue:** Plain white card, green progress bar — no band colours, same for every age. On Adventurer's dark cosmic home it reads as a generic widget dropped in.
**Impact:** Low–Medium. Same issue flagged for Sprout (S-001); a band-aware achievements card would fix it everywhere.
**Recommendation:** Theme from band colours; for Adventurer lean into the "mission log / rank" framing (ties to A-018).
**Effort:** M

#### A-009 — AppBar subscription/tier badge uses hard-coded colours
**Where:** `lib/main_story.dart:553-582,895` (`Colors.deepPurpleAccent`, `Colors.white`)
**Issue:** Minor, but part of the same pattern: top-of-screen chrome isn't band-aware.
**Impact:** Low.
**Recommendation:** Fold into the A-006/A-007 theming pass.
**Effort:** S

---

### WIZARD FLOW (frontend)

#### A-010 — "Pick a Path" is offered to a 12-year-old exactly as it's offered to a 3-year-old
**Where:** `lib/screens/wizard_steps/hero_creator_story_type_page.dart` (mode orbs, ~469-551); routed tone is the only band difference (`magic_review_step.dart` tone switch → Adventurer = `fantasy`).
**Issue:** The interactive mode card, label ("You choose what happens!"), and visual treatment are identical across all bands. A child who "graduated" Sprout/Explorer sees no signal that this is a deeper, more consequential branching experience for them.
**Impact:** Medium (annoyance + missed delight). Feels like a kiddie feature.
**Recommendation:** Give Adventurer a distinct Pick-a-Path pitch ("Every choice changes the outcome — can you reach the best ending?") and lean on branch depth/consequence in the backend tone. Visual parity with the Mission Briefing aesthetic.
**Effort:** M

#### A-011 — Scene picker hides the conflict hook it already has for this age
**Where:** `lib/screens/wizard_steps/hero_creator_scene_page.dart` (scene tiles, ~92-131); `ScenarioData` already exposes `conflictHookForAge()` (used by the Mission Briefing in `lib/widgets/adventurer_character_sheet.dart`).
**Issue:** At *selection* time a 10-year-old sees only "Crystal Cavern" — the same bare title a 7-year-old sees. The age-specific premise hook exists in the data but isn't surfaced until after they've already chosen.
**Impact:** Medium (missed delight). Choosing a setting is a key creative moment; a one-line premise would make it feel literary.
**Recommendation:** Show `conflictHookForAge(age)` as a one-line subtitle on each Adventurer scene tile. The content already exists — it just needs wiring forward.
**Effort:** S

#### A-012 — Personality is archetype-locked; no way to tune it
**Where:** Archetype sets personality sliders in `hero_creator_step.dart` (~821); slider UI exists only in Guardian/parent mode (`feeling_selection_step.dart` ~686-742), not exposed to the child.
**Issue:** A 9–12-year-old can pick "Brave Knight" but can't make them "brave but sarcastic" or "brave but shy." This age *defines themselves* through nuanced character customisation — it's the core fun of every game they play.
**Impact:** Medium (missed delight; mild frustration for power users).
**Recommendation:** Surface 2–3 personality nudge toggles for Adventurer after archetype pick (e.g., Bold↔Cautious, Serious↔Funny, Lone Wolf↔Team Player). Feeds the prompt directly.
**Effort:** M

#### A-013 — Genre twist: multi-select behaviour and combination are unclear
**Where:** `lib/screens/wizard_steps/hero_creator_story_type_page.dart:554-640` (chips: 🔍 Mystery, 😂 Comedy, 🚀 Sci-Fi, ⚔️ Action, 👻 Spooky, 💕 Romance)
**Issue:** Good news vs the March audit — the chips now have icons. Remaining gaps: it's unclear whether chips are single- or multi-select, and the chosen combination is only weakly echoed downstream (review appends "· 🔍 Mystery"). A 10-year-old who taps Sci-Fi + Spooky has no confirmation the blend will be honoured. (See A-005: even when honoured, moderation may flatten Spooky.)
**Impact:** Medium (annoyance). Genre blending is the most-loved screen for this age — ambiguity here costs real delight.
**Recommendation:** Make select/deselect state unmistakable; if multi-select, show a live "Your story: Story Quest · 🚀 Sci-Fi · 👻 Spooky" summary on the review/Mission Briefing screen.
**Effort:** S

#### A-014 — VERIFY: companion images on the review screen (cross-band bug in the March audit)
**Where:** review/Mission Briefing companion render; March `ux_audit_adventurer_10yo` logged broken × icons on both Explorer and Adventurer review screens.
**Issue:** Not re-confirmed in this code-only pass. If still broken, it lands at the emotional peak (the Mission Briefing "PARTY" line) and is maximally deflating.
**Impact:** Potentially Critical (unverified).
**Recommendation:** Run the wizard to the Mission Briefing with 2 companions and confirm the PARTY avatars render; if broken, add an emoji+name pill fallback.
**Effort:** S to verify

> ✅ **Wizard wins (keep):** typed-name-primary with voice as comfort option (right for this literacy); strategic companion personalities (Atlas "I've mapped three routes," Nyx "I know a way through"); 5-line free-text "Imagine It" with a good range of example prompts; explicit Next (no Sprout auto-advance); "Your adventure is being written…" loading copy.

---

### DELIGHT WIDGETS — mostly strong, keep and amplify

These are working. Listed so they're protected from regressions and as the foundation to build on:

- **Mission Briefing review** (`lib/screens/wizard_steps/magic_review_step.dart` → `lib/widgets/adventurer_character_sheet.dart`): RPG stat card — NAME/CLASS/ROLE/POWER/PARTY, "MISSION READY" button. The single best Adventurer moment. ⭐⭐⭐⭐⭐
- **Treasure-map loading** (`lib/widgets/avatar_loading_bands/adventurer_treasure_map.dart`): parchment terrain, progressive landmark reveal (compass→castle→dragon→chest), tappable + haptics. Turns dead wait time into a quest. ⭐⭐⭐⭐⭐
- **Open-book frame / book feel** (`lib/widgets/open_book_frame.dart` NEW MT-099, `storybook_page.dart`): per-band walnut leather for Adventurer reads as a real hardback. ⭐⭐⭐⭐⭐
- **Life Quest 9–12** (`lib/screens/life_quest_screen.dart`, `lib/data/life_quest_data.dart`): real social scenarios ("The Empty Seat," "The Comment"), coping toolbox, rewind-to-retry. Emotionally mature, respectful. ⭐⭐⭐⭐
- **Theme system** (`lib/theme/age_band_theme.dart` Adventurer block): indigo/teal, Bitter serif, sparkle 0.3, "ADVENTURER EXCLUSIVE" badge. The intent is exactly right. ⭐⭐⭐⭐

---

## Make-them-love-it opportunities (delight backlog)

Beyond fixing the leaks, the highest-leverage *additions* for this age:

1. **Build the real Adventurer Superhero tier** (closes A-001 *and* adds delight): proper villains with motives, powers with limits, sidekicks. This age loves superhero canon — meet it. **Highest combined fix+delight value.**
2. **A persistent "Party" / roster** — companions that recur across stories, with the Mission Briefing as the home base. 9–12 collect and build; give them continuity.
3. **Progression that feels like leveling, not badges** (extends A-008): rank/XP/mission-log framing reusing the achievement data already in `achievement_service.dart` (rarity tiers exist; reskin to "Recruit → Ranger → Legend").
4. **Chapter / serialized stories** — this age reads chapter books. Offer multi-part arcs that continue a saved hero. Backend already supports long (1800–2400).
5. **Surface the scene premise hooks** (A-011) — cheap, makes setting choice feel literary.
6. **Personality nudges** (A-012) — the customisation depth this age expects.
7. **Share / show-off path** — let a 9–12-year-old export or share a finished story; social pride is a strong driver here (gate appropriately for COPPA — no public profiles).

---

## Annoyances & Friction (per your ask)

The moments most likely to make a 9–12-year-old roll their eyes or feel let down,
ordered by how much they'd sting:

| Rank | Friction | Where | Why it bugs a 10-year-old |
|------|----------|-------|---------------------------|
| 1 | **Superhero mode hands them a toddler story** | A-001 | Picks the coolest option, gets 130 baby words. Betrayal of the whole "cool" promise. |
| 2 | **Home button says "Make Magic"** | A-006 | The most-seen action talks down to them every session. |
| 3 | **Pick Spooky/Action → get something de-fanged** | A-005, A-013 | Promise/delivery mismatch; "that wasn't spooky at all." |
| 4 | **Pick-a-Path looks identical to the 3-year-old version** | A-010 | "Isn't this the baby feature?" |
| 5 | **Can't make the character *theirs*** (personality locked to archetype) | A-012 | Customisation depth is the point at this age; archetype-only feels shallow. |
| 6 | **Scene tiles are bare names, no hook** | A-011 | Choosing feels like a menu, not a story. |
| 7 | **Genre multi-select is ambiguous; combo not confirmed** | A-013 | Taps two, unsure it "took." |
| 8 | **Character cards / achievements look generic** | A-007, A-008 | Visual register slips back toward the younger bands. |
| 9 | **(If still present) broken companion images on review** | A-014 | Deflation at the triumphant Mission Briefing peak. |
| 10 | **Latent 400-word truncation risk** | A-002 | A clipped story would feel broken and cheap. |

Net: the *frustration* is concentrated where the band drops back to a younger or generic
treatment — non-standard story modes (1, 3), undifferentiated shared UI (2, 4, 8), and
shallow customisation (5, 6, 7). None of the band's *own* designed surfaces frustrate; it's
the seams between Adventurer and the rest of the app.

---

## Priority table

| # | Finding | Severity | Effort | Type |
|---|---------|----------|--------|------|
| 1 | A-001 Superhero → Sprout template | ⛔ Critical | M | Content |
| 2 | A-006 "Make Magic" CTA + unthemed button | 🔴 High | S | UX |
| 3 | A-002 250–400 vs 1200–1800 word contradiction | 🔴 High | S | Correctness |
| 4 | A-014 VERIFY companion images on review | 🔴 High* | S | Bug (unconfirmed) |
| 5 | A-005 No 9–12 moderation tier vs genre twists | 🟠 Med | M | Content/Safety |
| 6 | A-013 Genre select/combination clarity | 🟠 Med | S | UX |
| 7 | A-011 Surface scene conflict hooks | 🟠 Med | S | Delight |
| 8 | A-010 Pick-a-Path band differentiation | 🟠 Med | M | UX/Delight |
| 9 | A-012 Personality nudges | 🟠 Med | M | Delight |
| 10 | A-007 Character cards ignore band theme | 🟠 Med | M | UX |
| 11 | A-003 Rhyme Time no age branch | 🟡 Low–Med | S | Content |
| 12 | A-008 Achievements card unthemed | 🟡 Low–Med | M | UX |
| 13 | A-004 LTR 7–12 collapse | 🟡 Low | S | Content |
| 14 | A-009 AppBar badge colours | 🟢 Low | S | UX |

### Top 3 if only three fixes ship
1. **A-001** — build (or at least reroute) the Adventurer superhero tier. The only break that makes the band actively *worse* than the one below it.
2. **A-006** — one-line CTA + button-colour fix; instantly stops the home screen from talking down to them.
3. **A-002** — make the word count one truth; removes a latent truncation bug and aligns front/back end.

---

*Audit by code walkthrough across theme, home, wizard, delight widgets, and backend
content calibration. Headline backend/CTA findings (A-001, A-002, A-006) verified against
source. A-014 is the one item needing a live run to confirm. Next band in the sweep:
Creator (12–14).*
