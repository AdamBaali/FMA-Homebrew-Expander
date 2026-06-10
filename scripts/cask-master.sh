#!/usr/bin/env bash
###############################################################################
# cask-master.sh — bulk Homebrew Cask authoring for the appcatalog.cloud
#                  "no-homebrew-cask" backlog (fleetdm/fleet).
#
# SOURCE OF THE BACKLOG — the 533-app universe this script + master-list.csv
# are derived from is Fleet's "appcatalog.cloud apps with no Homebrew cask"
# list (533 macOS appcatalog.cloud apps with no matching Homebrew cask, checked
# against the full 7,706-cask Homebrew list). Shared by Allen Houchins, 2026-06-08:
#   list  https://github.com/fleetdm/fleet/blob/118e968fac7f45d07f6dcd3bd08bcd055254928b/ee/maintained-apps/app-catalog-parity/no-homebrew-cask.md
#   slack https://fleetdm.slack.com/archives/C02TYJF11P0/p1780941961900449?thread_ts=1780930437.788159&cid=C02TYJF11P0
#   NOTE  the file has since been removed from fleet `main`; the pinned commit
#         (118e968) above is the durable reference. See NOT-ADDED.md.
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
# AUTHOR: Adam Baali <adam@mpc.ad>  ·  https://github.com/AdamBaali
#   Cask PRs open from the fork https://github.com/AdamBaali/homebrew-cask, and the
#   cask commits are authored as the above (override with AUTHOR_NAME/AUTHOR_EMAIL).
#
# -------------------------- HOW TO RUN ---------------------------------------
#   1) Add rows to the REGISTRY heredoc below (format + examples are there).
#   2) PREVIEW FIRST (writes + audits casks, touches nothing else):
#        DRYRUN=1 bash cask-master.sh
#      or one app at a time:  ONLY="filezilla" DRYRUN=1 bash cask-master.sh
#   3) Run for real:  bash cask-master.sh
#   4) For any app that failed, open /tmp/caskwork/<token>/report.md and paste
#      it back for a targeted fix. A tab-separated rollup of every app lands at
#      /tmp/caskwork/results.tsv, and the script exits non-zero if any app failed.
#
# ------------------------------ FLAGS ----------------------------------------
#   DRYRUN=1          preview only (no install/push/PR/FR)
#   ONLY="a b c"      run only these tokens (space-separated)
#   LIMIT=N           run at most N apps from the registry
#   STOP_ON_FAIL=1    halt the whole batch on the first app that fails (default 0)
#   JOBS=N            prefetch (resolve + download) up to N apps ahead in parallel
#                     (default 4; 0 = fully serial). Only built-in source types
#                     prefetch — custom resolvers always resolve serially. Disk
#                     stays bounded: at most N downloads are on disk at once.
#   KEEP=1            keep each app's download + extracted tree after it finishes
#                     (default 0 = delete them so a 300-app run can't fill the disk;
#                     reports/logs are always kept)
#   SKIP_PASSED=1     skip apps that already passed in a previous run (same CASKWORK
#                     dir): success/skipped always count; a dryrun pass counts only
#                     when running DRYRUN=1 again (default 0)
#   RUN_BLOCKED=1     also run the POLICY_BLOCKED tokens (known, re-verified brew
#                     audit policy rejections listed after the REGISTRY; default 0 =
#                     skip them, recorded as "skipped (policy-blocked)" in the rollup)
#   START_AT=token    skip registry rows until this token (resume an interrupted run)
#   LIVECHECK=0       skip the per-app `brew livecheck` (info-only; faster iteration)
#   CASKWORK=dir      work/report dir (default /tmp/caskwork — macOS wipes /tmp on
#                     reboot; set e.g. ~/caskwork to persist results across reboots)
#   CHECK=1           don't run anything; report registry vs data/master-list.csv
#                     drift (informational) and exit
#   STRICT=0          drop --strict from audit (default 1 = CI parity)
#   ZAP=0             skip the reinstall + zap test (default 1)
#   FRESH=0           keep an existing open PR instead of force-refreshing (default 1)
#   FILE_FR=0         author the cask PR but skip the Fleet FR (default 1)
#   CUSTOMER_LABEL="customer-x"   extra label on the Fleet FR (else add by hand)
#   FORK=fork         name of your fork's git remote in the tap (default "fork")
#   SUDO_NOPASSWD=0   don't write a temp passwordless-sudo drop-in; just keep the
#                     sudo timestamp warm (default 1 = one prompt, then no re-prompts;
#                     the temp /etc/sudoers.d entry is auto-removed when the run ends)
#   AUTHOR_NAME / AUTHOR_EMAIL   git identity for the cask commits, scoped to the
#                     tap only (defaults "AdamBaali" / "adam@mpc.ad"). Use
#                     AUTHOR_EMAIL=AdamBaali@users.noreply.github.com to keep it private.
#   FORK_OWNER=you    GitHub owner for the fork PR head/blob URLs (default: derived
#                     from the `fork` remote, else "AdamBaali")
#   HOMEBREW_NO_REQUIRE_TAP_TRUST is exported =1 so Homebrew 5.1.15+ will load
#                     casks from the local homebrew/cask clone (Tap Trust, 2026-05-30);
#                     the run also does `brew trust homebrew/cask` as the recommended path.
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
#                      vers=https://host/appcast.xml ; vregex=([0-9]+(?:\.[0-9]+)+)
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

# --- bash 4+ guard -----------------------------------------------------------
# macOS ships bash 3.2 at /bin/bash (frozen for GPLv3 licensing). This harness
# uses associative arrays (declare -A), which need bash 4.2+. If we were launched
# under an older bash (or sh) — e.g. `bash cask-master.sh` resolving to /bin/bash —
# re-exec under a modern bash (Homebrew's), preserving the current environment
# (DRYRUN=…, ONLY=…, etc.) and any args. If none exists, stop with an actionable
# message instead of the cryptic "declare: -g: invalid option" / "unbound variable".
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash "$(command -v bash 2>/dev/null)"; do
    [ -n "$_b" ] && [ -x "$_b" ] || continue
    _v="$("$_b" -c 'echo "${BASH_VERSINFO:-0}"' 2>/dev/null)"
    case "$_v" in ''|*[!0-9]*) continue;; esac
    [ "$_v" -ge 4 ] && exec "$_b" "$0" "$@"
  done
  echo "ERROR: this needs bash 4+ (you have ${BASH_VERSION:-an old shell})." >&2
  echo "       Install one and re-run:  brew install bash" >&2
  exit 1
fi

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
# filezilla | FileZilla | Client for transferring files over FTP, FTPS, and SFTP | dmg | direct | https://filezilla-project.org | url=https://dl3.cdn.filezilla-project.org/client/FileZilla_{v}_macosx-x86.app.tar.bz2;vers=https://filezilla-project.org/download.php?platform=macos-x86;vregex=([0-9]+(?:\.[0-9]+)+)

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
pique | Pique | Quick Look previews with syntax highlighting for configuration files | pkg | github_tag | https://github.com/macadmins/pique | repo=macadmins/pique;asset=Pique-{v}.pkg;lcregex=v?(\d+(?:\.\d+)+(?:b\d+)?)
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
automounter | AutoMounter | Mounts and remounts network file shares automatically | dmg | direct | https://www.pixeleyes.co.nz/automounter/ | url=https://www.pixeleyes.co.nz/automounter/AutoMounter.dmg;vers=https://www.pixeleyes.co.nz/automounter/version;vregex=([0-9]+(?:\.[0-9]+)+)
aws-cli | AWS Command Line Interface | Unified tool to manage Amazon Web Services from the command line | pkg | direct | https://aws.amazon.com/cli/ | url=https://awscli.amazonaws.com/AWSCLIV2-{v}.pkg;vers=https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst;vregex=^(2(?:\.\d+)+)$
brosix | Brosix | Secure instant messaging and collaboration client for teams | pkg | direct | https://www.brosix.com/download/ | url=https://downloads.brosix.com/builds/official/Brosix.pkg;vers=https://www.brosix.com/download/;vregex=version="mac">(\d+(?:\.\d+)+)
cakebrew | Cakebrew | Graphical interface to manage the Homebrew package manager | zip | direct | https://www.cakebrew.com | url=https://cakebrew-377a.kxcdn.com/cakebrew-{v}.zip;vers=https://www.cakebrew.com/appcast/profileInfo.php;vregex=cakebrew-(\d+(?:\.\d+)+)\.zip
dragonframe-2024 | Dragonframe 2024 | Stop-motion animation and time-lapse capture tool | pkg | direct | https://www.dragonframe.com/downloads/ | url=https://www.dragonframe.com/download/Dragonframe_{v}.pkg;vers=https://www.dragonframe.com/downloads/;vregex=2024\.[0-9]+\.[0-9]+
dragonframe-2025 | Dragonframe 2025 | Stop-motion animation and time-lapse capture tool | pkg | direct | https://www.dragonframe.com/downloads/ | url=https://www.dragonframe.com/download/Dragonframe_{v}.pkg;vers=https://www.dragonframe.com/downloads/;vregex=2025\.[0-9]+\.[0-9]+
dragonframe-5 | Dragonframe 5 | Stop-motion animation and time-lapse capture tool | pkg | direct | https://www.dragonframe.com/downloads/ | url=https://www.dragonframe.com/download/Dragonframe_{v}.pkg;vers=https://www.dragonframe.com/downloads/;vregex=5\.[0-9]+\.[0-9]+
grammarly | Grammarly | Writing assistant for grammar, spelling, and style suggestions | dmg | direct | https://www.grammarly.com/desktop | url=https://download-mac.grammarly.com/versions/{v}/Grammarly.dmg;vers=https://download-mac.grammarly.com/appcast.xml;vregex=versions\/(\d+(?:\.\d+)+)\/Grammarly\.dmg
hudl-studio | Hudl Studio | Creates animated sports graphics and telestration for video | dmg | direct | https://www.hudl.com/downloads/elite | url=https://studio-releases.s3.amazonaws.com/Studio-{v}.dmg;vers=https://studio-releases.s3.amazonaws.com/?list-type=2;vregex=Key>Studio-(\d+(?:\.\d+)+)\.dmg<
lucidlink | LucidLink | Streams files from cloud object storage as a local drive | pkg | direct_header | https://www.lucidlink.com/download | short=https://www.lucidlink.com/download/latest/osx/stable;regex=lucid-(\d+(?:\.\d+)+)\.pkg
luna-display | Luna Display | Turns an iPad or second device into an external display | dmg | direct_header | https://astropad.com/getting-started/luna-display/ | short=https://downloads.astropad.com/luna/mac/latest;regex=LunaDisplay-(\d+(?:\.\d+)+)\.dmg
masv | MASV | Transfers large media files at high speed | dmg | electron | https://massive.io | feed=https://dl.massive.io/latest-mac.yml;universal=masv-{v}-universal
mestrenova | Mestrenova | Processes and analyzes NMR, LC/GC/MS and other analytical chemistry data | dmg | direct | https://mestrelab.com | url=https://mestrelab.com/downloads/mnova/mac/MestReNova-{v}.dmg;vers=https://mestrelab.com/download/;vregex=MestReNova-(\d+\.\d+\.\d+-\d+)\.dmg
microsoft-skype-for-business | Microsoft Skype for Business | Enterprise instant messaging and online meeting client | pkg | msft_cdn | https://learn.microsoft.com/en-us/skypeforbusiness/ | short=https://go.microsoft.com/fwlink/?linkid=832978;regex=SkypeForBusinessUpdater-(\d+(?:\.\d+)+)\.pkg
network-share-mounter | Network Share Mounter | Mounts network shares automatically using stored credentials | pkg | direct | https://gitlab.rrze.fau.de/faumac/networkShareMounter | url=https://gitlab.rrze.fau.de/api/v4/projects/506/packages/generic/networksharemounter/release-{v}/NetworkShareMounter-{v}.pkg;vers=https://gitlab.rrze.fau.de/api/v4/projects/506/releases;vregex=release-([0-9]+(?:\.[0-9]+)+)
nodejs | Node.js | JavaScript runtime built on the V8 engine | pkg | direct | https://nodejs.org | url=https://nodejs.org/dist/v{v}/node-v{v}.pkg;vers=https://nodejs.org/dist/latest/;vregex=node-v([0-9]+(?:\.[0-9]+)+)\.pkg
particulars | Particulars | Displays detailed hardware and system information in the menu bar | pkg | direct_header | https://particulars.app | short=https://particulars.app/_downloads/Particulars-latest.pkg;regex=Particulars-(\d+(?:\.\d+)+)\.pkg
poll-everywhere | Poll Everywhere | Live audience response and interactive polling client | dmg | direct | https://www.polleverywhere.com | url=https://polleverywhere-app.s3.amazonaws.com/mac-stable/{v}/pollev.dmg;vers=https://polleverywhere-app.s3.amazonaws.com/?list-type=2&prefix=mac-stable/;vregex=mac-stable\/(\d+(?:\.\d+)+)\/pollev\.dmg
screencloud-player | ScreenCloud Player | Displays digital signage content on connected screens | dmg | electron | https://screencloud.com/download | feed=https://release.screen.cloud/player/desktop/channel/stable/latest-mac.yml;arm=scplayer_{v}_darwin_arm64;intel=scplayer_{v}_darwin_x64
signiant-app | Signiant App | Accelerated large file transfer client for Media Shuttle | dmg | direct | https://help.signiant.com/media-shuttle/signiant-app/download-signiant-app | url=https://updates.signiant.com/signiant_app/Signiant_App_{v}.dmg;vers=https://updates.signiant.com/signiant_app/signiant-app-info-mac.json;vregex=Signiant_App_([0-9]+(?:\.[0-9]+)+)\.dmg
things | Things | Personal task manager and to-do list organizer | zip | direct | https://culturedcode.com/things/ | url=https://static.culturedcode.com/things/Things3.zip;vers=https://culturedcode.com/things/mac/help/releasenotes/;vregex=\b(3\.\d+(?:\.\d+)+)
vonage-business | Vonage Business | Calling, messaging, and meetings for unified communications | dmg | electron | https://businesssupport.vonage.com/ | feed=https://s3.amazonaws.com/vbcdesktop.vonage.com/prod/mac/latest-mac.yml;universal=Vonage%20Business-{v}-universal

# ---- Phase 1 wave 1 (cold-sourced; verify on Mac with DRYRUN) ----
achico | Achico | Compresses images, PDFs, and videos while preserving quality | zip | github_tag | https://github.com/nuance-dev/achico | repo=nuance-dev/achico;asset=Achico.app.zip
api-utility | API Utility | Command-line tool to work with Jamf Pro APIs and manage secrets | zip | github_tag | https://github.com/Jamf-Concepts/apiutil | repo=Jamf-Concepts/apiutil;asset=API.Utility.zip
barcode-producer | Barcode Producer | Designs and generates retail barcodes and labels with vector export | zip | direct_header | https://www.barcodeproducer.com | short=https://r.barcodeproducer.com/app/download_mac/;regex=Barcode-Producer-(\d+(?:\.\d+)+)\.zip
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
hue | Hue | Client for photo retouching teams to manage post-production workflows | zip | direct_arch | https://help.creativeforce.io/en/articles/4752283-hue-desktop-app-overview | arm=https://download.creativeforce.io/released-files.042024/prod/hue-uxp/mac/Hue-{v}-mac-arm64.zip;intel=https://download.creativeforce.io/released-files.042024/prod/hue-uxp/mac/Hue-{v}-mac.zip;vers=https://download.creativeforce.io/released-files.042024/prod/hue-uxp/mac/latest-mac.yml;vregex=version: (\d+(?:\.\d+)+)
ibm-data-shift | IBM Data Shift | Migrates files, apps, and preferences between devices over peer-to-peer | zip | github_compound | https://github.com/IBM/mac-ibm-migration-tool | repo=IBM/mac-ibm-migration-tool;asset=IBM.Data.Shift.zip
impulso | Impulso | Task manager with priority scoring and flexible organization | zip | github_tag | https://github.com/nuance-dev/impulso | repo=nuance-dev/impulso;asset=Impulso.app.zip
insight | Insight | Video review and performance analysis for sports teams and athletes | dmg | direct | https://www.hudl.com/releases/insight | url=https://insight-releases.s3.eu-west-1.amazonaws.com/Insight-{v}-universal.dmg;vers=https://insight-releases.s3.eu-west-1.amazonaws.com/?list-type=2;vregex=Key>Insight-(\d+(?:\.\d+)+)-universal\.dmg<
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
lucidlink-classic | LucidLink Classic | Cloud storage that streams team media files on demand | pkg | direct_header | https://www.lucidlink.com/classic | short=https://www.lucidlink.com/download/latest/osx/stable;regex=lucid-(\d+(?:\.\d+)+)\.pkg
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

# ---- author batch A: GitHub arch-split + single-asset (verify on Mac with DRYRUN) ----
blink-eye | Blink Eye | Minimalist eye-care break reminder to reduce eye strain | dmg | github_arch | https://github.com/nomandhoni-cs/blink-eye | repo=nomandhoni-cs/blink-eye;arm=Blink.Eye_{v}_aarch64.dmg;intel=Blink.Eye_{v}_x64.dmg
chatkit | ChatKit | Native desktop client for AI chat assistants | dmg | github_arch | https://github.com/egoist/chatkit-releases | repo=egoist/chatkit-releases;arm=ChatKit_{v}_aarch64.dmg;intel=ChatKit_{v}_x64.dmg
droppoint | DropPoint | Drag-and-drop shelf for staging files before transfer | dmg | github_arch | https://github.com/GameGodS3/DropPoint | repo=GameGodS3/DropPoint;arm=DropPoint-{v}-arm64-Apple-Silicon.dmg;intel=DropPoint-{v}.dmg
file-architect | File Architect | Builds folder structures from a plain-text outline | dmg | github_arch | https://github.com/filearchitect/app | repo=filearchitect/app;arm=filearchitect_{v}_darwin-aarch64.dmg;intel=filearchitect_{v}_darwin-x86_64.dmg
peazip | PeaZip | Archive manager supporting many compression formats | dmg | github_arch | https://github.com/peazip/PeaZip | repo=peazip/PeaZip;arm=peazip-{v}.DARWIN.aarch64.dmg;intel=peazip-{v}.DARWIN.x86_64.dmg
smotrite | Smotrite | Plays IPTV channels and online video streams | dmg | github_arch | https://github.com/Lukentui/smotrite-app | repo=Lukentui/smotrite-app;arm=Smotrite-Mac-arm64-{v}-Installer.dmg;intel=Smotrite-Mac-x64-{v}-Installer.dmg
sniffnet | Sniffnet | Monitors network traffic and inspects connections | dmg | github_arch | https://github.com/GyulyVGC/sniffnet | repo=GyulyVGC/sniffnet;arm=Sniffnet_macOS_AppleSilicon.dmg;intel=Sniffnet_macOS_Intel.dmg
spacesuit | Spacesuit | Routes opened links to chosen browser profiles | dmg | github_arch | https://github.com/lightmode-laboratories/spacesuit | repo=lightmode-laboratories/spacesuit;arm=Spacesuit-arm64.dmg;intel=Spacesuit-x64.dmg
swiftguard | swiftGuard | Alerts on unauthorized USB and Thunderbolt access | dmg | github_arch | https://github.com/Lennolium/swiftGuard | repo=Lennolium/swiftGuard;arm=swiftGuard_arm64.dmg;intel=swiftGuard.dmg
time-machine-inspector | Time Machine Inspector | Inspects Time Machine backup contents and sizes | dmg | github_arch | https://github.com/probablykasper/time-machine-inspector | repo=probablykasper/time-machine-inspector;arm=Time.Machine.Inspector_{v}_aarch64.dmg;intel=Time.Machine.Inspector_{v}_x64.dmg
visualz | Visualz | Lighting and visualization design for live events | dmg | github_arch | https://github.com/madchops1/visualz-releases | repo=madchops1/visualz-releases;arm=Visualz-{v}-arm64.dmg;intel=Visualz-{v}-x64.dmg
nextai-translator | NextAI Translator | Translates text with AI models from the menu bar | dmg | github_tag | https://github.com/nextai-translator/nextai-translator | repo=nextai-translator/nextai-translator;asset=NextAI.Translator_{v}_aarch64.dmg
battery-toolkit | Battery Toolkit | Controls battery charging to extend battery lifespan | zip | github_tag | https://github.com/mhaeuser/Battery-Toolkit | repo=mhaeuser/Battery-Toolkit;asset=Battery-Toolkit-{v}.zip
hide-icons | Hide Icons | Hides desktop icons with a menu bar toggle | zip | github_tag | https://github.com/com-entonos/Hide-Icons | repo=com-entonos/Hide-Icons;asset=HideIcons{v}.zip
jamf-cli | Jamf CLI | Command-line interface for the Jamf Pro API | pkg | github_tag | https://github.com/Jamf-Concepts/jamf-cli | repo=Jamf-Concepts/jamf-cli;asset=jamf-cli-{v}.pkg
jamf-replicator | Jamf Replicator | Copies Jamf Pro objects between servers | zip | github_tag | https://github.com/jamf/Replicator | repo=jamf/Replicator;asset=Replicator.zip
jamf-sync | Jamf Sync | Syncs packages between Jamf Pro distribution points | zip | github_tag | https://github.com/jamf/JamfSync | repo=jamf/JamfSync;asset=Jamf.Sync.app.zip
mailvault | MailVault | Archives and backs up email into a local vault | dmg | github_tag | https://github.com/GraphicMeat/mail-vault-app | repo=GraphicMeat/mail-vault-app;asset=MailVault-v{v}.dmg
sapmachine-manager | SapMachine Manager | Installs and manages SapMachine JDK versions | pkg | github_tag | https://github.com/sap/sapmachine-manager-for-macos | repo=sap/sapmachine-manager-for-macos;asset=SapMachine_Manager_{v}.pkg
script2pkg | Script2Pkg | Wraps shell scripts into installer packages | pkg | github_tag | https://github.com/sap/script-to-package-tool-for-macos | repo=sap/script-to-package-tool-for-macos;asset=Script2Pkg_{v}.pkg

# ---- author batch B: direct_latest / direct_arch (verify on Mac; :no_check flagged) ----
arclite-pro | Arclite Pro | Menu bar tool to organize, compress, and manage archive files | dmg | direct_latest | https://etheriar.com/arclite-pro/ | url=https://etheriar.com/apps/Arclite+Pro.dmg
beam-studio | Beam Studio | Design and control software for laser cutters and engravers | dmg | direct_arch | https://flux3dp.com/beam-studio/ | arm=https://beamstudio.s3-ap-northeast-1.amazonaws.com/mac-arm64/Beam+Studio+{v}.dmg;intel=https://beamstudio.s3-ap-northeast-1.amazonaws.com/mac/Beam+Studio+{v}.dmg;vers=https://id.flux3dp.com/api/check-update?key=beamstudio-stable;vregex=mac-arm64\/Beam\+Studio\+(\d+(?:\.\d+)+)\.dmg
boundary | Boundary | Secure access to hosts and services without managing credentials | dmg | direct_arch | https://www.boundaryproject.io/ | arm=https://releases.hashicorp.com/boundary-desktop/{v}/boundary-desktop_{v}_darwin_arm64.dmg;intel=https://releases.hashicorp.com/boundary-desktop/{v}/boundary-desktop_{v}_darwin_amd64.dmg;vers=https://api.releases.hashicorp.com/v1/releases/boundary-desktop/latest;vregex="version"\s*:\s*"(\d+(?:\.\d+)+)\"
buhontfs | Buhontfs | Reads and writes Microsoft NTFS-formatted drives | dmg | direct_latest | https://www.drbuho.com/buhontfs | url=https://www.drbuho.com/download/buhontfs.dmg
canister | Canister | Verifies and manages LTO and LTFS tape archives | dmg | direct_latest | https://hedge.co/products/canister | url=https://hedge.video/download/canister/macos
cascable-pro-webcam | Cascable Pro Webcam | Uses a camera as a high-quality webcam for video calls | zip | direct_latest | https://cascable.se/pro-webcam/ | url=https://cascable.se/pro-webcam/CascableProWebcam-Latest.zip
cisco-audio-device | Cisco Audio Device | Audio driver for using a desk phone or headset with Webex | pkg | direct_latest | https://help.webex.com/ | url=https://www.cisco.com/c/dam/en/us/td/docs/collaboration/webex_centers/Collaboration-Help/TS-Help-Portal-Support-Utilities/CiscoAudioDeviceInstall/CiscoAudioDeviceInstall.pkg
connectmenow4 | ConnectMeNow4 | Mounts and monitors network shares from the menu bar | dmg | direct_arch | https://www.tweaking4all.com/software/macosx-software/connectmenow-v4/ | arm=https://www.tweaking4all.com/downloads/network/ConnectMeNow4-v{v}-macOS-arm64.dmg;intel=https://www.tweaking4all.com/downloads/network/ConnectMeNow4-v{v}-macOS-x86-64.dmg;vers=https://www.tweaking4all.com/software/macosx-software/connectmenow-v4/;vregex=ConnectMeNow4-v(\d+(?:\.\d+)+)-macOS
cotypist | Cotypist | Predictive text autocompletion that works across all apps | dmg | direct_latest | https://cotypist.app/ | url=https://cotypist.app/download/Cotypist.dmg
cursor-teleporter | Cursor Teleporter | Quickly jump the text cursor between recent edit locations | zip | direct | https://www.apptorium.com/cursor-teleporter | url=https://www.apptorium.com/public/products/cursor-teleporter/releases/CursorTeleporter-{v}.zip;vers=https://www.apptorium.com/updates/cursor-teleporter;vregex=CursorTeleporter-(\d+(?:\.\d+)+)\.zip
dialpad-meetings | Dialpad Meetings | Video meetings and conferencing client | dmg | direct_arch | https://www.dialpad.com/download/ | arm=https://storage.googleapis.com/uc_native/stable/osx/arm64/DialpadMeetings.dmg;intel=https://storage.googleapis.com/uc_native/stable/osx/x64/DialpadMeetings.dmg
disk-space-analyzer | Disk Space Analyzer | Visualizes disk usage and finds large files and folders | dmg | direct_latest | https://nektony.com/disk-expert | url=https://download.nektony.com/download/diskexpert/disk-space-analyzer.dmg
dropnotch | Dropnotch | Drag-and-drop shelf that lives in the notch area | dmg | direct_latest | https://junebytes.com/dropnotch | url=https://junebytes.com/downloads/DropNotch.dmg
editready | Editready | Transcodes and rewraps video into edit-ready formats | dmg | direct_latest | https://hedge.co/products/editready | url=https://updates.hedge.video/editready/macos/latest/EditReady.dmg
everweb | Everweb | Drag-and-drop website builder and publisher | dmg | direct_latest | https://www.everwebapp.com/ | url=https://www.ragesw.com/downloads/everweb/everweb.dmg
filemail | Filemail | Sends and receives large files without size limits | dmg | direct_latest | https://www.filemail.com/apps/mac-desktop | url=https://filemailprod.blob.core.windows.net/downloads/Apps/Filemail_Desktop_Setup_macos.dmg
fileminutes | Fileminutes | Searches, navigates, and acts on files from one window | dmg | direct_latest | https://www.fileminutes.com/ | url=https://www.fileminutes.com/downloads/FileMinutes.dmg
flashpeak-slimjet | Flashpeak Slimjet | Chromium-based web browser | dmg | direct_arch | https://www.slimjet.com/en/dlpage.php | arm=https://www.slimjet.com/release/slimjet_arm.dmg;intel=https://www.slimjet.com/release/slimjet.dmg;vers=https://www.slimjet.com/en/dlpage.php;vregex=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+
flexihub | Flexihub | Shares USB and serial devices over a network connection | dmg | direct_latest | https://www.flexihub.com/ | url=https://cdn.electronic.us/products/flexihub/mac/download/flexihub.dmg
flowjo | Flowjo | Flow cytometry data analysis and visualization platform | dmg | direct_arch | https://www.flowjo.com | arm=https://downloads.bdaccessportal.com/v11/mac/arm64/FlowJo-{v}-arm64.dmg;intel=https://downloads.bdaccessportal.com/v11/mac/x64/FlowJo-{v}-x64.dmg;vers=https://www.flowjo.com/flowjo/download;vregex=FlowJo-(\d+(?:\.\d+)+)-arm64\.dmg
focusee | Focusee | Screen recorder with automatic zoom and motion editing | dmg | direct_latest | https://gemoo.com/focusee/ | url=https://focusee.imobie-resource.com/product/focusee-en-v2-mac.dmg
folge | Folge | Creates step-by-step guides and standard operating procedures | dmg | direct_arch | https://folge.me/ | arm=https://folge.me/get-osx-arm64-release;intel=https://folge.me/get-osx-release
global-secure-access-client | Global Secure Access Client | Entra client for secure access to private and internet resources | pkg | direct_latest | https://learn.microsoft.com/en-us/entra/global-secure-access/reference-macos-client-release-history | url=https://aka.ms/globalsecureaccess-macos
grasshopper | Grasshopper | Virtual phone system for calls, texts, and voicemail | dmg | direct_latest | https://grasshopper.com/ | url=https://dl.grasshopper.com/Grasshopper.dmg
horse | Horse | Browser that organizes pages into trails instead of tabs | zip | direct_arch | https://browser.horse/ | arm=https://carrots.browser.horse/download/darwin-arm64;intel=https://carrots.browser.horse/download/darwin-x64;vers=https://browser.horse/changelog;vregex=v(\d+(?:\.\d+)+)
iboostup | Iboostup | Cleans, optimizes, and monitors system performance | dmg | direct_latest | https://www.iboostup.com/ | url=https://cdn.iboostup.com/iboostup.dmg
imymac-pdf-compressor | Imymac Pdf Compressor | Reduces PDF file size while keeping document quality | dmg | direct_latest | https://www.imymac.com/pdf-compressor/ | url=https://www.imymac.com/download/imymac-pdf-compressor.dmg
imymac-video-converter | Imymac Video Converter | Converts video between formats with editing tools | dmg | direct_latest | https://www.imymac.com/video-converter/ | url=https://www.imymac.com/download/imymac-video-converter.dmg
integrity-plus | Integrity Plus | Checks websites for broken links and reports issues | dmg | direct_latest | https://peacockmedia.software/mac/integrity-plus/ | url=https://peacockmedia.software/mac/integrity-plus/integrity-plus.dmg
integrity-pro | Integrity Pro | Link checker with sitemap, SEO, and spelling reports | dmg | direct_latest | https://peacockmedia.software/mac/integrity-pro/ | url=https://peacockmedia.software/mac/integrity-pro/integrity-pro.dmg
iperius-remote | Iperius Remote | Remote desktop client for support and unattended access | dmg | direct_latest | https://www.iperiusremote.com/ | url=https://www.iperiusremote.com/dsir.aspx?file=IperiusRemote.dmg
iphone-backup-extractor | Iphone Backup Extractor | Recovers messages, photos, and data from iOS device backups | dmg | direct_latest | https://reincubate.com/iphone-backup-extractor/ | url=https://releases.reincubate.com/iphonebackupextractor-latest.dmg
istatistica-pro | Istatistica Pro | System and hardware monitor showing sensors, network, and disk activity | dmg | direct_latest | https://www.imagetasks.com/istatistica/pro/ | url=https://www.imagetasks.com/istatistica/pro/download-pro/iStatisticaProTrial.dmg
jane-reader | Jane Reader | Distraction-free EPUB reader with annotation and library management | dmg | direct_arch | https://janereader.com/ | arm=https://janereader.com/downloads/releases/darwin/aarch64/{v};intel=https://janereader.com/downloads/releases/darwin/x86_64/{v};vers=https://janereader.com/en/changelog.xml;vregex=changelog\/(\d+(?:\.\d+)+)<\/guid>
later | Later | Saves open browser tabs and restores them in a later session | dmg | direct_latest | https://github.com/alyssaxuu/later | url=https://github.com/alyssaxuu/later/raw/master/Later.dmg
lingvanex-translator | Lingvanex Translator | Translates text, speech, and documents across many languages | dmg | direct_latest | https://lingvanex.com/products/macos-translator/ | url=https://lingvanex-downlod.s3.eu-central-1.amazonaws.com/LingvanexMacOS.dmg
mac-linguist | Mac Linguist | Translates text between languages using online translation services | dmg | direct_latest | https://maclinguist.com/ | url=https://maclinguist.com/Mac%20Linguist.dmg
macuncle-eml-viewer | Macuncle Eml Viewer | Opens and reads EML email message files without an account | dmg | direct_latest | https://www.macuncle.com/eml/viewer/ | url=https://www.macuncle.com/dl/macuncle-eml-viewer.dmg
minimoon | Minimoon | Minimal music player for the menu bar | dmg | direct_latest | https://www.plastaq.com/minimoon/ | url=https://minimoon-dist.plastaq.com/MiniMoon-latest.dmg
mixpad | Mixpad | Multitrack audio recording and mixing studio | zip | direct_latest | https://www.nch.com.au/mixpad/index.html | url=https://www.nch.com.au/mixpad/mpmacu.zip
mxmarkedit | Mxmarkedit | Editor for writing and formatting Markdown text | zip | direct_latest | https://github.com/maxnd/mxMarkEdit | url=https://github.com/maxnd/mxMarkEdit/raw/main/app/mxMarkEdit.zip
my-picturemaxx-5 | My Picturemaxx 5 | Client for searching and managing stock media libraries | dmg | direct_latest | https://www.picturemaxx.com/en/download-my-picturemaxx | url=https://mypm-downloads.picturemaxx.com/setup-my-picturemaxx-5.dmg;verified=mypm-downloads.picturemaxx.com/
offshoot | Offshoot | Offloads and verifies media files from camera cards | dmg | direct_latest | https://hedge.co/products/offshoot | url=https://updates.hedge.video/hedge/macos/latest/OffShoot.dmg;verified=updates.hedge.video/
ondesoft-spotify-converter | Ondesoft Spotify Converter | Downloads and converts Spotify tracks to MP3, M4A, or FLAC | dmg | direct_latest | https://www.ondesoft.com | url=https://dl.ondesoft.com/odspconverter_mac.dmg;verified=dl.ondesoft.com/

# ---- author batch C: direct_latest / direct_arch / github_tag (verify on Mac) ----
otter | Otter | AI meeting notetaker that records, transcribes, and summarizes conversations | dmg | direct_latest | https://otter.ai/ | url=https://assets.otter.ai/desktop-app/mac/production/integrationpage/otter_universal_latest.dmg
alectrona-patch | Patch Desktop | Configures and manages Alectrona Patch software-update policies | pkg | direct_latest | https://www.alectrona.com/patch | url=https://software.alectrona.com/patch-desktop/latest.pkg
patternodes | Patternodes | Node-based tool for creating animated and parametric vector graphics | dmg | direct_latest | https://www.lostminds.com/patternodes/ | url=https://www.lostminds.com/downloads/patternodes3.dmg
pdfsail | Pdfsail | Edits, converts, and compresses PDF documents | dmg | direct_latest | https://www.pdfsail.com/ | url=https://download.pdfsail.com/OfficeSuite/PDFSailMac/PDFsail_mac_Desktop%20Installer.dmg
pixillion | Pixillion | Converts images between 65+ formats including JPG, PNG, and GIF | zip | direct_latest | https://www.nchsoftware.com/imageconverter/index.html | url=https://www.nchsoftware.com/imageconverter/pixillionmaci.zip
print-window | Print Window | Creates customizable listings and catalogs of files and folders | dmg | direct_latest | https://apps.apple.com/us/app/print-window/id834048325 | url=http://www.printwindowapp.com/software/printwindow.dmg
pulseway | Pulseway | Remote monitoring and management agent for IT systems | dmg | direct_latest | https://www.pulseway.com/downloads | url=https://pulseway.s3.us-east-1.amazonaws.com/website/downloads/Pulseway.dmg
quilt-app | Quilt | Captures screen content and exports it as searchable PDFs | dmg | direct_latest | https://quiltformac.com/ | url=https://github.com/shubhamshah02/Quilt/releases/download/prod/Quilt.Installer.dmg
rumplet | Rumplet | Drop applet for sending large files through a Rumpus server | zip | direct_latest | https://www.maxum.com/Rumpus/Rumplet.html | url=https://www.maxum.com/DownloadPackages/Rumplet.zip
screenflow-hal-audio-driver | Screenflow Hal Audio Driver | Audio capture driver for the App Store edition of ScreenFlow | pkg | direct_latest | https://www.telestream.net/screenflow/overview.htm | url=https://www.telestream.net/download-files/screenflow/InstallTelestreamAudioCapture.pkg.zip
shokz-connect | Shokz Connect | Manages and updates firmware for Shokz headsets | dmg | direct_latest | https://pro.shokz.com/pages/shokz-connect | url=https://appcdn.shokz.com/shokz-connect/latest/Shokz-Connect-latest-mac.dmg
station | Station | Workspace that unifies your web apps into a single window | zip | github_tag | https://github.com/getstation/desktop-app | repo=getstation/desktop-app;asset=Station.zip
substage | Substage | Client for staging, committing, and managing Git repositories | dmg | direct_latest | https://selkie.design/substage/ | url=https://assets.selkie.design/substage/download/latest/Substage.dmg
teamwire | Teamwire | Secure messenger for enterprise team chat and file sharing | dmg | direct_arch | https://www.teamwire.eu | arm=https://desktop.teamwire.eu/dist/v{v}/teamwire-{v}-mac-arm64.dmg;intel=https://desktop.teamwire.eu/dist/v{v}/teamwire-{v}-mac-x64.dmg;vers=https://desktop.teamwire.eu/dist/;vregex=href="v(\d+(?:\.\d+)+)\/\"
tinyweb | TinyWeb | Minimal browser that stays out of the way while reading | dmg | direct_latest | https://tinyweb.so/ | url=https://tinyweb.so/release/osx/tinyweb_latest
trace | Trace | Logs and reviews how working time is spent across tasks | dmg | direct_latest | https://trace.argio.ch/en/ | url=https://trace.argio.ch/download/Trace.dmg
trident | Trident | Unified workspace combining email, calendar, chat, and contacts | dmg | direct_arch | https://www.zoho.com/trident/ | arm=https://downloads.zohocdn.com/trident/mac/apple/Trident.dmg;intel=https://downloads.zohocdn.com/trident/mac/intel/Trident.dmg
trint | Trint | Transcribes and edits audio and video into searchable text | zip | direct_arch | https://trint.com | arm=https://desktopapp.trint.com/updates/darwin/arm64/Trint-darwin-arm64-{v}.zip;intel=https://desktopapp.trint.com/updates/darwin/x64/Trint-darwin-x64-{v}.zip;vers=https://desktopapp.trint.com/updates/darwin/arm64/RELEASES.json;vregex=currentRelease"\s*:\s*"(\d+(?:\.\d+)+)"
tweeten | Tweeten | Client for Twitter built on the TweetDeck interface | zip | github_tag | https://github.com/MehediH/Tweeten | repo=MehediH/Tweeten;asset=tweeten-darwin-x64.zip
usb-network-gate | USB Network Gate | Shares USB devices with other computers over a network | dmg | direct_latest | https://www.eltima.com/products/usb-over-ethernet/ | url=https://cdn.electronic.us/products/usb-over-ethernet/mac/download/usb_network_gate.dmg
utm-coordinate-converter | UTM Coordinate Converter | Converts between UTM and latitude/longitude coordinates | dmg | direct_arch | https://www.ewert-technologies.ca/home/products/utm-coordinate-converter-home.html | arm=https://bitbucket.org/vewert/ewert-technologies/downloads/ucc_{v}_aarch64.dmg;intel=https://bitbucket.org/vewert/ewert-technologies/downloads/ucc_{v}_x86-64.dmg;vers=https://www.ewert-technologies.ca/home/products/utm-coordinate-converter-home/utm-coordinate-converter-downloads.html;vregex=ucc_(\d+(?:\.\d+)+)_
vagon | Vagon | Streams a high-performance cloud computer to your device | dmg | direct_arch | https://vagon.io/download | arm=https://app.vagon.io/apps/Vagon-arm64.dmg;intel=https://app.vagon.io/apps/Vagon.dmg
vectoraster | Vectoraster | Generates raster patterns and halftone effects from images | dmg | direct_latest | https://lostminds.com/vectoraster/ | url=https://www.lostminds.com/downloads/vectoraster8.dmg
vectorstyler | Vectorstyler | Vector graphics design and illustration tool | dmg | direct_arch | https://www.vectorstyler.com/ | arm=https://www.vectorstyler.com/product/vectorstyler_m1.dmg;intel=https://www.vectorstyler.com/product/vectorstyler_intel.dmg
videoproc-vlogger | Videoproc Vlogger | Free video editor with effects, transitions, and color grading | dmg | direct_latest | https://www.videoproc.com/video-editing-software/ | url=https://www.videoproc.com/download/videoproc-vlogger.dmg
vidmore-player | Vidmore Player | Plays Blu-ray discs, DVDs, and digital media files | dmg | direct_latest | https://www.vidmore.com/vidmore-player/ | url=https://download.vidmore.com/mac/vidmore-player.dmg
vidmore-screen-recorder | Vidmore Screen Recorder | Records screen activity, audio, and webcam footage | zip | direct_latest | https://www.vidmore.com/screen-recorder/ | url=https://download.vidmore.com/mac/screen-recorder.zip
vidmore-video-enhancer | Vidmore Video Enhancer | Upscales and improves video resolution and quality | dmg | direct_latest | https://www.vidmore.com/video-enhancer/ | url=https://download.vidmore.com/mac/video-enhancer.dmg
viper-ftp | Viper Ftp | Client for transferring files over FTP, SFTP, and cloud storage | dmg | direct_latest | https://viperftp.com/ | url=https://naarakstudio.com/download/ViperFTP.dmg
xnresize | Xnresize | Batch resizes images and converts between formats | dmg | direct_latest | https://www.xnview.com/en/xnresize/ | url=https://download.xnview.com/XnResize-mac-x64.dmg

# ---- author batch D: AutoPkg-pending resolved (verify on Mac with DRYRUN) ----
1piece | 1Piece | Window manager with thumbnails, hot corners, and mouse triggers | zip | direct | https://app1piece.com | url=https://app1piece.com/1Piece-{v}.zip;vers=https://app1piece.com/download/;vregex=1Piece-(\d+(?:\.\d+)+)\.zip
accents | Accents | Unlocks iMac and MacBook accent colors on any Mac | zip | direct_latest | https://mahdi.jp/apps/accents | url=https://tars.mahdi.jp/apps/accents.zip
air-flow | Air | Syncs an Air workspace into Finder for local file access | zip | direct_arch | https://air.inc/air-flow-macos | arm=https://github.com/AirLabsTeam/airflow-releases/releases/download/v{v}/Air-{v}-arm64-mac.zip;intel=https://github.com/AirLabsTeam/airflow-releases/releases/download/v{v}/Air-{v}-mac.zip;vers=https://github.com/AirLabsTeam/airflow-releases/releases/latest;vregex=([0-9]+(?:\.[0-9]+)+)
aircall-workspace | Aircall Workspace | Business phone client with CRM and helpdesk integrations | pkg | direct_arch | https://aircall.io/download/ | arm=https://download-electron.aircall.io/aircall-workspace/Aircall-Workspace-{v}-arm64.pkg;intel=https://download-electron.aircall.io/aircall-workspace/Aircall-Workspace-{v}-x64.pkg;vers=https://electron.aircall.io/update/osx/0.0.0?appType=aircall-workspace;vregex="name"\s*:\s*"(\d+(?:\.\d+)+)\"
airtime | Airtime | Adds custom looks and visuals to video-meeting webcam feeds | dmg | direct_latest | https://www.airtime.com/download | url=https://updates.airtimetools.com/mac/hybrid/Airtime.dmg
amazon-appstream-20 | Amazon Appstream 20 | Client for streaming applications and desktops from AWS | pkg | direct_latest | https://clients.amazonappstream.com/ | url=https://clients.amazonappstream.com/installers/mac/global/WorkSpacesApplicationsClient.pkg
appcode | Appcode | IDE for Swift and Objective-C iOS and app development | dmg | direct_arch | https://www.jetbrains.com/objc/ | arm=https://download.jetbrains.com/objc/AppCode-{v}-aarch64.dmg;intel=https://download.jetbrains.com/objc/AppCode-{v}.dmg;vers=https://data.services.jetbrains.com/products/releases?code=AC&latest=true&type=release;vregex="version":"(\d+(?:\.\d+)+)"
arcade | Arcade | Records interactive product demos and exports to video or GIF | dmg | direct_header | https://www.arcade.software/download | short=https://app.arcade.software/desktop/download;regex=dmg\/(\d+(?:\.\d+)+)\/Arcade\.dmg
changes | Changes | Native Git client with a low-cognitive-load interface | zip | github_tag | https://github.com/maoyama/Changes | repo=maoyama/Changes;asset=Changes.zip
dinoxcope | Dinoxcope | Image capture and analysis for Dino-Lite USB microscopes | dmg | direct_latest | https://www.dinolite.us/features/dinoxcope/ | url=https://files.dinolite.us/downloads/software/dnx/latest/DinoXcope.dmg
flinto | Flinto | Designs interactive and animated app prototypes | dmg | direct_header | https://www.flinto.com/ | short=https://www.flinto.com/download_latest;regex=Flinto-(\d+(?:\.\d+)+)\.dmg
folder-tidy | Folder Tidy | Sorts and organizes files into subfolders by type using rules | dmg | direct_header | https://www.tunabellysoftware.com/folder_tidy/ | short=https://www.tunabellysoftware.com/latest/Folder_Tidy.dmg;regex=Folder Tidy (\d+(?:\.\d+)+)\.dmg
fontagent | FontAgent | Organizes, activates, and manages font libraries with previews | dmg | direct_latest | https://www.insidersoftware.com/fontagent-mac/ | url=https://store.insidersoftware.com/_downloads/FontAgent10.dmg
goto-meeting | GoTo | Client for online meetings and screen sharing | dmg | electron | https://support.goto.com/ | feed=https://goto-desktop.getgo.com/latest-mac.yml;arm=GoTo-{v}-arm64;intel=GoTo-{v}
grab2text | Grab2Text | Extracts text and QR codes from images, PDFs, and video | dmg | direct_latest | https://www.softwarehow.com/grab2text/ | url=https://www.softwarehow.com/downloads/Grab2Text.dmg
houdahgeo | HoudahGeo | Geotags and maps photos with GPS tracks and reverse geocoding | zip | direct | https://www.houdah.com/houdahGeo/ | url=https://dl.houdah.com/houdahGeo/updates/cast_assets/HoudahGeo{v}.zip;vers=https://www.houdah.com/houdahGeo/updates/cast6.php;vregex=HoudahGeo(\d+(?:\.\d+)+)\.zip
ledger-live | Ledger Live | Manages crypto assets and Ledger hardware wallets | dmg | electron | https://www.ledger.com/ledger-live | feed=https://download.live.ledger.com/latest-mac.yml;universal=ledger-live-desktop-{v}-mac
microsoft-advertising-editor | Microsoft Advertising Editor | Bulk-edits and manages Microsoft Advertising campaigns offline | dmg | direct_latest | https://about.ads.microsoft.com/en/tools/productivity/microsoft-advertising-editor | url=https://prod.editor.ads.microsoft.com/download/production-mac/c/MicrosoftAdvertisingEditor.dmg
mindview-9 | MindView 9 | Mind mapping with timelines, outlines, and Office export | dmg | direct_latest | https://www.matchware.com/mind-mapping-software-mac | url=https://link.matchware.com/mindview9_mac
movie-magic-budgeting | Movie Magic Budgeting | Creates and manages film and TV production budgets | dmg | direct_latest | https://www.ep.com/support/movie-magic-budgeting/ | url=https://updates.ep.com/mmb/Movie%20Magic%20Budgeting.dmg
nightowl | NightOwl | Menu bar toggle for switching between light and dark mode | zip | direct | https://nightowl.kramser.xyz/ | url=https://darkmenu.s3.amazonaws.com/NightOwl-{v}.zip;vers=https://darkmenu.s3.amazonaws.com/appcast.xml;vregex=NightOwl-(\d+(?:\.\d+)+)\.zip
phraseexpress | PhraseExpress | Text expander that inserts canned responses and boilerplate text | dmg | direct_latest | https://www.phraseexpress.com/ | url=https://www.phraseexpress.com/PhraseExpressSetup.dmg
sidebar | Sidebar | Adds a customizable shortcut bar to the menu bar and screen edge | dmg | direct | https://sidebarapp.net/ | url=https://download.sidebarapp.net/Sidebar%20{v}.dmg;vers=https://download.sidebarapp.net/appcast.xml;vregex=Sidebar%20(\d+(?:\.\d+)+)\.dmg
soundq | SoundQ | Searches, auditions, and downloads sound effects from connected libraries | pkg | direct | https://www.prosoundeffects.com/soundq/ | url=https://prosoundeffects.blob.core.windows.net/software-updates/SoundQ/SoundQ_v{v}.pkg;vers=https://www.prosoundeffects.com/soundq/;vregex=SoundQ_v(\d+(?:\.\d+)+)\.pkg
startup-manager-pro | Startup Manager Pro | Manages login items, launch delays, and multiple startup sets | dmg | direct | https://startupmanager.appmac.fr/ | url=https://startupmanager.appmac.fr/update/sparkle/Startup%20Manager%20Pro-{v}.dmg;vers=https://startupmanager.appmac.fr/update/sparkle/appcast.xml;vregex=Startup%20Manager%20Pro-(\d+(?:\.\d+)+)\.dmg
tembo-2 | Tembo 2 | Searches every file on the computer from one window | zip | direct | https://www.houdah.com/tembo/ | url=https://dl.houdah.com/tembo/updates/cast2_assets/Tembo{v}.zip;vers=https://www.houdah.com/tembo/updates/cast2.xml;vregex=Tembo(\d+(?:\.\d+)+)\.zip
tembo-3 | Tembo 3 | Searches every file on the computer from one window | zip | direct | https://www.houdah.com/tembo/ | url=https://dl.houdah.com/tembo/updates/cast2_assets/Tembo{v}.zip;vers=https://www.houdah.com/tembo/updates/cast3.xml;vregex=Tembo(\d+(?:\.\d+)+)\.zip
textsoap | TextSoap | Cleans up and reformats text with automated scrubbing rules | dmg | direct_latest | https://textsoap.com/mac/index.html | url=https://textsoap.nyc3.digitaloceanspaces.com/files/textsoap9_latest.dmg
typewhisper | TypeWhisper | On-device speech-to-text dictation that types into any app | dmg | direct | https://github.com/TypeWhisper/typewhisper-mac | url=https://github.com/TypeWhisper/typewhisper-mac/releases/download/v{v}/TypeWhisper-v{v}.dmg;vers=https://api.github.com/repos/TypeWhisper/typewhisper-mac/releases?per_page=100;vregex=TypeWhisper-v(\d+\.\d+\.\d+)\.dmg
vernier-graphical-analysis | Vernier Graphical Analysis | Collects and graphs data from Vernier sensors and probes | dmg | direct_latest | https://graphicalanalysis.app/ | url=https://software-releases.graphicalanalysis.com/ga/mac/release/latest/Vernier-Graphical-Analysis.dmg

# ---- custom conversion: 78 source=custom (resolver fns below) + 6 handler rows ----
barcode-studio | Barcode Studio | Generates 1D and 2D barcodes and exports them as images or vectors | pkg | custom | https://www.tec-it.com/en/product/barcode-software/barcode-maker/Default.aspx |
bimcollab-zoom | BIMcollab Zoom | Reviews and coordinates BIM models and clash issues | dmg | custom | https://www.bimcollab.com/en/products/bimcollab-zoom |
buhocleaner | BuhoCleaner | Cleans junk files and frees up disk space | dmg | custom | https://www.drbuho.com/buhocleaner |
capture-one | Capture One | Edits and organizes raw photos with tethered capture | dmg | custom | https://www.captureone.com |
cato-client | Cato Client | Connects devices to the Cato SASE cloud network | pkg | custom | https://www.catonetworks.com/sase |
cloudya | Cloudya | Cloud telephony client for calls, chat, and meetings | zip | custom | https://www.nfon.com/en/products/cloudya |
code42 | Code42 | Backs up endpoint data and detects insider risk | dmg | custom | https://www.crashplan.com |
comic-life-4 | Comic Life 4 | Creates comics and photo stories from your own images | zip | custom | https://plasq.com/apps/comiclife/macwin/ |
conniepad | Conniepad | Collaborative meeting notes that turn into organized minutes | dmg | custom | https://conniepad.com/ |
cricut-design-space | Cricut Design Space | Designs projects and sends cut jobs to Cricut machines | dmg | custom | https://cricut.com/en-us/design-space |
daylite | Daylite | CRM and productivity manager for small businesses | zip | custom | https://www.marketcircle.com/daylite/ |
dedoose | Dedoose | Analyzes qualitative and mixed-methods research data | dmg | direct_header | https://www.dedoose.com | short=https://downloads.dedoose.com/dedoose-app-releases/Dedoose-Mac.dmg;regex=Dedoose-Mac-v(\d+(?:\.\d+)+)\.dmg
delighted | DelightEd | Converts written text to spoken-word audio files | zip | custom | https://eclecticlight.co/delighted-podofyllin/ |
dell-display-peripheral-manager | Dell Display Peripheral Manager | Adjusts settings for Dell monitors and connected peripherals | pkg | custom | https://www.dell.com/support/kbdoc/en-us/000201067/dell-display-and-peripheral-manager-for-macos |
deskrest | DeskRest | Reminds you to take breaks to reduce eye and wrist strain | dmg | custom | https://github.com/Marceeelll/DeskRest-releases |
displaylink-manager | Displaylink Manager | Drives external displays connected through DisplayLink docks | pkg | custom | https://www.synaptics.com/products/displaylink-graphics/downloads/macos |
depnotify | Depnotify | Shows enrollment progress during automated device setup | pkg | direct_latest | https://github.com/jamf/DEPNotify | url=https://files.jamfconnect.com/DEPNotify.pkg
eclipse-ide-for-embedded-cc-developers | Eclipse IDE for Embedded CC Developers | Eclipse IDE distribution for embedded C and C++ development | dmg | custom | https://www.eclipse.org/downloads/packages/ |
eclipse-ide-for-scout-developers | Eclipse IDE for Scout Developers | Eclipse IDE distribution for building Scout business applications | dmg | custom | https://www.eclipse.org/downloads/packages/ |
final-draft-12 | Final Draft 12 | Screenwriting tool for formatting and outlining scripts | dmg | custom | https://www.finaldraft.com |
final-draft-13 | Final Draft 13 | Screenwriting tool for formatting and outlining scripts | dmg | custom | https://www.finaldraft.com |
flashprint-5 | FlashPrint 5 | Slicer that prepares 3D models for FlashForge printers | pkg | custom | https://www.flashforge.com/pages/download-center |
foldr | Foldr | Client for browsing and accessing Foldr file and resource shares | dmg | custom | https://foldr.com/ |
fotomagico | FotoMagico | Builds slideshows from photos, video, and music | zip | custom | https://fotomagico.com/download/ |
frameio-transfer | Frame.io Transfer | Uploads and downloads media files to and from Frame.io | dmg | custom | https://frame.io/transfer |
growly-glucose | Growly Glucose | Tracks blood glucose readings, meals, and medication | dmg | custom | https://growlybird.com/glucose/ |
guardian-browser | Guardian Browser | Locked-down browser for taking online proctored exams | dmg | custom | https://guardian.meazurelearning.com/ |
huddly | Huddly | Configures and updates firmware for Huddly conference cameras | dmg | custom | https://www.huddly.com |
hudl-sportscode | Hudl Sportscode | Tags and analyzes sports video for performance review | dmg | custom | https://www.hudl.com/downloads/elite |
huggingchat-mac | HuggingChat | Chat client for Hugging Face conversational models | zip | custom | https://github.com/huggingface/chat-macOS |
imanage-work | iManage Work Desktop | Connects to iManage Work document and email management | pkg | custom | https://docs.imanage.com/work-mac-help/10.4.1/en/ |
ipsw-updater | IPSW Updater | Notifies when new IPSW firmware files are released | zip | custom | https://ipsw.app/ |
jamf-compliance-editor | Jamf Compliance Editor | Builds and tailors security compliance baselines for devices | pkg | custom | https://github.com/Jamf-Concepts/jamf-compliance-editor |
jamf-connect-configuration | Jamf Connect Configuration | Builds configuration profiles for Jamf Connect authentication | dmg | custom | https://www.jamf.com/products/jamf-connect/ |
jamf-connect-login | Jamf Connect Login | Authenticates the login window against a cloud identity provider | pkg | custom | https://www.jamf.com/products/jamf-connect/ |
joan-configurator | Joan Configurator | Configures Joan room and desk booking displays | dmg | custom | https://support.getjoan.com/knowledge/what-is-the-joan-configurator |
jpegmini-pro | Jpegmini Pro | Reduces photo file size while preserving visual quality | dmg | custom | https://jpegmini.com/downloads/mac |
keeper-secrets-manager-cli | Keeper Secrets Manager Cli | Command-line client for retrieving secrets from Keeper vaults | pkg | custom | https://github.com/Keeper-Security/secrets-manager |
lg-calibration-studio | Lg Calibration Studio | Calibrates color on supported monitors | pkg | custom | https://www.lg.com/us/support/product/lg-34WK95U-W.AUS |
macos-instantview | Macos Instantview | Display and file-transfer driver for Silicon Motion docking devices | dmg | custom | https://www.siliconmotion.com/events/instantview/ |
mamp-pro | Mamp Pro | Manages local Apache, Nginx, PHP, and MySQL development servers | pkg | custom | https://www.mamp.info/en/mac/ |
maxon-cinema-4d-2026 | Maxon Cinema 4D 2026 | Professional 3D modeling, animation, and rendering suite | dmg | custom | https://www.maxon.net/en/downloads/cinema-4d-2026-downloads |
medialab-connect | Medialab Connect | Companion uploader for the MediaLab clinical content platform | dmg | custom | https://www.medialab.co/downloads/ |
mersive-solstice | Mersive Solstice | Wireless screen sharing client for Solstice collaboration displays | dmg | direct_header | https://www.mersive.com/download/ | short=https://www.mersive.com/files/41693/;regex=SolsticeClient-(\d+(?:\.\d+)+)\.dmg
microsoft-company-portal | Microsoft Company Portal | Enrolls devices and installs company apps via Intune | pkg | custom | https://learn.microsoft.com/en-us/mem/intune/apps/apps-company-portal-macos |
microsoft-powershell | Microsoft Powershell | Cross-platform task automation shell and scripting language | pkg | custom | https://github.com/PowerShell/PowerShell |
mimiq | Mimiq | Creates a virtual NDI camera from networked video sources | dmg | custom | https://hedge.co/products/mimiq |
mister-horse-product-manager | Mister Horse Product Manager | Installs and updates Mister Horse animation presets and extensions | dmg | custom | https://misterhorse.com/product-manager |
monotype-connect | Monotype Connect | Manages and syncs fonts from a Monotype subscription | dmg | custom | https://www.monotype.com/products/monotype-connect |
multiviewer-for-f1 | Multiviewer For F1 | Watches multiple Formula 1 live timing and video feeds at once | dmg | custom | https://multiviewer.app |
netbird | Netbird | WireGuard-based mesh VPN client for private networks | pkg | custom | https://github.com/netbirdio/netbird |
noor | Noor | Native team chat for organized conversations and channels | dmg | custom | https://noor.to/ |
nvivo-14 | NVivo 14 | Qualitative data analysis for coding and interpreting research | dmg | custom | https://lumivero.com/products/nvivo/ |
nvivo-15 | NVivo 15 | Qualitative data analysis for coding and interpreting research | dmg | custom | https://lumivero.com/products/nvivo/ |
okiocam-snapshot-and-recorder | OKIOCAM Snapshot and Recorder | Document-camera capture with snapshots and screen recording | zip | custom | https://www.okiolabs.com/apps-software-download/ |
onemenu | OneMenu | All-in-one window manager with clipboard and system monitor menu bar | zip | direct | https://coffeebreak.software/one-menu/ | url=https://files.coffeebreak.software/products/one-menu/OneMenu-v{v}.zip;version=26.10.2
optisigns-digital-signage | OptiSigns Digital Signage | Plays digital signage content on connected screens | dmg | direct_header | https://www.optisigns.com/ | short=https://links.optisigns.com/mac;regex=OptiSigns Digital Signage-(\d+(?:\.\d+)+)\.dmg
origami-3 | Origami 3 | Designs packaging dielines and 3D mockups for print | dmg | custom | https://boxshot.com/origami/ |
poly-lens | Poly Lens Desktop | Manages headsets, video bars, and room devices | pkg | custom | https://www.hp.com/us-en/poly/software-and-services/software/poly-lens/app.html |
postlab | PostLab | Collaboration and version history for Final Cut and Premiere | dmg | custom | https://hedge.co/products/postlab |
praxislive | PraxisLIVE | Visual live programming for media and generative art | pkg | custom | https://www.praxislive.org/ |
prisma-access-browser | Prisma Access Browser | Secure enterprise browser with built-in access controls | pkg | custom | https://www.paloaltonetworks.com/sase/prisma-browser |
setup-manager | Setup Manager | Automates first-run enrollment and setup workflows | pkg | custom | https://github.com/jamf/Setup-Manager |
sforzando | sforzando | Sample player and synthesizer for SFZ instruments | dmg | custom | https://www.plogue.com/products/sforzando.html |
shellhistory | ShellHistory | Searchable history of shell commands across sessions | zip | custom | https://loshadki.app/shellhistory/ |
slido-for-powerpoint | Slido for PowerPoint | Live polls, quizzes, and Q&A inside presentations | dmg | custom | https://www.slido.com/powerpoint-polling |
smart-mirror-app | SMART Mirror | Mirrors a screen to a SMART interactive display | pkg | custom | https://support.smarttech.com/docs/software/smart-mirror/en/downloads/mirror-apps/macos-iq3.cshtml |
snapgene | SnapGene | Plans, visualizes, and documents molecular cloning and PCR | dmg | custom | https://www.snapgene.com/ |
soundfield-by-rode | Soundfield By RODE | Ambisonic surround-sound plugin in AU, VST, and AAX formats | pkg | custom | https://rode.com/en-us/software/soundfield-by-rode |
spyder-x-elite | Spyder X Elite | Calibrates displays and projectors for accurate color | pkg | custom | https://spyder-support.datacolor.com/hc/en-us/articles/4403402938514-Spyder-X-Elite-macOS |
spyder-x-pro | Spyder X Pro | Calibrates displays and projectors for accurate color | pkg | custom | https://spyder-support.datacolor.com/hc/en-us/articles/4403402966546-Spyder-X-Pro-macOS |
starface | Starface | Client for unified telephony, chat, and video calls | dmg | custom | https://knowledge.starface.de/pages/viewpage.action?pageId=46564694 |
strongdm | StrongDM | Access proxy for databases, servers, clusters, and clouds | dmg | custom | https://www.strongdm.com |
studio-viewer | Studio Viewer | Views 3D packaging and label designs from Esko workflows | dmg | custom | https://www.esko.com/en/support/free-software |
synology-active-backup-for-business-agent | Synology Active Backup For Business Agent | Agent that backs up endpoints to a Synology NAS | pkg | custom | https://www.synology.com/en-global/dsm/feature/active_backup_business |
synology-drive-client | Synology Drive Client | Syncs and shares files with a Synology NAS | pkg | custom | https://www.synology.com/en-global/dsm/feature/drive |
universal-type-client | Universal Type Client | Font management client for organizing and activating typefaces | pkg | custom | https://www.extensis.com |
usher | Usher | Organizes and plays your local and iTunes video library | dmg | custom | https://manytricks.com/usher/ |
vivi | Vivi | Wireless screen mirroring and display control for classrooms | pkg | direct_header | https://vivi.io | short=https://api.vivi.io/mac;regex=Vivi-(\d+(?:\.\d+)+)\.pkg
windsurf | Windsurf | Agentic IDE with AI code completion, chat, and refactoring | dmg | custom | https://windsurf.com |
wonderpen | WonderPen | Distraction-free editor for long-form writing and notes | dmg | custom | https://www.tominlab.com/en/wonderpen/ |
workbrew | Workbrew | Manages Homebrew deployments across an organization fleet | pkg | custom | https://workbrew.com |
xmlmind | Xmlmind | Editor for DocBook, DITA, XHTML, and other XML documents | dmg | custom | https://www.xmlmind.com/xmleditor/download.shtml |
zaxconvert | Zaxconvert | Converts Zaxcom audio recordings between file formats | zip | custom | https://zaxcom.com/support/downloads/ |

TABLE

# ----------------------------------------------------------------------------
# POLICY-BLOCKED tokens - authored in the REGISTRY above, but a full dry run
# proved `brew audit --strict --online --new` rejects them for reasons NO cask
# edit can fix (NOT-ADDED.md section 2 keeps the human-readable rollup).
# Skipped by default so a full run doesn't burn ~70 download+audit cycles on
# known rejections; each lands in results.tsv as "skipped (policy-blocked)".
# A new upstream release CAN flip a verdict (app gets notarized, repo gains
# stars): re-test with  RUN_BLOCKED=1 [ONLY="tok ..."]  and delete what passes.
# ----------------------------------------------------------------------------
declare -A POLICY_BLOCKED=(
  [1piece]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [air-flow]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [airbattery]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [api-utility]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [backgrounds]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [bartranslate]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [battery-toolkit]="GitHub repo archived; app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [bimcollab-zoom]="Gatekeeper signature invalid ('software has been altered') - vendor bundle fails verification, hard audit reject"
  [blink-eye]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [boring-notch]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [brewmate]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [caesium-image-compressor]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [canister]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [chatkit]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [chromebuddy]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers); app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [close-desktop]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [corelcad]="discontinued (2023); only a fixed unversioned trial dmg, no livecheck source"
  [desktop-icon-manager]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [dictation-daddy]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [dragonframe-2024]="vendor site returns HTTP 406 to every non-browser client - brew homepage/livecheck checks cannot pass"
  [dragonframe-2025]="vendor site returns HTTP 406 to every non-browser client - brew homepage/livecheck checks cannot pass"
  [dragonframe-5]="vendor site returns HTTP 406 to every non-browser client - brew homepage/livecheck checks cannot pass"
  [dropnote]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers); app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [droppoint]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [editready]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [elevate24]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [file-architect]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [fontagent]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [freeter]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [fuzzlecheck-4]="no robot-readable version source (JS-only download page)"
  [hide-icons]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [impulso]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [jamf-actions]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [jamf-cli]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [imymac-pdf-compressor]="vendor 403s all non-browser downloads (imymac.com WAF) - brew cannot fetch; same vendor as PUA-bucketed powermymac"
  [imymac-video-converter]="vendor 403s all non-browser downloads (imymac.com WAF) - brew cannot fetch; same vendor as PUA-bucketed powermymac"
  [jamf-environment-test]="GitHub repo archived"
  [jamf-framework-redeploy]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [jamf-printer-manager]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [jamf-protect-ulf-uploader]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [jamfdash]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [later]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [logoer]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [macuncle-eml-viewer]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [mailvault]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [mindview-9]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [mixpad]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [modalfilemanager]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [monsterwriter]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [mxmarkedit]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers); app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [noteey]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [object-info]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [offshoot]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [onemenu]="no robot-readable version source (JS-only download page)"
  [peazip]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [pixillion]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [print-window]="vendor TLS certificate expired (printwindowapp.com) - brew cannot download; re-test with RUN_BLOCKED=1 once the vendor renews"
  [psso-utility]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [quickrecorder]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [quilt-app]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [sapmachine-manager]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [shokz-connect]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [smotrite]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers); app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [sniffnet]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [squirreldisk]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [station]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [supercorners]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [swiftcord]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [swiftguard]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [sym-helper]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [textream]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [time-machine-inspector]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [tinyweb]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [trace]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [utm-coordinate-converter]="Bitbucket repo not notable enough (<30 forks / <75 watchers) - same policy bar as GitHub"
  [visualz]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [vocal]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [watchflower]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [wudpecker]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  # -- added 2026-06-10 after audit/research proof during the full dry run:
  [appcode]="JetBrains discontinued AppCode (EOL Dec 2023) - new casks for EOL products are rejected"
  [depnotify]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [deskrest]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [huggingchat-mac]="only GitHub pre-releases exist (v0.7.0) - audit --new rejects pre-release-only projects"
  [jamf-compliance-editor]="GitHub repo not notable enough (<75 stars / <30 forks / <30 watchers)"
  [okiocam-snapshot-and-recorder]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [soundfield-by-rode]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
  [horse]="downloads are unversioned redirects to expiring signed URLs on a private GitHub repo - no version-pinned public URL or stable sha256 possible"
  [lucidlink]="v3 client is portal-distributed (app.lucidlink.com) - no public versioned URL; Classic 2.x is covered by lucidlink-classic"
  [nightowl]="removed from homebrew-cask as possible malware (Homebrew/homebrew-cask#149439) - app silently enrolled Macs in a paid proxy network"
  [relagit]="app not signed + Apple-notarized (hard requirement for new homebrew/cask casks)"
)
RUN_BLOCKED="${RUN_BLOCKED:-0}"

# ----------------------------------------------------------------------------
# Environment + flags
# ----------------------------------------------------------------------------
set -uo pipefail
# HOMEBREW_NO_REQUIRE_TAP_TRUST=1: Homebrew 5.1.15+ (Tap Trust, added 2026-05-30)
# refuses to *load* casks from an "untrusted" tap — which now includes a locally
# cloned/forked homebrew/cask — so `brew audit` and `brew livecheck` fail with
# "Refusing to load cask ... from untrusted tap" (while `brew style`, which only
# lints the file, still passes). This keeps the local tap loadable for the run.
# Recommended long-term alternative: `brew trust homebrew/cask` (done below too).
export GIT_PAGER=cat HOMEBREW_NO_INSTALL_FROM_API=1 HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_REQUIRE_TAP_TRUST=1
DRYRUN="${DRYRUN:-0}"; FORK="${FORK:-fork}"; FILE_FR="${FILE_FR:-1}"; CUSTOMER_LABEL="${CUSTOMER_LABEL:-}"
FRESH="${FRESH:-1}"; STRICT="${STRICT:-1}"; ZAP="${ZAP:-1}"
ONLY="${ONLY:-}"; LIMIT="${LIMIT:-}"; STOP_ON_FAIL="${STOP_ON_FAIL:-0}"
JOBS="${JOBS:-4}"; KEEP="${KEEP:-0}"; SKIP_PASSED="${SKIP_PASSED:-0}"; START_AT="${START_AT:-}"
LIVECHECK="${LIVECHECK:-1}"; CHECK="${CHECK:-0}"
AUTHOR_NAME="${AUTHOR_NAME:-AdamBaali}"; AUTHOR_EMAIL="${AUTHOR_EMAIL:-adam@mpc.ad}"
[ "$STRICT" = 1 ] && SFLAG="--strict" || SFLAG=""
if [ "$STRICT" = 1 ]; then AUDIT_DESC="--strict --online --new"; else AUDIT_DESC="--online --new"; fi
if [ "$ZAP" = 1 ]; then TESTED="installed, reinstalled, uninstalled, and zapped"; VERIFIED="the artifact, a clean uninstall, an idempotent reinstall, and the zap stanza paths"; else TESTED="installed and uninstalled"; VERIFIED="the artifact and uninstall"; fi
DISCLOSURE="AI (Claude) assisted in creating this PR: it researched the download URL, version, bundle identifier, minimum macOS, and pkg receipt, and drafted the cask DSL. I reviewed the result, ran brew style --fix and brew audit --cask $AUDIT_DESC with no offenses or errors, and $TESTED the cask locally on macOS to verify $VERIFIED."
ROOT="${CASKWORK:-/tmp/caskwork}"; mkdir -p "$ROOT"
MASTER="$ROOT/MASTER-summary.md"; RESULTS="$ROOT/results.tsv"

trim(){ local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# Every download/scrape goes through curl; bounded retries so one transient
# network blip doesn't fail an app (HTTP 4xx aren't retried; -f still fails them).
# NOTE: deliberately NO default User-Agent spoof — what our resolvers see must match
# what brew's own (non-browser) curl sees at audit/livecheck time. Vendors that block
# robots get POLICY_BLOCKED instead (dragonframe). Some WAFs even invert: cisco.com
# 403s browser UAs but serves plain curl — a global -A breaks more than it fixes.
curl(){ command curl --connect-timeout 20 --retry 3 "$@"; }

# ----------------------------------------------------------------------------
# CHECK=1 — registry vs data/master-list.csv drift report (no brew/gh needed).
# Informational: tokens renamed in the CSV bucket text ("token goto-desktop")
# are matched; anything else listed is drift (or a deliberate multi-version
# variant like dragonframe-2024/2025) — eyeball it and fix whichever side is stale.
# ----------------------------------------------------------------------------
if [ "$CHECK" = 1 ]; then
  CSV="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/data/master-list.csv"
  [ -f "$CSV" ] || { echo "CHECK: $CSV not found (run from the repo checkout)"; exit 1; }
  RT="$(mktemp)"; CT="$(mktemp)"
  while IFS= read -r _l; do
    case "$(trim "$_l")" in ""|\#*) continue;; esac
    IFS='|' read -r _t _rest <<< "$_l"; printf '%s\n' "$(trim "$_t")"
  done <<< "$REGISTRY" | sort -u > "$RT"
  # quoted CSV fields may contain commas (curl one-liners in version_method), so a
  # naive awk -F',' shifts the bucket out of $15 for those rows (dragonframe-2024/2025,
  # lucidlink, poll-everywhere showed as false drift). Parse the CSV properly and emit
  # "slug<TAB>bucket" for in-registry rows.
  FL="$(mktemp)"
  perl -ne 'next if $. == 1; chomp;
    my @f; while (/\G("(?:[^"]|"")*"|[^,]*)(,|$)/g) { push @f, $1; last if $2 eq "" }
    my $b = $f[14] // ""; $b =~ s/^"//;
    print "$f[0]\t$b\n" if $b =~ /^in-registry/;' "$CSV" > "$FL"
  # a bucket like "in-registry (token goto-meeting)" means the slug was renamed:
  # count the renamed token, not the original slug
  { awk -F'\t' '$2 !~ /token / {print $1}' "$FL"; grep -oE 'token [a-z0-9@.+-]+' "$FL" | awk '{print $2}'; } \
    | sort -u > "$CT"; rm -f "$FL"
  echo "Registry tokens: $(wc -l < "$RT" | tr -d ' ')   CSV in-registry slugs (incl. renames): $(wc -l < "$CT" | tr -d ' ')"
  echo; echo "-- in REGISTRY but not in-registry in the CSV:"
  comm -23 "$RT" "$CT" | sed 's/^/   /' || true
  echo; echo "-- in-registry in the CSV but missing from the REGISTRY:"
  comm -13 "$RT" "$CT" | sed 's/^/   /' || true
  rm -f "$RT" "$CT"; exit 0
fi

# ----------------------------------------------------------------------------
# Prerequisites (checked once)
# ----------------------------------------------------------------------------
TAP="$(brew --repository homebrew/cask 2>/dev/null)" || { echo "ERROR: Homebrew not found"; exit 1; }
[ -d "$TAP" ] || { echo "ERROR: homebrew-cask tap not found at $TAP"; exit 1; }
# Tap Trust (Homebrew 5.1.15+): mark the official cask tap trusted once so `brew
# audit`/`brew livecheck` will load casks from this local clone. The env export
# above is the guaranteed fallback; this is the recommended path and is a silent
# no-op on older brew (and harmless if already trusted).
brew trust homebrew/cask </dev/null >/dev/null 2>&1 || true
# Author the cask commits as you, scoped to THIS tap only (your global git
# config is untouched). Override with AUTHOR_NAME / AUTHOR_EMAIL.
git -C "$TAP" config user.name  "$AUTHOR_NAME"  >/dev/null 2>&1 || true
git -C "$TAP" config user.email "$AUTHOR_EMAIL" >/dev/null 2>&1 || true
DEF="$(git -C "$TAP" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@.*/@@')"; [ -z "$DEF" ] && DEF=master
command -v gh >/dev/null 2>&1 || { echo "ERROR: install gh: brew install gh"; exit 1; }
if [ "$DRYRUN" != 1 ]; then
  gh auth status >/dev/null 2>&1 || { echo "ERROR: run: gh auth login"; exit 1; }
fi
if [ -z "${FORK_OWNER:-}" ]; then
  FORK_OWNER="$(git -C "$TAP" remote get-url "$FORK" 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+)/.*#\1#')"
  [ -n "$FORK_OWNER" ] || FORK_OWNER="AdamBaali"
fi
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
  MINOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$1/Contents/Info.plist" 2>/dev/null || echo 11)"
  # Intel-only artifact => audit requires `caveats { requires_rosetta }` on Apple silicon.
  local exe bin archs
  exe="$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$1/Contents/Info.plist" 2>/dev/null)"
  bin="$1/Contents/MacOS/$exe"
  if [ -n "$exe" ] && [ -f "$bin" ]; then
    archs="$(lipo -archs "$bin" 2>/dev/null || file "$bin")"
    case "$archs" in
      *arm64*)         NEEDS_ROSETTA=0 ;;   # universal or arm-native
      *x86_64*|*i386*) NEEDS_ROSETTA=1 ;;   # Intel-only
    esac
  fi; }

inspect(){ RECEIPT=""; LABELS=""; MAU=""; NEEDS_ROSETTA=0
  case "$ARTIFACT" in
    zip) rm -rf "$W/x"; mkdir "$W/x"; ditto -xk "$DL" "$W/x"; read_app "$(find "$W/x" -maxdepth 3 -name '*.app' | head -1)";;
    dmg) hdiutil detach /tmp/ck-vol >/dev/null 2>&1 || true
         # `yes |` auto-accepts any embedded software license agreement (SLA) so a
         # licensed dmg (e.g. AKVIS) mounts unattended instead of prompting "Agree Y/N?".
         # (`brew install` already auto-agrees; this is only for our own inspect mount.)
         yes | hdiutil attach "$DL" -nobrowse -noverify -noautoopen -mountpoint /tmp/ck-vol >/dev/null 2>&1 || true
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
  if printf '%s' "$a" | grep -qiE 'verified.*(redundant|not needed|should be removed|do not need|unnecessary)'; then
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
# registrable domain (last two dot-labels): static.culturedcode.com -> culturedcode.com.
# Homebrew only wants a `verified:` when the URL's registrable domain differs from the
# homepage's; a download host that's a subdomain of the homepage domain must NOT add it.
reg_dom(){ printf '%s' "$1" | awk -F. '{if(NF>=2)print $(NF-1)"."$NF; else print $0}'; }

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
    # Mirror Homebrew livecheck (PageMatch): collect EVERY match (capture group 1
    # if the regex defines one, else the whole match) and keep the version-max,
    # exactly like livecheck does. First-match broke on pages that list oldest
    # first (mestrelab) and on stray numbers (aws changelog "p6-b300.48xlarge").
    # The XML/RSS prologue is stripped first: a generic vregex on a Sparkle
    # appcast otherwise matches `<?xml version="1.0"` / `<rss version="2.0">`
    # and resolves a bogus "1.0" (grammarly, cakebrew).
    v="$(curl -fsSL "${SP[vers]}" | VRE="${SP[vregex]}" perl -ne '
           s/<\?xml[^>]*\?>//g; s/<rss[^>]*>//g;
           while (/$ENV{VRE}/gi) { print((defined $1 ? $1 : $&), "\n") }
         ' | sort -uV | tail -1)"
    [ -n "$v" ] || die "direct: vregex matched nothing at ${SP[vers]}"
  else die "direct: provide version= or vers=+vregex="; fi
  VERSION="$v"; URL="$(sub_dl "${SP[url]}")"; curl -fL "$URL" -o "$DL"; }

# arch-split GitHub release: two assets (arm + intel), dmg/zip only. {v}=version in
# asset names; on_arm/on_intel carry the per-arch sha+url; livecheck = :github_latest.
_resolve_github_arch(){
  get_github_tag "${SP[repo]}"; [ -n "$TAG" ] || die "github_arch: no latest tag for ${SP[repo]}"
  case "$TAG" in [vV][0-9]*) VERSION="${TAG#?}";; *) VERSION="$TAG";; esac
  local VI='#{version}'; TAGI="${TAG/$VERSION/$VI}"
  URL="https://github.com/${SP[repo]}/releases/download/$TAG/$(sub_dl "${SP[arm]}")"
  curl -fL "$URL" -o "$DL"
  curl -fL "https://github.com/${SP[repo]}/releases/download/$TAG/$(sub_dl "${SP[intel]}")" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "github_arch: intel asset download failed"; }

write_github_arch(){
  local repo="${SP[repo]}" zapblock="" armurl intelurl
  case "$ARTIFACT" in zip|dmg) : ;; *) die "github_arch writer: only zip/dmg supported (got '$ARTIFACT')";; esac
  armurl="https://github.com/$repo/releases/download/$TAGI/$(sub_cask "${SP[arm]}")"
  intelurl="https://github.com/$repo/releases/download/$TAGI/$(sub_cask "${SP[intel]}")"
  [ -n "$BUNDLE_ID" ] && zapblock="
$(zap_for "$BUNDLE_ID")"
  cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 "$SHA"
    url "$armurl"
  end
  on_intel do
    sha256 "$SHA_X64"
    url "$intelurl"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$zapblock
end
RB
}

# unversioned "latest" download: version :latest + sha256 :no_check. Homebrew discourages this for
# new casks (no upstream version to track) — used only where the vendor offers no versioned URL.
_resolve_direct_latest(){ VERSION="latest"; URL="$(sub_dl "${SP[url]}")"; curl -fL "$URL" -o "$DL"; }
write_direct_latest(){
  local url_cask="${SP[url]}" verified="" hp_host dl_host zapblock="" uninstall=""
  hp_host="$(printf '%s' "$HOMEPAGE" | sed -E 's#^https?://([^/]+).*#\1#')"
  dl_host="$(printf '%s' "$url_cask" | sed -E 's#^https?://([^/]+).*#\1#')"
  [ "$(reg_dom "$hp_host")" != "$(reg_dom "$dl_host")" ] && verified=",
      verified: \"${dl_host#www.}/\""
  [ -n "$BUNDLE_ID" ] && zapblock="
$(zap_for "$BUNDLE_ID")"
  case "$ARTIFACT" in
    pkg)
      if [ -n "$LABELS" ]; then local arr; arr="$(printf '"%s", ' $LABELS | sed 's/, $//')"
        uninstall="uninstall launchctl: [$arr],
            pkgutil:   \"$RECEIPT\""
      else uninstall="uninstall pkgutil: \"$RECEIPT\""; fi
      cat > "$CASK" <<RB
cask "$TOKEN" do
  version :latest
  sha256 :no_check

  url "$url_cask"$verified
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

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
  version :latest
  sha256 :no_check

  url "$url_cask"$verified
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  depends_on macos: :$SYM

  app "$APP_NAME"
$zapblock
end
RB
    ;;
    *) die "direct_latest writer: unsupported artifact '$ARTIFACT'";;
  esac; }

# arch-split direct download (two URLs). Versioned via vers/vregex (or version=), else :latest.
_resolve_direct_arch(){
  if [ -n "${SP[version]:-}" ]; then VERSION="${SP[version]}"
  elif [ -n "${SP[vers]:-}" ]; then
    # same matching rules as _resolve_direct: version-MAX over every match,
    # XML/RSS prologue stripped (mirrors brew livecheck's PageMatch behavior)
    VERSION="$(curl -fsSL "${SP[vers]}" | VRE="${SP[vregex]}" perl -ne '
           s/<\?xml[^>]*\?>//g; s/<rss[^>]*>//g;
           while (/$ENV{VRE}/gi) { print((defined $1 ? $1 : $&), "\n") }
         ' | sort -uV | tail -1)"
    [ -n "$VERSION" ] || die "direct_arch: vregex matched nothing at ${SP[vers]}"
  else VERSION="latest"; fi
  URL="$(sub_dl "${SP[arm]}")"; curl -fL "$URL" -o "$DL"
  curl -fL "$(sub_dl "${SP[intel]}")" -o "$W/dl-x64" && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "direct_arch: intel download failed"; }
write_direct_arch(){
  local armurl intelurl zapblock="" verified="" hp_host dl_host verline armsha intelsha lc=""
  armurl="$(sub_cask "${SP[arm]}")"; intelurl="$(sub_cask "${SP[intel]}")"
  hp_host="$(printf '%s' "$HOMEPAGE" | sed -E 's#^https?://([^/]+).*#\1#')"
  dl_host="$(printf '%s' "$armurl" | sed -E 's#^https?://([^/]+).*#\1#')"
  [ "$(reg_dom "$hp_host")" != "$(reg_dom "$dl_host")" ] && verified=",
        verified: \"${dl_host#www.}/\""
  if [ "$VERSION" = latest ]; then verline="version :latest"; armsha="sha256 :no_check"; intelsha="sha256 :no_check"
  else verline="version \"$VERSION\""; armsha="sha256 \"$SHA\""; intelsha="sha256 \"$SHA_X64\""
    # unversioned templates (no #{version}) serve a changing file: audit requires
    # `sha256 :no_check` even with a pinned version + livecheck (flashpeak-slimjet)
    case "$armurl$intelurl" in *'#{version}'*) ;; *) armsha="sha256 :no_check"; intelsha="sha256 :no_check";; esac
    [ -n "${SP[vers]:-}" ] && lc="
  livecheck do
    url \"${SP[vers]}\"
    regex(/${SP[vregex]}/i)
    strategy :page_match
  end"
  fi
  [ -n "$BUNDLE_ID" ] && zapblock="
$(zap_for "$BUNDLE_ID")"
  case "$ARTIFACT" in zip|dmg) : ;; *) die "direct_arch writer: only zip/dmg (got '$ARTIFACT')";; esac
  cat > "$CASK" <<RB
cask "$TOKEN" do
  $verline

  on_arm do
    $armsha
    url "$armurl"$verified
  end
  on_intel do
    $intelsha
    url "$intelurl"$verified
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"$lc

  depends_on macos: :$SYM

  app "$APP_NAME"
$zapblock
end
RB
}

resolve(){
  if declare -F "resolve_$TFN" >/dev/null; then "resolve_$TFN"; return $?; fi
  case "$SOURCE" in
    github_tag)      _resolve_github_tag;;
    github_arch)     _resolve_github_arch;;
    github_compound) _resolve_github_compound;;
    electron)        _resolve_electron;;
    msft_cdn)        _resolve_msft;;
    direct)          _resolve_direct;;
    direct_latest)   _resolve_direct_latest;;
    direct_arch)     _resolve_direct_arch;;
    direct_header)   _resolve_direct_header;;
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
  elif [ -n "${SP[lcregex]:-}" ]; then
    # Custom tag regex (e.g. beta/build suffix the default github_latest regex drops).
    lc="livecheck do
    url :url
    regex(/${SP[lcregex]}/i)
    strategy :github_latest do |json, regex|
      match = json[\"tag_name\"]&.match(regex)
      next if match.blank?

      match[1]
    end
  end"
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
  local base="${SP[feed]%/*}" lc quit="" zapblock="" verified="" bhost hphost
  # electron feeds often live on an S3/CDN host distinct from the homepage -> needs verified.
  bhost="$(printf '%s' "$base" | sed -E 's#^https?://([^/]+).*#\1#')"
  hphost="$(printf '%s' "$HOMEPAGE" | sed -E 's#^https?://([^/]+).*#\1#')"
  [ "$(reg_dom "$bhost")" != "$(reg_dom "$hphost")" ] && verified=",
      verified: \"${bhost#www.}/\""
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

  url "$base/$fn.dmg"$verified
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
    url "$base/$farm.dmg"$verified
  end
  on_intel do
    sha256 "$SHA_X64"
    url "$base/$fintel.dmg"$verified
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

# Generic header/redirect download (version lives in the redirect target filename or a
# Content-Disposition header, not in a page) — like msft_cdn but for any host and any artifact.
# spec: short=<url that redirects to the versioned file> ; regex=<filename regex, version captured>
_resolve_direct_header(){
  local short="${SP[short]}" real="" base loc
  base="$(printf '%s' "$short" | sed -E 's#^(https?://[^/]+).*#\1#')"
  # Walk every redirect hop and keep the FIRST whose filename carries a version:
  # vendors often bounce versioned-URL -> opaque CDN/id URL (particulars.app ->
  # gitlab package_files), and only the early hop is livecheck-bumpable. Relative
  # Locations (astropad) are resolved against the short URL's host.
  while IFS= read -r loc; do
    case "$loc" in http://*|https://*) ;; /*) loc="$base$loc";; *) continue;; esac
    if basename "${loc%%\?*}" | grep -qE '[0-9]+(\.[0-9]+)+'; then real="$loc"; break; fi
  done < <(curl -sIL "$short" | awk -F': ' 'tolower($1)=="location"{print $2}' | tr -d '\r')
  # fallback: the final URL after all redirects (%{url_effective} is always absolute)
  [ -n "$real" ] || real="$(curl -sIL -o /dev/null -w '%{url_effective}' "$short" 2>/dev/null)"
  [ -n "$real" ] || real="$short"
  VERSION="$(basename "${real%%\?*}" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || VERSION="$(curl -sIL "$short" | grep -i '^content-disposition' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "direct_header: no version from $short"
  DH_URLT="$(printf '%s' "$real" | sed "s/${VERSION//./\\.}/#{version}/")"
  URL="$real"; curl -fL "$URL" -o "$DL"; }
write_direct_header(){
  local host lc uninstall zapblock="" verified="" hp_host
  host="$(printf '%s' "$DH_URLT" | sed -E 's#https?://([^/]+)/.*#\1#')"
  # same rule as write_direct: `verified:` ONLY when the registrable domain
  # differs from the homepage's (downloads.astropad.com == astropad.com -> none)
  hp_host="$(printf '%s' "$HOMEPAGE" | sed -E 's#^https?://([^/]+).*#\1#')"
  [ "$(reg_dom "$hp_host")" != "$(reg_dom "$host")" ] && verified=",
      verified: \"${host#www.}/\""
  lc="livecheck do
    url \"${SP[short]}\"
    regex(/${SP[regex]}/i)
    strategy :header_match
  end"
  [ -n "$BUNDLE_ID" ] && zapblock="
$(zap_for "$BUNDLE_ID")"
  case "$ARTIFACT" in
    pkg)
      if [ -n "$LABELS" ]; then local arr; arr="$(printf '"%s", ' $LABELS | sed 's/, $//')"
        uninstall="uninstall launchctl: [$arr],
            pkgutil:   \"$RECEIPT\""
      else uninstall="uninstall pkgutil: \"$RECEIPT\""; fi
      cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "$DH_URLT"$verified
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

  url "$DH_URLT"$verified
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
    *) die "direct_header writer: unsupported artifact '$ARTIFACT'";;
  esac; }

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
  local url_cask verified="" lc hp_host dl_host zapblock="" shaline
  url_cask="$(sub_cask "${SP[url]}")"
  # Unversioned URL (no #{version} interpolation) => audit requires sha256 :no_check.
  case "$url_cask" in *'#{version}'*) shaline="sha256 \"$SHA\"";; *) shaline="sha256 :no_check";; esac
  hp_host="$(printf '%s' "$HOMEPAGE" | sed -E 's#^https?://([^/]+).*#\1#')"
  dl_host="$(printf '%s' "$url_cask" | sed -E 's#^https?://([^/]+).*#\1#')"
  [ "$(reg_dom "$hp_host")" != "$(reg_dom "$dl_host")" ] && verified=",
      verified: \"${dl_host#www.}/\""
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
  $shaline

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
  $shaline

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

# If artifact inspection found an Intel-only binary, add the required Rosetta caveat.
# Inserts before the cask's closing top-level `end` (after zap), matching brew style order.
inject_rosetta(){
  [ "${NEEDS_ROSETTA:-0}" = 1 ] || return 0
  grep -q 'requires_rosetta' "$CASK" 2>/dev/null && return 0
  perl -i -0pe 's/\nend\n\z/\n\n  caveats do\n    requires_rosetta\n  end\nend\n/' "$CASK"
}

write_cask(){
  if declare -F "write_cask_$TFN" >/dev/null; then "write_cask_$TFN"; return $?; fi
  case "$SOURCE" in
    github_tag|github_compound) write_github;;
    github_arch) write_github_arch;;
    electron) write_electron;;
    msft_cdn) write_msft;;
    direct)   write_direct;;
    direct_latest) write_direct_latest;;
    direct_arch) write_direct_arch;;
    direct_header) write_direct_header;;
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
# ===== Custom per-app resolvers (auto-generated from the custom-conversion run) =====
# resolve_<tfn> / write_cask_<tfn> for source=custom apps. Verify on a Mac with DRYRUN.

#!/usr/bin/env bash
###############################################################################
# funcs-cc-chunk1.sh — custom resolve_/write_cask_ pairs for cc-chunk1 apps
# that no built-in cask-master.sh SOURCE could express.
#
# Sourced by scripts/cask-master.sh (which defines $DL, $W, $CASK, $TOKEN,
# $NAME, $DESC, $HOMEPAGE, $ARTIFACT and — after resolve+inspect — $VERSION,
# $SHA, $SHA_X64, $APP_NAME, $RECEIPT, $BUNDLE_ID, $SYM, die(), shasum, etc.).
# Each resolve_<tfn> sets VERSION + URL and downloads to "$DL"; arch-split also
# downloads the intel file to "$W/dl-x64" and sets SHA_X64. Each write_cask_<tfn>
# writes the cask to "$CASK". <tfn> = token with every '-' replaced by '_'.
###############################################################################

# ---------------------------------------------------------------------------
# barcode-studio — arch-split, nested .pkg.zip, different min-macOS per arch,
# build-stamped filename. arm64 = macOS 12+, intel = macOS 11+. (TEC-IT)
# ---------------------------------------------------------------------------
resolve_barcode_studio(){
  VERSION="17.2.0.32089"
  URL="https://www.tec-it.com/download/Unix/Mac-OS/bcstudio-${VERSION}-mac-12.0-arm64.pkg.zip"
  curl -fL "$URL" -o "$DL"
  curl -fL "https://www.tec-it.com/download/Unix/Mac-OS/bcstudio-${VERSION}-mac-11.0.pkg.zip" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "barcode-studio: intel download failed"
}
write_cask_barcode_studio(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 "$SHA"
    url "https://www.tec-it.com/download/Unix/Mac-OS/bcstudio-#{version}-mac-12.0-arm64.pkg.zip"

    depends_on macos: :monterey
  end
  on_intel do
    sha256 "$SHA_X64"
    url "https://www.tec-it.com/download/Unix/Mac-OS/bcstudio-#{version}-mac-11.0.pkg.zip"

    depends_on macos: :big_sur
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.tec-it.com/en/download/barcode-studio/mac-os-x"
    regex(%r{bcstudio[._-]v?(\d+(?:\.\d+)+)[._-]mac}i)
    strategy :page_match
  end

  pkg "BarcodeStudioInstaller.pkg"

  uninstall pkgutil: "com.tec-it.bcstudio"

  zap trash: [
    "~/Library/Caches/com.tec-it.bcstudio",
    "~/Library/Preferences/com.tec-it.bcstudio.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# bimcollab-zoom — dmg behind a redirect; filename has spaces and a compound
# "<major.minor> build <n>" version. version.csv "9.8,14".
# ---------------------------------------------------------------------------
resolve_bimcollab_zoom(){
  local real
  real="$(curl -sIL "https://bimcollab.com/download/ZOOM/MAC" | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  [ -n "$real" ] || die "bimcollab-zoom: no redirect from download page"
  local fn vers build
  fn="$(basename "${real%%\?*}" | python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))' 2>/dev/null || basename "${real%%\?*}")"
  vers="$(printf '%s' "$fn" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  build="$(printf '%s' "$fn" | grep -oiE 'build[ ._-]?[0-9]+' | grep -oE '[0-9]+' | head -1)"
  [ -n "$vers" ] && [ -n "$build" ] || die "bimcollab-zoom: could not parse version/build from $fn"
  VERSION="$vers,$build"
  URL="$real"; curl -fL "$URL" -o "$DL"
}
write_cask_bimcollab_zoom(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://download.bimcollab.com/BIMcollab%20Zoom%20#{version.csv.first}%20build%20#{version.csv.second}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://bimcollab.com/download/ZOOM/MAC"
    regex(%r{BIMcollab[%20A-Za-z]+(\d+(?:\.\d+)+)[%20A-Za-z]*build[%20]*(\d+)\.dmg}i)
    strategy :header_match do |headers, regex|
      next if headers["location"].blank?

      match = headers["location"].match(regex)
      next if match.blank?

      "#{match[1]},#{match[2]}"
    end
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# buhocleaner — dmg filename embeds the BUILD (b256), marketing version comes
# from the Sparkle appcast. version.csv "1.16.2,256". (Dr. Buho)
# ---------------------------------------------------------------------------
resolve_buhocleaner(){
  local feed="https://drbuho.net/buhocleaner/appcast.xml" xml short build
  xml="$(curl -fsSL "$feed")" || die "buhocleaner: appcast fetch failed"
  short="$(printf '%s' "$xml" | grep -oE 'sparkle:shortVersionString="[^"]*"' | head -1 | grep -oE '[0-9]+(\.[0-9]+)+')"
  build="$(printf '%s' "$xml" | grep -oE 'sparkle:version="[0-9]+"' | head -1 | grep -oE '[0-9]+')"
  [ -n "$short" ] && [ -n "$build" ] || die "buhocleaner: could not read version/build from appcast"
  VERSION="$short,$build"
  URL="https://drbuho.net/buhocleaner/buhocleaner_b${build}.dmg"; curl -fL "$URL" -o "$DL"
}
write_cask_buhocleaner(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://drbuho.net/buhocleaner/buhocleaner_b#{version.csv.second}.dmg",
      verified: "drbuho.net/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://drbuho.net/buhocleaner/appcast.xml"
    strategy :sparkle do |item|
      "#{item.short_version},#{item.version}"
    end
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# capture-one — versioned dmg, but the download URL carries a per-release hash
# path segment (/d/mac/<hash>/) that is not derivable from the version.
# Resolve the current enclosure from the Sparkle feed.
# ---------------------------------------------------------------------------
resolve_capture_one(){
  local feed="https://www.captureone.com/update/capture-one-mac.xml" xml
  xml="$(curl -fsSL "$feed")" || die "capture-one: appcast fetch failed"
  URL="$(printf '%s' "$xml" | grep -oE 'url="https://downloads\.captureone\.pro/d/mac/[^"]*CaptureOne\.Mac\.[^"]*\.dmg"' | head -1 | sed -E 's/^url="//; s/"$//')"
  [ -n "$URL" ] || die "capture-one: no dmg enclosure in appcast"
  VERSION="$(basename "$URL" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "capture-one: could not parse version from $URL"
  curl -fL "$URL" -o "$DL"
}
write_cask_capture_one(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://downloads.captureone.pro/d/mac/5b34e26779686357603e50d52e700a0b4b946199/CaptureOne.Mac.#{version}.dmg",
      verified: "downloads.captureone.pro/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.captureone.com/update/capture-one-mac.xml"
    strategy :sparkle
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# cato-client — pkg; version lives in a 301 redirect Location PATH segment
# (not the filename, which is always CatoClient.pkg). header_match livecheck.
# ---------------------------------------------------------------------------
resolve_cato_client(){
  local alias="https://clientdownload.catonetworks.com/public/clients/CatoClient.pkg" real
  real="$(curl -sIL "$alias" | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  [ -n "$real" ] || die "cato-client: no redirect from $alias"
  VERSION="$(printf '%s' "$real" | grep -oE '/[0-9]+(\.[0-9]+)+/' | head -1 | tr -d /)"
  [ -n "$VERSION" ] || die "cato-client: could not parse version from $real"
  URL="$real"; curl -fL "$URL" -o "$DL"
}
write_cask_cato_client(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://clients.catonetworks.com/macos/#{version}/CatoClient.pkg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://clientdownload.catonetworks.com/public/clients/CatoClient.pkg"
    regex(%r{/macos/(\d+(?:\.\d+)+)/CatoClient\.pkg}i)
    strategy :header_match
  end

  pkg "CatoClient.pkg"

  uninstall pkgutil: "$RECEIPT"

  zap trash: [
    "~/Library/Caches/$BUNDLE_ID",
    "~/Library/Preferences/$BUNDLE_ID.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# cloudya — appInDmgInZip: the .zip holds a .dmg that holds the .app. The
# harness inspector cannot unwrap a dmg-in-zip, so resolve/write by hand.
# URL is versioned (cloudya-<v>-mac.zip). (NFON)
# ---------------------------------------------------------------------------
resolve_cloudya(){
  VERSION="2.2.0"
  URL="https://cdn.cloudya.com/cloudya-${VERSION}-mac.zip"; curl -fL "$URL" -o "$DL"
}
write_cask_cloudya(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://cdn.cloudya.com/cloudya-#{version}-mac.zip",
      verified: "cdn.cloudya.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    regex(/cloudya[._-]v?(\d+(?:\.\d+)+)[._-]mac\.zip/i)
    strategy :page_match
  end

  container nested: "cloudya-#{version}.dmg"

  depends_on macos: :$SYM

  app "Cloudya.app"

  zap trash: [
    "~/Library/Application Support/Cloudya",
    "~/Library/Caches/com.nfon.cloudya",
    "~/Library/Preferences/com.nfon.cloudya.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# code42 — pkgInDmg, x86_64-only build. The latest-mac.dmg alias 302-redirects
# to a dmg whose filename embeds non-derivable build tokens; resolve via that
# redirect (relative Location -> prepend host).
# ---------------------------------------------------------------------------
resolve_code42(){
  local alias="https://download-preservation.code42.com/installs/agent/latest-mac.dmg" loc
  loc="$(curl -sIL "$alias" | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  [ -n "$loc" ] || die "code42: no redirect from $alias"
  case "$loc" in http*) URL="$loc";; /*) URL="https://download-preservation.code42.com$loc";; *) URL="https://download-preservation.code42.com/installs/agent/$loc";; esac
  VERSION="$(printf '%s' "$URL" | grep -oE '/cloud/[0-9]+(\.[0-9]+)+/' | head -1 | grep -oE '[0-9]+(\.[0-9]+)+')"
  [ -n "$VERSION" ] || die "code42: could not parse version from $URL"
  curl -fL "$URL" -o "$DL"
}
write_cask_code42(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://download-preservation.code42.com/installs/agent/cloud/#{version}/33/install/Code42_#{version}_15252000061260_33_Mac-x86-64.dmg",
      verified: "download-preservation.code42.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://download-preservation.code42.com/installs/agent/latest-mac.dmg"
    regex(%r{/cloud/(\d+(?:\.\d+)+)/}i)
    strategy :header_match
  end

  depends_on arch: :x86_64
  depends_on macos: :$SYM

  pkg "Install Code42.pkg"

  uninstall pkgutil: "$RECEIPT"

  zap trash: [
    "~/Library/Caches/$BUNDLE_ID",
    "~/Library/Preferences/$BUNDLE_ID.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# comic-life-4 — zip; download URL embeds a year + marketing version + build
# (/download/<year>/<ver>/ComicLife-Release-<ver>-<build>.zip). The live file
# serves 4.2 build 521. version.csv "4.2,521". (plasq)
# ---------------------------------------------------------------------------
resolve_comic_life_4(){
  local alias="https://plasq.com/downloads/comiclife4-mac" real fn ver build
  real="$(curl -sIL "$alias" | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  [ -n "$real" ] || real="$alias"
  fn="$(basename "${real%%\?*}")"
  ver="$(printf '%s' "$fn" | grep -oE 'Release-[0-9]+(\.[0-9]+)+' | head -1 | grep -oE '[0-9]+(\.[0-9]+)+')"
  build="$(printf '%s' "$fn" | grep -oE -- '-[0-9]+\.zip$' | grep -oE '[0-9]+')"
  [ -n "$ver" ] && [ -n "$build" ] || die "comic-life-4: could not parse version/build from $fn"
  VERSION="$ver,$build"
  URL="$real"; curl -fL "$URL" -o "$DL"
}
write_cask_comic_life_4(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://plasq.com/download/2026/#{version.csv.first}/ComicLife-Release-#{version.csv.first}-#{version.csv.second}.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://plasq.com/downloads/comiclife4-mac"
    regex(%r{ComicLife-Release-(\d+(?:\.\d+)+)-(\d+)\.zip}i)
    strategy :header_match do |headers, regex|
      next if headers["location"].blank?

      match = headers["location"].match(regex)
      next if match.blank?

      "#{match[1]},#{match[2]}"
    end
  end

  depends_on macos: :$SYM

  app "Comic Life 4.app"

  zap trash: [
    "~/Library/Caches/com.plasq.comiclife4",
    "~/Library/Preferences/com.plasq.comiclife4.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# conniepad — dmg; filename has a space + a parenthesized build and a
# cache-buster query, so there is no clean {v} template. page_match livecheck.
# ---------------------------------------------------------------------------
resolve_conniepad(){
  local page href
  page="$(curl -fsSL "https://conniepad.com/")" || die "conniepad: homepage fetch failed"
  href="$(printf '%s' "$page" | grep -oE 'https://release-bucket\.confibuy\.au/conniepad/[^"'"'"' ]+\.dmg' | head -1)"
  [ -n "$href" ] || die "conniepad: no dmg href on homepage"
  VERSION="$(printf '%s' "$href" | python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))' 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "conniepad: could not parse version from $href"
  URL="$href"; curl -fL "$URL" -o "$DL"
}
write_cask_conniepad(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://release-bucket.confibuy.au/conniepad/ConniePad%20#{version}%20(692).dmg",
      verified: "release-bucket.confibuy.au/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://conniepad.com/"
    regex(%r{ConniePad[%20\s]+(\d+(?:\.\d+)+)[%20\s]}i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# cricut-design-space — dmg behind a time-limited SIGNED CloudFront URL that
# cannot be templated. Resolve version from the Cricut update JSON, then fetch
# a fresh signed installer URL from the desktopdownload API.
# ---------------------------------------------------------------------------
resolve_cricut_design_space(){
  VERSION="$(curl -fsSL 'https://apis.cricut.com/desktopdownload/UpdateJson?operatingSystem=osxnative&shard=a' 2>/dev/null \
    | grep -oE '"rolloutVersion"[: ]*"[0-9.]+"' | head -1 | grep -oE '[0-9]+(\.[0-9]+)+')"
  [ -n "$VERSION" ] || die "cricut: could not read rolloutVersion"
  local signed
  signed="$(curl -fsSL "https://apis.cricut.com/desktopdownload/InstallerFile?operatingSystem=osxnative&shard=a&fileName=CricutDesignSpace-Install-v${VERSION}.dmg" 2>/dev/null \
    | grep -oE 'https://[^"]*CricutDesignSpace-Install\.dmg[^"]*' | head -1)"
  [ -n "$signed" ] || signed="$(curl -sIL 'https://apis.cricut.com/desktopdownload/InstallerFile?operatingSystem=osxnative&shard=a' | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  [ -n "$signed" ] || die "cricut: could not obtain signed installer URL"
  URL="$signed"; curl -fL "$URL" -o "$DL"
}
write_cask_cricut_design_space(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://apis.cricut.com/desktopdownload/InstallerFile?operatingSystem=osxnative&shard=a&fileName=CricutDesignSpace-Install-v#{version}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://apis.cricut.com/desktopdownload/UpdateJson?operatingSystem=osxnative&shard=a"
    regex(/"rolloutVersion"[: ]*"(\d+(?:\.\d+)+)"/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# daylite — zip; the Sparkle enclosure URL embeds a build + date stamp
# (.b20819.2026-05-26-0955) that is not derivable from the version. Resolve the
# current enclosure straight from the appcast. (Marketcircle)
# ---------------------------------------------------------------------------
resolve_daylite(){
  local feed="https://www.daylite.app/appcasts/daylite.xml" xml
  xml="$(curl -fsSL "$feed")" || die "daylite: appcast fetch failed"
  URL="$(printf '%s' "$xml" | grep -oE 'url="https://www\.daylite\.app/appcasts/releases/[^"]*\.zip"' | head -1 | sed -E 's/^url="//; s/"$//')"
  [ -n "$URL" ] || die "daylite: no zip enclosure in appcast"
  VERSION="$(printf '%s' "$xml" | grep -oE 'sparkle:shortVersionString="[^"]*"' | head -1 | grep -oE '[0-9]+(\.[0-9]+)+')"
  [ -n "$VERSION" ] || VERSION="$(basename "$URL" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [ -n "$VERSION" ] || die "daylite: could not parse version"
  curl -fL "$URL" -o "$DL"
}
write_cask_daylite(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://www.marketcircle.com/downloads/latest-daylite"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.daylite.app/appcasts/daylite.xml"
    strategy :sparkle, &:short_version
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# delighted — zip on a WordPress uploads path with a date folder and a
# condensed version token ("delighted25" = 2.5); not templatable from version.
# page_match the downloads page for the current href. (Eclectic Light Co.)
# ---------------------------------------------------------------------------
resolve_delighted(){
  local page href
  page="$(curl -fsSL "https://eclecticlight.co/downloads/")" || die "delighted: downloads page fetch failed"
  href="$(printf '%s' "$page" | grep -oE 'https://eclecticlight\.co/wp-content/uploads/[0-9]{4}/[0-9]{2}/delighted[0-9]+\.zip' | head -1)"
  [ -n "$href" ] || die "delighted: no delighted zip href on downloads page"
  local tok
  tok="$(basename "$href" .zip | grep -oE '[0-9]+$')"
  [ -n "$tok" ] || die "delighted: could not parse version token from $href"
  VERSION="${tok:0:1}.${tok:1}"
  URL="$href"; curl -fL "$URL" -o "$DL"
}
write_cask_delighted(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://eclecticlight.co/wp-content/uploads/2026/03/delighted#{version.major}#{version.minor}.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://eclecticlight.co/downloads/"
    regex(%r{/delighted(\d)(\d+)\.zip}i)
    strategy :page_match do |page, regex|
      page.scan(regex).map { |m| "#{m[0]}.#{m[1]}" }
    end
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# dell-display-peripheral-manager — pkgInZip; the URL carries an opaque
# per-release FOLDER id (not version-derived) and the host UA-gates non-browser
# clients (curl -> 403; browser UA -> 200). Scrape the driver-details page for
# the current zip href; download with a browser UA. (Dell DDPM)
# ---------------------------------------------------------------------------
resolve_dell_display_peripheral_manager(){
  local ua="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
  local page href
  page="$(curl -fsSL -A "$ua" "https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=0h874")" || die "ddpm: driver page fetch failed"
  href="$(printf '%s' "$page" | grep -oE 'https://dl\.dell\.com/FOLDER[0-9A-Za-z]+/[0-9]+/DDPMv[0-9.]+\.zip' | head -1)"
  [ -n "$href" ] || die "ddpm: no DDPM zip href on driver page"
  VERSION="$(basename "$href" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "ddpm: could not parse version from $href"
  URL="$href"; curl -fL -A "$ua" "$URL" -o "$DL"
}
write_cask_dell_display_peripheral_manager(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://dl.dell.com/FOLDER09180078M/1/DDPMv#{version}.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=0h874"
    regex(/DDPMv(\d+(?:\.\d+)+)\.zip/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  pkg "DDPM_Installer.pkg"

  uninstall pkgutil: "$RECEIPT"

  zap trash: [
    "~/Library/Caches/$BUNDLE_ID",
    "~/Library/Preferences/$BUNDLE_ID.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# deskrest — GitHub release dmg whose asset filename carries a BUILD suffix
# (DeskRest.v<ver>-<build>.dmg) that is absent from the tag, so a github_tag
# asset template cannot reconstruct it. Read the real asset name off the
# latest release. (Marceeelll/DeskRest-releases)
# ---------------------------------------------------------------------------
resolve_deskrest(){
  local repo="Marceeelll/DeskRest-releases" tag asset
  tag="$(curl -sI "https://github.com/$repo/releases/latest" | awk -F'/tag/' 'tolower($0)~/^location/{print $2}' | tr -d '\r')"
  [ -n "$tag" ] || die "deskrest: no latest tag"
  case "$tag" in [vV][0-9]*) VERSION="${tag#?}";; *) VERSION="$tag";; esac
  asset="$(curl -fsSL "https://api.github.com/repos/$repo/releases/tags/$tag" 2>/dev/null \
    | grep -oE '"browser_download_url": *"[^"]+\.dmg"' | head -1 | sed -E 's/.*"(https[^"]+)".*/\1/')"
  [ -n "$asset" ] || asset="https://github.com/$repo/releases/download/$tag/DeskRest.${tag}-153.dmg"
  URL="$asset"; curl -fL "$URL" -o "$DL"
}
write_cask_deskrest(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/Marceeelll/DeskRest-releases/releases/download/v#{version}/DeskRest.v#{version}-153.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# displaylink-manager — pkg; the URL path embeds a non-derivable year-month
# folder (2026-05) and a space-laden filename, so it must be scraped from the
# Synapt​ics product page. page_match for version. (DisplayLink)
# ---------------------------------------------------------------------------
resolve_displaylink_manager(){
  local page href
  page="$(curl -fsSL "https://www.synaptics.com/products/displaylink-graphics/downloads/macos")" || die "displaylink: product page fetch failed"
  href="$(printf '%s' "$page" | grep -oiE 'https://[^"'"'"' ]*DisplayLink[^"'"'"' ]*\.pkg' | head -1)"
  [ -n "$href" ] || die "displaylink: no pkg href on product page"
  VERSION="$(printf '%s' "$href" | python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))' 2>/dev/null | grep -oE 'Connectivity[0-9]+(\.[0-9]+)+' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || VERSION="$(printf '%s' "$href" | grep -oE '[0-9]+(\.[0-9]+)+' | tail -1)"
  [ -n "$VERSION" ] || die "displaylink: could not parse version from $href"
  URL="$href"; curl -fL "$URL" -o "$DL"
}
write_cask_displaylink_manager(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://www.synaptics.com/sites/default/files/exe_files/2026-05/DisplayLink%20Manager%20Graphics%20Connectivity#{version}-EXE.pkg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.synaptics.com/products/displaylink-graphics/downloads/macos"
    regex(%r{Connectivity[%20A-Za-z]*(\d+(?:\.\d+)+)[%20A-Za-z-]*EXE\.pkg}i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  pkg "DisplayLink Manager Graphics Connectivity#{version}-EXE.pkg"

  uninstall launchctl: "com.displaylink.useragent",
            pkgutil:   "$RECEIPT"

  zap trash: [
    "~/Library/Caches/$BUNDLE_ID",
    "~/Library/Preferences/$BUNDLE_ID.plist",
  ]
end
RB
}


#!/usr/bin/env bash
# ============================================================================
# funcs-cc-chunk2.sh — CUSTOM resolve_/write_cask_ pairs for chunk2 apps that
# do not fit any built-in cask-master.sh SOURCE row.
#
# Paste these into (or source them alongside) scripts/cask-master.sh. Each pair
# is named resolve_<tfn> / write_cask_<tfn> where <tfn> is the cask token with
# every '-' replaced by '_'. The harness calls resolve_<tfn> (must set VERSION
# + URL and download to "$DL"), then computes "$SHA" from "$DL", runs inspect()
# (sets APP_NAME / RECEIPT / BUNDLE_ID / SYM), then calls write_cask_<tfn>
# (must write "$CASK"). Helpers used: zap_for, sub_cask. Harness vars used
# literally: $TOKEN $NAME $DESC $HOMEPAGE $ARTIFACT $VERSION $SHA $SHA_X64
# $APP_NAME $RECEIPT $BUNDLE_ID $SYM $W $DL $CASK.
#
# NESTED-CONTAINER pattern (dmg-in-zip / app-in-dmg-in-zip / pkg-in-zip):
#   The harness inspector only unwraps ONE level, so it cannot read the bundle
#   id / app name / pkg receipt out of a doubly-nested archive. These resolvers
#   therefore download the OUTER archive (capturing its sha into OUTER_SHA, which
#   is what the cask url points at), then unzip it and set "$DL" to the INNER
#   dmg/pkg so the harness inspect() can read the real metadata. The writer then
#   uses sha256 "$OUTER_SHA" (sha of the file at url) — $SHA (sha of the inner
#   artifact) is intentionally unused for these.
# ============================================================================

# ---------------------------------------------------------------------------
# eclipse-ide-for-embedded-cc-developers  (arch-split dmg, compound version)
# Modeled 1:1 on the live eclipse-jee cask: arch aarch64/x86_64, compound
# version "4.39,2026-03", mirror download.php url, shared org.eclipse.platform.ide
# leftovers, livecheck reuses the eclipse-ide cask, depends_on_java caveat.
# ---------------------------------------------------------------------------
resolve_eclipse_ide_for_embedded_cc_developers(){
  local rel="2026-03" ver="4.39" base
  VERSION="$ver,$rel"
  base="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/$rel/R"
  URL="$base/eclipse-embedcpp-$rel-R-macosx-cocoa-aarch64.dmg&mirror_id=1"
  curl -fL "$URL" -o "$DL"
  curl -fL "$base/eclipse-embedcpp-$rel-R-macosx-cocoa-x86_64.dmg&mirror_id=1" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "eclipse-embedcpp: intel dmg download failed"
}
write_cask_eclipse_ide_for_embedded_cc_developers(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  arch arm: "aarch64", intel: "x86_64"

  version "$VERSION"
  sha256 arm:   "$SHA",
         intel: "$SHA_X64"

  url "https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/#{version.csv.second}/R/eclipse-embedcpp-#{version.csv.second}-R-macosx-cocoa-#{arch}.dmg&mirror_id=1"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    cask "eclipse-ide"
  end

  depends_on macos: :big_sur

  # Renamed to avoid conflict with other Eclipse.
  app "Eclipse.app", target: "Eclipse Embedded CC.app"

  zap trash: [
    "~/Library/Caches/org.eclipse.platform.ide",
    "~/Library/Cookies/org.eclipse.platform.ide.binarycookies",
    "~/Library/Preferences/org.eclipse.platform.ide.plist",
    "~/Library/Saved Application State/org.eclipse.platform.ide.savedState",
  ]

  caveats do
    depends_on_java
  end
end
RB
}

# ---------------------------------------------------------------------------
# eclipse-ide-for-scout-developers  (arch-split dmg, compound version)
# Same model as eclipse-jee / embedded-cc above; package id eclipse-scout.
# ---------------------------------------------------------------------------
resolve_eclipse_ide_for_scout_developers(){
  local rel="2026-03" ver="4.39" base
  VERSION="$ver,$rel"
  base="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/$rel/R"
  URL="$base/eclipse-scout-$rel-R-macosx-cocoa-aarch64.dmg&mirror_id=1"
  curl -fL "$URL" -o "$DL"
  curl -fL "$base/eclipse-scout-$rel-R-macosx-cocoa-x86_64.dmg&mirror_id=1" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "eclipse-scout: intel dmg download failed"
}
write_cask_eclipse_ide_for_scout_developers(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  arch arm: "aarch64", intel: "x86_64"

  version "$VERSION"
  sha256 arm:   "$SHA",
         intel: "$SHA_X64"

  url "https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/#{version.csv.second}/R/eclipse-scout-#{version.csv.second}-R-macosx-cocoa-#{arch}.dmg&mirror_id=1"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    cask "eclipse-ide"
  end

  depends_on macos: :big_sur

  # Renamed to avoid conflict with other Eclipse.
  app "Eclipse.app", target: "Eclipse Scout.app"

  zap trash: [
    "~/Library/Caches/org.eclipse.platform.ide",
    "~/Library/Cookies/org.eclipse.platform.ide.binarycookies",
    "~/Library/Preferences/org.eclipse.platform.ide.plist",
    "~/Library/Saved Application State/org.eclipse.platform.ide.savedState",
  ]

  caveats do
    depends_on_java
  end
end
RB
}

# ---------------------------------------------------------------------------
# final-draft-12  (app-in-dmg-in-zip; filename strips dots: 12.0.11 -> 12011)
# Outer zip finaldraft12011Mac.zip -> inner .dmg -> Final Draft.app.
# DL = inner dmg (for inspect); cask sha = OUTER_SHA (sha of the zip at url).
# url uses #{version.no_dots} to rebuild the dot-stripped filename token.
# ---------------------------------------------------------------------------
resolve_final_draft_12(){
  VERSION="12.0.11"
  URL="https://www.finaldraft.com/downloads/finaldraft12011Mac.zip"
  curl -fL "$URL" -o "$DL" || die "final-draft-12: outer zip download failed"
  OUTER_SHA="$(shasum -a 256 "$DL" | awk '{print $1}')"
  rm -rf "$W/inner"; mkdir -p "$W/inner"; ditto -xk "$DL" "$W/inner" 2>/dev/null || unzip -oq "$DL" -d "$W/inner"
  local inner; inner="$(find "$W/inner" -maxdepth 3 -type f -iname '*.dmg' ! -path '*__MACOSX*' | head -1)"
  [ -n "$inner" ] || die "final-draft-12: no inner .dmg found in zip"
  cp "$inner" "$DL"
}
write_cask_final_draft_12(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$OUTER_SHA"

  url "https://www.finaldraft.com/downloads/finaldraft#{version.no_dots}Mac.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.finaldraft.com/support/install-final-draft/install-final-draft-12-macintosh/"
    regex(/finaldraft(\d+)Mac\.zip/i)
    strategy :page_match do |page, regex|
      page.scan(regex).map { |m| m[0].chars.first(2).join + "." + m[0].chars[2] + "." + m[0].chars[3..].join }.max
    end
  end

  depends_on macos: :big_sur

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# final-draft-13  (app-in-dmg-in-zip; 13.3.2 -> 1332; min macOS 12)
# ---------------------------------------------------------------------------
resolve_final_draft_13(){
  VERSION="13.3.2"
  URL="https://www.finaldraft.com/downloads/finaldraft1332Mac.zip"
  curl -fL "$URL" -o "$DL" || die "final-draft-13: outer zip download failed"
  OUTER_SHA="$(shasum -a 256 "$DL" | awk '{print $1}')"
  rm -rf "$W/inner"; mkdir -p "$W/inner"; ditto -xk "$DL" "$W/inner" 2>/dev/null || unzip -oq "$DL" -d "$W/inner"
  local inner; inner="$(find "$W/inner" -maxdepth 3 -type f -iname '*.dmg' ! -path '*__MACOSX*' | head -1)"
  [ -n "$inner" ] || die "final-draft-13: no inner .dmg found in zip"
  cp "$inner" "$DL"
}
write_cask_final_draft_13(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$OUTER_SHA"

  url "https://www.finaldraft.com/downloads/finaldraft#{version.no_dots}Mac.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.finaldraft.com/support/install-final-draft/install-final-draft-13-macintosh/"
    regex(/finaldraft(\d+)Mac\.zip/i)
    strategy :page_match do |page, regex|
      page.scan(regex).map { |m| m[0].chars.first(2).join + "." + m[0].chars[2] + "." + m[0].chars[3..].join }.max
    end
  end

  depends_on macos: :monterey

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# flashprint-5  (pkg-in-zip; non-derivable "_mac (new)" suffix; EOL, pinned)
# Outer versioned zip contains FlashPrint-5.8.7.pkg. DL = inner pkg (for the
# receipt); cask sha = OUTER_SHA. The outer filename has URL-encoded spaces and
# parens ("_mac (new)") that are not derivable from the version, so url is
# fully literal and version is pinned (final FlashPrint 5 release; line is EOL).
# ---------------------------------------------------------------------------
resolve_flashprint_5(){
  VERSION="5.8.7"
  URL="https://flashforge-resource.oss-us-east-1.aliyuncs.com/FlashPrint_5.8.7/FlashPrint_5.8.7_mac%20%28new%29.zip"
  curl -fL "$URL" -o "$DL" || die "flashprint-5: outer zip download failed"
  OUTER_SHA="$(shasum -a 256 "$DL" | awk '{print $1}')"
  rm -rf "$W/inner"; mkdir -p "$W/inner"; ditto -xk "$DL" "$W/inner" 2>/dev/null || unzip -oq "$DL" -d "$W/inner"
  local inner; inner="$(find "$W/inner" -maxdepth 3 -type f -iname '*.pkg' ! -path '*__MACOSX*' | head -1)"
  [ -n "$inner" ] || die "flashprint-5: no inner .pkg found in zip"
  cp "$inner" "$DL"
}
write_cask_flashprint_5(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$OUTER_SHA"

  url "https://flashforge-resource.oss-us-east-1.aliyuncs.com/FlashPrint_#{version}/FlashPrint_#{version}_mac%20%28new%29.zip",
      verified: "flashforge-resource.oss-us-east-1.aliyuncs.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.flashforge.com/pages/download-center"
    regex(/FlashPrint[._-]v?(\d+(?:\.\d+)+)/i)
    strategy :page_match
  end

  depends_on macos: :big_sur

  pkg "FlashPrint-#{version}.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# foldr  (dmg-in-zip; UNVERSIONED outer latest.zip -> version :latest)
# Outer latest.zip holds foldr.<ver>.dmg. The only published macOS URL is the
# unversioned "latest" alias with no version feed, so version :latest +
# sha256 :no_check (the inner filename carries the version, but it is not in any
# trackable URL/page). DL = inner dmg so inspect() reads the app name + bundle.
# ---------------------------------------------------------------------------
resolve_foldr(){
  VERSION="latest"
  URL="https://foldr-downloads-us.us-east-1.linodeobjects.com/clients/macos/latest.zip"
  curl -fL "$URL" -o "$DL" || die "foldr: outer zip download failed"
  rm -rf "$W/inner"; mkdir -p "$W/inner"; ditto -xk "$DL" "$W/inner" 2>/dev/null || unzip -oq "$DL" -d "$W/inner"
  local inner; inner="$(find "$W/inner" -maxdepth 3 -type f -iname '*.dmg' ! -path '*__MACOSX*' | head -1)"
  [ -n "$inner" ] || die "foldr: no inner .dmg found in zip"
  cp "$inner" "$DL"
}
write_cask_foldr(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version :latest
  sha256 :no_check

  url "https://foldr-downloads-us.us-east-1.linodeobjects.com/clients/macos/latest.zip",
      verified: "foldr-downloads-us.us-east-1.linodeobjects.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  depends_on macos: :big_sur

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# fotomagico  (app.zip; compound version+build with literal parens in filename)
# FotoMagico-6.9.2-Boinx-(1016682).app.zip — version "6.9.2,1016682" via
# version.csv; not nested, so DL = the zip and inspect() sets app + bundle.
# ---------------------------------------------------------------------------
resolve_fotomagico(){
  VERSION="6.9.2,1016682"
  URL="https://cdn.boinx.com/software/fotomagico/FotoMagico-6.9.2-Boinx-(1016682).app.zip"
  curl -fL "$URL" -o "$DL" || die "fotomagico: zip download failed"
}
write_cask_fotomagico(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://cdn.boinx.com/software/fotomagico/FotoMagico-#{version.csv.first}-Boinx-(#{version.csv.second}).app.zip",
      verified: "cdn.boinx.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://fotomagico.com/download/"
    regex(/FotoMagico[._-](\d+(?:\.\d+)+)[._-]Boinx[._-]\((\d+)\)\.app\.zip/i)
    strategy :page_match do |page, regex|
      match = page.match(regex)
      next if match.blank?

      "#{match[1]},#{match[2]}"
    end
  end

  depends_on macos: :catalina

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# frameio-transfer  (arch-split dmg; hash-in-URL; no public version feed)
# Public /latest/ dmgs behind a hash segment, no RELEASES/yml -> version :latest
# + sha256 :no_check, on_arm/on_intel. Adobe Frame.io Transfer (Squirrel.Mac).
# ---------------------------------------------------------------------------
resolve_frameio_transfer(){
  local h="6ab0c27d61d7cf8793b0357e6533ed81"
  VERSION="latest"
  URL="https://transferapp.frame.io/Frame.io-Transfer/$h/latest/darwin/arm64/Frame.io+Transfer.dmg"
  curl -fL "$URL" -o "$DL" || die "frameio-transfer: arm dmg download failed"
  curl -fL "https://transferapp.frame.io/Frame.io-Transfer/$h/latest/darwin/x64/Frame.io+Transfer.dmg" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "frameio-transfer: intel dmg download failed"
}
write_cask_frameio_transfer(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version :latest
  sha256 :no_check

  on_arm do
    url "https://transferapp.frame.io/Frame.io-Transfer/6ab0c27d61d7cf8793b0357e6533ed81/latest/darwin/arm64/Frame.io+Transfer.dmg"
  end
  on_intel do
    url "https://transferapp.frame.io/Frame.io-Transfer/6ab0c27d61d7cf8793b0357e6533ed81/latest/darwin/x64/Frame.io+Transfer.dmg"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"
  depends_on macos: :catalina

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# growly-glucose  (dmg; version encoded WITHOUT separators: 1.1.1 -> 111)
# url rebuilds the token via #{version.no_dots}. DL = dmg, inspect sets bundle.
# ---------------------------------------------------------------------------
resolve_growly_glucose(){
  VERSION="1.1.1"
  URL="https://www.growlybird.com/downloads/glucose_111.dmg"
  curl -fL "$URL" -o "$DL" || die "growly-glucose: dmg download failed"
}
write_cask_growly_glucose(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://www.growlybird.com/downloads/glucose_#{version.no_dots}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://growlybird.com/glucose/"
    regex(/Version\s+(\d+(?:\.\d+)+)/i)
    strategy :page_match
  end

  depends_on macos: :big_sur

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# guardian-browser  (arch-split; TWO per-arch latest-mac.yml feeds; unversioned dmgs)
# electron template needs one feed + versioned filenames; this ships separate
# arm/intel feeds and unversioned dmg names, so it is custom. Version read from
# the arm feed; livecheck = :electron_builder on the arm feed.
# ---------------------------------------------------------------------------
resolve_guardian_browser(){
  local armfeed="https://production-archimedes-secure-browser-artifacts.s3.amazonaws.com/latest/mac-arm64/latest-mac.yml"
  local base="https://production-archimedes-secure-browser-artifacts.s3.amazonaws.com/latest"
  VERSION="$(curl -fsSL "$armfeed" | awk -F': ' '/^version:/{print $2; exit}' | tr -d '\r ')"
  [ -n "$VERSION" ] || die "guardian-browser: could not read version from arm feed"
  URL="$base/mac-arm64/guardian-browser-arm64.dmg"
  curl -fL "$URL" -o "$DL" || die "guardian-browser: arm dmg download failed"
  curl -fL "$base/mac-x64/guardian-browser-x64.dmg" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "guardian-browser: intel dmg download failed"
}
write_cask_guardian_browser(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 :no_check
    url "https://production-archimedes-secure-browser-artifacts.s3.amazonaws.com/latest/mac-arm64/guardian-browser-arm64.dmg",
        verified: "production-archimedes-secure-browser-artifacts.s3.amazonaws.com/"
  end
  on_intel do
    sha256 "$SHA_X64"
    url "https://production-archimedes-secure-browser-artifacts.s3.amazonaws.com/latest/mac-x64/guardian-browser-x64.dmg",
        verified: "production-archimedes-secure-browser-artifacts.s3.amazonaws.com/"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://production-archimedes-secure-browser-artifacts.s3.amazonaws.com/latest/mac-arm64/latest-mac.yml"
    strategy :electron_builder
  end

  auto_updates true
  depends_on macos: :big_sur

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# huddly  (x64-only dmg; version ONLY in Content-Disposition; url unversioned)
# The download endpoint is an unversioned /latest/ URL whose response sets
# filename Huddly-<ver>-osx-x64.dmg. Version parsed from that header; url stays
# the unversioned endpoint; livecheck = :header_match. x64 app -> requires_rosetta.
# ---------------------------------------------------------------------------
resolve_huddly(){
  URL="https://app.huddly.com/download/latest/osx"
  VERSION="$(curl -sIL "$URL" | grep -i '^content-disposition' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "huddly: no version in content-disposition"
  curl -fL "$URL" -o "$DL" || die "huddly: dmg download failed"
}
write_cask_huddly(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 :no_check

  url "https://app.huddly.com/download/latest/osx"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    regex(/Huddly[._-](\d+(?:\.\d+)+)[._-]osx/i)
    strategy :header_match
  end

  depends_on macos: :big_sur

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
  caveats do
    requires_rosetta
  end
end
RB
}

# ---------------------------------------------------------------------------
# hudl-sportscode  (dmg-in-zip; url IS version-templatable; min macOS 15)
# Outer HudlSportscode-<ver>.dmg.zip -> inner dmg. DL = inner dmg (for inspect);
# cask sha = OUTER_SHA. No static version page (elite page is JS-rendered), so
# livecheck uses :header_match against the version-templated outer URL.
# ---------------------------------------------------------------------------
resolve_hudl_sportscode(){
  VERSION="12.81.1"
  URL="https://sportscode64-updates.s3.amazonaws.com/PublicReleaseDmgs/HudlSportscode-12.81.1.dmg.zip"
  curl -fL "$URL" -o "$DL" || die "hudl-sportscode: outer zip download failed"
  OUTER_SHA="$(shasum -a 256 "$DL" | awk '{print $1}')"
  rm -rf "$W/inner"; mkdir -p "$W/inner"; ditto -xk "$DL" "$W/inner" 2>/dev/null || unzip -oq "$DL" -d "$W/inner"
  local inner; inner="$(find "$W/inner" -maxdepth 3 -type f -iname '*.dmg' ! -path '*__MACOSX*' | head -1)"
  [ -n "$inner" ] || die "hudl-sportscode: no inner .dmg found in zip"
  cp "$inner" "$DL"
}
write_cask_hudl_sportscode(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$OUTER_SHA"

  url "https://sportscode64-updates.s3.amazonaws.com/PublicReleaseDmgs/HudlSportscode-#{version}.dmg.zip",
      verified: "sportscode64-updates.s3.amazonaws.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  depends_on macos: :sequoia

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# huggingchat-mac  (GitHub zip; repo ARCHIVED, all releases pre-release)
# releases/latest has no "Latest" tag, so :github_latest finds nothing -> pin
# version 0.7.0; livecheck scans the releases page (prereleases) via page_match.
# Discontinued. DL = zip, inspect sets app + bundle.
# ---------------------------------------------------------------------------
resolve_huggingchat_mac(){
  VERSION="0.7.0"
  URL="https://github.com/huggingface/chat-macOS/releases/download/v0.7.0/HuggingChat.zip"
  curl -fL "$URL" -o "$DL" || die "huggingchat-mac: zip download failed"
}
write_cask_huggingchat_mac(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/huggingface/chat-macOS/releases/download/v#{version}/HuggingChat.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://github.com/huggingface/chat-macOS/releases"
    regex(/releases\/tag\/v?(\d+(?:\.\d+)+)/i)
    strategy :page_match
  end

  depends_on macos: :sonoma

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# imanage-work  (pkg-in-zip; UNVERSIONED enclosure; Sparkle appcast)
# Sparkle enclosure "iManage Work Desktop for Mac.pkg.zip" (pkg nested in zip,
# spaces, no version in name) -> inner pkg. DL = inner pkg (for the receipt);
# cask sha = OUTER_SHA; version from the appcast; livecheck = :sparkle.
# ---------------------------------------------------------------------------
resolve_imanage_work(){
  VERSION="10.8.4"
  URL="https://updates.imanage.com/autoupdates/iManage%20Work%20Desktop%20for%20Mac.pkg.zip"
  curl -fL "$URL" -o "$DL" || die "imanage-work: outer zip download failed"
  OUTER_SHA="$(shasum -a 256 "$DL" | awk '{print $1}')"
  rm -rf "$W/inner"; mkdir -p "$W/inner"; ditto -xk "$DL" "$W/inner" 2>/dev/null || unzip -oq "$DL" -d "$W/inner"
  local inner; inner="$(find "$W/inner" -maxdepth 3 -type f -iname '*.pkg' ! -path '*__MACOSX*' | head -1)"
  [ -n "$inner" ] || die "imanage-work: no inner .pkg found in zip"
  cp "$inner" "$DL"
}
write_cask_imanage_work(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$OUTER_SHA"

  url "https://updates.imanage.com/autoupdates/iManage%20Work%20Desktop%20for%20Mac.pkg.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://updates.imanage.com/autoupdates/appcast.xml"
    strategy :sparkle
  end

  depends_on macos: :big_sur

  pkg "iManage Work Desktop for Mac.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# ipsw-updater  (zip; version-string transform 2026.4.15-1 -> 202604151)
# Filename token zero-pads the month and strips dots/dash, which is not a plain
# version interpolation, so url is literal and version is pinned. DL = zip,
# inspect sets app + bundle. livecheck = page_match on the updates page.
# ---------------------------------------------------------------------------
resolve_ipsw_updater(){
  VERSION="2026.4.15-1"
  URL="https://ipsw.app/download/IPSWUpdater-v202604151.zip"
  curl -fL "$URL" -o "$DL" || die "ipsw-updater: zip download failed"
}
write_cask_ipsw_updater(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 :no_check

  url "https://ipsw.app/download/IPSWUpdater-v202604151.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://ipsw.app/download/updates.php"
    regex(/(\d{4}\.\d+\.\d+(?:-\d+)?)/i)
    strategy :page_match
  end

  depends_on macos: :big_sur

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# jamf-compliance-editor  (GitHub pkg; tag/version skew: tag v1.5, asset 1.5.0)
# :github_latest gives tag "v1.5" which won't match the asset's "1.5.0", so the
# version is pinned to the asset version and the tag is rebuilt from
# #{version.major_minor}. livecheck reads the .pkg asset name out of the latest
# release JSON to recover the full x.y.z version.
# ---------------------------------------------------------------------------
resolve_jamf_compliance_editor(){
  local repo="Jamf-Concepts/jamf-compliance-editor" tag asset
  tag="$(curl -sI "https://github.com/$repo/releases/latest" | awk -F'/tag/' 'tolower($0)~/^location/{print $2}' | tr -d '\r')"
  [ -n "$tag" ] || tag="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | awk -F'"' '/"tag_name"/{print $4; exit}')"
  [ -n "$tag" ] || die "jamf-compliance-editor: no latest tag"
  asset="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | grep -oE 'JamfComplianceEditor-[0-9][0-9.]*\.pkg' | head -1)"
  if [ -n "$asset" ]; then VERSION="$(printf '%s' "$asset" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  else VERSION="${tag#v}"; case "$VERSION" in *.*.*) ;; *) VERSION="$VERSION.0";; esac; asset="JamfComplianceEditor-$VERSION.pkg"; fi
  URL="https://github.com/$repo/releases/download/$tag/$asset"
  curl -fL "$URL" -o "$DL" || die "jamf-compliance-editor: pkg download failed"
}
write_cask_jamf_compliance_editor(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/Jamf-Concepts/jamf-compliance-editor/releases/download/v#{version.major_minor}/JamfComplianceEditor-#{version}.pkg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    regex(/JamfComplianceEditor[._-]v?(\d+(?:\.\d+)+)\.pkg/i)
    strategy :github_latest do |json, regex|
      json["assets"]&.map { |a| a["name"][regex, 1] }&.compact&.max
    end
  end

  depends_on macos: :big_sur

  pkg "JamfComplianceEditor-#{version}.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# jamf-connect-configuration  (dmg; version ONLY in x-amz-meta-version header)
# Shared JamfConnect.dmg (also used by jamf-connect-login) whose drag-install
# artifact for THIS token is "Jamf Connect Configuration.app". url is unversioned;
# version read from the x-amz-meta-version response header; livecheck =
# :header_match on the same field. DL = dmg so inspect can read the bundle id.
# ---------------------------------------------------------------------------
resolve_jamf_connect_configuration(){
  URL="https://files.jamfconnect.com/JamfConnect.dmg"
  VERSION="$(curl -sIL "$URL" | grep -i '^x-amz-meta-version' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "jamf-connect-configuration: no x-amz-meta-version header"
  curl -fL "$URL" -o "$DL" || die "jamf-connect-configuration: dmg download failed"
}
write_cask_jamf_connect_configuration(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 :no_check

  url "https://files.jamfconnect.com/JamfConnect.dmg",
      verified: "files.jamfconnect.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    strategy :header_match do |headers|
      headers["x-amz-meta-version"]
    end
  end

  depends_on macos: :big_sur

  app "Jamf Connect Configuration.app"
$(zap_for "$BUNDLE_ID")
end
RB
}


# shellcheck shell=bash
# ============================================================================
# funcs-cc-chunk3.sh — custom resolve_<tfn>/write_cask_<tfn> pairs for the
# apps in in-cc-chunk3.tsv that do NOT fit a built-in cask-master.sh source.
#
# Source these from cask-master.sh (paste into its custom section, or
# `source` this file) BEFORE running the batch. <tfn> = token with every
# '-' replaced by '_'. Each resolve_<tfn> sets VERSION + URL and downloads
# to "$DL" (arch-split also writes "$W/dl-x64" and sets SHA_X64). Each
# write_cask_<tfn> writes "$CASK". $SHA/$SHA_X64/$VERSION are harness-set
# during resolve+sha; receipts/bundle ids/app names are hardcoded from the
# verified notes (the harness artifact inspector cannot reliably unwrap
# pkgInDmg / pkgInZip / arch-split installers).
#
# Apps NOT in this file (mersive-solstice) fit a built-in source and live in
# out-cc-chunk3.tsv as a regular registry row, not here.
# ============================================================================

# ---------------------------------------------------------------------------
# jamf-connect-login — pkgInDmg, shared unversioned dmg, version in x-amz header
#   Shared https://files.jamfconnect.com/JamfConnect.dmg (same dmg as
#   jamf-connect-configuration). Inner artifact = "Jamf Connect.pkg"
#   (receipt com.jamf.connect.login; bundles JamfConnectLaunchAgent.pkg).
#   Version only in the x-amz-meta-version response header -> :header_match.
# ---------------------------------------------------------------------------
resolve_jamf_connect_login(){
  local url="https://files.jamfconnect.com/JamfConnect.dmg"
  VERSION="$(curl -sI "$url" | awk -F': ' 'tolower($1)=="x-amz-meta-version"{print $2}' | tr -d '\r ')"
  [ -n "$VERSION" ] || VERSION="$(curl -sI "$url" | grep -i '^content-disposition' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "jamf-connect-login: no version in headers"
  URL="$url"; curl -fL "$URL" -o "$DL"
}
write_cask_jamf_connect_login(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 :no_check

  url "https://files.jamfconnect.com/JamfConnect.dmg",
      verified: "files.jamfconnect.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    strategy :header_match
  end

  depends_on macos: :$SYM

  pkg "Jamf Connect.pkg"

  uninstall pkgutil: "com.jamf.connect.login"

  zap trash: [
    "~/Library/Caches/com.jamf.connect.login",
    "~/Library/Preferences/com.jamf.connect.login.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# joan-configurator — arch-split dmg, UNVERSIONED stable aliases, header version
#   arm  https://configurator.getjoan.com/download/flavor/joan/latest/osx_arm64
#   intel https://configurator.getjoan.com/download/flavor/joan/latest/osx_64
#   version only via Content-Disposition (joan-configurator-2.1.4-*.dmg) ->
#   :header_match. URLs cannot template {v}; arch-split.
# ---------------------------------------------------------------------------
resolve_joan_configurator(){
  local arm="https://configurator.getjoan.com/download/flavor/joan/latest/osx_arm64"
  local intel="https://configurator.getjoan.com/download/flavor/joan/latest/osx_64"
  VERSION="$(curl -sIL "$arm" | grep -i '^content-disposition' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "joan-configurator: no version in content-disposition"
  URL="$arm"; curl -fL "$URL" -o "$DL"
  curl -fL "$intel" -o "$W/dl-x64" && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "joan-configurator: intel download failed"
}
write_cask_joan_configurator(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 :no_check
    url "https://configurator.getjoan.com/download/flavor/joan/latest/osx_arm64"
  end
  on_intel do
    sha256 "$SHA_X64"
    url "https://configurator.getjoan.com/download/flavor/joan/latest/osx_64"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://configurator.getjoan.com/download/flavor/joan/latest/osx_arm64"
    regex(/joan-configurator[._-]v?(\d+(?:\.\d+)+)[._-]arm64/i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  app "Joan Configurator.app"

  zap trash: [
    "~/Library/Application Support/Joan Configurator",
    "~/Library/Caches/com.getjoan.joan-configurator",
    "~/Library/Preferences/com.getjoan.joan-configurator.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# jpegmini-pro — dmg, build-only token in URL, version != filename
#   https://assets.jpegmini.com/downloads/pro/mac/jpegmini_pro4_b72851.dmg
#   marketing version 4.2.3.72851 (build b72851 is the only number in the URL).
#   bundle com.beamr.jpegminipro.app. No stable versioned URL template.
# ---------------------------------------------------------------------------
resolve_jpegmini_pro(){
  VERSION="4.2.3.72851"
  URL="https://assets.jpegmini.com/downloads/pro/mac/jpegmini_pro4_b72851.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_jpegmini_pro(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://assets.jpegmini.com/downloads/pro/mac/jpegmini_pro4_b72851.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://jpegmini.com/downloads/mac"
    regex(/jpegmini[._-]pro\d*[._-]b(\d+)\.dmg/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "JPEGmini Pro.app"

  zap trash: [
    "~/Library/Caches/com.beamr.jpegminipro.app",
    "~/Library/HTTPStorages/com.beamr.jpegminipro.app",
    "~/Library/Preferences/com.beamr.jpegminipro.app.plist",
    "~/Library/Saved Application State/com.beamr.jpegminipro.app.savedState",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# keeper-secrets-manager-cli — pkg, GitHub monorepo (ksm-cli-* tags)
#   https://github.com/Keeper-Security/secrets-manager/releases/download/
#     ksm-cli-1.3.0/keeper-secrets-manager-cli-macos-1.3.0.pkg
#   :github_latest grabs the wrong tag -> filter ksm-cli-* tags via regex.
#   receipt resolved on-Mac; official Keeper-built pkg.
# ---------------------------------------------------------------------------
resolve_keeper_secrets_manager_cli(){
  local repo="Keeper-Security/secrets-manager"
  TAG="$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=50" 2>/dev/null \
        | awk -F'"' '/"tag_name"/{print $4}' | grep -E '^ksm-cli-[0-9]' | head -1)"
  [ -n "$TAG" ] || die "keeper-ksm-cli: no ksm-cli-* tag found"
  VERSION="${TAG#ksm-cli-}"
  URL="https://github.com/$repo/releases/download/$TAG/keeper-secrets-manager-cli-macos-$VERSION.pkg"
  curl -fL "$URL" -o "$DL"
}
write_cask_keeper_secrets_manager_cli(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/Keeper-Security/secrets-manager/releases/download/ksm-cli-#{version}/keeper-secrets-manager-cli-macos-#{version}.pkg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    regex(/^ksm-cli[._-]v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end

  depends_on macos: :$SYM

  pkg "keeper-secrets-manager-cli-macos-#{version}.pkg"

  uninstall pkgutil: "$RECEIPT"

$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# lg-calibration-studio — pkgInZip, opaque fileId in URL, scraped version
#   https://gscs-b2c.lge.com/downloadFile?fileId=mp6Ez3DAnsO4r3HuzRaLfw
#   Content-Disposition Mac_LCS_7.6.8.zip ; version 7.6.8 from LG support page.
#   fileId is NOT version-derived; both must be re-scraped each release.
# ---------------------------------------------------------------------------
resolve_lg_calibration_studio(){
  VERSION="7.6.8"
  URL="https://gscs-b2c.lge.com/downloadFile?fileId=mp6Ez3DAnsO4r3HuzRaLfw"
  curl -fL "$URL" -o "$DL"
}
write_cask_lg_calibration_studio(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 :no_check

  url "https://gscs-b2c.lge.com/downloadFile?fileId=mp6Ez3DAnsO4r3HuzRaLfw",
      verified: "gscs-b2c.lge.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.lg.com/us/support/product/lg-34WK95U-W.AUS"
    regex(/LG Calibration Studio[^0-9]+(\d+(?:\.\d+)+)/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  pkg "LG Calibration Studio.pkg"

  uninstall pkgutil: "$RECEIPT"

$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# macos-instantview — dmg, compound version V3.24R0004 (zero-padded build)
#   https://www.siliconmotion.com/downloads/macOS_InstantView_V3.24R0004.dmg
#   marketing "V3.24 R04" -> version.csv "3.24,4". bundle com.SMI-Inc.InstantView.
# ---------------------------------------------------------------------------
resolve_macos_instantview(){
  VERSION="3.24,4"
  URL="https://www.siliconmotion.com/downloads/macOS_InstantView_V3.24R0004.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_macos_instantview(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://www.siliconmotion.com/downloads/macOS_InstantView_V#{version.csv.first}R000#{version.csv.second}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.siliconmotion.com/downloads/"
    regex(/macOS_InstantView_V(\d+(?:\.\d+)+)R0*(\d+)\.dmg/i)
    strategy :page_match do |page, regex|
      page.scan(regex).map { |m| "#{m[0]},#{m[1]}" }
    end
  end

  depends_on macos: :$SYM

  app "InstantView.app"

  zap trash: [
    "~/Library/Caches/com.SMI-Inc.InstantView",
    "~/Library/Preferences/com.SMI-Inc.InstantView.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# mamp-pro — arch-split pkg, URL embeds marketing "7.4" not full "7.4.0"
#   arm   https://downloads.mamp.info/MAMP-PRO/macOS/MAMP-PRO/MAMP-MAMP-PRO-7.4-Apple-chip.pkg
#   intel https://downloads.mamp.info/MAMP-PRO/macOS/MAMP-PRO/MAMP-MAMP-PRO-7.4-Intel-x86.pkg
#   version 7.4.0 -> version.csv "7.4.0,7.4" (full,url). arch-split non-electron pkg.
# ---------------------------------------------------------------------------
resolve_mamp_pro(){
  VERSION="7.4.0,7.4"
  local base="https://downloads.mamp.info/MAMP-PRO/macOS/MAMP-PRO"
  URL="$base/MAMP-MAMP-PRO-7.4-Apple-chip.pkg"; curl -fL "$URL" -o "$DL"
  curl -fL "$base/MAMP-MAMP-PRO-7.4-Intel-x86.pkg" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "mamp-pro: intel download failed"
}
write_cask_mamp_pro(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 "$SHA"
    url "https://downloads.mamp.info/MAMP-PRO/macOS/MAMP-PRO/MAMP-MAMP-PRO-#{version.csv.second}-Apple-chip.pkg"
  end
  on_intel do
    sha256 "$SHA_X64"
    url "https://downloads.mamp.info/MAMP-PRO/macOS/MAMP-PRO/MAMP-MAMP-PRO-#{version.csv.second}-Intel-x86.pkg"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.mamp.info/en/downloads/"
    regex(/MAMP[._-]PRO[^0-9]+(\d+(?:\.\d+)+)/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  pkg "MAMP PRO.pkg"

  uninstall pkgutil: "$RECEIPT"

$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# maxon-cinema-4d-2026 — dmg, version path 2026.2.0 but filename uses 2026.2
#   https://mx-app-blob-prod.maxon.net/.../releases/2026.2.0/Cinema4D_2026_2026.2_Mac.dmg
#   version.csv "2026.2.0,2026.2" (path,filename). Licensed (installer public).
# ---------------------------------------------------------------------------
resolve_maxon_cinema_4d_2026(){
  VERSION="2026.2.0,2026.2"
  URL="https://mx-app-blob-prod.maxon.net/mx-package-production/installer/macos/maxon/cinema4d/releases/2026.2.0/Cinema4D_2026_2026.2_Mac.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_maxon_cinema_4d_2026(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://mx-app-blob-prod.maxon.net/mx-package-production/installer/macos/maxon/cinema4d/releases/#{version.csv.first}/Cinema4D_2026_#{version.csv.second}_Mac.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.maxon.net/en/downloads/cinema-4d-2026-downloads"
    regex(/Cinema4D_2026_(\d+(?:\.\d+)+)_Mac\.dmg/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "Maxon Cinema 4D 2026/Cinema 4D.app"

  zap trash: [
    "~/Library/Caches/net.maxon.cinema4d",
    "~/Library/Preferences/net.maxon.cinema4d.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# medialab-connect — arch-split dmg, per-release content hash in URL path
#   intel https://info.medialab.app/share/asset/source/M6MZN/<hash>/MediaLab_Connect-1.8.0.dmg
#   arm   https://info.medialab.app/share/asset/source/gZ0v8/<hash>/MediaLab_Connect-1.8.0-arm64.dmg
#   hash + short id not derivable from version -> hardcode current release.
# ---------------------------------------------------------------------------
resolve_medialab_connect(){
  VERSION="1.8.0"
  local arm="https://info.medialab.app/share/asset/source/gZ0v8/adc264f88859996db344c4c5d4161a67ea5e4e84366ec734e101975302ef2c73/MediaLab_Connect-1.8.0-arm64.dmg"
  local intel="https://info.medialab.app/share/asset/source/M6MZN/db865132ed3f3d6a48efa5449963954cd45d189fbf8abba9c068d3d213d3cc75/MediaLab_Connect-1.8.0.dmg"
  URL="$arm"; curl -fL "$URL" -o "$DL"
  curl -fL "$intel" -o "$W/dl-x64" && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "medialab-connect: intel download failed"
}
write_cask_medialab_connect(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 "$SHA"
    url "https://info.medialab.app/share/asset/source/gZ0v8/adc264f88859996db344c4c5d4161a67ea5e4e84366ec734e101975302ef2c73/MediaLab_Connect-#{version}-arm64.dmg",
        verified: "info.medialab.app/"
  end
  on_intel do
    sha256 "$SHA_X64"
    url "https://info.medialab.app/share/asset/source/M6MZN/db865132ed3f3d6a48efa5449963954cd45d189fbf8abba9c068d3d213d3cc75/MediaLab_Connect-#{version}.dmg",
        verified: "info.medialab.app/"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.medialab.co/downloads/"
    regex(/MediaLab[._-]Connect[._-]v?(\d+(?:\.\d+)+)/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "MediaLab Connect.app"

  zap trash: [
    "~/Library/Application Support/MediaLab Connect",
    "~/Library/Caches/co.medialab.connect",
    "~/Library/Preferences/co.medialab.connect.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# microsoft-company-portal — pkg, derived from MAU Sparkle feed; bundles MAU
#   feed 0409IMCP01.xml -> CompanyPortal_5.2604.1-Upgrade.pkg, -Upgrade->-Installer
#   https://res.public.onecdn.static.microsoft/mro1cdnstorage/<UUID>/MacAutoupdate/
#     CompanyPortal_#{version}-Installer.pkg . Deselect bundled MAU at install.
# ---------------------------------------------------------------------------
resolve_microsoft_company_portal(){
  local feed="https://officecdnmac.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/0409IMCP01.xml"
  local loc; loc="$(curl -fsSL "$feed" | grep -oE 'CompanyPortal_[0-9.]+-Upgrade\.pkg' | head -1)"
  [ -n "$loc" ] || die "ms-company-portal: no Location in MAU feed"
  VERSION="$(printf '%s' "$loc" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  URL="https://res.public.onecdn.static.microsoft/mro1cdnstorage/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/CompanyPortal_${VERSION}-Installer.pkg"
  curl -fL "$URL" -o "$DL"
}
write_cask_microsoft_company_portal(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://res.public.onecdn.static.microsoft/mro1cdnstorage/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/CompanyPortal_#{version}-Installer.pkg",
      verified: "res.public.onecdn.static.microsoft/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://officecdnmac.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/0409IMCP01.xml"
    strategy :sparkle
  end

  auto_updates true
  depends_on macos: :$SYM

  pkg "CompanyPortal_#{version}-Installer.pkg",
      choices: [
        {
          "choiceIdentifier" => "com.microsoft.autoupdate",
          "choiceAttribute"  => "selected",
          "attributeSetting" => 0,
        },
      ]

  uninstall quit:    "com.microsoft.autoupdate2",
            pkgutil: "$RECEIPT"

$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# microsoft-powershell — arch-split pkg on GitHub (PowerShell/PowerShell)
#   arm64 powershell-#{version}-osx-arm64.pkg ; x64 powershell-#{version}-osx-x64.pkg
#   token avoids the homebrew-core 'powershell' formula collision.
# ---------------------------------------------------------------------------
resolve_microsoft_powershell(){
  local repo="PowerShell/PowerShell"
  get_github_tag "$repo"; [ -n "$TAG" ] || die "ms-powershell: no latest tag"
  case "$TAG" in [vV][0-9]*) VERSION="${TAG#?}";; *) VERSION="$TAG";; esac
  URL="https://github.com/$repo/releases/download/$TAG/powershell-${VERSION}-osx-arm64.pkg"
  curl -fL "$URL" -o "$DL"
  curl -fL "https://github.com/$repo/releases/download/$TAG/powershell-${VERSION}-osx-x64.pkg" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "ms-powershell: x64 download failed"
}
write_cask_microsoft_powershell(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 "$SHA"
    url "https://github.com/PowerShell/PowerShell/releases/download/v#{version}/powershell-#{version}-osx-arm64.pkg"
  end
  on_intel do
    sha256 "$SHA_X64"
    url "https://github.com/PowerShell/PowerShell/releases/download/v#{version}/powershell-#{version}-osx-x64.pkg"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :$SYM

  pkg "powershell-#{version}-osx-#{arch}.pkg"

  uninstall pkgutil: "com.microsoft.powershell"

  zap trash: [
    "~/.cache/powershell",
    "~/.config/powershell",
    "~/.local/share/powershell",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# mimiq — dmg, URL embeds a build timestamp + version + build (not derivable)
#   https://updates.hedge.video/mimiq/macos/updates/production/
#     Mimiq_20260505135920_v26.2b197/Mimiq_20260505135920_v26.2b197.dmg
#   version 26.2 build 197. Hardcode current release; livecheck off release docs.
# ---------------------------------------------------------------------------
resolve_mimiq(){
  VERSION="26.2"
  URL="https://updates.hedge.video/mimiq/macos/updates/production/Mimiq_20260505135920_v26.2b197/Mimiq_20260505135920_v26.2b197.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_mimiq(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://updates.hedge.video/mimiq/macos/updates/production/Mimiq_20260505135920_v26.2b197/Mimiq_20260505135920_v26.2b197.dmg",
      verified: "updates.hedge.video/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://docs.hedge.video/mimiq/releases"
    regex(/[Vv]ersion[^0-9]+(\d+(?:\.\d+)+)/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "Mimiq.app"

  zap trash: [
    "~/Library/Caches/video.hedge.Mimiq",
    "~/Library/Preferences/video.hedge.Mimiq.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# mister-horse-product-manager — dmg, final CDN URL has a per-link random token
#   stable https://misterhorse.com/downloads/product-manager/osx -> 301 ->
#   /downloads/get?id=4&os=osx -> 302 -> CDN .../<token>/MisterHorseProductManager_<v>.dmg
#   Use the stable redirect as url (brew follows it); version + livecheck via header_match.
#   bundle com.misterhorse.ProductManager.
# ---------------------------------------------------------------------------
resolve_mister_horse_product_manager(){
  local short="https://misterhorse.com/downloads/product-manager/osx"
  local real; real="$(curl -sIL "$short" | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  VERSION="$(basename "${real%%\?*}" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "mister-horse: no version in redirect"
  URL="$short"; curl -fL "$URL" -o "$DL"
}
write_cask_mister_horse_product_manager(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 :no_check

  url "https://misterhorse.com/downloads/product-manager/osx"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://misterhorse.com/downloads/product-manager/osx"
    regex(/MisterHorseProductManager[._-]v?(\d+(?:\.\d+)+)\.dmg/i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  app "Mister Horse Product Manager.app"

  zap trash: [
    "~/Library/Application Support/com.misterhorse.ProductManager",
    "~/Library/Caches/com.misterhorse.ProductManager",
    "~/Library/Preferences/com.misterhorse.ProductManager.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# monotype-connect — dmg, version is dot->hyphen encoded in the URL
#   https://bin.extensis.com/ExtensisConnect-M-28-1-5.dmg  (28.1.5 -> 28-1-5)
#   bundle com.extensis.connect. Public download via the links.extensis.com 302.
# ---------------------------------------------------------------------------
resolve_monotype_connect(){
  VERSION="28.1.5"
  URL="https://bin.extensis.com/ExtensisConnect-M-28-1-5.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_monotype_connect(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://bin.extensis.com/ExtensisConnect-M-#{version.dots_to_hyphens}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://links.extensis.com/extensis_connect/ec_latest?language=en&platform=mac"
    regex(/ExtensisConnect-M-(\d+(?:-\d+)+)\.dmg/i)
    strategy :header_match do |headers, regex|
      m = headers["location"]&.match(regex)
      next if m.blank?

      m[1].tr("-", ".")
    end
  end

  depends_on macos: :$SYM

  app "Extensis Connect.app"

  zap trash: [
    "~/Library/Application Support/com.extensis.connect",
    "~/Library/Caches/com.extensis.connect",
    "~/Library/Preferences/com.extensis.connect.plist",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# multiviewer-for-f1 — dmg (universal), per-release numeric ID in URL path
#   https://releases.multiviewer.app/download/<numericID>/MultiViewer-<v>-universal.dmg
#   ID not derivable from version; resolve via the JSON releases API.
#   Electron, bundle com.electron.multiviewer-for-f1.
# ---------------------------------------------------------------------------
resolve_multiviewer_for_f1(){
  local api="https://api.multiviewer.app/api/v1/releases/latest"
  local json; json="$(curl -fsSL "$api")"
  VERSION="$(printf '%s' "$json" | grep -oE '"version"[ :]*"[^"]+"' | head -1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "multiviewer: no version from API"
  URL="$(printf '%s' "$json" | grep -oE 'https://releases\.multiviewer\.app/download/[0-9]+/MultiViewer-[0-9.]+-universal\.dmg' | head -1)"
  [ -n "$URL" ] || die "multiviewer: no universal dmg URL from API"
  curl -fL "$URL" -o "$DL"
}
write_cask_multiviewer_for_f1(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "$URL"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://api.multiviewer.app/api/v1/releases/latest"
    strategy :json do |json|
      json["version"]
    end
  end

  auto_updates true
  depends_on macos: :$SYM

  app "MultiViewer for F1.app"

  uninstall quit: "com.electron.multiviewer-for-f1"

  zap trash: [
    "~/Library/Application Support/MultiViewer for F1",
    "~/Library/Caches/com.electron.multiviewer-for-f1",
    "~/Library/Caches/com.electron.multiviewer-for-f1.ShipIt",
    "~/Library/Preferences/com.electron.multiviewer-for-f1.plist",
    "~/Library/Saved Application State/com.electron.multiviewer-for-f1.savedState",
  ]
end
RB
}

# ---------------------------------------------------------------------------
# netbird — arch-split pkg on GitHub (netbirdio/netbird)
#   arm64 netbird_#{version}_darwin_arm64.pkg ; amd64 netbird_#{version}_darwin_amd64.pkg
#   signed pkg installers (the darwin .tar.gz builds are not eligible).
# ---------------------------------------------------------------------------
resolve_netbird(){
  local repo="netbirdio/netbird"
  get_github_tag "$repo"; [ -n "$TAG" ] || die "netbird: no latest tag"
  case "$TAG" in [vV][0-9]*) VERSION="${TAG#?}";; *) VERSION="$TAG";; esac
  URL="https://github.com/$repo/releases/download/$TAG/netbird_${VERSION}_darwin_arm64.pkg"
  curl -fL "$URL" -o "$DL"
  curl -fL "https://github.com/$repo/releases/download/$TAG/netbird_${VERSION}_darwin_amd64.pkg" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "netbird: amd64 download failed"
}
write_cask_netbird(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  arch arm: "arm64", intel: "amd64"

  version "$VERSION"

  on_arm do
    sha256 "$SHA"
  end
  on_intel do
    sha256 "$SHA_X64"
  end

  url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird_#{version}_darwin_#{arch}.pkg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :$SYM

  pkg "netbird_#{version}_darwin_#{arch}.pkg"

  uninstall pkgutil: "$RECEIPT"

$(zap_for "$BUNDLE_ID")
end
RB
}


#!/usr/bin/env bash
###############################################################################
# funcs-cc-chunk4.sh — custom resolve_/write_cask_ pairs for chunk 4.
#
# Source these (or paste into) scripts/cask-master.sh's "OPTIONAL per-app
# overrides" section. Each pair is named resolve_<tfn> / write_cask_<tfn>
# where <tfn> is the registry token with every '-' replaced by '_'.
#
# Harness-set vars available in these functions:
#   $TOKEN $NAME $DESC $HOMEPAGE $ARTIFACT $CASK $DL $W   (always)
#   $VERSION $SHA $SHA_X64 $APP_NAME $BUNDLE_ID $RECEIPT $SYM  (set by the
#   harness AFTER resolve, from artifact inspection — usable in write_cask_*)
# resolve_* must set VERSION + URL and download the arm/universal file to $DL;
# for arch-split also download intel to "$W/dl-x64" and set SHA_X64.
#
# Validate: bash -n progress/sourced/funcs-cc-chunk4.sh
###############################################################################

# ---------------------------------------------------------------------------
# noor — native team-chat app (Rust). Arch-split DMG (aarch64 / x64) on a CDN.
# WHY CUSTOM: arch-split non-electron dmg; the x86_64 redirect currently
# resolves to cdn.noor.to/undefined, so URLs are built from the version read
# off the working aarch64 redirect filename. Two shas (arm/intel).
# ---------------------------------------------------------------------------
resolve_noor(){
  local loc base="https://cdn.noor.to/noor-2-releases"
  loc="$(curl -sIL "https://sun.noor.to/download/latest/macos/aarch64" \
        | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  VERSION="$(basename "${loc%%\?*}" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || { echo "noor: could not read version" >&2; return 1; }
  URL="$base/Noor_${VERSION}_aarch64.dmg"; curl -fL "$URL" -o "$DL"
  curl -fL "$base/Noor_${VERSION}_x64.dmg" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" \
    || { echo "noor: intel dmg download failed" >&2; return 1; }
}
write_cask_noor(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 "$SHA"
    url "https://cdn.noor.to/noor-2-releases/Noor_#{version}_aarch64.dmg"
  end
  on_intel do
    sha256 "$SHA_X64"
    url "https://cdn.noor.to/noor-2-releases/Noor_#{version}_x64.dmg"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://sun.noor.to/download/latest/macos/aarch64"
    regex(/Noor_(\d+(?:\.\d+)+)_aarch64\.dmg/i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# nvivo-14 — unversioned alias redirects to a versioned dmg whose version lives
# in the URL PATH (.../14.24.0.52/NVivo14.dmg), NOT the filename. The built-in
# direct_header resolver reads version from the basename only (NVivo14.dmg ->
# no version) so it cannot resolve this. CUSTOM: parse version from Location.
# ---------------------------------------------------------------------------
resolve_nvivo_14(){
  local loc short="https://download.qsrinternational.com/Software/NVivo14forMac/NVivo.dmg"
  loc="$(curl -sIL "$short" | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  VERSION="$(printf '%s' "$loc" | grep -oE '[0-9]+(\.[0-9]+){2,}' | head -1)"
  [ -n "$VERSION" ] || { echo "nvivo-14: could not read version" >&2; return 1; }
  URL="https://download.qsrinternational.com/Software/NVivo14forMac/${VERSION}/NVivo14.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_nvivo_14(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://download.qsrinternational.com/Software/NVivo14forMac/#{version}/NVivo14.dmg",
      verified: "download.qsrinternational.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://download.qsrinternational.com/Software/NVivo14forMac/NVivo.dmg"
    regex(%r{NVivo14forMac/(\d+(?:\.\d+)+)/}i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# nvivo-15 — same shape as nvivo-14 (version in the redirect PATH).
# ---------------------------------------------------------------------------
resolve_nvivo_15(){
  local loc short="https://download.qsrinternational.com/Software/NVivo15forMac/NVivo15.dmg"
  loc="$(curl -sIL "$short" | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  VERSION="$(printf '%s' "$loc" | grep -oE '[0-9]+(\.[0-9]+){2,}' | head -1)"
  [ -n "$VERSION" ] || { echo "nvivo-15: could not read version" >&2; return 1; }
  URL="https://download.qsrinternational.com/Software/NVivo15forMac/${VERSION}/NVivo15.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_nvivo_15(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://download.qsrinternational.com/Software/NVivo15forMac/#{version}/NVivo15.dmg",
      verified: "download.qsrinternational.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://download.qsrinternational.com/Software/NVivo15forMac/NVivo15.dmg"
    regex(%r{NVivo15forMac/(\d+(?:\.\d+)+)/}i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# okiocam-snapshot-and-recorder — document-camera capture app.
# WHY CUSTOM: nested dmgInZip (.dmg.zip = zip -> dmg -> app); the URL has a
# space + double extension needing encoding. Version is in the filename.
# Homebrew auto-unzips then mounts the inner dmg; the cask just declares `app`.
# ---------------------------------------------------------------------------
resolve_okiocam_snapshot_and_recorder(){
  VERSION="1.0.17"
  URL="https://okiolabs-downloads.s3.us-east-2.amazonaws.com/OKIOCAM+Snapshot+and+Recorder-${VERSION}.dmg.zip"
  curl -fL "$URL" -o "$DL"
}
write_cask_okiocam_snapshot_and_recorder(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "1.0.17"
  sha256 "$SHA"

  url "https://okiolabs-downloads.s3.us-east-2.amazonaws.com/OKIOCAM+Snapshot+and+Recorder-#{version}.dmg.zip",
      verified: "okiolabs-downloads.s3.us-east-2.amazonaws.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.okiolabs.com/apps-software-download/"
    regex(/Snapshot[+ ]and[+ ]Recorder-(\d+(?:\.\d+)+)\.dmg\.zip/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# origami-3 — Boxshot/Appsforlife packaging-dieline tool. Arch-split dmg
# (ARM/Intel) whose CDN path embeds the version (origami/3/<v>/...). The
# id.appsforlife.com redirect carries the version. WHY CUSTOM: arch-split +
# version-in-CDN-path -> needs per-arch url + sha, not a single template.
# ---------------------------------------------------------------------------
resolve_origami_3(){
  local loc base
  loc="$(curl -sIL "https://id.appsforlife.com/download/origami/mac-arm" \
        | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  VERSION="$(printf '%s' "$loc" | grep -oE 'origami/3/([0-9]+(\.[0-9]+)+)/' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || VERSION="3.4.5"
  base="https://cdn4.appsforlife.com/origami/3/${VERSION}"
  URL="$base/Origami3_ARM.dmg"; curl -fL "$URL" -o "$DL"
  curl -fL "$base/Origami3_Intel.dmg" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" \
    || { echo "origami-3: intel dmg download failed" >&2; return 1; }
}
write_cask_origami_3(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 "$SHA"
    url "https://cdn4.appsforlife.com/origami/3/#{version}/Origami3_ARM.dmg",
        verified: "cdn4.appsforlife.com/"
  end
  on_intel do
    sha256 "$SHA_X64"
    url "https://cdn4.appsforlife.com/origami/3/#{version}/Origami3_Intel.dmg",
        verified: "cdn4.appsforlife.com/"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://id.appsforlife.com/download/origami/mac-arm"
    regex(%r{origami/3/(\d+(?:\.\d+)+)/}i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# poly-lens — HP Poly Lens, manages headsets/video bars/room devices.
# WHY CUSTOM: nested pkgInDmg; the download URL embeds a non-derivable 4-part
# build twice (.../2.3.1.1775/2.3.1.1775/LensDesktop-2.3.1.1775.dmg) only
# obtainable from the GraphQL API; Apple-Silicon-only since 2.3.0.
# ---------------------------------------------------------------------------
resolve_poly_lens(){
  local json api="https://api.silica-prod01.io.lens.poly.com/graphql"
  json="$(curl -fsS "$api" \
    -H 'Content-Type: application/json' \
    --data '{"query":"{ availableProductSoftwareByPid(pid:\"lens-desktop-mac\"){ version productBuild{ archiveUrl } } }"}' 2>/dev/null)"
  URL="$(printf '%s' "$json" | grep -oE 'https?://[^"]+\.dmg' | head -1)"
  VERSION="$(printf '%s' "$json" | grep -oE '"version"[^,}]*' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  if [ -z "$URL" ]; then
    VERSION="2.3.1.1775"
    URL="https://swupdate.lens.poly.com/lens-desktop-mac/${VERSION}/${VERSION}/LensDesktop-${VERSION}.dmg"
  fi
  [ -n "$VERSION" ] || VERSION="2.3.1.1775"
  curl -fL "$URL" -o "$DL"
}
write_cask_poly_lens(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://swupdate.lens.poly.com/lens-desktop-mac/#{version}/#{version}/LensDesktop-#{version}.dmg",
      verified: "swupdate.lens.poly.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://api.silica-prod01.io.lens.poly.com/graphql"
    strategy :header_match
  end

  depends_on arch: :arm64
  depends_on macos: :$SYM

  pkg "LensDesktop-#{version}.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# postlab — Hedge PostLab, FCP/Premiere collaboration.
# WHY CUSTOM: the download path/filename embed a non-derivable build timestamp
# (20260429104609) and build (b254) not computable from version 26.1.3; the
# version comes from the docs releases page (page_match livecheck).
# ---------------------------------------------------------------------------
resolve_postlab(){
  VERSION="26.1.3"
  local stamp="20260429104609" build="b254"
  URL="https://updates.hedge.video/postlab/macos/updates/production/PostLab_${stamp}_v${VERSION}${build}/PostLab_${stamp}_v${VERSION}${build}.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_postlab(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "26.1.3"
  sha256 "$SHA"

  url "https://updates.hedge.video/postlab/macos/updates/production/PostLab_20260429104609_v#{version}b254/PostLab_20260429104609_v#{version}b254.dmg",
      verified: "updates.hedge.video/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://docs.hedge.video/postlab/releases"
    regex(/PostLab[._-]v?(\d+(?:\.\d+)+)/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# praxislive — visual live-coding IDE. Arch-split macOS .pkg installers whose
# release tag (v6.6.0-build1) differs from the version (6.6.0).
# WHY CUSTOM: arch-split pkg + tag/version skew -> neither github_tag nor
# github_arch (pkg unsupported) fits.
# ---------------------------------------------------------------------------
resolve_praxislive(){
  local tag repo="codelerity/praxislive-installers"
  tag="$(curl -sI "https://github.com/$repo/releases/latest" \
        | awk -F'/tag/' 'tolower($0)~/^location/{print $2}' | tr -d '\r')"
  [ -n "$tag" ] || tag="v6.6.0-build1"
  VERSION="$(printf '%s' "$tag" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || VERSION="6.6.0"
  URL="https://github.com/$repo/releases/download/$tag/PraxisLIVE-${VERSION}-arm64.pkg"
  curl -fL "$URL" -o "$DL"
  curl -fL "https://github.com/$repo/releases/download/$tag/PraxisLIVE-${VERSION}-x86_64.pkg" -o "$W/dl-x64" \
    && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" \
    || { echo "praxislive: intel pkg download failed" >&2; return 1; }
}
write_cask_praxislive(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  arch arm: "arm64", intel: "x86_64"

  version "$VERSION"
  on_arm do
    sha256 "$SHA"
  end
  on_intel do
    sha256 "$SHA_X64"
  end

  url "https://github.com/codelerity/praxislive-installers/releases/download/v#{version}-build1/PraxisLIVE-#{version}-#{arch}.pkg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://github.com/codelerity/praxislive-installers/releases/latest"
    regex(/PraxisLIVE[._-]v?(\d+(?:\.\d+)+)[._-].*\.pkg/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  pkg "PraxisLIVE-#{version}-#{arch}.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# prisma-access-browser — Palo Alto secure enterprise browser.
# WHY CUSTOM: the pkg filename carries a per-build hash suffix (-8711916a) not
# derivable from version; resolve via the release-manager redirect endpoint
# (redirect=false returns JSON with nextversion + sha256 for livecheck :json).
# ---------------------------------------------------------------------------
resolve_prisma_access_browser(){
  local appid="%7Bdfef2477-4f0e-454b-bc0d-03ce61074e4c%7D"
  local api="https://release-manager.us.gs.talon-sec.com/api/v1/latest?appid=${appid}&platform=mac&architecture=universal&channel=packaged&redirect=true"
  URL="$(curl -sIL "$api" | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  if [ -n "$URL" ]; then
    VERSION="$(basename "${URL%%\?*}" | grep -oE '[0-9]+(\.[0-9]+){2,}' | head -1)"
  fi
  if [ -z "$URL" ] || [ -z "$VERSION" ]; then
    VERSION="149.18.3.103"
    URL="https://updates.talon-sec.com/releases/Prisma%20Access%20Browser/mac/packaged/universal/Prisma%20Access%20Browser-${VERSION}-8711916a.pkg"
  fi
  curl -fL "$URL" -o "$DL"
}
write_cask_prisma_access_browser(){
  local fn; fn="$(basename "${URL%%\?*}")"
  cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://release-manager.us.gs.talon-sec.com/api/v1/latest?appid=%7Bdfef2477-4f0e-454b-bc0d-03ce61074e4c%7D&platform=mac&architecture=universal&channel=packaged&redirect=true",
      verified: "release-manager.us.gs.talon-sec.com/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://release-manager.us.gs.talon-sec.com/api/v1/latest?appid=%7Bdfef2477-4f0e-454b-bc0d-03ce61074e4c%7D&platform=mac&architecture=universal&channel=packaged&redirect=false"
    strategy :json do |json|
      json["nextversion"]
    end
  end

  depends_on macos: :$SYM

  pkg "$fn"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# setup-manager — jamf Setup Manager. github release; tag is plain v1.4.5 but
# the build (646) appears ONLY in the asset filename, not the tag.
# WHY CUSTOM: build-in-filename-only -> github_tag would hardcode the build and
# github_compound expects a v-<ver>-b-<build> tag. version "1.4.5,646".
# ---------------------------------------------------------------------------
resolve_setup_manager(){
  local tag repo="jamf/Setup-Manager" asset ver build
  tag="$(curl -sI "https://github.com/$repo/releases/latest" \
        | awk -F'/tag/' 'tolower($0)~/^location/{print $2}' | tr -d '\r')"
  [ -n "$tag" ] || tag="v1.4.5"
  ver="$(printf '%s' "$tag" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  asset="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep -oE 'Setup\.Manager-[0-9.]+-[0-9]+\.pkg' | head -1)"
  build="$(printf '%s' "$asset" | sed -E 's/.*-([0-9]+)\.pkg/\1/')"
  [ -n "$build" ] || build="646"
  VERSION="${ver},${build}"
  URL="https://github.com/$repo/releases/download/$tag/Setup.Manager-${ver}-${build}.pkg"
  curl -fL "$URL" -o "$DL"
}
write_cask_setup_manager(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/jamf/Setup-Manager/releases/download/v#{version.csv.first}/Setup.Manager-#{version.csv.first}-#{version.csv.second}.pkg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    regex(/Setup\.Manager-(\d+(?:\.\d+)+)-(\d+)\.pkg/i)
    strategy :github_latest do |json, regex|
      json["assets"].map do |asset|
        match = asset["name"]&.match(regex)
        next if match.blank?

        "#{match[1]},#{match[2]}"
      end
    end
  end

  depends_on macos: :$SYM

  pkg "Setup.Manager-#{version.csv.first}-#{version.csv.second}.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# sforzando — Plogue free SFZ player. Versioned dmg on s3 verified, but the
# whole plogue.com site returns 410 Gone to brew's UA (200 only to a full
# browser UA) -> no reachable homepage/version page for audit/livecheck.
# WHY CUSTOM: download verified but no clean livecheck page; header_match off
# the static s3 filename.
# ---------------------------------------------------------------------------
resolve_sforzando(){
  VERSION="1.982"
  URL="https://s3.amazonaws.com/sforzando/MAC_sforzando_v${VERSION}.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_sforzando(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "1.982"
  sha256 "$SHA"

  url "https://s3.amazonaws.com/sforzando/MAC_sforzando_v#{version}.dmg",
      verified: "s3.amazonaws.com/sforzando/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://s3.amazonaws.com/sforzando/MAC_sforzando_v#{version}.dmg"
    strategy :header_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# shellhistory — loshadki.app shell-history viewer. Nested appInZip; the URL
# filename carries only "3.1" (not the full 3.1.0) and there is no clean
# version-history page to livecheck. WHY CUSTOM: truncated version in URL +
# no livecheck source -> version "3.1.0" hardcoded, literal url with 3.1.
# ---------------------------------------------------------------------------
resolve_shellhistory(){
  VERSION="3.1.0"
  URL="https://loshadki.app/shellhistory/releases/ShellHistory-3.1.app.zip"
  curl -fL "$URL" -o "$DL"
}
write_cask_shellhistory(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "3.1.0"
  sha256 "$SHA"

  url "https://loshadki.app/shellhistory/releases/ShellHistory-#{version.major_minor}.app.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://loshadki.app/shellhistory/releases/ShellHistory-#{version.major_minor}.app.zip"
    strategy :header_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# slido-for-powerpoint — Slido desktop poller. The dmg filename carries only
# the build (r3325), not the 1.12.0 marketing version, so {v} can't template
# the URL. WHY CUSTOM: version "1.12.0" + literal build url + :sparkle
# livecheck on the appcast (shortVersionString).
# ---------------------------------------------------------------------------
resolve_slido_for_powerpoint(){
  local loc
  loc="$(curl -sIL "https://www.slido.com/api/download?application=powerpoint-mac" \
        | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  [ -n "$loc" ] || loc="https://download.slido.com/slido-for-mac/updates/SlidoForMac_r3325.dmg"
  VERSION="$(curl -fsSL "https://download.slido.com/slido-for-mac/updates/appcast.xml" 2>/dev/null \
        | grep -oE 'sparkle:shortVersionString="[0-9.]+"' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || VERSION="1.12.0"
  URL="$loc"; curl -fL "$URL" -o "$DL"
}
write_cask_slido_for_powerpoint(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "1.12.0"
  sha256 "$SHA"

  url "https://download.slido.com/slido-for-mac/updates/SlidoForMac_r3325.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://download.slido.com/slido-for-mac/updates/appcast.xml"
    strategy :sparkle
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# smart-mirror-app — SMART Mirror screen-mirroring. The pkg URL embeds a
# release-line path segment (4_49) AND a 4-part app version in the filename
# that don't share one interpolatable token. WHY CUSTOM: hand-authored url +
# page_match livecheck on the IQ3 downloads page.
# ---------------------------------------------------------------------------
resolve_smart_mirror_app(){
  VERSION="2.49.1.50573.101"
  URL="https://downloads.smarttech.com/software/smartmirror/4_49/mac/SMART_Mirror_App_${VERSION}.pkg"
  curl -fL "$URL" -o "$DL"
}
write_cask_smart_mirror_app(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "2.49.1.50573.101"
  sha256 "$SHA"

  url "https://downloads.smarttech.com/software/smartmirror/4_49/mac/SMART_Mirror_App_#{version}.pkg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://support.smarttech.com/docs/software/smart-mirror/en/downloads/mirror-apps/macos-iq3.cshtml"
    regex(/SMART[._ ]Mirror[._ ]App[._ ](\d+(?:\.\d+)+)\.pkg/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  pkg "SMART_Mirror_App_#{version}.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# snapgene — molecular-biology tool. A stable redirect resolves a dmg whose CDN
# path nests version components: SnapGene/<major>.x/<major>.<minor>/<full>/
# snapgene_<full>_mac.dmg. WHY CUSTOM: needs string transforms on the version
# (major / major_minor) not expressible with a single {v} token.
# ---------------------------------------------------------------------------
resolve_snapgene(){
  local loc
  loc="$(curl -sIL "https://www.snapgene.com/local/targets/download.php?os=mac" \
        | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  VERSION="$(basename "${loc%%\?*}" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || VERSION="8.2.2"
  local maj min; maj="${VERSION%%.*}"; min="${VERSION#*.}"; min="${min%%.*}"
  URL="https://cdn.snapgene.com/downloads/SnapGene/${maj}.x/${maj}.${min}/${VERSION}/snapgene_${VERSION}_mac.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_snapgene(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://cdn.snapgene.com/downloads/SnapGene/#{version.major}.x/#{version.major_minor}/#{version}/snapgene_#{version}_mac.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.snapgene.com/local/targets/download.php?os=mac"
    regex(/snapgene_(\d+(?:\.\d+)+)_mac\.dmg/i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}


#!/usr/bin/env bash
###############################################################################
# funcs-cc-chunk5.sh — CUSTOM resolve_/write_cask_ pairs for chunk5 apps that
# do not fit any built-in cask-master.sh SOURCE. Append-sourced by the harness
# (each app's source=custom). Token '-' -> '_' for the function suffix (<tfn>).
#
# Harness-set vars available inside these functions:
#   $TOKEN $NAME $DESC $HOMEPAGE $ARTIFACT $CASK $DL $W
#   (after resolve+sha+inspect): $VERSION $SHA $SHA_X64 $APP_NAME $RECEIPT
#   $BUNDLE_ID $SYM
# Helpers available: zap_for, die, curl.
#
# Facts come from progress/sourced/in-cc-chunk5.tsv notes (verified live).
# Inner pkg/app names inside dmg/zip containers are resolved on-Mac during the
# DRYRUN install; the literals below are best-known and may need a one-line
# tweak after the first DRYRUN (see per-app comments).
###############################################################################

# ---------------------------------------------------------------------------
# soundfield-by-rode — pkgInZip; opaque CMS ids in URL path won't survive {v}.
# zip contains "SoundField By RØDE.pkg" (no .app). Download host != homepage.
# ---------------------------------------------------------------------------
resolve_soundfield_by_rode(){
  VERSION="1.0.2"
  URL="https://edge.rode.com/zip/page/1890/modules/5329/SoundFieldByRODE_MAC_ver${VERSION}.pkg.zip"
  curl -fL "$URL" -o "$DL"
}
write_cask_soundfield_by_rode(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://edge.rode.com/zip/page/1890/modules/5329/SoundFieldByRODE_MAC_ver#{version}.pkg.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://rode.com/en-us/software/soundfield-by-rode"
    regex(/SoundFieldByRODE_MAC_ver(\d+(?:\.\d+)+)\.pkg\.zip/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  pkg "SoundField By RØDE.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# spyder-x-elite — pkgInZip; version only via redirect (sxe100). Inner pkg name
# resolved on-Mac (best-known: "Spyder X Elite.pkg"). Download host != homepage.
# ---------------------------------------------------------------------------
resolve_spyder_x_elite(){
  VERSION="6.3"
  URL="https://cdn.datacolor.com/spyder/SpyderXElite_${VERSION}.pkg.zip"
  curl -fL "$URL" -o "$DL"
}
write_cask_spyder_x_elite(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://cdn.datacolor.com/spyder/SpyderXElite_#{version}.pkg.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://goto.datacolor.com/download/mac/sxe100"
    regex(/SpyderXElite_(\d+(?:\.\d+)+)\.pkg\.zip/i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  pkg "Spyder X Elite.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# spyder-x-pro — pkgInZip; same shape as elite (sxp100). Inner pkg resolved
# on-Mac (best-known: "Spyder X Pro.pkg"). Download host != homepage.
# ---------------------------------------------------------------------------
resolve_spyder_x_pro(){
  VERSION="6.3"
  URL="https://cdn.datacolor.com/spyder/SpyderXPro_${VERSION}.pkg.zip"
  curl -fL "$URL" -o "$DL"
}
write_cask_spyder_x_pro(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://cdn.datacolor.com/spyder/SpyderXPro_#{version}.pkg.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://goto.datacolor.com/download/mac/sxp100"
    regex(/SpyderXPro_(\d+(?:\.\d+)+)\.pkg\.zip/i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  pkg "Spyder X Pro.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# starface — dmg filename embeds build (1789) + git short-hash (d191cf7) not
# derivable from version 10.0.0, so {v} can't build the URL. page_match on the
# KB download page. starface.com 401s automated clients; homepage is the KB.
# ---------------------------------------------------------------------------
resolve_starface(){
  VERSION="10.0.0"
  URL="https://www.starface-cdn.de/starface/clients/mac/STARFACE_10.0.0_1789_d191cf7.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_starface(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://www.starface-cdn.de/starface/clients/mac/STARFACE_10.0.0_1789_d191cf7.dmg",
      verified: "starface-cdn.de/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://knowledge.starface.de/pages/viewpage.action?pageId=46564694"
    regex(/STARFACE[._-](\d+(?:\.\d+)+)[._-]/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# strongdm — universal dmg via stable alias that 307s to a URL with a per-build
# hash path segment. Alias rejects HEAD (405), so the built-in direct_header
# resolver (HEAD-only) can't read it -> custom resolve via GET. livecheck
# :header_match on the alias (also GET-based via brew). Hash baked into the url
# (maintainer bumps it; livecheck tracks the version).
# ---------------------------------------------------------------------------
resolve_strongdm(){
  local alias="https://app.strongdm.com/downloads/client/darwin" real
  real="$(curl -sL -o /dev/null -w '%{url_effective}' "$alias")"
  [ -n "$real" ] || die "strongdm: could not resolve alias"
  VERSION="$(basename "$real" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$VERSION" ] || die "strongdm: could not parse version from $real"
  URL="$real"
  curl -fL "$URL" -o "$DL"
}
write_cask_strongdm(){
  local urlt host
  urlt="$(printf '%s' "$URL" | sed "s/${VERSION//./\\.}/#{version}/g")"
  host="$(printf '%s' "$URL" | sed -E 's#https?://([^/]+)/.*#\1#')"
  cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "$urlt"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://app.strongdm.com/downloads/client/darwin"
    regex(/SDM-(\d+(?:\.\d+)+)\.dmg/i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# studio-viewer — dmg; version uses dots (26.03) but filename uses underscores
# (Studio_Viewer_26_03.dmg) -> needs version.tr(".","_"). header_match on the
# Latest/Mac redirect. Download host != homepage.
# ---------------------------------------------------------------------------
resolve_studio_viewer(){
  VERSION="26.03"
  URL="https://cdn-my.esko.com/downloads/Public/Free/Latest/Studio_Viewer_${VERSION//./_}.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_studio_viewer(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://cdn-my.esko.com/downloads/Public/Free/Latest/Studio_Viewer_#{version.tr(".", "_")}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://mysoftware.esko.com/public/downloads/Free/StudioViewer/Latest/Mac"
    regex(/Studio_Viewer_(\d+(?:_\d+)+)\.dmg/i)
    strategy :header_match do |headers, regex|
      m = headers["content-disposition"]&.match(regex) || headers["location"]&.match(regex)
      next if m.blank?

      m[1].tr("_", ".")
    end
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# synology-active-backup-for-business-agent — pkgInDmg; inner pkg resolved
# on-Mac (best-known: "Synology Active Backup for Business Agent.pkg"). Full
# version "3.2.0-5053" used in both path and filename (single {v} ok), but the
# direct writer can't reference the inner pkg -> custom. page_match on archive.
# x86_64 build dir. Download host != homepage.
# ---------------------------------------------------------------------------
resolve_synology_active_backup_for_business_agent(){
  VERSION="3.2.0-5053"
  URL="https://global.download.synology.com/download/Utility/ActiveBackupBusinessAgent/${VERSION}/Mac/x86_64/Synology%20Active%20Backup%20for%20Business%20Agent-${VERSION}.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_synology_active_backup_for_business_agent(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://global.download.synology.com/download/Utility/ActiveBackupBusinessAgent/#{version}/Mac/x86_64/Synology%20Active%20Backup%20for%20Business%20Agent-#{version}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://archive.synology.com/download/Utility/ActiveBackupBusinessAgent"
    regex(/>(\d+(?:[.-]\d+)+)</i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  pkg "Synology Active Backup for Business Agent.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# synology-drive-client — pkgInDmg; version 4.0.3-17892 -> version.csv
# "4.0.3,17892": URL path uses full "4.0.3-17892" but FILENAME uses only build
# "17892" (synology-drive-client-17892.dmg) -> single {v} can't map both.
# Inner pkg resolved on-Mac (best-known: "Install Synology Drive Client.pkg").
# page_match on archive. Download host != homepage.
# ---------------------------------------------------------------------------
resolve_synology_drive_client(){
  VERSION="4.0.3,17892"
  local full="4.0.3-17892" build="17892"
  URL="https://global.download.synology.com/download/Utility/SynologyDriveClient/${full}/Mac/Installer/synology-drive-client-${build}.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_synology_drive_client(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://global.download.synology.com/download/Utility/SynologyDriveClient/#{version.csv.first}-#{version.csv.second}/Mac/Installer/synology-drive-client-#{version.csv.second}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://archive.synology.com/download/Utility/SynologyDriveClient"
    regex(%r{SynologyDriveClient[/-](\d+(?:\.\d+)+)-(\d+)}i)
    strategy :page_match do |page, regex|
      page.scan(regex).map { |m| "#{m[0]},#{m[1]}" }
    end
  end

  depends_on macos: :$SYM

  pkg "Install Synology Drive Client.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# universal-type-client — pkgInZip; version 7.0.13 but URL uses DASH form
# UTC-7-0-13-M.zip -> needs version.tr(".","-"). Inner pkg resolved on-Mac
# (best-known: "Universal Type Client.pkg"). page_match on the support page.
# Download host (bin.extensis.com) != homepage.
# ---------------------------------------------------------------------------
resolve_universal_type_client(){
  VERSION="7.0.13"
  URL="https://bin.extensis.com/UTC-${VERSION//./-}-M.zip"
  curl -fL "$URL" -o "$DL"
}
write_cask_universal_type_client(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://bin.extensis.com/UTC-#{version.tr(".", "-")}-M.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.extensis.com/support/universal-type-server-7/"
    regex(/UTC-(\d+(?:-\d+)+)-M\.zip/i)
    strategy :page_match do |page, regex|
      page.scan(regex).map { |m| m[0].tr("-", ".") }
    end
  end

  depends_on macos: :$SYM

  pkg "Universal Type Client.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# usher — dmg; filename is usher<version.no_dots>.dmg (2.4.1 -> usher241.dmg)
# -> needs version.no_dots. Sparkle appcast for livecheck. Download host
# (manytricks.com) == homepage host -> no verified. min macOS 10.13.
# ---------------------------------------------------------------------------
resolve_usher(){
  VERSION="2.4.1"
  URL="https://manytricks.com/download/_do_not_hotlink_/usher${VERSION//./}.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_usher(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://manytricks.com/download/_do_not_hotlink_/usher#{version.no_dots}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://manytricks.com/usher/appcast.xml"
    strategy :sparkle, &:short_version
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# windsurf — arch-split dmg via JSON update API; real dmg URL embeds a
# non-derivable commit-hash path segment -> custom + arch-split. Token windsurf
# (app rebranded "Devin"). livecheck :json field windsurfVersion. The JSON also
# carries sha256hash, but the harness recomputes from the downloads.
# ---------------------------------------------------------------------------
resolve_windsurf(){
  local api_arm="https://windsurf-stable.codeium.com/api/update/darwin-arm64-dmg/stable/latest"
  local api_x64="https://windsurf-stable.codeium.com/api/update/darwin-x64-dmg/stable/latest"
  local jarm jx64 uarm ux64
  jarm="$(curl -fsSL "$api_arm")"; jx64="$(curl -fsSL "$api_x64")"
  VERSION="$(printf '%s' "$jarm" | grep -oE '"windsurfVersion":"[^"]+"' | head -1 | sed -E 's/.*:"([^"]+)"/\1/')"
  [ -n "$VERSION" ] || die "windsurf: could not read windsurfVersion"
  uarm="$(printf '%s' "$jarm" | grep -oE '"url":"[^"]+"' | head -1 | sed -E 's/.*:"([^"]+)"/\1/')"
  ux64="$(printf '%s' "$jx64" | grep -oE '"url":"[^"]+"' | head -1 | sed -E 's/.*:"([^"]+)"/\1/')"
  [ -n "$uarm" ] && [ -n "$ux64" ] || die "windsurf: could not read dmg urls"
  URL="$uarm"; curl -fL "$URL" -o "$DL"
  curl -fL "$ux64" -o "$W/dl-x64" && SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')" || die "windsurf: x64 dmg download failed"
  WS_ARM="$uarm"; WS_X64="$ux64"
}
write_cask_windsurf(){
  local arm_t x64_t
  arm_t="$(printf '%s' "$WS_ARM" | sed "s/${VERSION//./\\.}/#{version}/g")"
  x64_t="$(printf '%s' "$WS_X64" | sed "s/${VERSION//./\\.}/#{version}/g")"
  cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 "$SHA"
    url "$arm_t",
        verified: "windsurf-stable.codeiumdata.com/"
  end
  on_intel do
    sha256 "$SHA_X64"
    url "$x64_t",
        verified: "windsurf-stable.codeiumdata.com/"
  end

  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://windsurf-stable.codeium.com/api/update/darwin-arm64-dmg/stable/latest"
    strategy :json do |json|
      json["windsurfVersion"]
    end
  end

  auto_updates true
  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# wonderpen — universal dmg; 4-part version (3.1.3.8431) plus a minor-version
# subdir (/3.1/) in the path neither of which fits a single {v} template.
# Versioned URL via tominlab CDN proxy (302 -> file.tominlab.com).
# Subdir = first two version components. page_match on the downloads page.
# ---------------------------------------------------------------------------
resolve_wonderpen(){
  VERSION="3.1.3.8431"
  local minor="3.1"
  URL="https://www.tominlab.com/to/get-file/cdn?file=WonderPen/desktop/${minor}/WonderPen-v${VERSION}-mac-universal.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_wonderpen(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://www.tominlab.com/to/get-file/cdn?file=WonderPen/desktop/#{version.major_minor}/WonderPen-v#{version}-mac-universal.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.tominlab.com/en/wonderpen/downloads/all"
    regex(/WonderPen-v(\d+(?:\.\d+)+)-mac-universal\.dmg/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# workbrew — plain pkg; only public source is the stable UNVERSIONED redirect
# (console.workbrew.com/downloads/macos 303 -> signed GitHub asset that
# EXPIRES). No public versioned URL -> url is the stable unversioned redirect;
# header_match on it for the version. Receipt resolved on-Mac.
# ---------------------------------------------------------------------------
resolve_workbrew(){
  local short="https://console.workbrew.com/downloads/macos" cd
  cd="$(curl -sIL "$short" | grep -i '^content-disposition' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  [ -n "$cd" ] || cd="$(curl -sL -o /dev/null -w '%{url_effective}' "$short" | grep -oE 'Workbrew-[0-9]+(\.[0-9]+)+' | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  VERSION="$cd"
  [ -n "$VERSION" ] || die "workbrew: could not parse version"
  URL="$short"
  curl -fL "$URL" -o "$DL"
}
write_cask_workbrew(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 :no_check

  url "https://console.workbrew.com/downloads/macos"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://console.workbrew.com/downloads/macos"
    regex(/Workbrew-(\d+(?:\.\d+)+)\.pkg/i)
    strategy :header_match
  end

  depends_on macos: :$SYM

  pkg "Workbrew-#{version}.pkg"

  uninstall pkgutil: "$RECEIPT"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# xmlmind — dmg; filename encodes version with underscores (xxe-perso-11_1_0)
# -> needs version.tr(".","_"). XMLmind XML Editor Personal Edition. Bundles a
# private OpenJDK. page_match on the download page. Download host == homepage.
# ---------------------------------------------------------------------------
resolve_xmlmind(){
  VERSION="11.1.0"
  URL="https://www.xmlmind.com/xmleditor/_download/xxe-perso-${VERSION//./_}.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask_xmlmind(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://www.xmlmind.com/xmleditor/_download/xxe-perso-#{version.tr(".", "_")}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://www.xmlmind.com/xmleditor/download.shtml"
    regex(/xxe-perso-(\d+(?:_\d+)+)\.dmg/i)
    strategy :page_match do |page, regex|
      page.scan(regex).map { |m| m[0].tr("_", ".") }
    end
  end

  depends_on macos: :$SYM

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}

# ---------------------------------------------------------------------------
# zaxconvert — combined PC+MAC zip whose Mac app is itself a NESTED zip
# ("ZaxConvert MAC v6.68.zip") under a versioned top dir; WordPress date-path
# URL (/2025/08/) that doesn't derive from version; current build is BETA.
# nested_container unpacks the inner zip; app resolved on-Mac. No stable
# livecheck (date path + beta) -> page_match on the downloads page.
# ---------------------------------------------------------------------------
resolve_zaxconvert(){
  VERSION="6.68"
  URL="https://zaxcom.com/wp-content/uploads/2025/08/Zaxconvert_${VERSION}_PC_MAC-BETA.zip"
  curl -fL "$URL" -o "$DL"
}
write_cask_zaxconvert(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://zaxcom.com/wp-content/uploads/2025/08/Zaxconvert_#{version}_PC_MAC-BETA.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://zaxcom.com/support/downloads/"
    regex(/Zaxconvert[._-](\d+(?:\.\d+)+)[._-]PC_MAC/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  nested_container "Zaxconvert_#{version}_PC_MAC-BETA/ZaxConvert MAC v#{version}.zip"

  app "$APP_NAME"
$(zap_for "$BUNDLE_ID")
end
RB
}


run_one(){
  set -uo pipefail
  STAGE=init; STATUS=incomplete
  VERSION=""; URL=""; SHA=""; SHA_X64=""; BUNDLE_ID=""; MINOS=""; SYM=""; RECEIPT=""; LABELS=""; MAU=""
  STYLE_OUT=""; AUDIT=""; LIVECHECK_OUT=""; PR=""; FR=""; REFUSED=""; AUTOFIX=""; APP_NAME=""
  MS_REAL=""; MS_URLT=""; DH_URLT=""; TAG=""; TAGI=""
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
    sec "brew livecheck --cask (info only)" "${LIVECHECK_OUT:-(not run)}"
    [ -f "$W/install.log" ]   && sec "brew install --cask"   "$(cat "$W/install.log")"
    [ -f "$W/uninstall.log" ] && sec "brew uninstall --cask" "$(cat "$W/uninstall.log")"
    [ -f "$W/install2.log" ]  && sec "brew install --cask (reinstall / idempotency)" "$(cat "$W/install2.log")"
    [ -f "$W/zap.log" ]       && sec "brew uninstall --zap --cask" "$(cat "$W/zap.log")"
    sec "git" "$(git -C "$TAP" status -s 2>/dev/null; echo '--- last commit ---'; git -C "$TAP" log --oneline -1 2>/dev/null)"
    sec "Progress log" "$(cat "$S")"
    if [ "$DRYRUN" = 1 ] && [ -f "$CASK" ]; then
      # DRYRUN writes the cask untracked on $DEF (no branch): keep a copy in $W
      # and remove it from the tap so the tap is left clean even on failure.
      cp "$CASK" "$W/$TOKEN.rb" 2>/dev/null; rm -f "$CASK"
    fi
    emit_result
    echo; echo "==== review bundle for $TOKEN ($STATUS) — full report at $REPORT ===="
  }
  die(){ STATUS="failed"; log "[$TOKEN] $1"; report; exit 1; }

  cd "$TAP" || { echo "cannot cd tap"; exit 1; }
  STAGE="precheck"
  if brew info --cask "$TOKEN" >/dev/null 2>&1; then
    STATUS="skipped (cask exists upstream)"
    log "[$TOKEN] a cask already exists in homebrew-cask — skipping the PR. File a Fleet FR for the existing cask separately if needed."
    report; exit 0
  fi
  brew info --formula "$TOKEN" >/dev/null 2>&1 && log "[$TOKEN] WARNING: token collides with a homebrew-core formula — rename (e.g. ${TOKEN}-desktop) or audit will reject it"
  if [ "$DRYRUN" != 1 ]; then
    # base was synced once before the batch; branch per app only on live runs
    git checkout -q "$DEF" 2>/dev/null
    git branch -D "add-$TOKEN" >/dev/null 2>&1 || true; git checkout -q -b "add-$TOKEN"
    [ "$FRESH" = 1 ] && git push "$FORK" --delete "add-$TOKEN" >/dev/null 2>&1 || true
  fi

  STAGE="resolve"
  if [ -f "$W/resolved.env" ] && grep -q '^RESOLVED_OK=1' "$W/resolved.env"; then
    . "$W/resolved.env"
    log "[$TOKEN] using prefetched download (version ${VERSION:-?})"
  else
    [ -s "$W/prefetch.log" ] && log "[$TOKEN] prefetch did not complete ($W/prefetch.log) — resolving serially"
    resolve
  fi
  [ -s "$DL" ] || die "download failed (resolve produced no file at \$DL)"
  STAGE="sha";       SHA="$(shasum -a 256 "$DL" | awk '{print $1}')"
  STAGE="inspect";   inspect
  STAGE="write";     write_cask; [ -f "$CASK" ] || die "write_cask did not create $CASK"; inject_rosetta
  STAGE="style";     brew style --fix "$TOKEN" >/dev/null 2>&1; STYLE_OUT="$(brew style "$TOKEN" 2>&1)"
  STAGE="audit";     AUDIT="$(brew audit --cask $SFLAG --online --new "$TOKEN" 2>&1)"
  # anchor on brew's real failure shapes ("Error:", "N problems in ...") so a
  # token/desc containing words like "fail" can't false-positive the audit check
  issues(){ printf '%s' "$STYLE_OUT" | grep -qE '[1-9][0-9]* offense' || printf '%s' "$AUDIT" | grep -qE '(^|[[:space:]])Error:|[1-9][0-9]* (problems?|errors?)'; }
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
  if [ "$LIVECHECK" = 1 ]; then
    STAGE="livecheck"; LIVECHECK_OUT="$(brew livecheck --cask "$TOKEN" 2>&1 || true)"
  fi
  if [ "$DRYRUN" != 1 ]; then git add "$CASK"; git commit -q -m "Add $TOKEN (new cask)" 2>/dev/null || true; fi
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
  # drop brew's cached installer for this cask so a long live run can't fill the disk
  if [ "$KEEP" != 1 ]; then
    BC="$(brew --cache --cask "$TOKEN" 2>/dev/null || true)"
    [ -n "$BC" ] && rm -f "$BC" 2>/dev/null
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
# Select the apps to run (ONLY / START_AT / LIMIT / SKIP_PASSED), parsed up front
# so the sudo check and the prefetcher only consider what will actually run.
# ----------------------------------------------------------------------------
declare -a T_TOKEN=() T_NAME=() T_DESC=() T_ART=() T_SRC=() T_HP=() T_SPEC=()
declare -a PB_TOK=() PB_WHY=()
started=1; [ -n "$START_AT" ] && started=0
nskip=0
for line in "${ROWS[@]}"; do
  IFS='|' read -r c1 c2 c3 c4 c5 c6 c7 <<< "$line"
  tok="$(trim "$c1")"; [ -z "$tok" ] && continue
  if [ -n "$ONLY" ]; then case " $ONLY " in *" $tok "*) ;; *) continue;; esac; fi
  if [ "$started" = 0 ]; then [ "$tok" = "$START_AT" ] && started=1 || continue; fi
  if [ "$SKIP_PASSED" = 1 ] && [ -f "$ROOT/$tok/result.env" ]; then
    pst="$(grep '^STATUS=' "$ROOT/$tok/result.env" 2>/dev/null | cut -d= -f2-)"
    case "$pst" in
      success*|skipped*) nskip=$((nskip+1)); continue;;
      dryrun*) if [ "$DRYRUN" = 1 ]; then nskip=$((nskip+1)); continue; fi;;
    esac
  fi
  if [ -n "${POLICY_BLOCKED[$tok]:-}" ] && [ "$RUN_BLOCKED" != 1 ]; then
    PB_TOK+=("$tok"); PB_WHY+=("${POLICY_BLOCKED[$tok]}"); continue
  fi
  if [ -n "$LIMIT" ] && [ "${#T_TOKEN[@]}" -ge "$LIMIT" ]; then break; fi
  T_TOKEN+=("$tok"); T_NAME+=("$(trim "$c2")"); T_DESC+=("$(trim "$c3")")
  T_ART+=("$(trim "$c4")"); T_SRC+=("$(trim "$c5")"); T_HP+=("$(trim "$c6")"); T_SPEC+=("$(trim "$c7")")
done
[ "$nskip" -gt 0 ] && echo "SKIP_PASSED=1 — skipping $nskip app(s) that already passed (reports under $ROOT)."
if [ "${#T_TOKEN[@]}" -eq 0 ]; then
  if [ "${#PB_TOK[@]}" -gt 0 ]; then
    echo "Nothing to run: the selection matched only POLICY_BLOCKED app(s) — known brew-audit policy rejections (NOT-ADDED.md §2). Re-test with RUN_BLOCKED=1:"
    for _k in "${!PB_TOK[@]}"; do echo "  - ${PB_TOK[$_k]} — ${PB_WHY[$_k]}"; done
  else
    echo "Nothing to run (ONLY/START_AT/LIMIT/SKIP_PASSED selected 0 apps)."
  fi
  exit 0
fi

# ----------------------------------------------------------------------------
# Sudo: ask ONCE, then cache for the entire run so per-app install/uninstall/zap
# never re-prompt. pkg installs (and pkg uninstall/zap) shell out to sudo many
# times; a short system timestamp_timeout (or tty_tickets) defeats the classic
# "keep the timestamp warm" trick and you get prompted on every step. So by
# default we prompt once and install a TEMPORARY passwordless sudoers drop-in
# for the current user, removed automatically when the run ends (even on Ctrl-C).
#   SUDO_NOPASSWD=1 (default): one prompt -> temp /etc/sudoers.d entry -> zero
#                              further prompts; auto-removed on exit.
#   SUDO_NOPASSWD=0          : don't touch sudoers — just keep the credential
#                              timestamp warm (may re-prompt if the OS expires it).
# ----------------------------------------------------------------------------
SUDO_NOPASSWD="${SUDO_NOPASSWD:-1}"
NEED_SUDO=0
for _i in "${!T_TOKEN[@]}"; do
  { [ "${T_ART[$_i]}" = pkg ] || [ "${T_SRC[$_i]}" = msft_cdn ]; } && NEED_SUDO=1
done
SUDOERS_FILE=""
declare -a PFPID=()
cleanup_sudo(){ [ -n "${SUDOERS_FILE:-}" ] && sudo rm -f "$SUDOERS_FILE" 2>/dev/null; [ -n "${SUDO_PID:-}" ] && kill "$SUDO_PID" 2>/dev/null; }
cleanup_run(){ local p; for p in "${PFPID[@]:-}"; do [ -n "$p" ] && [ "$p" != 0 ] && kill "$p" 2>/dev/null; done; cleanup_sudo; }
trap cleanup_run EXIT INT TERM
if [ "$DRYRUN" != 1 ] && [ "$NEED_SUDO" = 1 ]; then
  echo "Priming sudo once — enter your password a single time; it's cached for the whole run."
  sudo -v || { echo "sudo is required for pkg installs/uninstalls"; exit 1; }
  if [ "$SUDO_NOPASSWD" = 1 ]; then
    SUDOERS_FILE="/etc/sudoers.d/cask-master-$$"
    if printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$(id -un)" | sudo tee "$SUDOERS_FILE" >/dev/null 2>&1 \
       && sudo chmod 440 "$SUDOERS_FILE" 2>/dev/null \
       && sudo visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then
      echo "  ✓ passwordless sudo enabled for THIS run only ($SUDOERS_FILE; auto-removed on exit)."
    else
      sudo rm -f "$SUDOERS_FILE" 2>/dev/null; SUDOERS_FILE=""
      echo "  (couldn't install a temp sudoers drop-in — keeping the sudo timestamp warm instead.)"
      ( while true; do sudo -n true 2>/dev/null; sleep 30; kill -0 "$$" 2>/dev/null || exit; done ) & SUDO_PID=$!
    fi
  else
    ( while true; do sudo -n true 2>/dev/null; sleep 30; kill -0 "$$" 2>/dev/null || exit; done ) & SUDO_PID=$!
  fi
fi

# ----------------------------------------------------------------------------
# Sync the tap base ONCE (was per-app). DRYRUN never leaves $DEF; live runs
# branch per app off this base.
# ----------------------------------------------------------------------------
git -C "$TAP" checkout -q "$DEF" 2>/dev/null || true
# Base the run on UPSTREAM's tip when an upstream remote exists: in a fork-clone
# tap, origin is the fork and forks don't auto-sync — a stale base makes the
# duplicate precheck (`brew info --cask`, API disabled) miss casks merged
# upstream since, and the script would open duplicate PRs. Fall back to a plain
# pull (the old behavior) when there's no upstream remote.
if git -C "$TAP" remote get-url upstream >/dev/null 2>&1; then
  git -C "$TAP" fetch -q upstream "$DEF" 2>/dev/null \
    && git -C "$TAP" merge -q --ff-only "upstream/$DEF" 2>/dev/null || true
else
  git -C "$TAP" pull -q --ff-only 2>/dev/null || true
fi

# ----------------------------------------------------------------------------
# Parallel prefetch: resolve + download up to JOBS apps ahead. Built-in source
# types only — custom resolve_<tfn> functions may set extra variables their
# writers need, so custom rows always resolve serially inside run_one. Each
# prefetch runs in its own $W; disk stays bounded because the main loop deletes
# each app's download as soon as the app finishes (unless KEEP=1).
# ----------------------------------------------------------------------------
PF_VARS="VERSION URL TAG TAGI SHA_X64 MS_REAL MS_URLT DH_URLT"
start_prefetch(){
  local i="$1" tok tfn
  [ -n "${PFPID[$i]:-}" ] && return 0
  tok="${T_TOKEN[$i]}"; tfn="${tok//-/_}"
  case "${T_SRC[$i]}" in
    github_tag|github_arch|github_compound|electron|msft_cdn|direct|direct_latest|direct_arch|direct_header) ;;
    *) PFPID[$i]=0; return 0;;
  esac
  declare -F "resolve_$tfn" >/dev/null && { PFPID[$i]=0; return 0; }
  (
    TOKEN="$tok"; TFN="$tfn"; NAME="${T_NAME[$i]}"; ARTIFACT="${T_ART[$i]}"
    SOURCE="${T_SRC[$i]}"; HOMEPAGE="${T_HP[$i]}"
    W="$ROOT/$tok"; DL="$W/dl"
    rm -rf "$W"; mkdir -p "$W"
    exec >"$W/prefetch.log" 2>&1
    die(){ echo "[$TOKEN] prefetch: $*"; exit 1; }
    VERSION=""; URL=""; TAG=""; TAGI=""; SHA_X64=""; MS_REAL=""; MS_URLT=""; DH_URLT=""
    parse_spec "${T_SPEC[$i]}"
    if resolve && [ -s "$DL" ]; then
      { for v in $PF_VARS; do printf '%s=%q\n' "$v" "${!v}"; done; echo "RESOLVED_OK=1"; } > "$W/resolved.env"
    fi
  ) & PFPID[$i]=$!
}

# ----------------------------------------------------------------------------
# Run the batch
# ----------------------------------------------------------------------------
NTOT="${#T_TOKEN[@]}"
{ echo "# Master cask run — $(date)"; echo; echo "Mode: $([ "$DRYRUN" = 1 ] && echo DRYRUN || echo LIVE)  |  base: $DEF  |  fork: ${FORK_OWNER:-?}  |  apps: $NTOT  |  jobs: $JOBS"; echo; } > "$MASTER"
printf 'token\tstatus\tstage\tversion\tpr\tfr\treport\n' > "$RESULTS"
if [ "${#PB_TOK[@]}" -gt 0 ]; then
  echo "Policy-blocked: skipping ${#PB_TOK[@]} app(s) a prior full audit proved unshippable (NOT-ADDED.md §2; RUN_BLOCKED=1 re-tests them)."
  for _k in "${!PB_TOK[@]}"; do
    _t="${PB_TOK[$_k]}"; _why="${PB_WHY[$_k]}"
    mkdir -p "$ROOT/$_t"
    { echo "TOKEN=$_t"; echo "STATUS=skipped (policy-blocked)"; echo "STAGE=policy"
      echo "PR="; echo "FR="; echo "VERSION="; } > "$ROOT/$_t/result.env"
    [ -f "$ROOT/$_t/report.md" ] || printf '# Cask run report — %s\n\n- Outcome: **skipped (policy-blocked)**\n- Reason: %s\n' "$_t" "$_why" > "$ROOT/$_t/report.md"
    printf '%s\tskipped (policy-blocked)\tpolicy\t\t\t\t%s\n' "$_t" "$ROOT/$_t/report.md" >> "$RESULTS"
    printf -- '- **%s** — skipped (policy-blocked: %s)\n' "$_t" "$_why" >> "$MASTER"
  done
fi
NFAIL=0; FAILED_TOKENS=""
for i in "${!T_TOKEN[@]}"; do
  if [ "$JOBS" -gt 0 ] 2>/dev/null; then
    for (( j=i; j<i+JOBS && j<NTOT; j++ )); do start_prefetch "$j"; done
    [ "${PFPID[$i]:-0}" != 0 ] && wait "${PFPID[$i]}" 2>/dev/null || true
  fi
  TOKEN="${T_TOKEN[$i]}"; NAME="${T_NAME[$i]}"; DESC="${T_DESC[$i]}"
  ARTIFACT="${T_ART[$i]}"; SOURCE="${T_SRC[$i]}"; HOMEPAGE="${T_HP[$i]}"; SPEC="${T_SPEC[$i]}"
  TFN="${TOKEN//-/_}"
  parse_spec "$SPEC"
  W="$ROOT/$TOKEN"; DL="$W/dl"
  # prefetched apps already have a fresh $W (made by the prefetch subshell)
  if [ "${PFPID[$i]:-0}" = 0 ]; then rm -rf "$W"; mkdir -p "$W"; fi
  n=$((i+1))

  echo; echo "════ [$n/$NTOT] $TOKEN  ($NAME) — source=$SOURCE artifact=$ARTIFACT ════"
  ( run_one ); rc=$?

  if [ "$DRYRUN" != 1 ]; then
    git -C "$TAP" checkout -q "$DEF" 2>/dev/null || true
    git -C "$TAP" branch -D "add-$TOKEN" >/dev/null 2>&1 || true
  fi
  # disk hygiene: drop the download + extracted tree as soon as the app is done
  # (reports/logs/casks in $W are kept). KEEP=1 keeps everything.
  [ "$KEEP" = 1 ] || rm -rf "$W/dl" "$W/dl-x64" "$W/x"

  st="?"; stg="?"; ver=""; pr=""; fr=""
  if [ -f "$W/result.env" ]; then
    st="$(grep '^STATUS=' "$W/result.env" | cut -d= -f2-)"
    stg="$(grep '^STAGE=' "$W/result.env" | cut -d= -f2-)"
    ver="$(grep '^VERSION=' "$W/result.env" | cut -d= -f2-)"
    pr="$(grep '^PR=' "$W/result.env" | cut -d= -f2-)"
    fr="$(grep '^FR=' "$W/result.env" | cut -d= -f2-)"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$TOKEN" "$st" "$stg" "$ver" "$pr" "$fr" "$W/report.md" >> "$RESULTS"
  printf -- '- **%s** — %s%s%s  _(report: %s)_\n' "$TOKEN" "$st" "${pr:+ — PR: $pr}" "${fr:+ — FR: $fr}" "$W/report.md" >> "$MASTER"
  echo "──── $TOKEN: $st ${pr:+| PR=$pr} ${fr:+| FR=$fr}"
  case "$st" in success*|dryrun*|skipped*) ;; *) NFAIL=$((NFAIL+1)); FAILED_TOKENS+="$TOKEN ";; esac

  if [ "$rc" != 0 ] && [ "$STOP_ON_FAIL" = 1 ]; then
    echo "STOP_ON_FAIL=1 and $TOKEN did not succeed — stopping the batch."; break
  fi
done

{ echo; echo "## Totals"; echo
  echo "- ran: $NTOT  |  failed: $NFAIL  |  policy-skipped: ${#PB_TOK[@]}  |  results: $RESULTS"
  if [ "$NFAIL" -gt 0 ]; then
    echo; echo "## Failed (re-run just these: SKIP_PASSED=1, or ONLY=\"$(trim "$FAILED_TOKENS")\")"; echo
    for t in $FAILED_TOKENS; do echo "- $t — $ROOT/$t/report.md"; done
  fi; } >> "$MASTER"

echo; echo "===================================================================="
echo " MASTER SUMMARY — $MASTER"
echo "===================================================================="
cat "$MASTER"
echo
echo "Machine-readable rollup: $RESULTS"
echo "For any app that failed, open $ROOT/<token>/report.md and paste it back for a targeted fix."
if [ "$NFAIL" -gt 0 ]; then exit 1; fi
exit 0
