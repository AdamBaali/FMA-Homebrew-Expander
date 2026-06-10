# FMA Homebrew Expander — Complete Documentation

Complete guide to using `scripts/cask-master.sh` for batch Homebrew Cask authoring.

---

## 📖 Table of Contents

1. [Quick Start](#quick-start)
2. [New Features & Safety Improvements](#new-features--safety-improvements)
3. [Flag Reference](#flag-reference)
4. [Common Workflows](#common-workflows)
5. [Monitoring & Debugging](#monitoring--debugging)
6. [Auto-fix Features](#auto-fix-features)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Option 1: Fast Audit (30 seconds per app)
Preview casks without installing:
```bash
DRYRUN=1 bash scripts/cask-master.sh
```
**What happens:** Writes casks, runs `brew style` + `brew audit`, reports issues. No installation.

### Option 2: Full Testing (2-3 minutes per app)
Complete validation before submitting:
```bash
DRYRUN=1 TEST_INSTALL=1 bash scripts/cask-master.sh
```
**What happens:** Audit + install + uninstall + reinstall + zap verification. No PR/FR submission.

### Option 3: Submit First Batch (Recommended)
Submit 10 apps at a time (safe default):
```bash
bash scripts/cask-master.sh
```
**What happens:** Full testing + git push + PR creation + Fleet FR creation. Limits to 10 apps.

### Option 4: Submit Next Batch
Skip apps that already passed:
```bash
BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh
```
**What happens:** Process next 10 apps, skipping those that passed previously.

---

## New Features & Safety Improvements

### 🛡️ Duplicate PR Prevention (`SKIP_OPEN_PR=1`)

**Problem:** Running twice creates duplicate PRs  
**Solution:** Automatically skip apps with existing open PRs

```bash
SKIP_OPEN_PR=1 bash scripts/cask-master.sh
```

**When to use:**
- Re-running without checking if PRs exist
- Updating existing apps without duplicating submissions

### 📦 Batch Processing (`BATCH_SIZE=10`)

**Problem:** 300 apps submitted at once floods Homebrew  
**Solution:** Process apps in controlled batches (default 10)

```bash
bash scripts/cask-master.sh                    # 10 apps (safe default)
BATCH_SIZE=5 bash scripts/cask-master.sh       # 5 apps (smaller batches)
BATCH_SIZE=0 bash scripts/cask-master.sh       # Unlimited (all selected apps)
```

**Workflow for large runs:**
```bash
# Day 1: Submit first 10
bash scripts/cask-master.sh

# Day 2: Submit next 10 (skip what passed)
BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh

# Continue until done...
```

### 🧪 Full Testing in Dry-Run (`TEST_INSTALL=1`)

**Problem:** Can't fully test without committing to submission  
**Solution:** Test everything locally except git push and PR creation

```bash
DRYRUN=1 TEST_INSTALL=1 bash scripts/cask-master.sh
```

**What gets tested:**
- ✅ Version resolution & download
- ✅ SHA256 verification
- ✅ Bundle ID & artifact inspection
- ✅ Cask DSL generation
- ✅ `brew style --fix`
- ✅ `brew audit --strict --online --new`
- ✅ `brew install --cask` (full installation)
- ✅ `brew uninstall --cask` (uninstall)
- ✅ Reinstall for idempotency
- ✅ `brew uninstall --zap` (zap stanza paths)
- ❌ Git push (skipped)
- ❌ PR creation (skipped)
- ❌ Fleet FR creation (skipped)

### 🔧 Auto-fix Features

Automatically detects and fixes common issues:

**Hardcoded Version Strings**
```ruby
# Before: pkg "Escrow.Buddy-1.0.0.pkg"
# After:  pkg "Escrow.Buddy-#{version}.pkg"
```

**Deprecated `depends_on` Syntax**
```ruby
# Before (wrong):
on_arm do
  sha256 "..."
  url "..."
end
on_intel do
  sha256 "..."
  url "..."
end
depends_on macos: :monterey  # ❌ Wrong position

# After (correct):
on_arm do
  sha256 "..."
  url "..."
  depends_on macos: :monterey  # ✅ Correct
end
```

**Other Auto-fixes:**
- Platform words in descriptions ("macOS", "Mac", etc.)
- Redundant `verified:` stanzas
- Trailing periods in descriptions
- Missing leading articles in descriptions
- Missing `depends_on` entries

---

## Flag Reference

### Core Workflow Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `DRYRUN=1` | 0 | Quick audit only (no install, no push, no PR) |
| `TEST_INSTALL=1` | 0 | Full testing (install/uninstall/zap, no push/PR) |
| `BATCH_SIZE=N` | 10 | Max N apps per run (0 = unlimited) |
| `SKIP_OPEN_PR=1` | 0 | Skip apps with existing open PRs |
| `SKIP_PASSED=1` | 0 | Skip apps that already passed |
| `ONLY="a b c"` | — | Run only these apps (space-separated) |
| `LIMIT=N` | — | Run at most N apps total |
| `START_AT=token` | — | Resume from this app (skip earlier ones) |
| `STOP_ON_FAIL=1` | 0 | Stop entire batch on first failure |

### Testing Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `ZAP=0` | 1 | Skip zap verification (faster, less thorough) |
| `LIVECHECK=0` | 1 | Skip livecheck (faster iteration) |
| `STRICT=0` | 1 | Drop `--strict` from audit (not recommended) |

### Cask Submission Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `FILE_FR=0` | 1 | Skip Fleet FR creation |
| `FRESH=0` | 1 | Keep existing open PR instead of refreshing |
| `CUSTOMER_LABEL="label"` | — | Extra label for Fleet FR |

### Performance Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `JOBS=N` | 4 | Parallel prefetch (N concurrent downloads) |
| `KEEP=1` | 0 | Keep downloads (uses more disk space) |
| `CASKWORK=dir` | /tmp/caskwork | Report directory |
| `SUDO_NOPASSWD=0` | 1 | Skip passwordless-sudo setup |

### Other Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `CHECK=1` | 0 | Report registry vs CSV drift (no run) |
| `RUN_BLOCKED=1` | 0 | Also test policy-blocked apps |
| `FORK=name` | "fork" | Git remote name for fork |

---

## Common Workflows

### Workflow 1: Test Before First Submission

```bash
# Step 1: Quick audit
DRYRUN=1 BATCH_SIZE=10 bash scripts/cask-master.sh

# Step 2: Review results
cat /tmp/caskwork/MASTER-summary.md

# Step 3: Full test specific apps
DRYRUN=1 TEST_INSTALL=1 ONLY="escrow-buddy icons" bash scripts/cask-master.sh

# Step 4: Check detailed reports
cat /tmp/caskwork/escrow-buddy/report.md
cat /tmp/caskwork/escrow-buddy/install.log
cat /tmp/caskwork/escrow-buddy/zap.log

# Step 5: Fix issues if needed (edit spec in script)

# Step 6: Re-test after fixes
DRYRUN=1 TEST_INSTALL=1 ONLY="escrow-buddy" bash scripts/cask-master.sh

# Step 7: Submit when confident
bash scripts/cask-master.sh
```

### Workflow 2: Staged Batch Submission (Safe for Fleet)

```bash
# Batch 1: Submit first 10 apps
bash scripts/cask-master.sh

# Batch 2: Submit next 10 (skip those that passed)
BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh

# Batch 3: Submit next 10
BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh

# Continue until all apps submitted
```

### Workflow 3: Fix and Re-run Failed Apps

```bash
# Check what failed
cat /tmp/caskwork/MASTER-summary.md | grep "Failed"

# Re-test failed apps
SKIP_PASSED=1 bash scripts/cask-master.sh
```

### Workflow 4: Resume Interrupted Run

```bash
# Run was interrupted at app "icons"
# Skip everything before "icons", resume from there:
START_AT=icons bash scripts/cask-master.sh

# OR: Skip apps that passed, continue from failures:
SKIP_PASSED=1 bash scripts/cask-master.sh
```

### Workflow 5: Prevent Duplicate PRs

```bash
# First run creates PRs
bash scripts/cask-master.sh

# Later: prevent duplicate PRs when re-running
SKIP_OPEN_PR=1 bash scripts/cask-master.sh
```

### Workflow 6: Test Single App

```bash
# Quick test
DRYRUN=1 ONLY="app-token" bash scripts/cask-master.sh

# Full test
DRYRUN=1 TEST_INSTALL=1 ONLY="app-token" bash scripts/cask-master.sh

# Submit
ONLY="app-token" bash scripts/cask-master.sh
```

---

## Monitoring & Debugging

### Check Overall Results

```bash
# Summary of all apps
cat /tmp/caskwork/MASTER-summary.md

# Tab-separated results (for spreadsheet)
cat /tmp/caskwork/results.tsv

# Failed apps with re-run command
tail /tmp/caskwork/MASTER-summary.md
```

### Check Individual App

```bash
# Full report for one app
cat /tmp/caskwork/escrow-buddy/report.md

# Cask file that was generated
cat /tmp/caskwork/escrow-buddy/escrow-buddy.rb

# Audit output
cat /tmp/caskwork/escrow-buddy/audit.log

# Install test
cat /tmp/caskwork/escrow-buddy/install.log

# Uninstall test
cat /tmp/caskwork/escrow-buddy/uninstall.log

# Zap test
cat /tmp/caskwork/escrow-buddy/zap.log
```

### Check Auto-fixes Applied

```bash
# See what was auto-fixed for each app
grep "AUTOFIX:" /tmp/caskwork/*/report.md

# See specific fixes
grep "replaced hardcoded versions" /tmp/caskwork/*/report.md
grep "fixed deprecated depends_on" /tmp/caskwork/*/report.md
```

---

## Auto-fix Features

The script automatically detects and fixes these issues:

### 1. Hardcoded Version Strings
**Detection:** `pkg` or `app` stanzas with version numbers in filenames  
**Fix:** Replaces with `#{version}` variable  
**Example:** `pkg "App-1.0.0.pkg"` → `pkg "App-#{version}.pkg"`

### 2. Deprecated `depends_on` Syntax
**Detection:** `brew audit` warning about deprecated `depends_on` syntax  
**Fix:** Moves `depends_on` into architecture-specific blocks  
**When:** Only when cask has `on_arm`/`on_intel` blocks

### 3. Platform Words in Descriptions
**Detection:** Audit warning about platform words in description  
**Fix:** Removes "macOS", "Mac", "Windows", "Linux", etc.

### 4. Redundant `verified:` Stanzas
**Detection:** Audit warning about unnecessary verified stanza  
**Fix:** Removes verified when domain matches homepage

### 5. Trailing Periods in Descriptions
**Detection:** Description ends with period  
**Fix:** Removes trailing period

### 6. Leading Articles in Descriptions
**Detection:** Description starts with "A" or "The"  
**Fix:** Removes leading article

### 7. Missing `depends_on` Entries
**Detection:** Audit warning about minimum macOS requirement  
**Fix:** Adds `depends_on macos: :symbol` when needed

---

## Troubleshooting

### "Double PR created"
**Problem:** Same app has two open PRs  
**Fix:** Use `SKIP_OPEN_PR=1` for future runs:
```bash
SKIP_OPEN_PR=1 bash scripts/cask-master.sh
```

### Run was interrupted
**Problem:** Script stopped halfway through  
**Fix:** Resume from failures:
```bash
SKIP_PASSED=1 bash scripts/cask-master.sh
```

### Disk filling up
**Problem:** `/tmp/caskwork` or `/tmp` running out of space  
**Fix:** Clean up downloads (reports are kept):
```bash
rm -rf /tmp/caskwork/*/dl /tmp/caskwork/*/x  # Keep reports
rm -rf /tmp/caskwork                          # Remove everything
```
Or use persistent directory:
```bash
CASKWORK=~/caskwork bash scripts/cask-master.sh
```

### Want to update existing PR
**Problem:** Want to re-test and update an app that has a PR  
**Solution:** Default behavior updates open PRs:
```bash
bash scripts/cask-master.sh                # Updates open PRs (FRESH=1)
SKIP_OPEN_PR=1 bash scripts/cask-master.sh # Skip existing, process failures
```

### Brew style/audit taking too long
**Problem:** Slow iteration during testing  
**Fix:** Skip slow steps:
```bash
DRYRUN=1 LIVECHECK=0 ZAP=0 ONLY="app" bash scripts/cask-master.sh
```

### Sudo prompts appearing
**Problem:** Being asked for sudo password repeatedly  
**Fix:** Default behavior handles this automatically (SUDO_NOPASSWD=1). If issues persist:
```bash
SUDO_NOPASSWD=0 bash scripts/cask-master.sh  # Keep timestamp warm manually
```

---

## Registry Format

Apps are defined in the `REGISTRY` variable at the top of the script:

```
token | name | description | artifact | source | homepage | spec
```

**Example:**
```
escrow-buddy | Escrow Buddy | Escrows FileVault recovery keys at the login window | pkg | github_tag | https://github.com/macadmins/escrow-buddy | repo=macadmins/escrow-buddy;asset=Escrow.Buddy-{v}.pkg
```

**Fields:**
- `token`: Lowercase, hyphenated identifier (must not collide with Homebrew formulae)
- `name`: Human-readable app name
- `description`: Max 80 chars, no platform words, no leading article, no period
- `artifact`: `zip`, `dmg`, or `pkg` (anything else makes app ineligible)
- `source`: How to resolve version/download:
  - `github_tag` — GitHub releases
  - `github_arch` — GitHub releases with architecture-specific builds
  - `github_compound` — GitHub with compound versioning
  - `electron` — Electron Builder feeds
  - `direct` — Direct URL with manual version/regex
  - `direct_latest` — Direct URL, auto-detect latest
  - `direct_arch` — Direct URL with architecture variants
  - `direct_header` — Direct URL via HTTP redirects
  - `msft_cdn` — Microsoft CDN downloads
  - `custom` — Custom resolver function
- `spec`: Key=value pairs for source-specific configuration

---

## Best Practices

### 1. Always Start with DRYRUN
```bash
DRYRUN=1 bash scripts/cask-master.sh  # Preview first
# Review reports, then run for real
bash scripts/cask-master.sh
```

### 2. Use Small Batches When Testing
```bash
BATCH_SIZE=5 DRYRUN=1 bash scripts/cask-master.sh   # Test with 5
bash scripts/cask-master.sh                          # Real with 10
```

### 3. Preserve Work with Persistent CASKWORK
```bash
# Avoid losing work to /tmp wipe
CASKWORK=~/caskwork bash scripts/cask-master.sh
```

### 4. Skip Slow Steps When Iterating
```bash
# Faster testing (skip livecheck + zap)
DRYRUN=1 LIVECHECK=0 ZAP=0 ONLY="app" bash scripts/cask-master.sh
```

### 5. Test Full Workflow Before Large Batch
```bash
# Test on 1 app first
DRYRUN=1 TEST_INSTALL=1 ONLY="one-app" bash scripts/cask-master.sh

# Then test on small batch
BATCH_SIZE=5 bash scripts/cask-master.sh

# Then commit to full batch
BATCH_SIZE=10 bash scripts/cask-master.sh
```

---

## Time Estimates

| Operation | Time per App |
|-----------|--------------|
| Quick audit (DRYRUN=1) | 30 seconds |
| Full test (DRYRUN=1 TEST_INSTALL=1) | 2-3 minutes |
| Full run with submission | 2-3 minutes |
| Install only | ~1 minute |
| Install + Uninstall | ~1.5 minutes |
| Install + Uninstall + Reinstall + Zap | ~2 minutes |

Batch times (approximate):
- 10 apps audit-only: 5 minutes
- 10 apps full test: 20-30 minutes
- 10 apps with submission: 20-30 minutes

---

## Support & References

- **Project instructions:** See `CLAUDE.md`
- **Policy blocklist:** See `NOT-ADDED.md`
- **Registry and verdicts:** See `data/master-list.csv`
- **Cask authoring skill:** `.claude/skills/homebrew-cask-author/`
- **Script source:** `scripts/cask-master.sh` (fully commented)

---

**Last updated:** 2026-06-10
