#!/bin/bash

# Helper to verify zap stanza paths for an app
# Usage: bash verify-zap-paths.sh <app-token>

if [[ -z "${1:-}" ]]; then
  echo "Usage: bash verify-zap-paths.sh <app-token>"
  echo ""
  echo "Example: bash verify-zap-paths.sh slack"
  exit 1
fi

APP_TOKEN="$1"
CASKWORK="${CASKWORK:-/tmp/caskwork}"
APP_DIR="$CASKWORK/$APP_TOKEN"
CASK_FILE="$APP_DIR/cask.rb"

if [[ ! -f "$CASK_FILE" ]]; then
  echo "Error: Cask file not found: $CASK_FILE"
  exit 1
fi

echo "=== Verification Checklist for $APP_TOKEN ==="
echo ""
echo "BEFORE YOU BEGIN:"
echo "  1. Install the app from the cask: brew install --cask $APP_TOKEN"
echo "  2. Open and use the app normally (create files, change settings, etc.)"
echo "  3. Uninstall: brew uninstall --cask $APP_TOKEN"
echo ""

echo "ZAP STANZA PATHS TO VERIFY:"
echo ""

# Extract zap block from cask
sed -n '/zap do/,/^  end$/p' "$CASK_FILE" | while IFS= read -r line; do
  if [[ $line =~ \{\{user\}\} ]] || [[ $line =~ ~/ ]] || [[ $line =~ /Users/ ]]; then
    # This is a path line — expand it for the current user
    expanded="${line//\{\{user\}\}/$USER}"
    expanded="${expanded//~/$HOME}"
    expanded=$(eval "echo $expanded")

    echo "  Path: $expanded"
    if [[ -e "$expanded" ]]; then
      echo "    ✓ EXISTS"
    else
      echo "    ✗ NOT FOUND — may be created by app, verify during use"
    fi
    echo ""
  fi
done

echo "MANUAL VERIFICATION:"
echo "  1. Did you install, open, and use the app?"
echo "  2. After uninstall, which files/folders remain in:"
echo "       ~/Library/Application Support/"
echo "       ~/Library/Caches/"
echo "       ~/Library/Preferences/"
echo "       ~/Library/Saved Application State/"
echo ""
echo "  3. Compare against the zap stanza above."
echo "  4. Edit if needed: $CASK_FILE"
echo ""
echo "COMMON ZAP PATHS:"
echo "  - \`\${HOME}/Library/Application Support/<AppName>\`"
echo "  - \`\${HOME}/Library/Preferences/com.<company>.<AppName>.plist\`"
echo "  - \`\${HOME}/Library/Caches/<AppName>\`"
echo "  - \`\${HOME}/Library/Saved Application State/<AppName>.savedState\`"
echo ""
