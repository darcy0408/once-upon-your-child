# Story Weaver Multi-Persona UX & Image Audit

**Date:** 2026-07-18 · **Method:** static code analysis only (no app execution, no prod calls) · **Personas:** one boy + one girl (man/woman for adult) for **each of the six age bands discovered in code** — sprout 2-5, explorer 6-8, adventurer 9-12, creator 13-14, adolescent 15-17, adult 18+ (`lib/theme/age_band_theme.dart:10-38`). The audit prompt assumed four bands; the codebase defines six, so coverage was expanded from 8 to 12 personas rather than dropping bands. Where boy and girl findings were identical, rows are collapsed to "(both)" — the UI creates gender differences only in paired `_boy`/`_girl` art assets (all pairs verified present), the CharacterLibrary 👦/👧 emoji fallback, and the `wizard_data.dart:8` gender default of `'Girl'`.

## Executive Summary

The band system itself is excellent — per-band themes, wizard branches, copy registers, and backend illustration styles are genuinely well matched to each age. The app's biggest problem is structural, not cosmetic: the legacy `StoryScreen` home (`lib/main_story.dart:80`) is dead code that nothing navigates to, which **orphans the entire library layer** — Saved Stories, Offline Stories, Achievements, Multi-Character, Settings, and via Settings the Parent Dashboard, Weekly Recap, Profile Manager, adult Meditation, and post-onboarding legal links. No user of any age can browse their saved stories. Second: onboarding asks name before age, so every teen and adult gets the preschool speech-bubble UI with spoken TTS on first launch. Third: parental-control gates are weak (two-digit addition on the Times-Up screen, back-button bypass) and one purchase path is fully ungated. Fourth: shared chrome (reader, chronicles, achievements, coloring, times-up, paywalls) ignores band theming, undercutting the mature bands the wizard wins over. Roughly 6,000 lines of dead character/avatar screens plus 151 bundled midjourney assets should be deleted. Per-screen details and a prioritized fix list follow.

---

## 1. SplashScreen (`lib/screens/splash_screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | `assets/images/splash_logo.webp` on purple; wordmark means nothing to a pre-reader | None; 4.0s fixed animation, no tap-to-skip (25-53); `SafeAssetImage` has no fallback → blank purple on asset failure | Tap-to-skip after fade-in | 3 | Add a companion character (Sunny/Pebble) to the splash |
| Explorer (both) | Logo only; sparkle-assembly animation would hold a 7yo through the wait | Same unskippable 4s | Same | 2-3 | Tap-to-skip + errorBuilder |
| Adventurer (both) | Fine for 11; subtle starfield would match band | Same | Same | 3 | Tap-to-skip |
| Creator (both) | Purple+gold reads "kids app"; post-splash loading is a gold sparkle (`main_story.dart:196-199`) | Same | Same | 3 | Skippable splash, neutral loading spinner |
| Adolescent (both) | Not band-aware; returning users could get dark `#070B14` variant | Same | Same | 2 | Dark returning-user variant |
| Adult (both) | Brand mark fine; kid-purple backdrop | Same | Shorten to ~1.2s | 2 | 4s dead time is the first impression for a task-oriented adult |

**Cross-Band Issues**
- Unskippable fixed 4.0s hold for every band, every launch (`splash_screen.dart:25-53`).
- No image fallback: a missing/corrupt `splash_logo.webp` renders 4s of blank purple.
- No band awareness anywhere on the launch path even when age is already stored.

## 2. WelcomeScreen (`lib/screens/welcome_screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | **Zero illustrations** — teaser is an `Icons.auto_awesome` glyph (405-472); name bubble deliberately mascot-less (507). Age-gate neutrality (769-797) justifies plainness only on the age step | All live: mic 88px (630), "That's me!" disabled-when-empty (724-726), age circles 88-120px (813-819), under-13 → consent (881-887). Back button ~48px < 88px sprout min (360). Disabled "That's me!" gives no TTS nudge; empty-name error is an unreadable snackbar (287-291) | Teaser could merge into splash | 3-4 | Mascot illustration + spoken prompt on the empty-name state |
| Explorer (both) | Same art void; Biscuit-the-puppy mascot asking the name would beat the bare bubble | Same handlers; no error UI if speech init fails (630-654) | Fine at 3 steps | 3-4 | Character art on teaser/name steps |
| Adventurer (both) | No art; a cosmic hero would counter "baby app" first impression | Handlers solid; 9-11 get the same big-circle age grid as toddlers (799-824, deliberate STORE-5) | **Name asked before age** (`_step` 0→1) so 9-12s get the young-child treatment before the app knows their band | 2-3 | Swap step order: age → name |
| Creator (both) | Gold Cinzel/Fredoka fairy-tale teaser reads little-kids to a 13-14yo | Same order bug: `_buildNameStep` (474-477) sees null age → sprout UI + star burst + TTS "Hi $name!" (297-305); the clean `_buildCreatorNameStep` (569-598) only renders for returning users | Ask age first; suppress auto-TTS until band known | 2 | Age-before-name |
| Adolescent (both) | Same; mature name card uses Creator purple not band teal (571) | Same order bug; 13-17 "Just so you know" dialog (978-1013) is well pitched; consent-write retry solid (1024-1044) | Fold the notice dialog into the age step | 2 | De-whimsy the pre-age teaser |
| Adult (both) | Icon+type only | Same order bug: a 35yo gets the speech bubble, "That's me!", and slow kid TTS (157, 480-567); 18+ path itself clean | One "Who's this for? Me / My child" fork | 2-3 | Age-before-name so adults are never greeted like preschoolers |

**Cross-Band Issues**
- **Name-before-age ordering gives every user ≥9 the sprout-styled name step + unsolicited TTS on first run** — the single worst first impression for 4 of 6 bands (fix: reorder steps, one screen).
- Zero illustration on the app's very first screens for the bands that most need pictures.
- Auto-TTS speaks before band is known (151-157) — embarrassing for teens/adults in public.

## 3. ParentalConsentScreen (`lib/screens/parental_consent_screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout/Explorer/Adventurer (both) | Emoji only; child sees the "Time to get a grown-up! 🌟" hand-off card (693-710) with no art; a "hand the tablet to your grown-up" illustration would explain the sudden stop wordlessly | Exemplary: scroll-gate (208-216), gated checkbox+submit (791-899), email verify/resend/change with loading+errors (1014-1183), share-to-parent (771-785); endpoints verified (`backend/routes/user_routes.py:228,453,608`) | None — legally load-bearing | 2 | Age-tier the hand-off copy ("A parent needs to approve this" for 9-12) + one waiting-child illustration |
| Creator/Adolescent (both) | N/A — never shown; gate is `age < 13` (`welcome_screen.dart:873`); teens self-attest | — | — | n/a | — |
| Adult (both) | None needed on a legal surface | Same solid flow (seen when consenting for kids) | Scroll gate could be per-section checkmarks | 4 | **Parent-facing legal text is set in Fredoka, the toddler font (250-263, 365)** — undermines credibility; and the analytics claim "never enabled for anyone under 18" (574-577) contradicts Parent Controls' 13+ toggle (see §Parent Controls) |

**Cross-Band Issues**
- Analytics-age contradiction between this screen and Parent Controls — compliance review needed.
- Consent promises per-story "view or delete from Parent Controls" (390) that Parent Controls doesn't offer (export-JSON / delete-everything only).

## 4. ChildProfileManagerScreen (`lib/screens/child_profile_manager_screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| All child bands (both) | Emoji avatars (line 21); kid-coded for teens, fine for parents | Effectively unreachable: entries are dead-chain Settings (228) / Parent Dashboard (154); **`pushNamed('/manage-profiles')` at `main_story.dart:1008` targets a route never registered (78-83) → crash if revived**. Save silently no-ops on empty name (222-224); no try/catch on saves | n/a until reachable | 1-2 | Register or remove the route |
| Adult (both) | Reuse each child's generated hero avatar as the profile picture | **`_deleteProfile` → `DELETE /api/user/<id>/data` wipes ALL server data for the shared account, not one profile** (`child_profile_service.dart:115`) — delete-scope hazard, flag for review. Age picker caps at 18 (93-98) | Add per-profile consent-status chips | 3 | Fix delete scope + reachable entry point |

**Cross-Band Issues**
- Unregistered `/manage-profiles` route (latent crash) and account-wide delete behind a "delete this profile" confirm are both flagged for human review.

## 5. WizardStoryScreen — live home (`lib/screens/wizard_story_screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Emoji step icons ⭐🐉🌈✨ (593-601) — good pre-reader design | Leave-dialog is text-only, no TTS (87-111); "Heroes"/"Bedtime" nav tiles ≈40px tall via `_LabeledNavButton` (697-732) vs 88px sprout min; **icon-only Chronicles button (518-538) bypasses the leave-guard** — one stray tap exits a mid-build 4yo | Hide Chronicles for sprout; trim top bar | 4 | Sprout-size or hide non-essential top-bar buttons |
| Explorer (both) | `MoonPhaseProgress` gets emoji icons for sprout but **null for explorer** (593-594) — text-only labels for early readers | `_openLifeQuests` (113-144) has no loading/error state; Parent shield ungated (565-580) | Hide Chronicles inside Heroes | 3-4 | Step icons for explorer + trim top bar |
| Adventurer (both) | Gradient host, fine; step labels "My Character/My Companions…" (603-609) right register | All live incl. draft save/restore (174-246); Chronicles entry has **no age gate** while the dead menu gated 11+ (`main_story.dart:681-686`) — inconsistent | Up to 6 top-bar controls + 4 dots is crowded | 4 | Add a **"My Stories" library entry** — none exists anywhere live |
| Creator (both) | Correct near-black gradient | Mature icon buttons **skip `_confirmLeaveWizard`** (480-485 vs 473-477) — one tap loses a half-built brief; mic icon for "Voice Story Mode" (552-562) reads as speech input | 4-dot stepper overstates a 2-step flow | 4 | Consistent leave-guard for mature icons |
| Adolescent (both) | Same | Same guard skip; same mic ambiguity | Collapse Chronicles/Heroes to one menu | 3 | Leave-guard + rename/re-icon Voice Story Mode |
| Adult (both) | Fine | Close is a **silent no-op at root** (`canPop()` false, 452-456); "Parent" shield shown to the account holder; Chronicles passes `userId:''` (533) | Fold icon row into overflow | 3-4 | Fix root close no-op + add library entry |

**Cross-Band Issues**
- **No library/saved-stories/achievements entry exists on the live home for any band** — the app's #1 structural gap (see §17-§23).
- Leave-guard applied inconsistently: young labeled buttons guarded, mature icons and sprout Chronicles not.
- Draft saves only on step change (348), not on app-lifecycle pause — interrupted sessions lose brief text.

## 6. HeroCreatorStep (`lib/screens/wizard_steps/hero_creator_step.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Gender art `gender_sprout_{boy,girl}.webp` (3257-3259) ✓; all 8 sprout archetype webp ✓ (frame styles mixed per prior cohesion audit); 4 companion webp ✓; **ungendered archetype fallbacks resolve `.jpg` that don't exist** (3221-3246) → emoji if a gendered file ever fails | Superb fail-safes: surprise-name (MT-267, 3328-3372), auto-advance + TTS everywhere, double-advance latch (568-578). **Two stale TTS prompts:** page-2 says "Tap Choose Look" vs on-screen labels (4074 vs 1636/1671); page-6 says "tap Make Magic!" but sprout cards auto-advance with no such button (4079) | Look pages could collapse — archetype art could BE the look | 5 | Fix the two stale sprout TTS prompts |
| Explorer (both) | 8 explorer archetype webp ✓; `ember.webp` still the style-mismatched CGI file from the cohesion audit; gender art ✓ | Welcome-back card save has no loading state / double-tap risk (1202/1115); explorer-only "Tell Me a Story!" express lane (2066) excellent | Merge avatar-source and archetype pages | 4-5 | Replace on-screen word "archetype" (1758) — above reading level |
| Adventurer (both) | 8 archetype webp ✓ but figures read 7-9yo, `master_creator_girl` (sparkly unicorn) skews young; gender `.jpg` ✓; **fallback chain broken** (`age_band_asset_resolver.dart:15-16` builds `.jpg`, only `.webp` exists) | **"How old is your new hero?" dialog labels Adventurer "9-11" and Creator "12-14"** (828-835) vs actual 12=adventurer (`age_band_theme.dart:34-35`) — a 12yo's hero silently becomes Creator; auto-TTS narrates every page at 0.75 with no mute (4096-4113); Fredoka leaks (1182, 3677, 3785) | Merge avatar page into page 1 | 3-4 | Fix band labels in `_promptNewCharacterAge`; TTS opt-in at 9+ |
| Creator (both) | Hosts the brief (see §9); page-0 welcome-back subtitle hardcodes Fredoka "Tap your character…!" (1177-1187) | Continue/new sheet wired (1199-1210); accordion sub-step jumps correct (633-679) | Already the simplification | 4 | Band-gate the page-0 subtitle |
| Adolescent (both) | `gender_adolescent_*.webp` ✓; **`assets/images/hero_placeholder.jpg` referenced at 4043 does not exist on disk** → broken image for restored characters | Archetype gate + scroll-to (1083-1099) solid; vibe-chooser correctly adolescent-only (521) | Correctly bypasses paged flow | 3 | Ship a real hero placeholder asset |
| Adult (both) | `gender_adult_*.webp` ✓; adult archetypes ✓ | Dead code: `_addFriendByName` unreachable (235, 2471); `_customAvatarFilePath` only ever null (2890); kid strings leak into adult Cast section ("one buddy is plenty" 1938-1955, purple Add-Person buttons 2208-2232); page-entry TTS can voice kid prompts (248, 4096-4112) | Prune dead plumbing | 3 | Silence auto-TTS + de-kid the Cast strings for mature |

**Cross-Band Issues**
- `AgeBandAssetResolver.archetypePath` builds `.jpg` while every band ships `.webp` — broken fallback chain for all bands (S fix).
- Auto-TTS has no opt-out for 9-12, and can fire kid prompts for mature bands.
- New-hero age dialog band labels are wrong at the 12 and 14 boundaries.

## 7. HeroCreatorScenePage (`lib/screens/wizard_steps/hero_creator_scene_page.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Shared young tiles + pressed variants ✓ (124-175); **label/audio/art mismatch:** tile reads "Stomp with the Dinosaurs!" (`scenario_data.dart:250`) over dragon art while tap-TTS says "Friendly Dragons!" (4117-4124); commissioned `assets/images/ui/sprout/tiles/` set still unused (cohesion-audit P2 open) | Auto-advance ≤8 ✓; Next arrow is redundant for sprout and allows skipping with no scene selected (335-336) | Hide sprout's Next arrow | 4 | Reconcile dinosaur/dragon label vs TTS vs art |
| Explorer (both) | Same 4 tiles — rainbows/crystals/dragons fit; only 4 worlds, no space/dino/ocean option (interest gap for both genders, skews boy) | Auto-advance ✓; Big Feelings → LifeQuest ✓ | Fine | 4 | Add a 5th world (space or ocean-friends) |
| Adventurer (both) | Own art set, all 5 webp ✓ — volcano dragon/aurora door art is the best in the app | Explicit Next for 9+ deliberate ✓; Next enabled with no selection | Expose the 4 unused `scenes/adventurer/` worlds as tiles | 4-5 | More scenarios (mystery/heist); disable Next until a pick |
| Creator/Adolescent/Adult (both) | N/A — mature bands never mount this page (3945-3975); adult branches inside it are dead code (75, 88, 113-122); adolescent's authored `scenarioPageTitle` strings (`age_band_theme.dart:500-501`) are never read | — | Delete dead mature branches | n/a | Remove unreachable band code |

**Cross-Band Issues**
- Next arrow permits advancing with no scene selected for young bands.
- Dead adult/adolescent code and unused authored strings inside a young-only page invite future confusion.

## 8. HeroStoryTypePage (`lib/screens/wizard_steps/hero_creator_story_type_page.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Emoji-only cards (531-614) — only major sprout choice with no illustration; painted tiles would beat emoji | Auto-advance + latch ✓; 5 stacked cards can push the 5th below the fold with no scroll cue; free-tier "words-only" banner (498-529) is parent text on a child page | 5 choices is the top of a 4yo's budget — consider 3 | 4 | Illustrated mode tiles |
| Explorer (both) | Gradient orbs, no art; `superhero_btn.webp` exists unused | Wish tap-grid, no keyboard (887) — exactly right; daily spotlight orb (660-689) clever | Preselected default = 0-1 taps ✓ | 4-5 | TTS the orb labels for early readers |
| Adventurer (both) | Orbs fine; small per-mode art would help | Best-tuned page: genre chips incl. Mystery/Spooky, personality twists, "Poetry" at ≥11 (646), superhero pitch "real villain, real stakes"; superhero handoff has no spinner (733) | Collapse personality into genre row | 5 | Age the wish hint ("find the hidden vault") |
| Creator/Adolescent/Adult (both) | N/A — mature bands use the brief (3995); `case AgeBand.adult` (220) is dead | — | — | n/a | Prune dead adult case |

**Cross-Band Issues**
- Free-tier "words-only" signpost lives only here, so mature bands never see it before generating (see §10 MagicReview).

## 9. HeroCreatorCreativeBrief — mature Step 1 (`lib/screens/wizard_steps/hero_creator_creative_brief.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Creator (both) | Gender silhouettes (257-263) ✓ — the best teen-coded art in the app; 8 archetype webp ✓ but figures read 10-11yo vs their "Logic Architect" labels; **only 4-5 of ~13 worlds have creator art** (`assets/images/scenarios/creator/`) vs adolescent/adult's full sets — most tiles are gradient+emoji fallbacks under strong titles; companion `cipher.webp` is kawaii (flowers/sparkles) against the band's zero-sparkle contract | "Start a Hero Saga" pins `heroMode='antihero'` for creator (983-1016) — inert server-side but misleading stored data; slider label casing inconsistent (533-560); all CTAs traced live with distress scan (1122-1136) | Collapse Personality sliders to an "advanced" link | 4 | **Ship the 8 missing creator scenario images**; age-up archetype portraits |
| Adolescent (both) | All 12 art-backed adolescent world tiles ✓ + `imagine_it.webp` ✓ — best-fitted art set; **`questionFor` returns null for adolescent** (663-667) — creator/adult tiles carry psychological hooks, hers are bare titles; latent `.jpg` fallback bug (dormant — gender always set) | **Comment/code mismatch:** lines 321-324 claim the archetype grid is hidden for adolescent but only the desire field is gated (350) — grid renders and is required `*`, redundant with Identity+Edge; genre chips lack Thriller/Crime, include "👻 Spooky" | Hide the required archetype grid for adolescent (or fix comment + drop `*`); gender defaults `'Girl'` (`wizard_data.dart:8`) — a boy always makes a corrective tap (the app's one real gender asymmetry); start unselected for mature | 4 | Resolve the archetype-grid gate; surface thematic hooks |
| Adult (both) | **3 adult tiles claim art that doesn't exist** — `artBackedIds` lists `vanishing_colors`, `volcano_dragons`, `survival_island` (677-696) but `assets/images/scenarios/adult/` ships none of them → error-fallback rendering; brief's gender picker has no "Man/Woman" label override (288-310; labels exist only in the non-mature picker `hero_creator_step.dart:3284/3294`) | Personality slider keys (`expressiveness/...`, 534-565) disjoint from reset defaults (`energy/...`, `hero_creator_step.dart:812-819`) — verify what the backend reads; "Start a Hero Saga" forces antihero while promising "design your own hero" | Personality optional | 4 | Ship or de-claim the 3 missing adult world images |

**Cross-Band Issues**
- Missing/inconsistent scenario art claims across all three mature bands (creator worst).
- `heroMode='antihero'` silently forced by the saga CTA for non-adolescent mature bands — mislabeled feature.
- Disjoint personality-slider key sets feeding one map.

## 10. MagicReviewStep (`lib/screens/wizard_steps/magic_review_step.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Hero avatar + floating companion ✓; style token `'whimsical'` (471) → backend | Giant pulsing GO! (1461-1508) — but **silently disabled if a dot-jump skipped the archetype** (1467-1469 vs `wizard_data.dart:216-225`) with no TTS explanation; tappable recap rows cued only by a 14px refresh icon (1582) | Already minimal | 5 | Never render GO disabled for sprout — auto-fill the gap like MT-267 did names |
| Explorer (both) | **Review orb scene art mismatches the tapped tile** — `illustrationForAge` maps crystal_cavern→`ocean_depths.webp`, volcano_dragons→`enchanted_forest.webp`, vanishing_colors→`cloud_castle.webp` (`scenario_data.dart:357,276,439`) — same class of bug MT-311 fixed for sprout | Chips jump back ✓; countdown + cancel + retry robust (299-335) | Hide length chips for this band | 5 | Show the exact scene art the child tapped |
| Adventurer (both) | "MISSION BRIEFING" RPG sheet — best review in the app; but `deep_archive.webp` backs two scenarios and `ruined_citadel.webp` two more (`scenario_data.dart:232,316,358,440`) — different quests, same picture | MISSION READY gating + honest progress + cancel ✓; audio-only launch button exists only in the standard layout (2691), not the briefing | None | 5 | De-duplicate scene art; audio-only parity |
| Creator (both) | Pitch-doc layout ✓ | **Pitch card prints raw `selectedArchetypeId`** — "The Quiz Whiz" leaks onto a 14yo's pitch (2111-2116); redundant Nunito "Change companions" button (163-186); **`MagicalLoadingView` invites teens to "Catch the sparkles! ✨" while `particleCount` is 0 for the band** (`magical_loading_view.dart:886-913`; `:461-462`) — a sparkle game with no sparkles | Drop the duplicate button | 4 (pitch) / 1 (loading) | Map archetype through `nameForAge()`; band-gate the loading view |
| Adolescent (both) | Minimal review renders **zero images** — her chosen scene art never shown (1807-1938); no "Previously/Issue #N" card though `priorSaga` is computed and sent (568-597, 671) | "Start Writing" gating + retry ✓; **error copy "Uh oh! Something went wiggly." (968) and ✨ 429 message (979-981) render to 16yos** | Fine | 3 | Mature error copy + scene-art header + saga recap |
| Adult (both) | None by design | Edit affordance is `Icons.refresh` (1801, 2464) — reads "reload"; **free-tier silent illustration downgrade with no upfront notice on the mature path** (389-390, 555-557); consent-error copy says "Ask a parent" (971); dead `_PulsingCastSpellFrame` animation (3095-3101) | Length not editable here | 4 | Surface the illustration tier before spending quota |

**Cross-Band Issues**
- Free-tier users on the mature path get a silent no-art downgrade — the only signpost lives on a young-band page.
- Generation UX (progress, cancel, retry, double-launch guards) is uniformly excellent — the model for the rest of the app.
- MagicalLoadingView interior is not band-gated (kid register + broken sparkle game for mature bands).

## 11. ImagineItScreen (`lib/screens/wizard_steps/imagine_it_screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Emoji idea chips (426-627); 96px mic anchor ✓ | "Be a superhero" chip duplicates the story-type card — two entrances to one flow | Drop the duplicate chip | 4 | TTS read-back of the captured idea (pre-readers can't verify text) |
| Explorer (both) | **Sprout gets 8 tappable idea tiles; explorer gets a blank text box** (242-247) — heaviest literacy demand in the wizard for a 7yo | Mic gated on availability ✓; distress check ✓ | Extend idea tiles to explorer | 3 | Idea chips for explorer so no keyboard is required |
| Adventurer (both) | None needed | All wired; safety line (313-328) reads respectful | Duplicate Done/"Use this idea" commits | 3-4 | Rotate 9-12-pitched example prompts ("midnight museum theft") |
| Creator/Adolescent/Adult (both) | N/A — mature bands use the brief's inline field (only pushed from the young scene page, `hero_creator_scene_page.dart:350`) | — | Mature inline field lacks this screen's mic — consider adding voice input to the brief | n/a | — |

**Cross-Band Issues**
- Explorer is the only young band without idea starters.

## 12. Superhero flow (`superhero_entry / vibe_chooser / power / costume / reveal / welcome_back _screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Sprout never gets the portrait reveal (gated on photo avatar, `power:477-490`) — the flow's "wow" image withheld from the band that would gasp loudest | **Zero TTS in the entire flow** (grep: no `AppTtsService` in any superhero file) — every instruction is text a pre-reader can't read; mechanics (auto-advance, 🎲 surprise) otherwise ideal; no sprout re-entry shortcut exists anywhere live | Make "Surprise me!" the default sprout path | 3 | Wire TTS prompts into costume/power for ≤5 |
| Explorer (both) | Powers/capes/emblems are emoji tiles — the flow's biggest art gap; no cumulative costume preview | Dismissing the required name sheet silently aborts confirm with zero feedback (`power:423`); decodable catchphrase pool (900-901) is a lovely touch; "ISSUE #1" jargon unreadable at 7 (`reveal:287`); welcome-back noir headers ("PREVIOUSLY IN YOUR SAGA", "The cost:") rendered verbatim to 7yos (350, 296, 362) | Merge cape+emblem pages | 4-5 | Live costume-preview mannequin; band-adapt recap copy |
| Adventurer (both) | Reveal = own AI portrait as comic cover — the app's delight peak; welcome-back portrait fallback ✓ | Nemesis roster mixes great villains with "Booger Baron / Professor Picklejuice" potty tier (`power:1229-1290`) — embarrassing at 11; skip aborts HTTP ✓ | Keep length — every step is a wanted choice | 5 | Stamp the saved portrait on welcome-back + saga headers; tier the nemesis list |
| Creator (both) | No raster art; costume swatches fine | **Costume screen's noir-font flag tests `band == adolescent` at every call site** (`costume:373-976`) → creator gets Fredoka while power/reveal/welcome-back correctly use `adolescent || creator`; rainbow-cape hide is adolescent-only (585-590) contradicting the same file's MT-298 emblem logic; entry loading text Fredoka (entry:115) | Fine | 4 | Change costume-screen font checks to the shared noir predicate |
| Adolescent (both) | Vibe-chooser cards are emoji (112-126) — the band's signature decision deserves two-tone art; **backend `build_superhero_transform_prompt` hardcodes "Pixar-style… child" with no band parameter** (`backend/services/image_prompt_helpers.py:100-109`) — flagged for review (trigger path unconfirmed) | Edge roster with costs ("Ghost — the better you hide, the more alone you are") is the best-written surface in the app for the band; sensitivity interstitial + crisis panel wired (`costume:311-340, 189`) | Two cards is right | 5 | Show the Edge's "cost" line in the review; band-parameterize the transform prompt |
| Adult (both) | Runs on Creator visuals (`entry:49-50`), abandoning the amber theme; "Rainbow cape 🌈" at 18+ | **Welcome-back "Open the next issue" overwrites any typed premise with 'being a superhero'** (`welcome_back:96`) while first-run preserves it (`power:443-449`) | Collapse the 3 costume pages | 3 | Stop clobbering `customElements` on saga re-entry |

**Cross-Band Issues**
- The saga "Previously… / Issue #N" recap is the app's best retention hook — reuse the pattern in MagicReview (adolescent asks for exactly this).
- Costume-screen band styling is half-migrated (adolescent-only checks).
- No TTS for pre-readers anywhere in the flow.

## 13. BedtimeWizardScreen (`lib/screens/bedtime_wizard_screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Voice-first, minimal visuals — right call; option chips would be more usable as pictures | Shortest flow (companion→place→story, 378-405); fuzzy voice matching with safe defaults (669-728); duration deliberately unsent ✓ | Leanest flow in the app | 5 | Picture option chips; soft lullaby bed under generation |
| Explorer (both) | Deliberately art-free ✓ | Chip fallback when mic fails (99-104); dispose cancels generation (283-286); "issue {n} of your saga" spoken to a 7yo (338) | ~7 questions is long at bedtime — merge feeling+setting | 4 | Shorten the question chain |
| Adventurer (both) | None; dim scene art behind the conversation would elevate | Band rosters (Thunder Wolf…, Ruined Citadel…) verified (614-651) | "Same as last time" repeat path | 4 | One-tap repeat-last-recipe |
| Creator/Adolescent (both) | None (orb) | Fully mature-forked prompts (138-141, 204-508); relabeled "Voice Story Settings" ✓ | Fine | 3-4 | Discoverability — the mic icon hides the feature |
| Adult (both) | None | Generic failure speaks "Let's try again tomorrow. Goodnight!" then pops (911-914) — dead end at 10pm; `_parseAge` caps at 18 (846-876); launch sheet stays purple/gold for mature (`bedtime_launch_sheet.dart:49-138`) | Fine | 4 | Retry affordance on failure; band-theme the sheet |

**Cross-Band Issues**
- Entry point (mic icon labeled ambiguously) undersells the app's most novel mode for every band ≥13.

## 14. StoryResultScreen (`lib/story_result_screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Backend sprout prompt ("warm rounded 3D storybook", `image_prompt_helpers.py:230-242`) ✓; **free tier = wall of unreadable words** — no per-page art for the picture-book band (`canGetIllustrations`, `magic_review_step.dart:389-390`), saved only by auto-TTS; end-page fallback is glyph sparkles | Auto-save ✓, 2-button controls + parent unlock ✓, upsells suppressed ✓; end CTA tiles ~70px < 88px min (3902-3963); "Chronicles" tile (3866-3886) opens ungated while old menu gated 11+ | One giant "Again!" would do | 4-5 | Guarantee fallback art per page for free-tier sprout (pricing review) |
| Explorer (both) | Style prompt ✓ (243-252); grey "Image unavailable" (1454-1475) reads "I broke it"; locked-preview tile is gradient+lock — show a blurred sample | **Stale BYOK upsell: "free with your own key" (5056)** — BYOK sunset (MT-358), false promise; `_saveStory` no in-flight disable (2115-2189); raw `$e` in save errors (2181) | Young action bar already tight ✓ | 4-5 | Fix BYOK string; in-world loading/error states |
| Adventurer (both) | Adventurer prompt "not babyish, not kawaii" ✓ (253-263); **safety-blocklist fallback swaps in "cheerful young hero in a sunny meadow"** (`replicate_image_generator.py:75-99`) — babyish art inside a middle-grade story; **failed/quota art renders literally nothing** — `PerPageIllustration` failed → `SizedBox.shrink()`, upsell suppressed for the band (`per_page_illustration.dart:38-92`) | **Dead footer arrows in the ≥11 reader** — prev/next (4788-4818) mutate an index the ListView ignores, so `isOnEndPage` (4872) rarely fires, hiding the Color chip (5180-5186) and rating row (5072-5101); remix worlds never map to the band's scene set (2221-2237); no read-aloud control for 9-12 (TTS gated ≤ explorer, 717) | End CTAs duplicate the bottom bar | 3 | Make the ≥11 reader track scroll (restores footer/rating/Color in one fix) |
| Creator (both) | Creator YA-novel prompt ✓ (264-273); **end page hardcodes cream parchment + gold filigree + ✨** (3330-3360) inside her dark reader | "Save" leads nowhere (library unreachable); two rating systems on one page (emoji quick-rate + stars); '✍️' emoji CTA icon (5108) | Collapse to Save + overflow | 4 | Dark end/cover pages; give Save a destination |
| Adolescent (both) | Graphic-novel prompt ✓ (274-283) — best image slot in the app; grey failure box on near-black page; cream cover/end pages (3243-3244, 3331-3332) | **`_FlipSparkles` gold burst fires on every page flip gated only on reduce-motion, never `band.showParticles`** (4668-4679); 48px ✨ on "The End" for all non-sprout (3348-3351); **TTS/read-aloud entirely unmounted for her band** (717) despite a band voice existing; 5-star not emoji ✓; antihero distress panel correctly scoped ✓ (3800-3819) | Fold the 2-toggle reading-options sheet into the app bar | 2 | Gate sparkles on `showParticles`; dark cover/end; enable mature TTS |
| Adult (both) | AI badges everywhere ✓ — honest labeling | **`_effectiveAge` defaults to 7 on null age** (340-346) → adults can get the kid flip-book with sparkles; report flow exemplary (parent gate → `/report-story` → mailto, 1879-1968); kid strings leak ("a grown-up will review this" 1921, "safely tucked away" 2202); Chronicles CTA passes `userId:''` (3881) | ~8 end-page chips — collapse | 3 | Fix the `_effectiveAge` fallback; delete the BYOK line |

**Cross-Band Issues**
- Stale BYOK upsell string (5056) — a false purchase promise shown to every free user (trust-damaging; S fix).
- Cover/end pages ignore `preferDarkMode`; flip sparkles ignore `showParticles`.
- Illustration failure states: invisible (adventurer), scary-grey (young), light-on-dark (mature) — one band-aware placeholder fixes all.
- Read-aloud gated to ≤8 even though the TTS pipeline supports every band.

## 15. StoryReaderScreen (`lib/story_reader_screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Renders persisted art; free-tier gap as above | Auto-play + 2-button controls + 2s long-press parent unlock (1264-1307) — excellent | Good | 5 | None |
| Explorer (both) | Text focus ✓ | Auto-play ✓ but explorer gets the **full adult control row** instead of simplified controls (1036-1037); word-highlight karaoke (299-377) is gold | Simplified explorer controls | 4 | Surface Easy-Reader phrase toggle here |
| Adventurer (both) | Band theme ignored (parchment/purple 917-919) | **Resume restarts narration from zero** — fallback `_resumeReading` calls `speak(widget.storyText)` (848); speed chips ✓ | Drop "A story for X" star chrome | 3 | Fix resume; dark cosmic reading theme |
| Creator (both) | **Zero band theming** — purple gradient + parchment + gold for every band (917-1027) | Autoplay correctly off ✓; robust TTS fallbacks (598-714) | Merge into result screen as an audio drawer | 1 | Band-theme this screen (largest single theme violation) |
| Adolescent (both) | Same skin problem | Behavior band-correct (no autoplay, rate 1.0, typed failures never fall back robotic) | Controls right | 2 | Dark surface + teal accents |
| Adult (both) | Same | **TTS consent/quota failures silent** (563-566, 687-692); mid-story synthesis failure ends playback quietly (647-653) | Fine | 3 | Toast on quota fallback ("using device voice"); never fail audio silently |

**Cross-Band Issues**
- Hardcoded kid chrome for all bands; silent TTS degradation; resume bug.

## 16. PickAPathAdventureScreen (`lib/pick_a_path_adventure_screen.dart`)

| Persona | Image Findings | Button Findings | Simplification | Delight | Top Improvement |
|---|---|---|---|---|---|
| Sprout (both) | Choices are text+emoji; spoken choices mitigate | Segments auto-advance after TTS (148-190); big buttons ✓; inventory hidden ✓ | Good | 4 | Picture-coded choice buttons |
| Explorer (both) | Segment art with in-world fallbacks ✓ | **Young-choices UI gates at `age <= 7` (1252-1254)** — an 8yo explorer falls into the adult-shaped UI, splitting the band; raw errors "Error: $e" shown to children (290, 475) | Align gate to ≤8 | 5 | Fix the age-7/8 band seam + de-jargon errors |
| Adventurer (both) | ✨ placeholder OK; 📖 emoji failure fallback cheap; completion moment has no art (1711-1714) | **Save persists only the final segment as the whole story** (779-780) — the built adventure is lost; auto-narration fires per segment at 11 (159-166) with one-shot stop; session cap 8 segments ≤10 vs 15 at 11+ (209-213) | Rename "My Backpack" → "Gear" | 4 | Save the full transcript |
| Creator (both) | Pending ✨ placeholder for a band with sparkle 0 | Mature labels ✓; guards ✓; **in-progress saves exist but no resume UI (TODO 737-740)** — a 12-segment story is unrecoverable | None | 4-5 | Build the resume picker |
| Adolescent (both) | Band-tinted fallback ✓ | deepPurple "✨ Do something else…" affordance (1575-1650) off-band; amber completion icon (1711); "What do you do next?" 2nd-person chrome over 3rd-person narration (1541) | None | 3-4 | Teal-ify the free-text affordance |
| Adult (both) | Persistent cover beats per-segment ✨ | **Auto-TTS narrates every segment for adults** (142-166) — contradicts the app's own no-unexpected-audio rule; save failure shows raw `$e` (811-817) | Merge Items/Thread expanders | 4 | Resume UI + stop mature auto-narration |

**Cross-Band Issues**
- Full-transcript save + resume UI are the two highest-value fixes for the app's best-loved mode.
- Crisis handling (client + backend) verified solid on every band's path (489-495, 557-565).

## 17. StorybookPage widget (`lib/widgets/storybook_page.dart`)

All bands: decorative parchment/gold CustomPaint, non-interactive, genuinely book-like for ≤12. `darkPage` plumbing exists (57, 291-326) but cover/end callers never pass it for `preferDarkMode` bands, and there's no accent parameter. **Top improvement:** honor `darkPage` + accept a band accent (S). Delight: 4 young / 3 mature.

## 18. SavedStoriesScreen (`lib/saved_stories_screen.dart`) — UNREACHABLE

Only constructors live in dead `StoryScreen` (`main_story.dart:349, 672`). Every band loses its library; the screen even has finished band adaptations (sprout "My Story Shelf" 62-220, mature compact toggle 63-65 — which excludes adolescent, a one-line fix). Findings if revived: **no cover thumbnails** despite covers persisted (264, `story_card.dart:31-80`); **delete/swipe-delete with no confirm or undo from any of three entry points** (299-307, 638-646, 701-707); kid theme chips ("Unicorns") shown to all bands (31-44); PDF export lacks a spinner (514-551). **Top improvement: re-wire a "My Stories" entry into the live home (all 12 personas' #1 or #2 finding), add delete confirm, render cover thumbnails.**

## 19. OfflineStoriesScreen (`lib/offline_stories_screen.dart`) — UNREACHABLE + HOLLOW

Dead entry (`main_story.dart:664`); additionally `OfflineStoryCache.cacheStory()` is called only from tests, so the screen would be permanently empty. Unthemed deepPurple. Its delete-confirm pattern (287-304) is the one SavedStories should copy. **Top improvement:** fold "offline" into the restored library as a badge/filter; don't revive standalone.

## 20. ChroniclesListScreen (`lib/screens/chronicles_list_screen.dart`)

| Persona | Key findings |
|---|---|
| Sprout (both) | De-facto library ("Our Stories 📚", 36) — but **saved-story tiles have no `onTap` (184-198): dead rows**; creation dialog demands typed title + genre dropdown — impossible at 4 |
| Explorer (both) | Band seam: ≤7 "My Adventure Books" vs 8 "My Chronicles" (34-54); typed-title dialog heavy at 6-7; empty-title Create silently no-ops (328-332); Isar errors swallowed (77-79) |
| Adventurer (both) | Inconsistent age gate — dead menu blocked <11 (`main_story.dart:681-686`), live wizard/story-end entries don't; `Icons.menu_book` for every chronicle — no covers |
| Creator/Adolescent (both) | Hardcoded deepPurple AppBar + magical gradient (130-135) in dark-band apps; "Start Chapter 2! ✨" chip (239) sparkles at all ages |
| Adult (both) | Same theming; no loading state on create |

Delight 2-3 across bands. **Cross-band:** wire sprout `onTap` (P0); pick one age-gate policy; band-theme; auto-suggest titles; cover art.

## 21. ChronicleScreen (`lib/screens/chronicle_screen.dart`)

All bands: **`tone: 'whimsical'` + `length: 'medium'` hardcoded for every chapter continuation** (88-89) — a Mystery chronicle or an adult's literary saga is forced whimsical (S fix: pass band tone). Sprout gets an emoji trail ✓; explorer's 8yos fall into the mature ExpansionTile via raw `age <= 7` checks (183-188); purple chrome for dark bands (114); "Growth: …" moral line is eye-roll fuel at 11 (405-413); no chapter thumbnails anywhere. Delight 3.

## 22. SagaRecordScreen (`lib/screens/saga_record_screen.dart`)

Correctly band-themed via `themeForBand` (33-57); read-only; nothing broken. Adolescent 5/5 — reference-quality register. Adventurer/explorer reach it with unchanged noir vocabulary ("THE LEDGER", "WHO KNOWS") — wrong register at 6-12 (explorer 1/5); the hero portrait is never stamped on the dossier. **Top improvement:** band-adapt or band-gate the copy; add the portrait.

## 23. StoryNotesScreen (`lib/screens/story_notes_screen.dart`)

Well built for every band: band-toned disclosure, quiet trigger, parent preview mirrors it. Adult 5/5 ("exactly the honesty a skeptical parent wants"). Minor: 💛 trigger emoji reads young at 9+ (199); no TTS for sprout; hide the caregiver co-read line for mature (108-129). Delight 3-5.

## 24. AchievementsScreen (`lib/achievements_screen.dart`) — UNREACHABLE

Dead entries only (`main_story.dart:442-451, 660, 1572`). The personas who most crave collections (explorer/adventurer) can't reach it; if revived: zero band theming (light Material inside a dark app, 98-116); badges are tinted Material icons, no art; names like "Unicorn Dreamer" shown verbatim to teens (`achievement.dart:359`); `_loadAchievements` marks all badges viewed on entry (62-64) so "NEW" survives one visit and there's no unlock moment. Delight 1-2 shipped, 5 potential. **Top improvement:** reachability → illustrated badges → band-keyed copy.

## 25. WeeklyRecapScreen (`lib/screens/weekly_recap_screen.dart`)

Parent-facing; currently unreachable (only `settings_screen.dart:209`, dead chain). Export button is the app's best (disabled + "Building PDF…" + paywall + error, 58-93); on-device privacy note accurate (236-239). Issues: file header claims a parent gate that doesn't exist for mature "account-holder" minors (see §31); copy references the dead Feelings Garden (153); data not per-profile. Delight 4 (parent). **Top improvement:** reachability + per-profile scoping + settle the mature-minor gate.

## 26. Dead character/avatar island — DELETE CANDIDATES

`character_creation_screen.dart`, `character_creation_screen_enhanced.dart`, `character_edit_screen_enhanced.dart`, `avatar_builder_screen.dart`, `screens/avatar_picker_screen.dart`, `screens/midjourney_avatar_picker_screen.dart`: **all dead** (zero live constructors; the enhanced screen is the sole parent of the three pickers, itself orphaned — verified independently by 10 personas' greps). Consequences: ~6,000 lines of maintenance surface, a second `/create-character` implementation, latent bugs (avatar_builder false "saved!" on empty name, 226-235), and **151 midjourney webp files bundled into every build for zero reachable value** (`assets/avatars/midjourney/` stays referenced by `avatar_service.dart:76,158` — verify before deleting assets). **Top improvement:** delete the island per the unfinished-features-audit ethos.

## 27. CharacterLibraryScreen (`lib/screens/character_library_screen.dart`)

Live via wizard "Heroes". All bands: avatar fallback chain ends in giant 👦/👧 emoji (188-199, 698-708) — the one UI spot that differs by gender, babyish for both; `Image.network` branch has **no errorBuilder** (668-679); external avataaars fallback URL (687-692) is off-brand + third-party fetch; **Chronicle button silently no-ops when userId null** (613-637); role-emoji matcher expects legacy roles the wizard never writes (vs `hero_creator_step.dart:1024`) so the fallback always fires; **empty-state/FAB push a NEW WizardStoryScreen on top of the wizard** (292-300, 346-354) — stackable wizard→Heroes→wizard loop; magical purple hardcoded for mature (211-212). Delight 2-3. **Top improvement:** archetype-art fallbacks, errorBuilder, fix the nested-wizard loop.

## 28. CharacterEditorScreen (`lib/screens/character_editor_screen.dart`)

Live via library (177). **Role dropdown offers only legacy roles while live characters carry archetype names → `initialValue` not in items (385-399): debug assert / undefined release behavior, and saving rewrites the archetype (65).** Age dropdown caps at 17 (314-321) — adult characters unrepresentable, silently re-banded; gender dropdown includes 'Other' (347) — inconsistent with the app-wide Boy/Girl decision (reported as an inconsistency to reconcile either direction, per owner policy). No avatar preview at all. Save states ✓. Delight 2. **Top improvement:** source roles from `CharacterArchetypes`; extend ages; show the portrait.

## 29. CustomAvatarScreen (`lib/custom_avatar_screen.dart`)

The live selfie→avatar flow; best COPPA gating in the app (photo opt-in triple-checked: 273-277, 411-414, 453, 488-490; sprout consent skip ✓; 3-min bound on the old 504 hang, 554; 401 retry; upgrade dialog). Bugs: **`_genderAsset` requests `gender_adventurer_{boy,girl}.webp` but disk has `.jpg`** (1206 vs `hero_creator_step.dart:3264`) → 9-12s of both genders see blank gender cards (one-line fix, confirmed by 2 personas); consent backstop silently no-ops for adults (490); Cancel doesn't abort the in-flight request (1671); sparkle strings gate only on `_isSprout` — "Generate Magic Avatar ✨"/"Your Magical Avatar ✨" in CinzelDecorative shown to teens/adults (1626, 1844-1851). Delight 4-5. **Top improvement:** the `.webp`/`.jpg` fix + de-sparkle mature strings.

## 30. MultiCharacterScreen (`lib/multi_character_screen.dart`) — UNREACHABLE + LIKELY BROKEN

Only entry is the dead menu (`main_story.dart:697`), yet the paywall sells "Multi-Character Stories" (`premium_upgrade_screen.dart:399-402`). One persona's backend grep found **no route for `/generate-multi-character-story`** (only a comment in `subscription_routes.py:9`) — the CTA would always fail as "Network error" (verify before shipping either way). Text-only cards, parent-voiced "Pick at least one child" copy, response-shape mismatch (`items` vs `characters`, 36). **Top improvement:** finish-or-remove; hide the paywall claim until real.

## 31. Activities: FeelingsGarden / LifeQuest / Coloring / AdultMeditation / TimesUp

**FeelingsGardenScreen** (`lib/screens/feelings_garden_screen.dart`) — dead code (no constructor call sites; Feelings tab routes to LifeQuest). Knock-ons: `feelings_journal` (Parent Dashboard's feelings source) is written only here → dashboard feelings permanently empty; the per-band feelings art sets (21-31 files per band) are largely orphaned; the shared `FeelingsCloudPicker` (live via `FeelingsQuestModal`, `hero_creator_step.dart:442`) has a **verified id-mismatch bug: hyphenated ids (`hurt-mad`, `what-if-y`…) never match underscore filenames** because neither `AgeBandAssetResolver.feelingPath` (`age_band_asset_resolver.dart:28`) nor the caller (`feelings_cloud_picker.dart:706-710`) normalizes — six purpose-made explorer images orphaned, fallback hits the cohesion-audit's flagged `feelings_faces/` files (near-blank `embarrassed.webp` still live). Adventurer `happy.webp` has baked text + fake-transparency checkerboard vs the excellent `surprised.webp` — regenerate the badge-style files if the surface is revived.

**LifeQuestScreen** (`lib/screens/life_quest_screen.dart`) — live and good. Sprout: animal-friend grid + auto-TTS + crisis panel = the app's best young activity (5/5). Explorer: subtitle falsely says quests are "on their way" above 15 real quests (295-296, one-line fix); TTS off by default with dense Merriweather prose (110, 893); no completion reward. Adventurer/creator/adolescent: emoji-only cards where band feeling art exists; teen register ("Reset kit", invitation-not-cheer) verified right; amber "grown-up check first" chip can feel surveilled at 16 — pair with a rationale. Adult: **zero adult quests → routed adults hit an empty "More quests coming soon!" dead end (434-473) while the purpose-built AdultMeditationScreen sits unreachable** — repoint mature/adult entries.

**ColoringBookLibraryScreen / ColoringScreen** — live via story-result "Color" (1596-1634), zero band adaptation, and stub-riddled: **web Download "coming soon" (121-128), Print instructions-only (190-226), coloring-screen Print/Export dead-ends after rendering a PNG (123-153), Share copies a data-URL (228-240), Save writes unrestorable point-counts and never loads back (60-84)** — a false "✅ Coloring saved!". Library never passes `childAge` → everyone colors as an 8yo (346-352 → `coloring_screen.dart:15`); child-reachable delete with text-only confirm (43-76); brush-only, no flood-fill or undo — exceeds age-6-7 motor precision. Delight 1-3. **Top:** hide stubs, pass age, parent-gate delete/share for sprout, add flood-fill+undo, gate the chip off mature bands.

**AdultMeditationScreen** — well-built (amber orb, grounding stepper, honest dismissal; 4/5) but **unreachable** (only dead `main_story.dart:309`) and its journal is unencrypted SharedPreferences with no view-all/delete-entry UI (128, 158-161, 246) — privacy gap for an adult journal on a family device; heavy prompts lack a crisis footer (unlike child surfaces). Single-point band gate with no in-screen re-check. Adolescent persona notes the breathing/grounding tools locked to 18+ are arguably what a 16yo's "Inner Map" needs most — product question, flagged.

**TimesUpScreen** — reaches every band (`main.dart:164-191`) with Fredoka + "Great job playing!" (74-75). **The "parent" gate is two-digit addition (34-39), repeatable, granting +15min (48)** — self-solvable from ~age 8, decorative at 11-17 (the bands most motivated to bypass); **no `PopScope` — system back may dismiss the lockout entirely**; no double-grant disable during the success delay (48-53); no TTS or friendly art for a pre-reader who experiences an unexplained full-screen stop. Delight 1-3. **Top:** shared multiplication/PIN gate + PopScope + band-toned copy + sprout TTS/illustration.

## 32. Settings & commerce

**SettingsScreen** (`lib/settings_screen.dart`) — **unreachable** (dead chain), stranding Weekly Recap, Profile Manager, Parent Dashboard, and the only post-onboarding ToS/Privacy links. If restored: **Dark Mode toggle is a no-op** — writes a provider no one consumes; `MaterialApp` passes `AppTheme.light` as both themes (`main_story.dart:69-84`); child gate is simple addition (39-41) vs multiplication elsewhere; **no Parent Controls entry at all** though the privacy policy documents "menu → Parent Controls" (`privacy_policy_screen.dart:132`); ElevenLabs logo fetched from a remote CDN (458-465, CSP risk).

**ParentControlsScreen** — live (wizard shield, welcome). Mostly excellent, four real issues: (1) reachable only from Welcome + a wizard icon, never Settings — parents following the policy's documented path get lost; (2) **deselecting the last Big Feelings trigger is never saved — `_saveToApi` early-returns on empty (321-323), so the backend keeps guiding stories after a parent turns them off** (parental-control integrity bug); (3) autosave failures swallowed (`catch (_) {}`, 341); (4) analytics toggle at 13+ (254, 634-649) vs consent's "never under 18" — compliance review. "Delete All My Data" copy says "your child's data" but wipes the whole multi-profile account (809-866); raw `$error` in snackbars (861, 930); math gate is single-digit multiplication — trivial at 11+; **the wizard shield entry is itself ungated** — a 7yo can reach screen-time settings and Delete All Data behind only a text confirm (flagged for human review).

**ParentDashboardScreen** — unreachable; and **reads the wrong store**: "Recent Stories" uses legacy `saved_stories_v2` SharedPreferences whose only writer is pick-a-path (55; writer `pick_a_path_adventure_screen.dart:71`) while wizard stories save to Isar → **false "No stories in the last 30 days" for active families**; feelings from the dead-garden journal, not per-profile (63); empty state points at the unreachable Feelings Garden (360); story rows not tappable.

**SubscriptionScreen** — self-described "Example screen" (7) live in four routes; white/green Material off-brand; checkout traced end-to-end to `stripe_routes.py:76` ✓; "Up to 10 stories every day" vs monthly framing elsewhere. **PremiumUpgradeScreen** — **`showCharacterLimitDialog` pushes it with NO parental gate (`paywall_dialog.dart:319-327`)** — a child lands on live purchase buttons (P0 safety flag); "Therapeutic Superhero Missions"/"expanded therapeutic prompts" (388-397) **directly contradict the consent screen's "not therapy" box, the ToS disclaimer, and the privacy policy** — the exact claims a skeptical parent screenshots; "Ad-Free" implies ads exist (408-412); CTA hidden until a card is tapped with only one tier to pick (154). **SubscriptionManagementScreen** — solid (cancel/portal/restore verified against `stripe_routes.py:76-227`) but **"Upgrade to Family" (447-460) leads to a paywall with nothing to buy** (Family delisted, `subscription_models.dart:393-403`); raw `error.toString()` (552-556); **reachable ungated by 13-17 "account holders" via Settings/ParentControls — a 14yo can cancel the family plan or open the Stripe portal behind no gate while purchases ARE gated** (inconsistent; human review). **SubscriptionSuccessScreen** — clean; unhandled sync future (19). **ToS** — stale: Family tier + "unlimited stories" + "cancel from Settings" (39-44). **PrivacyPolicy** — best-in-class vendor list; two drifts: "ages 3-17" omits the shipped 18+ band (73); documented deletion path doesn't exist (132).

**Cross-Band Issues (commerce)**
- One ungated purchase path + inconsistent mature-minor gating (cancel ungated, buy gated) + weak arithmetic gates = the parental-control story needs one deliberate pass.
- Marketing/legal copy contradictions ("therapeutic", "Ad-Free", Family tier, BYOK) are trust leaks for exactly the paying audience.

## 33. StoryScreen legacy home (`lib/main_story.dart`)

**Dead, confirmed by 12 independent greps:** registered only at `/story-home` (80-81, "Keep old screen accessible"); nothing pushes it; live entry is `_AppEntryPoint` → WizardStoryScreen (219-228). It is not harmless: it is the **sole owner of the library/achievements/settings/multi-character/adult-Reflect navigation** (see §18-25, 31-32), contains the unregistered `/manage-profiles` push (1008, crash if tapped), and on web may be reachable via the `#/story-home` URL fragment (unverified). **Decision needed: port its navigation into the live home shell, then delete it.**

---

## Prioritized Fix List

Effort: S < 1h · M ≈ half-day · L = multi-day.

### P0 — Broken functionality & safety
1. **Orphaned app shell**: no live entry to Saved Stories / Achievements / Settings / Offline / Multi-Character / adult Reflect — port StoryScreen's nav into `lib/screens/wizard_story_screen.dart`, then delete `StoryScreen` (`lib/main_story.dart:80,235-1705`). **L** — unlocks §18, 24, 31, 32 at once.
2. Ungated purchase path: route `lib/widgets/paywall_dialog.dart:319-327` through `showPaywallGated`. **S** (safety).
3. Parent Controls empty-trigger save bug — `lib/screens/parent_controls_screen.dart:321-323`: deselecting the last Big Feelings trigger never persists. **S** (control-integrity).
4. TimesUp lockout: two-digit-addition gate + no PopScope + double-grant window — `lib/screens/times_up_screen.dart:34-61`; use the shared multiplication/PIN gate and block back. **M**.
5. Analytics-age contradiction: consent "never under 18" (`lib/screens/parental_consent_screen.dart:574-577`) vs 13+ toggle (`lib/screens/parent_controls_screen.dart:254,634-649`) — reconcile + verify `PrivacyService` runtime behavior. **M** (compliance).
6. Profile delete wipes the whole account under per-profile copy — `lib/services/child_profile_service.dart:115`, `lib/screens/parent_controls_screen.dart:809-866`. **M**.
7. Dead ≥11 reader footer (hides rating + Color chip) — `lib/story_result_screen.dart:4788-4818,4872`. **M**.
8. Pick-a-Path saves only the last segment; no resume UI — `lib/pick_a_path_adventure_screen.dart:779-780,737-740`. **M**.
9. Sprout Chronicles story tiles have no `onTap` — `lib/screens/chronicles_list_screen.dart:184-198`. **S**.
10. CustomAvatar `gender_adventurer_*.webp` vs `.jpg` → blank gender cards for 9-12 — `lib/custom_avatar_screen.dart:1206`. **S**.
11. CharacterEditor role dropdown crash-risk + age cap 17 + archetype overwrite — `lib/screens/character_editor_screen.dart:314-399,65`. **M**.
12. Unregistered `/manage-profiles` route — `lib/main_story.dart:78-83,1008`. **S**.
13. Parent Dashboard reads the legacy story store + non-per-profile feelings → false zeros — `lib/screens/parent_dashboard_screen.dart:54-86`. **M**.
14. Coloring fake Save / stub Print-Export-Download-Share — `lib/coloring_screen.dart:60-153`, `lib/coloring_book_library_screen.dart:120-240`; hide or finish. **M**.
15. Multi-Character CTA posts to an apparently nonexistent endpoint — `lib/multi_character_screen.dart:78` (verify `backend/routes/`); paywall still sells the feature. **M**.
16. Dark Mode toggle no-op — `lib/settings_screen.dart:147-154` vs `lib/main_story.dart:69-84`. **S** (fix or remove).
17. StoryReader resume restarts narration from zero — `lib/story_reader_screen.dart:848`. **S**.
18. Feelings id hyphen/underscore mismatch orphans band art — `lib/theme/age_band_asset_resolver.dart:28`, `lib/widgets/feelings_cloud_picker.dart:706-710`. **S**.
19. Superhero saga re-entry clobbers the typed premise — `lib/screens/wizard_steps/superhero_welcome_back_screen.dart:96`. **S**.
20. Trust-copy false promises (functional): stale BYOK upsell `lib/story_result_screen.dart:5056` **S**; "Therapeutic…"/"Ad-Free" claims `lib/premium_upgrade_screen.dart:388-412` **S**; ToS Family/unlimited `lib/screens/terms_of_service_screen.dart:39-44` **S**; phantom "Upgrade to Family" `lib/screens/subscription_management_screen.dart:447-460` **S**; privacy "3-17" + wrong deletion path `lib/screens/privacy_policy_screen.dart:73,132` **S**.
21. Mature-minor account-holder inconsistency (13-17 can cancel/portal ungated while buying is gated) — `lib/settings_screen.dart:130-135`, `lib/screens/subscription_management_screen.dart:246-293`. **M** (owner decision + gate).

### P1 — Image gaps
1. Free-tier sprout stories ship zero art for the picture-book band — gating at `lib/screens/wizard_steps/magic_review_step.dart:389-390` (pricing/product review). **M**.
2. Band-aware illustration failure/quota placeholders (invisible for adventurer, grey-on-dark for mature) — `lib/widgets/per_page_illustration.dart:38-92`, `lib/story_result_screen.dart:1454-1475`. **M**.
3. Safety-fallback prompt is babyish for older bands — band-tier it in `backend/replicate_image_generator.py:75-99`. **S**.
4. Cover thumbnails in Saved Stories / Chronicles (covers already persisted) — `lib/widgets/story_card.dart:31-80`, `lib/screens/chronicles_list_screen.dart:219`. **M**.
5. Ship the 8 missing creator scenario images; fix the 3 phantom adult `artBackedIds` — `assets/images/scenarios/{creator,adult}/`, `lib/screens/wizard_steps/hero_creator_creative_brief.dart:677-696`. **L** (art) / **S** (de-claim).
6. Explorer review-orb scene art contradicts the tapped tile; adventurer scene art double-booked — `lib/data/scenario_data.dart:276,357,439 / 232,316,358,440`. **M**.
7. Missing `assets/images/hero_placeholder.jpg` (referenced `lib/screens/wizard_steps/hero_creator_step.dart:4043`) + broken `.jpg` archetype fallback (`lib/theme/age_band_asset_resolver.dart:15-16`). **S**.
8. Age-up creator + adventurer archetype portraits; de-kawaii `companions/creator/cipher.webp`; regenerate adventurer badge-style feelings files. **L** (art).
9. Dark cover/end story pages + gate `_FlipSparkles`/✨ on `band.showParticles` — `lib/story_result_screen.dart:3243-3360,4668-4679`. **S**.
10. Welcome/name-step mascot art for young bands; TimesUp sleepy-companion art + sprout TTS. **M**.
11. Achievements badge art + band theming (after reachability). **L**.
12. Sprout human-review items: `assets/images/feelings/sprout/` vs cohesion-audit "adult-coded faces"; `my_big_feelings_btn` art; `lightning_runner` warmth. **S** (review).
13. Band-parameterize `build_superhero_transform_prompt` (Pixar-child hardcode) — `backend/services/image_prompt_helpers.py:100-109`. **S**.
14. Illustrated mode/idea tiles for sprout & explorer (story-type page, ImagineIt chips). **M**.

### P2 — Delight & simplification
1. Age-before-name onboarding reorder (+ mute pre-band TTS) — `lib/screens/welcome_screen.dart:48-49,151-157,474-478`. **M** — the highest-leverage single UX fix for ≥9.
2. Skippable splash + fallback — `lib/screens/splash_screen.dart:25-53`. **S**.
3. Band-theme the shared chrome: StoryReader (**M**), Chronicles list/detail (**S**), CharacterLibrary (**S**), Achievements (**M**), paywalls (**M**), bedtime launch sheet (**S**), MagicalLoadingView (**M**).
4. Chronicle chapters: pass band tone instead of `'whimsical'` — `lib/screens/chronicle_screen.dart:88-89`. **S**.
5. Fix sprout stale TTS prompts (`hero_creator_step.dart:4074,4079`) + dinosaur/dragon label-TTS-art mismatch (`scenario_data.dart:250` vs `hero_creator_step.dart:4117-4124`). **S**.
6. Explorer band seams: pick-a-path young-UI gate ≤8 (`pick_a_path_adventure_screen.dart:1252`), chronicle log style by band not `age<=7`, LifeQuest "on their way" subtitle (`life_quest_screen.dart:295`). **S** each.
7. Superhero polish: TTS for ≤5, costume-screen noir predicate for creator, nemesis-roster tone tier for 11-12, portrait on welcome-back/saga, Edge cost in review. **M**.
8. Enable read-aloud for ≥9 on the result screen (pipeline exists; gate at `story_result_screen.dart:717`); speed presets for mature. **S**.
9. SavedStories delete confirm/undo + adolescent compact toggle (`saved_stories_screen.dart:63-65,299-307`). **S**.
10. Adolescent brief: thematic questions + review scene art + saga recap; mature error-copy pass ("went wiggly", "Ask a parent", raw `$e` strings app-wide). **M**.
11. Route mature/adult "Life Quests" entries to AdultMeditation (adults) and consider its tools for 15-17 (owner decision); add journal entry management + crisis footer. **M**.
12. Sprout GO!-disabled trap: auto-fill or speak the reason (`magic_review_step.dart:1467-1469`). **S**.
13. De-sparkle mature strings in CustomAvatar/remix/chronicle badges; "Man/Woman" labels in the mature brief's gender picker. **S**.
14. Nested wizard→Heroes→wizard navigation loop (`character_library_screen.dart:292-354`). **S**.
15. Leave-guard consistency on the wizard top bar (mature icons, sprout Chronicles). **S**.

---

## Could Not Verify (aggregated)

- **Pixel content of most raster assets** — existence, paths, and wiring verified; only ~20 representative images were visually inspected across auditors. The cohesion-audit P0s (FREEPIK watermark, adult-coded feelings faces) still need a human art pass before launch lock.
- **Runtime behaviors**: web deep-link reachability of `#/story-home` and `/subscription-success`; CSP disposition of the ElevenLabs CDN SVG; `DropdownButtonFormField` assertion behavior in release; whether `DELETE /api/user/<id>/data` cascades across child profiles server-side; store-build OS purchase sheets layering on the app's gates. Static analysis only, per brief.
- **Backend internals**: `/generate-multi-character-story` absence (one grep — confirm), personality-slider key consumption, T10 antihero prompt quality, illustration request assembly for interactive segments.
- **Depth exceptions** noted per persona: parent-gated interiors were audited to their gates by child personas; a few 1,500+ line files were audited by targeted section reads rather than line-by-line (disclosed in each persona's self-check).
- **Process note**: the audit prompt specified 8 subagents over 4 bands; 6 bands were discovered in code, so 12 personas ran. One agent (Adventurer girl) failed on a session limit and was re-dispatched once per the error-handling rule; two others (Creator girl, Adolescent girl) returned status lines first and were re-prompted once to produce full reports. All 12 delivered; every screen has coverage from all bands or an explicit exclusion reason.
