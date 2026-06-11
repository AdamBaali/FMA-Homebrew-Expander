#!/bin/bash
###############################################################################
# analyze-cask.sh — detailed cask quality analysis and recommendations
#
# Analyzes a cask for quality, correctness, and best practices:
#   • Hardcoded versions
#   • Deprecated syntax
#   • URL correctness and verification
#   • Livecheck regex quality
#   • App metadata correctness
#   • Zap stanza completeness
#   • Code style and idioms
#
# Usage: bash analyze-cask.sh <cask-file>
#
###############################################################################

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: bash analyze-cask.sh <cask-file>"
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
CYAN='\033[0;36m'
NC='\033[0m'

issue_count=0
warning_count=0
suggestion_count=0

report_error() {
  echo -e "${RED}ERROR:${NC} $1"
  ((issue_count++))
}

report_warning() {
  echo -e "${YELLOW}WARNING:${NC} $1"
  ((warning_count++))
}

report_suggestion() {
  echo -e "${CYAN}SUGGESTION:${NC} $1"
  ((suggestion_count++))
}

report_pass() {
  echo -e "${GREEN}✓${NC} $1"
}

echo "Analyzing: $CASK_FILE"
echo ""

# Extract cask content
cask_name=$(basename "$CASK_FILE" .rb)
cask_content=$(cat "$CASK_FILE")

# =========================================================================
# CHECK 1: Hardcoded versions in URLs
# =========================================================================
echo -e "${BLUE}Check 1: Hardcoded Versions${NC}"

if grep -E 'url.*[0-9]+\.[0-9]+' "$CASK_FILE" | grep -v '#{version}' | grep -v 'strategy' | head -3 | grep -q .; then
  echo "Potential hardcoded version in URL:"
  grep -E 'url.*[0-9]+\.[0-9]+' "$CASK_FILE" | grep -v '#{version}' | grep -v 'strategy' | head -3 | sed 's/^/  /'
  report_error "URL contains version number — should use #{version} interpolation"
else
  report_pass "No hardcoded versions in URL"
fi
echo ""

# =========================================================================
# CHECK 2: Deprecated syntax
# =========================================================================
echo -e "${BLUE}Check 2: Deprecated Syntax${NC}"

# Check for old depends_on :macos syntax
if grep -E 'depends_on.*:macos' "$CASK_FILE" > /dev/null; then
  report_error "Uses deprecated depends_on :macos syntax — should use depends_on macos: blocks"
else
  report_pass "No deprecated depends_on :macos syntax"
fi

# Check for depends_on macos: (correct syntax)
if grep -E 'depends_on macos:' "$CASK_FILE" > /dev/null; then
  report_pass "Uses correct depends_on macos: syntax"
fi

# Check for homepage
if ! grep -E 'homepage' "$CASK_FILE" > /dev/null; then
  report_warning "No homepage URL provided"
else
  report_pass "Homepage URL present"
fi

# Check for description
if ! grep -E 'desc' "$CASK_FILE" > /dev/null; then
  report_warning "No description provided"
else
  local desc=$(grep 'desc' "$CASK_FILE" | sed 's/.*desc "\([^"]*\)".*/\1/')
  if [[ ${#desc} -lt 10 ]]; then
    report_warning "Description is very short: '$desc'"
  else
    report_pass "Description present and reasonable length"
  fi
fi

echo ""

# =========================================================================
# CHECK 3: URL and artifact type
# =========================================================================
echo -e "${BLUE}Check 3: URL & Artifact Type${NC}"

local url=$(grep -m1 'url "' "$CASK_FILE" | sed 's/.*url "\([^"]*\)".*/\1/')
local artifact_type=""

if [[ "$url" == *".dmg" ]]; then
  artifact_type="DMG"
  report_pass "DMG artifact detected"
elif [[ "$url" == *".zip" ]]; then
  artifact_type="ZIP"
  report_pass "ZIP artifact detected"
elif [[ "$url" == *".pkg" ]]; then
  artifact_type="PKG"
  report_pass "PKG artifact detected"
elif [[ "$url" == *".tar.gz" ]]; then
  artifact_type="TAR.GZ"
  report_pass "TAR.GZ artifact detected"
else
  report_warning "Unknown artifact type from URL: $url"
fi

# Check for verified
if grep -E 'verified:' "$CASK_FILE" > /dev/null; then
  local verified=$(grep 'verified:' "$CASK_FILE" | sed 's/.*verified: "\([^"]*\)".*/\1/')
  report_pass "Verified source: $verified"
else
  report_warning "No verified source provided (recommended for security)"
fi

echo ""

# =========================================================================
# CHECK 4: Livecheck
# =========================================================================
echo -e "${BLUE}Check 4: Livecheck Configuration${NC}"

if grep -E 'livecheck do' "$CASK_FILE" > /dev/null; then
  report_pass "Livecheck block present"

  if grep -E 'strategy.*:page_match' "$CASK_FILE" > /dev/null; then
    report_pass "Uses page_match strategy"
  elif grep -E 'strategy.*:header_match' "$CASK_FILE" > /dev/null; then
    report_pass "Uses header_match strategy"
  elif grep -E 'strategy.*:git' "$CASK_FILE" > /dev/null; then
    report_pass "Uses git strategy"
  else
    report_suggestion "Verify livecheck strategy is appropriate for the source"
  fi

  # Check regex
  if grep -E 'regex' "$CASK_FILE" > /dev/null; then
    local regex=$(grep 'regex' "$CASK_FILE" | sed 's/.*regex(\([^)]*\)).*/\1/')
    if [[ ${#regex} -lt 10 ]]; then
      report_warning "Regex appears short/simple, verify it matches all version formats"
    else
      report_pass "Regex pattern present"
    fi
  fi
else
  report_warning "No livecheck block — app updates will not be automatically detected"
fi

echo ""

# =========================================================================
# CHECK 5: App metadata
# =========================================================================
echo -e "${BLUE}Check 5: App Metadata${NC}"

# Check for app block
if grep -E 'app "' "$CASK_FILE" > /dev/null; then
  local app_name=$(grep -m1 'app "' "$CASK_FILE" | sed 's/.*app "\([^"]*\)".*/\1/')
  report_pass "App path declared: $app_name"

  # Verify app path looks reasonable
  if [[ "$app_name" == *".app" ]]; then
    report_pass "App path includes .app extension"
  else
    report_warning "App path missing .app extension"
  fi
else
  report_error "No app block found — cask won't install the app"
fi

# Check for bundle_id (optional but recommended for some cases)
if grep -E 'bundle_id' "$CASK_FILE" > /dev/null; then
  local bundle_id=$(grep 'bundle_id' "$CASK_FILE" | sed 's/.*bundle_id: "\([^"]*\)".*/\1/')
  report_pass "Bundle ID declared: $bundle_id"

  if [[ "$bundle_id" == com.* ]]; then
    report_pass "Bundle ID follows reverse-domain convention"
  fi
fi

echo ""

# =========================================================================
# CHECK 6: Zap stanza
# =========================================================================
echo -e "${BLUE}Check 6: Zap Stanza${NC}"

if grep -E 'zap' "$CASK_FILE" > /dev/null; then
  report_pass "Zap stanza present"

  local zap_lines=$(grep -A 20 'zap' "$CASK_FILE" | wc -l)
  if [[ $zap_lines -lt 2 ]]; then
    report_warning "Zap stanza appears empty or minimal"
  else
    # Count zap entries
    local zap_entries=$(grep -A 20 'zap' "$CASK_FILE" | grep -E 'trash:|delete:' | wc -l)
    report_pass "Zap stanza contains $zap_entries cleanup entries"
  fi

  # Check for common zap locations
  if grep -E 'Library/Application Support' "$CASK_FILE" > /dev/null; then
    report_pass "Cleans up ~/Library/Application Support"
  fi

  if grep -E 'Library/Preferences' "$CASK_FILE" > /dev/null; then
    report_pass "Cleans up ~/Library/Preferences"
  fi

  if grep -E 'Library/Caches' "$CASK_FILE" > /dev/null; then
    report_pass "Cleans up ~/Library/Caches"
  fi

  if grep -E 'Library/Saved Application State' "$CASK_FILE" > /dev/null; then
    report_pass "Cleans up ~/Library/Saved Application State"
  fi
else
  report_warning "No zap stanza — uninstall will not clean up app data"
fi

echo ""

# =========================================================================
# CHECK 7: SHA256 and versioning
# =========================================================================
echo -e "${BLUE}Check 7: SHA256 & Version${NC}"

if grep -E 'sha256' "$CASK_FILE" > /dev/null; then
  local sha=$(grep 'sha256' "$CASK_FILE" | sed 's/.*sha256 "\([^"]*\)".*/\1/')
  if [[ ${#sha} -eq 64 ]]; then
    report_pass "SHA256 hash present and correct length"
  else
    report_warning "SHA256 hash present but unexpected length: ${#sha}"
  fi
else
  report_error "No SHA256 hash found — cask cannot verify download integrity"
fi

if grep -E 'version "' "$CASK_FILE" > /dev/null; then
  local version=$(grep -m1 'version "' "$CASK_FILE" | sed 's/.*version "\([^"]*\)".*/\1/')
  report_pass "Version declared: $version"

  # Check version format
  if [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    report_pass "Version follows semantic versioning"
  elif [[ "$version" =~ ^[0-9]{4}[0-9]{2}[0-9]{2}$ ]]; then
    report_pass "Version follows date format (YYYYMMDD)"
  else
    report_suggestion "Version format is non-standard: $version (may be acceptable depending on app)"
  fi
else
  report_error "No version declared"
fi

echo ""

# =========================================================================
# CHECK 8: Code style and structure
# =========================================================================
echo -e "${BLUE}Check 8: Code Style${NC}"

# Check for unnecessary blank lines
if grep -E '^[[:space:]]*$' "$CASK_FILE" | wc -l | grep -q .; then
  local blank_lines=$(grep -c '^[[:space:]]*$' "$CASK_FILE" || true)
  if [[ $blank_lines -gt 3 ]]; then
    report_suggestion "Multiple blank lines found (consider condensing for readability)"
  fi
fi

# Check for consistent indentation (should be 2 spaces)
if grep -E '^  [^ ]' "$CASK_FILE" > /dev/null; then
  report_pass "Consistent 2-space indentation"
else
  report_warning "Indentation may not be consistent (check for tabs vs spaces)"
fi

echo ""

# =========================================================================
# SUMMARY
# =========================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}Summary${NC}"
echo ""
echo -e "Issues:      ${RED}$issue_count${NC}"
echo -e "Warnings:    ${YELLOW}$warning_count${NC}"
echo -e "Suggestions: ${CYAN}$suggestion_count${NC}"
echo ""

if [[ $issue_count -eq 0 && $warning_count -eq 0 ]]; then
  echo -e "${GREEN}✓ Cask looks good!${NC}"
elif [[ $issue_count -eq 0 ]]; then
  echo -e "${YELLOW}⚠ Review warnings above before submission${NC}"
else
  echo -e "${RED}✗ Fix errors before submission${NC}"
fi
echo ""
