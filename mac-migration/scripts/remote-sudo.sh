#!/bin/zsh
# Run a command on the NEW Mac with sudo available, without a TTY.
# The new Mac's login password is asked for in a dialog on THIS Mac, sent over the SSH connection's stdin,
# and kept only in that remote session's environment. Nothing is written to disk or printed.
#
# Usage:  NEW_MAC=user@host.local remote-sudo.sh '<command run by bash on the new Mac>'
# Example: remote-sudo.sh 'NONINTERACTIVE=1 /bin/bash ~/mac-migration/brew-install.sh'
#          remote-sudo.sh 'brew bundle --file ~/mac-migration/Brewfile --no-upgrade'
#          remote-sudo.sh 'brew ruby -e '"'"'exit(system("/usr/bin/sudo","-A","-v") ? 0 : 1)'"'"' && echo helper-ok'
# Env: NEW_MAC (required), MIGRATION_SSH_KEY (default ~/.ssh/id_ed25519), MIGRATION_DIR (default ~/mac-migration)
set -u
[[ "${1:-}" == "-h" || $# -lt 1 ]] && { sed -n '2,12p' "$0"; exit 0; }
: "${NEW_MAC:?set NEW_MAC=user@host.local}"
KEY="${MIGRATION_SSH_KEY:-$HOME/.ssh/id_ed25519}"
DIR="${MIGRATION_DIR:-~/mac-migration}"
HERE="${0:A:h}"
SSH=(/usr/bin/ssh -o IdentitiesOnly=yes -i "$KEY" -o ServerAliveInterval=30 "$NEW_MAC")

# make sure the helper is on the new Mac (resolve the folder to an absolute path there)
RDIR=$("${SSH[@]}" "mkdir -p $DIR && cd $DIR && pwd") || { echo "cannot reach the new Mac"; exit 1; }
/usr/bin/scp -q -o IdentitiesOnly=yes -i "$KEY" "$HERE/sudo-askpass.sh" "$NEW_MAC:$RDIR/sudo-askpass.sh" \
  && "${SSH[@]}" "chmod 700 '$RDIR/sudo-askpass.sh'" || { echo "could not install sudo-askpass.sh on the new Mac"; exit 1; }

PW=$("$HERE/askpass.sh" "Login password for your account on the NEW Mac ($NEW_MAC). Used by sudo for this step only; not stored.") || { echo "cancelled"; exit 1; }
[[ -n "$PW" ]] || { echo "empty password, stopping"; exit 1; }

printf '%s\n' "$PW" | "${SSH[@]}" "
IFS= read -r MIGRATION_SUDO_PW
export MIGRATION_SUDO_PW HOMEBREW_MIGRATION_SUDO_PW=\"\$MIGRATION_SUDO_PW\"
export SUDO_ASKPASS='$RDIR/sudo-askpass.sh'
export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin HOMEBREW_NO_ENV_HINTS=1 NONINTERACTIVE=1
/usr/bin/sudo -k
if ! /usr/bin/sudo -A -v 2>/dev/null; then echo 'SUDO PASSWORD CHECK FAILED (nothing was run)'; exit 2; fi
/bin/bash -c $(printf '%q' "$1")
rc=\$?
/usr/bin/sudo -k
unset MIGRATION_SUDO_PW HOMEBREW_MIGRATION_SUDO_PW
echo \"exit code: \$rc\"
exit \$rc
"
rc=$?
unset PW
exit $rc
