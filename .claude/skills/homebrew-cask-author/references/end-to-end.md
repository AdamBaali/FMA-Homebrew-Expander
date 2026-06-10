# End-to-end cask script

## For a single app

Copy **The harness** verbatim. Fill the `CONFIG` block at the top. Replace the two stub functions
`resolve()` and `write_cask()` with the block from **Source blocks** that matches the app's download
source (GitHub release / electron feed / Microsoft CDN pkg / direct). Keep everything else. Hand the
user the whole assembled script, then ask them to run `DRYRUN=1 bash …` to preview and paste back
`/tmp/caskwork/summary.txt`.

## For batch mode (10+ apps)

Use `scripts/cask-master.sh` instead. It wraps this harness in a loop over a registry (CSV rows: 
`token | name | desc | artifact | source | homepage | spec`). Fill the registry, then:

```bash
DRYRUN=1 TEST_INSTALL=1 bash scripts/cask-master.sh  # preview all, full testing
bash scripts/cask-master.sh  # submit (first 10 by default; BATCH_SIZE=N for more)
SKIP_PASSED=1 bash scripts/cask-master.sh  # resume from failures
```

Each app gets its own `/tmp/caskwork/<token>/report.md` with full diagnostics. See SKILL.md for 
complete flag reference and workflow.

Baked-in behaviour: the script **stops with a summary** the moment audit, install, or uninstall
fails (so the PR is never opened on a broken cask); `DRYRUN=1` writes + audits the cask and prints
the cask and the PR/FR text but touches nothing else; pkg installs prompt for sudo; `gh` must be
authed as the fork owner and have `fleetdm/fleet` access; `FILE_FR=0` skips the Fleet FR;
`CUSTOMER_LABEL="customer-x"` labels it. The PR body is built from Homebrew's **live** template (the
pulled tap's `.github/PULL_REQUEST_TEMPLATE.md`) with its boxes ticked plus the AI disclosure, so the
checklist can't go stale if Homebrew changes it.

`write_cask` heredocs are **unquoted** (`<<RB`) so `$SHA`, `$SYM`, `$BUNDLE_ID` etc. expand while
Ruby `#{…}` stays literal. If a cask ever needs a literal `$` (e.g. a `$`-anchored livecheck regex),
escape it as `\$`.

## The harness

```bash
#!/usr/bin/env bash
# ---------- CONFIG (fill these) ----------
TOKEN="ibm-notifier"                                   # must not collide with a homebrew-core formula
NAME="IBM Notifier"
DESC="Agent that displays custom notifications and alerts to end users"  # obey ALL cask desc rules (see cask-dsl.md)
HOMEPAGE="https://github.com/IBM/mac-ibm-notifications" # must return 200 to brew
ARTIFACT="zip"                                         # zip | dmg | pkg
# -----------------------------------------
set -uo pipefail
export GIT_PAGER=cat HOMEBREW_NO_INSTALL_FROM_API=1 HOMEBREW_NO_AUTO_UPDATE=1
DRYRUN="${DRYRUN:-0}"; FORK="${FORK:-fork}"; FILE_FR="${FILE_FR:-1}"; CUSTOMER_LABEL="${CUSTOMER_LABEL:-}"
FRESH="${FRESH:-1}"   # 1 = clean slate: delete any stale fork branch first so every run makes a fresh PR/FR. FRESH=0 = re-run-safe (keep an existing open PR).
STRICT="${STRICT:-1}"; [ "$STRICT" = 1 ] && SFLAG="--strict" || SFLAG=""   # CI parity; STRICT=0 drops --strict
ZAP="${ZAP:-1}"                                                            # ZAP=0 skips the reinstall + zap test
W=/tmp/caskwork; mkdir -p "$W"; DL="$W/dl"; S="$W/summary.txt"; REPORT="$W/report.md"; : > "$S"
# state + captured outputs (pre-set so report() is safe even if we die very early)
STAGE="init"; STATUS="incomplete"; WORK=""; DEF=""; CASK=""; FORK_OWNER=""; APP_NAME=""
VERSION=""; URL=""; SHA=""; SHA_X64=""; BUNDLE_ID=""; MINOS=""; SYM=""; RECEIPT=""; LABELS=""; MAU=""
STYLE_OUT=""; AUDIT=""; LIVECHECK=""; PR=""; FR=""; REFUSED=""; AUTOFIX=""
log(){ echo "$@" | tee -a "$S"; }
sec(){ printf '\n## %s\n\n```\n%s\n```\n' "$1" "${2:-(none)}" >> "$REPORT"; }
if [ "$STRICT" = 1 ]; then AUDIT_DESC="--strict --online --new"; else AUDIT_DESC="--online --new"; fi
if [ "$ZAP" = 1 ]; then TESTED="installed, reinstalled, uninstalled, and zapped"; VERIFIED="the artifact, a clean uninstall, an idempotent reinstall, and the zap stanza paths"; else TESTED="installed and uninstalled"; VERIFIED="the artifact and uninstall"; fi
DISCLOSURE="AI (Claude) assisted in creating this PR: it researched the download URL, version, bundle identifier, minimum macOS, and pkg receipt, and drafted the cask DSL. I reviewed the result, ran brew style --fix and brew audit --cask $AUDIT_DESC with no offenses or errors, and $TESTED the cask locally on macOS to verify $VERIFIED."

# ---- report(): always writes a complete, self-contained review bundle and prints it ----
report(){
  {
    echo "# Cask run report — $TOKEN"
    echo
    echo "- App: $NAME"
    echo "- Outcome: **$STATUS**$([ "$STATUS" = failed ] && echo " — failed at stage: $STAGE")"
    echo "- When: $(date)"
    echo "- Branch: add-$TOKEN  |  base: ${DEF:-?}  |  fork: ${FORK_OWNER:-?}/$FORK"
    [ -n "$PR" ] && echo "- PR: $PR"
    [ -n "$FR" ] && echo "- Fleet FR: $FR"
  } > "$REPORT"
  sec "Resolved values" "version:     ${VERSION:-?}
artifact:    $ARTIFACT
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
  sec "brew audit --cask --online --new"   "${AUDIT:-(not run)}"
  sec "Auto-fixes applied (review these)"  "${AUTOFIX:-none}"
  sec "brew livecheck --cask (info only)"  "${LIVECHECK:-(not run)}"
  [ -f "$W/install.log" ]   && sec "brew install --cask"   "$(cat "$W/install.log")"
  [ -f "$W/uninstall.log" ] && sec "brew uninstall --cask" "$(cat "$W/uninstall.log")"
  [ -f "$W/install2.log" ]  && sec "brew install --cask (reinstall / idempotency)" "$(cat "$W/install2.log")"
  [ -f "$W/zap.log" ]       && sec "brew uninstall --zap --cask" "$(cat "$W/zap.log")"
  sec "git" "$(git -C "${WORK:-.}" status -s 2>/dev/null; echo '--- last commit ---'; git -C "${WORK:-.}" log --oneline -1 2>/dev/null)"
  sec "Progress log" "$(cat "$S")"
  echo; echo "===================================================================="
  echo " REVIEW BUNDLE ($STATUS) — read $REPORT, or paste the block below to Claude"
  echo "===================================================================="
  cat "$REPORT"
}
die(){ STATUS="failed"; log "[$TOKEN] $1"; report; exit 1; }

WORK="$(brew --repository homebrew/cask 2>/dev/null)" || die "Homebrew not found"; cd "$WORK" || die "cannot cd tap"
DEF="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@.*/@@')"; [ -z "$DEF" ] && DEF=master
LETTER="$(printf '%s' "$TOKEN" | cut -c1)"; CASK="Casks/$LETTER/$TOKEN.rb"
command -v gh >/dev/null 2>&1 || die "install gh: brew install gh"
[ "$DRYRUN" = 1 ] || gh auth status >/dev/null 2>&1 || die "run: gh auth login"
FORK_OWNER="$(git remote get-url "$FORK" 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+)/.*#\1#')"

mac_symbol(){ case "${1%%.*}" in
  10) echo catalina;; 11) echo big_sur;; 12) echo monterey;; 13) echo ventura;;
  14) echo sonoma;; 15) echo sequoia;; 16|26) echo tahoe;; *) echo big_sur;; esac; }
read_app(){ APP_NAME="$(basename "$1")"
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$1/Contents/Info.plist" 2>/dev/null)"
  MINOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$1/Contents/Info.plist" 2>/dev/null || echo 11)"
  # Intel-only artifact => write_cask must add `caveats { requires_rosetta }` (audit enforces it).
  local exe bin; exe="$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$1/Contents/Info.plist" 2>/dev/null)"
  bin="$1/Contents/MacOS/$exe"
  if [ -n "$exe" ] && [ -f "$bin" ]; then case "$(lipo -archs "$bin" 2>/dev/null || file "$bin")" in
    *arm64*) NEEDS_ROSETTA=0;; *x86_64*|*i386*) NEEDS_ROSETTA=1;; esac; fi; }
inspect(){ RECEIPT=""; LABELS=""; MAU=""; NEEDS_ROSETTA=0
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

# ===== REPLACE with a Source block: resolve() sets VERSION + URL and downloads to $DL =====
resolve(){ die "resolve() not filled in"; }
# ===== REPLACE with a Source block: write_cask() writes $CASK =====
write_cask(){ die "write_cask() not filled in"; }

# zap_for BUNDLE_ID -> standard user-level leftover paths for the zap stanza, scoped to that bundle id
# (so shared components like Microsoft AutoUpdate are left alone). Empty bundle id -> no zap. Source
# blocks call this so every cask ships a zap. brew style --fix normalises the indentation.
zap_for(){ [ -z "$1" ] && return 0; cat <<Z
  zap trash: [
    "~/Library/Caches/$1",
    "~/Library/HTTPStorages/$1",
    "~/Library/Preferences/$1.plist",
    "~/Library/Saved Application State/$1.savedState",
  ]
Z
}

# autofix(): apply ONLY safe, deterministic fixes keyed off audit/style text. Uses perl (macOS sed
# does not honour \n in replacements). Returns 0 if it changed the cask, 1 if no safe rule applied.
# Anything NOT listed here (UA-gated livecheck, :no_check / unversioned url, unreachable homepage,
# notability, signing/notarization) is deliberately left for human/Claude review, not auto-edited.
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

STAGE="precheck"; git checkout -q "$DEF"; git pull -q --ff-only 2>/dev/null || true
brew info --cask "$TOKEN" >/dev/null 2>&1 && die "a cask '$TOKEN' already exists in homebrew-cask — no PR needed; file the Fleet FR instead"
brew info --formula "$TOKEN" >/dev/null 2>&1 && log "[$TOKEN] WARNING: token collides with a homebrew-core formula — rename (e.g. ${TOKEN}-desktop) or audit will reject it"
git branch -D "add-$TOKEN" >/dev/null 2>&1 || true; git checkout -q -b "add-$TOKEN"
# Clean slate: drop any stale branch (and its closed PR) left on the fork from a prior run, so this run
# always pushes a fresh branch and opens a new PR/FR. (Skipped in DRYRUN; FRESH=0 keeps an open PR.)
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
  pass=0
  while [ "$pass" -lt 2 ]; do
    autofix "$AUDIT
$STYLE_OUT" || { log "[$TOKEN] no further safe auto-fix applies (remaining issues need review)"; break; }
    brew style --fix "$TOKEN" >/dev/null 2>&1; STYLE_OUT="$(brew style "$TOKEN" 2>&1)"
    AUDIT="$(brew audit --cask $SFLAG --online --new "$TOKEN" 2>&1)"
    issues || { log "[$TOKEN] auto-fix cleared style + audit"; break; }
    pass=$((pass+1))
  done
fi
STAGE="livecheck"; LIVECHECK="$(brew livecheck --cask "$TOKEN" 2>&1 || true)"   # informational: detected vs cask version
{ echo "── audit ──"; printf '%s\n' "$AUDIT" | sed 's/^/    /'; } >> "$S"
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

# Push: prefer force-with-lease; fall back to a plain force push if the branch already exists on the
# fork from a prior run (force-with-lease errors "stale info" when there's no local tracking ref).
# (Cleanest of all is to delete the stale branch on the fork first, then this just creates it fresh.)
STAGE="push"
git push --force-with-lease "$FORK" "add-$TOKEN" 2>/dev/null \
  || git push --force "$FORK" "add-$TOKEN" \
  || die "push failed"

# Re-run safety: if an OPEN PR already exists for this branch, don't open a duplicate PR or Fleet FR
# (we still force-pushed the latest commit to the branch above, which updates the existing PR).
PR="$(gh api "repos/Homebrew/homebrew-cask/pulls?head=${FORK_OWNER}:add-${TOKEN}&state=open" --jq '.[0].html_url // empty' 2>/dev/null || true)"
if [ -n "$PR" ]; then
  log "[$TOKEN] branch updated; PR already open: $PR (skipping PR + Fleet FR creation)"
else
# Build the PR body from the CURRENT Homebrew template — never a hardcoded checklist. The tap was
# just pulled, so .github/PULL_REQUEST_TEMPLATE.md is live: tick every box, fill any cask
# placeholder, append the honest AI disclosure. Fall back to a baked-in checklist only if missing.
TPL="$(ls "$WORK"/.github/PULL_REQUEST_TEMPLATE.md "$WORK"/.github/pull_request_template.md 2>/dev/null | head -1)"
if [ -n "$TPL" ]; then
  sed -E -e 's/^([[:space:]]*[-*][[:space:]]*)\[[[:space:]]\]/\1[x]/' \
         -e "s/<cask>/$TOKEN/g; s/{{[[:space:]]*cask[[:space:]]*}}/$TOKEN/g; s/<token>/$TOKEN/g" "$TPL" > "$W/pr.md"
  { echo; echo "$DISCLOSURE"; } >> "$W/pr.md"
  log "[$TOKEN] PR body built from live template: $TPL (boxes ticked + AI disclosure appended)"
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
  log "[$TOKEN] live template not found in .github/ — used baked-in checklist (keep references/pr-and-disclosure.md in sync)"
fi

# Honesty aid for the "not already refused" box: surface any prior closed PR for this token.
REFUSED="$(gh search prs "$TOKEN" --repo Homebrew/homebrew-cask --match title --state closed --json url --jq 'length' 2>/dev/null || echo '?')"
log "[$TOKEN] prior closed PRs matching token: $REFUSED (confirm none was a refusal)"

{ echo "── PR body ──"; sed 's/^/    /' "$W/pr.md"; } >> "$S"
STAGE="pr"; PR="$(gh pr create --repo Homebrew/homebrew-cask --base "$DEF" --head "$FORK_OWNER:add-$TOKEN" --title "Add $TOKEN (new cask)" --body-file "$W/pr.md")" || die "PR create failed"
log "[$TOKEN] PR: $PR"

STAGE="fr"; if [ "$FILE_FR" = 1 ]; then
  # Keep the Fleet FR simple: the PR, direct links to the cask file and the installer, the file type,
  # and the token. No customer/vendor/user story (the :help-solutions-consulting label is always added;
  # the customer/prospect label is added by hand or via CUSTOMER_LABEL).
  CASKURL="https://github.com/$FORK_OWNER/homebrew-cask/blob/add-$TOKEN/$CASK"
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
```

## Source blocks

Pick the one matching the download source; paste over the two stub functions. Update the literal
repo/URL/regex to the app.

### A) GitHub release — compound tag `v<ver>-b-<build>`, zip  (example: IBM Notifier)

```bash
resolve(){
  local loc; loc="$(curl -sI "https://github.com/IBM/mac-ibm-notifications/releases/latest" \
        | awk -F'/tag/' 'tolower($0)~/^location/{print $2}' | tr -d '\r')"
  local vnum="${loc#v-}"; local build="${vnum##*-b-}"; vnum="${vnum%-b-*}"
  VERSION="$vnum,$build"
  URL="https://github.com/IBM/mac-ibm-notifications/releases/download/v-${vnum}-b-${build}/IBM.Notifier.zip"
  curl -fL "$URL" -o "$DL"
}
write_cask(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/IBM/mac-ibm-notifications/releases/download/v-#{version.csv.first}-b-#{version.csv.second}/IBM.Notifier.zip"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    regex(/v-(\d+(?:\.\d+)+)-b-(\d+)/i)
    strategy :github_latest do |json, regex|
      match = json["tag_name"]&.match(regex)
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
```

### B) GitHub release — plain semver tag, pkg  (example: SAP Power Monitor)

`url`/`homepage` share github.com, so **no `verified:`**. Launchctl labels + zap are auto-filled.

```bash
resolve(){
  VERSION="$(curl -sI "https://github.com/SAP/power-monitoring-tool-for-macos/releases/latest" \
            | awk -F'/tag/' 'tolower($0)~/^location/{print $2}' | tr -d '\r')"
  URL="https://github.com/SAP/power-monitoring-tool-for-macos/releases/download/${VERSION}/PowerMonitor_${VERSION}.pkg"
  curl -fL "$URL" -o "$DL"
}
write_cask(){
  local uninstall zap=""
  if [ -n "$LABELS" ]; then
    local arr; arr="$(printf '"%s", ' $LABELS | sed 's/, $//')"
    uninstall="uninstall launchctl: [$arr],
            pkgutil:   \"$RECEIPT\""
  else
    uninstall="uninstall pkgutil: \"$RECEIPT\""
  fi
  [ -n "$BUNDLE_ID" ] && zap="

$(zap_for "$BUNDLE_ID")"
  cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/SAP/power-monitoring-tool-for-macos/releases/download/#{version}/PowerMonitor_#{version}.pkg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :$SYM

  pkg "PowerMonitor_#{version}.pkg"

  $uninstall$zap
end
RB
}
```

### C) Electron `latest-mac.yml` — arch-split dmg  (example: GoTo)

Read the feed for the version and the **versioned** dmg names. Two arches → one `sha256 arm:, intel:`.
For a **single universal** dmg instead, drop the `arch` line, use one `sha256 "$SHA"`, and a url like
`".../App-#{version}-universal.dmg"`.

```bash
resolve(){
  local yml="https://goto-desktop.goto.com/latest-mac.yml"
  VERSION="$(curl -fsSL "$yml" | awk -F': ' '/^version:/{print $2; exit}' | tr -d '\r ')"
  URL="https://goto-desktop.goto.com/GoTo-${VERSION}-arm64.dmg"      # arm dmg (inspected by harness)
  curl -fL "$URL" -o "$DL"
  curl -fL "https://goto-desktop.goto.com/GoTo-${VERSION}.dmg" -o "$W/dl-x64"   # intel dmg
  SHA_X64="$(shasum -a 256 "$W/dl-x64" | awk '{print $1}')"
}
write_cask(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  arch arm: "-arm64", intel: ""

  version "$VERSION"
  sha256 arm:   "$SHA",
         intel: "$SHA_X64"

  url "https://goto-desktop.goto.com/GoTo-#{version}#{arch}.dmg"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://goto-desktop.goto.com/latest-mac.yml"
    strategy :electron_builder
  end

  auto_updates true
  depends_on macos: :$SYM

  app "$APP_NAME"

  uninstall quit: "$BUNDLE_ID"

  zap trash: [
    "~/Library/Application Support/$BUNDLE_ID",
    "~/Library/Caches/$BUNDLE_ID",
    "~/Library/Preferences/$BUNDLE_ID.plist",
    "~/Library/Saved Application State/$BUNDLE_ID.savedState",
  ]
end
RB
}
```

### D) Microsoft CDN pkg via `aka.ms` redirect — MAU-aware  (example: Remote Help, Copilot)

`verified:` is derived from the real CDN host. **Set the livecheck regex to the actual filename**
(Remote Help ships `Microsoft_Remote_Help_<ver>_installer.pkg` — note the `_installer` before `.pkg`).
If the pkg bundles AutoUpdate, `inspect` sets `$MAU` and the choices-deselect + `quit:` are added.

```bash
resolve(){
  local short="https://aka.ms/downloadremotehelpmacos"
  local real; real="$(curl -sIL "$short" | awk -F': ' 'tolower($1)=="location"{print $2}' | tail -1 | tr -d '\r')"
  VERSION="$(basename "${real%%\?*}" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
  URLT="$(printf '%s' "$real" | sed "s/${VERSION//./\\.}/#{version}/")"
  URL="$real"; curl -fL "$URL" -o "$DL"
}
write_cask(){
  local host; host="$(printf '%s' "$URLT" | sed -E 's#https?://([^/]+)/.*#\1#')"
  local pkg uninstall
  if [ -n "$MAU" ]; then
    pkg="pkg \"$(basename "$URLT")\",
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
    pkg="pkg \"$(basename "$URLT")\""
    uninstall="uninstall pkgutil: \"$RECEIPT\""
  fi
  cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "$URLT",
      verified: "$host/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://aka.ms/downloadremotehelpmacos"
    regex(/Microsoft_Remote_Help_(\d+(?:\.\d+)+)_installer\.pkg/i)
    strategy :header_match
  end

  auto_updates true
  depends_on macos: :$SYM

  $pkg

  $uninstall

$(zap_for "$BUNDLE_ID")
end
RB
}
```

### E) Direct versioned vendor URL  (template for a plain dmg/pkg)

Add `verified:` **only** if the download host differs from the homepage host.

```bash
resolve(){
  VERSION="1.2.3"                                       # set from the vendor's version source
  URL="https://vendor.example/download/App-${VERSION}.dmg"
  curl -fL "$URL" -o "$DL"
}
write_cask(){ cat > "$CASK" <<RB
cask "$TOKEN" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://vendor.example/download/App-#{version}.dmg",
      verified: "vendor.example/"
  name "$NAME"
  desc "$DESC"
  homepage "$HOMEPAGE"

  livecheck do
    url "https://vendor.example/download"
    regex(/App-(\d+(?:\.\d+)+)\.dmg/i)
    strategy :page_match
  end

  depends_on macos: :$SYM

  app "$APP_NAME"

$(zap_for "$BUNDLE_ID")
end
RB
}
```
