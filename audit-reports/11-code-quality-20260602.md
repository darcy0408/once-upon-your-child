# Code Quality & Maintainability Audit — Story Weaver

**Date:** 2026-06-02
**Commit:** `83814abf` (branch `session/audit`, cut from `origin/main`)
**Auditor:** Claude (staff-engineer review harness)
**Scope:** Static analysis, test coverage, complexity, dependency hygiene, documentation.
**Method:** Tooling executed locally on Windows (Flutter `C:\src\flutter`, Python 3.13). All
findings reproduce from the commands in `lint-summary.txt`. No source was modified.

---

## Executive Summary

The codebase is **healthier than its size suggests**. Both test suites pass (646 backend,
373 Flutter unit). Under the project's own enforced lint policy, the Python backend is
flake8/isort/black **clean** and the Dart core analyzer reports **one** trivial info. The
"zero-warning" claim in `PROJECT_STATUS.md` holds for the gates that actually run.

The real debt is concentrated in five places, none of them style:

1. **Security supply-chain:** `pyjwt 2.12.1` carries **four** CVEs (fixed in 2.13.0). This is
   the JWT layer for an app handling children's accounts — it is the single highest
   friction-per-hour fix in this report (~30 min).
2. **A dead quality gate:** the WCAG a11y `custom_lint` plugin **fails to start** and has
   almost certainly been silently non-functional. For an app whose Phase 6 included a WCAG
   2.2 AA audit, the lint that defends that work does not run.
3. **A frozen dev toolchain:** an `analyzer 6.3.0` override (forced by `isar_generator 3.1.0`
   + `custom_lint 0.6.x`) pins the entire build/codegen/lint stack years back, drags in three
   **discontinued** packages, and is the root cause of #2. Everything else upgrade-related is
   blocked behind this one knot.
4. **Coverage holes on money & compliance paths:** `iap_routes.py` 25%, `user_routes.py` 23%
   (contains COPPA "Delete All My Data"), `api_key_routes.py` 51% (BYOK), `ai_quota.py` 44%
   (cost circuit-breaker). Backend total is a respectable 58%, but it is thin exactly where a
   regression costs money or violates a child-data promise.
5. **God-files:** `story_result_screen.dart` (5,045 LOC) and `story_routes.py` (2,297 LOC /
   30% covered) are the bus-factor and merge-conflict epicenter — directly relevant given the
   documented multi-session merge pain.

`mypy` reports 308 type errors but is **advisory only** in CI (`|| true`); it is a latent-bug
map, not a gate. The raw "720 flake8 findings" number is a non-issue — all 720 are codes the
team deliberately `extend-ignore`s in `backend/.flake8`, and CI is green.

Net: this is a one-developer codebase that has kept its gates green while accumulating
**toolchain and coverage** debt rather than **style** debt. Pay items 1–4 below first; they
are cheap relative to the risk they retire.

---

## 1. Lint Summary

| Tool | Mode | Result | Gated in CI? |
|------|------|--------|--------------|
| `flutter analyze` | core | 1 info (`unnecessary_import`) | Yes (errors only) |
| `dart run custom_lint` (a11y) | plugin | **FAILS TO START** | Supposed to; effectively no |
| `flake8` | enforced (`.flake8`) | **0** | Yes — green |
| `flake8` | raw (no config) | 720 (all extend-ignored codes) | n/a |
| `black --check` | project config | **0** | Yes — green |
| `isort --check` | project config | **0** | Yes — green |
| `mypy` | `--ignore-missing-imports` | 308 errors / 60 files | **No** (`\|\| true`) |

Full breakdown in `lint-summary.txt`. The single Dart info is autofixable with
`dart fix --apply`.

---

## 2. Coverage Report

**Backend — pytest, 58% total** (17,875 statements, 7,533 missed). Critical-path modules:

| Module | Stmts | Cov | Note |
|--------|-------|-----|------|
| `models/consent_record.py` | 40 | 80% | COPPA records — OK |
| `services/story_service.py` | 715 | 76% | core engine — OK |
| `middleware/auth.py` | 150 | 69% | acceptable, tighten |
| `tasks/story_tasks.py` | 801 | 68% | Celery pipeline |
| `routes/stripe_routes.py` | 101 | 65% | web payments |
| `routes/api_key_routes.py` | 111 | **51%** | BYOK validation |
| `utils/ai_quota.py` | 344 | **44%** | cost circuit-breaker |
| `routes/story_routes.py` | 1,044 | **30%** | largest route file |
| `routes/iap_routes.py` | 127 | **25%** | Apple/Google billing |
| `routes/user_routes.py` | 287 | **23%** | **incl. COPPA data-deletion** |

0%-covered files are one-shot scripts / migrations / the `eval/` quality harness
(`migrate_*.py`, `generate_*.py`, `eval/*`) — acceptable; not runtime paths. The one runtime
module at 0% is `services/avatar_to_prompt_helper.py` (72 stmts).

**Frontend — flutter test, 20.4% of instrumented lines** (706/3,466), and only **36 of 325**
`lib/` files are instrumented by the `test/unit` subset. CI gates only `test/unit/services`.
Widget/golden tests exist outside this run, so true coverage is higher than 20% but is not
measured by any gate. No coverage signal exists for the screen layer where most LOC lives.

---

## 3. Complexity Hotspots

Thresholds: file >500 LOC, file dominated by one concern, dual-import tax.

**Dart `lib/` — 325 files, 125,468 LOC:**

| LOC | File | Kind |
|-----|------|------|
| 7,885 | `lib/data/life_quest_data.dart` | data table (acceptable, but consider splitting per-band) |
| **5,045** | `lib/story_result_screen.dart` | **screen — extract** |
| 3,497 | `lib/screens/wizard_steps/hero_creator_step.dart` | screen — extract |
| 2,881 | `lib/screens/wizard_steps/magic_review_step.dart` | screen — extract |
| 2,284 | `lib/services/api_service_manager.dart` | service god-object |
| 1,849 | `lib/main_story.dart` | entry + nav + subscription load |

**Python `backend/` — 128 non-test files, 33,594 LOC:**

| LOC | File |
|-----|------|
| **2,297** | `backend/routes/story_routes.py` (also 30% covered) |
| 1,863 | `backend/services/story_service.py` |
| 1,675 | `backend/tasks/story_tasks.py` (also 84 mypy errors) |
| 1,523 | `backend/services/avatar_generation_service.py` |
| 1,325 | `backend/services/interactive_adventure_prompt_builder.py` |

**Other signals:**
- **365** `print()` calls in non-test backend code — Railway prod logging goes through gunicorn
  stderr (see the known deploy-log gotcha); structured `logging` would make prod debuggable.
- **273** broad/`except Exception` handlers in non-test backend code — error-swallowing risk
  (bare `except:` was already migrated to `except Exception:`, but the breadth remains).
- **60** `try/except ImportError` dual-path import blocks — the documented "run from root or
  from `backend/`" tax; also the main source of the 62 mypy `no-redef` errors.
- **49** TODO/FIXME/HACK markers (31 Dart, 18 Python).
- **1** stray `print()` in `lib/` (Dart side is clean).

---

## 4. Dependency Audit

**Security (act now):** `pyjwt 2.12.1` → **4 CVEs** (PYSEC-2026-175/177/178/179), fix `2.13.0`.
Pulled via `flask-jwt-extended`. No other vulnerable packages in `requirements.txt`.

**Frozen Flutter toolchain (root debt):** `dependency_overrides: analyzer 6.3.0` (latest 13.0.0)
is the keystone. It is forced by `isar_generator 3.1.0` (stale `analyzer <6.0` cap) and
`custom_lint 0.6.x`. Consequences:
- `build_runner` stuck at 2.4.13 (latest 2.15 / build 4.x), `custom_lint` 0.6 (latest 0.8.1),
  `riverpod` 2.x (latest 3.x).
- **Discontinued** transitive packages now in the tree: `js`, `build_resolvers`,
  `build_runner_core`.
- Directly causes the broken a11y plugin (§Finding CQ-02).
- Exit path: migrate **Isar 3 → 4** (or replace Isar), which releases the analyzer cap and lets
  the whole stack move forward.

**Backend Dependabot:** 12 open PRs (#192–#203). The breaking ones (per project memory:
`stripe` v15, `redis` 8, `cryptography` 48, `google-genai` 2.x) need payment/Celery/TTS
smoke-tests; the rest (`flask-jwt-extended`, `sentry-sdk`, `click`, `requests`, the two GitHub
Actions bumps) are low-risk. **Note:** bumping `flask-jwt-extended` (#203) may not move `pyjwt`
itself — verify `pyjwt>=2.13.0` resolves after the bump, or pin it directly.

**License:** MIT project; no GPL/AGPL contamination observed in the dependency set.

---

## 5. Documentation Audit

**Strong:** the root `README.md` (458 lines) is genuinely good — architecture diagrams of both
trees, the age-constraint table, quick-start, testing, deployment, cost model. 789 files under
`docs/`. The session-history + `MANUAL_TASKS.md` system substitutes well for a CHANGELOG. An
onboarding contributor could plausibly ship a small PR within the 4-hour test **for the backend**.

**Gaps:**
- No `CONTRIBUTING.md`, no `backend/README.md`, no formal ADR directory. Architectural decisions
  live in pubspec comments, session files, and agent memory — fine for a solo dev, a real
  bus-factor risk for a successor.
- **Stale `README` deployment section:** still says "Railway + **Netlify**" and "can alternatively
  be deployed to **Netlify**" (lines ~360, 410, 437). Prod frontend moved to **Cloudflare Pages**
  (PR #169); Netlify is orphaned. `DEPLOYMENT_INSTRUCTIONS.md` is described as a "Netlify guide."
- **`README` documents a broken workflow:** `analysis_options.yaml` and the README present
  `dart run custom_lint` as the a11y lint path — which does not run (§CQ-02). Either fix the
  plugin or annotate it as known-broken so contributors don't trust a dead gate.
- No root `.env.example` (a `backend/.env.example` exists and is good).

---

## 6. Top 10 Technical Debt (ordered by friction-per-fix-hour)

| ID | Title | Cat | Sev | Location | Remediation | Effort | Friction/hr |
|----|-------|-----|-----|----------|-------------|--------|-------------|
| CQ-01 | `pyjwt` 4 CVEs | Supply-chain | **Critical** | `backend/requirements.txt` | Bump `pyjwt>=2.13.0`, re-run auth tests | ~0.5h | **Very high** |
| CQ-02 | a11y `custom_lint` gate dead | Tooling | **High** | `pubspec.yaml` overrides, `tools/a11y_lint` | Short-term: document as broken + run a11y checks manually. Real fix rides CQ-03 | 0.5h doc / rides CQ-03 | High |
| CQ-03 | Frozen analyzer/build toolchain | Maintainability | High | `dependency_overrides: analyzer 6.3.0` | Migrate Isar 3→4 (or drop Isar codegen), then lift the pin; unblocks build_runner/custom_lint/riverpod + 3 discontinued pkgs | 1–2d | High |
| CQ-04 | Payment/COPPA route coverage | Testing | High | `iap_routes.py` 25%, `user_routes.py` 23% | Add tests for IAP verify + `DELETE /user/<id>/data` happy & failure paths | 0.5–1d | High |
| CQ-05 | `story_routes.py` god-file, 30% cov | Maintainability | High | `backend/routes/story_routes.py` (2,297 LOC) | Split into sub-blueprints (generate / interactive / status); test as you carve | 1–2d | Medium-high |
| CQ-06 | `mypy` 308 errors (advisory) | Code quality | Medium | 60 files; `story_tasks.py` (84) | Type the Celery pipeline first; add `mypy` as a soft gate per-module, drop `\|\| true` once a module is clean | iterative | Medium |
| CQ-07 | 365 `print()` in backend | Observability | Medium | backend non-test `*.py` | Convert to module `logging`; Railway logs become structured/debuggable | 0.5–1d (mechanical) | Medium |
| CQ-08 | Dart screen god-files | Maintainability | Medium | `story_result_screen.dart` 5,045; `hero_creator_step.dart` 3,497 | Extract widgets/sections; cuts merge conflicts across parallel sessions | 1–2d each | Medium |
| CQ-09 | `lib/` root structure drift | Structure | Low | ~12 screens/data files in `lib/` root | Move into `lib/screens` / `lib/data`; fix imports. Improves navigability + onboarding | 0.5d | Low-med |
| CQ-10 | Doc staleness + missing scaffolding | Docs | Low | `README.md`, repo root | Fix Netlify→Cloudflare refs, flag custom_lint as broken, add `CONTRIBUTING.md` + `backend/README.md` | 0.5d | Low-med |

---

## Appendix — Tooling Notes & Precision Caveats

- **mypy / pip-audit** were not pre-installed; installed locally to run (`pip install mypy
  pip-audit`). `ruff` is not used by this project (CI uses flake8/black/isort) and was not run.
- **Frontend coverage** reflects the `test/unit` subset only; widget/golden suites were not
  executed, so 20.4% is a floor, not the true figure. No CI gate measures full frontend coverage.
- **flake8 720 vs 0:** the raw number ignores `backend/.flake8`; the enforced number is 0. This
  report treats the enforced policy as ground truth (it is what gates merges and what CI runs).
- **Duplication** was assessed by structural heuristics (dual-import blocks, repeated file/
  concern patterns), not a clone-detection tool; no automated near-duplicate scan was run.
- All commands reproduce against commit `83814abf`. Coverage scratch outputs are under the
  worktree (`_pytest_cov.txt`, `flutter_analyze_raw.txt`, etc.) and are gitignored.
