# Image for the Railway cron service that backs up Postgres to Cloudflare R2.
# See backup.sh for what it does and which variables it needs.
#
# Build context is this directory only (set the service's root directory to
# ops/pg-backup in Railway), so none of the app's code ships in this image.
#
# postgres:alpine tracks the newest Postgres client on purpose: pg_dump refuses
# to dump a server newer than itself, while a newer client against an older
# server is fine.
FROM postgres:alpine

RUN apk add --no-cache aws-cli curl

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

USER postgres
ENTRYPOINT []
CMD ["/usr/local/bin/backup.sh"]
