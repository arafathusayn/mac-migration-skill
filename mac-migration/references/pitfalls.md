# Pitfalls catalogue — what actually went wrong, and the rule it produced

Read this once before starting. Each entry happened during a real migration.

## Trust and communication
1. **Saying a step was "queued" when no job was running.** The person later found the folder missing.
   → Start background jobs immediately or report the step as "not started". Keep a live status table.
2. **Assuming iCloud would bring Desktop/Documents.** The toggle was off on the new Mac; the folders were
   empty. → Verify arrival by counting files on the target; ask before deferring any personal folder.
3. **Promising to copy wallpaper and widgets before researching.** Research showed both unsafe on macOS 26.
   → Research first, then promise.

## Copy correctness
4. **An exclusion pattern removed git-tracked files** (`.DS_Store` committed in one repo; a `courses/` folder
   with tracked transcripts next to videos). → Check `git ls-files` before excluding a name; exclude by
   extension inside mixed folders; diff repo state on both Macs.
5. **Version pins vs auto-updates.** Keeping only "today's" tool version breaks the tool if it updates
   before the next sync. → Re-read symlinks before each sync; check for broken links after.
6. **Live SQLite copied raw**, with WAL files. → Online-backup snapshots; remove stale `-wal/-shm` on the target.
7. **openrsync rejected a forwarded option** (`--info=stats2`) and the transfer died at 0 bytes. → `--stats`.
8. **Homebrew packaging changes** (rustup launchers, app-bundle CLIs) broke copied symlinks. → `check-links.sh`.

## Secrets and identity
9. **Reading `security dump-keychain` with `grep -A`** attributed the next item's account to a service.
   → Parse per item block.
10. **Homebrew stripped the askpass variable**, so `sudo` got an empty password and logged failed attempts.
    → `HOMEBREW_`-prefixed copy; helper exits 1 when empty; test inside `brew ruby` first.
11. **Adding `/usr/bin/security` to a keychain item's ACL** to verify a hash lets any script read it.
    → Only when needed; remove afterwards.
12. **Treating a pairing tool's host keychain items as a "license".** They were the old Mac's identity.
    → Pair the new Mac; licenses usually live with the vendor account.
13. **Shared OAuth refresh tokens** between two Macs can log one of them out. → Fresh logins on the new Mac.

## Services and data
14. **A self-hosted service used a shared cloud database.** Starting it on the new Mac meant two instances
    processing the same queue. → Identify single-instance services; keep them on hold until switch-over.
15. **launchd did not create a missing log directory** for a copied LaunchAgent. → Create log dirs first.
16. **A browser opened before its key existed would have deleted every cookie.** → Key first, verify hash,
    then open; keep a pristine copy for rollback.

## Tooling (Claude Code on macOS)
17. `cd` into another folder in a Bash call can change the session's working directory — use absolute paths.
18. zsh glob qualifiers like `*(N)` may not work in the tool's shell; one unmatched glob aborts the whole
    command — use `find`.
19. Chat-run commands have no TTY: password prompts fail. Use the askpass dialog or the person's Terminal.
20. `timeout` is not installed on macOS by default: `perl -e 'alarm N; exec @ARGV' cmd`.
