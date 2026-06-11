#!/bin/bash
###############################################################################
# validate-all-prs.sh — end-to-end validation for all open PRs
#
# Comprehensive workflow that validates all 20 open PRs:
#   1. Generate casks for all apps
#   2. Run end-to-end validation for each (filesystem snapshots, app launch, etc.)
#   3. Analyze each cask for quality issues
#   4. Generate summary report showing readiness
#
# Usage: bash validate-all-prs.sh
#
###############################################################################

set -euo pipefail

CASKWORK="${CASKWORK:-$HOME/caskwork}"
VALIDATION_DIR="$CASKWORK/validation-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$VALIDATION_DIR"

# The 20 open PRs
APPS=(
  "poll-everywhere"
  "mestrenova"
  "masv"
  "luna-display"
  "hudl-studio"
  "brosix"
  "automounter"
  "atlassian-companion"
  "alivecolors"
  "alarm-clock-pro"
  "akvis-frames"
  "akvis-artifact-remover-ai"
  "akvis-airbrush"
  "airradar"
  "utiliti"
  "pique"
  "mobile-to-local"
  "managed-app-schema-builder"
  "jamfcheck"
  "jamf-reenroller"
)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_section() {
  echo -e "\n${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
}

log_pass() {
  echo -e "${GREEN}✓${NC} $1"
}

log_fail() {
  echo -e "${RED}✗${NC} $1"
}

log_info() {
  echo "  $1"
}

# Summary tracking
declare -A status_map
declare -a ready_apps
declare -a review_apps
declare -a failed_apps
declare -a skipped_apps

# Main workflow
echo "FMA Homebrew Cask — End-to-End Validation"
echo ""
echo "This will validate all 20 open PRs:"
echo "  • Generate each cask"
echo "  • Install and open each app"
echo "  • Monitor file creation"
echo "  • Verify zap stanzas"
echo "  • Audit for quality issues"
echo ""
echo "Reports will be saved to: $VALIDATION_DIR"
echo ""
read -p "Press Enter to begin (this will take 30-60 minutes)..." -t 5 || true
echo ""

passed_count=0
failed_count=0

for i in "${!APPS[@]}"; do
  app="${APPS[$i]}"
  app_num=$((i + 1))
  total=${#APPS[@]}

  log_section "[$app_num/$total] Validating: $app"

  # Run end-to-end validation
  if bash validation/end-to-end-validate.sh "$app" > "$VALIDATION_DIR/$app.log" 2>&1; then
    log_pass "Validation completed"

    # Copy detailed report
    if [[ -f "$CASKWORK/e2e-reports/$app-validation.md" ]]; then
      cp "$CASKWORK/e2e-reports/$app-validation.md" "$VALIDATION_DIR/$app-e2e.md"
    fi

    # Check if cask was skipped (already exists in Homebrew)
    if grep -q "already exists in Homebrew" "$VALIDATION_DIR/$app-e2e.md" 2>/dev/null || \
       grep -q "skipped (cask exists upstream)" "$CASKWORK/$app/report.md" 2>/dev/null; then
      skipped_apps+=("$app")
      status_map["$app"]="SKIPPED"
      log_warn "Status: SKIPPED (already exists in Homebrew)"
      ((passed_count++))
      continue
    fi

    # Run quality analysis
    cask_file="$CASKWORK/$app/$app.rb"
    if [[ -f "$cask_file" ]]; then
      log_info "Analyzing code quality..."
      if bash validation/analyze-cask.sh "$cask_file" > "$VALIDATION_DIR/$app-analysis.txt" 2>&1; then
        log_pass "Analysis completed"

        # Extract summary from analysis
        issues=$(grep -c "^ERROR:" "$VALIDATION_DIR/$app-analysis.txt" || echo 0)
        warnings=$(grep -c "^WARNING:" "$VALIDATION_DIR/$app-analysis.txt" || echo 0)

        if [[ $issues -eq 0 && $warnings -le 1 ]]; then
          ready_apps+=("$app")
          status_map["$app"]="READY"
          log_pass "Status: READY FOR SUBMISSION"
          ((passed_count++))
        else
          review_apps+=("$app")
          status_map["$app"]="REVIEW"
          log_info "Status: Needs review ($issues issues, $warnings warnings)"
          ((passed_count++))
        fi
      else
        review_apps+=("$app")
        status_map["$app"]="REVIEW"
        ((passed_count++))
      fi
    fi
  else
    log_fail "Validation failed"
    failed_apps+=("$app")
    status_map["$app"]="FAILED"
    ((failed_count++))
  fi

  echo ""
done

# =========================================================================
# FINAL SUMMARY
# =========================================================================
log_section "FINAL SUMMARY"

echo ""
echo "Results:"
echo "  Ready:   ${#ready_apps[@]} apps"
echo "  Review:  ${#review_apps[@]} apps"
echo "  Failed:  ${#failed_apps[@]} apps"
echo "  Skipped: ${#skipped_apps[@]} apps (already exist in Homebrew)"
echo ""

if [[ ${#ready_apps[@]} -gt 0 ]]; then
  echo -e "${GREEN}Ready for submission:${NC}"
  for app in "${ready_apps[@]}"; do
    echo "  ✓ $app"
  done
  echo ""
fi

if [[ ${#review_apps[@]} -gt 0 ]]; then
  echo -e "${YELLOW}Need review/fixes:${NC}"
  for app in "${review_apps[@]}"; do
    echo "  ⚠ $app"
  done
  echo ""
fi

if [[ ${#skipped_apps[@]} -gt 0 ]]; then
  echo -e "${YELLOW}Skipped (already exist):${NC}"
  for app in "${skipped_apps[@]}"; do
    echo "  ⊘ $app"
  done
  echo ""
fi

if [[ ${#failed_apps[@]} -gt 0 ]]; then
  echo -e "${RED}Failed validation:${NC}"
  for app in "${failed_apps[@]}"; do
    echo "  ✗ $app"
  done
  echo ""
fi

# =========================================================================
# NEXT STEPS
# =========================================================================
echo -e "${BLUE}Next Steps:${NC}"
echo ""

if [[ ${#ready_apps[@]} -gt 0 ]]; then
  echo "1. Review ready casks:"
  echo "   for app in ${ready_apps[@]}; do"
  echo "     echo \"=== \$app ===\""
  echo "     cat $VALIDATION_DIR/\$app-e2e.md"
  echo "     echo \"\""
  echo "   done"
  echo ""
fi

echo "2. Review analysis for apps needing fixes:"
echo "   ls -lah $VALIDATION_DIR/*-analysis.txt"
echo ""

echo "3. For each app needing fixes:"
echo "   • Read the analysis report"
echo "   • Edit the cask: vim $CASKWORK/<app>/<app>.rb"
echo "   • Re-run validation: bash end-to-end-validate.sh <app>"
echo ""

echo "4. Submit ready casks as PRs:"
echo "   bash scripts/cask-master.sh"
echo ""

# Save summary
cat > "$VALIDATION_DIR/SUMMARY.md" << EOF
# End-to-End Validation Summary

Date: $(date)

## Results

- Ready: ${#ready_apps[@]}
- Review: ${#review_apps[@]}
- Failed: ${#failed_apps[@]}

### Ready for Submission

$(for app in "${ready_apps[@]}"; do echo "- $app"; done)

### Need Review/Fixes

$(for app in "${review_apps[@]}"; do echo "- $app"; done)

### Failed Validation

$(for app in "${failed_apps[@]}"; do echo "- $app"; done)

## Reports

All detailed reports are in this directory:
- \`*-e2e.md\` — End-to-end validation report
- \`*-analysis.txt\` — Code quality analysis
- \`*.log\` — Raw validation logs

## Checklist

- [ ] Review all analysis reports
- [ ] Fix issues in casks
- [ ] Re-run validation for fixed apps
- [ ] Submit ready casks as PRs
EOF

echo "Summary saved to: $VALIDATION_DIR/SUMMARY.md"
echo ""
echo "All reports: $VALIDATION_DIR/"
