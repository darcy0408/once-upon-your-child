# Prompt-Craft Critique — prompt_service.py (2026-07-17)

Judge review of `backend/services/prompt_service.py` (superhero/saga per-band prompt builders) against four axes: emotional beats, band-voice differentiation, saga continuity, and residual rubric-leak surface (the PR #454 class). This is a critique + prioritized fix list only; no code was changed. Line numbers refer to `backend/services/prompt_service.py` at commit `e03fd44e` unless another file is named.

**Scope note (verified against the code, not assumed):**
- In production, `PromptService.build_story_prompt` is used **solely for the superhero theme** (`backend/tasks/story_tasks.py:1653`; confirmed by the comment at `story_service.py:815`). The standard non-superhero path is `AdvancedStoryEngine.generate_enhanced_prompt` in `story_service.py` — that path is the one PR #454 hardened. The generic tail of `build_story_prompt` (lines 276-368) + `_get_age_guidelines` (370-431) is live only for the eval harness (`backend/eval/generation.py:90`).
- Superhero-path output **does** flow through the #454 post-processing net: `story_tasks.py:941/1929/2396` parse via `_safe_extract_title_and_gem`, which applies `_strip_attempt_labels` → `_strip_meta_leakage` → `_strip_lesson_endings` (`story_service.py:2118-2121`). But `_META_LEAK_TERMS` (`story_service.py:156-191`) contains none of `prompt_service.py`'s own craft vocabulary, so the net cannot catch this file's leak class.
- The Adolescent (15-17) band is server-gated OFF pending clinical sign-off (`ANTIHERO_CRUX_ENABLED`, PR #402) — its fixes are pre-launch work for that band, but one of them is safety-adjacent (see Finding 2) and should land before the gate opens.
- No live-generation spot-check was run (optional per brief; the leak findings below are marked confirmed-by-#454-class vs. latent/suspected accordingly).

---

## Executive summary — the 3 highest-leverage fixes

1. **Saga nemesis continuity is structurally broken across all four saga bands (P0).** The server picks each Issue's villain with `recent_villains` *avoidance* (`story_tasks.py:1611-1616`), so a returning hero's "still-at-large" nemesis is deliberately NOT this Issue's villain — yet no rule requires the prior nemesis to be *named in prose* (the exact known weak spot), the Explorer recap actively asserts the old villain "is back" while the prompt pins a different one, and every band's `saga_state` output template hard-codes `"nemesis": "{villain['name']}"` — this Issue's new villain — so the arch-nemesis thread is overwritten every single Issue and "still-at-large" hooks can never pay off.

2. **The Adolescent interactive-crux path has silently drifted behind the single-shot builder (P0).** `_build_superhero_prompt_adolescent` does NOT consume the shared `_antihero_brief` — it re-implements ~200 lines inline and has since gained rules the crux path (which *does* use the brief) never got: the SECRET ON-PAGE mandate, the "engage THIS secret specifically" care clause, VILLAIN ON-PAGE, the NO-THEME-NAMING-in-final-beats ban, and per-page budgets. The comment at line 96-98 claims the builders "render an identical premise… by construction" — that claim is now false, and one missing clause is safety-adjacent.

3. **The #454 rubric-leak hardening never reached prompt_service.py (P1).** The standard path got renamed vocabulary, reworded operative sentences, and a SILENT SKELETON CHECK; the superhero builders still put copyable craft nouns in operative sentences ("refrain" ×4 and "wow words" in Explorer, "the real need" ×6 in Adventurer, "identity tag" in every young band, "Beat N — COLD OPEN"-style JSON placeholders in Creator/Adolescent) with no skeleton-check self-pass and no net coverage. Same class, latent, un-fixed here.

---

## Per-band findings

### Sprout (3-5) — `_build_superhero_prompt`, lines 547-699

**S-1. No emotional beat anywhere in the 6-beat chain (emotional-beats axis).**
The beats (lines 654-661) are a pure event sequence: intro → trouble → "I can help!" → power → soften → cheer. The only emotional demand in the whole prompt is the `emotional_arc` *metadata* field (line 684) — nothing asks for a feeling on the page. The generic path's EMOTIONAL HEART block (lines 325-340) and the `current_feeling`/EmotionService integration (306-310) are both skipped by the superhero short-circuit at line 172. Even at 100-130 words there is room for one body-feeling beat ("Mia's tummy went flip" at TROUBLE; "Mia felt warm and big" at CHEER).
*Fix:* add one line to HARD RULES: show ONE feeling in the body at the TROUBLE beat and ONE at the CHEER beat, using allowed simple words. Small, contained.

**S-2. Five of six beats are verbatim-mandated template text (differentiation-within-band).**
Beats 1, 2, 3, 5, 6 are exact sentences the model is ordered to copy ("Open with:", "Then:", "End the conflict like this:", "Close with:" — lines 656-661, built at 599-614). Two kids fighting the same villain get ~60% identical stories. The Explorer builder fixed exactly this ("SEEDS ARE PLOT IDEAS ONLY", audit 2026-07-07, line 958) but Sprout kept the rigid design. Ritual predictability is a stated feature at 3-5 (the "Once upon a time," opener genuinely is), but that argues for a fixed *opening*, not five fixed beats.
*Fix:* keep beat 1 verbatim (the ritual), convert beats 2/3/5/6 to Explorer-style "seed idea — rewrite in your own words" with the same vocabulary constraints. Weigh against the deliberate-rigidity note at 541-545 before executing.

**S-3. Pronoun rule references a gender that is never provided (latent contradiction).**
Line 670: "if {character}'s gender was told to you, use 'he' or 'she'…" — but the Sprout builder has no `hero_gender` parameter (signature 547-556), so the condition can never be true and the model always falls to name-repetition. Harmless today but misleading; and the fix (threading `hero_gender`, which `story_tasks.py:1687` already passes to `build_story_prompt`) is the same plumbing as E-3 below.

### Explorer (6-8) — `_build_superhero_prompt_explorer`, lines 722-1005

**E-1. Continuity block contradicts the villain pin AND the mandatory opener (saga axis; also the known nemesis-naming gap).**
- Line 885: `"still-at-large": "is back, up to something new"` — the recap asserts the prior nemesis IS in this story, while the VILLAIN section (933-937) pins a *different* villain ("the chosen villain is {villain['name']} and NO OTHER"), because `pick_pairing` is fed `recent_villains` to avoid repeats. The model must silently resolve a contradiction; the cheapest resolution is to drop the prior nemesis from prose entirely — which is exactly the observed failure (hook honored, nemesis unnamed).
- Lines 913-915: 'Start with a quick, friendly "Last time…" beat in the HERO INTRO' vs. the opening rule injected at line 952 (`_get_opening_rule`, `story_service.py:614`): "The story's very first words must be exactly '{opener},'". Two mandatory claims on the first sentence; behavior for returning heroes is unpredictable.
- No rule anywhere requires the prior nemesis's *name* to appear in prose (contrast: VILLAIN ON-PAGE and SECRET ON-PAGE rules exist in older bands).
*Fix:* (a) reword `_status_human["still-at-large"]` to "is still out there somewhere" (not "is back"); (b) add a NEMESIS MEMORY rule: when `prev_nemesis` differs from this Issue's villain, the prose must mention {prev_nemesis} by name at least once, consistent with their status (a wave across the park, a mentioned rumor, a thank-you); (c) order the two opening claims explicitly: exact opener phrase first, then the "Last time…" sentence(s).

**E-2. Leak surface: "refrain" and "wow words" are operative craft nouns (rubric-leak axis, latent).**
"Refrain" appears in operative sentences four times (946, 948, 949, 962), "wow words" twice (957). This is precisely the #454 mechanism (model transcribes rule nouns: "the first escalation", "his flaw—"); a story saying "and the refrain came back" or "a wow word like enormous" is the predicted failure. Neither term is in `_META_LEAK_TERMS`, and this builder has no final self-pass.
*Fix:* add a band-appropriate SILENT SKELETON CHECK (the pattern #454 proved: "re-read and rewrite any sentence containing 'refrain', 'wow word', 'seed', 'identity tag' used about the story itself") and add the same nouns to `_META_LEAK_TERMS` as a net.

**E-3. No pronoun rule at all (band-voice axis).**
The 2026-07-07 audit added the pronoun rule to Adventurer only (1133-1174). Explorer free-chooses; the same hero can flip he/she/they between Issues of one saga. `hero_gender` already arrives at `build_story_prompt` (`story_tasks.py:1687`) and is dropped for this band (noted at 1684-1686).
*Fix:* copy the Adventurer `pronoun_rule` block (1158-1174) into Explorer (and Creator/Adolescent — see C-3/A-4); thread the kwarg in `build_story_prompt`'s Explorer branch.

**E-4. Emotional interiority is thin.** Beat 3 (947) is framed as "cleverness or observation — a moment of noticing, not just kindness"; nothing asks for how the half-failure *feels*. One clause ("show in {character}'s body how the half-working try feels — a frown, a huff, a slower step — before the noticing") would give the 6-8 band a doubt→resolve micro-arc it currently lacks.

### Adventurer (9-12) — `_build_superhero_prompt_adventurer`, lines 1036-1375

The strongest band prompt: pronoun rule, ONE-BEAT MORAL RULE, PERSONAL STAKES, load-bearing-power rule, competing-feelings requirement (1327). Remaining issues:

**A-1. Nemesis continuity: same structural gap as Explorer (saga axis).**
The continuity block (1236-1286) recaps `prev_nemesis` in one bullet with no name-in-prose mandate, the `saga_state` template (1365) overwrites `nemesis` with this Issue's villain, and `recent_villains` avoidance guarantees the prior nemesis usually isn't the current one. "The thread left hanging" (1264-1267) is honored — that instruction is strong — but the *person* is not.
*Fix:* same NEMESIS MEMORY rule as E-1(b), tuned to this band's register.

**A-2. Leak surface: "the real need" is this band's "escalation" (rubric-leak axis, latent).**
"Real need"/"real need or motive" appears six times in operative text (1302, 1317, 1318, 1328, 1330, 1334). #454's round-2 lesson was that repeated rule nouns become headings the model transcribes ("The cost was named out loud" was an *Adventurer* standard-path leak). "Maya finally saw the real need beneath it" is borderline-idiomatic; "addressing the real need" in narration is not. No skeleton check here either.
*Fix:* in the SKELETON CHECK for this band, list "the real need", "motive", "perspective-taking"; vary the operative wording so no single phrase repeats six times (e.g., "what {villain} actually lacks", "what's driving them").

**A-3. `emotional_arc` example vocabulary is grown-up for the band** (1343: "'certain → humbled'") — minor, but "humbled" as a modeled register nudges the metadata (parent-facing) rather than harming prose. P2 polish only.

### Creator (13-14) — `_build_superhero_prompt_creator`, lines 1389-1644

**C-1. Creator and Adolescent-antihero share an identical 7-beat skeleton and near-identical register descriptors (band-voice axis).**
Creator beats (1594-1601): COLD OPEN / WRONGNESS / FIRST MOVE, REAL COST / DISSENT / TRUTH + CHOICE / RESOLUTION / AFTERMATH. Adolescent antihero beats (2452-2459): the same seven, near-verbatim. Register: Creator = "intelligent, grounded, a little noir" (1576); Adolescent = "grounded, atmospheric, morally grey — prestige YA / neo-noir" (2434). A 13-year-old's Issue and a 16-year-old's chapter differ only in the double-life premise bullets and reading level — the structural and tonal fingerprint blurs. The bands the product sells as distinct are adjacent-band clones at the skeleton level.
*Fix (P2, judgment call):* give Creator ONE structural differentiator the Adolescent band doesn't have — e.g., a named ally/team presence with real page-time (the DIALOGUE rule at 1608 already wants a talking cast; promote an ally to a required co-actor in one beat), and shift the register line from "a little noir" toward "sharp, hopeful, kinetic — mystery-forward" so hope vs. noir separates the bands.

**C-2. Saga `nemesis` overwrite (saga axis).** Same as A-1: `saga_state` template (1631-1632) hard-codes this Issue's villain into `nemesis`, clobbering a still-at-large arch-nemesis. Creator/Adolescent are the two bands where `superhero_validation.py` enforces the full continuity contract, so this band feels the loss most: the CONSEQUENCE CALLBACK (1562-1572) correctly forces `what_it_cost` to come due, but the *who* of the saga resets every Issue.
*Fix:* in the `saga_state` schema text, change `nemesis` to "the saga's arch-nemesis: keep {prev_nemesis} if they are still the defining threat, else {villain['name']}" (prompt-only), or persist an `arch_nemesis` separately (code). Plus the NEMESIS MEMORY prose rule as in E-1(b).

**C-3. No pronoun rule** (same as E-3; a 13-14 reader will notice a saga hero flipping pronouns between Issues faster than a 7-year-old will).

**C-4. Adult (18+) routing lands adults in a "Ages 13-14" template with age interpolated** (lines 223-243): the header renders "HERO SAGA — (Ages 13-14 — Creator band)… for a sophisticated 34-year-old reader" with grade 6-8 reading level. Documented as API-only reachable (UI-gated under-18), so P2: either suppress the band label + bump the reading-level line when `age >= 18`, or accept and comment it.

### Adolescent (15-17) — `_build_superhero_prompt_adolescent` (2120-2501), `_antihero_brief` (1652-1868), crux builders (1921-2108)

**AD-1. Single-shot vs. crux drift — the shared-brief architecture is bypassed by the single-shot builder (P0; partially safety-adjacent).**
`_antihero_brief` exists so "the two sites cannot drift" (52-54, 90-98) — but only the crux builders use it. The single-shot builder re-implements everything inline and has diverged in at least four places, all in the single-shot's favor:
- **SECRET ON-PAGE mandate** — single-shot `secret_bullet` (2210-2219) requires the child's typed secret to be spoken/thought on the page; the brief's `secret_bullet` (1728-1734) lacks it. A crux-path teen's disclosed secret can go unengaged.
- **"Engage THIS secret specifically" clause** — single-shot `secret_care_mandate` (2336-2347) forbids substituting the villain's scheme for the teen's disclosed struggle (an audit-found failure); the brief's version (1837-1846) lacks the clause. This is the safety-adjacent one: it exists because the being-seen beat was observed resolving to a *substitute* concern.
- **VILLAIN ON-PAGE rule** — single-shot (2467) and classic (2397) have it; `_antihero_hard_rules` (1904-1914, used by both crux phases) does not.
- **NO THEME-NAMING IN FINAL TWO BEATS + aphorism-dialogue ban + per-page budgets + length self-check** — single-shot (2461-2463, 2471-2472, 2500); crux hard rules have only the shorter generic tone ban (1914). The crux part 2 — which writes exactly those final beats (5-7) — is the path *most* exposed to theme-naming endings and has the *least* protection.
*Fix:* make the single-shot builder consume `_antihero_brief`/`_antihero_premise_block`/`_antihero_hard_rules` (deleting ~200 duplicated lines), and move the four missing rules into the shared blocks — with the theme-naming ban parameterized per phase (part 1 doesn't write beats 6-7; part 2 must carry it). Do this before `ANTIHERO_CRUX_ENABLED` opens.

**AD-2. Nemesis continuity** — same overwrite as C-2 (2491) and same missing name-in-prose rule (continuity block 2252-2316). The `callback_mandate` (2318-2328) is excellent for *costs*; nothing equivalent exists for the *person*.

**AD-3. Length spec is self-contradictory (P2).** "LENGTH: 1400-1900 words — this is a HARD MAXIMUM, not a target" (2462, 2392) — a range cannot be a maximum; and per-page floors (180×7 = 1260) permit outputs under the 1400 floor while `superhero_validation.py` allows up to 2200. Harmless-ish, but confused constraints degrade compliance with the ones that matter.
*Fix:* "TARGET 1400-1900; HARD MAXIMUM 1900" and align page floors (200×7) or relax the stated floor.

**AD-4. Leak surface** — smallest of the bands (the tone bans are already #454-grade). Residual: JSON page placeholders "Beat 1 — COLD OPEN…" (2481-2487, 1988-1991, 2092-2094) hand the model beat labels in the very slot it fills; #454 showed placeholder/heading text is the likeliest copy source. "End on the held breath before the decision" (1975, 2000) risks a literal held-breath closing line in every part-1 (sameness, not leakage). *Fix:* reword placeholders to `"(write the cold-open beat here — no labels, no scene numbers)"` form across all bands' OUTPUT FORMAT blocks; vary the part-1 closing instruction.

### Adult (18+) and the generic path

**G-1. No adult band exists in this file** — 18+ superhero routes to Creator (see C-4). The standard non-superhero adult prompt lives in `story_service.py` and is out of scope here except to note the routing.

**G-2. Generic `_get_age_guidelines` has a length inversion and stale band boundaries (eval-only surface today).**
Lines 406-431: ages 9-12 get 900-1800 words; ages 13-15 get a *400-600 word cap*; 16+ get 600-800. A 13-year-old's story is capped at a third of a 10-year-old's. Boundaries (≤15 / 16+) also mismatch the product bands (Creator 12-14 / Adolescent 15-17), and this path specifies no POV at all (the deliberate 2nd-person-under-15 rule lives only in the standard path). Since `build_story_prompt`'s generic tail is live only for `backend/eval/generation.py`, the practical harm is that the *eval harness judges against wrong-length, POV-less prompts* — which quietly distorts any before/after comparison run through it. Fix the caps and add the POV rules, or point the eval harness at the standard-path builder.

---

## Rubric-leak verdict (axis 4, direct answer)

**Closed** on the standard path (`story_service.py`): #454's reworded band rules + SILENT SKELETON CHECK + `_strip_attempt_labels`/extended `_META_LEAK_TERMS` verified 0 leaks in 5 of 6 bands (2 borderline idioms, Adolescent).
**Latent** in `prompt_service.py`: none of the prompt-side hardening was applied here. The post-processing net does run on superhero output (via `_safe_extract_title_and_gem`) but its term list shares no vocabulary with this file's craft nouns ("refrain", "wow words", "identity tag", "seed idea", "the real need", beat labels in JSON placeholders). Risk ranking: Explorer > Adventurer > Sprout ≈ Creator > Adolescent (whose tone bans are already strong). No live repro was run; classification is by identity with the #454 mechanism (operative rule nouns + copyable placeholder headings).

---

## Prioritized fix list

| Pri | Band(s) | Fix (one line) | Est. effort |
|---|---|---|---|
| P0 | Explorer/Adventurer/Creator/Adolescent | Nemesis continuity: add NEMESIS MEMORY name-in-prose rule when prior nemesis ≠ this Issue's villain; stop `saga_state.nemesis` overwriting the arch-nemesis; fix Explorer "is back" status wording | M (4 builders, prompt-only + one schema-text change) |
| P0 | Adolescent | De-drift crux path: single-shot consumes `_antihero_brief`; port SECRET ON-PAGE, engage-THIS-secret clause, VILLAIN ON-PAGE, theme-naming ban into shared blocks (before antihero gate opens) | M (refactor + rule moves; tests exist in `test_antihero_crux.py`) |
| P1 | Explorer/Adventurer/Creator/Adolescent | Port #454 hardening: band-specific SILENT SKELETON CHECK; de-repeat "refrain"/"wow words"/"the real need" in operative sentences; extend `_META_LEAK_TERMS` with this file's nouns | S-M |
| P1 | All bands' OUTPUT FORMAT | Reword JSON page placeholders from "Beat N — COLD OPEN." to "(write the … beat here — no labels)" — placeholders are the likeliest transcription source | S |
| P1 | Explorer | Resolve mandatory-opener vs. "Last time…" first-sentence collision (order them explicitly) | S |
| P1 | Explorer, Creator, Adolescent | Thread `hero_gender` + copy Adventurer's pronoun rule (kwarg already reaches `build_story_prompt`); fix Sprout's dead "if gender was told" clause | M (plumbing + 3 builders) |
| P1 | Sprout, Explorer | Emotional micro-beats: one body-feeling at Sprout TROUBLE + CHEER; one felt-doubt clause in Explorer beat 3 | S |
| P2 | Creator | Differentiate Creator from Adolescent: one structural differentiator (required ally co-actor) + register shift off "noir" toward hopeful/kinetic | M |
| P2 | Sprout | Loosen verbatim beats 2/3/5/6 to Explorer-style seeds (keep the ritual opener); reduces same-villain story sameness | S-M (weigh deliberate-rigidity rationale first) |
| P2 | Adolescent | Fix contradictory length spec ("range = hard maximum"); align page floors with the 1400 floor and validation's 2200 ceiling | S |
| P2 | Adult / generic path | Fix `_get_age_guidelines` 13-15 length inversion (600 cap vs. 9-12's 1800) + add POV rules, or repoint the eval harness at the standard-path builder; suppress "Ages 13-14" header for 18+ superhero routing | S |
| P2 | Adventurer | Vary "the real need" phrasing (6 operative repetitions) and soften `emotional_arc` example vocabulary | S |

**Suggested validation for the follow-up session:** run the existing six-band before/after harness (OpenRouter recipe in project memory) only for the P0/P1 prompt edits, with a returning-saga fixture (prior_saga carrying a nemesis different from the picked villain) — that fixture is the one no prior baseline exercised, and it is where fix #1 either proves out or doesn't.
