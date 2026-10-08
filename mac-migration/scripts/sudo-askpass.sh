#!/bin/sh
# SUDO_ASKPASS helper for the NEW Mac. Hands sudo the password held in the environment of one SSH session.
# Homebrew removes environment variables that do not start with HOMEBREW_ before it calls sudo, so the
# HOMEBREW_-prefixed copy is what reaches sudo during `brew install`. Exits non-zero (no password) instead
# of printing an empty line, so sudo stops at once rather than logging failed attempts.
# This file contains no secret.
PW="${MIGRATION_SUDO_PW:-${HOMEBREW_MIGRATION_SUDO_PW:-}}"
[ -n "$PW" ] || exit 1
printf '%s\n' "$PW"
