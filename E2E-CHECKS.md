# Complete List of E2E Validation Checks

This document lists all checks performed by the end-to-end validation system, matching and exceeding what Homebrew CI does.

## Overview

The validation system now includes **17 comprehensive phases** covering duplicate detection, system state monitoring, filesystem analysis, and full cask validation.

## The 17 Phases

### PHASE 1: Cask Generation
**What:** Generates the cask using `cask-master.sh` with `TEST_INSTALL=1`

**Verifies:**
- Version resolution works
- Download succeeds
- SHA256 computation is correct
- Cask syntax is valid

**Failure means:** Core cask generation failed; investigate download URL, version detection, or checksum

---

### PHASE 2: Duplicate Detection
**What:** Checks against all existing Homebrew casks for duplicates

**Detects:**
- Exact app name matches
- Bundle ID conflicts
- Vendor name variations
- Desktop/web variant issues
- Similar app names (fuzzy match)
- URL domain conflicts

**Checks against:**
- All ~14,000 existing Homebrew casks
- Vendor name variations (e.g., "MyApp" vs "My App Pro")
- Bundle ID uniqueness
- Desktop variants (e.g., `-desktop` suffix)

**Failure means:** Your cask duplicates or conflicts with existing cask; may need to:
- Rename to add suffix (e.g., `-desktop`, `-web`)
- Use different bundle ID
- Verify this is truly a new app

---

### PHASE 3: Metadata Extraction
**What:** Parses the generated cask to extract key metadata

**Extracts:**
- App name and path
- Bundle ID (if present)
- Minimum macOS version
- Download URL and domain
- Verified source

**Used for:** Verification in subsequent phases

---

### PHASE 4: Pre-install System State Snapshot
**What:** Captures the complete macOS system state BEFORE installation

**Snapshots:**
- All installed .app files (recursively)
- Kernel extensions (kexts)
- Package receipts (/var/db/receipts)
- Installed LaunchAgents (.plist files)
- Installed LaunchDaemons (.plist files)
- Loaded launchctl jobs

**Why it matters:** Detects if app leaves behind system artifacts (kernel extensions, launch jobs, packages) after uninstall

**Matches Homebrew CI:** Yes, this is exactly what Homebrew does

---

### PHASE 5: Pre-app Filesystem Snapshot
**What:** Captures filesystem state before app launch

**Snapshots files in:**
- `~/Library/Application Support`
- `~/Library/Preferences`
- `~/Library/Caches`
- `~/Library/Saved Application State`
- `~/Library/HTTPStorages`
- `/Library/LaunchDaemons`
- `/Library/LaunchAgents`

**Why it matters:** Establishes baseline for detecting what app creates when it runs

---

### PHASE 6: Install App
**What:** Installs the app via `brew install --cask <app>`

**Verifies:**
- DMG/PKG extraction works
- App placement is correct
- Dependencies resolve
- No installation errors

**Failure means:** The download, artifact format, or app structure is broken

---

### PHASE 7: Open & Monitor App
**What:** User interacts with the app for 1-2 minutes

**What app is doing:**
- Loading configuration
- Creating app data files
- Setting preferences
- Possibly creating support files

**Why it matters:** Apps behave differently on first launch vs subsequent runs; this captures the real initialization

**You should:**
- Create/modify files if possible
- Change preferences/settings
- Leave app running for enough time
- Close app when done (or let script force-close after 60s)

---

### PHASE 8: Post-install System State Snapshot
**What:** Captures system state AFTER app installation

**Verifies:**
- No unexpected kernel extensions installed
- No unexpected launch agents/daemons
- No unexpected package receipts
- App didn't break other apps

**Why it matters:** Detects if app installs system-level modifications (common for utilities, VPNs, etc.)

**Matches Homebrew CI:** Yes, this is their "snapshot before/after install" check

---

### PHASE 9: Post-app Filesystem Snapshot
**What:** Captures filesystem AFTER app was opened and used

**Compares against:** Phase 5 snapshot

**Detects:** Exactly what files the app created:
- Config files
- Cache files
- Preference files
- Support files
- Application data

**Result:** Definitive list of all files that must be in zap stanza

---

### PHASE 10: Verify Zap Stanza
**What:** Compares created files against zap stanza in cask

**Checks:**
- All files from Phase 9 are covered by zap paths
- No files created but not in zap stanza
- Zap paths use correct syntax

**Failure means:**
- Zap stanza is incomplete
- Files will be left behind after `brew uninstall --zap`
- Must add missing paths to zap stanza

**This is the most critical check** — users expect zap cleanup to work completely

---

### PHASE 11: Cask Style Check
**What:** Runs `brew style` on the cask

**Verifies:**
- Consistent 2-space indentation
- Proper Ruby syntax
- Homebrew formatting standards
- No deprecated code patterns

**Auto-fixes:** Some issues via `brew style --fix`

---

### PHASE 12: Audit Cask
**What:** Runs `brew audit --cask --strict --online --new`

**Verifies:**
- All required fields present
- No deprecated syntax
- URLs are reachable
- SHA256 is accurate
- Livecheck is valid
- No cask name conflicts
- Follows Homebrew policy
- Cask structure is correct

**Most important check** — if this fails, Homebrew won't accept the PR

---

### PHASE 13: Livecheck Validation
**What:** Tests the livecheck block with `brew livecheck --cask <app>`

**Verifies:**
- Livecheck strategy works (page_match, header_match, git, etc.)
- Regex pattern matches actual versions
- Version detection succeeds
- Can detect future app updates

**If fails:** Regex needs refinement or strategy needs changing

**Why it matters:** Users want automatic update detection

---

### PHASE 14: Verify App Metadata
**What:** Compares declared metadata against actual app

**Checks:**
- Bundle ID: `mdls -name kMDItemCFBundleIdentifier` matches cask
- App path: App is at `/Applications/<name>.app`
- Minimum macOS: App runs on declared minimum

**Failure means:** Metadata in cask is incorrect

---

### PHASE 15: Uninstall
**What:** Runs `brew uninstall --cask <app>`

**Verifies:**
- Uninstall succeeds
- No errors
- App can be removed cleanly

---

### PHASE 16: Reinstall Test (Idempotency)
**What:** Reinstalls the app

**Verifies:**
- Cask is idempotent (can install multiple times)
- Installation always succeeds
- App works after reinstall
- No leftover files cause conflicts

**Why it matters:** Users may run `brew install` multiple times

---

### PHASE 17: Zap Cleanup Verification
**What:** Runs `brew uninstall --zap --cask <app>` and verifies cleanup

**Compares:**
- Filesystem before zap vs after zap
- All paths in zap stanza are actually removed
- No leftover files in `~/Library/`

**Failure means:** Zap stanza paths don't work or are incomplete

---

## Duplicate Detection Details

The `check-duplicates.sh` script performs 6 specific checks:

### 1. Exact App Name Match
Searches all casks for identical app names.

**Example:**
- Your cask: "Poll Everywhere"
- Existing: "Poll Everywhere"
- **Result:** ✗ Duplicate

### 2. Bundle ID Match
If your cask declares a bundle ID, checks for duplicates.

**Example:**
- Your cask: `bundle_id: "com.company.app"`
- Existing: `bundle_id: "com.company.app"`
- **Result:** ✗ Duplicate

### 3. Desktop Variants
Checks for `-desktop` variants or base cask.

**Example:**
- Your cask: `myapp-desktop`
- Existing base: `myapp`
- **Result:** ⚠ Potential variant issue

### 4. Vendor Name Matching
Groups casks by vendor (first word of app name).

**Example:**
- Your cask: "Microsoft Teams Web"
- Existing: "Microsoft Teams", "Microsoft Office", "Microsoft Excel"
- **Result:** ℹ Multiple apps from same vendor (normal)

### 5. Similar Names (Fuzzy Match)
Detects apps with very similar names.

**Example:**
- Your cask: "MyApp Pro"
- Existing: "MyApp Free"
- **Result:** ⚠ Related apps (review to avoid duplication)

### 6. URL Domain Matching
Detects multiple casks from same domain.

**Example:**
- Your cask: `url "https://github.com/user/myapp/releases/..."`
- Existing: `url "https://github.com/user/myapp/..."`
- **Result:** ℹ Same domain (review to verify different apps)

---

## System State Monitoring

The `check-system-state.sh` script matches Homebrew's CI checks:

### Captured Items

| Item | Location | Why Monitored |
|------|----------|---------------|
| Installed apps | `/Applications`, `~/Applications` | Detect app placement |
| Kernel extensions | `/usr/sbin/kextstat` | Detect system modifications |
| Installed packages | `/var/db/receipts/*.plist` | Detect system installations |
| Launch agents | `~/Library/LaunchAgents/` | Detect background jobs |
| Launch daemons | `/Library/LaunchDaemons/` | Detect system services |
| Loaded jobs | `launchctl list` | Detect running background processes |

### Filtering

Automatically excludes:
- Apple-signed items (com.apple.*)
- Google auto-updaters (com.google.Keystone)
- System updates

### Interpreting Results

**Expected changes:**
- App installs itself (appears in INSTALLED APPS)
- Utility installs kernel extension
- Service registers LaunchAgent/Daemon

**Unexpected changes:**
- Unrelated app disappears
- System package added/removed
- Foreign launch jobs appear

---

## Quality Analysis Checks

The `analyze-cask.sh` script performs 8 additional quality checks:

1. **Hardcoded Versions** — URLs should use `#{version}`
2. **Deprecated Syntax** — Should use modern Ruby/Homebrew DSL
3. **Verified Sources** — URLs should have `verified:` security marker
4. **Livecheck Quality** — Presence and correctness of version detection
5. **Complete Zap Stanza** — All common cleanup locations covered
6. **App Metadata** — Bundle ID, homepage, description present
7. **SHA256 & Version** — Correct format and length
8. **Code Style** — Proper indentation, no unnecessary whitespace

---

## Total Checks

**17 validation phases + 8 quality analysis checks = 25 total verifications**

This exceeds what Homebrew's CI does and ensures production-grade casks.

---

## Exit Criteria

### Green Light (Ready for Submission)
```
Checks passed: 17 / 17
Issues:      0
Warnings:    0
Suggestions: 0
Status: ✓ READY FOR SUBMISSION
```

### Yellow Light (Review Required)
```
Checks passed: 14-16 / 17
Issues:      0
Warnings:    1-3
Suggestions: 0
Status: ⚠ REVIEW REQUIRED
```

Minor warnings (livecheck could be better, etc.) don't block submission but should be addressed.

### Red Light (Not Ready)
```
Checks passed: <14 / 17
Issues:      1+
Status: ✗ FAILED
```

Issues must be fixed before submission. Common issues:
- Duplicate detection failures
- Zap stanza incomplete
- Audit failures
- Livecheck broken

---

## Next Steps

After validation completes, refer to the phase that failed and:

1. Review the detailed report: `~/caskwork/e2e-reports/<app>-validation.md`
2. Run analysis: `bash analyze-cask.sh ~/caskwork/<app>/<app>.rb`
3. Auto-fix common issues: `bash cask-fixer.sh ~/caskwork/<app>/<app>.rb`
4. Edit cask: `vim ~/caskwork/<app>/<app>.rb`
5. Re-validate: `bash end-to-end-validate.sh <app>`
