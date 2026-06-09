# Researching a cask: where each value comes from

Mine existing Mac-admin tooling instead of guessing. This file covers the five sources and the
on-Mac inspection commands. Speed order: existing cask → Installomator → AutoPkg → Munki → the
binary itself. Cross-check at least two sources for the download URL and version.

## Contents
- Existing casks (fastest template)
- Installomator labels
- AutoPkg recipes
- Munki pkginfo
- The app / pkg itself (authoritative for ids and min OS)
- On-Mac inspection commands
- How each field maps

---

## Existing casks
Search `Homebrew/homebrew-cask` for the same vendor or the same installer type and copy the shape.
- Browse `https://github.com/Homebrew/homebrew-cask/tree/master/Casks/<first-letter>` or
  `brew cat <similar-token>` on a Mac to dump a known-good cask.
- A vendor's *other* cask is the best template (same signing, same livecheck quirks). Microsoft,
  Barco, Twocanoes, etc. usually have a sibling cask to mirror.
- The cookbook is authoritative for DSL rules: `https://docs.brew.sh/Cask-Cookbook`.

## Installomator labels
Installomator encodes download URL, installer type, version-detection, and the signing Team ID
per app. Repo: `https://github.com/Installomator/Installomator` (labels in `Installomator.sh`, or
`fragments/labels/*.sh` in recent versions).
- Find the label: grep the repo / script for the app name.
- Resolve it live on a Mac without installing:
  `./Installomator.sh <label> DEBUG=2 INSTALL=0 NOTIFY=silent`
  prints the resolved `downloadURL`, `appNewVersion`, `expectedTeamID`, and `type`.
- A label exposes: `type` (`dmg`/`pkg`/`zip`/`appInDmgInZip`/`tbz`/…), `downloadURL`,
  `appNewVersion`, `expectedTeamID`, `blockingProcesses`, sometimes `packageID`/`CLIInstaller`.

Maps to cask: `downloadURL`→`url`; `type`→artifact stanza + the `verified:` host; `appNewVersion`
→`version`; `expectedTeamID`→use to verify the download you hashed (`codesign`/`spctl`);
`packageID`→`pkgutil:` receipt; `blockingProcesses`→`uninstall quit:` candidates.

## AutoPkg recipes
AutoPkg recipes describe how to fetch and package an app. Repos under
`https://github.com/autopkg` (search the org, or `autopkg search <app>` if AutoPkg is installed).
- `*.download.recipe(.yaml)` → the download source. Look at the processor:
  `URLDownloader`/`URLTextSearcher` (direct/scraped URL), `GitHubReleasesInfoProvider` (GitHub
  releases), `SparkleUpdateInfoProvider` (a Sparkle appcast — gold for livecheck).
- `*.pkg.recipe` / `*.munki.recipe` → bundle identifier (often an `Input` like `BUNDLE_ID`) and
  pkginfo (receipts, installs).

Maps to cask: download processor → `url` and the right livecheck `strategy` (Sparkle appcast →
`livecheck` with a `:sparkle` strategy); bundle id → `uninstall`/`zap` and FMA `unique_identifier`.

## Munki pkginfo
Munki pkginfo plists carry the cleanest install/uninstall metadata (AutoPkg often emits them).
Sources: a Munki repo's `pkgsinfo/`, AutoPkg `.munki` output, or `makepkginfo <installer>`.
Key fields:
- `installer_item_location` → the installer file (and often the URL).
- `receipts[].packageid` → pkg receipt ids for `uninstall pkgutil:`.
- `installs[]` items → `CFBundleIdentifier`, `CFBundleShortVersionString`, `minosversion`, `path`
  (the app bundle id, version, min OS, and install path).
- `minimum_os_version` → `depends_on macos:`.
- `items_to_copy[]` → for drag-installs, the `.app` name and destination (the `app` stanza).
- `blocking_applications` → `uninstall quit:` candidates.

## The app / pkg itself (authoritative)
Vendor pages and tooling can be stale; the bundle is the source of truth for ids and min OS.
- Bundle id + min OS from `Info.plist` (see commands below).
- pkg receipts from `pkgutil` after install, or by expanding the pkg without installing.

---

## On-Mac inspection commands

```bash
# sha256 of the exact download
curl -fL "$URL" -o /tmp/app.bin && shasum -a 256 /tmp/app.bin

# pkg: inspect receipts WITHOUT installing
pkgutil --expand-full /tmp/app.pkg /tmp/app-expand
/usr/bin/grep -R "identifier" /tmp/app-expand/*/PackageInfo   # receipt ids + min OS hints

# pkg receipts AFTER an install
pkgutil --pkgs | grep -i VENDOR
pkgutil --pkg-info com.vendor.pkg.App

# dmg: mount, read the app, detach
hdiutil attach /tmp/app.dmg -nobrowse
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "/Volumes/App/App.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "/Volumes/App/App.app/Contents/Info.plist"
hdiutil detach "/Volumes/App"

# zip: list, then inspect
unzip -l /tmp/app.zip
ditto -xk /tmp/app.zip /tmp/app-unzip

# installed app: bundle id + min OS
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier'     "/Applications/App.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "/Applications/App.app/Contents/Info.plist"

# signing Team ID (verify the download matches the vendor)
codesign -dvvv "/Applications/App.app" 2>&1 | grep TeamIdentifier

# leftover launch jobs + zap candidates (run after using the app)
sudo find /Library/LaunchDaemons /Library/LaunchAgents /Library/PrivilegedHelperTools \
          ~/Library -iname "*KEYWORD*" 2>/dev/null
```

Beware false positives in the `find` sweep: unrelated apps' manifests (e.g. ProfileCreator,
iMazing) can match a generic keyword. Only add paths that clearly belong to this app's bundle id.

## How each field maps (summary)
- `url` ← Installomator `downloadURL` / AutoPkg download processor / Munki `installer_item_location`.
- `version` ← Installomator `appNewVersion` / Munki `CFBundleShortVersionString` / vendor feed.
- installer type ← Installomator `type` / file extension.
- bundle id ← app `Info.plist` `CFBundleIdentifier` (cross-check Munki `installs`).
- pkg receipt ← `pkgutil` / Munki `receipts` / Installomator `packageID`.
- `depends_on macos:` ← app `LSMinimumSystemVersion` / Munki `minimum_os_version` (bare symbol).
- `uninstall launchctl:`/`quit:` ← the `find` sweep / Munki `blocking_applications`.
- livecheck ← Sparkle appcast (AutoPkg) / vendor JSON feed / redirect header / version-history page.
