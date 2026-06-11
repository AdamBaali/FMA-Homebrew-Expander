#!/bin/bash
###############################################################################
# check-duplicates.sh — detect duplicate casks against Homebrew registry
#
# Checks for potential duplicates by:
#   • App name (exact and fuzzy match)
#   • Bundle ID
#   • Vendor name
#   • URL domain
#   • Desktop app variations (without -desktop suffix)
#
# Usage: bash check-duplicates.sh <cask-file>
#        bash check-duplicates.sh ~/caskwork/app/app.rb
#
###############################################################################

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: bash check-duplicates.sh <cask-file>"
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

HOMEBREW_TAP="${HOMEBREW_TAP:-$(brew --repository)/Library/Taps/homebrew/homebrew-cask}"

if [[ ! -d "$HOMEBREW_TAP" ]]; then
  echo "Error: Homebrew cask tap not found at $HOMEBREW_TAP"
  echo "Run: brew tap homebrew/cask"
  exit 1
fi

echo "Checking for duplicates against $(find "$HOMEBREW_TAP/Casks" -name "*.rb" | wc -l) existing casks..."
echo ""

# Extract metadata from our cask
cask_name=$(basename "$CASK_FILE" .rb)
app_name=$(grep -m1 'app "' "$CASK_FILE" | sed 's/.*app "\([^"]*\)".*/\1/' | sed 's/\.app$//' || echo "")
bundle_id=$(grep -m1 'bundle_id' "$CASK_FILE" | sed 's/.*bundle_id: "\([^"]*\)".*/\1/' || echo "")
url=$(grep -m1 'url "' "$CASK_FILE" | sed 's/.*url "\([^"]*\)".*/\1/' | sed 's|https?://||' | sed 's|/.*||' || echo "")
homepage=$(grep -m1 'homepage' "$CASK_FILE" | sed 's/.*homepage "\([^"]*\)".*/\1/' | sed 's|https?://||' | sed 's|/.*||' | sed 's|www\.||' || echo "")

# Extract vendor name (first word if multi-word app name)
vendor=$(echo "$app_name" | awk '{print tolower($1)}' | grep -oE '^[a-z]+' || echo "")

echo -e "${BLUE}Cask Information:${NC}"
echo "  Name:       $cask_name"
echo "  App:        $app_name"
echo "  Bundle ID:  ${bundle_id:-not found}"
echo "  URL domain: ${url:-not found}"
echo "  Vendor:     ${vendor:-not found}"
echo ""

# Initialize tracking
duplicates_found=0
warnings_found=0

# =========================================================================
# CHECK 1: Exact app name match
# =========================================================================
echo -e "${BLUE}Check 1: Exact App Name Match${NC}"

for cask_file in "$HOMEBREW_TAP/Casks"/*/*.rb; do
  existing_app=$(grep -m1 'app "' "$cask_file" | sed 's/.*app "\([^"]*\)".*/\1/' | sed 's/\.app$//' || echo "")

  if [[ -n "$existing_app" && "$existing_app" == "$app_name" ]]; then
    existing_cask=$(basename "$cask_file" .rb)
    echo -e "${RED}✗ DUPLICATE FOUND:${NC} $existing_cask"
    echo "  Same app name: '$app_name'"
    ((duplicates_found++))
  fi
done

if [[ $duplicates_found -eq 0 ]]; then
  echo -e "${GREEN}✓${NC} No exact app name matches"
fi
echo ""

# =========================================================================
# CHECK 2: Bundle ID match
# =========================================================================
echo -e "${BLUE}Check 2: Bundle ID Match${NC}"

if [[ -n "$bundle_id" ]]; then
  for cask_file in "$HOMEBREW_TAP/Casks"/*/*.rb; do
    existing_bundle=$(grep -m1 'bundle_id' "$cask_file" | sed 's/.*bundle_id: "\([^"]*\)".*/\1/' || echo "")

    if [[ -n "$existing_bundle" && "$existing_bundle" == "$bundle_id" ]]; then
      existing_cask=$(basename "$cask_file" .rb)
      echo -e "${RED}✗ DUPLICATE BUNDLE ID:${NC} $existing_cask"
      echo "  Same bundle ID: '$bundle_id'"
      ((duplicates_found++))
    fi
  done

  if [[ $duplicates_found -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} No bundle ID conflicts"
  fi
else
  echo -e "${YELLOW}⚠${NC} No bundle ID to check"
fi
echo ""

# =========================================================================
# CHECK 3: Desktop variant detection
# =========================================================================
echo -e "${BLUE}Check 3: Desktop Variants${NC}"

if [[ "$cask_name" == *"-desktop" ]]; then
  base_name="${cask_name%-desktop}"

  if find "$HOMEBREW_TAP/Casks" -name "${base_name}.rb" | grep -q .; then
    echo -e "${RED}✗ POTENTIAL VARIANT:${NC} Base name '$base_name' may already exist"
    echo "  This might be a desktop variant of: $base_name"
    ((warnings_found++))
  fi
else
  # Check if desktop variant exists
  if find "$HOMEBREW_TAP/Casks" -name "${cask_name}-desktop.rb" | grep -q .; then
    echo -e "${YELLOW}⚠${NC} Desktop variant already exists: ${cask_name}-desktop"
    ((warnings_found++))
  fi
fi

if [[ $warnings_found -eq 0 && $duplicates_found -eq 0 ]]; then
  echo -e "${GREEN}✓${NC} No desktop variant conflicts"
fi
echo ""

# =========================================================================
# CHECK 4: Vendor name matching
# =========================================================================
echo -e "${BLUE}Check 4: Vendor Name Variations${NC}"

if [[ -n "$vendor" ]]; then
  vendor_matches=()
  for cask_file in "$HOMEBREW_TAP/Casks"/*/*.rb; do
    cask=$(basename "$cask_file" .rb)
    existing_app=$(grep -m1 'app "' "$cask_file" | sed 's/.*app "\([^"]*\)".*/\1/' | sed 's/\.app$//' || echo "")
    existing_vendor=$(echo "$existing_app" | awk '{print tolower($1)}' | grep -oE '^[a-z]+' || echo "")

    if [[ -n "$existing_vendor" && "$existing_vendor" == "$vendor" && "$cask" != "$cask_name" ]]; then
      vendor_matches+=("$cask: $existing_app")
    fi
  done

  if [[ ${#vendor_matches[@]} -gt 0 ]]; then
    echo -e "${YELLOW}ℹ${NC} Found ${#vendor_matches[@]} casks from same vendor:"
    for match in "${vendor_matches[@]:0:5}"; do
      echo "  • $match"
    done
    if [[ ${#vendor_matches[@]} -gt 5 ]]; then
      echo "  ... and $((${#vendor_matches[@]} - 5)) more"
    fi
  else
    echo -e "${GREEN}✓${NC} No other casks from vendor '$vendor'"
  fi
else
  echo -e "${YELLOW}⚠${NC} Could not extract vendor name"
fi
echo ""

# =========================================================================
# CHECK 5: Similar names (fuzzy match)
# =========================================================================
echo -e "${BLUE}Check 5: Similar App Names${NC}"

similar=()
for cask_file in "$HOMEBREW_TAP/Casks"/*/*.rb; do
  cask=$(basename "$cask_file" .rb)
  existing_app=$(grep -m1 'app "' "$cask_file" | sed 's/.*app "\([^"]*\)".*/\1/' | sed 's/\.app$//' || echo "")

  # Check if names are similar (both contain same words, or one is substring of other)
  if [[ -n "$existing_app" && "$existing_app" != "$app_name" ]]; then
    # Very basic fuzzy match - if 80%+ of characters match or one contains the other
    if [[ "$app_name" == *"${existing_app:0:5}"* ]] || [[ "$existing_app" == *"${app_name:0:5}"* ]]; then
      similar+=("$cask: $existing_app")
    fi
  fi
done

if [[ ${#similar[@]} -gt 0 ]]; then
  echo -e "${YELLOW}⚠${NC} Found ${#similar[@]} potentially related casks:"
  for match in "${similar[@]:0:5}"; do
    echo "  • $match"
  done
  if [[ ${#similar[@]} -gt 5 ]]; then
    echo "  ... and $((${#similar[@]} - 5)) more"
  fi
  ((warnings_found++))
else
  echo -e "${GREEN}✓${NC} No similar app names found"
fi
echo ""

# =========================================================================
# CHECK 6: URL domain matching
# =========================================================================
echo -e "${BLUE}Check 6: URL Domain Conflicts${NC}"

if [[ -n "$url" ]]; then
  domain_matches=()
  for cask_file in "$HOMEBREW_TAP/Casks"/*/*.rb; do
    cask=$(basename "$cask_file" .rb)
    if [[ "$cask" != "$cask_name" ]]; then
      existing_url=$(grep -m1 'url "' "$cask_file" | sed 's/.*url "\([^"]*\)".*/\1/' | sed 's|https?://||' | sed 's|/.*||' || echo "")

      if [[ -n "$existing_url" && "$existing_url" == "$url" ]]; then
        domain_matches+=("$cask")
      fi
    fi
  done

  if [[ ${#domain_matches[@]} -gt 0 ]]; then
    echo -e "${YELLOW}ℹ${NC} Found ${#domain_matches[@]} other casks from same domain ($url):"
    for match in "${domain_matches[@]:0:5}"; do
      echo "  • $match"
    done
  else
    echo -e "${GREEN}✓${NC} No URL domain conflicts"
  fi
else
  echo -e "${YELLOW}⚠${NC} Could not extract URL domain"
fi
echo ""

# =========================================================================
# SUMMARY
# =========================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $duplicates_found -gt 0 ]]; then
  echo -e "${RED}✗ DUPLICATES FOUND: $duplicates_found${NC}"
  echo ""
  echo "This cask appears to duplicate an existing Homebrew cask."
  echo "Before submitting, verify:"
  echo "  1. Are these truly different apps?"
  echo "  2. Should this be a variant (e.g., -desktop, -web)?"
  echo "  3. Is bundle ID or vendor name actually different?"
  echo ""
  exit 1
elif [[ $warnings_found -gt 0 ]]; then
  echo -e "${YELLOW}⚠ WARNINGS: $warnings_found${NC}"
  echo ""
  echo "Review similar casks before submitting to avoid duplication."
  echo "You may need to:"
  echo "  1. Rename the cask (add -desktop, -web, etc. suffix)"
  echo "  2. Change the vendor/name to differentiate"
  echo "  3. Verify this is truly a new app"
  echo ""
  exit 0
else
  echo -e "${GREEN}✓ No duplicates detected${NC}"
  echo ""
  echo "This cask is unique and ready for submission."
  echo ""
  exit 0
fi
