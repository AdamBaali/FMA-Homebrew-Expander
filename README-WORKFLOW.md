# FMA Homebrew Cask Generator — Complete Workflow

## Overview

This project automates bulk Homebrew Cask generation for 500+ macOS apps with **zero guessing**, comprehensive validation, and production-grade output.

**New structure:**
- 📚 `research/` — App metadata and research registry
- 🔍 `validation/` — End-to-end cask validation (17 phases)
- 🛠️ `scripts/` — Cask generation and utilities
- 📖 `docs/` — Complete documentation

---

## Quick Start (5 Minutes)

### 1. Clone and Setup

```bash
cd /Users/adam/Documents/GitHub/FMA-Homebrew-Expander

# Check what's installed
brew --version
gh --version
```

### 2. Run Everything Locally

```bash
# Validate all 20 open PRs (generates + tests + analyzes)
bash validation/validate-all-prs.sh

# Results appear in ~/caskwork/validation-YYYYMMDD-HHMMSS/
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/SUMMARY.md
```

### 3. Fix and Submit

```bash
# Fix any issues
bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb
bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb

# Re-validate
bash validation/end-to-end-validate.sh <app>

# Submit ready casks
bash scripts/cask-master.sh
```

---

## Directory Structure

```
FMA-Homebrew-Expander/
│
├── research/                          # App research registry
│   ├── README.md                      # Research guide
│   └── apps/
│       ├── apps-registry.json         # All 500+ apps (you build this)
│       ├── app-template.json          # Template for new apps
│       └── examples.json              # Example entries
│
├── validation/                        # End-to-end cask validation
│   ├── validate-all-prs.sh            # Batch validation (17 phases each)
│   ├── end-to-end-validate.sh         # Single app validation
│   ├── analyze-cask.sh                # Code quality analysis
│   ├── cask-fixer.sh                  # Auto-fix common issues
│   ├── check-duplicates.sh            # Detect duplicates
│   ├── check-system-state.sh          # System state snapshots
│   └── README.md                      # Validation guide
│
├── scripts/                           # Cask generation
│   ├── cask-master.sh                 # Main generation harness
│   └── lib/
│       └── research-utils.sh          # Query research registry
│
├── docs/                              # Documentation
│   ├── QUICKSTART.txt                 # Quick reference card
│   ├── VALIDATION-GUIDE.md            # Usage guide
│   ├── E2E-VALIDATION.md              # Deep dive
│   ├── E2E-CHECKS.md                  # 17 phases explained
│   └── E2E-QUICK-START.md             # 5-min overview
│
├── data/                              # Generated outputs
│   ├── master-list.csv                # Status tracking
│   └── homebrew-apps/                 # Generated casks
│
└── (existing)
    ├── README.md                      # Original readme
    ├── DOCUMENTATION.md               # Original docs
    ├── CLAUDE.md                      # Project instructions
    ├── .claude/skills/                # Claude Code skills
    └── scripts/cask-master.sh          # Generation script
```

---

## Usage Patterns

### Pattern 1: Test Everything Locally

Perfect for validation before submission.

```bash
# Full validation of all 20 apps
bash validation/validate-all-prs.sh

# Wait 60-90 minutes...
# Review results
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/SUMMARY.md

# For each app:
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/<app>-e2e.md
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/<app>-analysis.txt
```

### Pattern 2: Test One App

Perfect for debugging or initial testing.

```bash
# Full validation with interactive app launch
bash validation/end-to-end-validate.sh poll-everywhere

# You'll be prompted to:
# 1. Review the generated cask
# 2. Install the app
# 3. Open it and interact (1-2 minutes)
# 4. Let script verify cleanup

# Results
cat ~/caskwork/e2e-reports/poll-everywhere-validation.md
```

### Pattern 3: Quick Quality Check

Perfect when you've fixed code and want to verify.

```bash
# Analyze cask without app launch
bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb

# Shows: errors, warnings, suggestions
```

### Pattern 4: Fix Issues

```bash
# See what needs fixing
bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb

# Auto-fix easy issues
bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb

# Manual edit for complex issues
vim ~/caskwork/<app>/<app>.rb

# Re-validate
bash validation/end-to-end-validate.sh <app>
```

### Pattern 5: Check for Duplicates

```bash
# Before generating a new cask
bash validation/check-duplicates.sh ~/caskwork/<app>/<app>.rb

# Or check as part of validation (automatic)
bash validation/validate-all-prs.sh
```

---

## Working with App Research Registry

The `research/apps/apps-registry.json` is the source of truth for all app metadata.

### Query the Registry

```bash
# Show statistics
bash scripts/lib/research-utils.sh stats

# List ready apps
bash scripts/lib/research-utils.sh list-ready

# List all apps
bash scripts/lib/research-utils.sh list-all

# Show info for one app
bash scripts/lib/research-utils.sh info poll-everywhere

# Validate app data
bash scripts/lib/research-utils.sh validate poll-everywhere
```

### Add a New App

```bash
# Copy template
cp research/apps/app-template.json research/apps/my-app.json

# Fill in all fields (use research/apps/examples.json as reference)
vim research/apps/my-app.json

# Add to registry
# (Manually append to research/apps/apps-registry.json or use jq)

# Generate cask from registry
ONLY="my-app" bash scripts/cask-master.sh
```

### Export Research Data

```bash
# Export one app's data
bash scripts/lib/research-utils.sh export poll-everywhere > /tmp/poll-everywhere.json

# Export all ready apps
bash scripts/lib/research-utils.sh export-ready > /tmp/ready-apps.json
```

---

## Complete End-to-End Example

### Day 1: Generate & Validate All 20

```bash
# Generate casks for all 20 apps
BATCH_SIZE=10 bash scripts/cask-master.sh

# Validate them
bash validation/validate-all-prs.sh

# Save results
cp -r ~/caskwork/validation-* ./validation-results/
git add validation-results/
git commit -m "Initial validation run for 20 open PRs"
```

### Day 2: Fix Issues

```bash
# Check summary
cat ./validation-results/SUMMARY.md

# Shows:
# Ready: 8 apps ✓
# Review: 10 apps (need fixes)
# Failed: 2 apps (critical)

# Fix the "Review" apps
for app in luna-display hudl-studio brosix ...; do
  echo "=== Fixing $app ==="
  bash validation/analyze-cask.sh ~/caskwork/$app/$app.rb
  bash validation/cask-fixer.sh ~/caskwork/$app/$app.rb
  vim ~/caskwork/$app/$app.rb  # Fix remaining issues manually
  bash validation/end-to-end-validate.sh $app
done

# For "Failed" apps, investigate report
cat ~/caskwork/$app/report.md
```

### Day 3: Submit Ready Casks

```bash
# Validate again to make sure everything passes
bash validation/validate-all-prs.sh

# Review final summary
cat ~/caskwork/validation-*/SUMMARY.md

# Submit
bash scripts/cask-master.sh  # without DRYRUN

# This will:
# - Create PR branches
# - Open PRs on Homebrew/homebrew-cask
# - File FMA requests on fleetdm/fleet
```

### Day 4: Commit & Push

```bash
# Commit results
git add -A
git commit -m "Validation and submission of 18 casks

- 8 direct ready submissions
- 10 casks fixed and re-validated
- Duplicates prevented
- System state verified
- All zap stanzas tested"

git push origin main

# Create branch for results if tracking separately
git checkout -b validation-2024-06
cp -r ~/caskwork/validation-* .
git add .
git commit -m "Final validation results"
git push origin validation-2024-06
```

---

## Running Locally: Complete Commands

### Essential Commands

```bash
# Work directory
cd /Users/adam/Documents/GitHub/FMA-Homebrew-Expander

# Validate all 20 apps (the main command)
bash validation/validate-all-prs.sh

# Validate single app with app launch
bash validation/end-to-end-validate.sh poll-everywhere

# Analyze for quality issues
bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb

# Auto-fix common issues
bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb

# Check for duplicates
bash validation/check-duplicates.sh ~/caskwork/<app>/<app>.rb

# Query research registry
bash scripts/lib/research-utils.sh stats
bash scripts/lib/research-utils.sh info poll-everywhere
```

### Research Registry

```bash
# View template
cat research/apps/app-template.json

# View example
cat research/apps/examples.json

# See structure
cat research/README.md
```

### Documentation

```bash
# Quick reference (start here)
cat docs/QUICKSTART.txt

# Practical usage guide
cat docs/VALIDATION-GUIDE.md

# Technical deep dive
cat docs/E2E-VALIDATION.md

# All 17 phases explained
cat docs/E2E-CHECKS.md
```

---

## Key Features

✅ **Zero Guessing**
- Captures exact files app creates
- Verifies zap stanza works
- Tests installation/uninstallation

✅ **Duplicate Prevention**
- Checks against 14k+ Homebrew casks
- Detects vendor variations
- Handles desktop/web suffixes

✅ **System State Monitoring**
- Pre/post install snapshots
- Detects system artifacts
- Matches Homebrew CI methodology

✅ **17 Validation Phases**
- Cask generation
- Metadata verification
- Filesystem monitoring
- Installation testing
- Code quality analysis

✅ **Research Registry**
- Centralized app metadata
- Batch query tools
- Export capabilities
- Status tracking

✅ **Local Testing**
- Run everything before submission
- No cloud dependencies
- Full reproducibility

---

## Troubleshooting

### "bash: validation/validate-all-prs.sh: No such file"

```bash
# Make sure you're in the right directory
cd /Users/adam/Documents/GitHub/FMA-Homebrew-Expander
ls -la validation/
```

### "Permission denied"

```bash
# Make scripts executable
chmod +x validation/*.sh
chmod +x scripts/lib/*.sh
```

### "jq not found"

```bash
# Install jq for JSON querying
brew install jq
```

### "Homebrew tap not found"

```bash
# Install Homebrew cask tap
brew tap homebrew/cask
```

### Low disk space

```bash
# Clean up old runs
rm -rf ~/caskwork/validation-*
rm -rf ~/caskwork/*/dl ~/caskwork/*/x
```

---

## What Gets Validated

The system checks **17 phases**:

1. ✓ Cask generation
2. ✓ Duplicate detection
3. ✓ Metadata extraction
4. ✓ Pre-install system snapshot
5. ✓ Pre-app filesystem snapshot
6. ✓ App installation
7. ✓ App launch & monitoring
8. ✓ Post-install system snapshot
9. ✓ Post-app filesystem snapshot
10. ✓ Zap stanza verification
11. ✓ Code style check
12. ✓ Audit check (Homebrew policy)
13. ✓ Livecheck validation
14. ✓ App metadata verification
15. ✓ Uninstall test
16. ✓ Reinstall test
17. ✓ Zap cleanup verification

**Plus:** 8 quality analysis checks

---

## Success Criteria

A cask is **production-ready** when:

```
Checks passed: 17 / 17
Issues:      0
Warnings:    0
Suggestions: 0
Status: ✓ READY FOR SUBMISSION
```

---

## Next Steps

1. **Read QUICKSTART.txt**: 2 minutes
2. **Run validation**: 60-90 minutes for all 20 apps
3. **Review results**: 10 minutes
4. **Fix issues**: Variable (usually 30 min-2 hours)
5. **Submit**: 15 minutes to create PRs

---

## See Also

- `docs/QUICKSTART.txt` — Quick reference
- `docs/VALIDATION-GUIDE.md` — Detailed usage
- `research/README.md` — Research registry guide
- `scripts/lib/research-utils.sh` — Registry query tool
- `CLAUDE.md` — Project instructions for AI
