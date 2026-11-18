#!/usr/bin/env bash
set -eu

# The official image runs init scripts only on a new data directory.
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1 <<'SQL'
\getenv replication_password REPLICATION_PASSWORD
CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD :'replication_password';
SQL

# This lab uses its own Docker network; the replication role must authenticate.
echo 'host replication replicator all scram-sha-256' >> "$PGDATA/pg_hba.conf"
