# Interactive Testing Workflow

This workflow addresses the reviewer feedback: **verify zap stanzas by actually installing, opening, and using each app before submitting.**

## Quick Start

```bash
# Start testing 20 apps one at a time
bash test-interactive.sh

# Or test a specific app
bash verify-zap-paths.sh slack
```

## Per-App Verification Checklist

For **each app**, follow this exact sequence:

### 1. Review the generated cask
```bash
# After the script pauses, review:
cat $CASKWORK/<app-token>/cask.rb
```
Check:
- [ ] Version is correct (not hardcoded)
- [ ] URLs are valid and downloadable
- [ ] Syntax looks correct

### 2. Install the app
```bash
brew install --cask <app-token>
```

### 3. Open and use the app
- [ ] Launch the app
- [ ] Create files / change settings / interact with it
- [ ] Use it for at least 1-2 minutes (not just launch)
- [ ] Quit the app

### 4. Check what was left behind
After you uninstall, you'll need to know which files/folders the app leaves behind.

**Manual check:**
```bash
# Before uninstalling, note the current state:
ls -la ~/Library/Application\ Support/
ls -la ~/Library/Preferences/ | grep -i <appname>
ls -la ~/Library/Caches/ | grep -i <appname>
ls -la ~/Library/Saved\ Application\ State/ | grep -i <appname>

# Then uninstall:
brew uninstall --cask <app-token>

# Check what remains:
ls -la ~/Library/Application\ Support/ | grep -i <appname>
ls -la ~/Library/Preferences/ | grep -i <appname>
ls -la ~/Library/Caches/ | grep -i <appname>
ls -la ~/Library/Saved\ Application\ State/ | grep -i <appname>
```

### 5. Verify/fix the zap stanza
The generated zap stanza likely won't be 100% correct. Use the helper:

```bash
bash verify-zap-paths.sh <app-token>
```

Compare the helper output against what you found in step 4. Edit if needed:

```bash
# Edit the cask directly:
vim $CASKWORK/<app-token>/cask.rb

# Find the zap block and update paths based on what you found
```

**Common zap paths:**
- `#{ENV["HOME"]}/Library/Application Support/<AppName>`
- `#{ENV["HOME"]}/Library/Preferences/com.<company>.<appname>.plist`
- `#{ENV["HOME"]}/Library/Caches/<AppName>`
- `#{ENV["HOME"]}/Library/Saved Application State/<AppName>.savedState`

### 6. Re-test your fix (optional but recommended)
If you edited the cask, test it again:

```bash
brew install --cask <app-token>
# Use the app
brew uninstall --cask <app-token>
# Verify nothing remains
```

### 7. Continue to next app
When the script pauses, press Enter to move to the next app.

## After All 20 Apps Are Tested

```bash
# Review the summary:
cat $CASKWORK/MASTER-summary.md

# When ready to submit PRs:
bash scripts/cask-master.sh
```

## Responding to Reviewer Comments

With this workflow, you can now confidently respond to reviewers:

> "I installed the app, opened it, created files, changed settings, then uninstalled and verified which files remained. The zap stanza includes [specific paths] that I confirmed exist after installation."

This shows you actually verified the paths, not just copied them from other casks.

## Disk Management

If you run out of disk space while testing:

```bash
# Keep reports, delete downloads:
rm -rf /tmp/caskwork/*/dl /tmp/caskwork/*/x

# Or use a persistent directory:
export CASKWORK=~/caskwork
bash test-interactive.sh
```
