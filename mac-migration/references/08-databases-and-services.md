# Phase 8 — Databases and background services

## SQLite files that are being written

Many tools (AI agent CLIs, MCP daemons, GPG's keyboxd, editors) keep SQLite databases in WAL mode under
the home folder. A raw rsync of a live database can produce a copy that is missing data or will not open,
and a **stale `-wal` file next to a newer database corrupts it** on the next open.

1. Find them: files held open (`lsof -nP +c 0 -u $USER | awk '$NF ~ /\.(sqlite3?|db)$/'`) plus any `*-wal`.
2. Snapshot with SQLite's online backup API: `scripts/snapshot_dbs.py <paths…>` (consistent even while the
   app writes; runs `PRAGMA integrity_check` on each snapshot).
3. On the new Mac, with the owning apps not running: `scripts/install-db-snapshots.sh` removes stale
   `-wal/-shm/-journal`, replaces each file atomically and integrity-checks it.
4. Repeat at the final sync (phase 11) with the apps stopped.

## Homebrew Postgres

Data lives outside the home folder (`/opt/homebrew/var/postgresql@NN`), and `brew bundle` creates a fresh
empty cluster per version.

- **Stopped cluster** (no `postmaster.pid`): copy the data directory as-is into a staging folder, move the
  fresh cluster aside (`postgresql@NN.fresh-initdb`, rollback), move yours into place, `chmod 700`, start
  it briefly on a spare port to list databases, stop it again if it was stopped on the old Mac. Newer
  *minor* versions read older data directories of the same major version.
- **Running cluster:** never copy the live directory. `pg_dumpall --clean --if-exists -f dump.sql`, start the
  new service, confirm it is empty, `psql -X -v ON_ERROR_STOP=0 -d postgres -f dump.sql`. Two errors are
  expected (dropping/creating the role you are connected as).
- **Prove it:** `scripts/pg-counts.sh` on both Macs → identical per-table exact row counts.
- Config: compare `postgresql.conf` non-comment lines; a stock config needs nothing.

## Redis

`redis-cli SAVE` on the old Mac, copy `/opt/homebrew/var/db/redis/dump.rdb` to the new Mac while Redis is
stopped there, start the service, compare `DBSIZE` and `redis-cli --scan | sort`. Diff `redis.conf`
non-comment lines; only added defaults/modules from a newer Redis means a stock config.

## Docker

Volumes live inside Docker Desktop's VM disk, not in project folders. Ask whether any volume matters
(dev databases); if yes, export it (`docker run --rm -v vol:/v -v $PWD:/b alpine tar czf /b/vol.tgz -C /v .`)
— otherwise install Docker Desktop only.

## Launch agents and services

- `brew services` entries: start them deliberately (`brew services start <name>`) after data is restored.
- The person's own LaunchAgents (`~/Library/LaunchAgents/*.plist`): read `ProgramArguments`,
  `WorkingDirectory`, log paths and environment; make sure every path exists on the new Mac (launchd does
  **not** create missing log directories), then `launchctl bootstrap gui/$(id -u) <plist>`; check the port
  or PID and the log.
- **Single-instance services — the most dangerous trap.** A service whose state is a *shared remote*
  resource (a cloud database, a job queue, a bot token, a LAN mDNS name) must run on one Mac at a time,
  or both copies process the same work. Check the service's config for its database URL / remote
  endpoints. Install it on the new Mac but keep its plist **outside** `~/Library/LaunchAgents` (otherwise it
  starts at next login); move it in at switch-over after stopping it on the old Mac.
- Local-only daemons (bound to 127.0.0.1 with local data) can run on both Macs; their data on the new Mac is
  overwritten by the final sync.

## Local web stacks

Reverse proxies with local certificates (Caddy `tls internal`, mkcert): copy the config, add `/etc/hosts`
entries (sudo), and install a new local CA with `caddy trust` / `mkcert -install` (sudo) rather than moving
the old CA's private key.
