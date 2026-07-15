# Image Cohesion Audit — co-displayed asset groups (2026-07-15)

Trigger: owner flagged the Explorer "Choose your setting" screen (washed-out Imagine It card,
blurry dragon tile vs crisp crystal cave). That screen was fixed the same day (see "Fixed in
this session" below); this audit reviews every other surface where multiple images render
together, plus per-band variants of the same surfaces.

Method: four parallel review agents traced each asset group to its render site in lib/
(file:line evidence), viewed the images, and graded each co-displayed set on style cohesion,
palette/exposure consistency, sharpness vs render size, aspect/crop fit, baked text/watermark
artifacts, and broken/placeholder art. ~170 images viewed. The four most consequential claims
(FREEPIK watermark, adult-coded feelings faces, BYTE QUEEN gender card, both one-line code
bugs) were independently re-verified by the lead session before this report was written.

---

## Fixed in this session (shipped alongside this audit)

- `assets/images/scenarios/dragon_friends_btn(.pressed).webp` — rebuilt at 1024×625 (was
  360×220 / 9 KB) from the crisp `sleeping_dragon.webp` story illustration; same cute-3D
  style as the rest of the young set. Pressed = +22% brightness to match the set's press flash.
- `assets/images/scenarios/imagine_it_btn_pressed.webp` — replaced the pale 360×220 watercolor
  with an 18:11 crop of the rich 1024² `imagine_it_btn.webp` night scene (kid + owl + books);
  the square original (which had a baked "11:1" artifact, cropped away) was deleted from the
  bundle. The Sprout-only contrast ColorFilter in `scene_widgets.dart` that compensated for
  the pale art was removed.
- `hero_creator_scene_page.dart` — saving from the Imagine It screen now auto-advances the
  wizard (calls `onContinue()`), consistent with preset-tile auto-advance for ≤8 (MT-279).
  Sprout TTS line shortened to "Great idea!".

---

## P0 — legal / safety / functional bugs (recommend fixing before next release)

1. **FREEPIK watermark shipping in the app.** `assets/images/feelings/adolescent/surprised.webp`
   is a stock image with a tiled diagonal FREEPIK watermark across the entire frame — visible
   on the adolescent feelings picker AND a licensing exposure (unlicensed stock in a paid app).
   VERIFIED. Fix: replace with a generated render in the band's style.
2. **Adult-coded emotion faces bundled in a COPPA-focused kids' app.**
   `assets/feelings_faces/aroused.webp` (baked "Aroused" label + seductive smirk — VERIFIED),
   `intimate.webp` (two kissing faces), `violated.webp`. No code path displays them, but
   `pubspec.yaml` bundles the whole folder, so they ship in every build and are extractable
   from the APK. Also garbage-word files from the poster-crop batch: `auctiole.webp`,
   `blowly.webp`, `snawed.webp`. Fix: delete the unreachable files (only ~70 of 157 ids are
   reachable from wheel data).
3. **Six feelings silently degrade to emoji — one-line fix.** `_FaceImage`
   (`lib/widgets/feelings_cloud_picker.dart:706,710`) uses raw wheel ids; hyphenated ids
   (`hurt-mad`, `what-if-y`, `red-faced`, `wish-i-could-hide`, `grossed-out`, `let-down`)
   never match the underscore filenames that exist in every band folder. VERIFIED. Fix:
   normalize `id.replaceAll('-','_')` (mapping already documented in
   `docs/assignments/UX_AUDIT_FIX_PLAN.md:438`). Note `can't-wait` has no asset anywhere.
4. **Blank gender cards, Adventurer band, Custom Avatar screen.**
   `lib/custom_avatar_screen.dart:1164` requests `gender_adventurer_$g.webp`; only `.jpg`
   exists (the wizard uses `.jpg` at `hero_creator_step.dart:3037,3262`). SafeAssetImage
   renders an empty box. VERIFIED. One-line extension fix.
5. **Near-blank feeling card on the 6-8 core grid.** `assets/feelings_faces/embarrassed.webp`
   is 99.86% transparent — an effectively empty card on the Explorer band's primary emotion
   picker. Fix: generate an explorer-band `embarrassed.webp`.

## P1 — worst co-displayed clashes on live screens (ranked)

1. **Adventurer (9-12) feelings core grid** — three colliding art systems:
   `assets/images/feelings/adventurer/{happy,angry,sad}.webp` are flat logo-badges with baked
   ALL-CAPS labels AND a baked fake-transparency checkerboard, next to one 3D character
   (`surprised.webp`) and low-res B/W clipart (`bad/fearful/disgusted` from feelings_faces).
   Fix: regenerate 3 files in the `surprised.webp` style + add band bad/fearful/disgusted.
2. **Sprout archetype 2×2 grid** (`hero_creator_step.dart:3601`) — three presentation
   treatments in one grid: `sprout/animal_whisperer_boy.webp` is a mid-frame crop of a
   jeweled-frame card (broken-screenshot look) and both animal_whisperer files carry a baked
   "Animal Friend!" caption that the widget then duplicates with its own label;
   `brave_hero_boy/girl.webp` have a baked gold frame + dark studio backdrop next to two
   frameless bright scenes. Fix: regenerate 4 files frameless/caption-free.
3. **Adolescent gender picker pair** — `assets/images/ui/gender/gender_adolescent_girl.webp`
   is detailed neon cyber art with baked "BYTE QUEEN" / "DATAWAVE" text next to a clean flat
   blue boy silhouette (VERIFIED; contradicts the silhouette intent stated at
   `hero_creator_creative_brief.dart:246-248`). Fix: silhouette girl matching other bands.
4. **Explorer feelings core grid** — `feelings_faces/frustrated.webp` (B/W clipart, baked
   label) and 200px `worried.webp` beside 3D Pixar-style kids. Fix: generate explorer-band
   worried/frustrated (adventurer folder already has them).
5. **Explorer companion grid** — `companions/explorer/ember.webp` is 400×400 3D-CGI in a
   1024px painterly matched set (robin/clover/biscuit); blurry at tile size. Fix: regenerate.
6. **Adult + Creator scene-picker sets** (`scenarios/adult/`, `scenarios/creator/`) — styles
   clash within each set: flat-vector crystal cavern vs photoreal lighthouse vs soft-real
   dragon; creator imagine_it is photographic-CG among vector tiles. The adult
   `vanishing_colors.webp` is a near-white gray field (deliberately "vanished" but reads as
   washed out at tile size). Lower priority: mature users, and each set is at least dark-toned
   consistently. Adolescent + Adventurer scene sets are cohesive — no action.
7. **Adolescent archetype card** — `archetypes/adolescent/quiz_whiz_girl.webp` has legible
   garbled AI text ("Albert Imodelen" quote, "MODERK APROPRECA" book spines). Fix: inpaint or
   regenerate.
8. **Adult archetype grid** — `adult/lightning_runner_boy+girl.webp` are portrait 1024×1536 in
   a landscape set; cover-crop cuts legs/ground-lightning and zoom clashes. Fix: re-render 3:2.
9. **Creator companions** — photoreal `rockin_robin.jpg` vs flat-anime `cipher.jpg` is the
   widest companion style gap; also sparkle-glyph watermarks fully visible on mature cards
   (BoxFit.contain shows corners that ClipOval crops elsewhere). Fix at next art pass.
10. **Adolescent world grid (13 tiles)** — impressively cohesive; only `neon_jungle.webp` is a
    flat-2D outlier among photoreal-cinematic renders; `standing_tall`/`change_is_coming` are
    ~1 stop too dark under the label scrim. Fix: regenerate one, lift shadows on two.
11. **Sprout companions** — `mochi.jpg` is the only black-background image (renders as a black
    disc among white discs) with an AI sparkle glyph in the corner. Fix: regenerate/knock out bg.
12. **Adult feelings grid** — `adult/happy.webp` is a desaturated gray statue that doesn't read
    "happy"; `surprised`/`sad` have floating-object artifacts. Fix at next art pass.

## P2 — content/label mismatch needing an owner decision

- **Sprout scene picker labels vs art vs story.** For age ≤5 the volcano_dragons tile shows
  DRAGON art labeled "Stomp with the Dinosaurs!", and the offline Sprout scaffold
  (`story_scaffolds.dart:272-283`) is genuinely a dinosaur story — a pre-reader picks by
  picture and gets a different story than the picture promised. Same class as MT-311.
  crystal_cavern is labeled "Under the Sea!" over crystal art. The plumbing to fix exists
  (`ScenarioCard.illustrationForAge` + `assets/images/ui/sprout/tiles/{dinosaurs,ocean,...}`)
  but `hero_creator_scene_page.dart` hardcodes the shared art instead of calling it.
  Decision needed: align tile art to the sprout story themes (use illustrationForAge for
  Sprout) — or align the sprout titles/stories back to the pictures. Weigh against MT-311
  history before changing.
- **Superhero review orb wrong subject** — the `superhero` scenario's Magic Review art is the
  360×220 *Big Feelings meditation tile* (`scenario_data.dart:684`): wrong subject, under-res.

## P3 — dead weight shipping in every build (~17 MB)

Whole-folder pubspec globs bundle everything; these are rendered nowhere:

| Group | Size | Notes |
|---|---|---|
| `assets/images/ui/` dead files | ~6.2 MB | 30+ loose files (incl. .jpg/.webp duplicate pairs, 3 filenames with spaces), glassy/ folder, clean/ orbs, per-band button sets only reachable via a broken `.png` uiPath (`image_continue_button.dart:103`, `image_make_magic_button.dart:49` — callers pass .png, files are .webp) |
| `assets/images/scenes/` sprout/creator/adolescent/adult | ~6.5 MB | `scenePath` only ever called with explorer/adventurer (`scenario_data.dart:177,183`) |
| `assets/images/orbs/` | all 18 | `orbPath` has zero callers — AND the set is mis-generated (photoreal characters instead of progress orbs, anatomy artifacts, chevron-down "done" icon); delete rather than fix |
| `assets/images/backgrounds/` | all | `backgroundPath` has zero callers; several files have baked AI artifacts ("1:5", "1:1" + frame, garbled fake-UI screenshot in creator/story_page_bg) — regenerate before ever wiring |
| `assets/images/themes/` + `quick_story_screen.dart` | 6 files | QuickStoryScreen is unreachable dead code; delete screen + assets (forest.webp is also a black-cornered outlier) |
| `assets/mood_lanterns/` + `mood_lantern_data.dart` | ~735 KB | Cohesive set, but `kMoodLanterns` imported nowhere — wire or drop |
| `assets/feelings_faces/` unreachable files | ~half of 157 | Includes the P0 adult-coded/garbage files |
| `archetypes/` root loose files | — | `ArchetypeCard`/`ArchetypeWheelSelector` never instantiated; `storm_rider.jpg` referenced nowhere |
| `lib/emotion_recognition_game.dart` | — | Dead code; also broken (.png vs .webp — every image falls to placeholder) |

Latent path bugs worth fixing if these ever get wired: `AgeBandAssetResolver.archetypePath`
builds `.jpg` names that don't exist in any band folder; `uiPath` callers pass `.png` names
for `.webp` files.

## Sets that passed under scrutiny

- Adolescent scene-picker set + 13-tile world grid (minus neon_jungle) — best set in the app.
- Adventurer scene-picker set (dragon is soft/atmospheric by style, acceptable).
- Adolescent companions (matched fantasy paintings), adventurer archetypes, adult archetypes
  (minus lightning_runner), sprout feelings watercolors (pup/bunny/lion/mouse), midjourney
  avatar gallery (150 files, uniform style, metadata consistent), sprout tile set
  (`ui/sprout/tiles/`) — clean and cohesive but currently unused by the scene picker (see P2).

## UPDATE (same day): P3 purge EXECUTED + size audit

The dead-asset purge ran on 2026-07-15 (same session, owner-approved). Every deletion was
re-verified by grep against lib/ + test/ before removal — the per-file check found MORE dead
weight than the original ~17 MB estimate:

- **assets/: 61.1 MB → 36.9 MB (−24.2 MB, ~40%). 295 files deleted.**
- Deleted: orbs/ (all), backgrounds/ (all), themes/ (all), mood_lanterns/ (all),
  scenes/{sprout,creator,adolescent,adult}, 122 dead ui/ files (kept: clean/make_magic pair,
  creator_white.webp, gender/, sprout/tiles/), 101 unreachable feelings_faces (incl. the P0
  adult-coded + garbage files — that item is now CLOSED), 5 dead root archetype jpgs (the
  *_framed.webp stay — they're the live ungendered fallback via imagePathForBand), the
  gender_creator_alt_girl.webp exact-duplicate, and the empty "New folder".
- Dead code removed: quick_story_screen.dart, mood_lantern_data.dart,
  emotion_recognition_game.dart, image_continue_button.dart; orbPath/backgroundPath/uiPath
  dropped from AgeBandAssetResolver; ImageMakeMagicButton's never-loadable per-band branch
  simplified to the clean/ assets. 24 pubspec asset entries removed.
- Verified: flutter analyze clean; 26 widget tests across feelings garden, wizard flow,
  hero-creator steps pass.

### Remaining condensation opportunities (measured by trial conversion, NOT yet applied)

| Change | Files | Savings | Risk/effort |
|---|---|---|---|
| scenes/*.jpg → webp q85 (needs scenePath '.jpg'→'.webp') | 8 | −2.8 MB | trivial code change, q85 imperceptible at review-orb size |
| Archetype art ≥1536px → 1024px webp q82 (rendered at ~180px tiles) | 40 | −3.7 MB | pure downscale, imperceptible |
| companions/*.jpg → webp q85 (filenames live in companion data) | 9 | −1.1 MB | mechanical rename sweep |
| splash_logo.png → webp q90 (one path in splash_screen.dart:78) | 1 | −0.9 MB | trivial |
| space_hum.mp3 + ocean_waves.mp3 are 160 kbps stereo ambience loops (2.5 + 2.2 MB) → 96 kbps (or 64k mono) | 2 | −2 to −3.5 MB | owner should listen before shipping |

Applying all of the above lands assets/ around **25–27 MB** (from the original 61 MB).

**UPDATE 2: image conversions EXECUTED same day** (commit 54509881) — all four image rows
applied and verified (visual spot-checks + analyze + widget tests). assets/ is now
**29.7 MB (from 61.1 MB — a 51% reduction)**. Only the ambience-mp3 re-encode remains open,
pending the owner listening to 96 kbps re-encodes of space_hum/ocean_waves (−2 to −3.5 MB
further). Note: `companions/${id}_normal.jpg` dynamic fallbacks in companion_widgets.dart:217
and magic_review_step.dart:252 reference files that have NEVER existed (pre-existing dead
fallback, masked by SafeAssetImage) — candidates for cleanup, not regressions.

## Suggested fix waves (small chunks)

- **Wave 1 (fast, high-stakes):** FREEPIK replacement; delete adult-coded/garbage
  feelings_faces; hyphen-normalization one-liner; gender_adventurer extension one-liner;
  explorer embarrassed.webp.
- **Wave 2 (art regen, worst live grids):** adventurer feelings 3+3; sprout archetypes 4;
  adolescent gender girl silhouette; explorer worried/frustrated; ember companion.
- **Wave 3 (dead-asset purge):** ~17 MB from pubspec + dead widgets (quick_story_screen,
  emotion_recognition_game, ImageContinueButton, ArchetypeCard/WheelSelector, orbs/,
  backgrounds/ decision).
- **Wave 4 (polish):** remaining P1 items 6-12, P2 decisions.
