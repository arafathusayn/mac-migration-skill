# Phase 7 — Browsers with live sessions (Chrome, Brave, other Chromium browsers)

Most people only need browser **sync** (bookmarks, extensions, passwords). If they want every website to
stay logged in, the profile *and its cookies* must move — and cookies only survive with the browser's
encryption key.

## How Chromium protects cookies on macOS (verified against Chromium source, 2026)

- Cookies (`Network/Cookies` or `Cookies`), saved passwords (`Login Data`), cards and OAuth tokens are
  encrypted (prefix `v10`, AES-128-CBC) with a key derived from the login-keychain item
  **service "Chrome Safe Storage", account "Chrome"** (Brave: "Brave Safe Storage" / "Brave").
- App-Bound Encryption (`v20`) is Windows-only; no machine-bound field exists in `Local State` on macOS.
- **If the item is missing at first launch, Chrome creates a new random key and silently deletes every
  cookie and password it cannot decrypt.** There is no error. So the key must exist on the new Mac before
  Chrome is ever opened there.
- Device Bound Session Credentials (DBSC) bind some Google sessions to the Secure Enclave; Chrome's own
  sign-in can also be device-bound. Expect: Google account / Chrome Sync asks to sign in once per profile
  ("Paused"); local data stays. Passkeys stored only in the profile do not survive; iCloud/Google Password
  Manager passkeys do.

## Procedure

1. **Old Mac:** quit the browser completely (`pgrep -x "Google Chrome"` must be empty). Note the version;
   the new Mac's browser must be the **same or newer** (older Chrome cannot open a newer profile).
2. **Copy the profile to a staging folder** on the new Mac (not Chrome's real folder), excluding only
   caches and downloadable components (`assets/chrome.filter`). Keep Service Worker `CacheStorage` and
   `ScriptCache` — installed web apps depend on them. Never copy `Singleton*` lock files.
3. Verify the staging copy with a full `rsync -an --checksum` (no DIFF lines).
4. **New Mac:** install the browser (Homebrew cask) but do not open it. Check the signature and team id:
   `codesign -dv --verbose=4 "/Applications/Google Chrome.app"` → `TeamIdentifier=EQHXZ8M8AV` (Google LLC).
   Confirm `~/Library/Application Support/Google/Chrome` does not exist and no Safe Storage item exists.
5. `ditto` the staging copy into place; delete any `Singleton*` files; compare file counts. Keep the staging
   copy as a pristine rollback source (delete it at cleanup — it contains every cookie).
6. **Move the key** with `scripts/keychain-item-transfer.sh` using service `Chrome Safe Storage`, account
   `Chrome`, app `/Applications/Google Chrome.app`, team `EQHXZ8M8AV`, and `--verify-hash` so the script
   compares SHA-256 of the stored value with the old Mac's. Do not open Chrome unless it prints MATCH.
7. The person opens Chrome. If a keychain prompt appears: enter the login password, **Always Allow**, never
   Deny. If sites look logged out: quit immediately (⌘Q) — Chrome deletes undecryptable cookies while it runs.
8. Evidence that it worked (read-only, Chrome may be running):
   `sqlite3 "file:<profile>/Network/Cookies?mode=ro" "select count(*) from cookies"` per profile on both Macs.
   A profile that was opened should keep almost all cookies (a handful of device-bound ones may go).
9. Remove `/usr/bin/security` from the item's Access Control if `--verify-hash` added it.

**Rollback:** quit Chrome; delete `~/Library/Application Support/Google/Chrome` and
`~/Library/Caches/Google/Chrome`; `security delete-generic-password -s "Chrome Safe Storage" -a Chrome`;
redo from step 5 using the pristine copy.

## After the move

- Do not run the browser on both Macs at the same time, and **never sign out of websites on the old Mac** —
  both copies share the same sessions, so signing out there can end them on the new Mac too.
- Profiles that were signed in ask for a Chrome Sync sign-in once; sign into the same account the profile
  already uses and keep data in that profile.
- Installed web apps ("Chrome Apps" in `~/Applications`) are shims; Chrome can recreate them from
  `chrome://apps`.
