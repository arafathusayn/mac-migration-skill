#!/bin/bash
# List broken symlinks in the usual command folders (run on the NEW Mac after each home-folder sync).
# Auto-updating CLIs, skipped tool data and Homebrew packaging changes all leave dangling links here.
# Prints nothing when every link resolves. Usage: check-links.sh [extra-dir ...]
set -u
[[ "${1:-}" == "-h" ]] && { sed -n '2,4p' "$0"; exit 0; }
for d in "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.bun/bin" "$HOME/go/bin" "$HOME/.deno/bin" /opt/homebrew/bin /usr/local/bin "$@"; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | while IFS= read -r l; do
    printf '%s -> %s\n' "$l" "$(readlink "$l")"
  done
done
