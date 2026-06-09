# Readiness — registry, custom to-do & review

_Last updated: 2026-06-09 (author batch C)._

## Summary

| Bucket | Count |
|---|---|
| Total apps | 533 |
| Sourced | 533 |
| **In REGISTRY (authored)** | **204** |
| Custom resolver to-do (bespoke) | 74 |
| Review | 181 |
| Ineligible | 15 |
| AutoPkg pending classification | 58 |
| Unsourced remaining | 0 |
| DRYRUN-clean | 0 (requires macOS) |

Registry by source type: `{'github_tag': 70, 'direct': 42, 'electron': 7, 'msft_cdn': 2, 'github_compound': 1, 'github_arch': 11, 'direct_latest': 56, 'direct_arch': 15}`

`direct_latest` rows are `version :latest` + `sha256 :no_check` (Homebrew discourages — prune at DRYRUN). Run `DRYRUN=1 bash scripts/cask-master.sh` on a Mac.

## Custom resolver to-do (74) — bespoke

Per-app facts in [`custom-todo.md`](custom-todo.md) (header-only version, hash/build-token URLs, arch-split pkg, nested pkgInDmg/pkgInZip, string-transform versions).

`barcode-studio, bimcollab-zoom, capture-one, cato-client, cloudya, code42, conniepad, cricut-design-space, daylite, dedoose, delighted, dell-display-peripheral-manager, depnotify, deskrest, displaylink-manager, eclipse-ide-for-embedded-cc-developers, eclipse-ide-for-scout-developers, final-draft-12, final-draft-13, fotomagico, frameio-transfer, growly-glucose, guardian-browser, huddly, hudl-sportscode, huggingchat-mac, ipsw-updater, jamf-connect-configuration, jamf-connect-login, jpegmini-pro, keeper-secrets-manager-cli, lg-calibration-studio, macos-instantview, mamp-pro, maxon-cinema-4d-2026, medialab-connect, mersive-solstice, microsoft-company-portal, microsoft-powershell, mimiq, mister-horse-product-manager, monotype-connect, multiviewer-for-f1, netbird, noor, nvivo-14, nvivo-15, okiocam-snapshot-and-recorder, onemenu, optisigns-digital-signage, origami-3, poly-lens-desktop, postlab, praxislive, setup-manager, sforzando, shellhistory, slido-for-powerpoint, smart-mirror-app, soundfield-by-rode, spyder-x-elite, spyder-x-pro, starface, strongdm, studio-viewer, synology-active-backup-for-business-agent, synology-drive-client, universal-type-client, vivi, windsurf, wonderpen, workbrew, xmlmind, zaxconvert`

## Review / ineligible (196)

Reasons in the `bucket` column of [`../data/master-list.csv`](../data/master-list.csv).

