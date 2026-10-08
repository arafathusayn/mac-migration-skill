# Phase 4 — Homebrew, casks, App Store apps and everything else

## Build the install list

1. `brew bundle dump --file=~/mac-migration/Brewfile --force` on the old Mac (fresh, not an old dotfiles copy).
2. Add casks for apps installed by hand. Map each `/Applications/*.app` to a cask by checking the app name
   the cask installs, not by guessing tokens:
   `brew info --cask --json=v2 <token…> | jq '.casks[] | {token, app: [.artifacts[] | .app? // empty]}'`.
   Watch for near-duplicates (`gemini` vs `google-gemini`, `telegram` vs `telegram-desktop`): compare the
   installed app's bundle id (`defaults read <App>.app/Contents/Info CFBundleIdentifier`).
3. App Store apps (have `Contents/_MASReceipt`): put them in a separate `Brewfile.mas` with
   `mas "Name", id: <kMDItemAppStoreAdamID>`; they install only after the person signs into the App Store.
4. Remove what the person declined (e.g. Android Studio, Java, Xcode) and anything they do not want
   reinstalled.
5. Remove `restart_service: :changed` from database/web-server formulae so `brew bundle` does not start
   Postgres/Redis/Caddy with empty data or default configs — services are started deliberately in phase 8.
6. Drop `go`/`cargo`/`uv`/`npm` lines when those tools arrive with the copied home folder; installing them
   concurrently with an in-flight copy of `~/.rustup` or `~/.cargo` can corrupt both.
7. Validate: `brew bundle list --file=Brewfile --all | wc -l`.

## Install Homebrew on the new Mac over SSH

The installer needs sudo (it creates `/opt/homebrew` and installs the Command Line Tools). It supports
`SUDO_ASKPASS` and `NONINTERACTIVE=1`. Download it to a file first, read it, then run it through
`scripts/remote-sudo.sh` (password dialog on the old Mac). The CLT install via `softwareupdate` happens
headless and takes 5–15 minutes. Its "Next steps" (`brew shellenv`) are already in the copied `.zprofile`.

## Run the bundle

Run `brew bundle --file=Brewfile --no-upgrade` through `scripts/remote-sudo.sh` with
`NONINTERACTIVE=1`, `HOMEBREW_NO_ENV_HINTS=1` and `PATH=/opt/homebrew/bin:…`. Expect:

| Failure | Cause | Action |
|---|---|---|
| `Cask '<x>' has been disabled because it does not pass the macOS Gatekeeper check` | Homebrew disabled it | Remove from Brewfile; install from the vendor only if the person needs it |
| `No available formula with the name "<x>"` | Formula removed (e.g. an abandoned tool) | Remove; suggest the successor |
| `.pkg` casks fail with "Sorry, try again … 3 incorrect password attempts" | Homebrew stripped the askpass env var | Use the `HOMEBREW_`-prefixed variable (see phase 2) and retry only those casks |
| `vscode` lines fail for one extension | Not on the Marketplace (installed from a `.vsix`) | Install from the `.vsix`, often bundled by the tool that installed it |

Casks whose apps need system extensions (VPNs, Docker) ask for approval on first launch — tell the person.

## Apps with no cask

Copy the bundle with Apple's `ditto`, which keeps code signatures, then verify:
```bash
ditto -c -k --keepParent "/Applications/App.app" - | ssh "$NEW_MAC" 'ditto -x -k - /Applications'
ssh "$NEW_MAC" 'codesign --verify --deep --strict "/Applications/App.app" && echo ok'
```
Never overwrite an existing app on the new Mac without asking.

## Editors

- **VS Code:** copy `~/Library/Application Support/Code/User/{settings.json,keybindings.json,mcp.json,snippets/,profiles/}`
  while VS Code has never run on the new Mac (no defaults to clash with); install extensions from the list:
  `code --install-extension a --install-extension b …` (one call). Compare `code --list-extensions` on
  both Macs; if Settings Sync is in use, tell the person to choose **Merge** when they sign in.
- **Zed, Ghostty, WezTerm, iTerm2 profiles:** plain files — copy, then validate (e.g. `ghostty +validate-config`).
  Fonts referenced by terminal configs live in `~/Library/Fonts`; copy those too or the config looks "stock".

## Command-line tools outside Homebrew

Check `/usr/local/bin` on the old Mac: many entries are symlinks created by apps (Docker, VPN clients,
editors) and come back when those apps install; some point into the home folder (copied) and need the
symlink recreated with sudo; some point at apps that are no longer installed (stale — skip).
