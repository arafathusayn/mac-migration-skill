#!/bin/bash
# Run ON THE NEW MAC (normally via keychain-item-transfer.sh). Reads two lines from stdin:
#   1) the new Mac's login password (unlocks the login keychain over SSH), 2) the item's secret value.
# Creates a generic-password item trusted by one app and its signing team, and never prints the value.
# With --verify-hash, also trusts /usr/bin/security (apple-tool partition) so the value's SHA-256 can be
# printed for comparison — remove `security` from the item's Access Control afterwards.
# Usage: keychain-item-install.sh <service> <account> <app-path> <team-id> [--verify-hash]
set -u
[[ "${1:-}" == "-h" || $# -lt 4 ]] && { sed -n '2,8p' "$0"; exit 0; }
SVC="$1"; ACCT="$2"; APP="$3"; TEAM="$4"; VERIFY="${5:-}"
KC="$HOME/Library/Keychains/login.keychain-db"
IFS= read -r PW
IFS= read -r VAL
fail() { echo "FAILED: $1"; unset PW VAL; exit 1; }
[ -n "$PW" ] && [ -n "$VAL" ] || fail "missing input"
[ -e "$APP" ] || fail "app not found: $APP"
security find-generic-password -s "$SVC" -a "$ACCT" "$KC" >/dev/null 2>&1 && fail "item already exists (not overwriting)"
security unlock-keychain -p "$PW" "$KC" || fail "could not unlock the login keychain"
if [ "$VERIFY" = "--verify-hash" ]; then
  security add-generic-password -s "$SVC" -a "$ACCT" -T "$APP" -T /usr/bin/security -w "$VAL" "$KC" || fail "add"
  security set-generic-password-partition-list -S "apple-tool:,teamid:$TEAM" -s "$SVC" -a "$ACCT" -k "$PW" "$KC" >/dev/null || fail "partition list"
  unset PW VAL
  echo "STORED_SHA256=$(security find-generic-password -w -s "$SVC" -a "$ACCT" "$KC" | tr -d '\n' | shasum -a 256 | cut -d' ' -f1)"
else
  security add-generic-password -s "$SVC" -a "$ACCT" -T "$APP" -w "$VAL" "$KC" || fail "add"
  security set-generic-password-partition-list -S "teamid:$TEAM" -s "$SVC" -a "$ACCT" -k "$PW" "$KC" >/dev/null || fail "partition list"
  unset PW VAL
  security find-generic-password -s "$SVC" -a "$ACCT" "$KC" >/dev/null 2>&1 && echo "STORED (not readable by scripts)"
fi
