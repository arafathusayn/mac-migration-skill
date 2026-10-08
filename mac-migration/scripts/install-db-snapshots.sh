#!/bin/bash
# Run ON THE NEW MAC. Installs SQLite snapshots made by snapshot_dbs.py into place.
# For each snapshot under SNAPSHOT_DIR (default ~/mac-migration/db-snapshots, mirroring paths relative to
# $HOME): removes a stale -wal/-shm/-journal next to the target (a stale WAL next to a newer database
# corrupts it), copies the snapshot in atomically, and runs PRAGMA integrity_check on the result.
# Refuses to run while any process named in BUSY_PROCS (space-separated, matched with pgrep -f) is running,
# because the owning app must not hold the database open during the swap.
# Usage: BUSY_PROCS="codex mytool" install-db-snapshots.sh [SNAPSHOT_DIR]
set -u
[[ "${1:-}" == "-h" ]] && { sed -n '2,9p' "$0"; exit 0; }
SNAP="${1:-$HOME/mac-migration/db-snapshots}"
for p in ${BUSY_PROCS:-}; do
  pgrep -f "$p" >/dev/null && { echo "ABORT: '$p' is running on this Mac"; exit 1; }
done
cd "$SNAP" || exit 1
bad=0; n=0
while IFS= read -r f; do
  rel="${f#./}"; dst="$HOME/$rel"
  mkdir -p "$(dirname "$dst")"
  rm -f "$dst-wal" "$dst-shm" "$dst-journal"
  cp -p "$f" "$dst.migrating" && mv -f "$dst.migrating" "$dst"
  ok=$(/usr/bin/sqlite3 "$dst" "PRAGMA integrity_check;" 2>&1 | head -1)
  n=$((n+1)); [ "$ok" = "ok" ] || bad=$((bad+1))
  echo "$ok $rel"
done < <(find . -type f \( -name '*.sqlite' -o -name '*.sqlite3' -o -name '*.db' \) | sort)
echo "installed: $n, problems: $bad"
[ "$bad" -eq 0 ]
