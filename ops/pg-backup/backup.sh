#!/bin/sh
# Daily Postgres backup, run INSIDE Railway as a cron service.
#
# Why this lives here and not in GitHub Actions: the database has no public
# network entry point. A GitHub runner cannot reach it, and must not be able
# to. This job runs on Railway's private network, dumps the database, and
# pushes the dump to a Cloudflare R2 bucket.
#
# Required variables (set on the Railway service, never in this repo):
#   DATABASE_URL           private connection string, as a Railway reference
#                          to the Postgres service
#   R2_ACCOUNT_ID          Cloudflare account id (R2 endpoint host prefix)
#   R2_ACCESS_KEY_ID       R2 API token access key (Object Read & Write on
#                          the backup bucket only)
#   R2_SECRET_ACCESS_KEY   R2 API token secret
#   R2_BUCKET              target bucket name
# Optional:
#   RETENTION_DAYS         days of dumps to keep (default 30)
#   RESEND_API_KEY, ALERT_EMAIL_FROM, ALERT_EMAIL_TO
#                          when all three are set, a failed run sends an email
set -eu

: "${DATABASE_URL:?DATABASE_URL is not set}"
: "${R2_ACCOUNT_ID:?R2_ACCOUNT_ID is not set}"
: "${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID is not set}"
: "${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY is not set}"
: "${R2_BUCKET:?R2_BUCKET is not set}"

RETENTION_DAYS="${RETENTION_DAYS:-30}"
PREFIX="postgres/story-weaver-pg-"
TODAY="$(date -u +%Y-%m-%d)"
DUMP_FILE="/tmp/story-weaver-pg-${TODAY}.sql.gz"
# R2_ENDPOINT can be overridden to point at a local S3 stand-in for testing.
R2_ENDPOINT="${R2_ENDPOINT:-https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com}"
STEP="start"

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION=auto
# R2 rejects the aws-cli v2 default integrity checksums.
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required

alert_on_failure() {
  code=$?
  rm -f "$DUMP_FILE"
  [ "$code" -eq 0 ] && return 0
  echo "BACKUP FAILED at step '${STEP}' (exit ${code})"
  if [ -n "${RESEND_API_KEY:-}" ] && [ -n "${ALERT_EMAIL_FROM:-}" ] &&
    [ -n "${ALERT_EMAIL_TO:-}" ]; then
    curl -sS -o /dev/null -w "alert email: HTTP %{http_code}\n" \
      -X POST https://api.resend.com/emails \
      -H "Authorization: Bearer ${RESEND_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "{\"from\":\"${ALERT_EMAIL_FROM}\",\"to\":[\"${ALERT_EMAIL_TO}\"],\"subject\":\"Postgres backup FAILED (${TODAY})\",\"text\":\"The daily Postgres backup failed at step '${STEP}' (exit ${code}). Production has no fresh off-site backup. Check the pg-backup service logs in Railway.\"}" ||
      echo "alert email could not be sent"
  fi
  exit "$code"
}
trap alert_on_failure EXIT

STEP="dump"
# Dump to a plain file first so a pg_dump failure fails the run (a pipe into
# gzip would hide its exit code under plain sh).
pg_dump "$DATABASE_URL" --no-owner --no-privileges -f /tmp/dump.sql
gzip -c /tmp/dump.sql >"$DUMP_FILE"
rm -f /tmp/dump.sql

STEP="verify"
SIZE="$(wc -c <"$DUMP_FILE")"
echo "Dump size: ${SIZE} bytes"
if [ "$SIZE" -lt 1000 ]; then
  echo "Dump file is suspiciously small - aborting."
  exit 1
fi
gzip -t "$DUMP_FILE"
# Capture the header before grepping it: grep exiting early on a live pipe
# kills gunzip with SIGPIPE.
header="$(gunzip -c "$DUMP_FILE" 2>/dev/null | head -50 || true)"
case "$header" in
*"PostgreSQL database dump"*) echo "Dump banner check: ok" ;;
*)
  echo "Dump does not contain the pg_dump header - aborting before upload."
  exit 1
  ;;
esac

STEP="upload"
aws s3 cp "$DUMP_FILE" "s3://${R2_BUCKET}/${PREFIX}${TODAY}.sql.gz" \
  --endpoint-url "$R2_ENDPOINT" --only-show-errors
echo "Uploaded ${PREFIX}${TODAY}.sql.gz"

STEP="prune"
# Dump names carry their date, so compare names instead of parsing object
# timestamps. Only reached after today's upload succeeded, so pruning can
# never remove the newest backup.
CUTOFF="$(date -u -d "@$(($(date -u +%s) - RETENTION_DAYS * 86400))" +%Y-%m-%d)"
echo "Pruning dumps dated before ${CUTOFF}"
aws s3api list-objects-v2 --bucket "$R2_BUCKET" --prefix "$PREFIX" \
  --endpoint-url "$R2_ENDPOINT" --query 'Contents[].Key' --output text |
  tr '\t' '\n' | while read -r key; do
  case "$key" in
  "${PREFIX}"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].sql.gz) ;;
  *) continue ;;
  esac
  key_date="${key#"$PREFIX"}"
  key_date="${key_date%.sql.gz}"
  if [ "$(printf '%s\n%s\n' "$key_date" "$CUTOFF" | sort | head -1)" = "$key_date" ] &&
    [ "$key_date" != "$CUTOFF" ]; then
    echo "  prune: $key"
    aws s3 rm "s3://${R2_BUCKET}/${key}" --endpoint-url "$R2_ENDPOINT" \
      --only-show-errors
  fi
done

STEP="done"
echo "Backup complete."
