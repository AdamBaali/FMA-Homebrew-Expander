#!/bin/bash
###############################################################################
# check-system-state.sh — snapshot and verify system state before/after install
#
# Matches Homebrew's CI system checks:
#   • Installed apps (/Applications, ~/Applications)
#   • Installed kernel extensions (kexts)
#   • Installed packages (from receipts)
#   • Installed launch agents/daemons
#   • Loaded launchctl jobs
#
# Usage: bash check-system-state.sh capture <output-file>
#        bash check-system-state.sh compare <before-file> <after-file> <cask-name>
#
###############################################################################

set -euo pipefail

case "${1:-}" in
  capture)
    if [[ $# -ne 2 ]]; then
      echo "Usage: bash check-system-state.sh capture <output-file>"
      exit 1
    fi
    output_file="$2"
    ;;
  compare)
    if [[ $# -ne 4 ]]; then
      echo "Usage: bash check-system-state.sh compare <before-file> <after-file> <cask-name>"
      exit 1
    fi
    before_file="$2"
    after_file="$3"
    cask_name="$4"
    ;;
  *)
    echo "Usage:"
    echo "  bash check-system-state.sh capture <output-file>"
    echo "  bash check-system-state.sh compare <before-file> <after-file> <cask-name>"
    exit 1
    ;;
esac

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Regex filters for excluded items (Google, Apple auto-updaters)
APPLE_LAUNCHJOBS_REGEX='application\.com\.apple\.(AppStore|installer|Preview|Safari|systemevents|systempreferences|Terminal)'
GOOGLE_LAUNCHJOBS_REGEX='com\.google\.(keystone|GoogleUpdater)'

# =========================================================================
# CAPTURE: Snapshot current system state
# =========================================================================
if [[ "${1:-}" == "capture" ]]; then
  echo "Capturing system state..." >&2

  {
    echo "=== INSTALLED APPS ==="
    # Find all .app files recursively up to depth 5
    for dir in "/Applications" "$HOME/Applications"; do
      if [[ -d "$dir" ]]; then
        find "$dir" -maxdepth 5 -name "*.app" -type d 2>/dev/null | sort || true
      fi
    done | sort -u

    echo ""
    echo "=== INSTALLED KEXTS ==="
    # Get loaded kernel extensions
    /usr/sbin/kextstat -kl 2>/dev/null | awk 'NR>1 {print $NF}' | grep -v '^com\.apple\.' || true

    echo ""
    echo "=== INSTALLED PACKAGES ==="
    # Get installed packages from receipts
    if [[ -d /var/db/receipts ]]; then
      ls /var/db/receipts/*.plist 2>/dev/null | \
        sed 's|.*/||g; s|\.plist$||' | \
        grep -v '^com\.google' | \
        sort || true
    fi

    echo ""
    echo "=== INSTALLED LAUNCH AGENTS ==="
    # Get launch agent .plist files
    for dir in "$HOME/Library/LaunchAgents" "/Library/LaunchAgents"; do
      if [[ -d "$dir" ]]; then
        find "$dir" -maxdepth 1 -name "*.plist" -type f 2>/dev/null | \
          sed 's|.*/||g; s|\.plist$||' || true
      fi
    done | sort -u

    echo ""
    echo "=== INSTALLED LAUNCH DAEMONS ==="
    # Get launch daemon .plist files
    for dir in "$HOME/Library/LaunchDaemons" "/Library/LaunchDaemons"; do
      if [[ -d "$dir" ]]; then
        find "$dir" -maxdepth 1 -name "*.plist" -type f 2>/dev/null | \
          sed 's|.*/||g; s|\.plist$||' || true
      fi
    done | sort -u

    echo ""
    echo "=== LOADED LAUNCHCTL JOBS ==="
    # Get currently loaded launchctl jobs
    (
      launchctl list 2>/dev/null | awk 'NR>1 {print $NF}' || true
    ) | \
      grep -v "^com\.apple\." | \
      grep -v "$GOOGLE_LAUNCHJOBS_REGEX" | \
      sort -u || true

  } > "$output_file"

  echo -e "${GREEN}✓${NC} System state saved to: $output_file" >&2
  exit 0
fi

# =========================================================================
# COMPARE: Analyze before/after differences
# =========================================================================
if [[ "${1:-}" == "compare" ]]; then
  echo ""
  echo "Comparing system state before/after install of: $cask_name"
  echo ""

  issues_found=0

  # Helper function to compare sections
  compare_section() {
    local section_name="$1"
    local before_marker="$2"
    local after_marker="$3"

    # Extract section from files
    local before_section=$(sed -n "/^$before_marker$/,/^=== /p" "$before_file" | tail -n +2 | head -n -1 | grep -v '^===' | sort -u)
    local after_section=$(sed -n "/^$after_marker$/,/^=== /p" "$after_file" | tail -n +2 | head -n -1 | grep -v '^===' | sort -u)

    if [[ -z "$before_section" ]]; then
      before_section=""
    fi
    if [[ -z "$after_section" ]]; then
      after_section=""
    fi

    # Find added items
    local added=$(comm -13 <(echo "$before_section") <(echo "$after_section") || echo "")

    # Find removed items (shouldn't happen)
    local removed=$(comm -23 <(echo "$before_section") <(echo "$after_section") || echo "")

    if [[ -n "$added" ]]; then
      echo -e "${YELLOW}$section_name — Added:${NC}"
      echo "$added" | grep -v '^$' | sed 's/^/  + /'
      ((issues_found++))
    fi

    if [[ -n "$removed" ]]; then
      echo -e "${RED}$section_name — Removed (unexpected):${NC}"
      echo "$removed" | grep -v '^$' | sed 's/^/  - /'
      ((issues_found++))
    fi
  }

  # Compare each section
  compare_section "Installed Apps" "=== INSTALLED APPS ===" "=== INSTALLED APPS ==="
  compare_section "Kernel Extensions" "=== INSTALLED KEXTS ===" "=== INSTALLED KEXTS ==="
  compare_section "Installed Packages" "=== INSTALLED PACKAGES ===" "=== INSTALLED PACKAGES ==="
  compare_section "Launch Agents" "=== INSTALLED LAUNCH AGENTS ===" "=== INSTALLED LAUNCH AGENTS ==="
  compare_section "Launch Daemons" "=== INSTALLED LAUNCH DAEMONS ===" "=== INSTALLED LAUNCH DAEMONS ==="
  compare_section "Loaded Launch Jobs" "=== LOADED LAUNCHCTL JOBS ===" "=== LOADED LAUNCHCTL JOBS ==="

  echo ""
  if [[ $issues_found -eq 0 ]]; then
    echo -e "${GREEN}✓ No unexpected system state changes${NC}"
    exit 0
  else
    echo -e "${YELLOW}⚠ Found $issues_found categories with changes${NC}"
    echo ""
    echo "Note: Changes are expected if the app:"
    echo "  • Installs kernel extensions"
    echo "  • Registers launch agents/daemons"
    echo "  • Modifies system packages"
    echo ""
    echo "Verify these changes are intentional and documented."
    exit 0
  fi
fi
