# Synthetic Playtest — Three Skeptical Users — 2026-07-17

**Method:** role-played funnel walkthroughs grounded in the live-prod evidence of
`audit-reports/ux-walkthrough-20260715.md` (real COPPA email round-trip, real timings, real
generation output), the actual screen copy in `lib/screens/` (quoted verbatim below), the
age-band audits (`docs/AGE_BAND_UX_LAUNCH_AUDIT.md`, `docs/SPROUT_UX_AUDIT_2026-05-04.md`),
and the live story samples in `docs/COMPETITIVE_PRODUCT_AUDIT_2026-07-14.md`. State assumed:
post-PR-#448 prod (audio works, MT-262 review-art leak fixed, MT-267 "Surprise me!" name
shipped) with MT-371–375 still open — i.e., what a beta tester hits **today**.

**These are not real users.** They are a cheap proxy for the beta feedback that doesn't exist
yet. Every complaint below is anchored to a real screen, real copy, or a really-observed
behavior; none of it is invented friction.

---

## Persona 1 — Dana, 34. Parent of Maya (4). Privacy-anxious, time-poor.

*Has deleted three "free educational" apps over ads and creepy permissions. Reads privacy
policies. Has 20 minutes between dinner and bath time. Heard about this from a mom group.*

### Walkthrough monologue

> Okay. "Once Upon YOUR Child." The name is a little QVC, but fine — at least it says what
> it is. Maya's on my lap. Let's see how long this takes.
>
> Screen one, screen two... name, age. I put in 4. Now a math problem — "Quick check that a
> grown-up is holding the device." Okay, honestly? Good. That's the first kids' app I've seen
> that checks *before* asking anything, not after. Point for you.
>
> Now a consent form. A long one. I have to scroll the whole notice before the button
> unlocks — "Please scroll through the notice above." And... huh. I'm actually reading it.
> "What We Collect & Why" is bulleted. "No behavioral advertising or third-party tracking."
> Photo-avatar is **off by default** and it says the photo "is used for nothing else."
> Analytics **off by default**. It lists every vendor by name — Cloudflare, Stripe, Railway,
> Sentry — and what each one receives. There's a "For stories — not therapy" box with the 988
> line in it. And then it lists the operator: a person's name, a street address in Grand
> Junction, Colorado, and a phone number.
>
> That last one stops me. This is one person. A person's *house*. Half of me finds that more
> trustworthy than any "trust center" page — a name and a phone number is more accountability
> than Moshi gives me while it ships my kid's data to Facebook. The other half of me is
> thinking: one person, no company page I can find, and I'm about to type in my kid's name
> and my email. Which half wins depends entirely on what happens next.
>
> Now it wants my email to send a verification code. Here's my problem: **I have not seen one
> sentence of a story yet.** Not a sample, not a screenshot of output, nothing. You're asking
> me to complete an email verification loop — for an app I can't evaluate — on faith. I've
> been burned by exactly this shape of ask before. Tonight I'm curious enough. On a worse
> night, this is where I close the tab.
>
> ...Okay, the code came in under thirty seconds and the email is genuinely well-written —
> it explains COPPA, it expires in 15 minutes, it doesn't try to upsell me. That's the moment
> the trust needle actually moves. Weird that the *email* is the best-designed screen in the
> onboarding.
>
> Then it asks me to "shape the stories" — Maya's feelings, triggers, coping. Whoa. I've
> known you for four minutes. You want my daughter's emotional triggers *before I've seen a
> single story*? I skip it. This should have asked me after the first story, when I'd have a
> reason to answer.
>
> The wizard itself is lovely, I'll give it that — Maya's tapping the avatar gallery herself.
> Then "Make Magic!" and... we wait. And wait. Almost two minutes. Maya asked "where's my
> story?" twice and slid off my lap once. The little star game holds her for maybe 40 seconds.
>
> The story arrives. The words are honestly good — it's about *her*, her ocean, her bunny
> buddy, and the scared-then-brave arc is the kind of thing I'd have picked off a shelf.
> The narration voice is warm. But the pictures. The girl on page one is not the avatar Maya
> chose. On page three she's a *different girl*. There's melted text baked into one of the
> illustrations, like a Midjourney fail from 2023. Maya pointed at the hero and said
> "that's not me." Four-year-olds notice. And for me — the parent who just read your lovely
> consent form — garbled AI text in the art is the tell I've been scanning for since screen
> one. It reads as *AI slop*, and it retroactively cheapens everything, including the parts
> that were genuinely careful.
>
> $9.99 a month? Oscar Stories is $4.99 and Moshi is $49.99 a *year*. The words might be
> worth it. The pictures, tonight, are an argument for the free tier — and I found out the
> free tier only illustrates one story when the illustrations quietly stopped, not because
> anyone told me up front.

### Abandonment points

- **Email-verification wall with zero product preview** (parental consent screen, pre-wizard).
  The single most likely quit point. A burned parent will not pay the email toll for an
  unevaluated app. The walkthrough measured ~5–6 minutes best-case to first story; that's
  5–6 minutes of pure faith. (MT-374's pre-consent sample story is exactly this.)
- **"Shape the stories" (feelings/triggers/coping) placed before the first story.** Reads as
  data-hungry to a privacy-anxious parent, which poisons the very trust the consent screen
  just earned. Skipped defensively. (MT-374 placement item.)
- **~110-second generation with a 4-year-old on the lap.** She won't abandon here the first
  night — but she'll pre-decide the app is "too slow for bedtime," which kills the retention
  use case.
- **First-story illustration betrayal** (MT-371: hero ≠ picked avatar, identity changes per
  page, garbled baked-in text). Not a quit-tonight point — a *never-subscribe* point. This is
  where "solo dev who really cares" flips to "AI wrapper."
- **Unsignposted free-tier illustration limit** (MT-280): illustrations silently downgrade
  and the paywall explains itself only after the fact — reads as bait, the exact pattern
  she's been burned by.

### Verdict

> **"The consent flow made me trust you and the pictures made me take it back — I'd keep the
> free tier and I would not put in a card."**

---

## Persona 2 — Maya, 4. Pre-literate. Taps everything. Attention span: one commercial break.

*Experienced from her side. She can't read a single word on the screen. Buttons are "the
sparkly one," "the big one." Anything without a voice or a picture does not exist.*

### Walkthrough monologue

> There's a screen with words. Words words words. No lady talking. Mommy is doing something
> boring with her phone-mail. I tap the screen — nothing fun happens. I tap again. Mommy says
> "one sec, baby." This part is Mommy's app, not mine. *(The entire pre-consent onboarding is
> voiceless by design — TTS is consent-gated, so the pre-reader gets no voice guidance on the
> very screens that ask her to act. MT-373.)*
>
> NOW it's good. There's pictures of kids and I tap the one with the brown hair like me and
> it goes *ding* and moves all by itself. I don't have to find any button. I tap the bunny.
> I tap the ocean one — "Under the Sea!" *(The card art shows a crystal cave, per the
> walkthrough — she can't read the label, so the picture IS the choice. She thinks she picked
> the cave.)* I say my name in the microphone and it sparkles. This part I can do ALL BY
> MYSELF.
>
> Then a screen where nothing dings. There's cards but one is already glowing and nothing
> moves when I look at it. I tap the glowing one — nothing. I tap it again. Where's the go?
> I hold the tablet up to Mommy. *(The story-type step has no visible action when the default
> is preselected — the live walkthrough itself stalled ~30 seconds here. MT-374. And on a
> small phone the GO! button can sit below the fold — S-017 — and toddlers don't scroll.)*
>
> Mommy pushed the big GO. Now there's a bouncing bunny and stars. One star... two stars...
> I like the stars. ...The stars are done. Where's my story? Where's my STORY? I push the
> screen. I go find my juice. *(110 seconds is three to four toddler attention-spans; the
> 5-star countdown covers less than half of it.)*
>
> The book is here! The lady reads it to me and the words — there are no words, just big
> pictures, and the lady says MY NAME. It says Maya! Again! ...But that girl isn't me. I
> picked the other hair. And on the next page it's a *different* girl. Is that girl in my
> story? Why is she in my story?
>
> Read it again. Again! *(She will absolutely ask for repeats — the payoff format, picture-book
> plus narration with her name in it, is exactly right for her. Everything around it is the
> problem.)*
>
> Later I press the top of the screen where the other buttons are and a list comes up with
> words words words and Mommy takes the tablet away. *(One tap off the happy path lands her in
> "Achievements / My Chronicles / Settings" — an AppBar built for Explorer+. S-003.)*

### Abandonment points

- **Every pre-consent screen** — she hands the device back immediately because nothing talks
  to her (MT-373). The app effectively starts as a parents-only app, which is survivable
  once, but means she can never *re-enter* it alone from a cold start.
- **Story-type step with a preselected default** — the one wizard screen that breaks the
  tap-goes-ding contract the rest of the wizard taught her. She stalls and hands back.
  (Observed 30-second stall in the real walkthrough.)
- **Seconds ~40–110 of generation** — the star game ends and she physically leaves. If a
  parent isn't there to re-summon her, the payoff plays to an empty room.
- **The wrong girl in the pictures** (MT-371) — she doesn't quit the app, she quits *the
  premise*: the magic claim was "a story about YOU," and the pictures say otherwise. She'll
  still want stories; she'll stop caring about the avatar she built, which is the product's
  emotional core.

### Verdict

> **"Read it again! ...but why is that girl in my story?"**

---

## Persona 3 — Theo, 16. Jaded. Would rather die than have a "kids' app" on his phone.

*Can smell adult-written teen voice from orbit. Screenshots cringe to the group chat. Only
here because the story thing sounded vaguely like AI Dungeon.*

### Walkthrough monologue

> The app is called "Once Upon YOUR Child." I'm the child. It's addressed to my mom. I have
> not tapped anything yet and I'm already someone's *your child*. If a friend saw this on my
> phone the name alone is the screenshot — I wouldn't even need to open it. Whatever the app
> does, it does it from inside a name that outs me for using it.
>
> Okay, onboarding is actually fast — name, age, done, no email, no account nag. Then a popup:
> "Just so you know" — in a bubbly rounded font with gold trim, like a birthday invitation —
> telling me my "parent or guardian should know you're using it. If they don't yet, let them
> know." I mean... legally, sure, fine. But you wrote "hey champ, tell your mom" in the Comic
> Sans of legal notices. The message is 13+; the font is 6.
>
> The actual builder surprises me. "Pick your vibe": "Be the Hero" or "Live a Double Life —
> an antihero saga: real stakes, a real cost." Okay. That's... not what I expected. "Build
> your cover." "What are you hiding?" — and one of the chips is literally "That I'm not
> okay." "What gives you away?" "Where do you draw the line?" — "Never sell out a friend,"
> "Never use it on someone weaker." "Who gets to see the real you?" — "One friend who knows
> everything," "No one — not yet."
>
> I keep waiting for it to flinch and it doesn't. Nobody says "it's okay to have big
> feelings!" at me. There IS a disclaimer screen when you pick the secret stuff — "stories
> are handled with care... real support is one tap away if any of it is true" — and yeah,
> my eyes rolled, the trench coat opened for a second and I saw the wellness app inside.
> But it's one screen, it's honest about what it is, and then it gets out of the way.
> That's the correct amount of therapy: one skippable screen of it.
>
> Then I hit "create" and stare at a loading screen long enough to switch to my group chat
> and forget the app exists. Found it again three minutes later.
>
> The story though. Okay. It's first person, it's about perfection-pressure, and it doesn't
> end with a moral. Nobody learns a lesson out loud. The last line doesn't hug me. I read
> the whole thing, which is more than I can say for anything a school counselor has ever
> handed me. It's genuinely better written than the app around it — like finding a good
> novelist trapped inside a Happy Meal.
>
> Would I come back? ...Quietly, maybe, in a browser tab, where it doesn't have an icon.
> I made a second story two days later and it also smelled like a bakery — the first one was
> literally *set* in a bakery and the next one had lemon-and-honey air for no reason. Once
> you notice the app has one candle scent, you can't un-notice it. And there's a companion
> option called "Rockin' Robin," which — no. I'm not adding "Rockin' Robin" to my gritty
> double-life saga. And $9.99 a month is more than my music. That's not a maybe, that's a no.

### Abandonment points

- **The install decision itself.** "Once Upon YOUR Child" as the visible brand is a hard
  social blocker for a self-serve 16-year-old — the abandonment happens on the app-store
  page / home-screen icon, before any UX is even reached. (The technical brand "Story
  Weaver" already exists and is exactly the name this band could carry.)
- **"Just so you know" dialog styled in Fredoka + gold** (welcome_screen.dart:988-996) — the
  first-impression tone contradiction. He clicks through it, but it costs the app its "not
  a kids' app" plea before the good noir copy gets a chance.
- **The ~2-minute silent generation wait** — he tabs away and may simply not return; there's
  no partial text, no hook on screen worth staring at, and (MT-375 territory) an impatient
  re-tap historically spawned duplicate generations.
- **The second/third story smelling like the first** (finding A-1, sensory-palette
  monoculture — the default "Bright colors, soft sounds, sweet smells" palette drove the
  premise of the 16-band sample). Band voice survives one story brilliantly; the *return
  visit* is where sameness reads as "the AI has one trick," and this persona only converts
  on return visits.
- **Any leftover kid-chrome in the noir flow** (gold accents/emoji-confetti on the teal band,
  "Rockin' Robin" offered in mature bands — MT-273/MT-281). Each instance is a screenshot
  he'd caption "therapy app thinks it's Batman."

### Verdict

> **"The writing's legit — shame it lives inside an app named by my mom, in a font picked by
> my little sister."**

---

## Top 5 fixes that would most change these verdicts (ranked)

1. **Fix Sprout illustration cohesion before anything else (MT-371).** It's the single point
   where all the earned trust converts or dies: Dana's "never-subscribe" moment, Maya's
   "that's not me," and the only place the product visibly reads as *AI slop* to the exact
   audience the consent flow just impressed. The words already deliver; the pictures are
   actively contradicting them. (Lead is already known: prefetcher firing with
   `characterAppearance=null` on a just-created character.)
2. **Put a story in front of the email wall (MT-374, "See a story").** The consent flow is a
   genuine trust *asset* — the best COPPA posture in the competitive set — but it's spent
   before any value is shown. One pre-baked sample story (no generation, no data) on the
   consent screen converts the email round-trip from toll to receipt. Same change bundle:
   move "Shape the stories" to after the first story, where answering it feels earned.
3. **Redesign the 110-second wait as an experience, not a spinner.** All three personas hit
   it; two of them physically leave. Options in ascending effort: stream/show the first page
   as soon as it exists; extend the Sprout star game to cover the real duration; give teens
   the opening line as a hook. Pair with the MT-375 resubmit guard so the impatient re-tap
   (observed in prod: 3 duplicate Celery jobs in 4 minutes) can't happen.
4. **De-parent the 13+ surface.** Present the Creator/Adolescent/Adult bands under the
   existing "Story Weaver" mark (the brand architecture — "Once Upon YOUR Child, powered by
   Story Weaver" — already permits this), and restyle the "Just so you know" notice in the
   band's own type/palette instead of Fredoka-and-gold. The teen content is the moat
   (nobody else generates for 15–17 at all); the wrapper is currently the only thing
   stopping this persona from being a repeat user. Sweep the remaining gold/kid-chrome
   leaks (MT-273) and pull "Rockin' Robin" from the mature-band companion list (MT-281 —
   re-art/rename in mature bands only; the Robin character itself stays as designed).
5. **Rotate the sensory palette (finding A-1) + make the story-type step act tappable
   (MT-374).** Two small ones that gate the *second* session: the bakery-scent monoculture
   is the teen's stated reason not to return, and the preselected story-type step is the
   one wizard screen that breaks the tap-advance contract for a 4-year-old (30-second stall
   observed live). Both are prompt/one-screen-sized changes.

*Deliberately not proposed:* gender-picker changes (owner-decided Boy/Girl, 2026-07),
premium-model swaps, and Family Voice cloning (owner-declined) — persona reactions were
kept honest, but the fix list respects settled decisions.
