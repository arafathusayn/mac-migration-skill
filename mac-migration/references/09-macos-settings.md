# Phase 9 — macOS settings: copy only what is safe

Research behind this file (Apple's `defaults(1)` man page on macOS 26, Eclectic Light, Der Flounder,
scriptingosx, Bombich, Apple developer forums, mathiasbynens/dotfiles) is summarised in the sources list
at the end. Re-check on a newer macOS before relying on it.

## Rules

- **Use `defaults write` per key; never copy plist files.** cfprefsd caches preferences: a copied file is
  ignored or overwritten. Do not `killall cfprefsd` (unreliable).
- **Never import whole domains** except an app's own domain while that app is quit (Terminal, iTerm2).
  Global domains carry language, locale, Apple Account and Apple Intelligence state.
- **Back up first, per domain**, on the new Mac: `defaults export <domain> ~/mac-migration/new-mac-original-defaults/<domain>.plist`.
- **Rollback** is two steps, because `defaults import` *merges*: `defaults delete <domain>` then
  `defaults import <domain> <backup>`, then restart the process or log out.
- **ByHost files** carry the old Mac's hardware UUID in their names; use `defaults -currentHost write`.
- Run as the user, not root; over SSH the full-disk-access toggle must be on (sandboxed domains otherwise
  write to the wrong place).
- Read the old value's **type** first: `defaults read-type <domain> <key>` (`-bool`, `-int`, `-float`, `-string`).

## Verdict table

| Setting | Verdict | How |
|---|---|---|
| Dock size, autohide, recents, orientation, magnification, hot corners (`wvous-*`) | Safe | per-key, `killall Dock`; install the apps first |
| Dock app list (`persistent-apps`) and stacks (`persistent-others`) | Safe after apps exist | write `tile-data` dicts with `_CFURLString`; missing apps show "?" |
| Mission Control grouping (`expose-group-apps`) | Safe | per-key, `killall Dock` |
| Finder options (extensions, view style, path bar) | Safe | per-key, `killall Finder` |
| Trackpad (both trackpad domains) | Safe | per-key + `defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1`; log out |
| Screenshots (`com.apple.screencapture`) | Safe | location folder must exist; `killall SystemUIServer` |
| Custom keyboard shortcuts (`symbolichotkeys`) | Safe for changed ids | `-dict-add <id> …` per id; log out |
| Menu bar clock | Safe | per-key, `killall ControlCenter` or log out |
| Stage Manager / tiling / widget visibility (`WindowManager`) | Safe | per-key booleans |
| Spaces | Only `spans-displays` | other keys are display-specific |
| Global options (dark mode, double-click title bar, autocorrect/smart quotes, per-app shortcuts) | Safe per key | never the whole global domain |
| Terminal / iTerm2 profiles | Safe with app quit | `defaults import` of the app's own domain; iTerm2 DynamicProfiles as files |
| Editor/terminal config files (VS Code, Zed, Ghostty) | Safe | plain files |
| Wallpaper | Manual | store format changed on Tahoe; pick it again (Aerials re-download) |
| Desktop widgets | Manual | undocumented, sandboxed; re-add by hand |
| Finder sidebar favourites | Manual | binary archive managed by a daemon |
| Input sources / keyboard layouts (HIToolbox) | Manual | a wrong layout can make the login password fail |
| Menu bar / Control Center items | Manual | protected group container on Tahoe |
| Default browser / file-type handlers | Manual | confirmation prompts; LaunchServices database |
| Appearance (Liquid Glass, icon style) | Manual | no documented keys |
| Privacy permissions (TCC), login/background items, Touch ID | Not copyable | re-grant on first launch; re-enroll |

## Procedure per domain

1. Export the old Mac's domain (`defaults export`) and list non-default keys with their types.
2. Back up the new Mac's domain.
3. Write each key with the matching type flag over SSH; restart the owning process.
4. Read every key back on the new Mac and compare value and type; report a table.
5. Move to the next domain only when this one checks out.

## Sources

- `man defaults` (macOS 26) — https://leancrew.com/all-this/man/man1/defaults.html
- https://eclecticlight.co/2023/07/28/how-preferences-do-and-dont-work/
- https://eclecticlight.co/2019/08/22/working-safely-and-effectively-with-preferences-in-mojave/
- https://bombich.com/kb/ccc/3/computer-specific-preference-files-caveats-migrating-new-computer
- https://mjtsai.com/blog/2020/09/23/macos-containers-and-defaults/
- https://github.com/mathiasbynens/dotfiles/blob/main/.macos
- https://developer.apple.com/forums/thread/827337 (Tahoe menu bar storage)
- https://scriptingosx.com/2026/03/macos-26-4-brings-more-default-app-confirmation-prompts/
- https://objective-see.org/blog/blog_0x4C.html (TCC) · https://eclecticlight.co/2025/12/03/manage-login-and-background-items/
