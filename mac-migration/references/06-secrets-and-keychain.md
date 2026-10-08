# Phase 6 — Secrets, keychain items and logins

## What moves as files

`~/.ssh` (all keys, `config`, `known_hosts`; never overwrite the new Mac's `authorized_keys`), `~/.aws`,
`~/.kube`, `~/.config/*` (gh config without tokens, gcloud, cloud CLIs), `~/.npmrc` (registry tokens),
`.env` files, signing keystores, `~/.gnupg` (stop `keyboxd` / `gpgconf --kill all` before the final
sync). Verify `~/.ssh` with checksums and permissions (`stat -f "%Sp %N"`; private keys must be 600).

Also check where configs reference key files (`IdentityFile` lines in `~/.ssh/config`): a key referenced
from `~/Downloads` or a project folder is easy to lose.

## What does not move: the local keychain

macOS stores many logins in the old Mac's **local** login keychain, which a clean setup does not copy.
iCloud Keychain only syncs website and Wi-Fi passwords. Read the service names (never values):

```bash
python3 - <<'EOF'
import subprocess, re
out = subprocess.run(["security", "dump-keychain", "/Users/" + __import__("getpass").getuser() +
                      "/Library/Keychains/login.keychain-db"], capture_output=True, text=True).stdout
for blk in out.split("keychain: ")[1:]:
    g = lambda k: (re.search(rf'"{k}"<blob>="([^"]*)"', blk) or [None, "-"])[1]
    print(g("svce"), "|", g("acct"))
EOF
```

**Parse per item block.** In `dump-keychain` output the `acct` attribute comes *before* `svce`;
`grep -A` after a service line reads the *next* item's account and leads to wrong conclusions.

Typical local-only items: `gh:github.com` (one per GitHub account — `git push` breaks without them),
AI CLI credentials, cloud CLI tokens, Docker Hub, VPN client credentials, and `<App> Safe Storage` keys
that Electron apps use to encrypt their saved sessions (copied app data cannot decrypt without them, so
Electron apps are better signed into fresh).

## Re-login or move the item?

- **Prefer a fresh login** for OAuth tools with rotating refresh tokens (AI CLIs, GitHub CLI): if two Macs
  share one refresh token, whichever refreshes first can invalidate the other. File-based logins that were
  copied (e.g. a CLI's `auth.json`) will work but carry the same risk — suggest re-login on the new Mac.
- **Move the item** only when it cannot be recreated (an encryption key such as Chrome's Safe Storage, a
  license blob). Use `scripts/keychain-item-transfer.sh`:
  1. Old Mac: `security find-generic-password -w -s <svc> -a <acct>` — the person sees a keychain prompt and
     clicks **Allow** (not *Always Allow*, which would weaken the old Mac's protection).
  2. New Mac (over SSH): `security unlock-keychain -p "$PW" login.keychain-db`, then
     `security add-generic-password -s <svc> -a <acct> -T "<app path>" -w "$VALUE"` and
     `security set-generic-password-partition-list -S teamid:<TEAMID> -s <svc> -a <acct> -k "$PW"`.
     The app's team id comes from `codesign -dv <App>.app 2>&1 | grep TeamIdentifier`.
  3. To prove the value matches you must be able to read it back; adding `-T /usr/bin/security` (and
     `apple-tool:` to the partition list) allows that silently — **for any script**. Do it only when a hash
     comparison is essential, and remove `security` from the item's Access Control afterwards
     (Keychain Access → item → Access Control → select `security` → "–" → Save).
- **Host identities are not licenses.** Items like `host-id` / `host-secret` from a phone-pairing tool
  identify the *old* Mac; copying them makes two machines claim one identity. Pair the new Mac instead.
  Licenses for such tools often live with the vendor account (App Store / Google Play / web key) and attach
  when the new Mac pairs.

## Licenses that are CLI-settable

Some apps expose their license through a CLI (e.g. a VPN client's `registration show` / `registration
license <key>`). Read the key on the old Mac into a variable, pipe it over SSH stdin, apply it, and print
only the resulting account type.

## The re-login checklist (give it to the person)

Group by urgency: (1) `gh auth login` for each account, AI CLI logins; (2) cloud/secret-manager CLIs;
(3) editor accounts and Settings Sync; (4) desktop apps (chat, meetings, VPN); (5) re-pair phone apps.
Also: old Mac keychain stays intact as a reference until the person signs off.
