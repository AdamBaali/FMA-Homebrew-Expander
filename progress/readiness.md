# Readiness — registry, custom to-do & review

_Last updated: 2026-06-09 (Phase 2 — github + subagent direct/electron/msft batches)._

## Summary

| Bucket | Count |
|---|---|
| Total apps | 533 |
| Sourced | 192 |
| **In REGISTRY (authored)** | **43** |
| Custom resolver to-do (verified, need resolve_/write_cask_) | 36 |
| Review (gated / dup / unversioned) | 42 |
| Ineligible | 3 |
| **DRYRUN-clean** | **0** (requires macOS) |

All registry rows are statically verified (live URL + version + livecheck source where applicable) but **not** DRYRUN-validated. Run `DRYRUN=1 bash scripts/cask-master.sh` on a Mac.

## Registry apps (token | source | artifact)

| token | source | artifact |
|---|---|---|
| `airbattery` | github_tag | dmg |
| `backgrounds` | github_tag | pkg |
| `elevate24` | github_tag | pkg |
| `escrow-buddy` | github_tag | pkg |
| `icons` | github_tag | pkg |
| `jamf-pppc-utility` | github_tag | zip |
| `jamf-printer-manager` | github_tag | zip |
| `jamf-reenroller` | github_tag | zip |
| `jamfcheck` | github_tag | dmg |
| `managed-app-schema-builder` | github_tag | zip |
| `mobile-to-local` | github_tag | zip |
| `pique` | github_tag | pkg |
| `sym-helper` | github_tag | zip |
| `utiluti` | github_tag | pkg |
| `airradar` | direct | dmg |
| `akvis-airbrush` | direct | dmg |
| `akvis-artifact-remover-ai` | direct | dmg |
| `akvis-frames` | direct | dmg |
| `alarm-clock-pro` | direct | dmg |
| `alivecolors` | direct | dmg |
| `atlassian-companion` | direct | zip |
| `automounter` | direct | dmg |
| `aws-cli` | direct | pkg |
| `brosix` | direct | pkg |
| `cakebrew` | direct | zip |
| `dragonframe-2024` | direct | pkg |
| `dragonframe-2025` | direct | pkg |
| `dragonframe-5` | direct | pkg |
| `grammarly` | direct | dmg |
| `hudl-studio` | direct | dmg |
| `lucidlink` | direct | pkg |
| `luna-display` | direct | dmg |
| `masv` | electron | dmg |
| `mestrenova` | direct | dmg |
| `microsoft-skype-for-business` | msft_cdn | pkg |
| `network-share-mounter` | direct | pkg |
| `nodejs` | direct | pkg |
| `particulars` | direct | pkg |
| `poll-everywhere` | direct | dmg |
| `screencloud-player` | electron | dmg |
| `signiant-app` | direct | dmg |
| `things` | direct | zip |
| `vonage-business` | electron | dmg |

## Watch at DRYRUN (known soft spots)

- **hudl-studio, mestrenova, particulars** — `direct` with bare `version=`, no livecheck (JS-rendered download page); audit will want a livecheck.
- **lucidlink, luna-display** — bare `version=`; both want a `:header_match` livecheck (version is in the redirect/filename) — convert to custom if audit insists.
- **vonage-business** — universal filename has a space (`Vonage Business-{v}-universal`); confirm URL-encoding resolves on Mac.
- **microsoft-skype-for-business** — EOL product; fwlink still serves a (MAU updater) pkg — confirm Fleet still wants it before submitting.
- **aws-cli / nodejs** — cask tokens intentionally differ from homebrew-core formulae `awscli` / `node` (no collision).
- **pique** — beta-only release (`0.1.0b5`): document the exception at PR time.
- **dragonframe-*** — dragonframe.com 406s a bare curl UA; may need `user_agent: :fake`.

## Custom resolver to-do (36)

Verified live download + version + livecheck, but URL doesn't fit a built-in source (arch-split non-electron, nested pkgInDmg/pkgInZip/appInDmgInZip, per-release hash, header-only version, or version:latest). Full per-app facts in [`custom-todo.md`](custom-todo.md). Author each as a resolve_<tfn>/write_cask_<tfn> pair on a Mac.

`beam-studio, capture-one, cato-client, cloudya, code42, cricut-design-space, daylite, dedoose, depnotify, displaylink-manager, everweb, final-draft-12, final-draft-13, flowjo, grasshopper, guardian-browser, huddly, hudl-sportscode, ipsw-updater, jamf-connect-configuration, jamf-connect-login, lg-calibration-studio, microsoft-company-portal, microsoft-powershell, nvivo-14, nvivo-15, strongdm, synology-active-backup-for-business-agent, synology-drive-client, teamwire, trint, universal-type-client, visualz, vivi, windsurf, workbrew`

## Review / ineligible (do not author)

| token | verdict | reason |
|---|---|---|
| `2do` | no | ineligible-mas-only |
| `acoustica` | review | Acon Digital Acoustica (v7.7.8, bundle com.AconDigital.Acoustica). Reason: gated |
| `acronis-cyber-protect-connect-client` | review | web-sourced-review |
| `adobe-acrobat` | review | web-sourced-review |
| `adobe-dynamic-media-classic` | review | web-sourced-review |
| `agenda` | review | Agenda by Momenta B.V. Reason: mas-only. agenda.com offers only the Mac App Stor |
| `amazon-corretto-11` | review | duplicate of existing Homebrew cask corretto@11 |
| `amazon-corretto-17` | review | duplicate of existing Homebrew cask corretto@17 |
| `amazon-corretto-21` | review | duplicate of existing Homebrew cask corretto@21 |
| `amazon-corretto-22` | review | EOL/non-LTS; Homebrew dropped corretto@22. Download exists arch-split: https://c |
| `amazon-corretto-8` | review | duplicate of existing Homebrew cask corretto@8 |
| `anaconda-navigator` | review | Reason: duplicate. Anaconda Navigator is not a standalone installer; it ships in |
| `anka` | review | Reason: exists. 'anka' resolves to Anka Virtualization (veertu-latest redirects |
| `apache-netbeans-15` | review | Reason: exists. The Friends-of-Apache-NetBeans/netbeans-installers repo is alrea |
| `app-cleaner-and-uninstaller` | review | Reason: exists. Slug/name match Nektony "App Cleaner & Uninstaller" already ship |
| `appgate-sdp` | review | web-sourced-review |
| `atera-agent` | review | web-sourced-review |
| `azul-zulu-jdk-11` | review | duplicate of existing Homebrew cask zulu@11 |
| `azul-zulu-jdk-17` | review | duplicate of existing Homebrew cask zulu@17 |
| `azul-zulu-jdk-21` | review | duplicate of existing Homebrew cask zulu@21 |
| `azul-zulu-jdk-8` | review | duplicate of existing Homebrew cask zulu@8 |
| `container` | review | homebrew-core formula collision; apple CLI runtime |
| `docker` | review | duplicate of existing Homebrew cask docker-desktop (Docker Desktop) |
| `dockutil` | review | homebrew-core formula collision (brew install dockutil) |
| `doctolib` | review | https://ddv-install.doctolib.fr/DoctolibProDesktop-latest-arm64.dmg = HTTP 200 b |
| `dstny` | review | https://soft.dstny.se/dstny_mac.dmg = HTTP 200 application/octet-stream but URL |
| `epos-connect` | review | Current Mac version 8.3.0.49911 (MacUpdater, 2025-09-22) but the direct .pkg URL |
| `homebrew` | no | bogus: Homebrew itself, not a cask |
| `jupyterlab` | review | formula collision + arch-split; needs token jupyterlab-desktop + custom |
| `mist-cli` | review | homebrew-core formula collision (brew install mist-cli) |
| `nextcloud-desktop-client` | review | duplicate of existing cask 'nextcloud' |
| `obs-studio` | review | duplicate of existing cask 'obs' |
| `onscreen-control` | review | REVIEW: broken. Installomator label 'onscreencontrol' is flagged broken (issue # |
| `plantronics-hub` | review | REVIEW: discontinued. https://www.poly.com/content/dam/www/software/PlantronicsH |
| `projectplace` | review | REVIEW: unversioned, no livecheck. https://service.projectplace.com/client_apps/ |
| `rhino-7` | review | REVIEW: paid, gated. Rhino is commercial (McNeel). No public unauthenticated ver |
| `rhino-8` | review | REVIEW: paid, gated. Same as rhino-7: commercial McNeel app, download behind com |
| `sketchup-viewer` | no | SketchUp Viewer for Desktop discontinued; "Beginning April 22, 2025, SketchUp Vi |
| `soundly` | review | Only an unversioned always-latest dmg: https://storage.googleapis.com/soundlyapp |
| `splashtop-sos` | review | Only an unversioned always-latest dmg: https://download.splashtop.com/sos/Splash |
| `surfdrive` | review | Gated. Installomator source page (servicedesk.surf.nl/wiki/.../74225443) is logi |
| `ultracompare` | review | Only an unversioned dmg https://downloads.ultraedit.com/main/uc/mac/UltraCompare |
| `xink` | review | account-gated SaaS email-signature client; download https://downloads.xink.io/ma |
| `zerotier` | review | duplicate of existing Homebrew cask zerotier-one (ZeroTier One) |
| `zoho-workdrive-genie` | review | download confirmed (200, ~55MB) https://www.zoho.com/workdrive/downloads/edit-to |
