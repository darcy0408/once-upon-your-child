# Unfinished-Features Audit — 2026-07-07

Three parallel read-only sweeps (Flutter client, backend, docs/backlog trail) cross-referencing
code reachability, client↔server route usage, env flags, and the session/MT history.
Verdicts: **DELETE** / **FINISH** / **KEEP (dormant-deliberate)** / **OWNER DECISION**.
Tracked as MT-350…MT-359. Executed waves reference this doc.

Headline: **~24,700 lines (~19.5% of `lib/`, 49 whole files) are unreachable dead code**;
backend has ~15 orphaned routes/modules; the largest unfinished build is **IAP receipt
verification** (client calls it; backend stubs raise `NotImplementedError`).

> Overlap note: PR **#407** (session/dead-code-sweep, opened 2026-07-07 by a parallel session)
> already deletes `character_evolution_screen.dart`, `character_gallery_screen.dart`,
> `coping_strategy_library.dart`, `feelings_wheel_screen.dart` + 4 mood/mindfulness files this
> audit didn't flag. Tables below note "(#407)" where a file is covered there. PR **#398**
> (annual billing + server quota) merged 2026-07-07 — removed from the finish list.

---

## 1. DELETE — Flutter (MT-356, waves: B → A → C-remainder + standalones)

### Cluster A — legacy "Story Home" pre-wizard app root (~6,600 lines)
Live app boots Splash → Consent → Wizard (`_AppEntryPointState.build()`, `main_story.dart:184-232`)
and never references `StoryScreen`; route `/story-home` is never pushed (only 3 `pushNamed` calls
exist app-wide; `/subscription-success` is the only registered+reachable one).

| File | Lines | Note |
|---|---|---|
| `lib/main_story.dart:235-2085` (`StoryScreen` + 6 private widgets) | 1,851 (partial file) | keep lines 1-234 |
| `lib/dialogs/upgrade_prompt_dialog.dart` | 409 | only call site is inside dead `StoryScreen` |
| `lib/quick_story_screen.dart` | 766 | |
| `lib/screens/adult_meditation_screen.dart` | 1,069 | **CAVEAT: only "Adult Breathe" impl — verify the Adult Reflect screen doesn't route here before deleting** |
| `lib/saved_stories_screen.dart` | 882 | |
| `lib/achievements_screen.dart` | 675 | |
| `lib/offline_stories_screen.dart` | 400 | |
| `lib/multi_character_screen.dart` | 252 | |
| `lib/widgets/story_card.dart` | 274 | only used by dead `saved_stories_screen` |

Also: `pushNamed('/manage-profiles')` (`main_story.dart:1008`) and `/subscription-plans`
(`upgrade_prompt_dialog.dart:178`) target **unregistered routes** — would throw if reached;
both call sites are inside this dead cluster.

### Cluster B — legacy character-creation / avatar-builder (~7,700 lines, 21 files)
Superseded by the Hero Creator wizard. Delete-roots: `character_creation_screen_enhanced.dart`
(1,797) and `character_edit_screen_enhanced.dart` (603) — unimported anywhere; a 2026-03-30
"dead code cleanup" commit missed them. Everything below is reachable only from those two:
`character_creation_screen.dart` (223), `character_customization_constants.dart` (157),
`avatar_preset_selector.dart` (208), `avatar_builder_screen.dart` (745),
`customizable_avatar_widget.dart` (129), `services/character_analytics.dart` (80),
`services/character_template_service.dart` (190), `appearance_options.dart` (63),
`interest_options.dart` (64), `sunset_jungle_theme.dart` (215), `emotion_models.dart` (284),
`emotion_picker_widget.dart` (313), `enhanced_character_avatar.dart` (387),
`character_gallery_screen.dart` (380) (#407), `feelings_wheel_screen.dart` (497) (#407),
`screens/avatar_picker_screen.dart` (325), `screens/midjourney_avatar_picker_screen.dart` (401),
`emotion_avatar_widget.dart` (235), `achievement_celebration_dialog.dart` (425 — its live call
site is commented out "annoying popups", rollback reads as final).

### Cluster C — orphaned "Character Evolution" therapeutic library (~7,650 lines, 10 files)
Built in a single day (2025-11-14); **silently orphaned 2026-07-03** when PR #367's subtraction
sprint deleted its only entry point (`character_management_screen_v2.dart`). Root screen
`character_evolution_screen.dart` + `coping_strategy_library.dart` are deleted by **#407**.
Remainder (all zero live importers, verified 2026-07-07): `character_evolution.dart` (433 — #407's
"still live" note is incorrect), **`therapeutic_models.dart` (662 — also dead; 21
`TherapeuticScenario` templates + the `TherapeuticGoal` enum)**, `conflict_resolution_stories.dart`
(721), `conflict_resolution_data.dart` (470), `emotion_recognition_game.dart` (767),
`empathy_building_exercises.dart` (923), `family_relationship_stories.dart` (800),
`peer_interaction_stories.dart` (800).

**Knock-on finding:** boundary-skills **Phase 1 (PR #253) rode on `therapeutic_models.dart` and
was orphaned with it** — the parent-facing "Setting Boundaries" therapeutic-goal picker no longer
exists live (boundary *content* survives via Life Quests `big_no` etc.). MT-232's "Phases 2-5 on
top of Phase 1" premise is stale; any future build starts on Life Quests / prompt-spine rails.

**Salvage inventory (2026-07-07 content audit):** ~1,600 lines of authored content; **~45%
near-drop-in** — the 8 conflict-resolution CYOA stories (~460 lines, maps almost directly to
`QuestChoice`/`QuestSegment`) and the 14 coping strategies' step-by-step instructions. Unique,
not covered by the 46 live Life Quests: a 10-scenario **focus/executive-function track** (impulse
control, active listening, organization, task persistence), the structured coping taxonomy, the
distractor-based empathy-labeling quiz mode, and warm non-conflict family-bonding stories.
~60-65% of topics are redundant (Life Quests covers them better: branching, sensitivity gating,
parent notes — the cluster has none of those). **OWNER DECISION: mine the high-salvage pieces
into Life Quests before deleting, or delete outright.** Git history preserves it either way.

### Standalone dead files (~3,400 lines)
`paywall_dialog.dart` (423), `widgets/imagine_it_input.dart` (1,246 — duplicate of live
`ImagineItScreen`), `character_appearance_converter.dart` (544, test-only refs),
`story_narrator.dart` (161), `providers/character_provider.dart` (55, providers never watched),
`widgets/age_band_badge.dart` (57), `widgets/image_continue_button.dart` (210),
`widgets/parallax_tilt_card.dart` (124), `widgets/pill_button.dart` (118, test-only),
`widgets/quality_badge.dart` (155), `data/mood_lantern_data.dart` (219),
`services/avatar_generation_service.dart` (120 — the *service*; `AvatarGenerationState` and
`AvatarService` are live, don't confuse). Partials: `FeatureUnlockCelebrationDialog`/
`FeatureUnlockProgressIndicator`/`FeatureLockOverlay` (`widgets/feature_unlock_tooltip.dart:73-230`;
`FeatureUnlockTooltip` itself is live), `MockIllustrationService`
(`story_illustration_service.dart:460-497`).

Stale doc artifact: `wizard_story_screen.dart:38-45` class comment still describes the removed
4-step wizard (live wizard = HeroCreator → MagicReview for **all** bands; sub-steps live inside
HeroCreator). Fix the comment during wave A.

## 2. DELETE — Backend

### Wave 1 (PR opened by this session: `chore/backend-deadwood-wave1`)
- `POST /api/user/<id>/cancel-subscription` (`user_routes.py:154-176`) — orphaned dup that skips
  Stripe entirely (would desync billing if hit).
- `GET /api/user/<id>/subscription` (`subscription_routes.py:88`) — dup of
  `/api/stripe/subscription-status/<id>`.
- `POST /auth/login` (`utility_routes.py:430-471`) — test-only login, **no prod gate** (delete or
  prod-gate if tests depend).
- `POST /generate-illustrations-mock`, `POST /generate-coloring-pages-mock`
  (`story_routes.py:~3227/~3319`), `POST /avatar/generate-avatar-mock` (`avatar_routes.py:~1366`)
  — unauthenticated, prod-ungated, zero callers.
- `GET /get-story-themes` (`story_routes.py:722`) — client sources themes locally.
- Dead modules: `models/models.py` (0 bytes), `tts_service.py` (old Google Cloud TTS),
  `services/avatar_to_prompt_helper.py`, `backend/migrations/*.py` (16 one-off scripts; schema is
  `db.create_all()` + `app.py:631-660` auto-migrate).
- CI: `rollback.yml` Netlify no-op job (a real rollback would silently skip the frontend);
  `health-monitoring.yml` (schedule-disabled, checks Netlify + a deleted endpoint).

### Wave 2 (MT-359 — after wave 1 + owner decisions)
- `avatar_gallery_routes.py` + `backend/static/avatars/` (55 PNGs) — client gallery is
  bundled-assets only.
- Legacy avatar-by-description subsystem: `avatar_routes.py:785,1030,1140,1185` +
  `AvatarGenerationService.generate_avatar/regenerate_avatar/get_fallback_avatars`
  (`avatar_generation_service.py:1288-1480,1674+`) — client avatars are DiceBear client-side.
- Achievement `record/story`, `record/character`, `stats` routes (`achievement_routes.py:58-96`)
  — client only uses `/achievement/sync` + `/achievement/data`.
- `api_key_routes.py` + `User.has_byok`/`gemini_api_key_encrypted` + `migrate_byok.py` — **only if
  MT-358 (BYOK direction) says sunset**; write path is unreachable today either way.
- `cicd.yml` `backend-deploy-check` echo stub (**check branch-protection required checks first**),
  `swagger.py` (dev tool, unwired), Netlify CORS vestige (`config/__init__.py:194-209`).

## 3. FINISH (filed as MTs)

| MT | Item | Size / gate |
|---|---|---|
| MT-350 | **IAP receipt verification** (STORE-1 Ph.2): `_verify_with_apple/_google` raise `NotImplementedError`; S2S handlers never persist (`IapNotificationEvent` has zero writers); client already calls `/api/iap/*/verify` (503 today, crash if flag flipped). Needs store product IDs + credentials. | Large; **app-store launch blocker**; blocked on store accounts / launch unpause |
| MT-351 | Wire client onboarding to `PATCH /api/user/<id>/age` — endpoint has zero callers; stated precondition for the `ENFORCE_RESOLVED_AGE` flip (MT-310). | Small |
| MT-352 | Consent-withdrawal path — `ConsentRecord.withdrawn/withdrawn_at` have no write path and no endpoint; only full deletion exists. COPPA/GDPR Art. 7(3). | Medium; pre-launch compliance |
| MT-353 | Report-content UI for existing `POST /report-story` — no button anywhere in `lib/`. Store review + kidSAFE expectation. | Small |
| MT-354 | `subscription_management_screen.dart:445` upgrade button = "coming soon" SnackBar; `PremiumUpgradeScreen` exists and is wired elsewhere. | Tiny |
| MT-355 | Pick-a-Path resume: progress persisted every choice (`_persistProgress`), `getInProgressStories()` has zero callers, no reconnect sync. Build resume picker or delete write path. | Decision + small build |

Not re-filed (already tracked/moving): landing page + waitlist (MT-322 positioning decision),
i18n of crisis-line detection (`distress_detector.dart:18` TODO), Story Notes caregiver label
(TODO MT-254), SEL Real-Life Echo (in flight as PR #403), ~~PR #398 merge~~ (merged 2026-07-07).

## 4. KEEP — dormant-deliberate (verified intact; do not "clean up")
`ANTIHERO_CRUX_ENABLED` (server) + `FeatureFlags.cruxChoiceEnabled` (client — full UI built:
`magic_review_step.dart:980-1037`, `story_result_screen.dart:3479,5262`); COPPA enforcement flags
(`ENFORCE_RESOLVED_AGE`, `COPPA_REQUIRE_VERIFIED_CONSENT`, `COPPA_REQUIRE_CURRENT_POLICY_VERSION`);
Family tier hidden (`subscription_models.dart:393-403`); dormant story providers
(claude/tiered/openrouter/auto/gemini-legacy in `story_tasks.py:185-535` — `tiered` is the
premium-differentiation candidate, see MT-358); Gemini kill-switches (`DISABLE_GEMINI_IMAGE`,
`ALLOW_DIRECT_GEMINI_IMAGE`); Gemini TTS 18+-only fallback; they/them pronoun fallback plumbing;
Boy/Girl picker; 2nd-person Pick-a-Path under-15; `/dev/loading-preview`; Netlify CORS vestige
(until wave 2). Parked-by-decision backlog stays parked: referral program (owner: zero value
pre-launch), guided meditation v2 spec, SMS/Stripe age verification (v1.1), Pop-Up Picture Book
(MT-199, pending signal), MT-200 reader polish, per-band delights (MT-289), boundary-skills
Phases 2-5 (MT-232 — **note: Phase 1 was orphaned with Cluster C, see §1**), MT-294 Creator
secrets (clinically gated), Isar at-rest encryption (deliberate defer), Hero Saga Phase 3 (MT-235).

## 5. OWNER DECISIONS (filed as MTs)
- **MT-357** — `WizardData.parentHiddenContext`: serialized end-to-end but `WizardDataMapper`
  never sets it (always null at the live call site); real flow went server-side via
  `child_profile_id`. Delete client plumbing or wire the mapper.
- **MT-358** — **BYOK direction.** Original rationale (API cost) is gone post-Gemini/ElevenLabs
  migration. "Pro users get better output" is better served by the already-built dormant `tiered`
  provider (premium → Claude) than by user key custody. Decide: sunset/hide BYOK at launch (like
  Family) vs keep. Wave-2 deletion of server-side key-custody routes depends on this.
- **Cluster C salvage** (part of MT-356) — mine the orphaned therapeutic library for Life Quests
  content before deleting, or delete outright.
- **MT-283** (pre-existing) — Adult band intent: "author for a child" vs self-use; UI is
  contradictory (~70% built for authoring, labeled "Your Hero").

## 6. Verified NOT unfinished (don't re-audit)
PDF export (#399), weekly parent recap (#401), gift subscriptions (#400, Stripe setup = MT-344),
funnel surfaces (#397), pricing chunk 1 (#395) + chunks 2-3 (#398, merged), Story Notes (#279),
boundary-skills Phase 1 (#253), Hero Saga Ph.1-2 (#252/#257), Sprout mad/sad/scared quests,
therapist portal removal (zero residue), ElevenLabs transcribe/child-STT removal (zero residue),
`backend-deploy.yml` deletion (confirmed gone), saga "Phase 2" markers (fully wired, live).
