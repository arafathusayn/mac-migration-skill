#!/bin/sh
# Native macOS hidden-input dialog. Prints what the person typed to stdout.
# Usage: askpass.sh "Prompt text"
# Works as SSH_ASKPASS / SUDO_ASKPASS on the machine it runs on, and for capturing a secret into a shell
# variable without it ever appearing in a terminal or chat transcript.
[ "${1:-}" = "-h" ] && { sed -n '2,5p' "$0"; exit 0; }
PROMPT="${1:-Password:}"
case "$PROMPT" in -*) PROMPT=" $PROMPT" ;; esac   # osascript would read a leading "-" as an option
exec /usr/bin/osascript \
  -e 'on run argv' \
  -e 'text returned of (display dialog (item 1 of argv) default answer "" with hidden answer with title "Mac migration" with icon caution)' \
  -e 'end run' "$PROMPT"
