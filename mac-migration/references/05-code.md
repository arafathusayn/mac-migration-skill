# Phase 5 — Code repositories

## Copy folders, never re-clone

Re-cloning loses everything that exists only locally: uncommitted changes, untracked files (often `.env`
files and keys), stashes, unpushed branches, local-only repos, and LFS objects. Copy the code folder with
rsync and exclude only what can be regenerated.

## Exclusions that are safe

Dependency and build output folders that git does not track: `node_modules/`, `.next/`, `.turbo/`,
`.venv/`, `__pycache__/`, `target/`, `.gradle/`, `build/`, `dist/`, `.output/`, `storybook-static/`,
`.pnpm-store/`, `.svelte-kit/`, `.cache/`, `DerivedData/`, plus installers (`*.dmg *.pkg *.exe *.apk *.aab`).
These are usually 80–90% of a code folder's size.

**Prove each excluded folder name holds no tracked files before excluding it** — run in every repo:
```bash
git ls-files | grep -E '(^|/)(build|dist|out|\.output|storybook-static|\.pnpm-store|coverage)/'
```
and run a positive control on a pattern that must match (e.g. `src/`) so a broken loop cannot look like
"nothing found". Never exclude `.DS_Store` or a content folder wholesale (e.g. a `courses/` folder that
holds videos *and* tracked transcripts) — exclude by extension instead (`courses/**.mp4`).

Template: `assets/code.filter.example`.

## Worktrees

Worktree commits live in the main repo's `.git`, so they come over with it. Only **uncommitted** changes
inside a worktree folder are at risk. If the person wants worktrees skipped:

1. List every worktree: `git worktree list --porcelain` in each main repo.
2. For each existing worktree, `git -C <wt> status --porcelain`. Ignore scratch-only entries (`.tmp/`);
   save real changes (`git diff --output=<file>.patch` for edits, copy untracked files) into
   `~/mac-migration/worktree-rescue/`.
3. Exclude the worktree folders; after the copy, run `git worktree prune` in each main repo on the new Mac
   so git forgets the missing paths (otherwise their branches stay "checked out elsewhere").

## Secrets in repos

To see where secrets live before copying, run `scripts/inventory.sh --secrets`: it runs
`gitleaks dir --redact` over the code folders and reports only file + rule (never the value), which
doubles as a checklist of files that must arrive (untracked `.env` files are the usual surprise).

`.env` files and gitignored keys are copied automatically because rsync ignores `.gitignore`. Check that
none sit inside excluded folders: find every `.env*`, `*.jks`, `*.keystore`, `*.p12`, `*.p8`, `*.pem`,
`google-services.json`, `key.properties`, `local.properties` outside `node_modules`, then diff that list
against the rsync dry-run of included files. Files only found inside excluded worktrees are usually
`.env.example` templates already tracked in git — check by content hash before dismissing them.

## Verify

Run `scripts/repo-state.sh` on both Macs (one line per repo: path, HEAD, hash of all refs, stash count,
hash of `git status --porcelain --untracked-files=all`) and diff the outputs. Every difference must be
explained: an expected excluded folder that was untracked on the old Mac is fine; a tracked file showing
as deleted means the filter was wrong — fix the filter and re-run the copy (it only sends what is missing).

## Before handing over

- Dependencies are missing by design: projects need `bun install` / `pnpm install` / `uv sync` /
  `cargo build` on first use. Offer to do the person's active repos one at a time.
- `git push` over HTTPS often depends on `gh` credentials stored in the keychain (phase 6); SSH remotes
  work once the copied key's passphrase is entered.
