# Sprout Verification Walkthrough — 2026-05-06

**Closes:** MT-057, MT-058, MT-059, MT-060, MT-061, MT-062 (newly integrated)
**Bonus read:** MT-035 console output

**Setup:** `flutter run -d chrome` against the local repo (picks up the MT-062 quest integration this session). Backend will use production Railway. Open Chrome DevTools console — the `[MT-035]` debug lines fire on every story save and we want to read them while we're already in there.

**Estimated walk time:** ~35-45 min focused, faster if no surprises.

---

## Phase 0 — Prep

- [ ] `flutter run -d chrome` is running, app loaded, splash gone
- [ ] DevTools console open (F12 → Console). Filter set to "Verbose" so `debugPrint` shows
- [ ] (Optional) Clear `localStorage` if you want a true cold-start: `localStorage.clear()` then refresh

---

## Phase 1 — MT-057: Welcome-back tap-to-start (cold + saved)

> Commit `a9b4bd41`. Welcome screen prompt brighter, "Or create someone new" demoted to underlined TextButton.

**First-time path (no saved character):**
- [ ] Welcome screen renders without a Welcome Back tile
- [ ] Walk through age gate → name entry → reach wizard

**Returning-user path:**
- [ ] After saving at least one character, refresh app
- [ ] Welcome Back screen leads with **"Tap your character to start a story!"** (16px white w600 — bigger/brighter than the old white70)
- [ ] Bottom CTA is a small **underlined "Or create someone new"** TextButton.icon (NOT the old gold ElevatedButton)
- [ ] Tile-tap on the saved character auto-advances into the wizard with that character pre-loaded — **no "Go" press required**
- [ ] "Or create someone new" tap loads the create-new flow

---

## Phase 2 — MT-060A: Skip-empty-build-hero page (Sprout, no photo consent)

> Commit `1e80d9c8`. The "How do you want to build your hero?" page should not show when only one option is available.

- [ ] Start a new Sprout (age 3-5) hero in the wizard, parental photo consent OFF
- [ ] Enter name + gender on page 1, tap Next
- [ ] **Avatar gallery opens immediately** — no intermediate "How do you want to build your hero?" page with one lonely button
- [ ] Pick an avatar → land on archetype page
- [ ] Tap **Back** on archetype → lands on name/gender, NOT on the empty single-button page

(If you have a premium account with parental consent ON, optionally re-walk to confirm the build-hero choice page DOES appear when both gallery + photo are real options. Skip if no premium.)

---

## Phase 3 — MT-060B: Sprout companion auto-advance

> Same commit. Sprout taps on `CompanionImageGrid` should auto-advance after ~1.4s.

- [ ] Continue a Sprout walkthrough to the **Adventure Team / companions** page
- [ ] Tap any magical companion in the grid → wizard auto-advances to the scene page after ~1.4s **without tapping Next**
- [ ] Quick re-tap a companion before the timer expires — should not double-fire (timer re-arms)
- [ ] **"Adventure alone!"** still works — tap → advances
- [ ] Tap a saved-character friend chip (FriendChipButton, separate from the magic-companion grid) — should NOT auto-advance (intentionally manual)

**Cross-band check (optional):**
- [ ] Walk an Explorer (6-8) to the same page → confirm it does **NOT** auto-advance (only Sprout gets the hook)

---

## Phase 4 — MT-053 + MT-061: Big Feelings tile → animal-friends grid

> Commit `1c668c0a`. Sprout entry to LifeQuestScreen.

- [ ] Continue Sprout wizard to scene picker page
- [ ] **Big Feelings** tile is present in the scene grid
- [ ] Tap Big Feelings → opens **LifeQuestScreen** (not the old thin "pick a cloud" modal)
- [ ] 2×2 grid renders 4 animals: **Sunny Pup, Rainy Bunny, Roary Lion, Shy Mouse**
- [ ] TTS says **"Tap a friend! Sunny Pup, Rainy Bunny, Roary Lion, Shy Mouse."** (was previously broken — 3 dark Pixar clouds with Sunny missing)

### MT-061 watch-item: rectangular-stamp risk in `FeelingsCloudPicker`

The 4 sprout PNGs (`happy.png`/`sad.png`/`mad.png`/`scared.png`, regenerated 2026-05-06) are **8-bit RGB, no alpha channel** — opaque rectangular backgrounds. The animal-friends grid in LifeQuestScreen is fine (rectangular cards), but the same PNGs are also read by the in-wizard `FeelingsCloudPicker` `_FaceImage` via `AgeBandAssetResolver.feelingPath`. There they're clipped inside a squircle/cloud-shape with its OWN tinted background.

- [ ] Open the Sprout in-wizard feelings picker (path: any wizard flow that hits the cloud picker, e.g. mature-band Big Feelings flow). If it doesn't appear in your usual Sprout flow you can skip — modal flow is now Creator+ only per MT-053.
- [ ] **If visible:** confirm the 4 emotion cards don't show a hard-edged tinted square sitting inside the squircle. If they do, fix is either `BoxFit.cover` on `_FaceImage` (`lib/widgets/feelings_cloud_picker.dart:714,718,727`) — but that crops the face — or generate transparent-background PNG variants. Document which.

### Continue MT-061

- [ ] Tap each friend → opens that friend's filtered quest list with 2 quests each (Pup 2, Bunny 2, Lion 2, Mouse 2 — see Phase 5)
- [ ] Tap **The Big Hello** (Sunny Pup) → walk end-to-end, confirm all 3 endings reachable: `bh_hug`, `bh_show`, `bh_breath`

---

## Phase 5 — MT-062: Four newly integrated Sprout quests

> Integrated this session into `lib/data/life_quest_data.dart` after `questBigHello`, registered in `allLifeQuests`. `flutter analyze` clean.

For each new quest: open it via the friend's filtered list, walk **both first-choice branches** to a different ending, confirm coping break fires correctly on segment 1.

### 5a — `questGoodbyeHug` / Rainy Bunny / sad / Belly Breath

- [ ] **The Bye-Bye Big Feeling** appears in Bunny's filtered list (alongside `questBigBearHug`)
- [ ] Open it → segment 1 prose renders: "It is morning. You are eating toast..."
- [ ] **Belly Breath coping break card** fires before choices on segment 1
- [ ] Walk left branch ("Hold on tight") → reach `gb_hug` or `gb_breath` ending
- [ ] Walk right branch ("Use your words") → reach `gb_kiss` or `gb_wave` ending
- [ ] `{name}` interpolation works in `gb_hold` ("I see your big sad, [name]")

### 5b — `questBigNo` / Roary Lion / mad / Dragon's Breath

- [ ] **The Big NO** appears in Lion's filtered list (alongside `questMyTurnYourTurn`)
- [ ] Open → ALL-CAPS "NOOOO!" renders in prose
- [ ] **Dragon's Breath coping break card** fires before choices
- [ ] Walk "Stomp" branch → `bn_smaller` or `bn_when`
- [ ] Walk "Roar" branch → `bn_when` or `bn_pick`
- [ ] `{name}` interpolation in `bn_smaller`

### 5c — `questFirstHi` / Shy Mouse / scared / Star Breath

- [ ] **The First Hi** appears in Mouse's filtered list (alongside `questBigLoud`)
- [ ] Open → segment 1 about cousin's birthday party renders
- [ ] **Star Breath coping break card** fires before choices
- [ ] Walk "Stay close" → `fh_wave` or `fh_tuck` ending
- [ ] Walk "Peek" → `fh_smile` or `fh_star` ending
- [ ] `{name}` interpolation in `fh_star` ("You did the brave thing, [name]")

### 5d — `questWarmHeart` / Sunny Pup / grateful / **Hot Cocoa Breath**

> Specifically check Hot Cocoa Breath — the savor-the-good technique. Should be visually + verbally distinct from the other three breathing techniques.

- [ ] **The Warm Heart** appears in Pup's filtered list (alongside `questBigHello`)
- [ ] Open → "DING DONG. The mail brought a package!" prose, "soft little hat" gift
- [ ] **Hot Cocoa Breath coping break card** fires — confirm copy is "smell the cocoa / cool it down" (not belly/dragon/star)
- [ ] Walk "Call to say thank you" → `wh_specific` or `wh_breath` ending
- [ ] Walk "Draw them a picture" → `wh_sign` or `wh_sparkle` ending
- [ ] `{name}` interpolation in `wh_specific`, `wh_sign`

---

## Phase 6 — MT-061 buddy-on-coping-break + MT-059 orb animation

> Two layered changes (`294d6e67` + `1c668c0a`) tested in one flow.

### Sprout in-story buddy (MT-061)

- [ ] During any Sprout quest's coping break (e.g. one of the four above, or *Big Bear Hug* "Take a big breath" → Belly Breath), confirm:
  - [ ] Intro card shows the **buddy portrait in a soft accent-glow circle**
  - [ ] Buddy pep-talk reads (e.g. "Rainy Bunny will breathe through the sad with you.")
  - [ ] Practice frame shows the **buddy clipped to a circle scaling 0.45→1.0** with the breath, NOT the orb

### Explorer Coping Toolbox — orb animation (MT-059)

- [ ] Switch to an Explorer (6-8) character, navigate to **My Quests** tab → **Coping Toolbox** at top
- [ ] Tap **Belly Breath** → "Let's go!" — confirm:
  - [ ] **Blue orb visibly grows over 4s**, holds at full size briefly, shrinks over 4s, repeats 4 cycles
  - [ ] Glow blur swells with the orb (aura matches scale)
  - [ ] After 4 cycles, "You did it!" appears
- [ ] Try **Dragon's Breath** (orange orb, 4s in / 1s hold / 6s out × 3) — same animation pattern, different color/timing
- [ ] Try **5-4-3-2-1** (green orb stays at half scale, prompt cycles every 6-12s)

### In-story break path (Explorer)

- [ ] Walk an Explorer quest with a coping break (e.g. *Tryout* → Star Breath, *Left Out* → Belly Breath)
- [ ] Confirm the **orb renders (not the buddy)** — older bands pass `buddy: null`
- [ ] "Done early" returns cleanly to the quest

---

## Phase 7 — MT-058: Sprout LTR ≥5 pages × ≤25 words

> Backend fix `cd222b08` deployed 2026-05-06 08:02. Production should be ready.

- [ ] As a Sprout character, generate a **"Listen and Learn easy words" / Read-Along** story
- [ ] Count pages — **expect ≥5** (was 2 in repro)
- [ ] Each page **≤25 words**
- [ ] Final page actually ENDS the story (closing beat, not a cliffhanger)
- [ ] Generate a **regular Story Quest** Sprout story → similar word check (≤25/page is prompt-side only on regular flow; over-runs may slip)

**Watch the Railway worker log** for `LTR format check failed` warnings:
- 1 retry = normal
- 2 failed attempts = model is still ignoring — escalate

---

## Phase 8 — MT-035: Console output read

> Existing `[MT-035]` debugPrints + the one I added this session (post-conversion `charactersJson` value).

While walking any of the above Sprout flows, when a story saves automatically (Sprout auto-save on story-result landing for ages ≤ 5), the console should print:

```
[MT-035] widget.characterName=<name>
[MT-035] widget.characterAge=<age>
[MT-035] characters.length=<1 or 0>
[MT-035] characters.names=<list>
[MT-035] storyLocal.charactersJson=<JSON or null>
```

- [ ] Capture the values for one Sprout save. Particularly: is `storyLocal.charactersJson` null or a real JSON string?
- [ ] If null → bug confirmed live, root cause is upstream of `StoryLocal.fromSavedStory` (one of `_character`, `widget.characterName`, or the `WizardData` propagation chain)
- [ ] If non-null → bug is downstream, in `OfflineStoryService.saveStory` or the SharedPreferences encoding layer

---

## After the walk

If most/all green, close-session and:
- [ ] Mark the closed MTs `done` in `docs/MANUAL_TASKS.md`
- [ ] Update `MT-061` with whether the rectangular-stamp risk materialized
- [ ] Update `MT-035` with the console reading
- [ ] PROJECT_STATUS.md known-issue #5 (~55 untracked PNGs) is **stale** — `.gitignore` already covers all the patterns. Remove that line.

If anything red, file a new MT and keep the original open.
