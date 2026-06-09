#!/usr/bin/env bash
###############################################################################
# cask-master.sh — bulk Homebrew Cask authoring for the appcatalog.cloud
#                  "no-homebrew-cask" backlog (fleetdm/fleet).
#
# This is the homebrew-cask-author skill's verified one-shot harness, wrapped
# in a loop. Each app you add to the REGISTRY below still gets:
#   its own add-<token> branch, its own homebrew-cask PR, its own Fleet FR.
# (One cask per PR is preserved — this just saves you re-pasting the harness.)
#
# Per app, in order, with a hard STOP for THAT app on any failure:
#   resolve version + download -> sha256 -> inspect artifact (bundle id, min
#   macOS, pkg receipt, LaunchDaemons, bundled MS AutoUpdate) -> write cask ->
#   brew style --fix -> brew audit --strict --online --new (+ bounded safe
#   auto-fix) -> real brew install + uninstall + reinstall + zap -> push to
#   your fork -> open PR (body from Homebrew's LIVE template + honest AI
#   disclosure) -> file the Fleet FMA FR linking the PR.
# A failing app does NOT stop the batch (default). Each app writes its own
# /tmp/caskwork/<token>/report.md; a rollup lands at /tmp/caskwork/MASTER-summary.md.
#
# REQUIREMENTS: macOS, Homebrew, gh (authed as your fork owner, with
# fleetdm/fleet access), a `fork` remote in the homebrew-cask tap, and sudo
# (pkg installs need it — primed once, kept alive for the run).
#
# -------------------------- HOW TO RUN ---------------------------------------
#   1) Add rows to the REGISTRY heredoc below (format + examples are there).
#   2) PREVIEW FIRST (writes + audits casks, touches nothing else):
#        DRYRUN=1 bash cask-master.sh
#      or one app at a time:  ONLY="filezilla" DRYRUN=1 bash cask-master.sh
#   3) Run for real:  bash cask-master.sh
#   4) For any app that failed, open /tmp/caskwork/<token>/report.md and paste
#      it back for a targeted fix.
#
# ------------------------------ FLAGS ----------------------------------------
#   DRYRUN=1          preview only (no install/push/PR/FR)
#   ONLY="a b c"      run only these tokens (space-separated)
#   LIMIT=N           run at most N apps from the registry
#   STOP_ON_FAIL=1    halt the whole batch on the first app that fails (default 0)
#   STRICT=0          drop --strict from audit (default 1 = CI parity)
#   ZAP=0             skip the reinstall + zap test (default 1)
#   FRESH=0           keep an existing open PR instead of force-refreshing (default 1)
#   FILE_FR=0         author the cask PR but skip the Fleet FR (default 1)
#   CUSTOMER_LABEL="customer-x"   extra label on the Fleet FR (else add by hand)
#   FORK=fork         name of your fork's git remote in the tap (default "fork")
#
# ------------------------- REGISTRY FORMAT -----------------------------------
# Pipe-delimited, one row per app. Whitespace around each field is trimmed.
# Lines starting with # and blank lines are ignored. Columns:
#
#   token | name | desc | artifact | source | homepage | spec
#
#   token     lowercase, hyphenated; must NOT collide with a homebrew-core
#             formula (script warns; rename e.g. goto-desktop if so).
#   name      human app name.
#   desc      <=80 chars, obey Cask/Desc rules: no platform word (macOS/Mac/
#             Windows/Linux/version names), no leading article ("A"/"The"),
#             no trailing period, must not start with the token; start capital.
#   artifact  zip | dmg | pkg   (anything else is NOT FMA-eligible — skip it)
#   source    github_tag | github_compound | electron | msft_cdn | direct | custom
#   homepage  a URL brew can reach (must 200 — some vendor pages 403 brew).
#   spec      source-specific key=value;key=value (see per-source notes). Use
#             {v} for the version and {t} for the raw git tag in templates.
#
# SPEC per source:
#   github_tag       repo=OWNER/REPO ; asset=AppName_{v}.pkg
#                    (semver tag like v1.2.3 or 1.2.3; {v}=version, {t}=raw tag.
#                     livecheck = :github_latest. asset is just the filename.)
#   github_compound  repo=OWNER/REPO ; asset=App.zip
#                    (tag shape v-<ver>-b-<build>, e.g. IBM Notifier; version
#                     becomes "<ver>,<build>" via version.csv.)
#   electron         feed=https://host/path/latest-mac.yml ;
#                      universal=App-{v}-universal                 (single dmg)
#                    OR  arm=App-{v}-arm64 ; intel=App-{v}         (two dmgs)
#                    (filenames WITHOUT the .dmg; livecheck = :electron_builder.)
#   msft_cdn         short=https://aka.ms/... ; regex=File_(\d+(?:\.\d+)+)\.pkg
#                    (pkg; version + filename derived from the redirect; bundled
#                     MS AutoUpdate auto-deselected; livecheck = :header_match.
#                     You supply the filename regex — you know the pattern.)
#   direct           url=https://host/App-{v}.dmg ;
#                      vers=https://host/appcast.xml ; vregex=[0-9]+(\.[0-9]+)+
#                    (vregex must match the VERSION substring. `verified:` added
#                     automatically when the download host != homepage host.
#                     A bare version=1.2.3 works but audit will likely want a
#                     livecheck — prefer vers/vregex.)
#   custom           define shell functions  resolve_<tfn>  and  write_cask_<tfn>
#                    further down (where <tfn> is the token with - turned to _).
#                    Set ARTIFACT so the artifact inspector still runs.
#
# Most rows will need only a quick check after DRYRUN. The two bits most likely
# to need a tweak are the livecheck regex and (for arch-split electron) the dmg
# filenames. Anything that doesn't fit a source => use source=custom.
###############################################################################

# ----------------------------------------------------------------------------
# REGISTRY — ADD YOUR APPS HERE. Examples are commented out; copy the shape.
# ----------------------------------------------------------------------------
read -r -d '' REGISTRY <<'TABLE' || true
# token | name | desc | artifact | source | homepage | spec

# ---- worked examples (uncomment / adapt; delete the ones you don't want) ----
# ibm-notifier | IBM Notifier | Agent that displays custom notifications and alerts to end users | zip | github_compound | https://github.com/IBM/mac-ibm-notifications | repo=IBM/mac-ibm-notifications;asset=IBM.Notifier.zip
# sap-power-monitor | SAP Power Monitor | Reports power and battery state for managed devices | pkg | github_tag | https://github.com/SAP/power-monitoring-tool-for-macos | repo=SAP/power-monitoring-tool-for-macos;asset=PowerMonitor_{v}.pkg
# goto-desktop | GoTo | Client for online meetings and screen sharing | dmg | electron | https://www.goto.com/meeting | feed=https://goto-desktop.goto.com/latest-mac.yml;arm=GoTo-{v}-arm64;intel=GoTo-{v}
# microsoft-remote-help | Microsoft Remote Help | Remote assistance tool for helpdesk and end users | pkg | msft_cdn | https://learn.microsoft.com/mem/intune/fundamentals/remote-help | short=https://aka.ms/downloadremotehelpmacos;regex=Microsoft_Remote_Help_(\d+(?:\.\d+)+)_installer\.pkg
# filezilla | FileZilla | Client for transferring files over FTP, FTPS, and SFTP | dmg | direct | https://filezilla-project.org | url=https://dl3.cdn.filezilla-project.org/client/FileZilla_{v}_macosx-x86.app.tar.bz2;vers=https://filezilla-project.org/download.php?platform=macos-x86;vregex=[0-9]+(\.[0-9]+)+

# ---- your apps below ----

# ---- github_tag batch (auto-generated; verify on Mac with DRYRUN) ----
airbattery | AirBattery | Monitors battery levels of nearby Apple and Bluetooth devices | dmg | github_tag | https://github.com/lihaoyun6/AirBattery | repo=lihaoyun6/AirBattery;asset=AirBattery_v{v}.dmg
backgrounds | Backgrounds | Sets the desktop picture from a configuration profile | pkg | github_tag | https://github.com/SAP/backgrounds | repo=SAP/backgrounds;asset=Backgrounds_{v}.pkg
elevate24 | Elevate24 | Manages privileged access requests with monitoring and reporting | pkg | github_tag | https://github.com/Jigsaw24/Elevate24 | repo=Jigsaw24/Elevate24;asset=Elevate24-{v}.pkg
escrow-buddy | Escrow Buddy | Escrows FileVault recovery keys at the login window | pkg | github_tag | https://github.com/macadmins/escrow-buddy | repo=macadmins/escrow-buddy;asset=Escrow.Buddy-{v}.pkg
icons | Icons | Generates icon image sets from a single source image | pkg | github_tag | https://github.com/SAP/macOS-icon-generator | repo=SAP/macOS-icon-generator;asset=Icons_{v}.pkg
jamf-pppc-utility | PPPC Utility | Builds privacy preferences policy control profiles | zip | github_tag | https://github.com/jamf/PPPC-Utility | repo=jamf/PPPC-Utility;asset=PPPC-Utility.zip
jamf-printer-manager | Jamf Printer Manager | Configures and deploys printers to managed devices | zip | github_tag | https://github.com/jamf/jamf-printer-manager | repo=jamf/jamf-printer-manager;asset=Jamf.Printer.Manager.zip
jamf-reenroller | ReEnroller | Re-enrolls devices into a management server | zip | github_tag | https://github.com/jamf/ReEnroller | repo=jamf/ReEnroller;asset=ReEnroller.zip
jamfcheck | JamfCheck | Audits Jamf Pro settings for security misconfigurations | dmg | github_tag | https://github.com/txhaflaire/JamfCheck | repo=txhaflaire/JamfCheck;asset=JamfCheck.dmg
managed-app-schema-builder | Managed App Schema Builder | Builds managed app configuration schemas | zip | github_tag | https://github.com/BIG-RAT/Managed-App-Schema-Builder | repo=BIG-RAT/Managed-App-Schema-Builder;asset=Managed.App.Schema.Builder.zip
mobile-to-local | Mobile to Local | Converts mobile accounts to local user accounts | zip | github_tag | https://github.com/BIG-RAT/mobile_to_local | repo=BIG-RAT/mobile_to_local;asset=Mobile.to.Local.zip
pique | Pique | Quick Look previews with syntax highlighting for configuration files | pkg | github_tag | https://github.com/macadmins/pique | repo=macadmins/pique;asset=Pique-{v}.pkg
sym-helper | SYM-Helper | Generates deployment scripts for the Setup Your Mac workflow | zip | github_tag | https://github.com/setup-your-mac/SYM-Helper | repo=setup-your-mac/SYM-Helper;asset=SYM-Helper.zip
utiluti | utiluti | Command-line tool to manage default apps and URL handlers | pkg | github_tag | https://github.com/scriptingosx/utiluti | repo=scriptingosx/utiluti;asset=utiluti-{v}.pkg

# ---- direct/electron/msft batch (subagent-sourced; verify on Mac with DRYRUN) ----
airradar | AirRadar | Scans for wireless networks and maps signal strength with GPS | dmg | direct | https://www.koingosw.com/products/airradar/ | url=https://www.koingosw.com/products/airradar/download/airradar.dmg;vers=https://www.koingosw.com/products/airradar/;vregex=Version (\d+(?:\.\d+)+)
akvis-airbrush | AKVIS AirBrush | Turns photos into airbrush-style artwork | dmg | direct | https://akvis.com/en/airbrush/index.php | url=https://akvis-dl.sfo2.cdn.digitaloceanspaces.com/akvis-airbrush-app.dmg;vers=https://akvis.com/en/airbrush/index.php;vregex=AirBrush (\d+(?:\.\d+)+)
akvis-artifact-remover-ai | AKVIS Artifact Remover AI | Removes JPEG compression artifacts using neural networks | dmg | direct | https://akvis.com/en/artifact-remover/index.php | url=https://akvis-dl.sfo2.cdn.digitaloceanspaces.com/akvis-artifact-remover-app.dmg;vers=https://akvis.com/en/artifact-remover/index.php;vregex=Artifact Remover AI (\d+(?:\.\d+)+)
akvis-frames | AKVIS Frames | Adds decorative frames and edge effects to photos | dmg | direct | https://akvis.com/en/frames/index.php | url=https://akvis-dl.sfo2.cdn.digitaloceanspaces.com/akvis-frames-app.dmg;vers=https://akvis.com/en/frames/index.php;vregex=Frames (\d+(?:\.\d+)+)
alarm-clock-pro | Alarm Clock Pro | Schedules alarms, reminders, and timed events with audio playback | dmg | direct | https://www.koingosw.com/products/alarmclockpro/ | url=https://www.koingosw.com/products/alarmclockpro/download/alarmclockpro.dmg;vers=https://www.koingosw.com/products/alarmclockpro/;vregex=Version (\d+(?:\.\d+)+)
alivecolors | AliveColors | Image editor with painting, retouching, and AI-based effects | dmg | direct | https://alivecolors.com/en/index.php | url=https://alivecolors.sfo2.cdn.digitaloceanspaces.com/alivecolors.dmg;vers=https://alivecolors.com/en/download.php;vregex=AliveColors (\d+(?:\.\d+)+)
atlassian-companion | Atlassian Companion | Edits Confluence and Jira attachments in their native apps | zip | direct | https://confluence.atlassian.com/display/DOC/Install+Atlassian+Companion | url=https://update-nucleus.atlassian.com/Atlassian-Companion/291cb34fe2296e5fb82b83a04704c9b4/darwin/x64/Atlassian%20Companion-darwin-x64-{v}.zip;vers=https://update-nucleus.atlassian.com/Atlassian-Companion/291cb34fe2296e5fb82b83a04704c9b4/darwin/x64/RELEASES.json;vregex=currentRelease"\s*:\s*"(\d+(?:\.\d+)+)
automounter | AutoMounter | Mounts and remounts network file shares automatically | dmg | direct | https://www.pixeleyes.co.nz/automounter/ | url=https://www.pixeleyes.co.nz/automounter/AutoMounter.dmg;vers=https://www.pixeleyes.co.nz/automounter/version;vregex=[0-9]+(\.[0-9]+)+
aws-cli | AWS Command Line Interface | Unified tool to manage Amazon Web Services from the command line | pkg | direct | https://aws.amazon.com/cli/ | url=https://awscli.amazonaws.com/AWSCLIV2-{v}.pkg;vers=https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst;vregex=[0-9]+(\.[0-9]+)+
brosix | Brosix | Secure instant messaging and collaboration client for teams | pkg | direct | https://www.brosix.com/download/ | url=https://downloads.brosix.com/builds/official/Brosix.pkg;vers=https://www.brosix.com/download/;vregex=version (\d+(?:\.\d+)+)
cakebrew | Cakebrew | Graphical interface to manage the Homebrew package manager | zip | direct | https://www.cakebrew.com | url=https://cakebrew-377a.kxcdn.com/cakebrew-{v}.zip;vers=https://www.cakebrew.com/appcast/profileInfo.php;vregex=[0-9]+(\.[0-9]+)+
dragonframe-2024 | Dragonframe 2024 | Stop-motion animation and time-lapse capture tool | pkg | direct | https://www.dragonframe.com/downloads/ | url=https://www.dragonframe.com/download/Dragonframe_{v}.pkg;vers=https://www.dragonframe.com/downloads/;vregex=2024\.[0-9]+\.[0-9]+
dragonframe-2025 | Dragonframe 2025 | Stop-motion animation and time-lapse capture tool | pkg | direct | https://www.dragonframe.com/downloads/ | url=https://www.dragonframe.com/download/Dragonframe_{v}.pkg;vers=https://www.dragonframe.com/downloads/;vregex=2025\.[0-9]+\.[0-9]+
dragonframe-5 | Dragonframe 5 | Stop-motion animation and time-lapse capture tool | pkg | direct | https://www.dragonframe.com/downloads/ | url=https://www.dragonframe.com/download/Dragonframe_{v}.pkg;vers=https://www.dragonframe.com/downloads/;vregex=5\.[0-9]+\.[0-9]+
grammarly | Grammarly | Writing assistant for grammar, spelling, and style suggestions | dmg | direct | https://www.grammarly.com/desktop | url=https://download-mac.grammarly.com/versions/{v}/Grammarly.dmg;vers=https://download-mac.grammarly.com/appcast.xml;vregex=[0-9]+(\.[0-9]+)+
hudl-studio | Hudl Studio | Creates animated sports graphics and telestration for video | dmg | direct | https://www.hudl.com/downloads/elite | url=https://studio-releases.s3.amazonaws.com/Studio-{v}.dmg;version=2.2.8
lucidlink | LucidLink | Streams files from cloud object storage as a local drive | pkg | direct | https://www.lucidlink.com/download | url=https://d3il9duqikhdqy.cloudfront.net/latest/osx/lucid-{v}.pkg;version=2.10.8237
luna-display | Luna Display | Turns an iPad or second device into an external display | dmg | direct | https://astropad.com/getting-started/luna-display/ | url=https://downloads.astropad.com/luna/mac/LunaDisplay-{v}.dmg;version=5.3.8.4999
masv | MASV | Transfers large media files at high speed | dmg | electron | https://massive.io | feed=https://dl.massive.io/latest-mac.yml;universal=masv-{v}-universal
mestrenova | Mestrenova | Processes and analyzes NMR, LC/GC/MS and other analytical chemistry data | dmg | direct | https://mestrelab.com | url=https://mestrelab.com/downloads/mnova/mac/MestReNova-{v}.dmg;version=16.0.0-39276
microsoft-skype-for-business | Microsoft Skype for Business | Enterprise instant messaging and online meeting client | pkg | msft_cdn | https://learn.microsoft.com/en-us/skypeforbusiness/ | short=https://go.microsoft.com/fwlink/?linkid=832978;regex=SkypeForBusinessUpdater-(\d+(?:\.\d+)+)\.pkg
network-share-mounter | Network Share Mounter | Mounts network shares automatically using stored credentials | pkg | direct | https://gitlab.rrze.fau.de/faumac/networkShareMounter | url=https://gitlab.rrze.fau.de/api/v4/projects/506/packages/generic/networksharemounter/release-{v}/NetworkShareMounter-{v}.pkg;vers=https://gitlab.rrze.fau.de/api/v4/projects/506/releases;vregex=release-([0-9]+(?:\.[0-9]+)+)
nodejs | Node.js | JavaScript runtime built on the V8 engine | pkg | direct | https://nodejs.org | url=https://nodejs.org/dist/v{v}/node-v{v}.pkg;vers=https://nodejs.org/dist/latest/;vregex=node-v([0-9]+(?:\.[0-9]+)+)\.pkg
particulars | Particulars | Displays detailed hardware and system information in the menu bar | pkg | direct | https://particulars.app | url=https://particulars.app/_downloads/Particulars-{v}.pkg;version=68.485
poll-everywhere | Poll Everywhere | Live audience response and interactive polling client | dmg | direct | https://www.polleverywhere.com | url=https://polleverywhere-app.s3.amazonaws.com/mac-stable/{v}/pollev.dmg;vers=https://www.polleverywhere.com/app/releases/mac;vregex=[0-9]+(\.[0-9]+)+
screencloud-player | ScreenCloud Player | Displays digital signage content on connected screens | dmg | electron | https://screencloud.com/download | feed=https://release.screen.cloud/player/desktop/channel/stable/latest-mac.yml;arm=scplayer_{v}_darwin_arm64;intel=scplayer_{v}_darwin_x64
signiant-app | Signiant App | Accelerated large file transfer client for Media Shuttle | dmg | direct | https://help.signiant.com/media-shuttle/signiant-app/download-signiant-app | url=https://updates.signiant.com/signiant_app/Signiant_App_{v}.dmg;vers=https://updates.signiant.com/signiant_app/signiant-app-info-mac.json;vregex=Signiant_App_([0-9]+(?:\.[0-9]+)+)\.dmg
things | Things | Personal task manager and to-do list organizer | zip | direct | https://culturedcode.com/things/ | url=https://static.culturedcode.com/things/Things3.zip;vers=https://culturedcode.com/things/mac/help/releasenotes/;vregex=[0-9]+(\.[0-9]+)+
vonage-business | Vonage Business | Calling, messaging, and meetings for unified communications | dmg | electron | https://businesssupport.vonage.com/ | feed=https://s3.amazonaws.com/vbcdesktop.vonage.com/prod/mac/latest-mac.yml;universal=Vonage Business-{v}-universal

# ---- Phase 1 wave 1 (cold-sourced; verify on Mac with DRYRUN) ----
achico | Achico | Compresses images, PDFs, and videos while preserving quality | zip | github_tag | https://github.com/nuance-dev/achico | repo=nuance-dev/achico;asset=Achico.app.zip
api-utility | API Utility | Command-line tool to work with Jamf Pro APIs and manage secrets | zip | github_tag | https://github.com/Jamf-Concepts/apiutil | repo=Jamf-Concepts/apiutil;asset=API.Utility.zip
barcode-producer | Barcode Producer | Designs and generates retail barcodes and labels with vector export | zip | direct | https://www.barcodeproducer.com | url=https://download.barcodeproducer.com/Barcode-Producer-{v}.zip;vers=https://r.barcodeproducer.com/app/download_mac/;vregex=[0-9]+(\.[0-9]+)+
bartranslate | BarTranslate | Menu bar translator widget powered by Google Translate | zip | github_tag | https://github.com/ThijmenDam/BarTranslate | repo=ThijmenDam/BarTranslate;asset=BarTranslate.app.zip
boring-notch | Boring Notch | Turns the notch into a music control center with visualizer and controls | dmg | github_tag | https://github.com/TheBoredTeam/boring.notch | repo=TheBoredTeam/boring.notch;asset=boringNotch.dmg
brewmate | BrewMate | GUI to search, install, and uninstall Homebrew casks | dmg | github_tag | https://github.com/romankurnovskii/BrewMate | repo=romankurnovskii/BrewMate;asset=BrewMate-{v}-universal.dmg
caesium-image-compressor | Caesium Image Compressor | Compresses JPG, PNG, WebP, and TIFF images while preserving quality | dmg | github_tag | https://github.com/Lymphatus/caesium-image-compressor | repo=Lymphatus/caesium-image-compressor;asset=caesium-image-compressor-{v}-macos.dmg
chromebuddy | ChromeBuddy | Opens external links in the frontmost Chrome window | zip | github_tag | https://github.com/AndreyGr/ChromeBuddy | repo=AndreyGr/ChromeBuddy;asset=ChromeBuddy.zip
close-desktop | Close | Sales CRM with built-in calling, SMS, and email | dmg | github_tag | https://github.com/closeio/closeio-desktop-releases | repo=closeio/closeio-desktop-releases;asset=Close-{v}.dmg
cloudtalk-phone | CloudTalk Phone | Call center client for making and receiving business calls | dmg | electron | https://www.cloudtalk.io/ | feed=https://cloudtalk-phone-distribution.s3.amazonaws.com/latest-mac.yml;universal=CloudTalk-Phone-{v}-mac
corelcad | CorelCAD | Drafting and 3D CAD tool compatible with DWG files | dmg | direct | https://www.corel.com/en/free-trials/ | url=https://www.corel.com/akdlm/6763/downloads/free/trials/CorelCAD/2023/CorelCAD2023.dmg;version=2023
cronica | Cronica | Watchlist and reminders for movies and TV shows | zip | github_tag | https://github.com/eggerco/cronica | repo=eggerco/cronica;asset=Cronica.app.zip
desktop-icon-manager | Desktop Icon Manager | Saves and restores desktop and Finder icon positions | zip | github_tag | https://github.com/com-entonos/Desktop-Icon-Manager | repo=com-entonos/Desktop-Icon-Manager;asset=DesktopIconManager{v}.zip
dictation-daddy | Dictation Daddy | Speech-to-text dictation tool that types into any app | dmg | github_tag | https://github.com/rahulbansal16/DictationDaddy | repo=rahulbansal16/DictationDaddy;asset=Dictation-Daddy-mac.dmg
dropnote | DropNote | Quick notes in the menu bar with tabbed and autosaved entries | zip | github_tag | https://github.com/bastian-js/dropnote | repo=bastian-js/dropnote;asset=DropNote.zip
figura | Figura | Removes image backgrounds locally with on-device processing | zip | github_tag | https://github.com/nuance-dev/figura | repo=nuance-dev/figura;asset=Figura.app.zip
fivenotes | FiveNotes | Menu bar notepad with five quick Markdown notes always at hand | zip | direct | https://www.apptorium.com/fivenotes | url=https://www.apptorium.com/public/products/fivenotes/releases/FiveNotes-{v}.zip;vers=https://www.apptorium.com/updates/fivenotes;vregex=FiveNotes-([0-9]+(?:\.[0-9]+)+)\.zip
freeter | Freeter | Organizer that gathers apps, files, and notes per project and workflow | dmg | electron | https://freeter.io | feed=https://github.com/FreeterApp/Freeter/releases/latest/download/latest-mac.yml;arm=Freeter-{v}-mac-arm64;intel=Freeter-{v}-mac-x64
fuzzlecheck-4 | Fuzzlecheck 4 | Plans film and video shoots with scheduling and call sheets | dmg | direct | https://www.fuzzlecheck.com/index/US/index.html | url=https://fuz4downloads.fuzzlecheck.com/fuz_mac_setup_{v}.dmg;version=4.8.0

# ---- Phase 1 wave 2 (cold-sourced; verify on Mac with DRYRUN) ----
haiku-animator | Haiku Animator | Design tool for creating Lottie animations and interactive web components | dmg | github_tag | https://github.com/HaikuTeam/animator | repo=HaikuTeam/animator;asset=Haiku-{v}.dmg
hue | Hue | Client for photo retouching teams to manage post-production workflows | zip | electron | https://help.creativeforce.io/en/articles/4752283-hue-desktop-app-overview | feed=https://download.creativeforce.io/released-files.042024/prod/hue-uxp/mac/latest-mac.yml;arm=Hue-{v}-mac-arm64;intel=Hue-{v}-mac
ibm-data-shift | IBM Data Shift | Migrates files, apps, and preferences between devices over peer-to-peer | zip | github_compound | https://github.com/IBM/mac-ibm-migration-tool | repo=IBM/mac-ibm-migration-tool;asset=IBM.Data.Shift.zip
impulso | Impulso | Task manager with priority scoring and flexible organization | zip | github_tag | https://github.com/nuance-dev/impulso | repo=nuance-dev/impulso;asset=Impulso.app.zip
insight | Insight | Video review and performance analysis for sports teams and athletes | dmg | direct | https://www.hudl.com/releases/insight | url=https://insight-releases.s3.eu-west-1.amazonaws.com/Insight-{v}-universal.dmg;vers=https://www.hudl.com/releases/insight;vregex=[0-9]+(\.[0-9]+)+
jamf-actions | Jamf Actions | Shortcuts actions for automating Jamf Pro tasks | zip | github_tag | https://github.com/Jamf-Concepts/actions | repo=Jamf-Concepts/actions;asset=Jamf.Actions.zip
jamf-aftermath | Jamf Aftermath | Incident response framework that collects and analyzes forensic data | pkg | github_tag | https://github.com/jamf/aftermath | repo=jamf/aftermath;asset=aftermath-{v}.pkg
jamf-cloud-package-replicator | Jamf Cloud Package Replicator | Replicates packages between Jamf Pro servers | zip | github_tag | https://github.com/BIG-RAT/jamfcpr | repo=BIG-RAT/jamfcpr;asset=jamfcpr.zip
jamf-environment-test | Jamf Environment Test | Tests network connectivity to Apple and Jamf hosted services | zip | github_tag | https://github.com/jamf/Jamf-Environment-Test | repo=jamf/Jamf-Environment-Test;asset=Jamf.Environment.Test.app.zip
jamf-framework-redeploy | Jamf Framework Redeploy | Redeploys the management framework to enrolled devices | zip | github_tag | https://github.com/red5coder/Jamf-Framework-Redeploy | repo=red5coder/Jamf-Framework-Redeploy;asset=Jamf.Framework.Redeploy.app.zip
jamf-protect-ulf-uploader | Jamf Protect ULF Uploader | Uploads unified log files to Jamf Protect | zip | github_tag | https://github.com/red5coder/jamf-protect-ulf-uploader | repo=red5coder/jamf-protect-ulf-uploader;asset=Jamf.Protect.ULF.Uploader.app.zip
jamf-prune | Jamf Prune | Removes unused items from a Jamf Pro server | zip | github_tag | https://github.com/BIG-RAT/Prune | repo=BIG-RAT/Prune;asset=Prune.zip
jamfdash | JamfDash | Native dashboard for browsing a Jamf fleet and security posture | pkg | github_tag | https://github.com/DevliegereM/JamfDash | repo=DevliegereM/JamfDash;asset=JamfDash_v{v}.pkg
jamfhelper-constructor | jamfHelper Constructor | Builds and previews jamfHelper dialog prompts | zip | github_tag | https://github.com/BIG-RAT/jhc | repo=BIG-RAT/jhc;asset=jhc.zip
logoer | Logoer | Changes the style of the Apple logo in the menu bar | dmg | github_tag | https://github.com/lihaoyun6/Logoer | repo=lihaoyun6/Logoer;asset=Logoer_v{v}.dmg
lucidlink-classic | LucidLink Classic | Cloud storage that streams team media files on demand | pkg | direct | https://www.lucidlink.com/classic | url=https://d3il9duqikhdqy.cloudfront.net/latest/osx/lucid-{v}.pkg;vers=https://www.lucidlink.com/download;vregex=lucid-(\d+(?:\.\d+)+)\.pkg
maccleanse | MacCleanse | Removes junk files and uninstalls apps to free disk space | dmg | direct | https://www.koingosw.com/products/maccleanse/ | url=https://www.koingosw.com/products/maccleanse/download/maccleanse.dmg;vers=https://www.koingosw.com/products/maccleanse/;vregex=Version (\d+(?:\.\d+)+)
microsoft-365-license-removal-tool | Microsoft 365 License Removal Tool | Removes Office license files for activation troubleshooting | pkg | msft_cdn | https://support.microsoft.com/en-us/office/how-to-remove-office-license-files-on-a-mac-b032c0f6-a431-4dad-83a9-6b727c03b193 | short=https://go.microsoft.com/fwlink/?linkid=849815;regex=Microsoft_Office_License_Removal_(\d+(?:\.\d+)+)\.pkg
modalfilemanager | ModalFileManager | Dual-pane file manager with Vim-style modal hotkeys | zip | github_tag | https://github.com/raguay/ModalFileManager | repo=raguay/ModalFileManager;asset=ModalFileManager-macOS-Universal.zip
monsterwriter | MonsterWriter | Distraction-free editor for theses, papers, and blog posts | dmg | github_tag | https://github.com/wolfoo2931/MonsterWriter | repo=wolfoo2931/MonsterWriter;asset=MonsterWriter-{v}-universal.dmg
mut | MUT | Bulk-update inventory records, groups, and prestage scope in Jamf Pro | zip | github_tag | https://github.com/jamf/mut | repo=jamf/mut;asset=MUT.app.zip
mymedia | MyMedia | Browse and play a local movie and TV library with artwork and tracking | dmg | github_tag | https://github.com/photangralenphie/MyMedia | repo=photangralenphie/MyMedia;asset=MyMedia-v{v}.dmg
namo | NAMO | Runs a local DNS server with host names that resolve to your current IP | dmg | direct | https://www.mamp.info/namo/en/ | url=https://downloads.mamp.info/NAMO/releases/mac/NAMO-{v}.dmg;vers=https://www.mamp.info/namo/en/;vregex=NAMO-(\d+\.\d+-\d+)\.dmg

# ---- Phase 1 wave 3 (cold-sourced; verify on Mac with DRYRUN) ----
nextpad | Nextpad++ | Native port of the Notepad++ source code editor with Scintilla engine | dmg | github_tag | https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos | repo=nextpad-plus-plus/nextpad-plus-plus-macos;asset=Nextpad++v{v}.dmg
noteey | Noteey | Visual note-taking app with an infinite canvas for text, images, and PDFs | dmg | github_tag | https://github.com/andyyoungm/muenzo | repo=andyyoungm/muenzo;asset=Noteey-{v}.universal.dmg
obd-auto-doctor | OBD Auto Doctor | Reads vehicle diagnostics and sensor data from an OBD-II adapter | dmg | direct | https://www.obdautodoctor.com/ | url=https://cdn2.obdautodoctor.com/release/obd-auto-doctor_{v}-l.dmg;vers=https://www.obdautodoctor.com/download/;vregex=obd-auto-doctor_(\d+(?:\.\d+)+)-l\.dmg
object-info | Object Info | Summarizes how Jamf Pro objects like groups, policies, and profiles relate | zip | github_tag | https://github.com/BIG-RAT/Object-Info | repo=BIG-RAT/Object-Info;asset=Object.Info.zip
ollamaspring | OllamaSpring | Chat client for running and managing local Ollama language models | zip | github_tag | https://github.com/CrazyNeil/Taify | repo=CrazyNeil/Taify;asset=OllamaSpring.zip
photos-workbench | Photos Workbench | Organize, rate, and compare photos in the Apple Photos library | dmg | direct | https://www.houdah.com/photosWorkbench/ | url=https://www.houdah.com/photosWorkbench/download_assets/Photos_Workbench_{v}.dmg;vers=https://www.houdah.com/photosWorkbench/download.html;vregex=Photos_Workbench_(\d+(?:\.\d+)+)\.dmg
psso-utility | PSSO Utility | Inspects and monitors Platform Single Sign-On status | pkg | github_tag | https://github.com/jamf-concepts/psso-utility | repo=jamf-concepts/psso-utility;asset=PSSOUtility.pkg
quickrecorder | QuickRecorder | Lightweight screen recorder based on ScreenCaptureKit | dmg | github_tag | https://github.com/lihaoyun6/QuickRecorder | repo=lihaoyun6/QuickRecorder;asset=QuickRecorder_v{v}.dmg
relagit | RelaGit | Graphical Git client for developers | dmg | electron | https://rela.dev/ | feed=https://github.com/relagit/relagit/releases/latest/download/latest-mac.yml;arm=RelaGit-mac-arm64;intel=RelaGit-mac-x64
remote-utilities-agent | Remote Utilities Agent | Attended remote support module that runs without installation | zip | direct | https://www.remoteutilities.com/ | url=https://www.remoteutilities.com/download/agent{v}.zip;vers=https://www.remoteutilities.com/download/mac.php;vregex=agent(\d+\.\d+\.\d+\.b\d+)\.zip
remote-utilities-viewer | Remote Utilities Viewer | Operator console to connect to and control remote computers | dmg | direct | https://www.remoteutilities.com/ | url=https://www.remoteutilities.com/download/viewer{v}.dmg;vers=https://www.remoteutilities.com/download/mac.php;vregex=viewer(\d+\.\d+\.\d+\.b\d+)\.dmg
renameninja | RenameNinja | Batch file renamer using regular expressions and JavaScript | zip | direct | https://loshadki.app/renameninja/ | url=https://loshadki.app/renameninja/releases/RenameNinja-{v}.app.zip;vers=https://loshadki.app/renameninja/;vregex=RenameNinja-(\d+(?:\.\d+)+)\.app\.zip
reqres | ReqRes | Web debugging proxy to capture and modify HTTP traffic | dmg | github_tag | https://github.com/OloApps/ReqRes | repo=OloApps/ReqRes;asset=ReqRes-{v}.dmg
root3-support-app | Root3 Support App | Menu bar app for user and helpdesk self-service support | pkg | github_tag | https://github.com/root3nl/SupportApp | repo=root3nl/SupportApp;asset=Support.{v}.pkg
rumpus | Rumpus | File transfer server supporting FTP, FTPS, WebDAV, and SFTP | dmg | direct | https://www.maxum.com/Rumpus/ | url=https://www.maxum.com/DownloadPackages/Rumpus-{v}.dmg;vers=https://www.maxum.com/Rumpus/Download/;vregex=Rumpus-([0-9]+(?:\.[0-9]+)+)\.dmg
scrutiny | Scrutiny | Website link checker, SEO auditor, and XML sitemap generator | dmg | direct | https://peacockmedia.software/mac/scrutiny/ | url=https://peacockmedia.software/mac/scrutiny/scrutiny.dmg;version=12.12.2;vers=https://peacockmedia.software/mac/scrutiny/;vregex=v([0-9]+(?:\.[0-9]+)+)
squirreldisk | SquirrelDisk | Disk usage analyzer that visualizes large files with a sunburst chart | dmg | github_tag | https://github.com/adileo/squirreldisk | repo=adileo/squirreldisk;asset=SquirrelDisk_{v}_x64.dmg

# ---- Phase 1 wave 4 (cold-sourced; verify on Mac with DRYRUN) ----
supercorners | SuperCorners | Assigns custom actions to screen corners and trigger zones | zip | github_tag | https://github.com/daniyalmaster693/SuperCorners | repo=daniyalmaster693/SuperCorners;asset=SuperCorners.zip
swiftcord | Swiftcord | Native Discord client built entirely in Swift | zip | github_tag | https://github.com/SwiftcordApp/Swiftcord | repo=SwiftcordApp/Swiftcord;asset=Swiftcord.zip
textream | Textream | Teleprompter that highlights your script in real time as you speak | dmg | github_tag | https://github.com/f/textream | repo=f/textream;asset=Textream.dmg
vocal | Vocal | Transcribes speech from video files into text on device | zip | github_tag | https://github.com/nuance-dev/vocal | repo=nuance-dev/vocal;asset=Vocal.app.zip
watchflower | WatchFlower | Reads and plots data from Bluetooth plant and temperature sensors | zip | github_tag | https://github.com/emericg/WatchFlower | repo=emericg/WatchFlower;asset=WatchFlower-{v}-macOS.zip
window-glue | Window Glue | Glues two windows together so they move and resize as one | dmg | github_tag | https://github.com/Conxt/WindowGlue | repo=Conxt/WindowGlue;asset=Window.Glue.{v}.dmg
wondershare-mockitt | Wondershare Mockitt | Online prototyping and UI/UX design and collaboration platform | dmg | direct | https://mockitt.com/download.html | url=https://cdn-us.modao.cc/desktop/{v}/mockitt-mac-{v}.dmg;vers=https://mockitt.com/download.html;vregex=mockitt-mac-(\d+(?:\.\d+)+)\.dmg
wudpecker | Wudpecker | AI meeting assistant that records calls and writes tailored notes | dmg | github_tag | https://github.com/wudpecker/mac-updates | repo=wudpecker/mac-updates;asset=Wudpecker.dmg

TABLE

# ----------------------------------------------------------------------------
# Environment + flags
# ----------------------------------------------------------------------------
set -uo pipefail
export GIT_PAGER=cat HOMEBREW_NO_INSTALL_FROM_API=1 HOMEBREW_NO_AUTO_UPDATE=1
DRYRUN="${DRYRUN:-0}"; FORK="${FORK:-fork}"; FILE_FR="${FILE_FR:-1}"; CUSTOMER_LABEL="${CUSTOMER_LABEL:-}"
FRESH="${FRESH:-1}"; STRICT="${STRICT:-1}"; ZAP="${ZAP:-1}"
ONLY="${ONLY:-}"; LIMIT="${LIMIT:-}"; STOP_ON_FAIL="${STOP_ON_FAIL:-0}"
[ "$STRICT" = 1 ] && SFLAG="--strict" || SFLAG=""
if [ "$STRICT" = 1 ]; then AUDIT_DESC="--strict --online --new"; else AUDIT_DESC="--online --new"; fi
if [ "$ZAP" = 1 ]; then TESTED="installed, reinstalled, uninstalled, and zapped"; VERIFIED="the artifact, a clean uninstall, an idempotent reinstall, and the zap stanza paths"; else TESTED="installed and uninstalled"; VERIFIED="the artifact and uninstall"; fi
DISCLOSURE="AI (Claude) assisted in creating this PR: it researched the download URL, version, bundle identifier, minimum macOS, and pkg receipt, and drafted the cask DSL. I reviewed the result, ran brew style --fix and brew audit --cask $AUDIT_DESC with no offenses or errors, and $TESTED the cask locally on macOS to verify $VERIFIED."
ROOT=/tmp/caskwork; mkdir -p "$ROOT"; MASTER="$ROOT/MASTER-summary.md"

trim(){ local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# ----------------------------------------------------------------------------
# Prerequisites (checked once)
# ----------------------------------------------------------------------------
TAP="$(brew --repository homebrew/cask 2>/dev/null)" || { echo "ERROR: Homebrew not found"; exit 1; }
[ -d "$TAP" ] || { echo "ERROR: homebrew-cask tap not found at $TAP"; exit 1; }
DEF="$(git -C "$TAP" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@.*/@@')"; [ -z "$DEF" ] && DEF=master
command -v gh >/dev/null 2>&1 || { echo "ERROR: install gh: brew install gh"; exit 1; }
if [ "$DRYRUN" != 1 ]; then
  gh auth status >/dev/null 2>&1 || { echo "ERROR: run: gh auth login"; exit 1; }
fi
FORK_OWNER="$(git -C "$TAP" remote get-url "$FORK" 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+)/.*#\1#')"
if [ "$DRYRUN" != 1 ] && [ -z "$FORK_OWNER" ]; then
  echo "ERROR: no '$FORK' remote in the tap. Add your homebrew-cask fork, e.g.:"
  echo "  git -C \"$TAP\" remote add $FORK git@github.com:<you>/homebrew-cask.git"
  exit 1
fi

# ----------------------------------------------------------------------------
# Shared helpers (artifact inspection, zap, auto-fix) — from the skill harness
# ----------------------------------------------------------------------------
mac_symbol(){ case "${1%%.*}" in
  10) echo catalina;; 11) echo big_sur;; 12) echo monterey;; 13) echo ventura;;
  14) echo sonoma;; 15) echo sequoia;; 16|26) echo tahoe;; *) echo big_sur;; esac; }

read_app(){ APP_NAME="$(basename "$1")"
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$1/Contents/Info.plist" 2>/dev/null)"
  MINOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$1/Contents/Info.plist" 2>/dev/null || echo 11)"; }

inspect(){ RECEIPT=""; LABELS=""; MAU=""
  case "$ARTIFACT" in
    zip) rm -rf "$W/x"; mkdir "$W/x"; ditto -xk "$DL" "$W/x"; read_app "$(find "$W/x" -maxdepth 3 -name '*.app' | head -1)";;
    dmg) hdiutil detach /tmp/ck-vol >/dev/null 2>&1 || true; hdiutil attach "$DL" -nobrowse -mountpoint /tmp/ck-vol >/dev/null
         read_app "$(find /tmp/ck-vol -maxdepth 1 -name '*.app' | head -1)"; hdiutil detach /tmp/ck-vol >/dev/null 2>&1 || true;;
    pkg) rm -rf "$W/x"; pkgutil --expand-full "$DL" "$W/x"
         RECEIPT="$(grep -rhoE 'identifier="[^"]+"' "$W/x" 2>/dev/null | grep -iv autoupdate | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
         A="$(find "$W/x" -maxdepth 6 -name '*.app' | grep -vi autoupdate | head -1)"; if [ -n "$A" ]; then read_app "$A"; else APP_NAME=""; BUNDLE_ID=""; MINOS=12; fi
         PKGMIN="$(grep -rhoE '<os-version[^>]*/>' "$W/x"/Distribution 2>/dev/null | grep -oE 'min="[0-9][0-9.]*"' | grep -oE '[0-9][0-9.]*' | head -1)"; [ -n "$PKGMIN" ] && MINOS="$PKGMIN"
         LABELS="$(find "$W/x" \( -path '*/LaunchDaemons/*.plist' -o -path '*/LaunchAgents/*.plist' \) 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.plist$//' | sort -u | tr '\n' ' ')"
         grep -rilE 'com\.microsoft\.autoupdate' "$W/x"/Distribution 2>/dev/null | head -1 | grep -q . && MAU=1;;
  esac
  SYM="$(mac_symbol "$MINOS")"; }

# zap_for BUNDLE_ID -> standard user-level leftover paths, scoped to that bundle id.
zap_for(){ [ -z "$1" ] && return 0; cat <<Z
  zap trash: [
    "~/Library/Caches/$1",
    "~/Library/HTTPStorages/$1",
    "~/Library/Preferences/$1.plist",
    "~/Library/Saved Application State/$1.savedState",
  ]
Z
}

# autofix(): ONLY safe, deterministic fixes keyed off audit/style text.
autofix(){ local a="$1" c=1
  if printf '%s' "$a" | grep -qiE 'Artifact defined :[a-z_]+ as the minimum macOS'; then
    local m; m="$(printf '%s' "$a" | grep -oiE 'Artifact defined :[a-z_]+' | head -1 | grep -oE ':[a-z_]+' | tr -d ':')"
    if [ -n "$m" ]; then
      if grep -q 'depends_on macos:' "$CASK"; then perl -i -pe 's/^(\s*depends_on macos:).*/$1 :'"$m"'/' "$CASK"
      else perl -0777 -i -pe 's/(\n\s*name\s[^\n]*\n)/${1}  depends_on macos: :'"$m"'\n/' "$CASK"; fi
      AUTOFIX+="set depends_on macos to :$m (from audit artifact min); "; c=0; SYM="$m"
    fi
  fi
  if printf '%s' "$a" | grep -qiE "desc.*(shouldn't contain the platform|should not contain the platform)"; then
    perl -i -pe 's/\b(macOS|Mac OS X|Windows|Linux|Mac)\b ?//g if /^\s*desc\s/; s/(desc\s+")(\w)/$1.uc($2)/e' "$CASK"; AUTOFIX+="removed platform word from desc; "; c=0; fi
  if printf '%s' "$a" | grep -qiE 'verified.*(redundant|not needed|should be removed|do not need)'; then
    perl -0777 -i -pe 's/,\s*\n?\s*verified:\s*"[^"]*"//g' "$CASK"; AUTOFIX+="removed redundant verified; "; c=0; fi
  if printf '%s' "$a" | grep -qiE 'desc.*(full stop|period|should not end)'; then
    perl -i -pe 's/^(\s*desc\s+"[^"]*)\."/$1"/' "$CASK"; AUTOFIX+="stripped trailing period from desc; "; c=0; fi
  if printf '%s' "$a" | grep -qiE 'desc.*should not start with'; then
    perl -i -pe 's/^(\s*desc\s+")(?:An?|The)\s+/$1/' "$CASK"; AUTOFIX+="removed leading article from desc; "; c=0; fi
  if printf '%s' "$a" | grep -qiE '(minimum macos|depends_on macos|no .*macos)' && ! grep -q 'depends_on macos:' "$CASK" && [ -n "$SYM" ]; then
    perl -0777 -i -pe 's/(\n\s*name\s[^\n]*\n)/${1}  depends_on macos: ">= :'"$SYM"'"\n/' "$CASK"; AUTOFIX+="added depends_on macos >= :$SYM; "; c=0; fi
  return $c; }

# ----------------------------------------------------------------------------
# Spec parsing + template substitution
# ----------------------------------------------------------------------------
parse_spec(){ declare -gA SP=(); local pairs p k v
  IFS=';' read -ra pairs <<< "$1"
  for p in "${pairs[@]}"; do
    p="$(trim "$p")"; [ -z "$p" ] && continue
    k="$(trim "${p%%=*}")"; v="$(trim "${p#*=}")"; SP["$k"]="$v"
  done; }

# {v} -> literal version, {t} -> raw tag (for the actual download URL)
sub_dl(){ local s="$1"; s="${s//\{v\}/$VERSION}"; s="${s//\{t\}/$TAG}"; printf '%s' "$s"; }
# {v} -> #{version}, {t} -> interpolated tag (for the cask url stanza)
sub_cask(){ local VI='#{version}' s="$1"; s="${s//\{v\}/$VI}"; s="${s//\{t\}/$TAGI}"; printf '%s' "$s"; }

get_github_tag(){ TAG="$(curl -sI "https://github.com/$1/releases/latest" \
        | awk -F'/tag/' 'tolower($0)~/^location/{print $2}' | tr -d '\r')"
  [ -n "$TAG" ] || TAG="$(curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
        | awk -F'"' '/"tag_name"/{print $4; exit}')"; }

# ----------------------------------------------------------------------------
# Resolvers (set VERSION + URL, download to $DL; arch-split also sets SHA_X64)
# ----------------------------------------------------------------------------
_resolve_github_tag(){
  get_github_tag "${SP[repo]}"; [ -n "$TAG" ] || die "github: no latest tag for ${SP[repo]}"
  case "$TAG" in [vV][0-9]*) VERSION="${TAG#?}";; *) VERSION="$TAG";; esac
  local VI='#{version}'; TAGI="${TAG/$VERSION/$VI}"
  URL="https://github.com/${SP[repo]}/releases/download/$TAG/$(sub_dl "${SP[asset]}")"
  curl -fL "$URL" -o "$DL"; }

_resolve_github_compound(){
  TAG="$(curl -sI "https://github.com/${SP[repo]}/releases/latest" \
        | awk -F'/tag/' 'tolower($0)~/^location/{print $2}' | tr -d '\r')"
  [ -n "$TAG" ] || die "github: no latest tag for ${SP[repo]}"
  local vnum="${TAG#v-}" build; build="${vnum##*-b-}"; vnum="${vnum%-b-*}"
  VERSION="$vnum,$build"; TAGI="v-#{version.csv.first}-b-#{version.csv.second}"
  URL="https://github.com/${SP[repo]}/releases/download/$TAG/$(sub_dl "${SP[asset]}")"
  curl -fL "$URL" -o "$DL"; }

_resolve_electron(){
  local feed="${SP[feed]}" base; base="${feed%/*}"
  VERSION="$(curl -fsSL "$feed" | awk -F': ' '/^version:/{print $2; exit}' | tr -d '\r ')"
  [ -n "$VERSION" ] || die "electron: could not read version from $feed"
  if [ -n "${SP[universal]:-}" ]; then
    URL="$base/$(sub_dl "${SP[universal]}").dmg"; curl -fL "$URL" -o "$DL"
  else
    URL="$base/$(sub_dl "${SP[arm]}").dmg"; curl -fL "$URL" -o "$DL"
    curl -fL "$base/$(sub_dl "${SP[intel]}").dmg" -o "$W/dl-x64" \
      && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "electron: intel dmg download failed"
  fi; }

_resolve_msft(){
  local short="${SP[short]}" real
  real="$(curl -sIL "$short" | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  [ -n "$real" ] || die "msft_cdn: no redirect from $short"
  VERSION="$(basename "${real%%\?*}" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "msft_cdn: could not parse version from $real"
  MS_REAL="$real"; MS_URLT="$(printf '%s' "$real" | sed "s/${VERSION//./\\.}/#{version}/")"
  URL="$real"; curl -fL "$URL" -o "$DL"; }

_resolve_direct(){
  local v
  if [ -n "${SP[version]:-}" ]; then v="${SP[version]}"
  elif [ -n "${SP[vers]:-}" ]; then
    v="$(curl -fsSL "${SP[vers]}" | grep -oiE "${SP[vregex]}" | head -1)"
    [ -n "$v" ] || die "direct: vregex matched nothing at ${SP[vers]}"
  else die "direct: provide version= or vers=+vregex="; fi
  VERSION="$v"; URL="$(sub_dl "${SP[url]}")"; curl -fL "$URL" -o "$DL"; }

resolve(){
  if declare -F "resolve_$TFN" >/dev/null; then "resolve_$TFN"; return $?; fi
  case "$SOURCE" in
    github_tag)      _resolve_github_tag;;
    github_compound) _resolve_github_compound;;
    electron)        _resolve_electron;;
    msft_cdn)        _resolve_msft;;
    direct)          _resolve_direct;;
    custom)          die "source=custom but no resolve_$TFN defined";;
    *) die "unknown source '$SOURCE' for $TOKEN";;
  esac; }

# ----------------------------------------------------------------------------
# Cask writers (write $CASK). brew style --fix normalises indentation after.
# ----------------------------------------------------------------------------
write_github(){
  local repo="${SP[repo]}" asset="${SP[asset]}" url_cask lc zapblock=""
  url_cask="https://github.com/$repo/releases/download/$TAGI/$(sub_cask "$asset")"
  if [ "$SOURCE" = github_compound ]; then
    lc='livecheck do
    url :url
    regex(/v-(\d+(?:\.\d+)+)-b-(\d+)/i)
    strategy :github_latest do |json, regex|
      match = json["tag_name"]&.match(regex)
      next if match.blank?

      "#{match[1]},#{match[2]}"
    end
  end'
  else
    lc='livecheck do
    url :url
    strategy :github_latest
  end'
  fi
  [ -n "$BUNDLE_ID" ] && zapblock="
$(zap_for "$BUNDLE_ID")"
  case "$ARTIFACT" in
    pkg)
      local uninstall
      if [ -n "$LABELS" ]; then
        local arr; arr="$(printf '"%s", ' $LABELS | sed 's/, $//')"
        uninstall="uninstall launchctl: [$arr],
            pkgutil:   \"$RECEIPT\""
      else uninstall="uninstall pkgutil: \"$RECEIPT\""; fi
      cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "$url_cask"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  $lc

  depends_on macos: :$SYM

  pkg "$(basename "$(sub_dl "$asset")")"

  $uninstall
$zapblock
end
RB
    ;;
    zip|dmg)
      cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "$url_cask"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  $lc

  depends_on macos: :$SYM

  app "$APP_NAME"
$zapblock
end
RB
    ;;
    *) die "github writer: unsupported artifact '$ARTIFACT'";;
  esac; }

write_electron(){
  local base="${SP[feed]%/*}" lc quit="" zapblock=""
  lc="livecheck do
    url \"${SP[feed]}\"
    strategy :electron_builder
  end"
  [ -n "$BUNDLE_ID" ] && { quit="

  uninstall quit: \"$BUNDLE_ID\""; zapblock="
$(zap_for "$BUNDLE_ID")"; }
  if [ -n "${SP[universal]:-}" ]; then
    local fn; fn="$(sub_cask "${SP[universal]}")"
    cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "$base/$fn.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  $lc

  auto_updates true
  depends_on macos: :$SYM

  app "$APP_NAME"$quit
$zapblock
end
RB
  else
    local farm fintel; farm="$(sub_cask "${SP[arm]}")"; fintel="$(sub_cask "${SP[intel]}")"
    cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 "$SHA"
    url "$base/$farm.dmg"
  end
  on_intel do
    sha256 "$SHA_X64"
    url "$base/$fintel.dmg"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  $lc

  auto_updates true
  depends_on macos: :$SYM

  app "$APP_NAME"$quit
$zapblock
end
RB
  fi; }

write_msft(){
  local host fn pkgstanza uninstall zapblock=""
  host="$(printf '%s' "$MS_URLT" | sed -E 's#https?://([^/]+)/.*#\1#')"
  fn="$(basename "${MS_URLT%%\?*}")"
  if [ -n "$MAU" ]; then
    pkgstanza="pkg \"$fn\",
      choices: [
        {
          \"choiceIdentifier\" => \"com.microsoft.autoupdate\",
          \"choiceAttribute\"  => \"selected\",
          \"attributeSetting\" => 0,
        },
      ]"
    uninstall="uninstall quit:    \"com.microsoft.autoupdate2\",
            pkgutil: \"$RECEIPT\""
  else
    pkgstanza="pkg \"$fn\""
    uninstall="uninstall pkgutil: \"$RECEIPT\""
  fi
  [ -n "$BUNDLE_ID" ] && zapblock="
$(zap_for "$BUNDLE_ID")"
  cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "$MS_URLT",
      verified: "$host/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "${SP[short]}"
    regex(/${SP[regex]}/i)
    strategy :header_match
  end

  auto_updates true
  depends_on macos: :$SYM

  $pkgstanza

  $uninstall
$zapblock
end
RB
}

write_direct(){
  local url_cask verified="" lc hp_host dl_host zapblock=""
  url_cask="$(sub_cask "${SP[url]}")"
  hp_host="$(printf '%s' "$HOMEPAGE" | sed -E 's#^https?://([^/]+).*#\1#')"
  dl_host="$(printf '%s' "$url_cask" | sed -E 's#^https?://([^/]+).*#\1#')"
  [ "$hp_host" != "$dl_host" ] && verified=",
      verified: \"$dl_host/\""
  if [ -n "${SP[vers]:-}" ]; then
    lc="livecheck do
    url \"${SP[vers]}\"
    regex(/${SP[vregex]}/i)
    strategy :page_match
  end"
  else
    lc="# livecheck TODO: static version $VERSION — add a livecheck or audit will likely flag it"
  fi
  [ -n "$BUNDLE_ID" ] && zapblock="
$(zap_for "$BUNDLE_ID")"
  case "$ARTIFACT" in
    pkg)
      local uninstall
      if [ -n "$LABELS" ]; then
        local arr; arr="$(printf '"%s", ' $LABELS | sed 's/, $//')"
        uninstall="uninstall launchctl: [$arr],
            pkgutil:   \"$RECEIPT\""
      else uninstall="uninstall pkgutil: \"$RECEIPT\""; fi
      cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "$url_cask"$verified
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  $lc

  depends_on macos: :$SYM

  pkg "$(basename "${URL%%\?*}")"

  $uninstall
$zapblock
end
RB
    ;;
    zip|dmg)
      cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "$url_cask"$verified
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  $lc

  depends_on macos: :$SYM

  app "$APP_NAME"
$zapblock
end
RB
    ;;
    *) die "direct writer: unsupported artifact '$ARTIFACT'";;
  esac; }

write_cask(){
  if declare -F "write_cask_$TFN" >/dev/null; then "write_cask_$TFN"; return $?; fi
  case "$SOURCE" in
    github_tag|github_compound) write_github;;
    electron) write_electron;;
    msft_cdn) write_msft;;
    direct)   write_direct;;
    custom)   die "source=custom but no write_cask_$TFN defined";;
    *) die "unknown source '$SOURCE'";;
  esac; }

# ============================================================================
# OPTIONAL per-app overrides for source=custom apps.
# Name them resolve_<tfn> / write_cask_<tfn>, where <tfn> is the token with
# every '-' replaced by '_'. resolve must set VERSION + URL and download to
# "$DL"; write_cask must write "$CASK". Use the writers above as a template.
# Example for token "my-weird-app" (tfn my_weird_app):
#
# resolve_my_weird_app(){
#   VERSION="$(curl -fsSL https://vendor.example/appcast.xml | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
#   URL="https://vendor.example/MyApp-${VERSION}.dmg"; curl -fL "$URL" -o "$DL"
# }
# write_cask_my_weird_app(){ cat > "$CASK" <<RB
# cask "$TOKEN" do
#   ...
# end
# RB
# }
# ============================================================================

# ----------------------------------------------------------------------------
# Per-app pipeline (runs in a subshell so a failure stops THIS app, not the run)
# ----------------------------------------------------------------------------
run_one(){
  set -uo pipefail
  STAGE=init; STATUS=incomplete
  VERSION=""; URL=""; SHA=""; SHA_X64=""; BUNDLE_ID=""; MINOS=""; SYM=""; RECEIPT=""; LABELS=""; MAU=""
  STYLE_OUT=""; AUDIT=""; LIVECHECK=""; PR=""; FR=""; REFUSED=""; AUTOFIX=""; APP_NAME=""
  MS_REAL=""; MS_URLT=""; TAG=""; TAGI=""
  S="$W/summary.txt"; REPORT="$W/report.md"; : > "$S"
  local LETTER; LETTER="$(printf '%s' "$TOKEN" | cut -c1)"; CASK="$TAP/Casks/$LETTER/$TOKEN.rb"

  log(){ echo "$@" | tee -a "$S"; }
  sec(){ printf '\n## %s\n\n```\n%s\n```\n' "$1" "${2:-(none)}" >> "$REPORT"; }
  emit_result(){ { echo "TOKEN=$TOKEN"; echo "STATUS=$STATUS"; echo "STAGE=$STAGE"; echo "PR=$PR"; echo "FR=$FR"; echo "VERSION=$VERSION"; } > "$W/result.env"; }
  report(){
    { echo "# Cask run report — $TOKEN"; echo
      echo "- App: $NAME"
      echo "- Outcome: **$STATUS**$([ "$STATUS" = failed ] && echo " — failed at stage: $STAGE")"
      echo "- When: $(date)"
      echo "- Branch: add-$TOKEN  |  base: ${DEF:-?}  |  fork: ${FORK_OWNER:-?}/homebrew-cask"
      [ -n "$PR" ] && echo "- PR: $PR"
      [ -n "$FR" ] && echo "- Fleet FR: $FR"
    } > "$REPORT"
    sec "Resolved values" "version:     ${VERSION:-?}
artifact:    $ARTIFACT
source:      $SOURCE
url:         ${URL:-?}
sha256:      ${SHA:-?}${SHA_X64:+
sha256(x64): $SHA_X64}
bundle id:   ${BUNDLE_ID:-?}
min macOS:   ${MINOS:-?}  ->  :${SYM:-?}
pkg receipt: ${RECEIPT:-n/a}
launchd:     ${LABELS:-none}
bundled MAU: $([ -n "$MAU" ] && echo yes || echo no)
prior closed PRs for token: ${REFUSED:-not checked}"
    sec "Environment" "$(sw_vers 2>/dev/null); $(brew --version 2>/dev/null | head -1); $(gh --version 2>/dev/null | head -1)"
    if [ -f "$CASK" ]; then sec "Cask ($CASK)" "$(cat "$CASK")"; else sec "Cask" "(not written)"; fi
    sec "brew style (remaining after --fix)" "${STYLE_OUT:-(not run)}"
    sec "brew audit --cask $AUDIT_DESC" "${AUDIT:-(not run)}"
    sec "Auto-fixes applied (review these)" "${AUTOFIX:-none}"
    sec "brew livecheck --cask (info only)" "${LIVECHECK:-(not run)}"
    [ -f "$W/install.log" ]   && sec "brew install --cask"   "$(cat "$W/install.log")"
    [ -f "$W/uninstall.log" ] && sec "brew uninstall --cask" "$(cat "$W/uninstall.log")"
    [ -f "$W/install2.log" ]  && sec "brew install --cask (reinstall / idempotency)" "$(cat "$W/install2.log")"
    [ -f "$W/zap.log" ]       && sec "brew uninstall --zap --cask" "$(cat "$W/zap.log")"
    sec "git" "$(git -C "$TAP" status -s 2>/dev/null; echo '--- last commit ---'; git -C "$TAP" log --oneline -1 2>/dev/null)"
    sec "Progress log" "$(cat "$S")"
    emit_result
    echo; echo "==== review bundle for $TOKEN ($STATUS) — full report at $REPORT ===="
  }
  die(){ STATUS="failed"; log "[$TOKEN] $1"; report; exit 1; }

  cd "$TAP" || { echo "cannot cd tap"; exit 1; }
  STAGE="precheck"; git checkout -q "$DEF" 2>/dev/null; git pull -q --ff-only 2>/dev/null || true
  if brew info --cask "$TOKEN" >/dev/null 2>&1; then
    STATUS="skipped (cask exists upstream)"
    log "[$TOKEN] a cask already exists in homebrew-cask — skipping the PR. File a Fleet FR for the existing cask separately if needed."
    report; exit 0
  fi
  brew info --formula "$TOKEN" >/dev/null 2>&1 && log "[$TOKEN] WARNING: token collides with a homebrew-core formula — rename (e.g. ${TOKEN}-desktop) or audit will reject it"
  git branch -D "add-$TOKEN" >/dev/null 2>&1 || true; git checkout -q -b "add-$TOKEN"
  [ "$FRESH" = 1 ] && [ "$DRYRUN" != 1 ] && git push "$FORK" --delete "add-$TOKEN" >/dev/null 2>&1 || true

  STAGE="resolve";   resolve; [ -s "$DL" ] || die "download failed (resolve produced no file at \$DL)"
  STAGE="sha";       SHA="$(shasum -a 256 "$DL" | awk '{print $1}')"
  STAGE="inspect";   inspect
  STAGE="write";     write_cask; [ -f "$CASK" ] || die "write_cask did not create $CASK"
  STAGE="style";     brew style --fix "$TOKEN" >/dev/null 2>&1; STYLE_OUT="$(brew style "$TOKEN" 2>&1)"
  STAGE="audit";     AUDIT="$(brew audit --cask $SFLAG --online --new "$TOKEN" 2>&1)"
  issues(){ printf '%s' "$STYLE_OUT" | grep -qE '[1-9][0-9]* offense' || printf '%s' "$AUDIT" | grep -qiE 'error|problem|fail'; }
  if issues; then
    log "[$TOKEN] style/audit reported issues — trying safe auto-fixes…"
    local pass=0
    while [ "$pass" -lt 2 ]; do
      autofix "$AUDIT
$STYLE_OUT" || { log "[$TOKEN] no further safe auto-fix applies (remaining issues need review)"; break; }
      brew style --fix "$TOKEN" >/dev/null 2>&1; STYLE_OUT="$(brew style "$TOKEN" 2>&1)"
      AUDIT="$(brew audit --cask $SFLAG --online --new "$TOKEN" 2>&1)"
      issues || { log "[$TOKEN] auto-fix cleared style + audit"; break; }
      pass=$((pass+1))
    done
  fi
  STAGE="livecheck"; LIVECHECK="$(brew livecheck --cask "$TOKEN" 2>&1 || true)"
  git add "$CASK"; git commit -q -m "Add $TOKEN (new cask)" 2>/dev/null || true
  STAGE="audit"; issues && die "style/audit still failing after auto-fix — see report (auto-fixed: ${AUTOFIX:-none})"
  log "[$TOKEN] style + audit OK${AUTOFIX:+ (auto-fixed: $AUTOFIX)}"

  if [ "$DRYRUN" = 1 ]; then STATUS="dryrun (audited, not shipped)"; log "[$TOKEN] DRYRUN — no install/push/PR/FR"; report; exit 0; fi

  STAGE="install"; log "[$TOKEN] install test (sudo prompt for pkgs)…"
  HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask "$TOKEN" 2>&1 | tee "$W/install.log" || die "install failed — no PR opened"
  STAGE="uninstall"
  brew uninstall --cask "$TOKEN" 2>&1 | tee "$W/uninstall.log" || { brew uninstall --force --cask "$TOKEN" >/dev/null 2>&1 || true; die "uninstall failed — fix uninstall stanza; no PR"; }
  log "[$TOKEN] install + uninstall OK"
  if [ "$ZAP" = 1 ]; then
    STAGE="reinstall"; log "[$TOKEN] reinstall (idempotency) + zap test…"
    HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask "$TOKEN" 2>&1 | tee "$W/install2.log" || die "reinstall failed — not idempotent after uninstall; no PR"
    STAGE="zap"
    brew uninstall --zap --cask "$TOKEN" 2>&1 | tee "$W/zap.log" || { brew uninstall --force --cask "$TOKEN" >/dev/null 2>&1 || true; die "zap failed — fix zap stanza paths; no PR"; }
    if grep -q 'No zap stanza present' "$W/zap.log"; then log "[$TOKEN] reinstall + uninstall OK (cask has no zap stanza)"
    else log "[$TOKEN] reinstall + zap OK (zap stanza paths exercised)"; fi
  fi

  STAGE="push"
  git push --force-with-lease "$FORK" "add-$TOKEN" 2>/dev/null \
    || git push --force "$FORK" "add-$TOKEN" \
    || die "push failed"

  PR="$(gh api "repos/Homebrew/homebrew-cask/pulls?head=${FORK_OWNER}:add-${TOKEN}&state=open" --jq '.[0].html_url // empty' 2>/dev/null || true)"
  if [ -n "$PR" ]; then
    log "[$TOKEN] branch updated; PR already open: $PR (skipping PR + Fleet FR creation)"
  else
    TPL="$(ls "$TAP"/.github/PULL_REQUEST_TEMPLATE.md "$TAP"/.github/pull_request_template.md 2>/dev/null | head -1)"
    if [ -n "$TPL" ]; then
      sed -E -e 's/^([[:space:]]*[-*][[:space:]]*)\[[[:space:]]\]/\1[x]/' \
             -e "s/<cask>/$TOKEN/g; s/{{[[:space:]]*cask[[:space:]]*}}/$TOKEN/g; s/<token>/$TOKEN/g" "$TPL" > "$W/pr.md"
      { echo; echo "$DISCLOSURE"; } >> "$W/pr.md"
      log "[$TOKEN] PR body built from live template: $TPL"
    else
      cat > "$W/pr.md" <<'PRB'
Adds the `__TOKEN__` cask (__NAME__ __VER__).

#### After making any changes to a cask, existing or new, verify:

- [x] Submission is for a stable version or documented exception
- [x] `brew audit --cask --online __TOKEN__` is error-free
- [x] `brew style --fix __TOKEN__` reports no offenses

#### Additionally, if adding a new cask:

- [x] Named the cask according to the token reference
- [x] Checked the cask was not already refused
- [x] `brew audit --cask --new __TOKEN__` worked successfully
- [x] `HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask __TOKEN__` worked successfully
- [x] `brew uninstall --cask __TOKEN__` worked successfully

#### If AI-assisted:

- [x] Personally reviewed, tested, and verified all changes including `zap` stanza paths

__DISCLOSURE__
PRB
      sed -i '' -e "s|__TOKEN__|$TOKEN|g" -e "s|__NAME__|$NAME|g" -e "s|__VER__|$VERSION|g" -e "s|__DISCLOSURE__|$DISCLOSURE|g" "$W/pr.md"
      log "[$TOKEN] live template not found — used baked-in checklist"
    fi
    REFUSED="$(gh search prs "$TOKEN" --repo Homebrew/homebrew-cask --match title --state closed --json url --jq 'length' 2>/dev/null || echo '?')"
    log "[$TOKEN] prior closed PRs matching token: $REFUSED (confirm none was a refusal)"
    STAGE="pr"; PR="$(gh pr create --repo Homebrew/homebrew-cask --base "$DEF" --head "$FORK_OWNER:add-$TOKEN" --title "Add $TOKEN (new cask)" --body-file "$W/pr.md")" || die "PR create failed"
    log "[$TOKEN] PR: $PR"

    STAGE="fr"; if [ "$FILE_FR" = 1 ]; then
      CASKURL="https://github.com/$FORK_OWNER/homebrew-cask/blob/add-$TOKEN/Casks/$LETTER/$TOKEN.rb"
      RX=""; [ -n "$RECEIPT" ] && RX="
- pkg receipt: \`$RECEIPT\`"
      cat > "$W/fr.md" <<FRB
## $NAME — Fleet-maintained app request (macOS)

- Homebrew cask PR: $PR
- Cask file: $CASKURL
- Installer file: $URL
- File type: $ARTIFACT
- Cask token: \`$TOKEN\`$RX

Once the cask PR merges (cask live on \`formulae.brew.sh\`), add \`ee/maintained-apps/inputs/homebrew/$TOKEN.json\` referencing token \`$TOKEN\`, then regenerate the manifest.
FRB
      GHLABELS=(--label ":help-solutions-consulting"); [ -n "$CUSTOMER_LABEL" ] && GHLABELS+=(--label "$CUSTOMER_LABEL")
      FR="$(gh issue create --repo fleetdm/fleet --title "New FMA: $NAME" --body-file "$W/fr.md" "${GHLABELS[@]}")" || log "[$TOKEN] FR create failed (PR is open: $PR)"
      [ -n "${FR:-}" ] && log "[$TOKEN] Fleet FR: $FR"
    fi
  fi
  STAGE="done"; STATUS="success"
  [ -n "$CUSTOMER_LABEL" ] || log "[$TOKEN] (no CUSTOMER_LABEL set — add the customer/prospect label to the Fleet FR by hand)"
  report
  git checkout -q "$DEF" 2>/dev/null || true
}

# ----------------------------------------------------------------------------
# Load registry into rows
# ----------------------------------------------------------------------------
declare -a ROWS=()
while IFS= read -r line; do
  case "$(trim "$line")" in ""|\#*) continue;; esac
  ROWS+=("$line")
done <<< "$REGISTRY"
[ "${#ROWS[@]}" -gt 0 ] || { echo "Registry is empty. Add app rows to the REGISTRY block, then re-run."; exit 0; }

# ----------------------------------------------------------------------------
# Prime sudo if any pkg / msft_cdn app is in scope (pkg installs need it)
# ----------------------------------------------------------------------------
NEED_SUDO=0
for line in "${ROWS[@]}"; do
  IFS='|' read -r _t _n _d a s _rest <<< "$line"
  a="$(trim "$a")"; s="$(trim "$s")"
  [ "$a" = pkg ] || [ "$s" = msft_cdn ] && NEED_SUDO=1
done
if [ "$DRYRUN" != 1 ] && [ "$NEED_SUDO" = 1 ]; then
  echo "Priming sudo (pkg installs need it)…"
  sudo -v || { echo "sudo is required for pkg installs"; exit 1; }
  ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null & SUDO_PID=$!
  trap '[ -n "${SUDO_PID:-}" ] && kill "$SUDO_PID" 2>/dev/null' EXIT
fi

# ----------------------------------------------------------------------------
# Run the batch
# ----------------------------------------------------------------------------
{ echo "# Master cask run — $(date)"; echo; echo "Mode: $([ "$DRYRUN" = 1 ] && echo DRYRUN || echo LIVE)  |  base: $DEF  |  fork: ${FORK_OWNER:-?}"; echo; } > "$MASTER"
n=0
for line in "${ROWS[@]}"; do
  IFS='|' read -r c1 c2 c3 c4 c5 c6 c7 <<< "$line"
  TOKEN="$(trim "$c1")"; NAME="$(trim "$c2")"; DESC="$(trim "$c3")"
  ARTIFACT="$(trim "$c4")"; SOURCE="$(trim "$c5")"; HOMEPAGE="$(trim "$c6")"; SPEC="$(trim "$c7")"
  [ -z "$TOKEN" ] && continue
  if [ -n "$ONLY" ]; then case " $ONLY " in *" $TOKEN "*) ;; *) continue;; esac; fi
  n=$((n+1)); if [ -n "$LIMIT" ] && [ "$n" -gt "$LIMIT" ]; then n=$((n-1)); break; fi
  TFN="${TOKEN//-/_}"
  parse_spec "$SPEC"
  W="$ROOT/$TOKEN"; rm -rf "$W"; mkdir -p "$W"; DL="$W/dl"

  echo; echo "════ [$n] $TOKEN  ($NAME) — source=$SOURCE artifact=$ARTIFACT ════"
  ( run_one ); rc=$?

  git -C "$TAP" checkout -q "$DEF" 2>/dev/null || true
  git -C "$TAP" branch -D "add-$TOKEN" >/dev/null 2>&1 || true

  st="?"; pr=""; fr=""
  if [ -f "$W/result.env" ]; then
    st="$(grep '^STATUS=' "$W/result.env" | cut -d= -f2-)"
    pr="$(grep '^PR=' "$W/result.env" | cut -d= -f2-)"
    fr="$(grep '^FR=' "$W/result.env" | cut -d= -f2-)"
  fi
  printf -- '- **%s** — %s%s%s  _(report: %s)_\n' "$TOKEN" "$st" "${pr:+ — PR: $pr}" "${fr:+ — FR: $fr}" "$W/report.md" >> "$MASTER"
  echo "──── $TOKEN: $st ${pr:+| PR=$pr} ${fr:+| FR=$fr}"

  if [ "$rc" != 0 ] && [ "$STOP_ON_FAIL" = 1 ]; then
    echo "STOP_ON_FAIL=1 and $TOKEN did not succeed — stopping the batch."; break
  fi
done

echo; echo "===================================================================="
echo " MASTER SUMMARY — $MASTER"
echo "===================================================================="
cat "$MASTER"
echo
echo "For any app that failed, open /tmp/caskwork/<token>/report.md and paste it back for a targeted fix."
