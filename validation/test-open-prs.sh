#!/bin/bash
set -euo pipefail

# Test the 20 open PRs one at a time
# Installs, opens, closes, uninstalls each app with manual verification

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

CASKWORK="${CASKWORK:-/tmp/caskwork}"
DRYRUN=1
TEST_INSTALL=1

echo "=== Testing 20 Open PRs ==="
echo ""
echo "For each app, you will:"
echo "  1. Generate the cask (TEST_INSTALL=1)"
echo "  2. Install the app: brew install --cask <app>"
echo "  3. Open and use the app (we'll pause for 30 sec or until you close it)"
echo "  4. Uninstall: brew uninstall --cask <app>"
echo "  5. Verify zap stanza paths"
echo "  6. Edit cask if needed"
echo ""
read -p "Press Enter to start..."

passed=0
failed=0

for app in "${APPS[@]}"; do
  echo ""
  echo "════════════════════════════════════════"
  echo "[$((passed + failed + 1))/20] Testing: $app"
  echo "════════════════════════════════════════"
  echo ""

  # Step 1: Generate cask with test install
  echo "[1/5] Generating cask..."
  if DRYRUN=$DRYRUN TEST_INSTALL=$TEST_INSTALL BATCH_SIZE=1 SKIP_PASSED=1 ONLY="$app" bash scripts/cask-master.sh > /dev/null 2>&1; then
    echo "✓ Cask generated"
  else
    echo "✗ Failed to generate cask"
    failed=$((failed + 1))
    read -p "Press Enter to skip to next app..."
    continue
  fi

  CASK_FILE="$CASKWORK/$app/$app.rb"
  if [[ ! -f "$CASK_FILE" ]]; then
    echo "✗ Cask file not found: $CASK_FILE"
    failed=$((failed + 1))
    read -p "Press Enter to skip to next app..."
    continue
  fi

  echo ""
  echo "[2/5] Review the generated cask:"
  echo "─────────────────────────────────────"
  head -30 "$CASK_FILE"
  echo "     ... (full file: $CASK_FILE)"
  echo "─────────────────────────────────────"
  echo ""
  read -p "Press Enter to install the app..."

  # Step 2: Install app
  echo ""
  echo "[3/5] Installing app: brew install --cask $app"
  if brew install --cask "$app" 2>&1; then
    echo "✓ Installation complete"
  else
    echo "⚠ Installation may have issues (app may not be available or already installed)"
  fi

  # Step 3: Open app and wait
  echo ""
  echo "[4/5] Opening app: $app"
  echo ""
  echo "The app should open shortly. Please:"
  echo "  • Use the app for at least 1-2 minutes"
  echo "  • Create/modify files if possible"
  echo "  • Change preferences/settings"
  echo "  • When done, close the app"
  echo ""
  echo "Starting timer (30 seconds, or close app to continue)..."

  # Try to open the app and wait for user to close it
  if open -a "$app" 2>/dev/null; then
    # Wait up to 30 seconds or until app closes
    for i in {1..30}; do
      if ! pgrep -f "Applications/$app.app" > /dev/null 2>&1; then
        echo "App closed."
        break
      fi
      sleep 1
      if (( i % 10 == 0 )); then
        echo "  Still waiting... ($((30 - i))s remaining)"
      fi
    done

    # Force close if still running
    pkill -f "Applications/$app.app" 2>/dev/null || true
  else
    echo "⚠ Could not open app (may be CLI-only or not installed)"
  fi

  echo ""
  read -p "Press Enter to uninstall and verify zap paths..."

  # Step 4: Uninstall
  echo ""
  echo "[5/5] Uninstalling: brew uninstall --cask $app"
  if brew uninstall --cask "$app" 2>&1; then
    echo "✓ Uninstalled"
  else
    echo "⚠ Uninstall had issues"
  fi

  # Verify zap paths
  echo ""
  echo "VERIFY ZAP PATHS:"
  echo "─────────────────────────────────────"
  bash verify-zap-paths.sh "$app" 2>/dev/null || true
  echo ""
  echo "Check the paths above against what remains in:"
  echo "  ~/Library/Application Support/$app*"
  echo "  ~/Library/Preferences/*$app*"
  echo "  ~/Library/Caches/$app*"
  echo "  ~/Library/Saved Application State/$app*"
  echo ""
  echo "Edit the cask if needed:"
  echo "  vim $CASK_FILE"
  echo ""

  read -p "Is the zap stanza correct? (press Enter to continue)..." -t 60 || true
  echo ""

  passed=$((passed + 1))
done

echo ""
echo "════════════════════════════════════════"
echo "=== COMPLETE ==="
echo "════════════════════════════════════════"
echo ""
echo "Results: $passed passed, $failed skipped"
echo ""
echo "Next steps:"
echo "  1. Review summary: cat $CASKWORK/MASTER-summary.md"
echo "  2. When ready: bash scripts/cask-master.sh (to submit PRs)"
echo ""
