# Story Weaver monitoring

This directory is documentation only — it holds no code or config. It records
what actually watches production, because an earlier version of this file
described a monitoring stack that was never built. The stack that used to sit
here was deleted on 2026-09-07; see the last section.

## What is actually in place

Production runs on Railway (backend, Celery worker, Celery beat) with the
frontend on Cloudflare Pages. Observability consists of:

- **Error tracking and tracing: Sentry.** Initialized in `backend/app.py`
  from `SENTRY_DSN` with the Flask integration, 10% trace sampling in
  production, profiling off, and a `before_send` scrubber.
- **Health endpoints** in `backend/routes/health_routes.py`:
  - `GET /health` - public liveness check.
  - `GET /version`.
  - `GET /health/detailed` - admin-only. Probes the database, makes a live
    Gemini API call, and reports memory use via psutil.
  - `GET /health/database`.
- **Scheduled reliability monitor** - `backend/tasks/monitoring_tasks.py`,
  run by Celery beat every 10 minutes (schedule in `backend/celery_config.py`).
  Raises a Sentry warning when the Celery queue depth crosses a threshold or
  when the daily data-retention purge heartbeat goes stale. It runs on the
  same worker it monitors, so a fully wedged worker delays it; the module
  docstring spells this out.
- **Database backups** - `.github/workflows/postgres-backup.yml` is present
  here as a manual-dispatch workflow only; its schedule is disabled in this
  repo. The daily run (09:00 UTC: `pg_dump`, gzip, upload to Cloudflare R2,
  archive verified before upload, dumps older than 30 days pruned, GitHub
  issue opened on failure) happens from a private ops repo that holds the
  database and R2 secrets.
- **Restore drill** - `.github/workflows/restore-drill.yml`, likewise
  manual-dispatch only here. The monthly drill (latest dump restored into a
  throwaway Postgres container, table and row counts checked, measured RTO
  printed, issue opened on failure) runs from the same private ops repo.
- **Railway** provides service logs and CPU/memory graphs in its dashboard.
  Alert rules live there, not in this repo. The intended rules are written
  up in `docs/RAILWAY_ALERTS_SETUP.md`; they cannot be verified from the repo.
- **User data endpoints** in `backend/routes/user_routes.py`:
  `GET /api/user/<id>/export` and `DELETE /api/user/<id>/data`. Inactive
  accounts are purged daily at 03:30 UTC by
  `backend/tasks/retention_tasks.py`.

There is no Prometheus, Grafana, Loki, Elasticsearch, Logstash, Kibana, or
New Relic. The backend exposes no `/metrics` endpoint and has no Prometheus
client dependency. No Loki instance is configured anywhere in this repo;
where session notes say "Loki", the logs being queried were Railway's.

## What used to be here, and why it was removed (2026-09-07)

This directory previously held a self-hosted observability stack that never
ran. All of it was deleted; recover it from git history if ever needed.

- `docker-compose.yml` declared Prometheus, Grafana, Loki, Promtail,
  Alertmanager, Elasticsearch, Logstash, Kibana, and Redis. It mounted five
  config files (`prometheus.yml`, `loki-config.yml`, `promtail-config.yml`,
  `alertmanager.yml`, `logstash.conf`), none of which were ever committed, so
  the stack could not start. It was never deployed anywhere.
- `dashboards/production-health-dashboard.json` was a Grafana dashboard for a
  Grafana that did not exist.
- 13 Python scripts (`uptime_monitor.py`, `cost_monitor.py`,
  `ai_anomaly_detector.py`, `weekly_report.py`, and the rest) were scheduled
  or invoked by nothing: not Celery beat, not a GitHub workflow, not Railway.
  Several imported scikit-learn, pandas, numpy, and joblib, which are not
  backend dependencies.

An earlier version of this README also claimed the backend was instrumented
with New Relic APM and a Prometheus client. It never was. That claim is the
reason this file now leads with what is actually in place.
