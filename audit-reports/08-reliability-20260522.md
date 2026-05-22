# Reliability Audit — Failure Mode and Effects Analysis

Date: 2026-05-22
Scope: Story Weaver backend (Flask API, Celery worker/beat), Redis, Postgres,
Stripe, Gemini, OpenRouter, Sentry, Railway.
Method: Static FMEA from code and configuration. No production failures were
triggered. Railway service inventory verified read-only via `get-status`.

## Executive Summary

Story Weaver's reliability posture is mixed: the parts that were explicitly
hardened are strong, and the parts that were never designed are silently
fragile. The Stripe webhook handler is the standout — signature verification,
`event.id` dedup with a unique-constraint backstop, an out-of-order cursor, and
fail-closed tier resolution make double-delivery genuinely safe. The quota
subsystem's split failure modes (availability limits fail open, cost breakers
fail closed) are textbook.

The weaknesses cluster around asynchronous story generation and data
durability — the two surfaces where failure is silent and the loss is a paid
deliverable or a child's data.

Three structural problems dominate the risk ranking:

1. Async story generation has no durability. `generate_story_task` runs with
   default `acks_late=False` and no retry, so a worker restart (every Railway
   redeploy does this) loses the task with the message already acked — the
   client polls a task that is `PENDING` forever. And `result_expires=3600`
   means a finished story's content is discarded after one hour; the `Story`
   DB row persists only metadata (title, theme), never `story_text`/`pages`.
   A user who closes their laptop loses a story that was successfully
   generated and paid for.

2. The synchronous generation path leaks work. On timeout,
   `_run_sync_story_task_with_timeout` calls `executor.shutdown(wait=False)`,
   abandoning a still-running generation thread, then dispatches a *second*
   async task for the same request. The result is double Gemini spend and
   duplicate `Story` rows per timed-out request.

3. Backups are unproven. Railway daily volume backups were staged on
   2026-05-14 but their active state is unconfirmed, restore has never been
   tested, and there is no off-Railway copy. `backend/backup_database.py`
   writes `pg_dump` output to an ephemeral container path and is never
   scheduled — dead code that implies a backup exists when it does not.

Cross-cutting: the most dangerous failures here are silent (beat skips a
purge, a story result expires, every story quietly becomes the static
fallback). None raise an exception, so Sentry never fires. Alerting is built
for crashes, not for silent degradation.

The top 10 Risk Priority Numbers and a hardening backlog follow. Effort is
scoped for a solo founder; only the top RPNs warrant runbooks.

## Service Inventory

Every external dependency and internal component that can fail, with at least
one failure mode each (full enumeration in the FMEA Matrix).

| Component | Role | Railway service | Key failure modes |
|---|---|---|---|
| Client (Flutter) | Web/mobile UI, polls task status | grand-light (`50f960c7`) | Retry storms, stale JWT, abandons polling |
| API | Flask + gunicorn, 2 sync workers, 120s timeout | story-weaver-app (`3a9d9f46`) | Worker-pool exhaustion, orphan threads, pool exhaustion |
| Celery worker | Story generation, `--pool=solo` (concurrency 1) | lovely-perfection (`f63456e1`) | Task loss on restart, throughput bottleneck |
| Celery beat | Daily data-retention purge scheduler | celery-beat (`edd97f13`) | Not in IaC; silent purge skips |
| Redis | Celery broker + result backend + rate limit + quota | Redis (`eab0180e`) | Eviction-driven task loss, result expiry, SPOF |
| Postgres | Primary datastore (users, stories, subs) | Postgres (`cfbe4566`) | Unproven backups, no migration framework |
| Stripe | Checkout, billing portal, webhooks | external | Secret rotation, outbound non-idempotency |
| Gemini | Story text, images, TTS | external | Outage → silent static fallback |
| OpenRouter | Fallback story text + images | external | Outage, per-image cost runaway |
| ElevenLabs / Edge TTS | Voice synthesis | external | Outage → robotic/no voice (degraded) |
| Sentry | Error monitoring | external | Alerting blind to silent failures |
| Railway | Hosting platform, single region | platform | Dyno restarts, crash-loop lockout, region outage |
| Cloudflare | CDN / image delivery | external | Cache/edge outage (degraded delivery) |

## FMEA Scoring Method

Each failure mode is scored 1–10 on three axes; RPN = Severity × Likelihood ×
Detectability (range 1–1000).

- Severity — impact when it occurs. 10 = payment loss, data loss, or child
  harm; 1 = cosmetic.
- Likelihood — probability of occurrence at current scale and traffic.
- Detectability — how hard the failure is to notice. 10 = fully silent, no
  signal; 1 = loud, alarmed, immediate. Higher is worse.

Severity bands: Critical = RPN ≥ 200 OR any potential payment/data loss
regardless of RPN; High = RPN 120–199; Medium = RPN 60–119; Low = RPN < 60.

## FMEA Matrix

| ID | Component | Failure Mode | Effect | S | L | D | RPN | Band |
|---|---|---|---|---|---|---|---|---|
| W1 | Celery worker | Worker restart/OOM mid-task; `acks_late=False`, no retry | Task lost, message already acked; client polls `PENDING` forever | 8 | 6 | 8 | 384 | Critical |
| R2 | Redis | `result_expires=3600`; `Story` row holds metadata only | Finished story content discarded after 1h; user permanently loses a paid story | 8 | 6 | 8 | 384 | Critical |
| SE1 | Sentry | Silent failures raise no exception | Beat skips, result expiry, static-fallback rate, queue depth never alert | 7 | 6 | 9 | 378 | Critical |
| P2 | Postgres | Backup restore never tested | Untested backup = no backup; recovery may fail when needed | 10 | 4 | 9 | 360 | Critical |
| R1 | Redis | Eviction policy not `noeviction` (unconfirmed) | Queued task messages / results evicted → silent task loss | 9 | 4 | 9 | 324 | Critical |
| A3 | API | Sync-timeout orphan thread + async fallback dispatched | Double Gemini spend, duplicate `Story` rows per timed-out request | 7 | 5 | 9 | 315 | Critical |
| A1 | API | Sync generation holds 1 of 2 gunicorn workers up to 75s | 2 concurrent requests stall whole API; healthcheck fails → restart | 8 | 6 | 6 | 288 | Critical |
| RW1 | Railway | Dyno restart / redeploy | In-flight async tasks (W1) and HTTP requests dropped | 6 | 7 | 6 | 252 | Critical |
| B1 | Celery beat | `celery-beat` service not in `railway.toml`; comment in `celery_config.py` is wrong | IaC rebuild loses beat → retention purge silently stops | 7 | 4 | 9 | 252 | Critical |
| B2 | Celery beat | Beat runs but purge firing is never verified | Daily COPPA purge can silently stop with no alert | 7 | 4 | 9 | 252 | Critical |
| P1 | Postgres | Volume backups staged 2026-05-14, active state unconfirmed; restore only same project/env | Possible no backups; no off-Railway DR | 10 | 3 | 8 | 240 | Critical |
| P5 | Postgres | `backup_database.py` writes to ephemeral `/app/backups`, never scheduled | Dead code implies a backup exists when it does not | 6 | 5 | 8 | 240 | Critical |
| X2 | Cross-cutting | Stacked retry layers (client + sync→async + last-resort sync) | One request can trigger up to 3 generations | 7 | 4 | 8 | 224 | Critical |
| S3 | Stripe | Outbound `checkout.Session.create` has no `idempotency_key` | Client retry → multiple checkout sessions / duplicate-subscription risk | 7 | 4 | 7 | 196 | High |
| G1 | Gemini | Outage → OpenRouter → static fallback, no user-facing signal | Paying user silently gets a generic 4-page story | 6 | 4 | 8 | 192 | High |
| G2 | Gemini+OR | Both providers down or `OPENROUTER_API_KEY` unset | Every story becomes static fallback; no static-fallback-rate alert | 7 | 3 | 8 | 168 | High |
| W2 | Celery worker | Single worker, `--pool=solo`, concurrency 1 | Throughput bottleneck; queued users wait up to 600s each | 5 | 6 | 5 | 150 | High |
| A5 | API | `/health` is shallow (no DB probe) | Bad deploy with broken DB passes healthcheck, goes live | 7 | 3 | 7 | 147 | High |
| A2 | API | Image request can run 120s == gunicorn `--timeout` | Worker killed mid-request; request dropped | 6 | 4 | 6 | 144 | High |
| A4 | API | Pool 10 + overflow 20 per worker ≈ 90 conns vs ~100 Postgres limit | Connection exhaustion under load → 500s | 7 | 4 | 5 | 140 | High |
| O2 | OpenRouter | Outage while `STORY_GEN_PROVIDER='openrouter'` (no Gemini fallback) | All stories become static fallback | 6 | 3 | 7 | 126 | High |
| W3 | Celery worker | Hung provider call held to `task_time_limit=600s` then SIGKILL, no retry | Task lost after 10-min hang | 6 | 3 | 6 | 108 | Medium |
| S5 | Stripe | `checkout.session.completed` carries bare subscription ID | `current_period_end` stored as `None` until first `subscription.updated` | 3 | 6 | 6 | 108 | Medium |
| P3 | Postgres | No migration framework; hand-run scripts, no transaction/rollback | Bad migration → manual recovery, possible partial schema | 7 | 3 | 5 | 105 | Medium |
| P4 | Postgres | `db.create_all()` on startup | Schema drift; dropped/renamed columns never reconciled | 5 | 3 | 7 | 105 | Medium |
| S6 | Stripe | Backend down beyond Stripe's ~3-day webhook retry window | Event permanently dropped → subscription state desync | 7 | 2 | 7 | 98 | Medium |
| RW2 | Railway | Crash-loop exhausts `restartPolicyMaxRetries=3` | Service stays DOWN until manual intervention | 8 | 3 | 4 | 96 | Medium |
| S2 | Stripe | Webhook secret rotation undocumented; code reads one secret | Rotation = window where all webhooks 401 | 6 | 3 | 5 | 90 | Medium (flagged High) |
| O1 | OpenRouter | Per-image pricing (~$0.0375); retry loop | Image-cost spike (mitigated by quota breaker) | 5 | 3 | 6 | 90 | Medium |
| SE2 | Sentry | Worker inits Sentry lazily on first task | Early worker-boot crash before first task not reported | 4 | 3 | 7 | 84 | Medium |
| R3 | Redis | Redis outage (SPOF: broker + results + rate limit + quota) | No async generation at all until Redis recovers | 8 | 3 | 3 | 72 | Medium |
| S4 | Stripe | Stripe API outage during checkout/portal create | User cannot subscribe; 500 returned | 6 | 3 | 4 | 72 | Medium |
| G3 | Gemini | Quota / 429 | `QUOTA_EXCEEDED` surfaced to user | 5 | 4 | 3 | 60 | Medium |
| C3 | Client | Access token expires after 1h offline | Brief re-auth via refresh token | 2 | 8 | 3 | 48 | Low |
| S1 | Stripe | Inbound webhook double-delivery | Re-applied absolute writes; safe (dedup + cursor) | 3 | 3 | 4 | 36 | Low |
| RW4 | Railway | Single-region (asia-southeast1) outage | Full outage | 8 | 1 | 3 | 24 | Low |
| R4 | Redis | Redis outage degrades rate limit / quota | Mitigated: per-process limit + DB cost breaker (M-2) | 4 | 3 | 2 | 24 | Low |

## Top 10 RPNs

| Rank | ID | RPN | Failure Mode |
|---|---|---|---|
| 1 | W1 | 384 | Worker restart loses an in-flight story task |
| 1 | R2 | 384 | Finished story content expires after 1h; only metadata persisted |
| 3 | SE1 | 378 | Alerting is blind to silent failures |
| 4 | P2 | 360 | Backup restore has never been tested |
| 5 | R1 | 324 | Redis eviction policy may silently drop queued tasks |
| 6 | A3 | 315 | Sync-timeout orphan thread causes double generation |
| 7 | A1 | 288 | Sync generation exhausts the 2-worker gunicorn pool |
| 8 | RW1 | 252 | Dyno restarts drop in-flight async and HTTP work |
| 8 | B1 | 252 | Beat service is absent from infrastructure-as-code |
| 8 | B2 | 252 | Daily retention purge firing is never verified |

### Findings detail

| ID | RPN | Component | Description | File:Line | Remediation | Effort | Runbook |
|---|---|---|---|---|---|---|---|
| W1 | 384 | Celery worker | `generate_story_task` decorated with no `acks_late`, no `max_retries`. A redeploy or OOM between message-ack and completion loses the task; client polls forever. | `backend/tasks/story_tasks.py:718` | Set `acks_late=True`, `task_reject_on_worker_lost=True`, and a bounded `autoretry_for`/`max_retries=2` on the task; ensure the task is idempotent first (see X2). | M | RB-1 |
| R2 | 384 | Redis / DB | `result_expires=3600`; the `Story` row persists `title`/`theme`/`themes` only — never `story_text` or `pages`. Late polling loses the story. | `backend/celery_config.py` (`result_expires`), `backend/tasks/story_tasks.py:1542` | Persist full `story_text` + `pages` to the `Story` row; serve `/task-status` from the DB row when the Celery result has expired. | M | RB-2 |
| SE1 | 378 | Sentry | Silent failures (beat skip, result expiry, all-fallback, queue growth) raise no exception, so Sentry never fires. | `backend/app.py:201` | Emit explicit metrics/events: `static_fallback` rate, Celery queue depth, last successful purge timestamp; alert on thresholds. | M | RB-7 |
| P2 | 360 | Postgres | No evidence a restore has ever been performed. Untested backups are not backups. | `docs/POSTGRES_BACKUP_DECISION_2026-05-14.md` | Perform a restore drill into a scratch environment; document the steps and time-to-recover. | M | RB-4 |
| R1 | 324 | Redis | If Railway Redis `maxmemory-policy` is not `noeviction`, queued Celery messages and results can be evicted. Uncertain — must be verified. | `backend/celery_config.py` | Verify and set `maxmemory-policy noeviction` on the Redis service; alarm on `evicted_keys > 0`. | S | RB-5 |
| A3 | 315 | API | `_run_sync_story_task_with_timeout` abandons a running thread on timeout (`shutdown(wait=False)`), then a second async task is dispatched. | `backend/routes/story_routes.py:327`, `:692` | Make generation idempotent on a client-supplied request key; on sync timeout, return the *same* task handle rather than dispatching a new one. | M | RB-1 |
| A1 | 288 | API | Sync generation occupies 1 of 2 gunicorn sync workers for up to 75s. 2 concurrent requests stall the whole API. | `railway.toml` (`--workers 2`), `backend/routes/story_routes.py:327` | Default to async generation; or raise worker count / move to gevent workers; keep sync path for low-latency cases only. | M | RB-6 |
| RW1 | 252 | Railway | Every redeploy restarts dynos, dropping in-flight async tasks (W1) and HTTP requests. | `railway.toml` | Fix W1 (`acks_late`) so restarts are survivable; deploy during low-traffic windows. | S | RB-1 |
| B1 | 252 | Celery beat | `celery-beat` runs in Railway but is absent from `railway.toml`; `celery_config.py` comment wrongly claims embedded `-B`. | `railway.toml`, `backend/celery_config.py:43` | Add the `celery-beat` service to `railway.toml`; correct the misleading comment. | S | RB-3 |
| B2 | 252 | Celery beat | No verification that the daily retention purge actually fires. | `backend/tasks/retention_tasks.py:38` | Have the purge task write a `last_run` heartbeat; alert if it is stale > 36h. | S | RB-3 |

## Idempotency Proof

For each mutating path, whether double-execution is safe:

| Path | Idempotent? | Reasoning |
|---|---|---|
| Stripe webhook `handle_webhook` | Yes | `event.id` dedup (`_already_processed`) with a unique-constraint backstop in `_record_event`; `_apply_subscription_updates` writes absolute values; `_is_stale_event` cursor blocks out-of-order replay. A replay re-applies identical state — harmless. |
| `_apply_subscription_updates` | Yes | Sets `subscription_tier`/`status`/`period_end` to absolute values, single `commit()`. |
| `purge_inactive_accounts_task` | Yes (asserted) | Docstring states already-anonymised and recently-active accounts are skipped. Not independently verified — recommend an explicit double-run test. |
| `generate_story_task` | **No** | No request key. A retry, the sync orphan thread (A3), or a client retry (C1) each produces a new `story_id`, a new `Story` row, fresh Gemini spend, and a separate quota increment. This is the root cause behind A3 and X2. |
| `create_checkout_session` | **No** | No Stripe `idempotency_key`; each call creates a distinct checkout session (S3). |
| `cancel_subscription` | Yes | `Subscription.modify(cancel_at_period_end=True)` is naturally idempotent. |
| `increment_daily_quota` | Uncertain | Counts after success; with non-idempotent generation, retries can over- or under-count. Flag for explicit testing. |

Highest-priority fix: give `generate_story_task` a client-supplied request
key, dedup on it, and key the `Story` row to it. That single change closes A3,
C1, and X2.

## Alert Audit

`docs/RAILWAY_ALERTS_SETUP.md` describes dashboard alerts for downtime, error
rate, slow response, and memory. Those cover loud, crash-style failures.
Sentry (`before_send` scrubbing is correct) catches exceptions.

The gap: the highest-RPN failures here are silent and exception-free.

| Failure mode | Raises exception? | Alert today? | Needed |
|---|---|---|---|
| Worker loses task on restart (W1) | No (client just polls) | No | Queue-depth + stuck-`PENDING` alert |
| Story result expiry (R2) | No | No | DB-backed retrieval makes it moot; until then, alert on result-not-found |
| Beat stops firing (B2) | No | No | `last_run` heartbeat staleness alert |
| All-static-fallback (G1/G2) | No | No | `static_fallback` rate alert |
| Redis eviction (R1) | No | No | `evicted_keys` alarm |
| Bad deploy passes shallow healthcheck (A5) | No | No | Deep healthcheck + post-deploy smoke |

## Runbook Coverage

| Runbook | Failure modes | Status |
|---|---|---|
| RB-1 Lost/stuck story task | W1, A3, RW1 | Missing — outline below |
| RB-2 Story result lost | R2 | Missing |
| RB-3 Beat / retention purge | B1, B2 | Missing |
| RB-4 Database restore | P1, P2 | Missing — Critical gap |
| RB-5 Redis incident | R1, R3 | Missing |
| RB-6 API capacity stall | A1, A2, A4 | Missing |
| RB-7 Provider outage | G1, G2, O2 | Partial — `STORY_GEN_PROVIDER` flag exists, no procedure |
| Security incident | — | Exists (`docs/SECURITY_RUNBOOK.md`) |

Gap analysis: of 7 reliability runbooks, 0 are fully documented. RB-4
(database restore) is the Critical gap — a restore must not be improvised.
Keep the set to these 7; a solo founder cannot maintain more.

### RB-4 Database Restore (outline — write this first)

1. Confirm daily volume backups are active: Railway → Postgres service →
   volume → Backups. If absent, this runbook cannot run — fix immediately.
2. Identify the target snapshot (24h RPO, 6-day retention).
3. Restore into a *scratch* environment first (Railway restores only into the
   same project; create a non-production environment).
4. Point a disposable backend at the restored DB; run `/health/detailed` and
   spot-check `users`, `stories`, subscription rows.
5. Only then restore into production; expect a brief write outage.
6. Record actual time-to-recover. If > 1h, that is the real RPO/RTO.

### RB-1 Lost / Stuck Story Task (outline)

1. Symptom: client reports a story stuck "processing"; `/task-status`
   returns `PENDING` indefinitely.
2. Check `lovely-perfection` deploy history for a restart near the request.
3. Inspect Celery queue depth in Redis (`LLEN` on the default queue).
4. Until W1 is fixed, the task is unrecoverable — instruct the user to
   regenerate; verify quota was not double-charged.
5. Permanent fix: `acks_late=True` so a lost task is redelivered.

## Hardening Backlog

Prioritised by RPN. Effort: S < 2h, M ~half-day, L multi-day.

| Priority | Items | Action | Effort |
|---|---|---|---|
| 1 | W1, A3, C1, X2 | Add a client request-idempotency key; dedup generation; key `Story` rows to it; set `acks_late=True` + bounded retry. | M |
| 2 | R2 | Persist full `story_text`/`pages` to the `Story` row; serve `/task-status` from DB on result-miss. | M |
| 3 | P1, P2 | Confirm Railway daily backups are active; run a restore drill; write RB-4. | M |
| 4 | R1 | Verify/set Redis `maxmemory-policy noeviction`; alarm on `evicted_keys`. | S |
| 5 | SE1, B2, G1/G2 | Emit metrics for static-fallback rate, queue depth, purge heartbeat; alert on each. | M |
| 6 | B1 | Add `celery-beat` to `railway.toml`; fix the wrong `celery_config.py` comment. | S |
| 7 | A1, A2, A4 | Default to async generation; review gunicorn worker count / pool sizing vs Postgres connection limit. | M |
| 8 | A5 | Deepen `/health` (DB probe) or add a post-deploy smoke check. | S |
| 9 | S3, S2 | Add `idempotency_key` to `checkout.Session.create`; document Stripe webhook-secret rotation. | S |
| 10 | P5 | Delete or fix `backend/backup_database.py` — it implies a backup that does not exist. | S |
| 11 | P3, P4 | Adopt a migration framework (Alembic); stop relying on `db.create_all()`. | L |

## Chaos Test Scenarios (staging only — explicit approval required)

Do not run against production. Do not commit chaos code to `main`.

| Experiment | Setup | Expected | Validates |
|---|---|---|---|
| Kill worker mid-task | Start an async generation; restart `lovely-perfection`. | With `acks_late`, task redelivers and completes. Without it, task is lost. | W1, RW1 |
| Expire a result | Generate a story; wait > 1h; poll `/task-status`. | DB-backed retrieval returns the story. Today: result lost. | R2 |
| Drop Redis | Stop the Redis service. | Sync path still serves; quota falls to DB breaker; clean error, no uncapped spend. | R1, R3, R4 |
| Replay a Stripe webhook | Re-POST a captured signed event within the 5-min window. | Handler returns `duplicate`, no state change. | S1 |
| Provider blackout | Set an invalid `GEMINI_API_KEY` and unset `OPENROUTER_API_KEY`. | Static fallback served; a `static_fallback` metric/alert fires. | G1, G2 |
| Saturate the API | Fire 4+ concurrent sync generations. | Async queueing absorbs load; the 2-worker pool does not stall. | A1 |

## Cost-of-Failure Analysis (top RPNs)

| Failure | Per-incident cost | Notes |
|---|---|---|
| W1 / R2 lost story | Refund or churn of one paying user; lost trust | A paid feature silently fails to deliver — disproportionate reputation damage for a children's product. |
| A3 double generation | ~2× Gemini spend + image cost per timed-out request | Recurring drain; scales with timeout rate. |
| P2 failed restore | Potential total data loss (all users, stories, subscriptions) | Existential. Probability low, impact unbounded. |
| B2 missed purge | COPPA/GDPR non-compliance; children's data retained past promise | Regulatory and reputational, not just technical. |
| G1/G2 silent fallback | Quality erosion across all users during an outage | No signal means no mitigation and no support response. |

## SLO Recommendation

Realistic objectives for current capability and scale (solo founder, pre-scale
traffic). Set these as targets to hold against, not contractual commitments.

| Objective | Target | Rationale |
|---|---|---|
| API availability | 99.0% monthly | Single region, single small fleet; redeploys cause brief drops. |
| Story generation success | 95% delivered without static fallback | Accounts for provider variance; below this, investigate. |
| Story generation latency (p95) | < 75s sync, < 5min async | Matches `SYNC_STORY_TIMEOUT_SECONDS` and `task_time_limit`. |
| Webhook processing success | 99.9% | Handler is robust; failures are Stripe-side or DB blips. |
| Data durability (RPO) | 24h until backups proven; target 1h after | Current Railway daily snapshot RPO; tighten only once restore is tested. |
| Recovery time (RTO) | Measure via RB-4 drill, then commit | Cannot be claimed until a restore has actually been timed. |

## Error-Handling Notes

- Idempotency of `generate_story_task` and `increment_daily_quota` could not
  be statically proven safe — flagged Uncertain; both need explicit tests.
- Stripe webhook-secret rotation is undocumented — flagged High (S2)
  regardless of RPN, per audit policy.
- Backup restore has never been tested — flagged Critical (P2) regardless of
  RPN, per audit policy.
- Conflicting retry layers (client retry, sync→async fallback, last-resort
  sync retry) multiply into up to 3 generations per request — surfaced as X2.
- Railway Redis eviction policy could not be confirmed from the repo — R1 is
  scored on the worst plausible case and marked for verification.
