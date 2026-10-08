# Phase 2 — Connect the Macs and move data

## 1. Find the new Mac

```bash
perl -e 'alarm 5; exec @ARGV' dns-sd -B _companion-link._tcp local.   # names of nearby Macs
perl -e 'alarm 4; exec @ARGV' dns-sd -G v4 <Name>.local               # its IP
nc -z -G 3 <Name>.local 22 && echo "SSH open"                          # Remote Login on?
```
(`perl -e 'alarm N; exec @ARGV' cmd` bounds commands that never exit when `timeout` is not installed.)

## 2. What the person must do on the new Mac

1. Sign into their Apple ID (iCloud Drive, Passwords & Keychain).
2. System Settings → General → Sharing → **Remote Login** on → ⓘ → **Allow full disk access for remote
   users** on (without it, writes into `~/Library/Containers` and some `defaults` domains silently go
   elsewhere). Remember to turn the full-disk-access toggle off at the end.
3. Keep both Macs on power and near the router (or on a Thunderbolt data cable).

## 3. Install the SSH key

`ssh-copy-id` needs a password prompt. Commands typed through the chat (`!cmd`) have **no TTY** and send
empty passwords. Two working options:

- The person runs `ssh-copy-id -f -o PubkeyAuthentication=no -i ~/.ssh/id_ed25519.pub <user>@<new>.local`
  in their own Terminal. `-o PubkeyAuthentication=no` avoids "Too many authentication failures" when the
  agent holds many keys; `-f` skips the pre-check that fails the same way.
- Or run it with the dialog helper: `SSH_ASKPASS=scripts/askpass.sh SSH_ASKPASS_REQUIRE=force ssh-copy-id …`.

If login then fails with "Server accepts key" followed by "Permission denied", the private key has a
passphrase and the agent is empty: `SSH_ASKPASS=… SSH_ASKPASS_REQUIRE=force ssh-add ~/.ssh/id_ed25519 < /dev/null`.

Use explicit options everywhere: `ssh -o IdentitiesOnly=yes -i "$MIGRATION_SSH_KEY" "$NEW_MAC" …`.

## 4. sudo on the new Mac without a TTY

Homebrew's installer, `.pkg` casks, `diskutil apfs addVolume`, `/etc/hosts` edits and `pmset` need sudo.
Pattern (implemented by `scripts/remote-sudo.sh` + `scripts/sudo-askpass.sh`):

1. A dialog on the old Mac asks for the **new Mac's** login password into a shell variable.
2. It is piped over SSH stdin; the remote side does `IFS= read -r MIGRATION_SUDO_PW`, exports it **and**
   `HOMEBREW_MIGRATION_SUDO_PW`, sets `SUDO_ASKPASS=~/mac-migration/sudo-askpass.sh`, verifies once with
   `sudo -A -v`, runs the work, then `sudo -k` and unsets everything.
3. **Homebrew strips environment variables that do not start with `HOMEBREW_`** before it calls sudo, so
   the helper must read the `HOMEBREW_` copy too. The helper must `exit 1` when it has no password —
   printing an empty line makes sudo log three failed attempts per call. Before a `brew install` that
   needs sudo, test inside Homebrew's own environment:
   `brew ruby -e 'exit(system("/usr/bin/sudo","-A","-v") ? 0 : 1)'`.

## 5. Transfer tool and speed

- macOS ships **openrsync** (protocol 29) as `/usr/bin/rsync`. Install Homebrew `rsync` 3.x on the old Mac
  and pass `--rsync-path=/usr/bin/rsync` until the new Mac has Brew's rsync too.
- openrsync rejects some forwarded options: use `--stats`, not `--info=stats2` (fails instantly with
  "connection unexpectedly closed (0 bytes)"). `--info=progress2` is fine (local only).
- Fast cipher for LAN: `-e "ssh … -c aes128-gcm@openssh.com -o ServerAliveInterval=30"`.
- Measure: `dd if=/dev/zero bs=1m count=1024 | ssh … 'cat > /dev/null'` (≈18 MB/s on ordinary Wi-Fi).
- Keep both Macs awake: prefix long jobs with `caffeinate -ims`, and run `ssh … 'caffeinate -ims -t 14400'`
  in the background for the new Mac.
- Run anything longer than a minute as a background job and report its progress; never claim it started
  if it did not.
- Exit codes: 24 = files vanished during transfer (normal on a live system); 23 = some attributes not set
  (on a root-owned volume root, usually just its mtime — check with an itemized dry run `rsync -ani`).

## 6. Verification primitives

```bash
# content-identical? (no DIFF lines = identical)
rsync -an --checksum --out-format='DIFF %n' SRC/ "$NEW_MAC:DST/" | grep -v '/$'
# file counts
find DIR -type f | wc -l            # run on both sides
```
