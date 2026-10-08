---
name: mac-migration
description: Move a person's whole working environment from an old Mac to a new Mac as a clean setup driven over SSH from the old Mac (instead of, or alongside, Apple's Migration Assistant) — inventory, Homebrew and apps, dotfiles and toolchains, code repos with uncommitted work, SSH keys and secrets, keychain-held logins, Chrome profiles with live sessions, local databases, background services, safe macOS settings, personal folders, encrypted volumes, verification, final sync and cleanup. Use this skill whenever someone mentions a new Mac or MacBook, moving or transferring anything (settings, apps, dotfiles, Homebrew packages, code, keys, browser logins, databases) from one Mac to another, setting up a new machine "like my old one", mirroring a developer environment, or asks what Migration Assistant would miss — even if they never say "migration".
---

# Mac migration (clean setup, driven from the old Mac)

This skill moves everything that matters from an **old Mac** (the source, where Claude runs) to a **new
Mac** (the target, reached over SSH), without carrying over hundreds of gigabytes of caches and cruft.
It was distilled from a real migration of a busy developer machine; every pitfall listed here actually
happened. The result should be a new Mac that behaves like the old one, with evidence (checksums, counts,
diffs) for every claim.

## Ground rules — and why they exist

1. **The old Mac is the source of truth.** Never delete, sign out of, or reconfigure anything on it beyond
   what a step needs. The person keeps it intact until they have verified the new Mac. Signing out of a
   website on the old Mac can kill the copied session on the new one.
2. **Never leave the new Mac broken.** Research before risky changes (macOS settings, keychain, browser
   data), back up before each change, change one area at a time, verify, and keep a rollback path.
   People migrating are usually on a deadline; a half-working machine costs them more than a slow one.
3. **Secrets never appear in the chat.** Passwords, tokens and keys travel through a native macOS dialog
   (`scripts/askpass.sh`) into a shell variable and over SSH stdin. Print only hashes or MATCH/MISMATCH.
4. **Proof, not claims.** Every "done" comes with evidence: rsync checksum dry-runs, file counts, git state
   diffs, row counts. Never say a step is "queued" unless a background job is actually running — people
   notice, and it destroys trust.
5. **The person decides what is skipped.** Propose exclusions (caches, models, old versions) with sizes,
   but never silently drop or defer anything personal (Desktop, Documents, Downloads, keys, `.env` files).
6. **Live data needs consistent copies.** A database or SQLite file that is being written must be dumped or
   snapshotted, not rsynced raw. A service that talks to a shared remote resource must run on one Mac only.

## How to run the migration

Work through the phases in order, but stay flexible: people interrupt with new priorities ("do Chrome
first"). Keep a running status table (format at the end) and report it whenever something finishes.
Each phase has a reference file with the exact commands and pitfalls; read it when you reach that phase.

| Phase | What | Read |
|---|---|---|
| 0 | Interview: approach, link, skip lists, priorities | (below) |
| 1 | Read-only inventory of the old Mac | `references/01-inventory.md` |
| 2 | Connect: Remote Login, SSH key, password dialogs, sudo, transfer speed | `references/02-connect-and-transfer.md` |
| 3 | Home folder: dotfiles, configs, toolchains (filtered rsync) | `references/03-home-and-toolchains.md` |
| 4 | Homebrew, casks, App Store, apps without a cask | `references/04-homebrew-and-apps.md` |
| 5 | Code: repos with uncommitted work, worktrees, `.env` files, keys | `references/05-code.md` |
| 6 | Secrets: keychain-held logins, keychain items, re-login list | `references/06-secrets-and-keychain.md` |
| 7 | Browsers: Chrome/Brave profiles with live sessions | `references/07-browsers.md` |
| 8 | Databases and background services | `references/08-databases-and-services.md` |
| 9 | macOS settings (Dock, Finder, trackpad, …) — only the safe ones | `references/09-macos-settings.md` |
| 10 | Personal folders, iCloud, encrypted volumes | `references/10-personal-data.md` |
| 11 | Switch-over, final sync, verification, cleanup | `references/11-final-sync-and-cleanup.md` |
| — | Pitfalls catalogue (read once at the start) | `references/pitfalls.md` |

### Phase 0 — Interview first

Collect these decisions before copying anything; ask them as a short multiple-choice batch, with sizes
from the inventory where you have them:

- **Approach.** Clean setup driven over SSH (this skill), or Apple Migration Assistant for a full clone.
  Migration Assistant is fine for non-developers; it also copies every cache and old version, and Homebrew
  often needs repair afterwards. A hybrid (Migration Assistant for one user folder) is rarely worth it.
- **Link.** A Thunderbolt/USB-C *data* cable between the Macs creates a Thunderbolt Bridge many times
  faster than Wi-Fi. A MagSafe or charge-only cable does not carry data. Over Wi-Fi expect 10–40 MB/s;
  plan small/critical items first.
- **Skip lists** (offer each with its size): Docker images/volumes; AI model weights (Ollama, LM Studio,
  Hugging Face cache, speech models); mobile toolchains (Android SDK/emulators, Java, Xcode simulators);
  old auto-updated tool versions; build outputs and dependency folders; installers; git worktrees;
  Pictures/Movies/Music; large app libraries.
- **Things people care about that tools usually miss:** browser sessions (cookies), app licenses, phone
  pairing apps, encrypted volumes, local databases, launch agents, fonts, Quick Actions.
- **Priorities.** Ask what they need working first (often: terminal + editor + browser + git push).

### Phase 1 — Inventory (read-only)

Run `scripts/inventory.sh` (read-only; writes a report to `~/mac-migration/inventory/`; add `--secrets`
to include a redacted gitleaks pass that shows which files hold secrets that must come along). It covers Homebrew,
apps by source, toolchains, sizes, repos with unpushed/uncommitted work, launch agents, keychain service
names (never values), databases, system-level config (`/etc/hosts`, `/opt/homebrew/etc`, trusted certs,
power settings). Summarise it for the person as a table: *what exists → how it gets to the new Mac*.
Details and the questions each finding raises: `references/01-inventory.md`.

### Phases 2–11

Follow the reference file for each phase. The short version:

2. **Connect.** The person enables Remote Login (+ "Allow full disk access for remote users", needed to
   write into `~/Library`). Install the old Mac's public key with `ssh-copy-id` in *their own* Terminal or
   through the askpass dialog — chat-run `!` commands have no TTY. Measure throughput with `dd | ssh`.
   Use `scripts/remote-sudo.sh` whenever the new Mac needs `sudo` (Homebrew, pkg installers, volumes).
3. **Home folder.** One filtered rsync of `$HOME` (template `assets/home.filter.example`): copy everything
   except named caches/data the person declined. Same paths and same user name make toolchains copy as-is.
   Afterwards check for broken symlinks (`scripts/check-links.sh`) — auto-updating CLIs and Homebrew
   layout changes break them.
4. **Homebrew.** Install Homebrew over SSH with `SUDO_ASKPASS`, then `brew bundle` from a fresh dump
   extended with casks for apps installed outside Brew. Expect disabled casks, removed formulae and pkg
   installers that need sudo (Homebrew strips the environment — see the reference).
5. **Code.** Copy repo folders, never re-clone: uncommitted work, stashes, unpushed branches and repos
   without a remote exist only on the old Mac. Exclude only dependency/build folders that git does not
   track, then prove it with `scripts/repo-state.sh` on both Macs.
6. **Secrets.** Many CLI and app logins live in the old Mac's *local* keychain and do not move with
   files. Give the person a re-login checklist; move individual keychain items only when needed
   (`scripts/keychain-item-transfer.sh`).
7. **Browsers.** Chrome profiles *with cookies* can move, but only together with the "Chrome Safe Storage"
   keychain key, placed **before Chrome's first launch** on the new Mac — otherwise Chrome silently deletes
   everything it cannot decrypt.
8. **Databases and services.** Dump/snapshot live databases; restore and compare row counts. Identify
   single-instance services (shared cloud DB, LAN announcers) and keep them on hold until switch-over.
9. **macOS settings.** Per-key `defaults write` for a researched safe list, with a backup and undo per
   domain; everything else is a short by-hand checklist.
10. **Personal data.** Verify Desktop/Documents/Downloads actually arrive (iCloud "Desktop & Documents" is
    often off on the new Mac). Recreate encrypted APFS volumes and copy their contents.
11. **Final sync.** Stop writers and single-instance services, take fresh snapshots, re-sync with a
    reviewed `--delete` dry-run, verify everything, move services over, then clean up migration artefacts
    and remote-access settings.

## Status report format

Report progress with this structure (fill in what applies, keep it short):

```markdown
| Item | Status | Evidence |
|---|---|---|
| SSH keys + config | ✅ done | 71 files, checksums identical |
| Code (N repos) | ✅ done | repo-state diff: identical except <expected> |
| Chrome profiles | ⏳ in progress | 2.1 / 3.3 GB |
| Homebrew bundle | ⚠️ 3 failed | <which, why, fix> |

**Needs you:** <dialogs to answer, things only the person can do>
**Next:** <ordered next steps>
```

## Scripts

All scripts are parameterised with environment variables (`NEW_MAC` = `user@host.local`,
`MIGRATION_SSH_KEY`, `MIGRATION_DIR` default `~/mac-migration`) and print usage with `-h`. Read a script
before running it; several pop up dialogs the person must answer.

| Script | Runs on | Purpose |
|---|---|---|
| `inventory.sh` | old | Read-only inventory report |
| `askpass.sh` | old | Native hidden-input dialog; prompt = first argument |
| `remote-sudo.sh` | old | Run a command on the new Mac with sudo, password from a dialog |
| `sudo-askpass.sh` | new | `SUDO_ASKPASS` helper that reads the password from the environment |
| `repo-state.sh` | both | One line per repo: HEAD, refs hash, stash count, status hash |
| `snapshot_dbs.py` | old | Consistent SQLite snapshots via the online backup API |
| `install-db-snapshots.sh` | new | Put snapshots in place safely and integrity-check them |
| `pg-counts.sh` | both | Exact row counts per table for a Postgres server |
| `keychain-item-transfer.sh` | old | Move one keychain item to the new Mac (dialogs, no printing) |
| `check-links.sh` | new | List broken symlinks in common tool bin folders |
| `fix-rustup-links.sh` | new | Repoint `~/.cargo/bin` proxies to Homebrew's rustup launchers |
| `create-encrypted-volume.sh` | old | Create an encrypted APFS volume on the new Mac |

`assets/` holds example rsync filters for the home folder, code, Chrome and Downloads.
