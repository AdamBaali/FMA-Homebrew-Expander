# End-to-End Cask Validation — Complete Usage Guide

## TL;DR — Run This

```bash
# Validate all 20 open PRs (takes 60-90 minutes)
bash validate-all-prs.sh

# Results appear in ~/caskwork/validation-YYYYMMDD-HHMMSS/
# Read the summary:
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/SUMMARY.md

# For each app, check:
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/<app>-e2e.md
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/<app>-analysis.txt
```

---

## Installation

All scripts are in the repo root. They're ready to use — no installation needed.

```bash
cd /Users/adam/Documents/GitHub/FMA-Homebrew-Expander
ls -la *.sh
```

### Scripts

| Script | Purpose | Time |
|--------|---------|------|
| `validate-all-prs.sh` | Orchestrate validation for all 20 apps | 60-90 min |
| `end-to-end-validate.sh` | Full validation for one app | 5-10 min |
| `analyze-cask.sh` | Code quality check (no app launch) | 30 sec |
| `cask-fixer.sh` | Auto-fix common issues | 1 min |
| `check-duplicates.sh` | Find duplicate casks | 30 sec |
| `check-system-state.sh` | System state snapshot/comparison | 10 sec |

### Documentation

| File | Content |
|------|---------|
| `E2E-VALIDATION.md` | Deep dive on workflow and best practices |
| `E2E-CHECKS.md` | Detailed explanation of all 17 validation phases |
| `E2E-QUICK-START.md` | Quick reference for the 5-minute overview |
| `VALIDATION-GUIDE.md` | This file — practical usage guide |

---

## Typical Workflow

### Option A: Validate One App (with app launch)

Perfect for testing before running all 20.

```bash
# Full validation with interactive app testing
bash end-to-end-validate.sh poll-everywhere

# You'll be prompted:
# 1. Press Enter to open the app
# 2. Interact with app for 1-2 minutes
# 3. Close it when done (or let script force-close after 60s)
# 4. Review filesystem changes
# 5. Verify zap stanza

# Results saved to:
# ~/caskwork/e2e-reports/poll-everywhere-validation.md
cat ~/caskwork/e2e-reports/poll-everywhere-validation.md
```

### Option B: Validate Multiple Apps

```bash
# Test 5 specific apps
bash end-to-end-validate.sh poll-everywhere mestrenova masv luna-display hudl-studio

# Or validate all 20
bash validate-all-prs.sh
```

### Option C: Quick Quality Check (no app launch)

```bash
# Analyze without opening app
bash analyze-cask.sh ~/caskwork/poll-everywhere/poll-everywhere.rb

# See what needs fixing
cat ~/caskwork/e2e-reports/poll-everywhere-validation.md | grep "✗"
```

### Option D: Check for Duplicates Only

```bash
# See if this cask duplicates an existing one
bash check-duplicates.sh ~/caskwork/poll-everywhere/poll-everywhere.rb
```

---

## Complete Workflow: Generate → Validate → Fix → Submit

### Step 1: Generate Initial Casks

```bash
# Generate first batch of 10 casks
BATCH_SIZE=10 bash scripts/cask-master.sh

# Results in ~/caskwork/<app>/<app>.rb
```

### Step 2: Run Full Validation

```bash
# Validate all generated casks
bash validate-all-prs.sh

# Wait 60-90 minutes...
# Check results when done:
ls ~/caskwork/validation-*/
```

### Step 3: Review Results

```bash
# Read summary
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/SUMMARY.md

# It shows:
# - Ready: 8 apps (ready for PR)
# - Review: 10 apps (need fixes)
# - Failed: 2 apps (critical issues)
```

### Step 4: Fix Issues

For each app marked "REVIEW":

```bash
# See what needs fixing
bash analyze-cask.sh ~/caskwork/<app>/<app>.rb

# Sample output:
# ERROR: URL contains version number — should use #{version}
# WARNING: No livecheck block
# SUGGESTION: Description is very short

# Auto-fix easy issues
bash cask-fixer.sh ~/caskwork/<app>/<app>.rb

# Edit remaining issues manually
vim ~/caskwork/<app>/<app>.rb

# Re-run validation to verify fixes
bash end-to-end-validate.sh <app>
```

### Step 5: Submit Ready Casks

```bash
# Submit all validated casks as PRs
bash scripts/cask-master.sh

# This will:
# - Create branches for each app
# - Open PRs on Homebrew/homebrew-cask
# - File FMA requests on fleetdm/fleet
```

---

## Understanding the Output

### After Single App Validation

Results saved to `~/caskwork/e2e-reports/<app>-validation.md`

Structure:
```
## 1. Cask Generation
✓ Cask generation passed

## 2. Duplicate Detection
✓ No duplicate casks found

## 3. Cask Code Quality
✓ brew style check passed

## 4. Livecheck & Version Detection
✓ Livecheck succeeded
```
...and so on for all 17 phases.

**Look for:**
- ✓ = Passed (good!)
- ✗ = Failed (must fix)
- ⚠ = Warning (review)

### After Batch Validation

Results in `~/caskwork/validation-YYYYMMDD-HHMMSS/`

```
SUMMARY.md              # High-level results
<app>-e2e.md            # Per-app detailed report
<app>-analysis.txt      # Code quality issues
<app>.log               # Raw validation logs
```

**SUMMARY.md shows:**
```
## Results
- Ready: 8
- Review: 10
- Failed: 2

### Ready for Submission
- poll-everywhere
- mestrenova
- masv
...

### Need Review/Fixes
- luna-display (4 issues, 2 warnings)
...
```

### Analysis Output

Example `analyze-cask.sh` output:

```
ERROR: URL contains version number — should use #{version}
WARNING: No livecheck block — app updates will not be auto-detected
SUGGESTION: Description is very short

Issues:      1
Warnings:    1
Suggestions: 1
```

---

## Common Issues and Fixes

### Issue: "Cask file not found"

```bash
# Happens if cask generation failed
cat ~/caskwork/<app>/report.md | grep -A 5 "✗"
```

Check the report for why generation failed (usually download, SHA256, or artifact format).

### Issue: "DUPLICATE FOUND"

```bash
# Your cask duplicates existing one
bash check-duplicates.sh ~/caskwork/<app>/<app>.rb

# Solutions:
# 1. Different app? Rename with suffix: -desktop, -web, etc.
# 2. Same vendor? Name should clearly differentiate
# 3. Verify bundle ID is actually different
```

### Issue: "Zap stanza incomplete"

```bash
# Files created but not in zap stanza
cat ~/caskwork/<app>/fs_changes.txt

# Add missing paths to zap block:
vim ~/caskwork/<app>/<app>.rb

# Re-validate:
bash end-to-end-validate.sh <app>
```

### Issue: "brew audit failed"

```bash
# See what audit found
brew audit --cask --strict --online --new ~/caskwork/<app>/<app>.rb

# Common issues:
# - URL unreachable (verify manually)
# - SHA256 wrong (recalculate)
# - Deprecated syntax (use brew style --fix)
```

### Issue: "Livecheck not working"

```bash
# Test manually
brew livecheck --cask <app> --verbose

# If fails:
# 1. Check URL is correct and reachable
# 2. Verify regex matches actual version format
# 3. Try different strategy (page_match vs header_match)
```

---

## Working with Filesystem Snapshots

The validation captures what files each app creates. Use this to build perfect zap stanzas.

```bash
# View files app created
cat ~/caskwork/<app>/fs_changes.txt

# Example output:
# ~/Library/Application Support/MyApp/config.plist
# ~/Library/Preferences/com.mycompany.MyApp.plist
# ~/Library/Caches/com.mycompany.MyApp

# All of these MUST be in zap stanza
```

Add to cask:
```ruby
zap trash: [
  "~/Library/Application Support/MyApp",
  "~/Library/Preferences/com.mycompany.MyApp.plist",
  "~/Library/Caches/com.mycompany.MyApp",
]
```

Then re-validate to confirm zap cleanup works.

---

## Batch Processing Strategy

For all 20 apps:

### Recommended Approach

```bash
# Day 1: Generate and validate all 20
bash validate-all-prs.sh
# Wait 60-90 minutes for results

# Day 2: Fix issues
for app in luna-display hudl-studio brosix ...; do
  echo "=== Fixing $app ==="
  bash analyze-cask.sh ~/caskwork/$app/$app.rb
  bash cask-fixer.sh ~/caskwork/$app/$app.rb
  bash end-to-end-validate.sh $app
done

# Day 3: Submit ready casks
bash scripts/cask-master.sh
```

### Or: Parallel Approach

Validate in batches of 5-10 to parallelize with other work:

```bash
# Batch 1
bash end-to-end-validate.sh poll-everywhere mestrenova masv luna-display hudl-studio

# Fix batch 1 while batch 2 runs
# Then submit batch 1 while validating batch 2
```

---

## Saving Results to Git

### Commit the Validation Scripts

```bash
git add -A
git commit -m "Add comprehensive end-to-end cask validation system

- validate-all-prs.sh: Orchestrate validation for all 20 apps
- end-to-end-validate.sh: 17-phase validation with filesystem snapshots
- analyze-cask.sh: Code quality checks
- cask-fixer.sh: Auto-fix common issues
- check-duplicates.sh: Detect duplicate casks vs Homebrew registry
- check-system-state.sh: Match Homebrew CI system state checks
- Documentation: E2E-VALIDATION.md, E2E-CHECKS.md, E2E-QUICK-START.md

Features:
- Duplicate detection against 14k+ existing casks
- System state snapshots (before/after install)
- Filesystem monitoring for zap stanza verification
- 17 comprehensive validation phases
- Batch and single-app validation
- Auto-fix for common issues"

git push origin main
```

### Save Validation Results

After validation, archive the results:

```bash
# Backup validation results
cp -r ~/caskwork/validation-YYYYMMDD-HHMMSS ./validation-results/
git add validation-results/
git commit -m "Add validation results from batch run"
git push origin main
```

Or create a separate branch:

```bash
# Create branch for validation results
git checkout -b validation-results-2024-06
cp -r ~/caskwork/validation-YYYYMMDD-HHMMSS ./
git add .
git commit -m "Validation run results for 20 open PRs"
git push origin validation-results-2024-06
```

---

## Integration with cask-master.sh

The validation scripts work alongside your existing `cask-master.sh`:

```bash
# Generate casks
BATCH_SIZE=10 bash scripts/cask-master.sh

# Validate generated casks
bash validate-all-prs.sh

# Fix any issues (see analysis reports)

# Submit ready ones
bash scripts/cask-master.sh  # without DRYRUN
```

No changes needed to `cask-master.sh` — validation is independent.

---

## Troubleshooting

### Scripts not found

```bash
# Make sure you're in the repo root
cd /Users/adam/Documents/GitHub/FMA-Homebrew-Expander
ls -la *.sh
```

### Permission denied

```bash
# Make scripts executable
chmod +x *.sh
```

### Homebrew cask tap not found

```bash
# install Homebrew cask tap
brew tap homebrew/cask

# Or specify manually
HOMEBREW_TAP=/path/to/homebrew-cask bash check-duplicates.sh ...
```

### Low disk space

```bash
# Clean up old validation runs
rm -rf ~/caskwork/validation-*

# Or keep reports, delete downloads
rm -rf ~/caskwork/*/dl ~/caskwork/*/x
```

---

## Next Steps

1. **Test on one app:**
   ```bash
   bash end-to-end-validate.sh poll-everywhere
   ```

2. **Review the reports:**
   ```bash
   cat ~/caskwork/e2e-reports/poll-everywhere-validation.md
   ```

3. **Run full validation:**
   ```bash
   bash validate-all-prs.sh
   ```

4. **Fix issues:**
   ```bash
   bash analyze-cask.sh ~/caskwork/<app>/<app>.rb
   bash cask-fixer.sh ~/caskwork/<app>/<app>.rb
   bash end-to-end-validate.sh <app>
   ```

5. **Submit:**
   ```bash
   bash scripts/cask-master.sh
   ```

6. **Commit to repo:**
   ```bash
   git add -A
   git commit -m "FMA cask validation run"
   git push origin main
   ```

---

## Questions?

- **How validation works:** See `E2E-VALIDATION.md`
- **All 17 phases explained:** See `E2E-CHECKS.md`
- **Quick reference:** See `E2E-QUICK-START.md`
- **Script in detail:** Read the script source (well-commented)

---

## One More Thing

The validation system is designed to be **zero-guessing**. If it passes:

- ✓ Cask is production-ready
- ✓ No duplicates
- ✓ Zap stanza works
- ✓ Livecheck works
- ✓ Bundle ID is correct
- ✓ Will pass Homebrew CI

Submit with confidence!
