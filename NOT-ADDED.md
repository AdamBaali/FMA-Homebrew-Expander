# Apps not added — and why

The catalog is **533** apps (`data/master-list.csv`, one row each, with a `bucket` column that
holds the authoritative per-app verdict). **318 were authored** into `scripts/cask-master.sh`.
**305** apps are not shipped, for two kinds of reason: **215** were never eligible to author
(section 1) and **90** were authored but are blocked by Homebrew core policy (section 2) —
leaving **228** casks that can actually ship to homebrew-cask core.

> **Source / future ref.** The 533-app universe is Fleet's "appcatalog.cloud apps with no
> Homebrew cask" list — 533 macOS [appcatalog.cloud](https://appcatalog.cloud/apps) apps with no
> matching Homebrew cask (checked against the full 7,706-cask Homebrew list) — shared by Allen
> Houchins on 2026-06-08:
> [the list](https://github.com/fleetdm/fleet/blob/118e968fac7f45d07f6dcd3bd08bcd055254928b/ee/maintained-apps/app-catalog-parity/no-homebrew-cask.md)
> · [Slack post](https://fleetdm.slack.com/archives/C02TYJF11P0/p1780941961900449?thread_ts=1780930437.788159&cid=C02TYJF11P0).
> The file has since been removed from fleet `main`, so the **pinned commit (`118e968`)** is the
> durable reference for reconciling this pile against the live catalog later.

## 1. Not eligible / not sourced — decided before authoring

215 apps never entered the registry. Grouped by reason (exact per-app reason: the
`bucket` column of `data/master-list.csv`):

| Reason | Count |
|---|---|
| App-specific reason | 73 |
| Duplicate of an existing cask/formula | 40 |
| Account / login / portal-gated | 32 |
| Mac App Store only | 20 |
| Paid / purchase-gated | 19 |
| Discontinued / EOL / renamed / dead | 16 |
| No public versioned download | 10 |
| Ineligible installer type | 3 |
| Adware / PUA | 2 |
| **Total not eligible** | **215** |

**App-specific reason (73)**  
`acronis-cyber-protect-connect-client`, `adobe-acrobat`, `adobe-acrobat-cleaner-tool`, `adobe-dynamic-media-classic`, `appgate-sdp`, `atera-agent`, `azul-zulu-jdk-22`, `azul-zulu-jdk-24`, `batchphoto`, `catalog`, `catalyst-browse`, `clamav`, `claroread`, `class`, `clipdrop`, `container`, `dante-virtual-soundcard`, `default-mail-app-to-microsoft-outlook`, `dockutil`, `doctolib`, `dstny`, `egnyte-connect`, `egnyte-desktop-app-core`, `epos-connect`, `exiftool`, `filezilla`, `findr`, `finito`, `foolcat`, `ftprush`, `hintview`, `homebrew`, `hydra`, `identity`, `identity-enterprise`, `instant-word-counter`, `inventorywatch`, `joy`, `jupyterlab`, `mana-security`, `microsoft-365`, `microsoft-365-business-pro`, `microsoft-365-complete-removal`, `mirrormask`, `mist-cli`, `nirvana`, `ntfs-disk-by-omi`, `onscreen-control`, `password-depot`, `pix-3`, `projectplace`, `python-3`, `receipts-space`, `scribe-desktop`, `setup-checklist`, `sketchup-pro-2021`, `sketchup-pro-2022`, `sketchup-pro-2023`, `skopos-agent`, `soundly`, `splashtop-sos`, `teos-connect`, `text-on-tap-overlay`, `trash-sweep`, `ultracompare`, `videostream`, `voices`, `walkme`, `wavepad`, `webfont`, `webkiosk-8`, `workplace-pure-client`, `zoho-workdrive-genie`

**Duplicate of an existing cask/formula (40)**  
`amazon-corretto-11`, `amazon-corretto-17`, `amazon-corretto-21`, `amazon-corretto-8`, `anaconda-navigator`, `anka`, `apache-netbeans-15`, `app-cleaner-and-uninstaller`, `azul-zulu-jdk-11`, `azul-zulu-jdk-17`, `azul-zulu-jdk-21`, `azul-zulu-jdk-8`, `cisco-webex`, `cleanshot-x`, `docker`, `eclipse-ide-for-enterprise-java-and-web-developers`, `eclipse-ide-for-rcp-and-rap-developers`, `foxit-phantompdf`, `httpie`, `istat-menu`, `kubernetes-desktop-client`, `languagetool`, `net-100`, `net-80`, `net-90`, `nextcloud-desktop-client`, `obs-studio`, `oracle-java-jdk-17`, `oracle-java-jdk-21`, `oracle-java-jdk-25`, `owasp-zap`, `responsivelyapp`, `rstudio-desktop`, `spark-desktop`, `stream-deck`, `tigervnc-viewer`, `vox-music-player`, `wacom-driver`, `zerotier`, `zoom-workplace`

**Account / login / portal-gated (32)**  
`acoustica`, `audiolava`, `avaya-cloud`, `avid-link`, `computer`, `docusign-edit`, `enreachcontact`, `eparaksts`, `farmerswife`, `hunchly`, `ib-eassessment-player`, `kelvin`, `lens-desktop`, `linked-helper`, `lucanet-software-manager`, `manycam`, `navigator`, `navionics-chart-installer`, `openphone`, `pandasuite-studio`, `pix`, `r-remote`, `screenml`, `smugmug`, `streamline`, `surfdrive`, `talkdesk`, `voiceedge`, `weave`, `wework-print`, `xelion`, `xink`

**Mac App Store only (20)**  
`2do`, `a-zippr`, `agenda`, `clevershare`, `elytra`, `eon-timer`, `keepnotes`, `komodo-screen-recorder`, `lingo`, `livechat`, `maglr`, `rocketsim`, `scratch-link`, `shortcut-bar`, `sleeve`, `speediness`, `studies`, `text-workflow`, `upaste`, `walkme-extension-for-safari`

**Paid / purchase-gated (19)**  
`amnesia`, `boxshot-5`, `brewer-x`, `kite`, `kubeswitch`, `macgpt`, `movie-magic-scheduling`, `musebox`, `palettebrain`, `peakto`, `pgmagic`, `rhino-7`, `rhino-8`, `shells`, `statusbuddy`, `supercharge`, `timebuzzer`, `umbra`, `xmledita`

**Discontinued / EOL / renamed / dead (16)**  
`alexsidebar`, `amazon-corretto-22`, `appdelete`, `brackets`, `cisco-umbrella-roaming-client`, `clipboardai`, `escape-medical-viewer`, `geekbench-ml`, `oracle-java-jdk-22`, `oracle-java-jdk-23`, `oracle-java-jdk-24`, `plantronics-hub`, `shellleap`, `sketchup-viewer`, `supavdo`, `yodel`

**No public versioned download (10)**  
`adobe-remote-update-manager`, `adobe-uninstaller`, `bananotate`, `bitcomet`, `frost-writer`, `myvideoanalyser`, `padlet`, `prelude-operator`, `screen-share`, `yoyotta`

**Ineligible installer type (3)**  
`ibm-spss-statistics`, `microsoft-defender`, `withsecure-elements`

**Adware / PUA (2)**  
`cryptotab-browser`, `powermymac`

## 2. Authored, but blocked by Homebrew core policy — found at audit

These *were* authored, but `brew audit --strict --online --new` rejects them and nothing in the
cask can fix it. Skip for homebrew-cask **core** (a Fleet-owned custom tap is the alternative).

> ✅ **Enforced since 2026-06-10:** `scripts/cask-master.sh` carries this list as
> `POLICY_BLOCKED` (right after the REGISTRY) and skips these tokens by default,
> recording `skipped (policy-blocked)` in results.tsv instead of re-failing them on
> every run. A new upstream release can flip a verdict (app gets notarized, repo gains
> stars) — re-test with `RUN_BLOCKED=1 ONLY="tok ..."` and delete entries that pass.

> ⚠️ Coverage: the dry run behind this list stopped at **244/318** authored apps (174 failed —
> 87 of them proved policy-blocked below, the other 87 were registry/spec bugs since fixed;
> 63 passed; 7 already existed upstream; 74 never ran). `appcode`, `corelcad`, and `nightowl`
> were added from research rather than audit output. Regenerate after the next full `DRYRUN=1`
> run — see the command at the bottom.

90 unique apps; the 95 reason rows below overlap because 5 apps (`battery-toolkit`,
`chromebuddy`, `dropnote`, `mxmarkedit`, `smotrite`) hit two reasons at once.

| Reason | Count |
|---|---|
| Not signed + Apple-notarized / signature invalid | 43 |
| GitHub/Bitbucket repo not notable enough (<75★ / <30 forks / <30 watchers) | 36 |
| GitHub repo archived | 2 |
| Vendor blocks automation / no version source / EOL (found 2026-06-10) | 13 |
| Removed from homebrew-cask as malware | 1 |

**Not signed + Apple-notarized / signature invalid (43)**  
`okiocam-snapshot-and-recorder`, `soundfield-by-rode`,
`1piece`, `airbattery`, `bartranslate`, `bimcollab-zoom` *(signature invalid: "software has been altered")*, `battery-toolkit`, `blink-eye`, `boring-notch`, `brewmate`, `caesium-image-compressor`, `canister`, `chromebuddy`, `dropnote`, `droppoint`, `editready`, `fontagent`, `freeter`, `later`, `logoer`, `macuncle-eml-viewer`, `mindview-9`, `mixpad`, `modalfilemanager`, `mxmarkedit`, `offshoot`, `peazip`, `pixillion`, `quickrecorder`, `relagit`, `shokz-connect`, `smotrite`, `sniffnet`, `squirreldisk`, `station`, `supercorners`, `swiftcord`, `swiftguard`, `textream`, `time-machine-inspector`, `tinyweb`, `trace`, `watchflower`

**GitHub/Bitbucket repo not notable enough (<75★ / <30 forks / <30 watchers) (36)**  
`depnotify`, `deskrest`, `jamf-compliance-editor`,
`air-flow`, `api-utility`, `backgrounds`, `chatkit`, `chromebuddy`, `close-desktop`, `desktop-icon-manager`, `dictation-daddy`, `dropnote`, `elevate24`, `file-architect`, `hide-icons`, `impulso`, `jamf-actions`, `jamf-cli`, `jamf-framework-redeploy`, `jamf-printer-manager`, `jamf-protect-ulf-uploader`, `jamfdash`, `mailvault`, `monsterwriter`, `mxmarkedit`, `noteey`, `object-info`, `psso-utility`, `quilt-app`, `sapmachine-manager`, `smotrite`, `sym-helper`, `utm-coordinate-converter` *(Bitbucket)*, `visualz`, `vocal`, `wudpecker`

**GitHub repo archived (2)**  
`battery-toolkit`, `jamf-environment-test`

**Vendor blocks automation / no version source / EOL (13)**  
`dragonframe-2024`, `dragonframe-2025`, `dragonframe-5` — dragonframe.com returns HTTP 406
to every non-browser client (curl, Homebrew's own UA), so brew's homepage/livecheck checks
can never pass. `corelcad` — discontinued 2023; only a fixed unversioned trial dmg remains.
`fuzzlecheck-4`, `onemenu` — JS-only download pages, no robot-readable version source.
`appcode` — JetBrains discontinued AppCode (EOL Dec 2023). `lucidlink` — the v3 client is
portal-distributed (app.lucidlink.com), no public versioned URL; Classic 2.x ships as
`lucidlink-classic`. `horse` — downloads are unversioned redirects to expiring signed URLs
on a private GitHub repo; no version-pinned public URL or stable sha256 is possible.
`imymac-pdf-compressor`, `imymac-video-converter` — imymac.com 403s every non-browser
download, so brew itself cannot fetch them (same vendor as the PUA-bucketed `powermymac`).
`print-window` — printwindowapp.com serves an expired TLS certificate; brew cannot
download. Re-test with `RUN_BLOCKED=1` once the vendor renews it.
`huggingchat-mac` — only GitHub pre-releases exist; audit `--new` rejects
pre-release-only projects.

**Removed from homebrew-cask as malware (1)**  
`nightowl` — removed upstream in 2023 ([homebrew-cask#149439](https://github.com/Homebrew/homebrew-cask/pull/149439)):
the app silently enrolled Macs in a paid third-party proxy network. Do not resubmit.

---

Regenerate section 2 after the dry run completes:

```bash
for d in /tmp/caskwork/*/; do grep -q '^STATUS=failed' "$d/result.env" 2>/dev/null || continue
  for p in 'not notable enough' 'Signature verification failed' 'repo is archived'; do
    grep -q "$p" "$d/report.md" && echo "$(basename $d): $p"; done; done | sort -t: -k2
```
