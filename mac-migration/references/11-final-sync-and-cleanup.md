# Phase 11 — Switch-over, final sync, verification and cleanup

The bulk copies ran while the old Mac was in use. The final sync makes the new Mac current and consistent.
Do it when the person is ready to switch, with their go-ahead.

## 1. Stop writers and single-instance services (old Mac)

Quit agent CLIs/desktop apps that write databases; `launchctl bootout gui/$(id -u)/<label>` for the
person's own daemons and every single-instance service; `gpgconf --kill all`. Stop the same local daemons
on the new Mac so the sync is not overwritten underneath them.

## 2. Refresh pins and snapshots

- Re-read version symlinks of self-updating tools and update the home filter pins (phase 3).
- Fresh SQLite snapshots (`scripts/snapshot_dbs.py`), fresh `pg_dumpall`, `redis-cli SAVE`.

## 3. Re-sync with deletions, reviewed

Bulk passes only add and update; deletions and renames made on the old Mac since then would reappear.

```bash
rsync -a --delete --dry-run --itemize-changes --filter='merge home.filter' ~/ "$NEW_MAC:~/" | grep '^\*deleting'
```
Show the deletion list to the person, per area (code, agent configs, tool data). Run with `--delete` only
where nothing was edited on the new Mac. Never use `--delete-excluded` (it would wipe excluded folders on
the target). Folders the person may already be using on the new Mac (Desktop, Documents, Downloads) get
no `--delete`.

Then install the database snapshots, re-restore Postgres or compare counts again, reload Redis.

## 4. Verify everything

- Full checksum dry-run of each copied area (no DIFF lines).
- `scripts/repo-state.sh` diff on both Macs; `git worktree prune` in repos whose worktrees were skipped.
- `scripts/check-links.sh` prints nothing.
- Row counts, key counts, cookie counts as applicable.
- Each service: process running, port listening, log clean.

## 5. Move single-instance services

Stop on the old Mac (and disable its plist with the person's OK), move the plist into the new Mac's
`~/Library/LaunchAgents`, `launchctl bootstrap`, check it serves and that LAN names (mDNS) resolve to the
new Mac.

## 6. Clean up (security first)

- Delete staged copies that contain secrets: the pristine browser profile copy (every cookie), database
  dumps and snapshots, staged data directories.
- Remove any `/usr/bin/security` entry added to keychain-item Access Control for verification.
- Remove the migration SSH key line from the new Mac's `~/.ssh/authorized_keys`.
- The person turns off "Allow full disk access for remote users". Turn Remote Login off too unless they use
  it (phone terminal apps such as Moshi or Blink need it).
- Remind: FileVault on (often off after setup), Time Machine, re-login checklist, permissions/login items,
  manual settings list, and to keep the old Mac untouched (not signed out of anything) until they sign off.

## 7. Final report

One table per area with evidence, a "needs you" list, and what was deliberately left behind with sizes.
