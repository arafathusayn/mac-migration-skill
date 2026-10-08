# Phase 3 — Home folder, dotfiles and toolchains

## Strategy: copy everything except named exclusions

An allowlist always misses something (a CLI's config in an odd dot-folder, a token file). Instead copy all
of `$HOME` with a filter file that excludes only:

- folders handled by other phases: `code/`, `Library/`, `Desktop/`, `Documents/`, `Downloads/`,
  `Pictures/`, `Movies/`, `Music/`, `Applications/`, the staging folder;
- caches and rebuildable data: `.cache/` (keep specific runtimes a config points into), `.npm/_cacache`,
  `.bun/install/cache`, `.nvm/.cache`, `.cargo/registry`, `.cargo/git`, `.rustup/downloads`,
  `.yarn/berry/cache`, `.pulumi/plugins`, editor extension folders (reinstalled from a list),
  `.vscode-server`, `.zcompdump*`, `.Trash`;
- what the person declined (Docker data, AI models, mobile toolchains…);
- live sockets: `.ssh/agent/`, and **the new Mac's `.ssh/authorized_keys`** (it holds the migration key;
  merge entries by hand if needed).

Template: `assets/home.filter.example`. Always dry-run first to show size and file count:
`rsync -a --dry-run --stats --filter='merge home.filter' ~/ /tmp/x/`.

Because the user name and home path are the same on both Macs (and both are Apple Silicon), nvm Node
versions, Bun globals, `~/.local/bin` tools, uv Pythons, miniconda and Rust toolchains copy as-is.

## Keep only the current version of self-updating tools

Tools like Claude Code (`~/.local/share/claude/versions/*`), Codex (`~/.codex/packages/*/releases/*`) or
other CLIs installed from git keep every old version. The filter can keep just the current one:

```
+ /.local/share/claude/versions/<current>
- /.local/share/claude/versions/*
```

**Pitfall:** these tools auto-update. If a sync runs after an update with stale pins, the `current`
symlink is copied but its target is excluded → the command breaks. Re-read the symlinks
(`readlink ~/.local/bin/claude`, `…/current`) and update the pins before **every** sync, and run
`scripts/check-links.sh` on the new Mac after it.

## Toolchain checks after the copy

```bash
ssh "$NEW_MAC" 'export PATH=$HOME/.local/bin:$HOME/.bun/bin:$HOME/.cargo/bin:/opt/homebrew/bin:$PATH
  for t in node bun cargo rustc uv python3 go; do printf "%-8s %s\n" $t "$($t --version 2>&1 | head -1)"; done'
```

- **Rust via Homebrew `rustup`:** older formulae shipped one `rustup-init` that every proxy in
  `~/.cargo/bin` pointed at; newer ones (1.29+) ship a separate launcher per proxy and no `rustup-init`.
  Copied proxies then break, or report rustup's version instead of cargo's. Fix with
  `scripts/fix-rustup-links.sh` (points each proxy at `/opt/homebrew/opt/rustup/bin/<name>`).
- **CLIs that point into an app bundle** (e.g. a git GUI's CLI in `~/Applications/X.app`) break if the cask
  installs the app to `/Applications`. Repoint the symlink.
- **Deliberately skipped tools** leave dangling links (an AI tool whose data was skipped); list them for the
  person instead of silently deleting.

## Shell startup

After the copy, start a login shell on the new Mac: `ssh "$NEW_MAC" 'zsh -lic "echo OK"'`. Expect
"command not found" lines for tools Homebrew has not installed yet (starship, zoxide, fzf…); they disappear
after phase 4. Lines like `can't change option: zle` only appear because the test shell has no TTY.
Nothing in a normal `.zshrc` should stop a shell from opening; look for `exec` or `set -e` if it does.

## Shell files are live

`.zsh_history` and agent state change constantly. Re-sync shell files right before telling the person
they are done and prove it with checksums on both sides.
