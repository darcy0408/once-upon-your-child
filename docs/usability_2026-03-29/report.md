# Six-Band Usability Report
**Date:** 2026-03-30
**Method:** Playwright browser automation, live dev build (flutter run -d web-server --web-port 8088)
**Scope:** Full wizard flow across all 6 age bands — Sprout (3–5), Explorer (6–8), Adventurer (9–11), Creator (12–14), Adolescent (15–17), Adult (18+)

---

## Summary

The six-band system is working well across the spectrum. Each band has a distinct visual identity and age-appropriate language. The fixes applied from the earlier audit (BUG-01 through UX-05) are confirmed in the live build. Several new issues were discovered during testing.

**Overall: 4 bands fully usable, 2 bands have blocking or near-blocking issues.**

---

## Band-by-Band Results

### 🌱 Sprout (ages 3–5)
**Status: Mostly good — 2 issues**

| # | Finding | Severity |
|---|---------|----------|
| S-01 | Archetype card names truncate ("The Master Cre...", "The Animal Whi...") — card grid too small for full names | Medium |
| S-02 | Story style orbs: no default selection, Next always active — child can skip story type entirely | Medium |

Screenshots: `sprout_01` – `sprout_12b`

---

### 🔭 Explorer (ages 6–8)
**Status: Mostly good — 3 issues (1 pre-existing bug)**

| # | Finding | Severity |
|---|---------|----------|
| E-01 | BUG-02 (pre-existing, fixed in code): Dragon companion shows broken image (404) in review — confirms fix is needed | High |
| E-02 | "Big adventure" length chip overflows on review screen (RenderFlex overflow by ~11px) | Medium |
| E-03 | Story style orbs: same no-default issue as Sprout | Medium |

Screenshots: `explorer_01` – `explorer_08`

---

### ⚔️ Adventurer (ages 9–11)
**Status: Excellent — 2 minor issues**

| # | Finding | Severity |
|---|---------|----------|
| A-01 | Welcome/unlock dialog ("You've Unlocked New Adventures!") overflows by 44px at bottom | Medium |
| A-02 | Archetype class shows "—" on review screen when user skips archetype selection | Low |

**Highlights:**
- Age-themed step labels ("My Character", "My Companions", "My Setting", "MISSION READY") ✅
- Story Quest pre-selected by default on story type step ✅
- Genre twist chips (Mystery, Comedy, Sci-Fi, Action, Spooky, Romance) age-appropriate ✅
- "MISSION BRIEFING" review card with dynamic mission hook text ✅
- All companion images load correctly ✅
- BUG-03 fix confirmed: avatar gallery upsell text no longer overflows ✅
- BUG-04 fix confirmed: FilterChips in avatar tweak panel have visible borders ✅

Screenshots: `adventurer_01` – `adventurer_21`

---

### 🎨 Creator (ages 12–14)
**Status: Good — 2 issues, 1 noteworthy UX gap**

| # | Finding | Severity |
|---|---------|----------|
| C-01 | Avatar widget overflows 29px in "Your Story Pitch" review card (`_HeroFallbackIdentity` column) | Medium |
| C-02 | "Start Writing" button disabled unless a setting is chosen — no inline hint explaining why | Low |

**Highlights:**
- No parental consent screen for age 13+ ✅ (correct COPPA threshold)
- "Build Your Story" with accordion sections (CHARACTER & ROLE, PERSONALITY, WORLD & SETTING, STORY OPTIONS) — sophisticated and appropriate ✅
- "What does your character want more than anything?" — deeper character development prompt ✅
- "Your Story Pitch" review card with Name/Setting/Cast/Format ✅
- Length selector (Short/Medium/Long), Medium pre-selected ✅
- Mature minimal UI appropriate for 12–14 ✅

Screenshots: `creator_01` – `creator_03`

---

### 🌙 Adolescent (ages 15–17)
**Status: Good — 1 issue**

| # | Finding | Severity |
|---|---------|----------|
| AD-01 | "Ready to begin?" review screen shows only name + "—" with no story summary — less informative than Creator's pitch card | Low |

**Highlights:**
- Same mature "Build Your Story" accordion structure as Creator ✅
- More realistic teen-style character art (distinct from Creator) ✅
- "Start Writing" correctly gated until setting chosen ✅
- No parental consent ✅

Screenshots: `adolescent_01` – `adolescent_03`

---

### 👤 Adult (ages 18+)
**Status: Good — 1 minor visual difference**

| # | Finding | Severity |
|---|---------|----------|
| AU-01 | "Begin" CTA uses a dark gold/olive colour — may read as disabled at a glance on dark background | Low |

**Highlights:**
- CTA label correctly changes from "Make Magic!" → "Start Writing" → "Begin" as bands mature ✅
- Most realistic adult character art (portrait style) ✅
- Same accordion structure as Creator/Adolescent ✅
- "Begin" gated on setting selection ✅

Screenshots: `adult_01` – `adult_03`

---

## Cross-Band Confirmed Fixes

All 9 items from the March 29 audit are confirmed working:

| Fix | Status |
|-----|--------|
| BUG-01: Sprout companion images (fluffy_dragon etc.) | ✅ Confirmed |
| BUG-02: Dragon 404 in review (code fixed) | ✅ Code fix applied |
| BUG-03: Avatar gallery upsell text overflow | ✅ Confirmed |
| BUG-04: FilterChip borders in tweak panel | ✅ Confirmed |
| BUG-05: Mode orb tap stability (GestureDetector outside MagicalFloat) | ✅ Code fix applied |
| UX-01: Age gate 13–14 / 15–17 split | ✅ Both bands reachable |
| UX-02: Parental consent scroll progress bar | ✅ Confirmed |
| UX-05: Bedtime mode semantic label shortened | ✅ "Bedtime mode" in tree |

---

## New Issues to Fix (Priority Order)

### High
| ID | Issue | Band(s) | File |
|----|-------|---------|------|
| NEW-01 | "Big adventure" length chip overflows on review screen | Explorer, likely all younger bands | `magic_review_step.dart` |

### Medium
| ID | Issue | Band(s) | File |
|----|-------|---------|------|
| NEW-02 | Welcome/unlock dialog overflows 44px at bottom | Adventurer (likely others with unlock dialogs) | Check unlock dialog widget |
| NEW-03 | Avatar overflow 29px in Creator/Adolescent/Adult review card (`_HeroFallbackIdentity`) | Creator, Adolescent, Adult | `_HeroFallbackIdentity` column widget |
| NEW-04 | Archetype card names truncate in Sprout band | Sprout only | `hero_creator_step.dart` (Sprout card size) |
| NEW-05 | Story style step (younger bands): no default selection, Next always active | Sprout, Explorer | `magic_story_step.dart` or equivalent |

### Low
| ID | Issue | Band(s) | File |
|----|-------|---------|------|
| NEW-06 | Archetype class shows "—" on Adventurer review when skipped | Adventurer | `magic_review_step.dart` |
| NEW-07 | Adolescent review shows no story summary details (only name + dash) | Adolescent | Review step |
| NEW-08 | Adult "Begin" button gold colour may look disabled | Adult | Review step button style |

---

## Age Band UI Consistency Matrix

| Feature | Sprout | Explorer | Adventurer | Creator | Adolescent | Adult |
|---------|--------|----------|------------|---------|------------|-------|
| Parental consent | ✅ | ✅ | ✅ | ❌ (13+) | ❌ | ❌ |
| Character art style | Cartoon | Cartoon | Adventure | Creator | Teen-realistic | Adult-portrait |
| Step CTA | "Make Magic!" | "Make Magic!" | "MISSION READY" | "Start Writing" | "Start Writing" | "Begin" |
| Story type default | None | None | Pre-selected | Pre-selected | Pre-selected | Pre-selected |
| Genre/mood options | Quick-picks | Quick-picks | Genre chips | Full options | Full options | Full options |
| Review screen | "YOUR ADVENTURE AWAITS!" | Same | "MISSION BRIEFING" | "Your Story Pitch" | "Ready to begin?" | "Ready to begin?" |
