# mac-migration — a Claude Code skill for moving to a new Mac

A [Claude Code](https://docs.claude.com/en/docs/claude-code) skill that migrates a whole working
environment from an old Mac to a new one as a **clean setup driven over SSH** — without dragging along
hundreds of gigabytes of caches, and without losing the things Migration Assistant and dotfile repos
usually miss.

It was distilled from a real migration of a busy developer Mac. Every pitfall in it actually happened.

## What it handles

- **Inventory** of the old Mac (read-only): Homebrew, apps by source, toolchains, repos with work that
  exists nowhere else, keychain-held logins, launch agents, databases, system-level config, iCloud state.
- **Connecting** two Macs without a TTY: SSH keys, native password dialogs, `sudo` over SSH (including
  Homebrew's environment stripping), openrsync quirks, throughput.
- **Home folder and toolchains** with one filtered rsync; version pins for self-updating CLIs; broken-link checks.
- **Homebrew** bundle (casks, App Store, apps without a cask), disabled casks and pkg installers.
- **Code**: copy repos instead of re-cloning (uncommitted work, stashes, `.env` files, keys), safe
  exclusions verified against git, worktrees, and a repo-state diff that proves both Macs match.
- **Secrets**: what moves as files, what lives only in the local keychain, moving single keychain items safely.
- **Browsers**: Chrome/Brave profiles **with live sessions** (the Safe Storage key must exist before first launch).
- **Databases and services**: consistent SQLite snapshots, Homebrew Postgres/Redis with row-count proofs,
  single-instance services that must never run on both Macs.
- **macOS settings**: a researched list of what is safe to copy with `defaults`, and what must be set by hand.
- **Personal data**: iCloud Desktop & Documents, encrypted APFS volumes.
- **Final sync and cleanup**: reviewed `--delete`, verification, moving services, removing migration access.

## Install

```bash
git clone https://github.com/arafathusayn/mac-migration-skill ~/src/mac-migration-skill
mkdir -p ~/.claude/skills
ln -s ~/src/mac-migration-skill/mac-migration ~/.claude/skills/mac-migration
```

Then, in Claude Code on the **old** Mac, say something like:

> I just got a new MacBook Pro on the same Wi-Fi. Help me move everything over — Homebrew, my dotfiles,
> my code, SSH keys, and keep me logged in to Chrome.

## Safety model

- Claude runs on the old Mac and changes the new Mac over SSH; the old Mac stays the untouched source of truth.
- Passwords, tokens and keys never appear in the chat: they go through a native macOS dialog and SSH stdin.
- Every step ends with evidence (checksums, file counts, git-state diffs, row counts).
- Nothing personal is skipped without the person's explicit decision.

Read `mac-migration/SKILL.md` and `mac-migration/references/pitfalls.md` before using it on a machine you care about.

## Repository hygiene: secrets and PII scanning

This repo is public, so every commit is scanned:

- **gitleaks** (secrets) and **`tools/pii_scan.py`** (e-mail and IP/MAC addresses, real home paths, `.local`
  host names, phone numbers, plus a private deny-list) run in a pre-commit hook and in GitHub Actions.
- Enable the hook in your clone: `git config core.hooksPath .githooks` (needs `brew install gitleaks`).
- Put personal terms you never want committed (names, employers, project names, handles) in
  `.pii-denylist` at the repo root, one per line. It is git-ignored on purpose.
- Run manually: `gitleaks dir . --redact --config .gitleaks.toml` and `python3 tools/pii_scan.py`.

## License

[Apache-2.0](LICENSE)
