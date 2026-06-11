#!/bin/bash
###############################################################################
# end-to-end-validate.sh — comprehensive cask validation workflow
#
# Validates a single cask end-to-end:
#   1. Generate cask with full testing
#   2. Pre-app filesystem snapshot
#   3. Install + open app + monitor file creation
#   4. Post-app snapshot + diff
#   5. Verify zap stanza covers all created files
#   6. Full cask validation (style, audit, livecheck, bundle ID, etc.)
#   7. Reinstall + zap + verify cleanup
#   8. Final report with all checks
#
# Usage: bash end-to-end-validate.sh <app-token> [<app-token> ...]
#
# Example:
#   bash end-to-end-validate.sh poll-everywhere
#   bash end-to-end-validate.sh poll-everywhere mestrenova masv
#
###############################################################################

set -euo pipefail

CASKWORK="${CASKWORK:-$HOME/caskwork}"
DRYRUN=1
TEST_INSTALL=1
REPORT_DIR="$CASKWORK/e2e-reports"
mkdir -p "$REPORT_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log_section() {
  echo -e "\n${BLUE}=== $1 ===${NC}"
}

log_pass() {
  echo -e "${GREEN}✓${NC} $1"
}

log_fail() {
  echo -e "${RED}✗${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

log_info() {
  echo "  $1"
}

# Filesystem utilities
capture_fs_snapshot() {
  local snapshot_file="$1"
  # Capture files in common app locations
  (
    find "$HOME/Library/Application Support" -type f 2>/dev/null | sort || true
    find "$HOME/Library/Preferences" -type f 2>/dev/null | sort || true
    find "$HOME/Library/Caches" -type f 2>/dev/null | sort || true
    find "$HOME/Library/Saved Application State" -type f 2>/dev/null | sort || true
    find "$HOME/Library/HTTPStorages" -type f 2>/dev/null | sort || true
    find "/Library/LaunchDaemons" -type f 2>/dev/null | sort || true
    find "/Library/LaunchAgents" -type f 2>/dev/null | sort || true
  ) > "$snapshot_file" 2>/dev/null
}

get_fs_changes() {
  local before="$1"
  local after="$2"
  local output="$3"
  comm -13 "$before" "$after" > "$output"
}

validate_single_app() {
  local app="$1"
  local app_work="$CASKWORK/$app"
  local report="$REPORT_DIR/$app-validation.md"
  local checks_passed=0
  local checks_total=0

  # Initialize report
  cat > "$report" << 'EOF'
# End-to-End Cask Validation Report
EOF

  echo "# Cask: $app" >> "$report"
  echo "Date: $(date)" >> "$report"
  echo "" >> "$report"

  # =========================================================================
  # PHASE 1: Generate cask with full testing
  # =========================================================================
  log_section "PHASE 1: Cask Generation"

  if [[ -d "$app_work" ]]; then
    rm -rf "$app_work"
  fi
  mkdir -p "$app_work"

  if CASKWORK=$CASKWORK DRYRUN=$DRYRUN TEST_INSTALL=$TEST_INSTALL BATCH_SIZE=1 ONLY="$app" bash scripts/cask-master.sh > "$app_work/gen.log" 2>&1; then
    log_pass "Cask generation successful"
    echo "" >> "$report"
    echo "## 1. Cask Generation" >> "$report"
    echo "" >> "$report"
    echo "✓ Cask generation passed" >> "$report"
    ((checks_passed++))
  else
    log_fail "Cask generation failed"
    echo "" >> "$report"
    echo "## 1. Cask Generation" >> "$report"
    echo "" >> "$report"
    echo "✗ Cask generation failed" >> "$report"
    cat "$app_work/gen.log" >> "$report"
    echo "" >> "$report"
    echo "**Status: FAILED**" >> "$report"
    cat "$report"
    return 1
  fi
  ((checks_total++))

  # Find cask file
  local cask_file="$app_work/$app.rb"
  if [[ ! -f "$cask_file" ]]; then
    log_fail "Cask file not found: $cask_file"
    echo "✗ Cask file not found: $cask_file" >> "$report"
    return 1
  fi
  log_pass "Cask file found: $cask_file"

  # =========================================================================
  # PHASE 2: Check for duplicates
  # =========================================================================
  log_section "PHASE 2: Check for Duplicates"

  echo "" >> "$report"
  echo "## 2. Duplicate Detection" >> "$report"
  echo "" >> "$report"

  if bash validation/check-duplicates.sh "$cask_file" > "$app_work/duplicates.log" 2>&1; then
    log_pass "No duplicates detected"
    echo "✓ No duplicate casks found" >> "$report"
    ((checks_passed++))
  else
    log_warn "Potential duplicate or conflict found (review carefully)"
    echo "⚠ Review duplicate check output:" >> "$report"
    echo '```' >> "$report"
    cat "$app_work/duplicates.log" >> "$report"
    echo '```' >> "$report"
  fi
  ((checks_total++))

  # =========================================================================
  # PHASE 3: Extract metadata from generated cask
  # =========================================================================
  log_section "PHASE 3: Extract Metadata"

  local app_name=$(grep -m1 'app "' "$cask_file" | sed 's/.*app "\([^"]*\)".*/\1/' || echo "")
  local bundle_id=$(grep -m1 'bundle_id' "$cask_file" | sed 's/.*bundle_id: "\([^"]*\)".*/\1/' || echo "")
  local min_macos=$(grep -m1 'macos:' "$cask_file" | sed 's/.*macos: \*:\([a-z_]*\).*/\1/' || echo "")
  local url=$(grep -m1 'url "' "$cask_file" | sed 's/.*url "\([^"]*\)".*/\1/' | head -1)

  log_info "App name: $app_name"
  log_info "Bundle ID: ${bundle_id:-not found}"
  log_info "Min macOS: ${min_macos:-not found}"
  log_info "URL: ${url:0:80}..."

  # =========================================================================
  # PHASE 4: Pre-install system state snapshot
  # =========================================================================
  log_section "PHASE 4: Pre-install System State Snapshot"

  local system_before="$app_work/system_before.txt"
  log_info "Capturing system state before install..."
  bash validation/check-system-state.sh capture "$system_before"
  log_pass "System state snapshot captured"

  # =========================================================================
  # PHASE 5: Pre-app filesystem snapshot
  # =========================================================================
  log_section "PHASE 5: Pre-app Filesystem Snapshot"

  local fs_before="$app_work/fs_before.txt"
  log_info "Capturing filesystem state before app launch..."
  capture_fs_snapshot "$fs_before"
  log_pass "Snapshot captured ($(wc -l < "$fs_before") files)"

  # =========================================================================
  # PHASE 6: Install app
  # =========================================================================
  log_section "PHASE 6: Install App"

  if brew install --cask "$app" > "$app_work/install.log" 2>&1; then
    log_pass "App installed successfully"
  else
    log_fail "App installation failed"
    cat "$app_work/install.log"
    return 1
  fi
  ((checks_passed++))
  ((checks_total++))

  # =========================================================================
  # PHASE 7: Open app and monitor
  # =========================================================================
  log_section "PHASE 7: Open & Monitor App"

  echo ""
  echo "The app '$app' is about to open."
  echo "Please:"
  echo "  • Use the app for 1-2 minutes"
  echo "  • Create/open/modify files if applicable"
  echo "  • Change preferences/settings"
  echo "  • Close the app when done (or wait 60s timeout)"
  echo ""
  read -p "Press Enter to open the app..." -t 5 || true
  echo ""

  # Open app
  if open -a "$app_name" 2>/dev/null; then
    log_info "App opened, waiting up to 60 seconds for user interaction..."

    # Wait up to 60 seconds or until app closes
    for i in {1..60}; do
      if ! pgrep -f "Applications/$app_name.app" > /dev/null 2>&1; then
        log_info "App closed after $i seconds"
        break
      fi
      sleep 1
      if (( i % 10 == 0 )); then
        log_info "Still monitoring ($((60 - i))s remaining)..."
      fi
    done

    # Force close if still running
    pkill -f "Applications/$app_name.app" 2>/dev/null || true
    sleep 1
  else
    log_warn "Could not open app (may be CLI-only or install failed)"
  fi

  # =========================================================================
  # PHASE 8: Post-install system state snapshot
  # =========================================================================
  log_section "PHASE 8: Post-install System State Snapshot"

  local system_after="$app_work/system_after.txt"
  log_info "Capturing system state after install..."
  bash check-system-state.sh capture "$system_after"
  log_pass "System state snapshot captured"

  # Check for unexpected system changes
  log_info "Checking for unexpected system changes..."
  bash validation/check-system-state.sh compare "$system_before" "$system_after" "$app" 2>&1 | tee -a "$app_work/system_changes.txt" || true

  # =========================================================================
  # PHASE 9: Post-app filesystem snapshot & diff
  # =========================================================================
  log_section "PHASE 9: Post-app Filesystem Snapshot"

  local fs_after="$app_work/fs_after.txt"
  log_info "Capturing filesystem state after app close..."
  capture_fs_snapshot "$fs_after"
  log_pass "Snapshot captured ($(wc -l < "$fs_after") files)"

  local fs_changes="$app_work/fs_changes.txt"
  get_fs_changes "$fs_before" "$fs_after" "$fs_changes"

  local num_changes=$(wc -l < "$fs_changes")
  if [[ $num_changes -gt 0 ]]; then
    log_info "Files created: $num_changes"
    log_info "Sample changes:"
    head -10 "$fs_changes" | while read line; do
      log_info "  $line"
    done
    if [[ $num_changes -gt 10 ]]; then
      log_info "  ... and $((num_changes - 10)) more"
    fi
  else
    log_info "No files created during app run"
  fi

  # =========================================================================
  # PHASE 10: Verify zap stanza
  # =========================================================================
  log_section "PHASE 10: Verify Zap Stanza"

  echo "" >> "$report"
  echo "## 2. Zap Stanza Verification" >> "$report"
  echo "" >> "$report"

  local zap_section=$(sed -n '/zap/,/end/p' "$cask_file")
  if [[ -z "$zap_section" ]]; then
    log_warn "No zap stanza found"
    echo "⚠ No zap stanza found" >> "$report"
  else
    log_info "Zap stanza found:"
    echo "$zap_section" | head -20 | while read line; do
      log_info "  $line"
    done

    # Check if zap paths match created files
    local zap_paths=$(echo "$zap_section" | grep -oE '~[^"]*|/[^"]*' | sort -u || true)
    local unmapped=0

    if [[ -s "$fs_changes" ]]; then
      while read created_file; do
        local file_dir=$(dirname "$created_file")
        local file_name=$(basename "$created_file")

        # Check if this file is covered by zap stanza
        local covered=false
        while read zap_path; do
          # Expand ~ to $HOME
          zap_path="${zap_path/\~/$HOME}"

          # Check if created file matches zap path (exact or wildcard)
          if [[ "$created_file" == "$zap_path" ]] || [[ "$created_file" == "$zap_path"* ]]; then
            covered=true
            break
          fi
        done <<< "$zap_paths"

        if [[ "$covered" == false ]]; then
          ((unmapped++))
          log_warn "File not in zap stanza: $created_file"
        fi
      done < "$fs_changes"
    fi

    if [[ $unmapped -eq 0 ]]; then
      log_pass "All created files are covered by zap stanza"
      echo "✓ All created files are covered by zap stanza" >> "$report"
      ((checks_passed++))
    else
      log_fail "$unmapped files created but not in zap stanza"
      echo "✗ $unmapped files created but not in zap stanza" >> "$report"
    fi
    ((checks_total++))
  fi

  # =========================================================================
  # PHASE 11: Cask validation - style
  # =========================================================================
  log_section "PHASE 11: Cask Style Check"

  echo "" >> "$report"
  echo "## 3. Cask Code Quality" >> "$report"
  echo "" >> "$report"

  if brew style "$cask_file" > "$app_work/style.log" 2>&1; then
    log_pass "brew style check passed"
    echo "✓ brew style check passed" >> "$report"
    ((checks_passed++))
  else
    log_fail "brew style check failed"
    echo "✗ brew style check failed" >> "$report"
    echo "" >> "$report"
    echo "Issues:" >> "$report"
    echo '```' >> "$report"
    cat "$app_work/style.log" >> "$report"
    echo '```' >> "$report"
  fi
  ((checks_total++))

  # =========================================================================
  # PHASE 12: Cask validation - audit
  # =========================================================================
  log_section "PHASE 12: Audit Cask"

  if brew audit --cask --strict --online --new "$cask_file" > "$app_work/audit.log" 2>&1; then
    log_pass "brew audit passed"
    echo "✓ brew audit --strict --online --new passed" >> "$report"
    ((checks_passed++))
  else
    log_fail "brew audit found issues"
    echo "✗ brew audit found issues" >> "$report"
    echo "" >> "$report"
    echo "Audit output:" >> "$report"
    echo '```' >> "$report"
    cat "$app_work/audit.log" >> "$report"
    echo '```' >> "$report"
  fi
  ((checks_total++))

  # =========================================================================
  # PHASE 13: Livecheck regex validation
  # =========================================================================
  log_section "PHASE 13: Livecheck Validation"

  echo "" >> "$report"
  echo "## 4. Livecheck & Version Detection" >> "$report"
  echo "" >> "$report"

  if brew livecheck --cask "$app" > "$app_work/livecheck.log" 2>&1; then
    local livecheck_result=$(cat "$app_work/livecheck.log")
    log_pass "Livecheck succeeded"
    log_info "Result: $livecheck_result"
    echo "✓ Livecheck succeeded" >> "$report"
    echo "" >> "$report"
    echo '```' >> "$report"
    echo "$livecheck_result" >> "$report"
    echo '```' >> "$report"
    ((checks_passed++))
  else
    log_warn "Livecheck failed or not applicable"
    echo "⚠ Livecheck failed or not applicable" >> "$report"
  fi
  ((checks_total++))

  # =========================================================================
  # PHASE 14: Verify app metadata
  # =========================================================================
  log_section "PHASE 14: Verify App Metadata"

  echo "" >> "$report"
  echo "## 5. App Metadata" >> "$report"
  echo "" >> "$report"

  # Get actual bundle ID from installed app
  local app_path="/Applications/$app_name.app"
  local actual_bundle_id=""
  if [[ -d "$app_path" ]]; then
    actual_bundle_id=$(mdls -name kMDItemCFBundleIdentifier -r "$app_path" 2>/dev/null || echo "")

    if [[ -n "$actual_bundle_id" ]]; then
      log_info "Actual bundle ID: $actual_bundle_id"
      echo "Bundle ID from app: \`$actual_bundle_id\`" >> "$report"

      if [[ "$bundle_id" == "$actual_bundle_id" ]]; then
        log_pass "Bundle ID matches"
        echo "✓ Bundle ID in cask matches app" >> "$report"
        ((checks_passed++))
      elif [[ -n "$bundle_id" ]]; then
        log_fail "Bundle ID mismatch: cask has '$bundle_id', app has '$actual_bundle_id'"
        echo "✗ Bundle ID mismatch: cask='$bundle_id' vs app='$actual_bundle_id'" >> "$report"
      fi
      ((checks_total++))
    fi
  fi

  # =========================================================================
  # PHASE 15: Uninstall
  # =========================================================================
  log_section "PHASE 15: Uninstall"

  if brew uninstall --cask "$app" > "$app_work/uninstall.log" 2>&1; then
    log_pass "App uninstalled successfully"
  else
    log_warn "Uninstall had issues (may be expected)"
  fi

  # =========================================================================
  # PHASE 16: Reinstall test (idempotency)
  # =========================================================================
  log_section "PHASE 16: Reinstall Test"

  echo "" >> "$report"
  echo "## 6. Installation & Idempotency" >> "$report"
  echo "" >> "$report"

  if brew install --cask "$app" > "$app_work/reinstall.log" 2>&1; then
    log_pass "Reinstall successful (idempotency verified)"
    echo "✓ Reinstall successful (idempotency verified)" >> "$report"
    ((checks_passed++))
  else
    log_fail "Reinstall failed"
    echo "✗ Reinstall failed" >> "$report"
  fi
  ((checks_total++))

  # =========================================================================
  # PHASE 17: Zap test (cleanup verification)
  # =========================================================================
  log_section "PHASE 17: Zap Cleanup Test"

  local fs_before_zap="$app_work/fs_before_zap.txt"
  log_info "Capturing filesystem before zap..."
  capture_fs_snapshot "$fs_before_zap"

  if brew uninstall --zap --cask "$app" > "$app_work/zap.log" 2>&1; then
    log_pass "Zap uninstall completed"

    # Check if zap actually removed files
    local fs_after_zap="$app_work/fs_after_zap.txt"
    log_info "Capturing filesystem after zap..."
    capture_fs_snapshot "$fs_after_zap"

    local remaining="$app_work/zap_remaining.txt"
    comm -23 "$fs_before_zap" "$fs_after_zap" > "$remaining"
    local num_removed=$(wc -l < "$remaining")

    if [[ $num_removed -gt 0 ]]; then
      log_pass "Zap removed $num_removed files"
      echo "✓ Zap stanza removed $num_removed files" >> "$report"
      ((checks_passed++))
    else
      log_warn "Zap may not have removed any tracked files"
      echo "⚠ Zap may not have removed any tracked files" >> "$report"
    fi
    ((checks_total++))
  else
    log_fail "Zap uninstall failed"
    echo "✗ Zap uninstall failed" >> "$report"
  fi

  # =========================================================================
  # FINAL SUMMARY
  # =========================================================================
  log_section "Summary"

  echo "" >> "$report"
  echo "## Summary" >> "$report"
  echo "" >> "$report"
  echo "**Checks passed: $checks_passed / $checks_total**" >> "$report"
  echo "" >> "$report"

  if [[ $checks_passed -eq $checks_total ]]; then
    log_pass "All $checks_total checks passed!"
    echo "**Status: ✓ READY FOR SUBMISSION**" >> "$report"
    echo "" >> "$report"
    echo "This cask is ready to be submitted as a PR to Homebrew." >> "$report"
  elif [[ $checks_passed -ge $((checks_total * 3 / 4)) ]]; then
    log_warn "Most checks passed, review issues above"
    echo "**Status: ⚠ REVIEW REQUIRED**" >> "$report"
    echo "" >> "$report"
    echo "Review the failed checks above and fix the cask or app configuration." >> "$report"
  else
    log_fail "Multiple checks failed, cask needs significant work"
    echo "**Status: ✗ FAILED**" >> "$report"
    echo "" >> "$report"
    echo "This cask has multiple issues and should not be submitted yet." >> "$report"
  fi

  echo ""
  echo "Full report: $report"
  echo ""
}

# Main
if [[ $# -eq 0 ]]; then
  echo "Usage: bash end-to-end-validate.sh <app-token> [<app-token> ...]"
  echo ""
  echo "Example:"
  echo "  bash end-to-end-validate.sh poll-everywhere"
  echo "  bash end-to-end-validate.sh poll-everywhere mestrenova masv"
  exit 1
fi

for app in "$@"; do
  validate_single_app "$app" || true
done

echo ""
echo "All reports saved to: $REPORT_DIR"
echo "View reports:"
echo "  ls -lah $REPORT_DIR"
