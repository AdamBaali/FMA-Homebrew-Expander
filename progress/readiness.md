# Readiness — registry, custom to-do & review

_Last updated: 2026-06-09 (Phase 1 complete — all 4 waves)._

## Summary

| Bucket | Count |
|---|---|
| Total apps | 533 |
| Sourced | 532 |
| **In REGISTRY (authored)** | **110** |
| Custom resolver to-do | 159 |
| Review | 180 |
| Ineligible | 15 |
| AutoPkg pending classification | 67 |
| Unsourced remaining | 1 |
| DRYRUN-clean | 0 (requires macOS) |

All registry rows are statically verified but **not** DRYRUN-validated. Run `DRYRUN=1 bash scripts/cask-master.sh` on a Mac.

## Registry apps (110) — token | source | artifact

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
| `haiku-animator` | github_tag | dmg |
| `hue` | electron | zip |
| `ibm-data-shift` | github_compound | zip |
| `impulso` | github_tag | zip |
| `insight` | direct | dmg |
| `jamf-actions` | github_tag | zip |
| `jamf-aftermath` | github_tag | pkg |
| `jamf-cloud-package-replicator` | github_tag | zip |
| `jamf-environment-test` | github_tag | zip |
| `jamf-framework-redeploy` | github_tag | zip |
| `jamf-protect-ulf-uploader` | github_tag | zip |
| `jamf-prune` | github_tag | zip |
| `jamfdash` | github_tag | pkg |
| `jamfhelper-constructor` | github_tag | zip |
| `logoer` | github_tag | dmg |
| `lucidlink-classic` | direct | pkg |
| `maccleanse` | direct | dmg |
| `microsoft-365-license-removal-tool` | msft_cdn | pkg |
| `modalfilemanager` | github_tag | zip |
| `monsterwriter` | github_tag | dmg |
| `mut` | github_tag | zip |
| `mymedia` | github_tag | dmg |
| `namo` | direct | dmg |
| `nextpad` | github_tag | dmg |
| `noteey` | github_tag | dmg |
| `obd-auto-doctor` | direct | dmg |
| `object-info` | github_tag | zip |
| `ollamaspring` | github_tag | zip |
| `photos-workbench` | direct | dmg |
| `psso-utility` | github_tag | pkg |
| `quickrecorder` | github_tag | dmg |
| `relagit` | electron | dmg |
| `remote-utilities-agent` | direct | zip |
| `remote-utilities-viewer` | direct | dmg |
| `renameninja` | direct | zip |
| `reqres` | github_tag | dmg |
| `root3-support-app` | github_tag | pkg |
| `rumpus` | direct | dmg |
| `scrutiny` | direct | dmg |
| `squirreldisk` | github_tag | dmg |
| `supercorners` | github_tag | zip |
| `swiftcord` | github_tag | zip |
| `textream` | github_tag | dmg |
| `vocal` | github_tag | zip |
| `watchflower` | github_tag | zip |
| `window-glue` | github_tag | dmg |
| `wondershare-mockitt` | direct | dmg |
| `wudpecker` | github_tag | dmg |

## Custom resolver to-do (159)

Per-app facts in [`custom-todo.md`](custom-todo.md).

`arclite-pro, barcode-studio, beam-studio, bimcollab-zoom, blink-eye, boundary, buhontfs, canister, capture-one, cascable-pro-webcam, cato-client, chatkit, cisco-audio-device, cloudya, code42, connectmenow4, conniepad, cotypist, cricut-design-space, cursor-teleporter, daylite, dedoose, delighted, dell-display-peripheral-manager, depnotify, dialpad-meetings, disk-space-analyzer, displaylink-manager, dropnotch, droppoint, eclipse-ide-for-embedded-cc-developers, eclipse-ide-for-scout-developers, editready, everweb, file-architect, filemail, fileminutes, final-draft-12, final-draft-13, flashpeak-slimjet, flexihub, flowjo, focusee, folge, fotomagico, frameio-transfer, global-secure-access-client, grasshopper, growly-glucose, guardian-browser, horse, huddly, hudl-sportscode, huggingchat-mac, iboostup, imymac-pdf-compressor, imymac-video-converter, integrity-plus, integrity-pro, iperius-remote, iphone-backup-extractor, ipsw-updater, istatistica-pro, jamf-connect-configuration, jamf-connect-login, jane-reader, jpegmini-pro, keeper-secrets-manager-cli, later, lg-calibration-studio, lingvanex-translator, mac-linguist, macos-instantview, macuncle-eml-viewer, mamp-pro, maxon-cinema-4d-2026, medialab-connect, mersive-solstice, microsoft-company-portal, microsoft-powershell, mimiq, minimoon, mister-horse-product-manager, mixpad, monotype-connect, multiviewer-for-f1, mxmarkedit, my-picturemaxx-5, netbird, nextai-translator, noor, nvivo-14, nvivo-15, offshoot, okiocam-snapshot-and-recorder, ondesoft-spotify-converter, onemenu, optisigns-digital-signage, origami-3, otter, patch-desktop, patternodes, pdfsail, peazip, pixillion, poly-lens-desktop, postlab, praxislive, print-window, pulseway, quilt, rumplet, screenflow-hal-audio-driver, setup-manager, sforzando, shellhistory, shokz-connect, slido-for-powerpoint, smart-mirror-app, smotrite, sniffnet, soundfield-by-rode, spacesuit, spyder-x-elite, spyder-x-pro, starface, station, strongdm, studio-viewer, substage, swiftguard, synology-active-backup-for-business-agent, synology-drive-client, teamwire, time-machine-inspector, tinyweb, trace, trident, trint, tweeten, universal-type-client, usb-network-gate, utm-coordinate-converter, vagon, vectoraster, vectorstyler, videoproc-vlogger, vidmore-player, vidmore-screen-recorder, vidmore-video-enhancer, viper-ftp, visualz, vivi, windsurf, wonderpen, workbrew, xmlmind, xnresize, zaxconvert`

## Review / ineligible (195)

Reasons in the `bucket` column of [`../data/master-list.csv`](../data/master-list.csv).

