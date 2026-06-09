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
