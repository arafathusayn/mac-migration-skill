<div align="center">

# mac-migration

**Move to a new Mac without losing a thing.**

A [Claude Code](https://docs.claude.com/en/docs/claude-code) skill that sets up your new Mac over Wi-Fi,<br>
one checked step at a time.

[![CI](https://github.com/arafathusayn/mac-migration-skill/actions/workflows/scan.yml/badge.svg)](https://github.com/arafathusayn/mac-migration-skill/actions/workflows/scan.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

</div>

<br>

## Why

Migration Assistant copies everything, including years of junk.
A dotfiles repo copies too little.
This skill sits in the middle.

Claude looks at your old Mac first and asks what you want to keep.
Then it builds the new Mac for you and checks its own work.

It comes from a real move of a busy developer Mac.
Every warning in it is something that really went wrong.

## What it moves

| | |
|:--|:--|
| ⌘ **Apps** | Homebrew and App Store apps, plus a to-do list for the rest |
| ⌂ **Home folder** | Dotfiles, shell setup, tool configs and fonts |
| ‹/› **Code** | Every repo as it is, with uncommitted work, stashes and `.env` files |
| ◈ **Secrets** | SSH keys, plus keychain logins moved one by one |
| ◎ **Browsers** | Chrome profiles that stay logged in |
| ≣ **Databases** | SQLite, Postgres and Redis, copied safely and checked |
| ⌥ **Settings** | Only the macOS settings that are safe to copy |
| ❐ **Your files** | Desktop, Documents, Downloads and encrypted disks |

## How it works

1. **Look.** Claude scans the old Mac. It changes nothing.
2. **Ask.** You decide what moves and what stays behind.
3. **Connect.** The old Mac talks to the new one over SSH.
4. **Copy.** Apps, files, code, secrets, browsers and databases.
5. **Prove.** Checksums, file counts and git diffs show both Macs match.
6. **Switch.** One last sync. Then clean up and move in.

## Install

```bash
git clone https://github.com/arafathusayn/mac-migration-skill ~/src/mac-migration-skill
mkdir -p ~/.claude/skills
ln -s ~/src/mac-migration-skill/mac-migration ~/.claude/skills/mac-migration
```

## Use

Put both Macs on the same network.
Turn on **Remote Login** on the new Mac (System Settings → General → Sharing).
Then open Claude Code on your **old** Mac and say:

> I got a new MacBook. It's on the same Wi-Fi. Help me move everything over.

Claude will guide you from there.

## Safe by design

✓ **Your old Mac stays the source of truth.** Nothing on it gets deleted.<br>
✓ **Passwords stay out of the chat.** You type them into a macOS dialog.<br>
✓ **Every step ends with proof,** not a promise.<br>
✓ **Nothing personal is skipped** unless you say so.

> [!TIP]
> Read [the pitfalls](mac-migration/references/pitfalls.md) before you start. It is a short list of what went wrong last time.

## What's inside

```
mac-migration/
├── SKILL.md       the plan Claude follows
├── references/    one guide for each step
├── scripts/       helpers to copy, check and prove
└── assets/        example rsync filters
```

## Contributing

This repo is public, so every commit is scanned for secrets and personal info.
Turn on the check in your clone:

```bash
brew install gitleaks
git config core.hooksPath .githooks
```

The hook runs [gitleaks](https://github.com/gitleaks/gitleaks) and a small PII scanner.
GitHub Actions runs both again on every push.

Want to block your own names or project names?
Add them to `.pii-denylist`, one per line.
Git ignores that file, so it never leaves your Mac.

## License

[Apache-2.0](LICENSE)
