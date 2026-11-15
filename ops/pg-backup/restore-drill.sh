#!/bin/sh
# Monthly restore drill, run INSIDE Railway as its own cron service.
#
# A backup that has never been restored is a hope, not a backup. This job
# downloads the newest dump from R2, restores it into a throwaway Postgres
# started inside this container, and checks that real data came back. It never
# touches the production database. The restored copy lives only in this
# container's /tmp and is gone when the run ends.
#
# Why Railway and not GitHub Actions: the app repo is public, so Actions logs
# (table and user counts) and failure issues would be public too, and an R2
# key that can read children's data would sit in a public repo's secrets.
#
# Required variables (set on the Railway service, never in this repo):
#   R2_ACCOUNT_ID          Cloudflare account id (R2 endpoint host prefix)
#   R2_ACCESS_KEY_ID       R2 API token access key. Use an Object Read ONLY
#                          token: the drill must not be able to delete backups.
#   R2_SECRET_ACCESS_KEY   R2 API token secret
#   R2_BUCKET              bucket holding the dumps
# Optional:
#   MAX_DUMP_AGE_DAYS      fail if the newest dump is older than this (default 2)
#   RESEND_API_KEY, ALERT_EMAIL_FROM, ALERT_EMAIL_TO
#                          when all three are set, the run emails its result:
#                          a short note on success, an alert on failure
set -eu

: "${R2_ACCOUNT_ID:?R2_ACCOUNT_ID is not set}"
: "${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID is not set}"
: "${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY is not set}"
: "${R2_BUCKET:?R2_BUCKET is not set}"

MAX_DUMP_AGE_DAYS="${MAX_DUMP_AGE_DAYS:-2}"
PREFIX="postgres/story-weaver-pg-"
TODAY="$(date -u +%Y-%m-%d)"
WORK="/tmp/drill"
DUMP_FILE="${WORK}/dump.sql.gz"
PGDATA_DIR="${WORK}/pgdata"
SOCKET_DIR="${WORK}/sock"
# R2_ENDPOINT can be overridden to point at a local S3 stand-in for testing.
R2_ENDPOINT="${R2_ENDPOINT:-https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com}"
STEP="start"
SUMMARY=""

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION=auto
# R2 rejects the aws-cli v2 default integrity checksums.
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required

send_email() {
  # $1 subject, $2 body. Plain text only; no quotes or backslashes in either.
  if [ -n "${RESEND_API_KEY:-}" ] && [ -n "${ALERT_EMAIL_FROM:-}" ] &&
    [ -n "${ALERT_EMAIL_TO:-}" ]; then
    curl -sS -o /dev/null -w "email: HTTP %{http_code}\n" \
      -X POST https://api.resend.com/emails \
      -H "Authorization: Bearer ${RESEND_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "{\"from\":\"${ALERT_EMAIL_FROM}\",\"to\":[\"${ALERT_EMAIL_TO}\"],\"subject\":\"$1\",\"text\":\"$2\"}" ||
      echo "email could not be sent"
  fi
}

finish() {
  code=$?
  if [ -d "$PGDATA_DIR" ]; then
    pg_ctl -D "$PGDATA_DIR" -m immediate stop >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK"
  if [ "$code" -eq 0 ]; then
    send_email "Postgres restore drill passed (${TODAY})" "${SUMMARY}"
    return 0
  fi
  echo "RESTORE DRILL FAILED at step '${STEP}' (exit ${code})"
  send_email "Postgres restore drill FAILED (${TODAY})" "The monthly restore drill failed at step '${STEP}' (exit ${code}). The off-site backups may not be restorable. Check the pg-restore-drill service logs in Railway."
  exit "$code"
}
trap finish EXIT

rm -rf "$WORK"
mkdir -p "$WORK" "$SOCKET_DIR"

STEP="find"
# Dump names carry their date, so the newest dump is the last name in sort
# order. Ignore anything that does not match the exact naming pattern.
# List on its own line first: inside a pipe, an auth or network error from aws
# would be swallowed and misreported as "no dumps".
keys="$(aws s3api list-objects-v2 --bucket "$R2_BUCKET" --prefix "$PREFIX" \
  --endpoint-url "$R2_ENDPOINT" --query 'Contents[].Key' --output text)"
latest="$(printf '%s\n' "$keys" | tr '\t' '\n' |
  grep -E "^${PREFIX}[0-9]{4}-[0-9]{2}-[0-9]{2}\.sql\.gz$" | sort | tail -1 || true)"
if [ -z "$latest" ]; then
  echo "No dumps found under ${PREFIX} - nothing to restore."
  exit 1
fi
dump_date="${latest#"$PREFIX"}"
dump_date="${dump_date%.sql.gz}"
echo "Newest dump: ${latest}"

STEP="freshness"
# A drill that restores a month-old dump would pass while the daily backup is
# broken. Fail loudly if the newest dump is stale.
CUTOFF="$(date -u -d "@$(($(date -u +%s) - MAX_DUMP_AGE_DAYS * 86400))" +%Y-%m-%d)"
if [ "$(printf '%s\n%s\n' "$dump_date" "$CUTOFF" | sort | head -1)" = "$dump_date" ] &&
  [ "$dump_date" != "$CUTOFF" ]; then
  echo "Newest dump (${dump_date}) is older than ${MAX_DUMP_AGE_DAYS} days - the daily backup has stopped."
  exit 1
fi

STEP="download"
aws s3 cp "s3://${R2_BUCKET}/${latest}" "$DUMP_FILE" \
  --endpoint-url "$R2_ENDPOINT" --only-show-errors
echo "Downloaded $(wc -c <"$DUMP_FILE") bytes"
gzip -t "$DUMP_FILE"

STEP="start-postgres"
# Throwaway server: unix socket only, no network listener, trust auth.
# UTF8 with the C locale: matches the production encoding without needing
# system locales, which this alpine image does not ship.
initdb -D "$PGDATA_DIR" -U postgres --auth=trust -E UTF8 --no-locale >/dev/null
pg_ctl -D "$PGDATA_DIR" -w -l "${WORK}/postgres.log" \
  -o "-c listen_addresses='' -k ${SOCKET_DIR} -c fsync=off" start >/dev/null
export PGHOST="$SOCKET_DIR" PGUSER=postgres PGDATABASE=postgres

STEP="restore"
start="$(date +%s)"
# gzip -t above already proved the archive is whole, so psql's exit code is
# the one that matters here.
gunzip -c "$DUMP_FILE" | psql -X -q -v ON_ERROR_STOP=1 >/dev/null
rto=$(($(date +%s) - start))
rm -f "$DUMP_FILE"

STEP="verify"
tables="$(psql -X -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")"
echo "Public tables restored: ${tables}"
if [ "$tables" -lt 1 ]; then
  echo "Restore produced zero public tables - the backup is not usable."
  exit 1
fi
if [ -z "$(psql -X -tAc "SELECT to_regclass('public.\"user\"');")" ]; then
  echo "No public.\"user\" table in the restored database."
  exit 1
fi
users="$(psql -X -tAc 'SELECT count(*) FROM "user";')"
echo "user table rows: ${users}"
if [ "$users" -lt 1 ]; then
  echo "The user table restored empty - the backup is not usable."
  exit 1
fi
echo "Largest tables by row count:"
psql -X -c "ANALYZE;" >/dev/null
psql -X -c "SELECT relname AS table, n_live_tup AS rows FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 10;"

STEP="done"
SUMMARY="Restored ${latest} into a throwaway database: ${tables} tables, ${users} users, restore took ${rto}s. No action needed."
echo "RESTORE DRILL PASSED. ${SUMMARY}"
