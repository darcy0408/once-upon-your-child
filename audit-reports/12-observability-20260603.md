# Observability Audit — Telemetry Coverage Gap Analysis

Date: 2026-06-03
Scope: Story Weaver client (Flutter), API (Flask/gunicorn), Celery worker + beat,
Sentry, structured logs, business/revenue events, alerting.
Method: Static audit from code and configuration only. No production telemetry
was collected. Precision limitation: where a signal depends on a Sentry UI alert
rule or a Railway environment variable not visible in the repo, the finding is
scored on the worst plausible case and marked for verification.

## Executive Summary

Story Weaver's observability is strongest exactly where it was hand-built and
weakest everywhere it was assumed. The client Sentry posture is genuinely good:
no session replay, no screenshots, no `setUser`, `sendDefaultPii=false`, and
aggressive `beforeBreadcrumb` scrubbing, all hard-gated behind parental consent.
The backend `before_send` scrubber is equally disciplined. The reliability
audit's silent-failure recommendations were partly implemented — queue-depth,
retention-heartbeat, and static-fallback signals now exist.

But the signals that matter for a solo founder to answer "what is happening in
production right now" are largely absent, fabricated, or self-defeating:

1. The reliability alerts meant to catch silent failures are themselves at risk
   of being silent. The Celery worker and beat have no `CeleryIntegration`; the
   monitoring task's `capture_message` calls only emit if some prior task booted
   the Flask app on that process. The alarms for the highest-RPN failures can
   no-op.
2. The founder dashboard reports fabricated numbers: error count, failure rate,
   and average generation time are hardcoded constants in `analytics_routes.py`.
   This is worse than no dashboard — it manufactures false confidence.
3. Three Critical failure paths have no alert at all: Stripe webhook failure
   (log-only), Postgres backup failure (no notification — this is the gap that
   ran silent for five days, fixed in PR #207), and AI cost runaway (the budget
   alert is dead code: `track_cost` is never called and its store is in-memory).
4. The business funnel is uninstrumented end to end. Checkout-started is never
   recorded, the webhook overwrites subscription state instead of journaling it,
   wizard events are Firebase-only and disabled on web, and story failures are
   never logged. Conversion and churn are uncomputable.

One Critical PII leak: the Celery task logs the full assembled prompt at INFO
before the real-name scrub runs, so a child's real name can reach the log
stream.

The "10-minute test" passes for at most 1 of 10 common production questions.
The instrumentation backlog below is ordered by questions-answered-per-engineering-hour;
the top four are all small-effort and unblock most of the rest.

### Top 10 Instrumentation Recommendations

| # | Recommendation | Answers | Effort |
|---|---|---|---|
| 1 | Add `CeleryIntegration` + an explicit `sentry_sdk.init` on the worker/beat process, and a startup assertion that `SENTRY_DSN` is set in production | Makes every backend error and reliability alert actually fire | S |
| 2 | Add a failure-notification step to `postgres-backup.yml` and a backup-age heartbeat alert | "Did last night's backup succeed?" | S |
| 3 | Alert on Stripe webhook failure (Sentry/Slack, not log-only) | "Are payments processing?" | S |
| 4 | Wire release tracking (`RAILWAY_GIT_COMMIT_SHA` to Sentry `release`) on client and backend | "Which deploy caused this?" | S |
| 5 | Re-enable the `health-monitoring.yml` cron with the correct Cloudflare URL | "Is the app up?" (proactive) | S |
| 6 | Emit a `story_generation_failed` audit event on both sync and async paths | "What is my failure rate?" | S |
| 7 | Replace hardcoded `analytics_routes.py` numbers with real queries, or remove the page | Kills false confidence | S |
| 8 | Aggregate the durable `api_cost_incurred` rows and add a daily-spend alert | "Am I within AI budget?" | M |
| 9 | Add `wizard_started` + `checkout_started` events to the existing `AuditLog` sink; compute conversion from them | Funnel + conversion rate | M |
| 10 | Switch backend logging to a JSON formatter and propagate `request_id` + `user_id` into Celery | Queryable, correlatable logs | M |

## Current Inventory

| Signal | Where | State |
|---|---|---|
| Client error monitoring | `lib/main.dart:20`, `sentry_flutter` | Live in release (20% sample); consent-gated; no replay/screenshots |
| Backend error monitoring | `backend/app.py:206`, `FlaskIntegration` only | Live if `SENTRY_DSN` set; strong `before_send` scrubber |
| Worker error monitoring | lazy via `get_flask_app()` | No `CeleryIntegration`; beat/monitoring tasks may run uninitialized |
| Distributed tracing | `FlaskIntegration` auto-transactions, `traces_sample_rate=0.1` prod | Not propagated to Celery; client to worker is not one trace |
| Backend logs | `logging.basicConfig`, plain text, root WARNING | Not JSON; `request_id` exists but not propagated to worker |
| Reliability signals | `backend/tasks/monitoring_tasks.py`, `story_tasks.py:1415` | queue depth, retention heartbeat, static fallback to Sentry warning |
| Compliance event sink | `AuditLog` (`backend/models/audit_log.py`) | Real server-side append-only log; fixed event vocabulary |
| Business/funnel analytics | `lib/services/*_analytics.dart` (Firebase) | Disabled on web; off until consent + age >= 13; no server sink |
| Revenue events | `StripeWebhookEvent` (dedup), `User` columns | Dedup bookkeeping only; no started events, no transition journal |
| Cost telemetry | `cost_tracking.py` (in-memory) + `cost_tracker.py` (DB) | Two disconnected systems; durable rows never aggregated |
| Admin dashboard | `analytics_routes.py` (API only) | Partly hardcoded placeholder numbers; not a page |
| Alerting | GitHub Actions Slack steps, Sentry UI rules | Health cron disabled; several Critical paths unalerted |
| Health checks | `health_routes.py` `/health` (DB probe), `/health/detailed` (admin) | Shallow public probe; deep probe not externally reachable |

## Journey Coverage

| Journey | Server signal | Client signal | 10-min answerable? |
|---|---|---|---|
| Signup / anonymous-auth | `audit_log("anonymous_session")`, `user_login`, `token_refreshed` | none useful | Partial |
| COPPA consent | `ConsentRecord` persisted (rich); consent-requested/verified events | consent gate flips analytics | Yes (compliance), No (funnel) |
| Wizard start / completion | none | Firebase only, no-op on web | No |
| Story generation success | `story_generated` (sync route only) | Firebase only | Partial |
| Story generation failure | none (the code comment claiming otherwise is wrong) | none | No |
| Payment / checkout / subscription | end-state on `User`; webhook dedup rows | Firebase `subscription_started` only | No (no started event) |
| Return visit / retention | `User.last_active_at`; "story created in window" proxy | none | Weak proxy only |

## Failure-Mode Coverage

Mapped against the reliability FMEA (`audit-reports/08-reliability-20260522.md`).
The FMEA's central thesis — "alerting is built for crashes, not for silent
degradation" — is partly addressed; the remaining gaps are below.

| FMEA ID | Failure mode | Telemetry signal today | Gap |
|---|---|---|---|
| W1 | Worker loses in-flight task on restart | queue-depth alert (partial proxy) | No stuck-`PENDING` detection; signal may no-op (OBS-02) |
| R2 | Finished story content expires after 1h | none | No result-not-found alert |
| SE1 | Silent failures raise no exception | partly fixed (3 reliability signals) | Signals depend on worker Sentry init (OBS-02) |
| B2 | Daily COPPA purge silently stops | heartbeat staleness alert (>36h) | Circular: beat must run to fire its own staleness alert |
| G1/G2 | All-providers-down static fallback | `static_fallback` Sentry signal | Live, but same worker-init caveat |
| R1 | Redis eviction drops queued tasks | none | No `evicted_keys` alarm |
| A5 | Bad deploy passes shallow healthcheck | `/health` now runs a DB probe | No Redis/worker/provider probe; no post-deploy smoke |
| S2/S6 | Stripe webhook secret rotation / outage | log-only | No alert (OBS-06) |
| (new) | Postgres backup job fails | none (until PR #207) | No failure notification (OBS-07) |
| (new) | AI cost runaway (A3 double-spend) | none | Budget alert is dead code (OBS-05) |
| (new) | Full outage / API down | none running | Health-monitoring cron disabled (OBS-08) |

## Alert Quality

### Inventory and signal-to-noise

| Alert | Trigger | Channel | Quality |
|---|---|---|---|
| Health-check failure | 4 curl checks fail | Slack | Schedule DISABLED — never fires; brittle string match on "Adventure" |
| Rollback notice | manual rollback runs | Slack | Manual-trigger only; informational |
| Celery queue depth high | depth >= 20 | Sentry warning | Live; actionable; at risk of no-op (OBS-02) |
| Retention heartbeat stale | age > 36h | Sentry warning | Live; circular dependency on beat |
| Static fallback | both providers down | Sentry warning | Live; functionally Critical but tagged only `warning` |
| Budget overspend | daily >$10 / weekly >$50 | Slack | DEAD — `track_cost` never called, store in-memory |

### Alert fatigue

At current pre-scale traffic, the live alerts are low-volume and not noisy — the
problem is the inverse of fatigue: too few real signals, and the loudest path
(health monitoring) is switched off. No alert fires on expected/transient
conditions today. The post-deploy "no heartbeat yet" case is correctly
suppressed to log-only — good hygiene.

### Ownership

The solo founder owns every alert. All Slack alerts share one webhook with no
severity routing; all Sentry signals emit at `level="warning"` with no P1/P2
distinction, including the functionally-Critical all-providers-down case. There
is no triage rubric in the repo. Recommended minimal rubric: P1 = payment,
data-loss, full outage (page immediately); P2 = degraded generation, cost
breach (review same day); P3 = everything else (weekly digest). Tag Sentry
signals with this severity rather than a flat `warning`.

### 10-minute test

| Production question | Answerable in 10 min today? | Why |
|---|---|---|
| Is the app up right now? | No | No running external monitor (cron disabled) |
| Are stories silently falling back? | Conditional | Signal exists but may no-op (OBS-02) |
| What is my generation failure rate today? | No | No failure event; dashboard hardcodes 2.0% |
| Wizard starts that didn't finish a story? | No | No funnel events reach a server |
| What was my conversion rate this week? | No | Checkout-started never recorded |
| Am I within AI budget today? | No | Budget alert dead; durable cost rows unaggregated |
| Did last night's DB backup succeed? | No | No alert; manual Actions check (ran silent 5 days) |
| Which deploy introduced this error? | No | No release tracking |
| What happened to user X's stuck story? | No | No request_id to worker correlation; result expires |
| Are payments processing? | No | Webhook failures are log-only |

Passing: at most 1 of 10. The audit success bar (5 of 10) is not met; recommendations 1-6 raise it to roughly 7 of 10 at small effort.

## Findings

| ID | Title | Gap Type | Severity | Component | Description | Remediation | Effort |
|---|---|---|---|---|---|---|---|
| OBS-01 | Sentry silently skips init when `SENTRY_DSN` unset | False confidence | Critical | Backend | `app.py:201` gates init on the env var; `.env.example` ships it commented out; no startup assertion forces it. If unset in Railway, all backend error telemetry is silently absent. | Add `SENTRY_DSN` to the production startup assertions in `_run_security_assertions`; fail loud if missing in prod. | S |
| OBS-02 | Worker/beat run with uninitialized Sentry; reliability alerts can no-op | Coverage | Critical | Worker | No `CeleryIntegration`; Sentry only inits lazily if a task calls `get_flask_app()`. `monitoring_tasks` and `celery-beat` can `capture_message` on a process where init never ran; the exception is swallowed. The silent-failure alarms are themselves silent. | Call `sentry_sdk.init` with `CeleryIntegration` at worker boot in `celery_config.py`; verify with a forced test event. | S |
| OBS-03 | Full prompt logged at INFO before the real-name scrub | PII leakage | Critical | Worker | `story_tasks.py:1091` `logger.info(f"Full prompt ...: {prompt}")` runs before `_scrub_real_name` at :1134; the prompt is built from character/feelings/recall data and can contain the child's real name. | Remove the line, or move it after the scrub and drop to DEBUG behind an explicit flag. | S |
| OBS-04 | Founder dashboard reports fabricated numbers | False confidence | Critical | Backend | `analytics_routes.py` returns hardcoded constants: error count `0` (:45), avg gen time `15.5` (:52), failure rate fixed at `2.0%` (:88), plus estimated feature usage (:99-138). | Replace with real queries against `AuditLog`/`Story`, or delete the misleading fields. | S |
| OBS-05 | AI cost/budget alert is dead code | Coverage | Critical | Backend | `track_cost` is injected but never called (zero call sites); `_cost_events` is an in-memory list wiped on restart. Cost runaway (FMEA A3 double-spend, O1 per-image) fires no alert. | Call `track_cost` on each AI/image/TTS call, or aggregate the durable `api_cost_incurred` rows; add a daily-spend threshold alert. | M |
| OBS-06 | Stripe webhook failure is log-only | Coverage | Critical | Backend | `webhook_handler.py:98,116,265` only `logger.error` on missing secret / processing failure. Silent payment and subscription-state desync. | Route webhook failures to Sentry `capture_exception` + a Slack alert; alert on signature/secret failures specifically. | S |
| OBS-07 | Postgres backup failure has no alert | Coverage | Critical | CI/CD | `postgres-backup.yml` has no `if: failure()` notification. The job failed silently for five days (fixed in PR #207); detection still relies on manually reading the Actions list. | Add a Slack failure step to the workflow and a backup-age heartbeat alert (alarm if newest R2 object > 36h old). | S |
| OBS-08 | No running external uptime/health monitor | Coverage | Critical | CI/CD | `health-monitoring.yml` cron is commented out (lines 3-8); only `workflow_dispatch` remains. A full outage is invisible until a user reports it. | Re-enable the schedule with the correct Cloudflare Pages URL and `BACKEND_URL`; replace the brittle "Adventure" string match with a status-field check. | S |
| OBS-09 | No release tracking on client or backend | Context | High | Both | Neither `sentry_sdk.init` nor `SentryFlutter.init` sets `release`. No deploy-to-regression attribution, no suspect-commit data. | Set `release` from `RAILWAY_GIT_COMMIT_SHA` (backend) and the build's version+commit (client). | S |
| OBS-10 | `request_id` not propagated into Celery | Context | High | Backend | The 8-char `g.request_id` (`app_helpers.py:191`) lives only in the request scope; worker logs carry `character_id` but no request_id/user_id, so a generation failure cannot be tied to its originating request or user. | Pass `request_id` and `user_id` into the task signature; bind them to the task logger and Sentry scope. | M |
| OBS-11 | Logs are plain-text, not JSON | Format | High | Backend | `basicConfig` uses a human-readable format; a duplicate `basicConfig` keeps root at WARNING. Logs are not machine-queryable or aggregatable across services. | Adopt a single JSON formatter module shared by app + worker; include `request_id`, `user_id`, `level`, `logger`. | M |
| OBS-12 | No funnel / conversion telemetry | Coverage | High | Both | Checkout-started never recorded (`stripe_routes.py:61`); webhook overwrites `User` state with no transition journal; wizard events are Firebase-only and disabled on web. Conversion and churn uncomputable. | Emit `wizard_started`, `wizard_completed`, `checkout_started`, `subscription_changed` to `AuditLog`; derive funnel from them. | M |
| OBS-13 | No story-generation failure event | Coverage | High | Backend | Only `story_generated` (success, sync route) is logged; the async task logs no outcome. `story_tasks.py:312`'s comment claiming failures are audited is inaccurate. | Emit `story_generation_failed` with reason/provider on both paths; count outcomes. | S |
| OBS-14 | Worker self-monitoring blind spot; beat liveness unmonitored | Coverage | High | Worker | `monitoring_tasks` runs on the same worker it monitors (documented at :13-15); a wedged worker also stops the monitor. Nothing confirms `celery-beat` is alive. | Move the liveness check to an external pinger (the re-enabled health cron) that asserts a fresh worker heartbeat key in Redis. | M |
| OBS-15 | Durable cost rows are written but never aggregated | Coverage | High | Backend | `cost_tracker.py:110` persists `api_cost_incurred` per call with `user_id`/`cost_usd`, but no code reads them; the dashboard reads the ephemeral in-memory system instead. | Add an aggregation query (per-day, per-user, per-provider) and surface it on the status page. | S |
| OBS-16 | Post-scrub prompt snippet and companion details logged | PII leakage | High | Worker | `story_tasks.py:1159` logs 500 chars of the (pseudonymized) prompt; `:1157-1158` log companion/pet free-text the child entered; `app_helpers.py:169` logs 200 chars of story body on content trips. | Drop these to DEBUG behind a flag; never log free-text fields at INFO. | S |
| OBS-17 | Client `debugPrint` logs child name/age to console | PII leakage | Medium | Client | `debugPrint` is not stripped from release web builds. Unguarded calls log child name/age, e.g. `avatar_creator_overlay.dart:527`, `character_creation_screen_enhanced.dart:356,729`, `models.dart:148,173`. Visible in browser devtools for any user including under-13. | Guard all child-data `debugPrint` behind `kDebugMode`, or route through `LoggerService` (already prod-safe). | M |
| OBS-18 | Worker environment mislabeled in Sentry | Context | Medium | Worker | The worker uses `FLASK_CONFIG` (default `"dev"`), a different var from the web service; if unset, worker errors land in Sentry tagged `environment=dev` at the dev sample rate. | Set `FLASK_CONFIG=production` on the worker service; align env resolution with the web app. | S |
| OBS-19 | No trace propagation client to worker | Coverage | Medium | Both | Tracing is on for the API but no `sentry-trace`/`traceparent` is forwarded into Celery, and there is no `CeleryIntegration`. A slow story generation is not one connected trace. | After OBS-02, propagate trace headers into the task and continue the trace in the worker. | M |
| OBS-20 | Under-13 sessions have zero error telemetry | Coverage | Medium | Client | Sentry is hard-gated off until consent + age >= 13, so most users (children) generate no crash data. This is the correct COPPA posture but leaves a real coverage blind spot. | Accept as a policy trade-off; compensate with anonymous, PII-free aggregate crash counts emitted server-side from error responses. | M |
| OBS-21 | No severity routing; flat `warning` level | Alert quality | Medium | Backend | All Sentry reliability signals emit at `warning`; all Slack alerts share one webhook. The all-providers-down case is functionally Critical but indistinguishable. | Introduce a P1/P2/P3 tag and route P1 to a paging channel. | S |
| OBS-22 | No log sampling | Cost | Low | Backend | Application logs run at 100%; only Sentry traces are sampled. Masked today only because root sits at WARNING. At scale, full-rate INFO (including per-generation bursts) raises log cost. | Add level/volume-based sampling for high-frequency INFO once volume grows. | S |
| OBS-23 | Shared hardcoded prod DSN across all flavors | Hygiene | Low | Client | `flavor_config.dart:60-105` falls back to one prod DSN for dev/staging/prod, so non-prod builds pollute the prod Sentry project (mitigated by `sampleRate=0` in dev). | Use a separate DSN/project per flavor, or require the `--dart-define` with no prod fallback. | S |
| OBS-24 | No unified founder health page | Coverage | Medium | Backend | Observability is scattered across Railway logs, Sentry, GitHub Actions, and Slack. The only aggregate views are individual admin API endpoints. | Build a single `/admin/status` page (see Dashboard Recommendation). | M |

## PII Leakage Audit

| Vector | Verdict |
|---|---|
| Backend `before_send` scrubber | Strong — filters story/prompt/parent keys, long strings, `Authorization`/`Cookie`/`X-API-Key` headers, query strings, and replaces `user` with `{id:[Filtered]}`. |
| Client breadcrumbs | Strong — `beforeBreadcrumb` drops `ui.input`, `user`, and `navigation` crumbs and rebuilds the rest keeping only category/type/level/timestamp. |
| Client replay/screenshots/view-hierarchy | Absent — none enabled. Correct for a children's app. |
| Client `setUser`/`sendDefaultPii` | Absent — no user identity attached. |
| Backend log stream | LEAK — `story_tasks.py:1091` logs the full pre-scrub prompt (OBS-03, Critical); `:1157-1159` and `app_helpers.py:169` log story/companion free-text (OBS-16, High). |
| Client console | LEAK — unguarded `debugPrint` of child name/age in release web (OBS-17, Medium). |
| Credentials | Clean — keys logged only as `bool(...)`; email addresses explicitly not logged; JWT claim keys logged, never values. |
| Payment data in breadcrumbs | Clean — no card/PCI data found in logs or breadcrumbs. |

No child user data may be sent to Sentry; the consent gate and scrubbers enforce
this on the wire. The residual leaks are to the log stream and browser console,
not to Sentry.

## Sampling-Strategy Audit

| Signal | Rate | Assessment |
|---|---|---|
| Backend errors | 1.0 (all) | Appropriate at current scale. |
| Backend traces | 0.1 prod / 0.2 dev | Appropriate; keep at 0.1 to control cost as traffic grows. |
| Backend profiling | 0.0 | Off; fine. |
| Client errors | 0.2 prod / 0.0 dev | Reasonable; 0.2 may undersample rare crashes at low volume — consider 1.0 until traffic grows. |
| Client traces | 0.2 prod | Fine. |
| Session replay | not set | Correctly absent for a children's app — do not enable. |
| Application logs | 1.0 | No sampling (OBS-22); acceptable now, revisit at scale. |

No critical event is sampled out: reliability signals use `capture_message`
(not subject to `traces_sample_rate`), and errors are at full rate.

## Dashboard Recommendation

Build one admin-authenticated `/admin/status` page (the founder's single pane)
with 5-7 indicators, each backed by a real query, not a constant:

1. API + worker liveness (DB `SELECT 1`, Redis ping, worker heartbeat key age).
2. Story generation outcomes, last 24h (success / fallback / failed counts and
   rate) — requires OBS-13.
3. Static-fallback rate, last 24h (provider health proxy).
4. Celery queue depth and oldest pending task age.
5. AI spend today vs the daily budget — requires OBS-15.
6. Newest Postgres backup age (alarm if > 36h) — requires OBS-07.
7. Subscription funnel, last 7d (checkout-started, completed, conversion rate) —
   requires OBS-12.

This page plus the four small-effort alert fixes (OBS-06, OBS-07, OBS-08, and
the OBS-02 worker init) is what moves the 10-minute test from 1/10 to roughly
7/10.

## Recommendations

The instrumentation backlog, ordered by questions-answered-per-engineering-hour.
Effort: S < 2h, M ~half-day.

| Priority | Items | Action | Effort | QAPEH |
|---|---|---|---|---|
| 1 | OBS-01, OBS-02 | Initialize Sentry on the worker with `CeleryIntegration`; assert `SENTRY_DSN` in prod. Without this, every other backend signal is unreliable. | S | Highest |
| 2 | OBS-03, OBS-16, OBS-17 | Stop logging child PII: remove the pre-scrub prompt log; demote snippets to DEBUG; guard client `debugPrint`. | S | High (risk) |
| 3 | OBS-07, OBS-06, OBS-08 | Add failure alerts for backup, Stripe webhook, and re-enable the uptime cron. | S | High |
| 4 | OBS-09 | Wire release tracking on both client and backend. | S | High |
| 5 | OBS-13, OBS-04 | Emit story-failure events; replace fabricated dashboard numbers with real queries. | S | High |
| 6 | OBS-15, OBS-05 | Aggregate durable cost rows; add a daily-spend alert. | M | Medium |
| 7 | OBS-11, OBS-10 | JSON logging + `request_id`/`user_id` propagation into Celery. | M | Medium |
| 8 | OBS-12 | Funnel events (`wizard_started`, `checkout_started`) into `AuditLog`; compute conversion. | M | Medium |
| 9 | OBS-24 | Build the `/admin/status` founder health page. | M | Medium |
| 10 | OBS-21, OBS-18, OBS-23 | Severity routing; fix worker env label; per-flavor DSN. | S | Low |

### FinOps note

Most recommendations are cost-neutral: release tracking, failure alerts,
re-enabling a GitHub cron, JSON logging, and writing event rows to the existing
Postgres `AuditLog` add negligible spend at current scale. Two carry cost
signals to watch: (a) do not raise `traces_sample_rate` or enable session replay
(replay is also disallowed for a children's app); (b) full-rate logging
(OBS-22) should gain sampling before traffic grows, or log egress cost will
scale linearly. The durable `api_cost_incurred` rows already exist, so OBS-15 is
a read-only aggregation with no new write cost.
