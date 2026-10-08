#!/bin/zsh
# Create an encrypted APFS volume on the NEW Mac that mirrors one on the old Mac (run on the OLD Mac).
# Three dialogs: the new Mac's login password (sudo), the new volume's password, and that password again.
# Stops if the two volume passwords differ (a typo would lock the person out of their own data).
# Prints no secrets. Copy the data afterwards with rsync and verify with a checksum dry run.
#
# Usage: NEW_MAC=user@host.local create-encrypted-volume.sh <VolumeName> [container=disk3] [APFS|"Case-sensitive APFS"] [owner:group] [mode]
# Example: create-encrypted-volume.sh Backup disk3 APFS root:admin 775
# Read the old volume first: diskutil info /Volumes/<Name>; diskutil apfs list; ls -ld /Volumes/<Name>
set -u
[[ "${1:-}" == "-h" || $# -lt 1 ]] && { sed -n '2,10p' "$0"; exit 0; }
: "${NEW_MAC:?set NEW_MAC=user@host.local}"
NAME="$1"; CONT="${2:-disk3}"; FS="${3:-APFS}"; OWNER="${4:-}"; MODE="${5:-}"
KEY="${MIGRATION_SSH_KEY:-$HOME/.ssh/id_ed25519}"
DIR="${MIGRATION_DIR:-~/mac-migration}"
HERE="${0:A:h}"
SSH=(/usr/bin/ssh -o IdentitiesOnly=yes -i "$KEY" "$NEW_MAC")

RDIR=$("${SSH[@]}" "mkdir -p $DIR && cd $DIR && pwd") || { echo "cannot reach the new Mac"; exit 1; }
/usr/bin/scp -q -o IdentitiesOnly=yes -i "$KEY" "$HERE/sudo-askpass.sh" "$NEW_MAC:$RDIR/" && "${SSH[@]}" "chmod 700 '$RDIR/sudo-askpass.sh'" || exit 1

SPW=$("$HERE/askpass.sh" "1 of 3 — Login password for your account on the NEW Mac. Needed to create the volume; not stored.") || exit 1
VPW=$("$HERE/askpass.sh" "2 of 3 — Choose the PASSWORD for the new encrypted volume “$NAME” on the new Mac.") || { unset SPW; exit 1; }
VPW2=$("$HERE/askpass.sh" "3 of 3 — Type the “$NAME” volume password AGAIN to confirm.") || { unset SPW VPW; exit 1; }
if [[ -z "$VPW" || "$VPW" != "$VPW2" ]]; then echo "The volume passwords did not match (or were empty). Nothing was created."; unset SPW VPW VPW2; exit 2; fi
unset VPW2

printf '%s\n%s\n' "$SPW" "$VPW" | "${SSH[@]}" "
IFS= read -r SPW; IFS= read -r VPW
export MIGRATION_SUDO_PW=\"\$SPW\" SUDO_ASKPASS='$RDIR/sudo-askpass.sh'
fail() { echo \"FAILED: \$1\"; /usr/bin/sudo -k; exit 1; }
diskutil info $(printf '%q' "/Volumes/$NAME") >/dev/null 2>&1 && fail 'a volume is already mounted with that name'
/usr/bin/sudo -k; /usr/bin/sudo -A -v 2>/dev/null || fail 'sudo password check failed (nothing created)'
printf '%s' \"\$VPW\" | /usr/bin/sudo -A /usr/sbin/diskutil apfs addVolume $(printf '%q ' "$CONT" "$FS" "$NAME") -stdinpassphrase >/dev/null || fail 'diskutil apfs addVolume'
unset VPW SPW
sleep 2
diskutil info $(printf '%q' "/Volumes/$NAME") >/dev/null 2>&1 || fail 'created but not mounted'
[ -n $(printf '%q' "$OWNER") ] && /usr/bin/sudo -A chown $(printf '%q' "$OWNER") $(printf '%q' "/Volumes/$NAME")
[ -n $(printf '%q' "$MODE") ] && /usr/bin/sudo -A chmod $(printf '%q' "$MODE") $(printf '%q' "/Volumes/$NAME")
/usr/bin/sudo -k; unset MIGRATION_SUDO_PW
diskutil info $(printf '%q' "/Volumes/$NAME") | grep -E 'Device Identifier|Volume Name|File System Personality|FileVault|Owners'
ls -ld $(printf '%q' "/Volumes/$NAME")
"
rc=$?
unset SPW VPW
exit $rc
