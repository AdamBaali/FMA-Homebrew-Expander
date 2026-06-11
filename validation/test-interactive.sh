#!/bin/bash
set -euo pipefail

# Interactive app testing script
# Tests 20 apps one at a time with manual verification between each
# Usage: bash test-interactive.sh [BATCH_SIZE=20] [SKIP_PASSED=1]

BATCH_SIZE=${BATCH_SIZE:-20}
DRYRUN=1
TEST_INSTALL=1

echo "=== Interactive App Testing ==="
echo "Batch size: $BATCH_SIZE"
echo "Dry run: enabled (no submissions)"
echo "Install testing: enabled"
echo ""
echo "For each app, you will:"
echo "  1. Review the generated cask"
echo "  2. Install and test the app"
echo "  3. Verify zap stanza paths exist and are correct"
echo "  4. Edit the cask if needed (in \$CASKWORK/<app>/)"
echo "  5. Confirm to move to the next app"
echo ""
read -p "Press Enter to start..."

app_count=0
while true; do
  if (( app_count >= BATCH_SIZE )); then
    echo ""
    echo "=== Batch complete ($BATCH_SIZE apps tested) ==="
    break
  fi

  echo ""
  echo "=== Testing app $((app_count + 1)) of $BATCH_SIZE ==="
  DRYRUN=$DRYRUN TEST_INSTALL=$TEST_INSTALL BATCH_SIZE=1 SKIP_PASSED=1 bash scripts/cask-master.sh

  app_count=$((app_count + 1))

  if (( app_count < BATCH_SIZE )); then
    echo ""
    echo "---"
    read -p "Verify the cask, check the zap paths, then press Enter to test the next app..."
  fi
done

echo ""
echo "=== Summary ==="
echo "Tested $app_count apps in this run."
echo "Review: cat \$CASKWORK/MASTER-summary.md"
echo "When ready to submit: bash scripts/cask-master.sh (remove DRYRUN)"
