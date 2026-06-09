# Readiness — registry, custom to-do & review

_Last updated: 2026-06-09 (Phase 1 wave 1 consolidated)._

## Summary

| Bucket | Count |
|---|---|
| Total apps | 533 |
| Sourced | 286 |
| **In REGISTRY (authored)** | **62** |
| Custom resolver to-do | 68 |
| Review | 78 |
| Ineligible | 10 |
| AutoPkg pending classification | 67 |
| Unsourced remaining | 247 |
| DRYRUN-clean | 0 (requires macOS) |

All registry rows are statically verified (live URL + version + livecheck where applicable) but **not** DRYRUN-validated. Run `DRYRUN=1 bash scripts/cask-master.sh` on a Mac.

## Registry apps (62) — token | source | artifact

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
| `achico` | github_tag | zip |
| `api-utility` | github_tag | zip |
| `barcode-producer` | direct | zip |
| `bartranslate` | github_tag | zip |
| `boring-notch` | github_tag | dmg |
| `brewmate` | github_tag | dmg |
| `caesium-image-compressor` | github_tag | dmg |
| `chromebuddy` | github_tag | zip |
| `close-desktop` | github_tag | dmg |
| `cloudtalk-phone` | electron | dmg |
| `corelcad` | direct | dmg |
| `cronica` | github_tag | zip |
| `desktop-icon-manager` | github_tag | zip |
| `dictation-daddy` | github_tag | dmg |
| `dropnote` | github_tag | zip |
| `figura` | github_tag | zip |
| `fivenotes` | direct | zip |
| `freeter` | electron | dmg |
| `fuzzlecheck-4` | direct | dmg |

## Custom resolver to-do (68)

Verified live download + version; URL needs a bespoke resolver. Per-app facts in [`custom-todo.md`](custom-todo.md).

`arclite-pro, barcode-studio, beam-studio, bimcollab-zoom, blink-eye, boundary, buhontfs, canister, capture-one, cascable-pro-webcam, cato-client, chatkit, cisco-audio-device, cloudya, code42, connectmenow4, conniepad, cotypist, cricut-design-space, cursor-teleporter, daylite, dedoose, delighted, dell-display-peripheral-manager, depnotify, dialpad-meetings, disk-space-analyzer, displaylink-manager, dropnotch, droppoint, eclipse-ide-for-embedded-cc-developers, eclipse-ide-for-scout-developers, editready, everweb, file-architect, filemail, fileminutes, final-draft-12, final-draft-13, flashpeak-slimjet, flexihub, flowjo, focusee, folge, fotomagico, frameio-transfer, grasshopper, guardian-browser, huddly, hudl-sportscode, ipsw-updater, jamf-connect-configuration, jamf-connect-login, lg-calibration-studio, microsoft-company-portal, microsoft-powershell, nvivo-14, nvivo-15, strongdm, synology-active-backup-for-business-agent, synology-drive-client, teamwire, trint, universal-type-client, visualz, vivi, windsurf, workbrew`

## Review / ineligible (88)

Per-app reasons are in the `bucket` column of [`../data/master-list.csv`](../data/master-list.csv) (gated, duplicate-of-existing-cask, unversioned, discontinued, Mac-App-Store-only).

