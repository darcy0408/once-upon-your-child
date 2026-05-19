# MT-139 — Per-age-band production verification sweep

Run: 2026-05-19 against `grand-light-production-68d9.up.railway.app`
Method: Playwright + Flutter semantics tree (CanvasKit app — semantics enabled via `flt-semantics-placeholder`).
Account: free tier, anonymous, child name "Tester", photo-avatar consent ON.

## Sprout band (age 4) — story: "Tester and the Rainbow Bubbles" (11 pages)

| MT | What | Result |
|----|------|--------|
| MT-032 | Sprout scene tap auto-advances wizard | PASS — tapping dinosaur scene jumped to step 4 |
| MT-043 | Sprout story-result redesign | PASS — body text visible at 414px width, no Reading Level pill |
| MT-054 | Sprout per-page illustrations on free server-key path | PASS — illustrations rendered for free non-BYOK account |
| MT-055 | "The End" page redesign | PASS — celebration banner + sparkles, large "The End", horizontal CTA row (Read to me / Loved / Color) |
| MT-058 | Sprout >=5 body pages | PASS — story generated 11 pages |
| MT-065 | Tappable review tiles + "Pick something new" | PASS (presence) — all three tiles + "Pick something new" button present on review step |
| MT-067 | Sprout sparkle-catcher idle stars | PASS — idle targets are star-shaped, glowing, layered (not gold discs); constellation counter present. Fireworks-on-tap not tested. |
| MT-074 | Featured photo-avatar card visual | PASS — gradient card, gold NEW badge, emoji-arrow row, "or" divider, gallery card below |
| MT-097 | Sprout page cap 8-12 | PASS for page count (11). **FAIL for no-gibberish-in-illustrations** — see findings below |
| MT-098 | Sprout page-count validation | PASS — 11 pages, within range |

### FINDING — MT-097 illustration gibberish text STILL PRESENT
Pages 1, 2 and 4 of the generated Sprout story have garbled/nonsense text baked into
the illustrations (e.g. page 1 "ROUMLE feel / RUMBLE!", page 2 "pekore lime. boinping bib...").
Commit `9628de7d` added an ABSOLUTE RULE forbidding readable text in images, but it is
not effective on production. Intermittent — page 3 was clean. Re-scope MT-097.
Screenshots: mt139-sprout-story-p1.png, mt139-sprout-story-p2.png.

### Note — MT-100 name gate
Tapping "Boy" with the hero-name override field visibly empty advanced to the build-style
sub-page with no red snackbar. Gate likely keys off the already-set child name ("Tester")
so the truly-nameless state is not reachable in normal flow. Not a reproducible bug.

## Explorer band (age 6-8) — story: "Flicker's Rainbow Dream" (11 pages)

| MT | What | Result |
|----|------|--------|
| MT-081 | "Add a Grown-up" picker | PASS — bottom sheet with 6 chips (Mom/Dad/Grandma/Grandpa/Aunt/Uncle) + name field; "👵 Grandma Nana" chip appears inline with delete |
| MT-100 | Robin companion dedupe | PASS — exactly one Robin orb in the showcase row |
| MT-043 | Older-band layout keeps Reading Level pill | PASS — "Reading Level: Early Reader" pill shown for Explorer |
| MT-051 | Story-type decision-fatigue | STILL RELEVANT (design task) — story-style step shows 4 modes + 6 "wish" chips at once |
| MT-086 | Free-tier illustrations w/ monthly cap | **FAIL on production** — see headline finding |
| MT-087 | Free-tier illustration cap upsell UI | **Still blocked** — banner never triggers (rate-limit shadowing, as MT-087's own note predicted) |
| MT-089 | Prefetcher 2-failure circuit-breaker | PASS (inferred) — Explorer prefetcher stopped after 2 consecutive 429s |

### HEADLINE FINDING — free-tier (ages 6+) stories get NO illustrations on production
The Explorer free-tier story "Flicker's Rainbow Dream" rendered **text-only on every page** —
no illustrations, no skeleton loaders, no quota/upsell banner.
Network trace of `POST /generate-illustrations`:
- Sprout story (unmetered): 5×[200] then 2×[429] — circuit-breaker tripped, 5/11 pages illustrated.
- Explorer story (metered free tier): 2×[429], zero [200] — circuit-breaker tripped, 0 pages illustrated.
The per-page prefetcher fires a burst of concurrent requests; the free-tier `1/minute`
rate-limit on `/generate-illustrations` returns HTTP 429, which is NOT the
`ILLUSTRATION_QUOTA_EXCEEDED` shape, so no illustrations render AND no upsell shows.
This is exactly the MT-113 / MT-087 "rate-limit shadowing" bug — **MT-113 is marked [done]
but the bug is still live on production.** This breaks the MT-086 free-illustration
feature and the MT-087 conversion UI for every free ages-6+ user.
Re-open MT-113; MT-086/MT-087 cannot pass until it is fixed.

### Observation — story title vs. scene
Both Sprout (dinosaur scene → "Rainbow Bubbles") and Explorer (dragon scene → "Rainbow
Dream") produced titles that don't reference the chosen scene. Story body DID match the
scene (Explorer story featured "Flicker the dragon"). Likely cosmetic; worth a glance.

## Adventurer band (age 9-11)

| MT | What | Result |
|----|------|--------|
| MT-052 | Coping Toolbox across bands | PASS (Adventurer) — "Feeling toolbox" strip with 6 techniques (Dragon/Belly/Star/Volcano/Hot Cocoa/5-4-3-2-1); 5 Adventurer quests listed |
| MT-053 | Big Feelings / Life Quest tile → LifeQuestScreen | PASS (Adventurer) — "Life Quest" scene tile routed to the rich "Pick Your Quest" LifeQuestScreen, not the thin modal |
| MT-059 | Breathing-orb practice sheet | PASS — Belly Breath ran all 4 rounds (Round 1→4), prompts cycled, completed to "You did it!" screen. Orb rendered; exercise functions end-to-end. |
| MT-100 | Age-picker dialog (create new hero) | PASS — "How old is your new hero?" modal, 6 bands, theme flips per band |

### RESOLVED — Adventurer wizard "Next" = automation artifact, NOT a bug
On the Adventurer "Choose your setting" step, the "Next: Story Style" arrow would not
advance under automation (tried Playwright element click, dispatched Mouse/Pointer
events, multiple scenes). The owner manually click-tested it and **the wizard advances
fine for a real user** — they reached the "Start Adventure!" step. So this is a
Flutter-semantics tap artifact: that particular button's tap action is not exposed to
the accessibility tree the Playwright harness drives. NOT a product bug.
Consequence: the older-band (Adventurer/Creator/Adolescent/Adult) story-result walks
could not be automated this pass — they need a manual or instrumented-build run.

Side note: the owner's manual run was on a localhost dev build (`localhost:49218`) and
story generation showed "Something went wrong" — most likely the local Flask backend
(`localhost:5000`) was not running. Sprout & Explorer story generation worked fine on
production, so this is probably a dev-environment issue, not a production failure
(unconfirmed — worth a retry on the production URL).

## Cross-band / non-wizard

| MT | What | Result |
|----|------|--------|
| MT-080 | Premium 6-char cap + "whole family" copy | PASS — subscription screen Premium card headlines "Premium — for the whole family", lists "6 characters", "'Whose turn is it?' rotating hero", "10,000 chars/mo of premium voice narration", "All 8 themes" |

### FINDING — privacy-copy contradiction on photo-avatar
The Parent Controls "Allow photo-based avatar creation" toggle says: *"Photos are
processed on-device and never uploaded."*
But the COPPA consent screen says the photo *"is sent securely to generate the avatar"*
and lists OpenRouter / Replicate / Cloudflare Workers AI as receiving *"the child's
photo"* on the photo-avatar path (consistent with MT-137).
The Parent Controls statement is factually wrong and COPPA-sensitive. File a fix MT to
correct the Parent Controls copy. Screenshot: parent-controls (e608 description).

## Not verified this pass
- Sprout: MT-016/019 (audio — blocked by MT-091 ElevenLabs outage), MT-018 (Make One Up — button present, not exercised), MT-021 (avatar steps), MT-030 (offline scaffold), MT-073 (BYOK tweak panel), MT-088/096 (photo avatar — needs a real face photo, not supplied)
- Creator / Adolescent / Adult: story walks blocked by the wizard-Next issue above
- MT-120 (paid-tier per-power overrides), MT-050/086 (BYOK illustrations) — need BYOK key applied
