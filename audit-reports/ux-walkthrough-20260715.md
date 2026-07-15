# Fresh-Eyes UX Walkthrough — 2026-07-15

**Method:** live prod (onceuponyourchild.app) via Playwright, fresh browser profile per persona,
no cached state — exactly what a first-time user sees. Personas: parent of a 4-year-old (Sprout,
full COPPA email round-trip completed for real), 15–17 teen, 18+ adult. Trigger: owner demoed the
app to a family member and lost them before the first story ("too confusing for your average
child or parent?").

**Headline answer:** the wizard is NOT the problem — it's the best part. The demo dies on
(a) the 8-screen pre-wizard gauntlet + email round-trip, (b) ~110s+ generation waits, and
(c) a broken payoff: narration audio was 100% dead on prod web (CSP), the adult/async story path
never completed at all (unauthenticated polling), and Sprout per-page art contradicts everything
the child picked.

---

## Funnel timings (fresh device → first story)

| Persona | Steps to wizard | Wall items | Generation | Total (best case) |
|---|---|---|---|---|
| Parent + 4yo (Sprout) | 8 screens incl. math gate, COPPA scroll, email code | email round-trip (code arrived <30 s, well-written) | ~110 s (sync 200 path) | ~5–6 min |
| Teen 15–17 | 4 (start → name → age → "Just so you know") | none — one Got-it dialog | not timed | <1 min to wizard |
| Adult 18+ | 3 (start → name → age) | none | **NEVER COMPLETED** (bug, fixed in PR #448) | n/a |

The adult wizard already implements the "simple first" ideal: everything optional is collapsed,
one Create Story button on step 1. The child bands' 4-step wizard is delightful (avatar gallery,
archetype art, buddy, scenes) — keep it; fix what brackets it.

## P0s found (both fixed in PR #448 the same day)

1. **All audio dead on prod web.** CSP had no `media-src`, so `default-src 'self'` blocked
   `blob:` SFX AND `data:audio/mpeg` TTS playback. "Read to me" was silent for the one band
   (3–5, picture-book design) that depends on narration. Backend TTS returned 200s — audio died
   at playback (`MEDIA_ELEMENT_ERROR: URL safety check`). Third CSP incident (gstatic, image_picker).
   Fix: `media-src 'self' data: blob:` in `web/_headers` + `nginx.conf`.
2. **Async story path never completed.** `/generate-story` → 202, then every `GET /task-status/<id>`
   poll 401'd — the client sent **no Authorization header** on polls (endpoint is auth-gated since
   the authz sweep). Client threw, callers re-submitted → 3 duplicate Celery generations from one
   user in 4 min, while the user watched "Setting the scene…" forever. Any story overrunning the
   sync window hits this: adult Medium, companion-heavy, long bedtime. Fix: poll sends
   `authHeaders()`; regression test pins it. Follow-ups: MT-375 (resubmit cap / idempotency).

## Filed as MTs

- **MT-370** — SMS "text plus" consent (owner request; 2025 amended COPPA Rule allows it;
  Twilio Verify + A2P 10DLC under the LLC; privacy-policy line for parent phone).
- **MT-371** — Sprout per-page illustration cohesion: hero ≠ picked avatar, identity changes every
  page, companion/scene absent, garbled AI text baked into art; + "Under the Sea!" scene card shows
  a crystal cave. Lead: prefetcher fires with `characterAppearance=null` on a just-created character.
- **MT-372** — Sprout story punctuation: declaratives/onomatopoeia end in "?" ("SPLASH? Pebble said",
  "WHOOSH BOING?"). Verify post-#441-deploy; tighten prompt if still rampant.
- **MT-373** — Sprout onboarding is voiceless pre-consent (TTS 403s by design; pre-readers get no
  voice guidance on the screens that ask them to act). Option: bundled onboarding phrases (no vendor
  call → no consent needed).
- **MT-374** — owner-decision bundle: pre-consent sample story ("See a story", biggest lever);
  move "Shape the stories" post-first-story; story-type step has no visible action when default
  preselected (walkthrough stalled ~30 s); adult gender cards say "Boy/Girl" + Girl preselected;
  rename "PICK YOUR ARCHETYPE!" for young bands.
- **MT-375** — duplicate-generation guard (client retry cap + server idempotency).

## Smaller fixes shipped in PR #448

- Parental-gate dialog on the consent path claimed "This opens an external website" (reused BYOK
  component copy) → message parameterized, consent screen passes accurate copy.
- Read-aloud badge said "ElevenLabs voice" for a consented 4-year-old (Azure serves kids;
  ElevenLabs is 13+ opt-in; client never learns the provider) → neutral "Storyteller voice".

## Notes / non-bugs

- The consent email itself is excellent (clear COPPA framing, 15-min expiry, code arrived <30 s).
- "Shape the stories" hidden-parent-context copy is good — it's the *placement* that hurts.
- Sprout reader showing no words in the book is intentional (picture-book: art + narration);
  the full text lives in the Read-to-me overlay. Works once audio works.
- Pre-consent TTS 403s are correct server behavior (consent gate) — the client shouldn't call (MT-373).
- "Customise it — Free with your key … uses your own Google AI key" on the child avatar path is
  jargon for parents AND a Gemini reference on a child path — left alone this session because the
  active `sw-byok-openai` worktree owns BYOK; flag it there.
- ~40 `/tts/synthesize` calls fired during one Sprout onboarding (warm-up storm) — worth a look
  at Azure char billing if sessions scale.
