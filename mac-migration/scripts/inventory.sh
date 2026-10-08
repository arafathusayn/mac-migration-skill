#!/bin/bash
# Read-only inventory of the OLD Mac for planning a migration. Changes nothing.
# Writes a Markdown report to $MIGRATION_DIR/inventory/report.md (default ~/mac-migration) and prints its path.
# Secret VALUES are never printed: keychain items are listed by service/account name only, and the optional
# gitleaks pass is run with --redact and reported as file + rule only.
#
# Usage: inventory.sh [--secrets] [code-dir ...]
#   code-dir defaults to whichever of ~/code ~/Projects ~/src ~/Developer ~/dev ~/work exist.
#   --secrets  also run `gitleaks dir --redact` over the code folders (needs gitleaks) to list where
#              secrets live, so none are left behind (e.g. untracked .env files).
set -u
[[ "${1:-}" == "-h" ]] && { sed -n '2,11p' "$0"; exit 0; }
SECRETS=0; [[ "${1:-}" == "--secrets" ]] && { SECRETS=1; shift; }
OUT="${MIGRATION_DIR:-$HOME/mac-migration}/inventory"; mkdir -p "$OUT"; R="$OUT/report.md"
DU=/usr/bin/du; GREP=/usr/bin/grep
CODE=("$@"); if [ ${#CODE[@]} -eq 0 ]; then for d in code Projects src Developer dev work; do [ -d "$HOME/$d" ] && CODE+=("$HOME/$d"); done; fi
h() { printf '\n## %s\n\n' "$1" >> "$R"; }
kb() { awk '{s=$1; $1=""; if (s>=1048576) printf "%7.1f GB %s\n", s/1048576, $0; else printf "%7.0f MB %s\n", s/1024, $0}'; }

{ echo "# Migration inventory — $(date '+%Y-%m-%d %H:%M %z')"; echo; sw_vers | tr '\n' ' '; echo; uname -m; } > "$R"

h "Disk"; df -h / /System/Volumes/Data 2>/dev/null >> "$R"

h "Largest items in the home folder"
find "$HOME" -mindepth 1 -maxdepth 1 -exec "$DU" -sk {} + 2>/dev/null | sort -rn | head -40 | kb | sed "s|$HOME/|~/|" >> "$R"

h "Homebrew"
if command -v brew >/dev/null; then
  { echo "taps: $(brew tap | wc -l | tr -d ' ')  leaves: $(brew leaves | wc -l | tr -d ' ')  casks: $(brew list --cask | wc -l | tr -d ' ')";
    echo; echo "services:"; brew services list 2>/dev/null | tail -n +2; } >> "$R"
else echo "not installed" >> "$R"; fi

h "Apps by source"
for base in /Applications "$HOME/Applications"; do
  for a in "$base"/*.app; do [ -d "$a" ] || continue
    src="manual"; [ -d "$a/Contents/_MASReceipt" ] && src="App Store id $(mdls -raw -name kMDItemAppStoreAdamID "$a" 2>/dev/null)"
    echo "- $(basename "$a") — $src — $(defaults read "$a/Contents/Info" CFBundleIdentifier 2>/dev/null)"
  done
done >> "$R"
echo "(Match 'manual' apps to casks with: brew info --cask --json=v2 <token>)" >> "$R"

h "Toolchains"
{ echo "node (nvm): $(ls "$HOME/.nvm/versions/node" 2>/dev/null | tr '\n' ' ')";
  echo "bun: $(command -v bun >/dev/null && bun --version)  globals: $(ls "$HOME/.bun/install/global/node_modules" 2>/dev/null | wc -l | tr -d ' ')";
  echo "rust: $(command -v rustup >/dev/null && rustup toolchain list | tr '\n' ' ')";
  echo "go bins: $(ls "$HOME/go/bin" 2>/dev/null | tr '\n' ' ')";
  echo "uv tools: $(command -v uv >/dev/null && uv tool list 2>/dev/null | $GREP -v '^-' | tr '\n' ' ')";
  echo "~/.local/bin: $(ls "$HOME/.local/bin" 2>/dev/null | tr '\n' ' ')";
  echo; echo "symlinked CLIs (version pins to keep):";
  find "$HOME/.local/bin" -maxdepth 1 -type l -exec sh -c 'printf "  %s -> %s\n" "$(basename "$1")" "$(readlink "$1")"' _ {} \; 2>/dev/null; } >> "$R"

h "Code repositories with work that exists only here"
echo "dirty | unpushed commits | stashes | remote | path" >> "$R"
for root in "${CODE[@]}"; do
  find "$root" -name node_modules -prune -o -name .git -type d -print 2>/dev/null | while IFS= read -r g; do
    r="${g%/.git}"
    d=$(git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    u=$(git -C "$r" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
    s=$(git -C "$r" stash list 2>/dev/null | wc -l | tr -d ' ')
    m=$(git -C "$r" remote 2>/dev/null | head -1); w=$(git -C "$r" worktree list 2>/dev/null | wc -l | tr -d ' ')
    [ "$d$u$s" != "000" ] || [ -z "$m" ] && echo "$d | $u | $s | ${m:-NO REMOTE} | ${r/#$HOME/~} (worktrees: $((w-1)))"
  done
done | sort -rn >> "$R"

h "Key and credential files outside node_modules (names only)"
find "$HOME" -maxdepth 5 \( -path "$HOME/Library" -o -path "$HOME/.Trash" -o -name node_modules -o -name .git \) -prune -o -type f \
  \( -name '*.jks' -o -name '*.keystore' -o -name '*.p12' -o -name '*.p8' -o -name '*.pem' -o -name 'id_*' -o -name '.env' -o -name '.env.*' -o -name '*.mobileprovision' \) \
  -print 2>/dev/null | sed "s|$HOME/|~/|" | head -300 >> "$R"

if [ $SECRETS -eq 1 ]; then
  h "gitleaks findings (redacted: file and rule only)"
  if command -v gitleaks >/dev/null; then
    for root in "${CODE[@]}"; do
      gitleaks dir "$root" --no-banner --redact --exit-code 0 --report-format json --report-path "$OUT/gitleaks.json" >/dev/null 2>&1
      python3 - "$OUT/gitleaks.json" "$HOME" >> "$R" <<'EOF'
import json, sys, collections
try: data = json.load(open(sys.argv[1]))
except Exception: data = []
c = collections.Counter((d.get("File","").replace(sys.argv[2], "~"), d.get("RuleID","")) for d in data)
for (f, rule), n in sorted(c.items()): print(f"- {f} — {rule} ×{n}")
print(f"({len(data)} findings)")
EOF
    done
    rm -f "$OUT/gitleaks.json"
  else echo "gitleaks not installed (brew install gitleaks)" >> "$R"; fi
fi

h "Login keychain items (service | account — names only)"
python3 - >> "$R" <<'EOF'
import subprocess, re, os
out = subprocess.run(["security", "dump-keychain", os.path.expanduser("~/Library/Keychains/login.keychain-db")],
                     capture_output=True, text=True).stdout
rows = set()
for blk in out.split("keychain: ")[1:]:   # one block per item; acct is printed BEFORE svce
    g = lambda k: (re.search(rf'"{k}"<blob>="([^"]*)"', blk) or [None, "-"])[1]
    svc = g("svce") if g("svce") != "-" else g("srvr")
    if not svc.startswith("com.apple."): rows.add(f"- {svc} | {g('acct')}")
print("\n".join(sorted(rows)))
EOF

h "Launch agents and daemons"
{ ls "$HOME/Library/LaunchAgents" 2>/dev/null; echo; ls /Library/LaunchAgents /Library/LaunchDaemons 2>/dev/null | $GREP -v '^com\.apple'; } >> "$R"

h "Databases"
{ ls -d /opt/homebrew/var/postgresql@* 2>/dev/null | while read -r d; do echo "- $d (running: $([ -f "$d/postmaster.pid" ] && echo yes || echo no))"; done
  [ -f /opt/homebrew/var/db/redis/dump.rdb ] && echo "- redis dump.rdb present"
  echo "SQLite files open now:"; lsof -nP +c 0 -u "$USER" 2>/dev/null | awk '$NF ~ /\.(sqlite3?|db)$/ {print "  " $1 " " $NF}' | sort -u | sed "s|$HOME/|~/|"; } >> "$R"

h "System-level configuration (needs sudo on the new Mac)"
{ echo "/etc/hosts custom lines:"; $GREP -v -E '^#|^$|localhost|broadcasthost' /etc/hosts
  echo "sudo Touch ID: $( [ -f /etc/pam.d/sudo_local ] && $GREP -c pam_tid /etc/pam.d/sudo_local || echo no)"
  echo "/etc/resolver: $(ls /etc/resolver 2>/dev/null | tr '\n' ' ')"
  echo "/opt/homebrew/etc: $(ls /opt/homebrew/etc 2>/dev/null | tr '\n' ' ')"
  echo "/usr/local/bin: $(ls /usr/local/bin 2>/dev/null | tr '\n' ' ')"
  echo "custom trusted roots:"; security dump-trust-settings -d 2>&1 | $GREP -E 'Cert [0-9]+:'
  echo "power:"; pmset -g custom | $GREP -E 'Power|sleep' ; } >> "$R"

h "Personal folders and iCloud"
for d in Desktop Documents Downloads Pictures Movies Music; do
  t=$(find "$HOME/$d" -type f 2>/dev/null | wc -l | tr -d ' '); dl=$(find "$HOME/$d" -type f -flags +dataless 2>/dev/null | wc -l | tr -d ' ')
  echo "- $d: $t files, $dl cloud-only" >> "$R"
done

h "Mounted volumes"
for v in /Volumes/*; do [ -d "$v" ] || continue; diskutil info "$v" 2>/dev/null | $GREP -E 'Volume Name|File System Personality|FileVault|Device Location|Volume Used Space' | tr -s ' ' >> "$R"; echo >> "$R"; done

echo "$R"
