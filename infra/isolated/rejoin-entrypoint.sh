#!/usr/bin/env bash
set -eu

: "${PRIMARY_HOST:?PRIMARY_HOST is required}"

mkdir -p "$PGDATA"
chown postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    if [ -n "$(ls -A "$PGDATA")" ]; then
        echo "Rejoin data directory is not empty; inspect it before retrying." >&2
        exit 1
    fi

    gosu postgres pg_basebackup \
        -h "$PRIMARY_HOST" \
        -D "$PGDATA" \
        -U replicator \
        -Fp -Xs -R -P
fi

exec docker-entrypoint.sh postgres