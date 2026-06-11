# End-to-End Cask Validation Workflow

This document describes the comprehensive end-to-end validation system for generating high-quality Homebrew casks with proper regex patterns, best practices, and zero guessing.

## Overview

The validation workflow consists of 4 integrated scripts that work together:

1. **end-to-end-validate.sh** — Main validation harness (14 phases)
2. **analyze-cask.sh** — Code quality and best practices analysis
3. **cask-fixer.sh** — Automated fixes for common issues
4. **validate-all-prs.sh** — Orchestration for all 20 apps

## Quick Start

### Validate a single app (with interactive testing):

```bash
bash end-to-end-validate.sh poll-everywhere
```

This will:
- Generate the cask
- Capture filesystem state before app launch
- Install and open the app (you interact with it for 1-2 min)
- Capture filesystem state after app close
- Verify all created files are in the zap stanza
- Run style, audit, and livecheck checks
- Reinstall and test zap cleanup
- Generate a detailed report

### Validate all 20 open PRs:

```bash
bash validate-all-prs.sh
```

This runs end-to-end validation for each app and generates:
- Per-app e2e validation reports
- Code quality analysis
- Summary of which apps are ready vs need review
- Actionable next steps

### Analyze a cask for quality issues:

```bash
bash analyze-cask.sh ~/caskwork/poll-everywhere/poll-everywhere.rb
```

This checks for:
- Hardcoded versions in URLs
- Deprecated syntax
- Missing or incomplete zap stanzas
- Livecheck quality
- App metadata correctness
- Code style issues

### Auto-fix common issues:

```bash
bash cask-fixer.sh ~/caskwork/poll-everywhere/poll-everywhere.rb
```

This automatically fixes:
- Hardcoded versions → `#{version}` interpolation
- Deprecated `depends_on :macos` syntax
- Whitespace and formatting
- Minor style issues

## Validation Phases Explained

### Phase 1: Cask Generation
Runs `cask-master.sh` with `TEST_INSTALL=1` to fully test the app locally without publishing.

**Verifies:**
- Version resolution works
- Download succeeds
- SHA256 computation correct
- Cask syntax valid

### Phase 2: Metadata Extraction
Parses the generated cask to extract:
- App name
- Bundle ID (if present)
- Minimum macOS version
- Download URL

### Phase 3: Pre-app Filesystem Snapshot
Captures baseline filesystem state across:
- `~/Library/Application Support`
- `~/Library/Preferences`
- `~/Library/Caches`
- `~/Library/Saved Application State`
- `~/Library/HTTPStorages`
- `/Library/LaunchDaemons`
- `/Library/LaunchAgents`

This establishes what files/folders exist before the app runs, so we can detect what it creates.

### Phase 4: Install App
Installs the app via `brew install --cask <app>` to verify:
- DMG/PKG extraction works
- App placement is correct
- Dependencies resolve
- No installation errors

### Phase 5: Open & Monitor App
User interacts with the app for 1-2 minutes while:
- The script monitors CPU and file changes
- The user can create files, change preferences, etc.
- After 60s (or when user closes the app), the script force-closes it

**This is critical** because it ensures:
- The app actually runs and works
- We capture ALL files/folders it creates
- We get accurate zap stanza data

### Phase 6: Post-app Filesystem Snapshot
Captures the filesystem again and diffs against Phase 3 to get the exact list of files created by:
- App initialization
- User interactions
- Preference/setting changes

### Phase 7: Verify Zap Stanza
Compares files created (from Phase 6) against the zap stanza in the cask:

- ✓ All created files are in `zap trash:`
- ✗ Files created but not in zap → must be added
- ⚠ Zap paths don't cover all locations → needs fixing

**Critical quality check**: The zap stanza must actually remove all traces of the app.

### Phase 8: Cask Style Check
Runs `brew style` to verify:
- Consistent indentation (2 spaces)
- Proper syntax
- Formatting standards

Homebrew will auto-fix some issues; others require manual fixes.

### Phase 9: Audit Cask
Runs `brew audit --cask --strict --online --new` to verify:
- All required fields present
- Deprecated syntax removed
- URLs are correct and reachable
- SHA256 is accurate
- Livecheck is valid (if present)
- No conflicts with existing casks
- Cask follows Homebrew policy

**Most important check** — audit must pass for Homebrew submission.

### Phase 10: Livecheck Validation
Tests the livecheck block to verify:
- Regex pattern correctly matches app versions
- Strategy is appropriate (page_match, header_match, git)
- Version detection works
- Will catch future app updates

**Livecheck quality matters**: Bad regex means the cask won't auto-update.

### Phase 11: Verify App Metadata
Compares declared app metadata against actual app:
- Bundle ID: `mdls -name kMDItemCFBundleIdentifier` ✓ matches cask
- App path: `/Applications/<app>.app` ✓ correct
- Minimum macOS: ✓ app runs on declared minimum

### Phase 12: Uninstall
Tests `brew uninstall --cask <app>` to verify:
- App is cleanly removed
- No errors during uninstall

### Phase 13: Reinstall Test (Idempotency)
Reinstalls the app to verify:
- Cask is idempotent (can be installed multiple times)
- Installation always succeeds
- App works after reinstall

**This is how users interact with brew** — they may run `brew install` multiple times.

### Phase 14: Zap Cleanup Verification
Runs `brew uninstall --zap --cask <app>` and verifies:
- All paths in zap stanza are actually removed
- No files remain in `~/Library/`
- Complete cleanup

If zap stanza is incomplete, leftover files will remain.

## Quality Analysis Checks

The `analyze-cask.sh` script performs these checks:

### 1. Hardcoded Versions
❌ **Bad:** `url "https://example.com/app-1.2.3.dmg"`
✅ **Good:** `url "https://example.com/app-#{version}.dmg"`

The version should be interpolated, not hardcoded.

### 2. Deprecated Syntax
❌ **Bad:** `depends_on :macos => :monterey`
✅ **Good:** `depends_on macos: :monterey`

Use modern Ruby syntax.

### 3. Verified Source
❌ **Bad:** No verified source
✅ **Good:** `url "...", verified: "example.com"`

Verified sources enable checksum verification for security.

### 4. Livecheck Quality
❌ **Bad:** No livecheck block (manual updates only)
✅ **Good:** Livecheck with appropriate regex and strategy

Good livecheck = automatic update detection.

### 5. Complete Zap Stanza
❌ **Bad:** No zap block (uninstall leaves data behind)
✅ **Good:** Comprehensive trash/delete paths covering all app data

Users expect `brew uninstall --zap` to completely remove the app.

### 6. App Metadata
✅ Check that declared app path matches actual app
✅ Check bundle ID is correct
✅ Check minimum macOS is accurate

## Workflow: Generate → Validate → Fix → Submit

### Step 1: Generate
```bash
# Auto-generate casks for first batch
BATCH_SIZE=10 bash scripts/cask-master.sh
```

### Step 2: Validate
```bash
# Run comprehensive end-to-end validation
bash validate-all-prs.sh
```

This generates a summary showing:
- ✓ Ready for submission (X apps)
- ⚠ Need review/fixes (Y apps)
- ✗ Failed validation (Z apps)

### Step 3: Analyze & Fix
For any app marked "Need review":

```bash
# See what needs fixing
bash analyze-cask.sh ~/caskwork/<app>/<app>.rb

# Auto-fix common issues
bash cask-fixer.sh ~/caskwork/<app>/<app>.rb

# Re-run validation to verify fixes
bash end-to-end-validate.sh <app>
```

### Step 4: Submit
```bash
# Submit validated casks as PRs
bash scripts/cask-master.sh  # without DRYRUN
```

## Understanding Zap Stanzas

The zap stanza is critical. It should cover:

### Standard Locations
```ruby
zap trash: [
  "~/Library/Application Support/app-name",        # App data
  "~/Library/Preferences/com.company.app.plist",   # Preferences
  "~/Library/Caches/com.company.app",              # Caches
  "~/Library/Saved Application State/app.savedState",  # Window state
]
```

### Extended Locations (if app uses them)
```ruby
zap trash: [
  # ... standard locations ...
  "~/Library/HTTPStorages/com.company.app",        # HTTP cookies
  "~/Library/WebKit/com.company.app",              # WebKit data
  "/Library/LaunchAgents/com.company.app.plist",   # User agent
  "/Library/LaunchDaemons/com.company.app.plist",  # System daemon
]
```

### Detection Process
1. **Phase 3**: Capture baseline filesystem
2. **Phase 5**: User opens app and creates data
3. **Phase 6**: Capture filesystem again
4. **Phase 7**: Diff shows exactly what app created
5. **Zap stanza**: Must include all files from diff

If the diff shows:
```
~/Library/Application Support/MyApp/config.plist
~/Library/Preferences/com.mycompany.MyApp.plist
~/Library/Caches/com.mycompany.MyApp
```

Then the zap stanza must include all three paths.

## Regex Patterns for Livecheck

Good regex patterns are critical for auto-updates.

### Examples

**Simple semantic versioning:**
```ruby
regex(%r{MyApp[._-]v?(\d+(?:\.\d+)*)}i)
```

**Date-based versioning (e.g., 2024.6.1):**
```ruby
regex(%r{(\d{4}(?:\.\d+)+)}i)
```

**From GitHub releases:**
```ruby
regex(%r{releases/tag/v?(\d+(?:\.\d+)*)}i)
```

**From S3 or CDN:**
```ruby
regex(%r{/(\d+(?:\.\d+)+)/}i)
```

### Testing Regex
```bash
# Extract the livecheck from a cask and test it
brew livecheck --cask <app>
```

If this shows:
```
<app>: 1.2.3 ==> 1.2.4
```

Your regex is working! If it shows nothing or errors, the regex needs fixing.

## When to Investigate Deeper

### Regex not matching all versions
1. Check if app uses pre-release versions (alpha, beta, rc)
2. Check if app uses date-based versioning
3. Check if version has unusual suffixes
4. Test regex with online tools (regex101.com)

### Livecheck fails completely
1. Verify the URL is still valid
2. Check if the source has changed
3. Consider switching strategies (page_match → header_match)
4. Use `brew livecheck --cask <app> --verbose` for debugging

### Zap stanza incomplete
1. Run the app yourself and check `~/Library/Application Support/`
2. Check for hidden files: `ls -la ~/Library/Application\ Support/ | grep <app>`
3. Check Preferences: `defaults read | grep <app>`
4. Add any missing paths to zap stanza

### App doesn't install
1. Check the download URL is correct
2. Verify SHA256 with: `shasum -a 256 <downloaded-file>`
3. Try manual download to verify it works
4. Check for code signing issues: `codesign -v /Applications/<app>.app`

## Common Issues and Fixes

| Issue | Fix |
|-------|-----|
| Hardcoded version in URL | Replace with `#{version}` |
| Deprecated `depends_on :macos` | Use `depends_on macos:` syntax |
| No livecheck | Add livecheck block with appropriate strategy |
| Incomplete zap stanza | Run app, capture created files, add to zap |
| Regex not matching | Test with actual app URLs, refine pattern |
| Bundle ID mismatch | Update cask to match actual app bundle ID |
| App won't install | Verify URL, SHA256, and archive format |

## Troubleshooting

### "Cask file not found"
The cask generation likely failed. Check:
```bash
cat ~/caskwork/<app>/report.md
```

### "brew audit failed"
Read the audit output carefully:
```bash
brew audit --cask --strict --online --new ~/caskwork/<app>/<app>.rb
```

Common issues:
- URL unreachable → verify URL works manually
- SHA256 wrong → recalculate
- Duplicate cask → check existing Homebrew casks

### "Zap paths not matching"
Run manually to see what files the app creates:
```bash
# Before
ls -la ~/Library/Application\ Support/ | grep <app>

# After opening app
ls -la ~/Library/Application\ Support/ | grep <app>
```

### "Livecheck not working"
Test manually:
```bash
brew livecheck --cask <app> --verbose
```

If this fails, the livecheck needs adjustment.

## Next Steps

1. **Start with one app:**
   ```bash
   bash end-to-end-validate.sh poll-everywhere
   ```

2. **Review the generated report:**
   ```bash
   cat ~/caskwork/e2e-reports/poll-everywhere-validation.md
   ```

3. **If issues found, analyze and fix:**
   ```bash
   bash analyze-cask.sh ~/caskwork/poll-everywhere/poll-everywhere.rb
   bash cask-fixer.sh ~/caskwork/poll-everywhere/poll-everywhere.rb
   ```

4. **Re-validate:**
   ```bash
   bash end-to-end-validate.sh poll-everywhere
   ```

5. **Once perfect, run all 20:**
   ```bash
   bash validate-all-prs.sh
   ```

6. **Submit ready casks:**
   ```bash
   bash scripts/cask-master.sh
   ```

## Questions?

Refer to:
- [Homebrew Cask Documentation](https://github.com/Homebrew/homebrew-cask/blob/master/CONTRIBUTING.md)
- [Cask DSL Reference](https://github.com/Homebrew/homebrew-cask/blob/master/doc/cask_language_reference.md)
- [Livecheck Documentation](https://github.com/Homebrew/homebrew-cask/blob/master/doc/cask_language_reference/stanzas/livecheck.md)
