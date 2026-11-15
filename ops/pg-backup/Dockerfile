# Image for the two Railway cron services that protect Postgres:
#   pg-backup         daily dump to Cloudflare R2 (backup.sh, the default)
#   pg-restore-drill  monthly test restore from R2 (restore-drill.sh)
# The service picks its job with the JOB variable: unset or "backup" runs
# backup.sh; "restore-drill" runs restore-drill.sh. See each script for the
# variables it needs.
#
# Build context is this directory only (upload with
# `railway up ops/pg-backup --path-as-root`), so none of the app's code ships
# in this image.
#
# postgres:alpine tracks the newest Postgres client on purpose: pg_dump refuses
# to dump a server newer than itself, while a newer client against an older
# server is fine. The same image carries the server binaries the restore drill
# starts its throwaway database with.
FROM postgres:alpine

RUN apk add --no-cache aws-cli curl

COPY backup.sh /usr/local/bin/backup.sh
COPY restore-drill.sh /usr/local/bin/restore-drill.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore-drill.sh

USER postgres
ENTRYPOINT []
CMD ["/bin/sh", "-c", "case \"${JOB:-backup}\" in backup) exec /usr/local/bin/backup.sh ;; restore-drill) exec /usr/local/bin/restore-drill.sh ;; *) echo \"Unknown JOB: ${JOB}\" >&2; exit 2 ;; esac"]
