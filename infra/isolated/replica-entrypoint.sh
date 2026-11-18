#!/usr/bin/env bash
set -eu

mkdir -p "$PGDATA"
chown postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  if [ -n "$(ls -A "$PGDATA")" ]; then
    echo 'Replica data directory is not empty; inspect it before retrying.' >&2
    exit 1
  fi
  gosu postgres pg_basebackup -h primary -D "$PGDATA" -U replicator -Fp -Xs -R
fi

exec docker-entrypoint.sh postgres
