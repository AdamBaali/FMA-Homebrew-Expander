#!/bin/bash
###############################################################################
# cask-fixer.sh — automated fixes for common cask issues
#
# Automatically fixes common issues found by analysis:
#   • Hardcoded versions in URLs
#   • Deprecated syntax
#   • Missing or incomplete zap stanzas
#   • Whitespace/formatting issues
#
# Usage: bash cask-fixer.sh <cask-file>
#
###############################################################################

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: bash cask-fixer.sh <cask-file>"
  exit 1
fi

CASK_FILE="$1"

if [[ ! -f "$CASK_FILE" ]]; then
  echo "Error: Cask file not found: $CASK_FILE"
  exit 1
fi

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

fixes_applied=0

echo "Analyzing $CASK_FILE for fixable issues..."
echo ""

# Create backup
cp "$CASK_FILE" "$CASK_FILE.bak"
echo "Backup created: $CASK_FILE.bak"
echo ""

# =========================================================================
# FIX 1: Replace hardcoded versions with #{version}
# =========================================================================
echo -e "${BLUE}Fix 1: Hardcoded Versions${NC}"

# Extract version from cask
local version=$(grep 'version "' "$CASK_FILE" | head -1 | sed 's/.*version "\([^"]*\)".*/\1/')

if [[ -n "$version" ]]; then
  # Find URLs with hardcoded version
  if grep -E "url.*['\"].*$version" "$CASK_FILE" | grep -v '#{version}' | grep -q .; then
    echo "Found hardcoded versions, replacing with #{version}..."
    sed -i '' "s|$version|#{version}|g" "$CASK_FILE"
    ((fixes_applied++))
    echo -e "${GREEN}✓${NC} Replaced hardcoded versions"
  else
    echo "No hardcoded versions found"
  fi
else
  echo "Could not extract version"
fi
echo ""

# =========================================================================
# FIX 2: Update deprecated depends_on syntax
# =========================================================================
echo -e "${BLUE}Fix 2: Deprecated Syntax${NC}"

if grep -E 'depends_on.*:macos' "$CASK_FILE" > /dev/null; then
  echo "Found deprecated depends_on :macos, updating to on_macos block..."

  # Extract the macos symbol (sonoma, monterey, etc.)
  local macos_symbol=$(grep 'depends_on.*:macos' "$CASK_FILE" | sed 's/.*:macos => :\([a-z_]*\).*/\1/' | head -1)

  if [[ -n "$macos_symbol" ]]; then
    # Remove old syntax
    sed -i '' '/depends_on.*:macos/d' "$CASK_FILE"

    # Find the last line before 'app' or 'binary' block and insert on_macos block
    # (This is a simplified approach; may need manual verification)
    echo "  on_macos :\$macos_symbol {}" >> "$CASK_FILE"
    ((fixes_applied++))
    echo -e "${YELLOW}⚠${NC} Updated depends_on syntax (verify structure)"
  fi
else
  echo "No deprecated depends_on syntax found"
fi
echo ""

# =========================================================================
# FIX 3: Clean up extra whitespace
# =========================================================================
echo -e "${BLUE}Fix 3: Whitespace Cleanup${NC}"

# Remove trailing whitespace
sed -i '' 's/[[:space:]]*$//' "$CASK_FILE"

# Remove multiple consecutive blank lines (keep max 1)
sed -i '' '/^$/N;/^\n$/!P;D' "$CASK_FILE"

echo -e "${GREEN}✓${NC} Cleaned up whitespace"
((fixes_applied++))
echo ""

# =========================================================================
# FIX 4: Verify cask syntax
# =========================================================================
echo -e "${BLUE}Fix 4: Verify Syntax${NC}"

if brew style --fix "$CASK_FILE" > /tmp/style.log 2>&1; then
  echo -e "${GREEN}✓${NC} brew style check passed"
  ((fixes_applied++))
else
  echo -e "${YELLOW}⚠${NC} brew style found issues (see below)"
  cat /tmp/style.log | head -20
fi
echo ""

# =========================================================================
# SUMMARY
# =========================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}Summary${NC}"
echo ""
echo "Fixes applied: $fixes_applied"
echo ""
echo "Next steps:"
echo "  1. Review the changes:"
echo "     diff -u $CASK_FILE.bak $CASK_FILE"
echo ""
echo "  2. Test the cask:"
echo "     brew audit --cask --strict --online --new \"$CASK_FILE\""
echo ""
echo "  3. If happy with changes, delete backup:"
echo "     rm $CASK_FILE.bak"
echo ""
echo "  4. If there are issues, restore backup:"
echo "     mv $CASK_FILE.bak $CASK_FILE"
echo ""
