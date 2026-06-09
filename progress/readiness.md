# Readiness — what's added, what isn't, and why

_Last updated: 2026-06-09. The single source of per-app status; revisit the **Not added** sections later._

## Summary

| Bucket | Count | Meaning |
|---|---|---|
| **Added** to `cask-master.sh` | **234** | ready to `DRYRUN=1 bash scripts/cask-master.sh` on a Mac |
| **Not added — needs custom resolver** | **84** | verified download, but URL/version doesn't fit a built-in source type |
| **Not added — review** | **196** | gated / login / paid / unversioned / unverifiable |
| **Not added — ineligible** | **18** | no FMA-eligible artifact (Mac App Store only, discontinued, `.tar.bz2`, duplicate of existing cask) |
| Total | 533 | (sourced 533) |

> `direct_latest` rows in the registry are `version :latest` + `sha256 :no_check` — Homebrew discourages these for new casks, so review/prune them at DRYRUN.

## ✅ Added — in the registry (234)

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
| `blink-eye` | github_arch | dmg |
| `chatkit` | github_arch | dmg |
| `droppoint` | github_arch | dmg |
| `file-architect` | github_arch | dmg |
| `peazip` | github_arch | dmg |
| `smotrite` | github_arch | dmg |
| `sniffnet` | github_arch | dmg |
| `spacesuit` | github_arch | dmg |
| `swiftguard` | github_arch | dmg |
| `time-machine-inspector` | github_arch | dmg |
| `visualz` | github_arch | dmg |
| `nextai-translator` | github_tag | dmg |
| `battery-toolkit` | github_tag | zip |
| `hide-icons` | github_tag | zip |
| `jamf-cli` | github_tag | pkg |
| `jamf-replicator` | github_tag | zip |
| `jamf-sync` | github_tag | zip |
| `mailvault` | github_tag | dmg |
| `sapmachine-manager` | github_tag | pkg |
| `script2pkg` | github_tag | pkg |
| `arclite-pro` | direct_latest | dmg |
| `beam-studio` | direct_arch | dmg |
| `boundary` | direct_arch | dmg |
| `buhontfs` | direct_latest | dmg |
| `canister` | direct_latest | dmg |
| `cascable-pro-webcam` | direct_latest | zip |
| `cisco-audio-device` | direct_latest | pkg |
| `connectmenow4` | direct_arch | dmg |
| `cotypist` | direct_latest | dmg |
| `cursor-teleporter` | direct | zip |
| `dialpad-meetings` | direct_arch | dmg |
| `disk-space-analyzer` | direct_latest | dmg |
| `dropnotch` | direct_latest | dmg |
| `editready` | direct_latest | dmg |
| `everweb` | direct_latest | dmg |
| `filemail` | direct_latest | dmg |
| `fileminutes` | direct_latest | dmg |
| `flashpeak-slimjet` | direct_arch | dmg |
| `flexihub` | direct_latest | dmg |
| `flowjo` | direct_arch | dmg |
| `focusee` | direct_latest | dmg |
| `folge` | direct_arch | dmg |
| `global-secure-access-client` | direct_latest | pkg |
| `grasshopper` | direct_latest | dmg |
| `horse` | direct_arch | zip |
| `iboostup` | direct_latest | dmg |
| `imymac-pdf-compressor` | direct_latest | dmg |
| `imymac-video-converter` | direct_latest | dmg |
| `integrity-plus` | direct_latest | dmg |
| `integrity-pro` | direct_latest | dmg |
| `iperius-remote` | direct_latest | dmg |
| `iphone-backup-extractor` | direct_latest | dmg |
| `istatistica-pro` | direct_latest | dmg |
| `jane-reader` | direct_arch | dmg |
| `later` | direct_latest | dmg |
| `lingvanex-translator` | direct_latest | dmg |
| `mac-linguist` | direct_latest | dmg |
| `macuncle-eml-viewer` | direct_latest | dmg |
| `minimoon` | direct_latest | dmg |
| `mixpad` | direct_latest | zip |
| `mxmarkedit` | direct_latest | zip |
| `my-picturemaxx-5` | direct_latest | dmg |
| `offshoot` | direct_latest | dmg |
| `ondesoft-spotify-converter` | direct_latest | dmg |
| `otter` | direct_latest | dmg |
| `patch-desktop` | direct_latest | pkg |
| `patternodes` | direct_latest | dmg |
| `pdfsail` | direct_latest | dmg |
| `pixillion` | direct_latest | zip |
| `print-window` | direct_latest | dmg |
| `pulseway` | direct_latest | dmg |
| `quilt-app` | direct_latest | dmg |
| `rumplet` | direct_latest | zip |
| `screenflow-hal-audio-driver` | direct_latest | pkg |
| `shokz-connect` | direct_latest | dmg |
| `station` | github_tag | zip |
| `substage` | direct_latest | dmg |
| `teamwire` | direct_arch | dmg |
| `tinyweb` | direct_latest | dmg |
| `trace` | direct_latest | dmg |
| `trident` | direct_arch | dmg |
| `trint` | direct_arch | zip |
| `tweeten` | github_tag | zip |
| `usb-network-gate` | direct_latest | dmg |
| `utm-coordinate-converter` | direct_arch | dmg |
| `vagon` | direct_arch | dmg |
| `vectoraster` | direct_latest | dmg |
| `vectorstyler` | direct_arch | dmg |
| `videoproc-vlogger` | direct_latest | dmg |
| `vidmore-player` | direct_latest | dmg |
| `vidmore-screen-recorder` | direct_latest | zip |
| `vidmore-video-enhancer` | direct_latest | dmg |
| `viper-ftp` | direct_latest | dmg |
| `xnresize` | direct_latest | dmg |
| `1piece` | direct | zip |
| `accents` | direct_latest | zip |
| `air-flow` | direct_arch | zip |
| `aircall-workspace` | direct_arch | pkg |
| `airtime` | direct_latest | dmg |
| `amazon-appstream-20` | direct_latest | pkg |
| `appcode` | direct_arch | dmg |
| `arcade` | direct | dmg |
| `changes` | github_tag | zip |
| `dinoxcope` | direct_latest | dmg |
| `flinto` | direct | dmg |
| `folder-tidy` | direct | dmg |
| `fontagent` | direct_latest | dmg |
| `goto-desktop` | electron | dmg |
| `grab2text` | direct_latest | dmg |
| `houdahgeo` | direct | zip |
| `ledger-live` | electron | dmg |
| `microsoft-advertising-editor` | direct_latest | dmg |
| `mindview-9` | direct_latest | dmg |
| `movie-magic-budgeting` | direct_latest | dmg |
| `nightowl` | direct | zip |
| `phraseexpress` | direct_latest | dmg |
| `sidebar` | direct | dmg |
| `soundq` | direct | pkg |
| `startup-manager-pro` | direct | dmg |
| `tembo-2` | direct | zip |
| `tembo-3` | direct | zip |
| `textsoap` | direct_latest | dmg |
| `typewhisper` | direct | dmg |
| `vernier-graphical-analysis` | direct_latest | dmg |

## 🛠️ Not added — needs a custom resolver (84)

Each has a verified download + version (facts in [`custom-todo.md`](custom-todo.md) and `sourced/*-results.tsv`), but needs a hand-written `resolve_<tfn>`/`write_cask_<tfn>` — best authored on a Mac where `DRYRUN` validates each. Grouped by **why**:

**version only in redirect/header (:header_match)** (32): `bimcollab-zoom`, `cato-client`, `code42`, `comic-life-4`, `daylite`, `dedoose`, `eclipse-ide-for-embedded-cc-developers`, `eclipse-ide-for-scout-developers`, `huddly`, `jamf-connect-configuration`, `jamf-connect-login`, `joan-configurator`, `lg-calibration-studio`, `mersive-solstice`, `mister-horse-product-manager`, `monotype-connect`, `noor`, `nvivo-14`, `nvivo-15`, `onemenu`, `optisigns-digital-signage`, `origami-3`, `sforzando`, `slido-for-powerpoint`, `smart-mirror-app`, `snapgene`, `spyder-x-elite`, `spyder-x-pro`, `strongdm`, `studio-viewer`, `vivi`, `workbrew`

**arch-split .pkg (needs arch var + per-arch sha)** (10): `barcode-studio`, `foldr`, `mamp-pro`, `microsoft-powershell`, `netbird`, `poly-lens-desktop`, `praxislive`, `prisma-access-browser`, `synology-active-backup-for-business-agent`, `synology-drive-client`

**build-in-filename / tag-version skew** (10): `buhocleaner`, `conniepad`, `deskrest`, `fotomagico`, `guardian-browser`, `jamf-compliance-editor`, `jpegmini-pro`, `postlab`, `setup-manager`, `shellhistory`

**per-release hash/token in URL** (9): `capture-one`, `dell-display-peripheral-manager`, `frameio-transfer`, `medialab-connect`, `microsoft-company-portal`, `multiviewer-for-f1`, `soundfield-by-rode`, `starface`, `windsurf`

**other — see custom-todo.md** (9): `cricut-design-space`, `delighted`, `depnotify`, `displaylink-manager`, `huggingchat-mac`, `keeper-secrets-manager-cli`, `macos-instantview`, `mimiq`, `wonderpen`

**nested container (pkg/app-in-zip/dmg)** (8): `cloudya`, `final-draft-12`, `final-draft-13`, `flashprint-5`, `hudl-sportscode`, `imanage-work-desktop`, `okiocam-snapshot-and-recorder`, `zaxconvert`

**string-transform version (dots->_/-/none)** (6): `growly-glucose`, `ipsw-updater`, `maxon-cinema-4d-2026`, `universal-type-client`, `usher`, `xmlmind`

## 🚫 Not added — review / ineligible (214)

Why each can't be a cask (revisit if a vendor adds a public versioned download):

| token | verdict | reason |
|---|---|---|
| `2do` | no | ineligible-mas-only |
| `adobe-remote-update-manager` | no | No public download. deploymenttools.acp.adobeoobe.com/RUM/RemoteUpdateManager.dm |
| `adobe-uninstaller` | no | No public download. Enterprise CLI uninstaller (com.adobe.uninstaller, Team JQ52 |
| `appdelete` | no | Developer (Reggie Ashworth) deceased 2017; official site reggieashworth.com now redirects |
| `boxshot-5` | no | Commercial paid app (Appsforlife). Download links route through account portal id.appsforl |
| `brewer-x` | no | Paid app ($29 one-time, Panini House). Download gated behind purchase at panini.house/brew |
| `cisco-umbrella-roaming-client` | no | Standalone Umbrella Roaming Client is discontinued/superseded by Cisco Secure Client; macO |
| `clamav` | no | Open-source CLI/daemon antivirus engine (clamd), not a GUI .app. Already a homebrew-core f |
| `clipdrop` | no | ClipDrop / AR Copy Paste (bundle app.arcopypaste.desktop). Reason: web-only. ClipDrop is n |
| `filezilla` | no | FileZilla Client current version 3.70.6 (2026-06-08), but macOS distribution is |
| `ftprush` | no | Vendor's only macOS download is a tar.bz2: https://www.wftpserver.com/download/FTPRush_mac |
| `homebrew` | no | bogus: Homebrew itself, not a cask |
| `mana-security` | no | Mana Security (com.manasecurity.mana). GitHub repo manasecurity/mana-security-app latest r |
| `powermymac` | no | PUA/adware. PowerMyMac (iMyMac "Mac cleaner"). Widely classified as a Potentially Unwanted |
| `scratch-link` | no | Now Mac App Store only. github.com/LLK/scratch-link (scratchfoundation) has NO releases (" |
| `shortcut-bar` | no | Mac App Store only — Shortcut Bar - Instant Access, FIPLAB Ltd, apps.apple.com/app/id11488 |
| `sketchup-viewer` | no | SketchUp Viewer for Desktop discontinued; "Beginning April 22, 2025, SketchUp Vi |
| `supavdo` | no | Domain dead. SupaVdo (bundle com.supavdo.SupaVdo, dev id PM83B39XB9). supavdo.com and www. |
| `a-zippr` | review | Mac App Store only (apps.apple.com/app/id1434280883); vendor zippr.app / appyogi.com link |
| `acoustica` | review | Acon Digital Acoustica (v7.7.8, bundle com.AconDigital.Acoustica). Reason: gated |
| `acronis-cyber-protect-connect-client` | review | web-sourced-review |
| `adobe-acrobat` | review | web-sourced-review |
| `adobe-dynamic-media-classic` | review | web-sourced-review |
| `agenda` | review | Agenda by Momenta B.V. Reason: mas-only. agenda.com offers only the Mac App Stor |
| `alexsidebar` | review | Discontinued: vendor alexcodes.app banner "Downloads stopped on October 1st" and "We've jo |
| `amazon-corretto-11` | review | duplicate of existing Homebrew cask corretto@11 |
| `amazon-corretto-17` | review | duplicate of existing Homebrew cask corretto@17 |
| `amazon-corretto-21` | review | duplicate of existing Homebrew cask corretto@21 |
| `amazon-corretto-22` | review | EOL/non-LTS; Homebrew dropped corretto@22. Download exists arch-split: https://c |
| `amazon-corretto-8` | review | duplicate of existing Homebrew cask corretto@8 |
| `amnesia` | review | Gumroad pay-what-you-want, email/checkout-gated download (goodsnooze.gumroad.com/l/amnesia |
| `anaconda-navigator` | review | Reason: duplicate. Anaconda Navigator is not a standalone installer; it ships in |
| `anka` | review | Reason: exists. 'anka' resolves to Anka Virtualization (veertu-latest redirects |
| `apache-netbeans-15` | review | Reason: exists. The Friends-of-Apache-NetBeans/netbeans-installers repo is alrea |
| `app-cleaner-and-uninstaller` | review | Reason: exists. Slug/name match Nektony "App Cleaner & Uninstaller" already ship |
| `appgate-sdp` | review | web-sourced-review |
| `atera-agent` | review | web-sourced-review |
| `audiolava` | review | No current public versioned URL. Acon Digital download portal (acondigital.com/downloads - |
| `avaya-cloud` | review | Login/tenant-gated UCaaS (RingCentral-rebranded Avaya Cloud Office). Desktop via ringcentr |
| `avid-link` | review | Login-gated. Installer fetched via my.avid.com (account) / Download Center; avid.com/produ |
| `azul-zulu-jdk-11` | review | duplicate of existing Homebrew cask zulu@11 |
| `azul-zulu-jdk-17` | review | duplicate of existing Homebrew cask zulu@17 |
| `azul-zulu-jdk-21` | review | duplicate of existing Homebrew cask zulu@21 |
| `azul-zulu-jdk-22` | review | non-LTS; Homebrew zulu casks are LTS-only (zulu tracks latest) | Verified live 200 both ar |
| `azul-zulu-jdk-24` | review | non-LTS; zulu cask already tracks the latest JDK | Verified live 200: https://cdn.azul.com |
| `azul-zulu-jdk-8` | review | duplicate of existing Homebrew cask zulu@8 |
| `bananotate` | review | No verifiable public direct download. bananotate.com is a JS SPA: /download, /Bananotate.d |
| `batchphoto` | review | Direct dmg http(s)://www.batchphoto.com/download/batchphoto.dmg returns 403 Forbidden even |
| `bitcomet` | review | No stable/derivable public versioned URL. Official macOS download (current v2.20.0, BitCom |
| `brackets` | review | discontinued (Adobe ended Brackets 2021); GitHub release has no macOS asset |
| `catalog` | review | Root3 App Catalog client (nl.root3.catalog) - the commercial patch-management agent behind |
| `catalyst-browse` | review | Sony Catalyst Browse. Distributed via Sony Creators' Cloud / support.d-imaging.s |
| `cisco-webex` | review | Duplicate: already a homebrew-cask cask as token "webex" (Webex, https://formulae.brew.sh/ |
| `claroread` | review | ClaroRead Mac (Claro Software / Texthelp) — commercial assistive text-to-speech |
| `class` | review | "Class" / Class for Zoom (com.classedu.classforzoom), enterprise EDU virtual-classroom app |
| `cleanshot-x` | review | Duplicate: already a homebrew-cask cask as token "cleanshot" (CleanShot X, https://formula |
| `clevershare` | review | Clevertouch (bundle com.clevertouch.clevershare2). Reason: mas-only. On Mac, Clevertouch o |
| `clipboardai` | review | ClipboardAI by Silas Wolf (bundle com.silaswolf.clipboard-ai). Reason: discontinued. Offic |
| `computer` | review | Computer by DevRev (bundle ai.devrev.desktop), product site computer.io. Reason: gated. co |
| `container` | review | homebrew-core formula collision; apple CLI runtime |
| `cryptotab-browser` | review | CryptoTab Browser (bundle site.cryptobrowser.cryptotab). Reason: adware. Bitcoin-mining br |
| `dante-virtual-soundcard` | review | Audinate Dante Virtual Soundcard (bundle com.audinate.DanteVirtualSoundcard). Reason: gate |
| `default-mail-app-to-microsoft-outlook` | review | Microsoft MailToOutlook (bundle com.microsoft.MailToOutlook). Reason: no-vendor-download. |
| `docker` | review | duplicate of existing Homebrew cask docker-desktop (Docker Desktop) |
| `dockutil` | review | homebrew-core formula collision (brew install dockutil) |
| `doctolib` | review | https://ddv-install.doctolib.fr/DoctolibProDesktop-latest-arm64.dmg = HTTP 200 b |
| `docusign-edit` | review | Portal/login-gated. DocuSign CLM "Docusign Edit"/SpringCM Edit (bundle com.springcm.Spring |
| `dstny` | review | https://soft.dstny.se/dstny_mac.dmg = HTTP 200 application/octet-stream but URL |
| `eclipse-ide-for-enterprise-java-and-web-developers` | review | Duplicate: cask "eclipse-jee" already exists (formulae.brew.sh/api/cask/eclipse-jee.json = |
| `eclipse-ide-for-rcp-and-rap-developers` | review | Duplicate: cask "eclipse-rcp" already exists (formulae.brew.sh/api/cask/eclipse-rcp.json = |
| `egnyte-connect` | review | Egnyte Desktop App (Egnyte Connect / Egnyte Drive, bundle com.egnyte.Egnyte-Driv |
| `egnyte-desktop-app-core` | review | Egnyte "Desktop App Core" for Mac, current version ~1.18.0 (per Egnyte helpdesk |
| `elytra` | review | Mac App Store only. Elytra RSS reader (bundle com.dezinezync.elytra) is distributed via MA |
| `enreachcontact` | review | No public macOS download (portal/SPA-gated). desktop.enreach.com is an SPA whose JS bundle |
| `eon-timer` | review | Mac App Store only (direct download discontinued). Charlie Monroe "Eon" time tracker (bund |
| `eparaksts` | review | JS-gated download. Latvian eID signer eParakstitajs 3.0 (bundle lv.euso.signanywhere; curr |
| `epos-connect` | review | Current Mac version 8.3.0.49911 (MacUpdater, 2025-09-22) but the direct .pkg URL |
| `escape-medical-viewer` | review | Discontinued. Vendor homepage escapetech.eu states "EMV Mac discontinued." (13 Sep 24); cu |
| `exiftool` | review | homebrew-core formula collision (brew install exiftool) |
| `farmerswife` | review | Portal-gated. farmerswife Desktop Client (bundle com.farmerswife.client) installers are se |
| `findr` | review | usefindr.com (AI enterprise knowledge/workplace-search SaaS; ToDesktop-wrapped, bundle com |
| `finito` | review | finito.ai AI writing assistant. Public unversioned download exists (https://www.finito.ai/ |
| `foolcat` | review | Camera-report tool (SyncFactory, now distributed by Hedge, bundle nl.syncfactory.Foolcat.M |
| `foxit-phantompdf` | review | Renamed: "Foxit PhantomPDF" is now "Foxit PDF Editor", which ALREADY EXISTS as a cask (htt |
| `frost-writer` | review | No public macOS download. frostwriter.com returns HTTP 404 (no site at root); App Store li |
| `geekbench-ml` | review | Discontinued/renamed: Geekbench ML (last release ML 0.6, Dec 2023) was superseded by "Geek |
| `hintview` | review | The HINT Project (Martin Ruckert) HINT viewer. Official page https://hint.userweb.mwn.de/h |
| `httpie` | review | DUPLICATE: cask "httpie-desktop" already exists (formulae.brew.sh/api/cask/httpie-desktop. |
| `hunchly` | review | GATED: download requires a Maltego ID account (downloads page states "You need t |
| `hydra` | review | Creaceed Hydra (Pro HDR editor, bundle id com.creaceed.hydra4, latest ~4.6). Primary distr |
| `ib-eassessment-player` | review | GATED / no public download: eassessment-admin.ibo.org is an authenticated IB adm |
| `ibm-spss-statistics` | review | IBM SPSS Statistics. Commercial licensed analytics software; macOS installer is behind IBM |
| `identity` | review | UniFi Identity (Ubiquiti, standard, bundle id com.ui.uid.standard-desktop). Download https |
| `identity-enterprise` | review | UniFi Identity Enterprise (Ubiquiti, bundle id com.ui.uid.desktop). Same Ubiquiti download |
| `instant-word-counter` | review | Instant Word Counter (G. Trigonakis, bundle id com.gtrigonakis.TextInfo). Distributed ONLY |
| `inventorywatch` | review | Apple Store stock checker (open source, worthbak/inventory-checker-app, bundle not exposed |
| `istat-menu` | review | Duplicate: "iStat Menu" is Bjango's iStat Menus, which ALREADY EXISTS as a cask (https://f |
| `joy` | review | indiegoodies "Joy" AI writing assistant (bundle com.indiegoodies.Agile, dev 555LCL8R2S). M |
| `jupyterlab` | review | formula collision + arch-split; needs token jupyterlab-desktop + custom |
| `keepnotes` | review | Mac App Store only. "KeepNotes for Google Keep" by Sergii Gerasimenko (bundle com.sergey-g |
| `kelvin` | review | Gated/stale. Creative Force "Kelvin" (e-commerce photography, bundle com.creativeforce.app |
| `kite` | review | Paid + unversioned. Kite Compositor (UI animation/prototyping, bundle co.kiteapp.Kite) is |
| `komodo-screen-recorder` | review | Mac App Store first / JS-gated. Kommodo Screen Recorder (apps.apple.com id1280654868). Des |
| `kubernetes-desktop-client` | review | Duplicate — this is Kubernetic (bundle com.kubernetic.desktop), already a cask as token ku |
| `kubeswitch` | review | Paid + gated. KubeSwitch menu-bar app (bundle com.razvanmacovei.KubeSwitch, site kubeswitc |
| `languagetool` | review | Duplicate — already a cask as token languagetool-desktop (https://formulae.brew.sh/api/cas |
| `lens-desktop` | review | Account-gated. Lens K8S IDE (Mirantis, bundle com.electron.kontena-lens). Download page ht |
| `lingo` | review | Mac App Store + account-gated. Lingo digital asset manager (bundle com.lingoapp.Lingo, lin |
| `linked-helper` | review | Login-gated. Linked Helper 2 (linkedhelper.com/downloads) requires sign-up/login to a Link |
| `livechat` | review | Mac App Store / no public direct download. LiveChat for Mac (livechat.com/app/livechat-for |
| `lucanet-software-manager` | review | Customer-portal login-gated. Lucanet.Software Manager downloads are on customer.lucanet.co |
| `macgpt` | review | Paid/login-gated: sold only via Gumroad (https://goodsnooze.gumroad.com/l/menugpt) and Mac |
| `maglr` | review | Maglr Presenter desktop app is distributed via Mac App Store (https://apps.apple.com/us/ap |
| `manycam` | review | ManyCam download (https://manycam.com/download/?os=mac) is JS-gated: the "Download for Mac |
| `microsoft-365` | review | Full Microsoft Office suite (com.microsoft.Office365, Team UBF8T346G9). Real public instal |
| `microsoft-365-business-pro` | review | appcatalog bundle "Office365BusinessPro" (com.microsoft.Office365BusinessPro) = Word/Excel |
| `microsoft-365-complete-removal` | review | Third-party app (bundle id com.microsoft.remove.Office but Developer ID QGS93ZLCU7, NOT Mi |
| `microsoft-defender` | review | NOT FMA-eligible: Microsoft Defender for Endpoint on macOS is an enterprise/lice |
| `mirrormask` | review | MirrorMask (mirrormask.app, native Mac privacy app). Homepage 200 but download is fully JS |
| `mist-cli` | review | homebrew-core formula collision (brew install mist-cli) |
| `movie-magic-scheduling` | review | Login/purchase-gated. Entertainment Partners (ep.com): macOS download only via a paid myEP |
| `musebox` | review | Paid app, no public download. brushedpixel.com/musebox sells a $19 perpetual license ("Buy |
| `myvideoanalyser` | review | No public direct download found. MyVideoAnalyser (sports video/performance analysis, bundl |
| `navigator` | review | Gated. "Navigator" = webAI Navigator (Iris Technology Inc., bundle com.iristechnologyinc.w |
| `navionics-chart-installer` | review | Gated. Navionics Chart Installer (now Garmin); the download flow (navionics.com/.../my-car |
| `net-100` | review | Duplicate. "Net 100" = .NET SDK 10.0 (Microsoft, dev UBF8T346G9). The existing Homebrew ca |
| `net-80` | review | Duplicate. "Net 80" = .NET SDK 8.0 (Microsoft, dev UBF8T346G9). Cask already exists: https |
| `net-90` | review | Duplicate. "Net 90" = .NET SDK 9.0 (Microsoft, dev UBF8T346G9). Cask already exists: https |
| `nextcloud-desktop-client` | review | duplicate of existing cask 'nextcloud' |
| `nirvana` | review | Mac-App-Store-only. Nirvana (GTD to-do app, nirvanahq.com, bundle com.nirvanahq.desktop, d |
| `ntfs-disk-by-omi` | review | Mac-App-Store-only. NTFS Disk by Omi (NTFS read/write utility by JingZhi He, bundle com.om |
| `obs-studio` | review | duplicate of existing cask 'obs' |
| `onscreen-control` | review | REVIEW: broken. Installomator label 'onscreencontrol' is flagged broken (issue # |
| `openphone` | review | Cloudflare-gated / unverifiable. OpenPhone (rebranded "Quo"), VoIP desktop client, bundle |
| `oracle-java-jdk-17` | review | Duplicate. "Oracle Java JDK 17" = Oracle JDK 17 LTS (bundle com.oracle.java.17.jdk, dev VB |
| `oracle-java-jdk-21` | review | Duplicate. "Oracle Java JDK 21" = Oracle JDK 21 LTS (bundle com.oracle.java.21.jdk, dev VB |
| `oracle-java-jdk-22` | review | EOL non-LTS. Oracle JDK 22 (bundle com.oracle.java.22.jdk, dev VB5E2TV963). A real public |
| `oracle-java-jdk-23` | review | EOL non-LTS. Oracle JDK 23 (bundle com.oracle.java.23.jdk, dev VB5E2TV963). Real public do |
| `oracle-java-jdk-24` | review | EOL non-LTS. Oracle JDK 24 (bundle com.oracle.java.24.jdk, dev VB5E2TV963). Real public do |
| `oracle-java-jdk-25` | review | Duplicate. Slug = Oracle JDK 25 (bundle com.oracle.java.25.jdk, dev VB5E2TV963). Version-p |
| `owasp-zap` | review | Duplicate. Slug = OWASP ZAP / Zed Attack Proxy (zaproxy.org, current v2.17.0, https://gith |
| `padlet` | review | No public native download. Padlet (bundle com.wallwisher.padlet, dev MY6RRLM5WC) is a web |
| `palettebrain` | review | Purchase-gated. PaletteBrain (ChatGPT-for-macOS utility, palettebrain.com) requires buying |
| `pandasuite-studio` | review | Login-gated. PandaSuite Studio (no-code app builder, bundle com.pandasuite.studio, dev 2HL |
| `password-depot` | review | UNVERIFIABLE direct download: www.password-depot.de / .com return HTTP 503 to al |
| `peakto` | review | Account/purchase-gated. Peakto (Cyme photo organizer, bundle io.cyme.Peakto, dev 7PS8QUM93 |
| `pgmagic` | review | Purchase-gated. pgMagic (natural-language Postgres client, bundle xyz.hill.pgMagic, dev 2L |
| `pix` | review | Gated. "Pix" = PIX System (bundle com.pixsystem.pixmac, dev 7D45HCDK89), a secure media-re |
| `pix-3` | review | PIX (bundle com.electron.pix, dev ID 7D45HCDK89) = Autodesk PIX / PIX System pro |
| `plantronics-hub` | review | REVIEW: discontinued. https://www.poly.com/content/dam/www/software/PlantronicsH |
| `prelude-operator` | review | No public versioned desktop download. Prelude pivoted to Prelude Security/Detect; the Oper |
| `projectplace` | review | REVIEW: unversioned, no livecheck. https://service.projectplace.com/client_apps/ |
| `python-3` | review | homebrew-core already provides Python as formulae (python@3.14 and python@3.13 b |
| `r-remote` | review | Yamaha Pro Audio R Remote V6.0.0 (free). Download is EULA/session-gated: the page-listed l |
| `receipts-space` | review | "Receipts Space" (Dirk Holtwick, bundle de.holtwick.mac.homebrew.Receipts2, MAS id16049777 |
| `responsivelyapp` | review | Duplicate: cask "responsively" already exists (https://formulae.brew.sh/api/cask/responsiv |
| `rhino-7` | review | REVIEW: paid, gated. Rhino is commercial (McNeel). No public unauthenticated ver |
| `rhino-8` | review | REVIEW: paid, gated. Same as rhino-7: commercial McNeel app, download behind com |
| `rocketsim` | review | Mac App Store only (RocketSim for Xcode Simulator, https://apps.apple.com/us/app/rocketsim |
| `rstudio-desktop` | review | Duplicate: cask "rstudio" already exists (https://formulae.brew.sh/api/cask/rstudio.json - |
| `screen-share` | review | ND (cn.com.nd.pmcast) classroom screen-sharing app. No official vendor download page or pu |
| `screenml` | review | screenml.com is Cloudflare bot-gated: returns HTTP 503/410 to curl and to browser-UA fetch |
| `scribe-desktop` | review | Current Scribe Desktop by Scribehow is bundle com.scribehow.ScribeDesktop at v5. |
| `setup-checklist` | review | Jamf-Concepts/setup-checklist (github) ships ONLY beta releases — latest tag v0.4.0beta (a |
| `shellleap` | review | No official website found (shellleap.com/.app/.dev/.io all resolve to nothing — HTTP 000), |
| `shells` | review | Shells.com Desktop-as-a-Service. The Mac client is a thin streaming client for a paid clou |
| `sketchup-pro-2021` | review | Trimble SketchUp. Official download page (sketchup.trimble.com/en/download/all) only offer |
| `sketchup-pro-2022` | review | Trimble SketchUp. Official download page only offers 2026/2025/2024; 2022 is a superseded |
| `sketchup-pro-2023` | review | Trimble SketchUp. Official download page only offers 2026/2025/2024; 2023 is a superseded |
| `skopos-agent` | review | Skopos / Lupasafe (skoposlab.eu) cyber-risk endpoint agent. The agent is downloaded from t |
| `sleeve` | review | Replay Software Sleeve 3. Two channels: Mac App Store (apps.apple.com/app/id1606145041) an |
| `smugmug` | review | Help-center-gated / no public versioned URL. SmugMug macOS Uploader (bundle com.smugmug.Sm |
| `soundly` | review | Only an unversioned always-latest dmg: https://storage.googleapis.com/soundlyapp |
| `spark-desktop` | review | Duplicate. Already a cask: readdle-spark (name "Spark", homepage https://sparkma |
| `speediness` | review | Mac App Store only. Speediness by Sindre Sorhus (bundle com.sindresorhus.Speediness) ships |
| `splashtop-sos` | review | Only an unversioned always-latest dmg: https://download.splashtop.com/sos/Splash |
| `statusbuddy` | review | Gumroad/TestFlight-gated, no public versioned URL. StatusBuddy by Guilherme Rambo (insideg |
| `stream-deck` | review | Duplicate. Already a cask: elgato-stream-deck (name "Elgato Stream Deck", homepa |
| `streamline` | review | JS-gated, no public versioned URL. Streamline desktop app (Webalys, bundle com.webalys.str |
| `studies` | review | Mac App Store only. Studies (Mental Faculty, bundle com.mentalfaculty.studies.mac) is sold |
| `supercharge` | review | Paid app (one-time purchase via Gumroad / Setapp). Only a time-limited TRIAL is publicly d |
| `surfdrive` | review | Gated. Installomator source page (servicedesk.surf.nl/wiki/.../74225443) is logi |
| `talkdesk` | review | Talkdesk Workspace desktop app download is behind the Talkdesk Workspace tenant login (use |
| `teos-connect` | review | Sony TEOS Connect is part of Sony's enterprise TEOS workplace-management suite (tied to BR |
| `text-on-tap-overlay` | review | Vendor download page https://text-on-tap.live/overlay.html unreachable from sandbox (HTTP |
| `text-workflow` | review | Mac App Store only (Text Workflow: Text Converter, id 1600520682; dev gtrigonakis links on |
| `tigervnc-viewer` | review | Duplicate: a cask 'tigervnc' already exists (formulae.brew.sh/api/cask/tigervnc.json = HTT |
| `timebuzzer` | review | timeBuzzer requires a paid account/login to use (my.timebuzzer.com; 15-day trial). Downloa |
| `trash-sweep` | review | Vendor site https://trashsweep.gurubag.com/ unreachable from sandbox (HTTP 503 / anti-bot) |
| `ultracompare` | review | Only an unversioned dmg https://downloads.ultraedit.com/main/uc/mac/UltraCompare |
| `umbra` | review | Pay-what-you-want via Gumroad (Replay Software); no GitHub, no public versioned download e |
| `upaste` | review | Mac App Store only (uPaste - Clipboard Manager, id 1503649026, dev Wu Chenghao). https://a |
| `videostream` | review | Native Mac pkg exists but is stale + unversioned: https://cdn.getvideostream.com/videostre |
| `voiceedge` | review | Comcast Business VoiceEdge desktop app: distribution is gated behind a Comcast Business ac |
| `voices` | review | Voices (text-to-speech, Jordi Bruin / goodsnooze, bundle com.goodsnooze.voices, latest v2. |
| `vox-music-player` | review | Duplicate: already a cask. appcatalog bundle com.coppertino.Vox == existing cask "vox" (ht |
| `wacom-driver` | review | Duplicate: already a cask. appcatalog bundle com.wacom.wacomtablet == existing cask "wacom |
| `walkme` | review | WalkMe Editor (bundle com.walkme.editor) is a desktop app distributed only behin |
| `walkme-extension-for-safari` | review | WalkMe Extension is a Safari App Extension distributed only via the Mac App Store (https:/ |
| `wavepad` | review | NCH WavePad Mac download https://www.nch.com.au/components/wavepadmacu.zip (HTTP 200) is o |
| `weave` | review | No public versioned download; bundle com.weave.app deployed via appcatalog/MDM portal, no |
| `webfont` | review | com.virae.webfontapp (webfontapp.com) current app is Mac-App-Store/Setapp-distributed; onl |
| `webkiosk-8` | review | xProline WebKiosk; only public download is a license-locked trial (https://download.xproli |
| `wework-print` | review | bundle com.hp.roamsetup = HP Roam print client rebranded for WeWork; tenant/portal-provisi |
| `withsecure-elements` | review | WithSecure Elements Agent installer is public (https://download.withsecure.com/PSB/latest/ |
| `workplace-pure-client` | review | Konica Minolta Workplace Pure cloud-print client; download served only behind the Workplac |
| `xelion` | review | Xelion Classic Softphone (nl.xelion.softphone.Xelion8); apps.xelion.com download portal li |
| `xink` | review | account-gated SaaS email-signature client; download https://downloads.xink.io/ma |
| `xmledita` | review | CoxOne XML Edita is Mac-App-Store (id1142675672) + paid FastSpring; only public direct dow |
| `yodel` | review | Yodel is discontinued: www.yodel.io/apps now 301-redirects to a "Yodel End-of-Life FAQ" (s |
| `yoyotta` | review | YoYotta current v4 requires a subscription and yoyotta.com offers no direct v4 download li |
| `zerotier` | review | duplicate of existing Homebrew cask zerotier-one (ZeroTier One) |
| `zoho-workdrive-genie` | review | download confirmed (200, ~55MB) https://www.zoho.com/workdrive/downloads/edit-to |
| `zoom-workplace` | review | Duplicate: "Zoom Workplace" is the rebranded Zoom desktop client, bundle us.zoom.xos, alre |
