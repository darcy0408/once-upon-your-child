# Sprout Verification Walkthrough

**Closes (if green):** MT-057, MT-058, MT-059, MT-060, MT-061, MT-062
**Bonus read:** MT-035 console output

**Scope:** one Chrome session against `flutter run -d chrome` (your local repo, includes the MT-062 quest integration committed in `56865c6b`). Backend = production Railway. Total walk: **~40 min focused.**

---

## TL;DR — what each phase tests

| Phase | Min | Tests | Bottom line |
|-------|-----|-------|-------------|
| 0 | 3 | Setup | `flutter run -d chrome`, DevTools open, console verbose |
| 1 | 4 | MT-057 | Welcome-back tap-to-start tile + demoted "create new" |
| 2 | 4 | MT-060A | Wizard skips empty build-hero page when only 1 option |
| 3 | 4 | MT-060B | Sprout taps companion → auto-advance after 1.4s |
| 4 | 4 | MT-053 + MT-061 setup | Big Feelings tile → 4-animal grid (LifeQuestScreen) |
| 5 | 12 | MT-062 | Walk all 4 new Sprout quests (Pup/Bunny/Lion/Mouse) |
| 6 | 5 | MT-061 buddy + MT-059 orb | Buddy shows on Sprout coping; orb animates on Explorer |
| 7 | 4 | MT-058 | Sprout LTR ≥5 pages, ≤25 words/page |
| 8 | 2 | MT-035 | Read console for `charactersJson=...` |

---

## Phase 0 — Boot up (3 min)

```powershell
# In the repo root (C:\dev\story-weaver-app)
flutter run -d chrome
```

Chrome opens. While it builds:
- **F12** → Console tab
- Console filter level: click "Default levels" → tick **"Verbose"** (so `debugPrint` appears)
- Console filter box: type `MT-035` and pin it for later — keeps the relevant lines visible. Clear filter when not in the save flow.
- (Optional cold-start) DevTools → Application → Local Storage → right-click `localhost` → Clear

When the splash gone and you're at the welcome screen, you're ready.

> **If the build errors:** check `flutter analyze lib/data/life_quest_data.dart` — should be `No issues found`. If a quest paste went wrong (unlikely; was clean at commit time) the quest data file is the suspect. Open the file at `~line 5928` and look for missing commas or unterminated strings.

---

## Phase 1 — MT-057: Welcome-back tap-to-start (4 min)

> Commit `a9b4bd41`. Welcome screen prompt brighter; bottom CTA demoted from gold ElevatedButton → small underlined TextButton.icon.

### 1A — Cold start (no saved character yet)

**Navigation:** fresh app load (after `localStorage.clear()` in Phase 0, or first ever).

**Look for:**
- Welcome screen does **not** show a Welcome Back tile
- Walk through age-gate → name entry → reach wizard

If you walk through and create a character, that creates the test data for 1B. Use a **Sprout-age character (3-5)** since we'll need it for phases 4-6. Suggested test record:
- **Name:** `Tester` (or any 5-7 char name)
- **Age:** `4`
- **Gender:** any

Save the character (let the wizard auto-save on the result screen).

### 1B — Returning user (saved character exists)

**Navigation:** refresh the Chrome tab (Ctrl+R or F5). The localStorage persists across reloads.

**Look for:**
- ✅ Welcome Back screen shows your saved character tile
- ✅ Top prompt reads **"Tap your character to start a story!"** in **16px white w600** — should look noticeably brighter/bigger than the surrounding text
- ✅ Bottom CTA is a small **underlined "Or create someone new"** with a `+` icon (NOT a gold filled button)
- ✅ Tapping the saved-character tile auto-advances into the wizard, character pre-loaded — **no "Go" press**
- ✅ Tapping "Or create someone new" → loads create-new flow

**If broken:** the prompt text or icon style is wrong → check `lib/screens/wizard_steps/hero_creator_step.dart:_buildPage0()`. The TextButton.icon with `Icons.add_circle_outline` should be at line ~874.

---

## Phase 2 — MT-060A: Skip-empty-build-hero (4 min)

> Commit `1e80d9c8`. Wizard should not show the "How do you want to build your hero?" page when only one path is real.

**Setup:** non-premium / no parental photo consent (default state for fresh anon user works).

**Navigation:** Welcome Back → tap "Or create someone new" (or fresh start). Pick **age 3-5** (Sprout). Enter name + gender on page 1.

**Tap Next.**

**Look for:**
- ✅ **Avatar gallery opens immediately** — no "How do you want to build your hero?" interstitial with one lonely button
- Pick an avatar → land on archetype page
- ✅ Tap **Back** on archetype → lands on **name/gender page**, NOT on an empty single-button page

**If broken:** the gate logic in `_handleContinue()` or page sequencing is wrong. Take a screenshot of the unexpected page and note which "Back" landing was wrong.

**Skip-if-no-premium-account:** the path *with* parental consent + premium should show the build-hero choice page (gallery + photo = 2 real options). If you want to test, toggle parent consent ON in parent gate. If not, skip — the negative case is the higher-value test.

---

## Phase 3 — MT-060B: Sprout companion auto-advance (4 min)

> Same commit. Sprout-age (≤5) taps on `CompanionImageGrid` should auto-advance after ~1.4s. Older bands should NOT.

**Navigation:** Continue the Sprout walkthrough from Phase 2 → reach the **Adventure Team / companions** page.

**Look for:**
- ✅ Tap any magical companion in the grid — wizard auto-advances to the scene page **after ~1.4s without tapping Next**
- ✅ Quick re-tap a different companion before the timer fires — should NOT double-fire (timer re-arms)
- ✅ "**Adventure alone!**" still works (no companion → tap → advances)
- ✅ Tap a saved-character friend chip (FriendChipButton, separate row) — should NOT auto-advance (intentionally manual)

### Cross-band negative check (60 sec)

- Back out to Welcome → create an Explorer-age character (age 7) **OR** edit existing Sprout to age 7 if your wizard supports
- Walk to the same companions page → tap a magical companion
- ✅ Should NOT auto-advance (only Sprout band, age ≤ 5, gets the hook)

**If broken:** auto-advance fired on Explorer → check the age-band gate in `companion_selector_step.dart` (or wherever the timer is wired). Auto-advance didn't fire on Sprout → check the post-frame callback / `mounted` guard.

---

## Phase 4 — MT-053 + MT-061 setup (4 min)

> Commit `1c668c0a`. Sprout entry to LifeQuestScreen renders 4 animals, not 3 broken clouds.

**Navigation:** Continue Sprout walkthrough → scene picker page (the grid of scene tiles with names like "Volcano Dragons", "Underwater Castle", etc.).

**Look for:**
- ✅ **Big Feelings** tile is visible in the grid (not hidden, not in an awkward 3:1 lonely row)
- Tap **Big Feelings** →
- ✅ Opens **LifeQuestScreen** (rich screen, NOT a thin "pick a cloud" modal)
- ✅ **2×2 grid renders 4 animals**: Sunny Pup (top-left), Rainy Bunny (top-right), Roary Lion (bottom-left), Shy Mouse (bottom-right)
- ✅ TTS plays: **"Tap a friend! Sunny Pup, Rainy Bunny, Roary Lion, Shy Mouse."**

> **Old broken state to confirm we're past:** 3 dark Pixar clouds with Sunny missing.

### MT-061 watch-item — rectangular-stamp risk (visual judgment, 60 sec)

The 4 sprout PNGs (`happy.png`/`sad.png`/`mad.png`/`scared.png`, regenerated 2026-05-06) are **8-bit RGB, no alpha channel** — opaque rectangular backgrounds. Same format as the old ones, but the new ones are 1254×1254 vs old 1024×1024 with possibly different bg tinting.

These same PNGs are also read by the **in-wizard `FeelingsCloudPicker`** via `_FaceImage` → `AgeBandAssetResolver.feelingPath`. There they're clipped inside a squircle-shape with its own tinted background.

**To check:** Sprout flow no longer routes through `FeelingsCloudPicker` (per MT-053 — Creator+ only now). So this concern only matters if you also walk a **Creator/Adolescent/Adult** character to a feelings picker that uses the cloud cards.

- ✅ **If you walk a mature band into a cloud picker:** confirm the 4 emotion cards don't show a hard-edged tinted square sitting visibly inside the squircle's tint. If they do → fix path is to generate transparent-bg PNG variants OR change `BoxFit.contain` → `BoxFit.cover` at `lib/widgets/feelings_cloud_picker.dart:714,718,727` (cover crops face — only do if assets aren't replaceable).
- 🔵 **Skip if you don't naturally hit a cloud picker** — the risk doesn't apply to Sprout's animal-friends grid.

### Continue: tap each friend, confirm 2 quests each

- ✅ Tap **Sunny Pup** → quest list shows: `The Big Hello`, `The Warm Heart` (newly integrated)
- ✅ Tap **Rainy Bunny** → quest list shows: `The Big Bear Hug`, `The Bye-Bye Big Feeling` (new)
- ✅ Tap **Roary Lion** → quest list shows: `My Turn, Your Turn`, `The Big NO` (new)
- ✅ Tap **Shy Mouse** → quest list shows: `The Big Loud`, `The First Hi` (new)

> **If a "new" quest is missing from a friend's list:** the `friend:` field on the const definition is wrong, or the const isn't in `allLifeQuests`. Check `lib/data/life_quest_data.dart` line 144-151 for the registration block.

---

## Phase 5 — MT-062: Four newly integrated Sprout quests (12 min)

> Walk each new quest end-to-end: open → confirm coping break → walk both first-choice branches to a different ending. ~3 min per quest.

For each quest:
1. Open the quest from the friend's list
2. Read segment 1 prose (verify exact text below)
3. Confirm **coping break card** fires before choices on segment 1
4. Tap the **first** first-choice → walk to an ending → note which one (`{name}` interpolation should fill in)
5. Hit Back / Restart → tap the **second** first-choice → walk to a different ending

### 5a — `questGoodbyeHug` / Rainy Bunny / sad / **Belly Breath** (3 min)

**Open:** Bunny → **The Bye-Bye Big Feeling**

**Segment 1 prose:** "It is morning. You are eating toast.\n\nYour grown-up puts on their shoes..."

- ✅ **Belly Breath** coping break card fires after the prose, before choices
- ✅ Branch A: **"Hold on tight to their leg"** → reaches `gb_hold` → choose `gb_hug` or `gb_breath` ending
- ✅ Branch B: **"Use your words"** → reaches `gb_words` → choose `gb_kiss` or `gb_wave` ending
- ✅ `{name}` interpolation in `gb_hold` ("I see your big sad, **[name]**")

### 5b — `questBigNo` / Roary Lion / mad / **Dragon's Breath** (3 min)

**Open:** Lion → **The Big NO**

**Segment 1 prose:** "You see the cookies on the counter.\n\n\"Cookie, please?\"\n\nGrown-up shakes their head..."

- ✅ ALL-CAPS "NOOOO!" renders in the prose
- ✅ **Dragon's Breath** coping break card fires
- ✅ Branch A: **"Stomp your feet"** → reaches `bn_stomp` → choose `bn_smaller` or `bn_when` ending
- ✅ Branch B: **"Roar it out like a dragon"** → reaches `bn_roar` (with "ROOOOAAAARRR!") → choose `bn_when` or `bn_pick` ending
- ✅ `{name}` interpolation in `bn_smaller` ("You did good, **[name]**")

### 5c — `questFirstHi` / Shy Mouse / scared / **Star Breath** (3 min)

**Open:** Mouse → **The First Hi**

**Segment 1 prose:** "It is your cousin's birthday party.\n\nYou walk in. So many people!..."

- ✅ **Star Breath** coping break card fires
- ✅ Branch A: **"Stay close to your grown-up"** → reaches `fh_close` → choose `fh_wave` or `fh_tuck` ending
- ✅ Branch B: **"Peek out and look around"** → reaches `fh_peek` → choose `fh_smile` or `fh_star` ending
- ✅ `{name}` interpolation in `fh_star` ("You did the brave thing, **[name]**")

### 5d — `questWarmHeart` / Sunny Pup / grateful / **Hot Cocoa Breath** (3 min)

> The most distinct of the four — Hot Cocoa Breath is the savor-the-good technique, NOT a regulate-down-from-distress technique. Verify the copy reflects "smell / cool" not "in / out."

**Open:** Pup → **The Warm Heart**

**Segment 1 prose:** "DING DONG.\n\nThe mail brought a package!\n\nA grown-up reads the tag..."

- ✅ **Hot Cocoa Breath** coping break card fires — confirm prompts say **"Smell the cocoa... cool it down..."** (NOT "in through nose, out through mouth" — that's belly breath)
- ✅ Branch A: **"Call to say thank you"** → reaches `wh_call` → choose `wh_specific` or `wh_breath` ending
- ✅ Branch B: **"Draw them a picture back"** → reaches `wh_draw` → choose `wh_sign` or `wh_sparkle` ending
- ✅ `{name}` interpolation in `wh_specific` ("You found the love I put inside it, **[name]**") and `wh_sign`

> **If any coping break card is missing or wrong technique:** the `copingBreakId` on segment 1 is wrong. The IDs are `belly_breath` / `dragon_breath` / `star_breath` / `hot_cocoa_breath`.

---

## Phase 6 — MT-061 buddy + MT-059 orb animation (5 min)

### 6A — Sprout buddy in coping break (2 min)

**Navigation:** Re-open one of the Sprout quests from Phase 5 → trigger any coping break (segment 1).

**Look for (this is the buddy/animal-friend layer added by `1c668c0a`):**
- ✅ **Intro card** shows the **buddy portrait in a soft accent-glow circle** (Pup/Bunny/Lion/Mouse depending on quest)
- ✅ **Buddy pep-talk** reads — e.g. "Rainy Bunny will breathe through the sad with you."
- ✅ **Practice frame** shows the **buddy clipped to a circle scaling 0.45→1.0** with the breath, NOT the standalone orb

> The buddy replaces the orb on **Sprout** quests only. Older bands fall through to the orb.

### 6B — Explorer Coping Toolbox orb (3 min)

**Navigation:** Back to Welcome → create or switch to an **Explorer (age 7-8)** character → into the wizard → My Quests tab → **Coping Toolbox** strip at top.

**Belly Breath (4s in / 4s out × 4):**
- ✅ Tap **Belly Breath** card → "Let's go!" button → confirm:
  - Blue orb visibly **grows over 4s**, holds at full size briefly, **shrinks over 4s**
  - Glow blur **swells with the orb** (aura matches scale)
  - Pattern repeats 4 cycles → "You did it!" appears

**Dragon's Breath (4s in / 1s hold / 6s out × 3):**
- ✅ Tap Dragon's → orange orb, same animation but different timing/color, 3 cycles

**5-4-3-2-1 (grounding, prompt-cycling):**
- ✅ Tap 5-4-3-2-1 → green orb stays at half scale, prompt text cycles every 6-12s

### 6C — Explorer in-story break (negative for buddy)

- ✅ Walk an Explorer Life Quest with a coping break (e.g. *Tryout* → Star Breath)
- ✅ The break shows the **orb** (NOT the buddy — older bands pass `buddy: null`)
- ✅ "Done early" returns cleanly to the quest

> **If orb is static** (doesn't animate): MT-059 fix didn't take. Check `lib/widgets/coping_practice_sheet.dart` for `TweenAnimationBuilder<double>` keyed on `'orb-c{cycle}-s{step}'` (commit `294d6e67`).

---

## Phase 7 — MT-058: Sprout LTR ≥5 pages × ≤25 words (4 min)

> Backend fix `cd222b08`, deployed 2026-05-06 08:02. Should be live on Railway.

**Navigation:** Switch back to your Sprout (age 3-5) character → start a new story → at the story-type picker, select **"Listen and Learn easy words"** / Read-Along.

**Generate.** The sparkle-catcher mini-game runs while the AI generates.

**Look for:**
- ✅ Story has **≥5 pages** (count by tapping Next; was 2 in repro)
- ✅ Each page has **≤25 words** (eyeball — short sentences, ~3 lines max)
- ✅ The **final page actually ends the story** (closing beat — not a cliffhanger or mid-action)

**Then generate a regular Story Quest Sprout story:**
- ✅ Word check ≤25/page (note: regular flow has no validator — over-runs may slip; flag if egregious)

### Watch the Railway worker log

I can't see it, but: warnings like `LTR format check failed` indicate retries. **1 retry** = normal (validator caught + retried). **2 failed attempts** = model is still ignoring the constraint and we need to escalate.

You can pull the log later via: `railway logs --service grand-light` (or via Railway dashboard).

> **If LTR returns 2 pages still:** the prompt fix isn't deployed yet OR the model regressed. Verify `git log -1 cd222b08` is in `origin/main` AND check Railway dashboard for current deployed commit.

---

## Phase 8 — MT-035: Console output read (2 min)

> The story-save in Phase 7 (or any Sprout auto-save during the walkthrough) fires the `[MT-035]` debugPrints. We want to capture them.

**Navigation:** During or right after any Sprout story save (auto-save fires when a Sprout-age story-result screen lands), check the DevTools Console.

**Filter:** Type `MT-035` in the console filter box.

**Expected output (5 lines per save):**
```
[MT-035] widget.characterName=Tester
[MT-035] widget.characterAge=4
[MT-035] characters.length=1
[MT-035] characters.names=[Tester]
[MT-035] storyLocal.charactersJson=[{"id":"...","name":"Tester","age":4,"role":"Hero",...}]
```

**The diagnostic question:**
- ✅ If `storyLocal.charactersJson=[{...}]` (real JSON): **bug is dead**, charactersJson persists fine. MT-035 can close as fixed.
- ❌ If `storyLocal.charactersJson=null`: **bug is live, root cause is upstream**. Check the input lines:
  - `characters.length=0` → upstream of `_saveStory`: `_character` is null AND `widget.characterName` is empty/null. Check `WizardData` propagation.
  - `characters.length=1` but `charactersJson=null` → impossible per `StoryLocal.fromSavedStory` logic; would mean `Character.toJson()` returned empty, worth investigating.

### Save the lines

Right-click in the console → "Save selected as..." or copy-paste them into the close-session record. They're load-bearing for either closing MT-035 or filing the next investigation step.

---

## After the walk — wrap-up

**If most/all green:**
1. Edit `docs/MANUAL_TASKS.md`: change `[open]` → `[done]` and append `(closed by <session-id>)` for: MT-057, MT-058, MT-059, MT-060, MT-061, MT-062, and possibly MT-035
2. PROJECT_STATUS.md known-issue #5 (the ~55 untracked PNGs) is **stale** — `.gitignore` already covers all the patterns. Remove or strike that line.
3. PROJECT_STATUS.md line 95 says "Test suite: 294/294 green" — actual is **288/294**. Either fix per MT-063 (the 6 stale `hero_creator_step_test.dart` failures) or update the line.
4. `git push` so Railway redeploys with the MT-062 quests in production.
5. Run `/close-session` to record the verification.

**If anything red:**
- File a new MT for each failure with the specific failure mode (page-X-screen-X-expected-Y-saw-Z).
- Keep the original MT open.
- Don't push if MT-062 quest rendering is broken — local is fine, prod can wait.

**If you only get partway through:**
- The phases are mostly independent. Stopping after Phase 5 still closes MT-062 + MT-061 + MT-053. The remaining are the more polish-y verifies.
- Note where you stopped in your close-session record so the next pickup point is clear.
