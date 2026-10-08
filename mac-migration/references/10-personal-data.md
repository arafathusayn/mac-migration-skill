# Phase 10 — Personal folders, iCloud and encrypted volumes

Personal folders are where people notice gaps first. Treat "it will come via iCloud" as a claim to verify,
not a plan. Only skip what the person explicitly chose to skip.

## Desktop and Documents with iCloud

If the old Mac uses iCloud "Desktop & Documents Folders", most files are cloud-only placeholders
(`find ~/Documents -type f -flags +dataless | wc -l`). Two clean options — ask which:

1. **Via iCloud (no copying):** the person turns on System Settings → [name] → iCloud → iCloud Drive →
   Desktop & Documents Folders on the new Mac. Verify file counts on both Macs afterwards. If the toggle is
   off on the new Mac, its Desktop/Documents stay empty — check, do not assume.
2. **Copy with rsync:** first materialise the cloud-only files on the old Mac. `brctl download` may do
   nothing; reading each file works:
   `find ~/Desktop ~/Documents -type f -flags +dataless -print0 | xargs -0 -n 4 -P 12 cat > /dev/null`
   then retry timeouts one by one and confirm `-flags +dataless` count is 0. Copy, verify by checksum and
   counts. **Afterwards the person must not enable iCloud Desktop & Documents on the new Mac**: macOS would
   keep the copied files in a separate "Desktop/Documents - <Mac>" folder (duplicates), and edits on the new
   Mac would not sync to iCloud.

Before copying into a folder the person may already be using on the new Mac, list what is there and check
name collisions by hash; copy without `--delete`.

## Downloads, Music, Public, ~/Applications

- Downloads: usually wanted minus installers (`assets/downloads.filter.example`). Check for keys or
  certificates referenced by configs (`~/.ssh/config` `IdentityFile` lines pointing into Downloads).
- `~/Applications` holds browser web-app shims and small helper apps; ask.
- Pictures/Movies: ask; large photo or video folders are often better moved by the person to iCloud Photos
  or an external disk.

## Encrypted APFS volumes

A volume like `/Volumes/Backup` may be an encrypted APFS volume on the internal disk (not a disk image).
Inspect: `diskutil info /Volumes/X` (FileVault: Yes, File System Personality, case sensitivity) and
`diskutil apfs list` (quota/reserve, role). Mirror it:

1. Create the same kind of volume on the new Mac: `scripts/create-encrypted-volume.sh` (asks for the new
   Mac's password and, twice, the new volume's password; stops if the two differ — a typo would lock the
   person out of their own data). Underneath: `diskutil apfs addVolume disk3 APFS <Name> -stdinpassphrase`
   (or `"Case-sensitive APFS"`), then match the root folder's owner and mode.
2. Copy the user data (skip `.Spotlight-V100`, `.fseventsd`, `.Trashes`, `.TemporaryItems`,
   `.DocumentRevisions-V100` — each volume creates its own).
3. Verify by checksum. Files the person adds on the new volume and Finder's `.DS_Store` are expected diffs.
4. Tell them how to change the password later: Disk Utility → File → Change Password, or
   `diskutil apfs changePassphrase <diskXsY> -user disk` (interactive; never put passwords on the command line).

For encrypted disk images (`.dmg`, `.sparsebundle`): copy the image file itself while unmounted — it keeps
its encryption and password.
