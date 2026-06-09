# Readiness — what's added, what isn't, and why

_Generated from `scripts/cask-master.sh` (REGISTRY) + `data/master-list.csv`. Regenerate after edits to avoid drift._

## Summary

| Bucket | Count |
|---|---|
| Total apps | 533 |
| Sourced | 533 |
| **Authored in cask-master.sh** | **318** |
| &nbsp;&nbsp;↳ via built-in source types | 240 |
| &nbsp;&nbsp;↳ via custom resolver functions | 78 |
| Needs a custom resolver (remaining) | 0 |
| Review | 196 |
| Ineligible | 18 |
| Other (low-confidence, verify) | 1 |
| DRYRUN-clean | 0 (requires macOS) |

Authored by source type: `{'github_tag': 71, 'direct': 55, 'electron': 9, 'msft_cdn': 2, 'github_compound': 1, 'github_arch': 11, 'direct_latest': 69, 'direct_arch': 18, 'custom': 78, 'direct_header': 4}`

Everything sourced is now in the script — a single `DRYRUN=1 bash scripts/cask-master.sh` on a Mac writes+audits all of them. `direct_latest` rows are `:no_check` (prune at DRYRUN).

## Custom-resolver apps (78) — verify these closely at DRYRUN

Authored via per-app `resolve_`/`write_cask_` in the script (header-only versions, per-release hash/build URLs, arch-split pkg, nested containers, version transforms). Facts in [`custom-todo.md`](custom-todo.md).

`barcode-studio, bimcollab-zoom, buhocleaner, capture-one, cato-client, cloudya, code42, comic-life-4, conniepad, cricut-design-space, daylite, delighted, dell-display-peripheral-manager, deskrest, displaylink-manager, eclipse-ide-for-embedded-cc-developers, eclipse-ide-for-scout-developers, final-draft-12, final-draft-13, flashprint-5, foldr, fotomagico, frameio-transfer, growly-glucose, guardian-browser, huddly, hudl-sportscode, huggingchat-mac, imanage-work-desktop, ipsw-updater, jamf-compliance-editor, jamf-connect-configuration, jamf-connect-login, joan-configurator, jpegmini-pro, keeper-secrets-manager-cli, lg-calibration-studio, macos-instantview, mamp-pro, maxon-cinema-4d-2026, medialab-connect, microsoft-company-portal, microsoft-powershell, mimiq, mister-horse-product-manager, monotype-connect, multiviewer-for-f1, netbird, noor, nvivo-14, nvivo-15, okiocam-snapshot-and-recorder, origami-3, poly-lens-desktop, postlab, praxislive, prisma-access-browser, setup-manager, sforzando, shellhistory, slido-for-powerpoint, smart-mirror-app, snapgene, soundfield-by-rode, spyder-x-elite, spyder-x-pro, starface, strongdm, studio-viewer, synology-active-backup-for-business-agent, synology-drive-client, universal-type-client, usher, windsurf, wonderpen, workbrew, xmlmind, zaxconvert`

## Not added — review / ineligible (214)

Why each can't be a cask (revisit if a vendor adds a public versioned download); per-app reason in the `bucket` column of [`../data/master-list.csv`](../data/master-list.csv):

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
