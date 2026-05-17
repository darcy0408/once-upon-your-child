# Audit Perspectives — Story Weaver / "Once Upon a Time"

Date: 2026-05-17
Context: A full **security** audit was completed 2026-05-16 (see `security-audit/`, the Six Hats
review). This file captures the *other* perspectives worth auditing the app from. Each is a
candidate for its own focused review, structured the same way the security audit was — read-only
sweep, findings ranked by severity and child-impact, then a remediation plan.

App profile (for scoping each audit): children's AI storytelling app, ages 3–17, four age bands
(Sprout 3–5, Explorer 6–8, Adventurer 9–12, adolescent). Flutter client, Flask + Celery backend on
Railway, Postgres, AI story/image generation, BYOK, Stripe subscriptions, COPPA consent flow.

Status legend: ☐ not started · ◐ in progress · ✅ done

---

## 1. ☐ Accessibility (a11y)
Screen-reader labels, focus order, tap-target sizes, colour contrast, text scaling, motion/animation
sensitivity, captions for TTS/audio. **Why here:** young children, motor-skill limits, and possible
assistive-tech use make this central, not cosmetic. A Playwright a11y harness already exists
(`docs/agent-briefs/PLAYWRIGHT_SMOKE_TEST.md`) — extend it. Surfaces: every screen in `lib/screens/`.

## 2. ☐ Child development & age-appropriateness (pedagogy)
Does vocabulary, sentence length, story complexity, page count, and interaction model actually fit
each band? Reading level vs. declared age; emotional content calibrated to developmental stage.
**Why here:** the whole product premise. Surfaces: age-band prompt templates, `quality_service.py`,
story-gen services, the Big Feelings / Life Quest content.

## 3. ☐ Content safety & editorial quality
Beyond the security prompt-injection angle: are *generated* stories coherent, on-theme, free of
scary/biased/inappropriate content, and consistent in tone? Illustration quality and text-in-image
artifacts. **Why here:** AI output is the product and it is non-deterministic. Surfaces: moderation
pipeline, image-gen routing, A/B results in `docs/IMAGE_GEN_AB_TEST_RESULTS.md`.

## 4. ☐ UX & usability
Onboarding friction, wizard flow, navigation clarity, error states, empty states, dead ends. Can a
caregiver *and* a child each complete core flows unaided? **Why here:** prior UX audits exist but are
band-specific and aging (`docs/UX_AGE_AUDIT.md`, `docs/SPROUT_UX_AUDIT_2026-05-04.md`) — a current
whole-app pass is due.

## 5. ☐ Performance & responsiveness
Cold-start time, story/image generation latency and perceived wait, frame jank, memory on low-end
devices, bundle/asset size, prefetcher behaviour. **Why here:** children abandon fast; AI calls are
slow. Surfaces: prefetcher circuit-breaker, image pipeline, Flutter web build.

## 6. ☐ Reliability & resilience (SRE)
Behaviour under provider outage, timeout, rate-limit, or offline: graceful degradation vs. crash or
hang. Retry/fallback logic, circuit breakers, the offline story fallback. **Why here:** the app
depends on several third-party AI/payment services. Surfaces: backend service layer, Celery worker,
quota handling.

## 7. ✅ Legal & compliance (beyond security's COPPA slice) — done 2026-05-17, see `LEGAL-COMPLIANCE.md`
Full COPPA §312, GDPR-K, app-store policies (Apple Kids Category, Google Families), accessibility
law (ADA/EN 301 549), and AI-disclosure rules. Privacy policy vs. actual data flows. **Why here:**
a kids' app faces the strictest regulatory regime; the security audit touched consent but not the
full surface. Surfaces: `PRIVACY_POLICY.md`, consent flow, store metadata.

## 8. ☐ Monetization & business model
Stripe subscription correctness, tier gating, paywall placement, BYOK economics, free-tier limits,
upgrade/downgrade/refund paths, trial behaviour. **Why here:** prior Stripe work found real bugs
(see `docs/PREMIUM_BYOK_MATRIX.md`); pricing decisions interact with cost-per-image. Surfaces:
webhook handler, subscription services, paywall UI.

## 9. ☐ Data integrity & analytics
Local persistence correctness (Isar / SharedPreferences), story/profile save reliability, migration
safety, and whether analytics events are accurate, consented, and not double-counted. **Why here:**
losing a child's saved story is a trust-killer; analytics gate on consent. Surfaces: local DB layer,
`firebase_analytics_service.dart`, `privacy_service.dart`.

## 10. ☐ Cost & efficiency
Per-story and per-image spend across providers, caching effectiveness, wasteful regeneration, model
routing choices. **Why here:** image gen is ~$0.0375/image and margins depend on it. Surfaces:
image-gen routing, caching layer, provider selection logic.

## 11. ☐ Inclusivity & representation
Diversity of avatars, names, story characters, and scenarios; gendered assumptions; cultural
breadth; representation of disability and family structures. **Why here:** a storytelling app shapes
how children see themselves and others. Surfaces: avatar categories, archetype images, prompt
templates.

## 12. ☐ Internationalization & localization
Hard-coded English strings, locale-aware dates/names, RTL readiness, TTS voice coverage, and whether
story generation can produce other languages. **Why here:** determines market reach; cheap to design
for now, expensive to retrofit. Surfaces: all UI strings, TTS service, story-gen prompts.

## 13. ☐ Code quality & technical debt
Dead code, duplicated services (e.g. the two competing SubscriptionService classes already noted),
test coverage gaps, dependency freshness, architectural drift. **Why here:** solo dev + many
parallel agent sessions accumulate drift. Surfaces: whole repo; test suite; `pubspec`/`requirements`.

## 14. ☐ Brand & narrative consistency
Consistent use of "Once Upon a Time, powered by Story Weaver", visual identity, tone of voice across
UI copy, store listing, and generated content. **Why here:** see memory `brand_name.md` — the brand
split is easy to get wrong. Surfaces: UI copy, splash/welcome screens, store metadata.

---

## Suggested order
If running these sequentially, a reasonable priority for a pre-launch kids' app:
1. Legal & compliance (#7) — blocks launch
2. Accessibility (#1) — blocks store approval in Kids categories
3. Child development & age-appropriateness (#2) — core product quality
4. Content safety & editorial quality (#3)
5. Reliability & resilience (#6)
6. UX & usability (#4)
7. Monetization (#8) + Data integrity (#9)
8. Everything else as capacity allows.
