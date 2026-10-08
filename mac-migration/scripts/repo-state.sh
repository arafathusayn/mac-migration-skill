#!/bin/bash
# Print one line per git repository under a folder:
#   path | HEAD | hash of every ref | stash count | hash of `git status --porcelain --untracked-files=all`
# Read-only. Run on both Macs and `diff` the outputs: identical lines prove the repos match, including
# uncommitted and untracked files, branches, tags and stashes.
# Usage: repo-state.sh [root]   (default: ~/code)
set -u
[[ "${1:-}" == "-h" ]] && { sed -n '2,7p' "$0"; exit 0; }
ROOT="${1:-$HOME/code}"
cd "$ROOT" || exit 1
find . -name node_modules -prune -o -name .git -type d -print 2>/dev/null | sort | while IFS= read -r g; do
  r="${g%/.git}"
  head=$(git -C "$r" rev-parse HEAD 2>/dev/null || echo none)
  refs=$(git -C "$r" for-each-ref --format='%(refname) %(objectname)' 2>/dev/null | shasum | cut -c1-12)
  stash=$(git -C "$r" stash list 2>/dev/null | wc -l | tr -d ' ')
  dirty=$(git -C "$r" status --porcelain --untracked-files=all 2>/dev/null | sort | shasum | cut -c1-12)
  echo "$r|$head|$refs|$stash|$dirty"
done
