#!/bin/bash
###############################################################################
# research-utils.sh — utilities for reading and querying app research data
#
# Provides functions to look up app metadata from the research registry
#
###############################################################################

set -euo pipefail

RESEARCH_DIR="${RESEARCH_DIR:-$(dirname "$0")/../../research}"
APPS_REGISTRY="$RESEARCH_DIR/apps/apps-registry.json"

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed"
  echo "Install with: brew install jq"
  exit 1
fi

# =========================================================================
# Query Functions
# =========================================================================

# Look up a single app by token
get_app_by_token() {
  local token="$1"
  jq ".apps[] | select(.token == \"$token\")" "$APPS_REGISTRY"
}

# Get app field by token
get_app_field() {
  local token="$1"
  local field="$2"
  jq -r ".apps[] | select(.token == \"$token\") | .$field" "$APPS_REGISTRY"
}

# Get download URL for app
get_download_url() {
  local token="$1"
  get_app_field "$token" "download_url"
}

# Get version detection regex
get_version_regex() {
  local token="$1"
  jq -r ".apps[] | select(.token == \"$token\") | .version_detection.regex" "$APPS_REGISTRY"
}

# Get bundle ID
get_bundle_id() {
  local token="$1"
  get_app_field "$token" "bundle_id"
}

# Get zap locations
get_zap_locations() {
  local token="$1"
  jq -r ".apps[] | select(.token == \"$token\") | .zap_stanza.locations[]" "$APPS_REGISTRY"
}

# Get minimum macOS version
get_min_macos() {
  local token="$1"
  get_app_field "$token" "min_macos"
}

# Get status
get_status() {
  local token="$1"
  get_app_field "$token" "status"
}

# =========================================================================
# List Functions
# =========================================================================

# List all app tokens
list_all_apps() {
  jq -r '.apps[].token' "$APPS_REGISTRY" | sort
}

# List apps by status
list_by_status() {
  local status="$1"
  jq -r ".apps[] | select(.status == \"$status\") | .token" "$APPS_REGISTRY" | sort
}

# List ready apps
list_ready_apps() {
  list_by_status "ready"
}

# List pending apps (not yet researched)
list_pending_apps() {
  list_by_status "pending"
}

# List researched apps
list_researched_apps() {
  list_by_status "researched"
}

# List blocked apps
list_blocked_apps() {
  list_by_status "blocked"
}

# List duplicates
list_duplicates() {
  jq -r '.apps[] | select(.status == "duplicate") | .token' "$APPS_REGISTRY" | sort
}

# =========================================================================
# Count Functions
# =========================================================================

# Count total apps
count_total() {
  jq '.apps | length' "$APPS_REGISTRY"
}

# Count apps by status
count_by_status() {
  local status="$1"
  jq ".apps | map(select(.status == \"$status\")) | length" "$APPS_REGISTRY"
}

# Get statistics
get_stats() {
  local total=$(count_total)
  local ready=$(count_by_status "ready")
  local researched=$(count_by_status "researched")
  local pending=$(count_by_status "pending")
  local blocked=$(count_by_status "blocked")
  local duplicate=$(count_by_status "duplicate")

  cat << EOF
App Registry Statistics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total apps:        $total
Ready:             $ready ($((ready * 100 / total))%)
Researched:        $researched ($((researched * 100 / total))%)
Pending:           $pending ($((pending * 100 / total))%)
Blocked:           $blocked ($((blocked * 100 / total))%)
Duplicate:         $duplicate ($((duplicate * 100 / total))%)
EOF
}

# =========================================================================
# Validation Functions
# =========================================================================

# Check if app exists in registry
app_exists() {
  local token="$1"
  if jq ".apps[] | select(.token == \"$token\")" "$APPS_REGISTRY" &> /dev/null; then
    return 0
  else
    return 1
  fi
}

# Validate app data has required fields
validate_app() {
  local token="$1"
  local required_fields=("name" "vendor" "token" "download_url" "bundle_id" "min_macos" "artifact_type" "status")

  for field in "${required_fields[@]}"; do
    local value=$(jq -r ".apps[] | select(.token == \"$token\") | .$field // \"\"" "$APPS_REGISTRY")
    if [[ -z "$value" || "$value" == "null" ]]; then
      echo "Missing or null field: $field"
      return 1
    fi
  done

  return 0
}

# =========================================================================
# Export Functions
# =========================================================================

# Export specific app data for cask generation
export_app_data() {
  local token="$1"
  local output_file="$2"

  jq ".apps[] | select(.token == \"$token\")" "$APPS_REGISTRY" > "$output_file"
  echo "Exported app data to: $output_file"
}

# Export all ready apps
export_ready_apps() {
  local output_file="${1:-ready_apps.json}"

  jq '.apps[] | select(.status == "ready")' "$APPS_REGISTRY" > "$output_file"
  echo "Exported $(count_by_status "ready") ready apps to: $output_file"
}

# =========================================================================
# Helper to display app info
# =========================================================================

show_app_info() {
  local token="$1"

  if ! app_exists "$token"; then
    echo "App not found: $token"
    return 1
  fi

  local name=$(get_app_field "$token" "name")
  local vendor=$(get_app_field "$token" "vendor")
  local status=$(get_app_field "$token" "status")
  local bundle_id=$(get_bundle_id "$token")
  local url=$(get_download_url "$token")
  local min_macos=$(get_min_macos "$token")

  cat << EOF
┌─ App Information ─────────────────────────────────────────┐
│ Name:       $name
│ Vendor:     $vendor
│ Token:      $token
│ Status:     $status
│ Bundle ID:  $bundle_id
│ Min macOS:  $min_macos
│ Download:   ${url:0:55}...
└───────────────────────────────────────────────────────────┘
EOF
}

# =========================================================================
# Main: If run directly, provide interactive mode
# =========================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-help}" in
    stats)
      get_stats
      ;;
    list-ready)
      list_ready_apps
      ;;
    list-pending)
      list_pending_apps
      ;;
    list-all)
      list_all_apps
      ;;
    list-blocked)
      list_blocked_apps
      ;;
    count)
      echo "Total apps: $(count_total)"
      ;;
    info)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 info <token>"
        exit 1
      fi
      show_app_info "$2"
      ;;
    validate)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 validate <token>"
        exit 1
      fi
      if validate_app "$2"; then
        echo "✓ App data is valid"
      else
        echo "✗ App data has issues"
        exit 1
      fi
      ;;
    *)
      cat << 'EOF'
research-utils.sh — Query and manage app research data

Usage:
  stats                    Show registry statistics
  list-ready              List apps ready for cask generation
  list-pending            List apps not yet researched
  list-all                List all apps
  list-blocked            List blocked apps
  count                   Count total apps
  info <token>            Show app information
  validate <token>        Validate app data

Examples:
  ./research-utils.sh stats
  ./research-utils.sh list-ready
  ./research-utils.sh info poll-everywhere
  ./research-utils.sh validate poll-everywhere

See also:
  research/README.md      Learn about the research structure
  research/apps/app-template.json    Template for new apps
EOF
      ;;
  esac
fi
