# FMA Homebrew Expander — Quick Usage Guide

This guide covers the complete workflow and all the improvements made to the `cask-master.sh` script.

## 🚀 Quick Start

### Safe Testing (No Real PRs/FRs)
```bash
# Preview first 10 apps without creating PRs
DRYRUN=1 bash scripts/cask-master.sh

# Check results
cat /tmp/caskwork/MASTER-summary.md
```

### First Batch Submission
```bash
# Submit the first 10 apps (creates PRs + Fleet FRs)
bash scripts/cask-master.sh

# Check status
cat /tmp/caskwork/results.tsv
```

### Subsequent Batches
```bash
# Submit next batch while skipping apps that already passed
BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh
```

---

## 📋 Complete Flag Reference

### Core Workflow
| Flag | Default | Purpose |
|------|---------|---------|
| `DRYRUN=1` | 0 | Preview only — no PRs, no installs, no git changes |
| `ONLY="a b c"` | — | Run only specific apps (space-separated) |
| `LIMIT=N` | — | Run at most N apps total |

### Batch Processing & Safety
| Flag | Default | Purpose |
|------|---------|---------|
| `BATCH_SIZE=N` | 10 | Limit to N apps per run (0 = unlimited) |
| `SKIP_OPEN_PR=1` | 0 | Skip apps with open PRs (prevent duplicates) |
| `SKIP_PASSED=1` | 0 | Skip apps that already passed previous runs |
| `STOP_ON_FAIL=1` | 0 | Stop the entire batch on first failure |

### Performance & Testing
| Flag | Default | Purpose |
|------|---------|---------|
| `JOBS=N` | 4 | Parallel prefetch (4 = 4 concurrent downloads) |
| `LIVECHECK=0` | 1 | Skip livecheck (faster iteration during testing) |
| `KEEP=1` | 0 | Keep app downloads/extracts (uses more disk) |

### Cask Quality
| Flag | Default | Purpose |
|------|---------|---------|
| `ZAP=0` | 1 | Skip zap test (faster, but less verification) |
| `STRICT=0` | 1 | Drop --strict from brew audit (not recommended) |

### PR Management
| Flag | Default | Purpose |
|------|---------|---------|
| `FRESH=0` | 1 | Keep existing open PR instead of refreshing |
| `FILE_FR=0` | 1 | Create cask PR but skip Fleet FR |

---

## 💡 Common Workflows

### Workflow 1: Safe Testing Before Submission
```bash
# 1. Preview the first batch
DRYRUN=1 bash scripts/cask-master.sh

# 2. Review the report
cat /tmp/caskwork/MASTER-summary.md
cat /tmp/caskwork/escrow-buddy/report.md  # Check individual app

# 3. Fix issues if needed (edit scripts/cask-master.sh spec/custom resolvers)

# 4. Iterate on specific apps
DRYRUN=1 ONLY="escrow-buddy icons" LIVECHECK=0 bash scripts/cask-master.sh
```

### Workflow 2: Staged Batch Submission (Safe for Fleet)
```bash
# Batch 1: Submit first 10 apps
bash scripts/cask-master.sh

# Batch 2: Submit next 10 apps (skip those that passed)
BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh

# Batch 3: Submit remaining apps
BATCH_SIZE=0 SKIP_PASSED=1 bash scripts/cask-master.sh

# OR: Skip apps with open PRs to only process failures
BATCH_SIZE=10 SKIP_PASSED=1 SKIP_OPEN_PR=1 bash scripts/cask-master.sh
```

### Workflow 3: Updating Existing PRs
```bash
# Fix issues in your registry/custom resolvers

# Re-run to push updated casks to existing PRs
bash scripts/cask-master.sh  # FRESH=1 (default) refreshes open PRs

# OR: Skip updating, only process apps without PRs
SKIP_OPEN_PR=1 bash scripts/cask-master.sh
```

### Workflow 4: Resume Interrupted Run
```bash
# Run was interrupted at "icons" app
# Resume from there:
START_AT=icons bash scripts/cask-master.sh

# Or: Skip apps that already passed, continue from failures
SKIP_PASSED=1 bash scripts/cask-master.sh
```

### Workflow 5: Focused Testing
```bash
# Test 3 specific apps without livecheck
ONLY="escrow-buddy pique icons" LIVECHECK=0 DRYRUN=1 bash scripts/cask-master.sh

# Then submit those 3:
ONLY="escrow-buddy pique icons" bash scripts/cask-master.sh
```

---

## 🔍 Monitoring & Debugging

### Check Overall Results
```bash
# Summary of all apps
cat /tmp/caskwork/MASTER-summary.md

# Tab-separated results (parse in spreadsheet)
cat /tmp/caskwork/results.tsv

# Failed apps with re-run command
grep "Failed" /tmp/caskwork/MASTER-summary.md
```

### Check Individual App
```bash
# Full report for one app
cat /tmp/caskwork/escrow-buddy/report.md

# Brew audit output
cat /tmp/caskwork/escrow-buddy/audit.log

# Install/uninstall logs
cat /tmp/caskwork/escrow-buddy/install.log
cat /tmp/caskwork/escrow-buddy/uninstall.log
```

### Auto-fixes Applied
```bash
# See what autofix did for each app
grep "AUTOFIX:" /tmp/caskwork/*/report.md

# See hardcoded versions that were fixed
grep "replaced hardcoded versions" /tmp/caskwork/*/report.md

# See deprecated depends_on that was fixed
grep "fixed deprecated depends_on" /tmp/caskwork/*/report.md
```

---

## 🛡️ Safety Features

### Duplicate PR Prevention
```bash
# Skip apps with open PRs
SKIP_OPEN_PR=1 bash scripts/cask-master.sh

# This prevents the "double submission" issue where:
# - Run 1: Creates PR for app A
# - Run 2 (accidental): Would create duplicate PR for app A
# - SKIP_OPEN_PR=1 prevents this by skipping app A
```

### Batch Limiting
```bash
# Default: BATCH_SIZE=10 (safe default)
bash scripts/cask-master.sh

# Smaller batches for testing
BATCH_SIZE=5 DRYRUN=1 bash scripts/cask-master.sh

# Unlimited (original behavior)
BATCH_SIZE=0 bash scripts/cask-master.sh
```

### Dry-run Safety
```bash
# ALWAYS start with dry-run to preview
DRYRUN=1 bash scripts/cask-master.sh

# DRYRUN=1 means:
# ✓ Resolves versions and downloads
# ✓ Inspects app artifacts
# ✓ Writes cask files
# ✓ Runs brew style + audit
# ✗ Does NOT install/uninstall/zap
# ✗ Does NOT push to git
# ✗ Does NOT create PRs/FRs
```

---

## 📊 Auto-fix Features

The script automatically fixes common issues:

### 1. Hardcoded Version Strings
**Before:** `pkg "Escrow.Buddy-1.0.0.pkg"`  
**After:** `pkg "Escrow.Buddy-#{version}.pkg"`

### 2. Deprecated `depends_on` Syntax
**Before:**
```ruby
on_arm do
  sha256 "..."
  url "..."
end
depends_on macos: :monterey  # ❌ Wrong position
```

**After:**
```ruby
on_arm do
  sha256 "..."
  url "..."
  depends_on macos: :monterey  # ✅ Correct position
end
```

### 3. Platform References in Descriptions
Removes unnecessary platform words ("macOS", "Mac", etc.) from descriptions.

### 4. Redundant `verified:` Stanzas
Removes verified: when not needed (same domain as homepage).

---

## 🎯 Best Practices

### 1. Always Start with DRYRUN
```bash
# STEP 1: Preview
DRYRUN=1 bash scripts/cask-master.sh

# STEP 2: Review
cat /tmp/caskwork/MASTER-summary.md

# STEP 3: Fix issues if needed

# STEP 4: Run for real
bash scripts/cask-master.sh
```

### 2. Use Small Batches When Testing
```bash
# Testing: 5-10 apps per batch
BATCH_SIZE=5 DRYRUN=1 bash scripts/cask-master.sh

# Production: larger batches after confidence
BATCH_SIZE=20 bash scripts/cask-master.sh
```

### 3. Preserve Work with Persistent CASKWORK
```bash
# Default: /tmp/caskwork (lost on macOS reboot)
bash scripts/cask-master.sh

# Better: preserve across reboots
CASKWORK=~/caskwork bash scripts/cask-master.sh

# Check later (even after reboot):
cat ~/caskwork/MASTER-summary.md
```

### 4. Skip Slow Steps When Iterating
```bash
# Faster iteration (skip livecheck + zap test)
DRYRUN=1 LIVECHECK=0 ZAP=0 ONLY="app-token" bash scripts/cask-master.sh

# Full verification (slower, but complete)
DRYRUN=1 bash scripts/cask-master.sh
```

---

## 🚨 Troubleshooting

### "Double PR created"
**Problem:** Same app has two open PRs  
**Solution:** Don't run without checking for open PRs. Use `SKIP_OPEN_PR=1` to prevent future issues.

### Run was interrupted
**Problem:** Script stopped halfway through  
**Solution:** Use `SKIP_PASSED=1` to skip completed apps and resume:
```bash
SKIP_PASSED=1 bash scripts/cask-master.sh
```

### Want to re-test existing PRs
**Problem:** Want to update an app that already has a PR  
**Solution:** Default behavior updates existing PRs. To keep them unchanged:
```bash
bash scripts/cask-master.sh  # Default: FRESH=1, updates open PRs
SKIP_OPEN_PR=1 bash scripts/cask-master.sh  # Skip existing, process failures only
```

### Disk running out
**Problem:** `/tmp/caskwork` filling up  
**Solution:** Don't use KEEP=1, and clean up old runs:
```bash
rm -rf /tmp/caskwork  # Safe to delete, reports are kept elsewhere

# Or use persistent dir and clean up:
CASKWORK=~/caskwork bash scripts/cask-master.sh
rm -rf ~/caskwork/*/dl ~/caskwork/*/x  # Keep reports, delete large files
```

---

## 📝 Registry Format

Apps are defined in the REGISTRY with this format:
```
token | name | description | artifact | source | homepage | spec
```

**Example:**
```
escrow-buddy | Escrow Buddy | Escrows FileVault recovery keys at the login window | pkg | github_tag | https://github.com/macadmins/escrow-buddy | repo=macadmins/escrow-buddy;asset=Escrow.Buddy-{v}.pkg
```

See CLAUDE.md for full documentation.

---

## 📞 Support

For detailed technical information:
- Read `CLAUDE.md` — full project documentation
- Read `IMPROVEMENTS.md` — technical details on improvements
- Check `scripts/cask-master.sh` — inline comments explain each section

For issues:
1. Check `/tmp/caskwork/<token>/report.md` for detailed logs
2. Review `/tmp/caskwork/MASTER-summary.md` for summary
3. Test with `DRYRUN=1 LIVECHECK=0 ONLY="<token>"` for quick iteration

---

**Last updated:** 2026-06-10  
**Latest improvements:** Batch processing, duplicate PR prevention, auto-fix enhancements
