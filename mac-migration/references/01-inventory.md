# Phase 1 — Inventory the old Mac (read-only)

Goal: know everything that exists before deciding what moves and how. Nothing in this phase changes
either Mac. Run `scripts/inventory.sh` for the bulk, then dig into whatever it flags.

## What to look at, and the question each answers

| Area | Command / place | Question it raises |
|---|---|---|
| Disk use | `du -sk ~/* ~/.[!.]*` (use `/usr/bin/du` if `du` is aliased) | What is big, and is it cache or data? |
| Homebrew | `brew tap`, `brew leaves`, `brew list --cask`, `brew bundle dump` | Fresh Brewfile is the install list |
| Apps | `/Applications`, `~/Applications`; App Store apps have `Contents/_MASReceipt` | Cask, App Store (`mdls -raw -name kMDItemAppStoreAdamID`), or copy as a bundle? |
| Toolchains | `~/.nvm/versions/node`, `~/.bun`, `~/.cargo/bin`, `rustup toolchain list`, `~/go/bin`, `uv tool list`, `~/.local/bin`, conda envs, `npm ls -g` | Copy as folders or reinstall? |
| Code | every `.git` under code folders: uncommitted count, unpushed commits (`git log --branches --not --remotes`), stashes, remote present | Which work exists only on this Mac? |
| Worktrees | `git worktree list --porcelain` per repo, `git -C <wt> status --porcelain` | Which worktrees hold real uncommitted work? |
| Secrets | `~/.ssh`, `~/.aws`, `~/.kube`, `~/.config/gh`, `.env*`, `*.jks *.keystore *.p12 *.pem *.p8` outside `node_modules` | Irreplaceable keys (e.g. app-store signing keys) |
| Keychain | `security dump-keychain ~/Library/Keychains/login.keychain-db` → service names only | Which logins will need redoing? |
| Launch agents | `~/Library/LaunchAgents`, `brew services list`, `launchctl list` | Which services must be recreated, and which are single-instance? |
| Databases | `/opt/homebrew/var/postgresql@*`, Redis `dump.rdb`, SQLite files held open (`lsof`), Docker volumes | What needs dumps/snapshots? |
| App data | `~/Library/Application Support/*` sizes, `~/Library/Preferences` third-party plists, `~/Library/Containers` | Config to copy vs re-login vs cache |
| Fonts etc. | `~/Library/Fonts`, `~/Library/Services` (Quick Actions), `~/Library/Spelling/LocalDictionary` | Small, easy, often forgotten |
| System level | `/etc/hosts`, `/etc/resolver`, `/etc/pam.d/sudo_local`, `/opt/homebrew/etc/*`, `/usr/local/bin` (non-Brew CLIs), `pmset -g custom`, custom trusted certs (`security dump-trust-settings -d`) | Needs sudo on the new Mac |
| iCloud | `find ~/Documents ~/Desktop -type f -flags +dataless` | Are Desktop/Documents mostly cloud-only? |
| Volumes | `diskutil info /Volumes/<X>`, `hdiutil info` | Encrypted APFS volume or disk image? |

## Reading the results well

- **Separate cache from data before proposing skips.** In one real home folder, 91 GB of 129 GB of code was
  `node_modules`; one agent CLI's package folder held 20 old self-updated releases; a self-hosted tool's
  install folder held two full copies. Show the person a size table split into "needed" and "regenerated automatically".
- **Look for repos that would lose work.** Count dirty files, unpushed commits and repos with no remote.
  These are the reason to copy folders instead of re-cloning.
- **Keychain service names tell you which logins are local.** Typical: `gh:github.com` (git push depends
  on it), `Claude Code-credentials`, `* Safe Storage` (Electron apps' encryption keys), CLI tokens
  (Supabase, Infisical, Docker, Hugging Face), VPN credentials.
- **Live SQLite files:** `lsof -nP +c 0 | awk '$NF ~ /\.(sqlite3?|db)(-wal)?$/'` and any `*-wal` files.
- **Symlinked CLIs** in `~/.local/bin`: note their targets (versioned folders) — they define which tool
  versions must be kept when skipping old versions.
- **Note things that are not PII-safe to print** (tokens in configs). Read key *names*, never values.

## Typical surprises

- Android release keystores (`*.jks`) sitting in `~/.android` — irreplaceable for app-store updates.
- Desktop/Documents synced with iCloud and evicted locally (only a few KB on disk).
- A self-hosted service whose database is a shared cloud Postgres (single-instance — see phase 8).
- A Postgres from Homebrew with data in `/opt/homebrew/var`, outside the home folder.
- Apps installed by hand that have no Homebrew cask (copy the bundle) and App Store apps (use `mas`).
