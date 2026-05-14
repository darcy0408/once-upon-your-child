# Postgres Backup Decision — 2026-05-14

## Context

Today (2026-05-14) we discovered prod had been running on ephemeral SQLite —
every Railway redeploy wiped state. We provisioned a real Postgres on Railway:

- Project: `radiant-tranquility` (`36b27716-089f-4441-9b9d-af942a6df7aa`)
- Service: `Postgres` (`cfbe4566-c0c2-4261-adc9-97654a8970f5`)
- Volume: `e3b79c6f-b165-4aec-b333-31d82e59d212` mounted at `/var/lib/postgresql/data`
- Image: `ghcr.io/railwayapp-templates/postgres-ssl:18`
- Region: `asia-southeast1-eqsg3a`
- Shared by: `story-weaver-app` (Flask) and `lovely-perfection` (Celery worker)

Default Railway Postgres comes with **no backups configured**. We need data
durability across redeploys and accidental drops.

## Options considered

| Option | Effort | Cost | Recovery quality | Verdict |
|---|---|---|---|---|
| (a) Daily `pg_dump` cron service writing to external bucket | ~30–60 min setup + ongoing maintenance of a sidecar service | Free compute (within Hobby usage) + S3/R2 storage | Logical dumps, restorable anywhere, off-Railway | Overkill for current scale |
| (b) Upgrade plan for "automatic backups" | 0 min, but plan cost goes up | Higher monthly minimum | Same as native volume backups | The "premium" backup option marketed by other PaaS doesn't apply here — Railway's volume backup is available on the current tier |
| (c) Defer until launch ("no real users yet") | 0 min | $0 | None | Risk doesn't match the moment — we *just* started persisting real data, including any test users we onboard this week |
| **(d) Enable Railway native volume backups (DAILY)** | 5 min via MCP | Per-GB incremental (CoW snapshots) — pennies at our DB size | 24-hour RPO, 6-day retention; one-click restore from dashboard | **Chosen** |

## Why (d) over (a)

`pg_dump` cron is the textbook answer when your PaaS has no native backup
story. Railway *does* have one — released since the docs we last checked.
Per [Railway backup docs](https://docs.railway.com/volumes/backups)
(last updated 2026-05-08):

> When a volume is mounted to a service, backups can be manually created,
> deleted and restored. And they can also be scheduled to run on a
> Daily / Weekly / Monthly schedule.
>
> - **Daily** — every 24 hours, kept for 6 days
> - **Weekly** — every 7 days, kept for 1 month
> - **Monthly** — every 30 days, kept for 3 months
>
> Backups are incremental and Copy-on-Write, we only charge for the data
> exclusive to them […] billed per-GB-minute.

This means:

- **Zero new code** — no sidecar, no S3 bucket, no Celery beat task to babysit.
- **No new failure mode** — `pg_dump` cron services rot silently when DB
  creds rotate or the cron container falls behind; native snapshots don't.
- **Cheap at our scale** — our DB is < 100 MB. Daily CoW deltas are bytes.
- **Restores are one-click** in the dashboard (stages a new mount, you
  review before deploy).

The only Railway-native caveat:

> Backups can only be restored into the same project + environment.

For true off-Railway disaster recovery (project deletion, account loss) we'd
still want an external `pg_dump` to R2/S3. Defer that until we have paying
users; track in `docs/MANUAL_TASKS.md`.

## What I implemented

Via `mcp__railway__railway-agent` against the Postgres service:

```
volumeMounts: {
  "e3b79c6f-b165-4aec-b333-31d82e59d212": {
    "mountPath": "/var/lib/postgresql/data",
    "backupSchedules": ["DAILY"]
  }
}
```

The change is **staged** on the service. It needs `accept-deploy` (or a
one-click Deploy from the Railway canvas) to activate. I didn't run
`accept-deploy` myself because the MCP instructions ask for user
confirmation before deploy actions.

## What still needs Darcy's hands

1. Open the Railway dashboard → `radiant-tranquility` → `Postgres` →
   review the staged change → click **Deploy**. (Or run the
   `accept-deploy` MCP call.)
2. Verify in the Postgres service's **Backups** tab that the schedule
   shows DAILY and that the first snapshot appears within 24 hours.
3. Optional: add WEEKLY and MONTHLY too. Cost is still cents — they
   give better recovery granularity (6 days / 1 month / 3 months).
4. Add a manual task: "external off-Railway `pg_dump` to R2 before
   launch" — only needed once we have paying users we can't reissue.
