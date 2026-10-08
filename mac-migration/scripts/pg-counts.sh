#!/bin/bash
# Print "database|schema.table|exact row count" for every user table in every non-template database of a
# local Postgres server. Read-only. Run on both Macs and diff the outputs.
# Usage: pg-counts.sh [major-version] [host] [port]     (defaults: 17 localhost 5432)
# Uses Homebrew's postgresql@<version> binaries.
set -u
[[ "${1:-}" == "-h" ]] && { sed -n '2,5p' "$0"; exit 0; }
V="${1:-17}"; H="${2:-localhost}"; P="${3:-5432}"
B="/opt/homebrew/opt/postgresql@$V/bin"
q() { "$B/psql" -X -h "$H" -p "$P" -d "$1" -Atc "$2"; }
for db in $(q postgres "select datname from pg_database where not datistemplate order by 1"); do
  for t in $(q "$db" "select quote_ident(schemaname)||'.'||quote_ident(relname) from pg_stat_user_tables order by 1"); do
    echo "$db|$t|$(q "$db" "select count(*) from $t")"
  done
done
