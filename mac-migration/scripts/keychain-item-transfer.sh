#!/bin/zsh
# Copy ONE generic-password keychain item from this (old) Mac to the new Mac over SSH. Prints no secrets.
# The person sees a keychain prompt on this Mac (click "Allow", not "Always Allow") and a dialog for the
# new Mac's login password. Use for things that cannot be recreated (e.g. a browser's Safe Storage key).
#
# Usage: NEW_MAC=user@host.local keychain-item-transfer.sh <service> <account> <app-path-on-new-Mac> <team-id> [--verify-hash]
# Chrome example:
#   keychain-item-transfer.sh "Chrome Safe Storage" Chrome "/Applications/Google Chrome.app" EQHXZ8M8AV --verify-hash
# Find the team id with: codesign -dv "/Applications/App.app" 2>&1 | grep TeamIdentifier
# With --verify-hash it prints MATCH/MISMATCH by comparing SHA-256 on both Macs; afterwards remove
# `security` from the item's Access Control on the new Mac (Keychain Access > Access Control).
set -u
[[ "${1:-}" == "-h" || $# -lt 4 ]] && { sed -n '2,12p' "$0"; exit 0; }
: "${NEW_MAC:?set NEW_MAC=user@host.local}"
SVC="$1"; ACCT="$2"; APP="$3"; TEAM="$4"; VERIFY="${5:-}"
KEY="${MIGRATION_SSH_KEY:-$HOME/.ssh/id_ed25519}"
DIR="${MIGRATION_DIR:-~/mac-migration}"
HERE="${0:A:h}"
SSH=(/usr/bin/ssh -o IdentitiesOnly=yes -i "$KEY" "$NEW_MAC")

RDIR=$("${SSH[@]}" "mkdir -p $DIR && cd $DIR && pwd") || { echo "cannot reach the new Mac"; exit 1; }
/usr/bin/scp -q -o IdentitiesOnly=yes -i "$KEY" "$HERE/keychain-item-install.sh" "$NEW_MAC:$RDIR/" || exit 1

VAL=$(security find-generic-password -w -s "$SVC" -a "$ACCT") || { echo "could not read '$SVC' on this Mac (prompt denied?)"; exit 1; }
[[ -n "$VAL" ]] || { echo "empty value"; exit 1; }
OLD=$(printf '%s' "$VAL" | shasum -a 256 | cut -d' ' -f1)
PW=$("$HERE/askpass.sh" "Login password for your account on the NEW Mac ($NEW_MAC). Unlocks its keychain to add '$SVC'; not stored.") || { echo "cancelled"; unset VAL; exit 1; }
OUT=$(printf '%s\n%s\n' "$PW" "$VAL" | "${SSH[@]}" "/bin/bash '$RDIR/keychain-item-install.sh' $(printf '%q ' "$SVC" "$ACCT" "$APP" "$TEAM" "$VERIFY")" 2>&1)
unset PW VAL
echo "$OUT" | grep -v '^STORED_SHA256='
if [[ "$VERIFY" == "--verify-hash" ]]; then
  NEW=$(echo "$OUT" | grep '^STORED_SHA256=' | cut -d= -f2)
  if [[ -n "$NEW" && "$NEW" == "$OLD" ]]; then echo "MATCH: identical value on both Macs"; else echo "MISMATCH or not stored - do not use the app yet"; exit 2; fi
fi
