# End-to-End Validation — Quick Start

## 5-Minute Overview

You now have a production-grade validation system with 4 integrated scripts:

### The Scripts

| Script | Purpose | Time |
|--------|---------|------|
| `end-to-end-validate.sh` | Full validation with filesystem snapshots & app launch | 5-10 min per app |
| `analyze-cask.sh` | Code quality analysis & best practices check | 30 sec per cask |
| `cask-fixer.sh` | Auto-fix common issues | 1 min per cask |
| `validate-all-prs.sh` | Orchestrate validation for all 20 apps | 60-90 min total |

## What Gets Checked

### End-to-End Validation (14 phases)
- ✓ Cask generation
- ✓ Metadata extraction
- ✓ Pre-app filesystem snapshot
- ✓ App installation
- ✓ App launch & user interaction
- ✓ Post-app filesystem snapshot
- ✓ Zap stanza verification
- ✓ Code style check
- ✓ Audit check
- ✓ Livecheck validation
- ✓ App metadata verification (bundle ID, min macOS)
- ✓ Uninstall test
- ✓ Reinstall test (idempotency)
- ✓ Zap cleanup verification

### Code Quality Analysis
- ✗ Hardcoded versions in URLs
- ✗ Deprecated syntax
- ✗ Missing livecheck
- ✗ Incomplete zap stanza
- ✗ Missing metadata (bundle ID, homepage, description)
- ✗ Code style issues

## Usage

### Validate One App
```bash
# Opens the app and monitors what it creates
bash end-to-end-validate.sh poll-everywhere
```

You'll be prompted to interact with the app for 1-2 minutes. The script captures:
- What files the app creates
- What should be in the zap stanza
- Whether the cask is production-ready

### Validate All 20 Apps
```bash
# Takes 60-90 minutes, generates summary
bash validate-all-prs.sh
```

Produces:
- Per-app e2e reports (`~/caskwork/validation-YYYYMMDD-HHMMSS/*-e2e.md`)
- Quality analysis (`*-analysis.txt`)
- Summary showing ready vs review vs failed

### Analyze a Cask (without app launch)
```bash
bash analyze-cask.sh ~/caskwork/poll-everywhere/poll-everywhere.rb
```

Shows all quality issues in the cask code (static analysis).

### Auto-Fix Common Issues
```bash
bash cask-fixer.sh ~/caskwork/poll-everywhere/poll-everywhere.rb
```

Automatically fixes:
- Hardcoded versions → `#{version}`
- Deprecated syntax
- Whitespace issues
- Minor style problems

## Typical Workflow

### First Time: Test One App
```bash
# Validate poll-everywhere with interactive app testing
bash end-to-end-validate.sh poll-everywhere

# Read the detailed report
cat ~/caskwork/e2e-reports/poll-everywhere-validation.md

# Analyze for quality issues
bash analyze-cask.sh ~/caskwork/poll-everywhere/poll-everywhere.rb

# Auto-fix issues
bash cask-fixer.sh ~/caskwork/poll-everywhere/poll-everywhere.rb

# Re-validate to verify fixes
bash end-to-end-validate.sh poll-everywhere
```

### Batch Validation: All 20 Apps
```bash
# Run complete validation for all 20
bash validate-all-prs.sh

# After 60-90 minutes, review results
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/SUMMARY.md

# For each app needing fixes:
bash analyze-cask.sh ~/caskwork/<app>/<app>.rb
bash cask-fixer.sh ~/caskwork/<app>/<app>.rb
bash end-to-end-validate.sh <app>

# Submit ready casks
bash scripts/cask-master.sh  # without DRYRUN
```

## Key Differences from Previous Approach

| Before | Now |
|--------|-----|
| Manual testing script | 14-phase end-to-end workflow |
| File path hardcoded wrong | Correct app-specific paths |
| No filesystem monitoring | Pre/post app snapshot comparison |
| Guess at zap stanza | Verify against actual created files |
| Manual regex testing | Automated livecheck validation |
| No quality metrics | Code quality analysis with fixes |

## What "Perfect" Looks Like

A cask passes validation when:

```
Summary
Checks passed: 14 / 14
Status: ✓ READY FOR SUBMISSION

This cask is ready to be submitted as a PR to Homebrew.
```

And analysis shows:
```
Issues:      0
Warnings:    0
Suggestions: 0

✓ Cask looks good!
```

## Understanding the Reports

### E2E Validation Report (`*-e2e.md`)
Shows all 14 phases with pass/fail status:
- Which checks passed
- Which failed and why
- Zap stanza coverage
- Audit results
- Livecheck working or not

### Analysis Report (`*-analysis.txt`)
Shows code quality issues:
- Hardcoded versions: where they are
- Deprecated syntax: what needs updating
- Missing fields: what to add
- Best practices: what could be improved

### Summary Report (`SUMMARY.md`)
After running all 20 apps:
- Ready: Apps that passed everything
- Review: Apps that need fixes
- Failed: Apps with critical issues
- Next steps for each category

## What Gets Generated Where

```
~/caskwork/
├── <app>/
│   ├── <app>.rb                    # Generated cask file
│   ├── report.md                   # Cask generation report
│   ├── fs_before.txt               # Pre-app snapshot
│   ├── fs_after.txt                # Post-app snapshot
│   ├── fs_changes.txt              # What app created
│   └── *.log                        # Install/uninstall logs
├── e2e-reports/
│   └── <app>-validation.md         # E2E validation report
└── validation-YYYYMMDD-HHMMSS/     # Batch validation results
    ├── <app>-e2e.md                # E2E report (copy)
    ├── <app>-analysis.txt          # Quality analysis
    ├── <app>.log                   # Validation logs
    └── SUMMARY.md                  # Batch summary
```

## Most Important Concept: Zap Stanzas

The biggest improvement over manual testing:

1. **Before**: Guess what files app creates, hope zap stanza works
2. **Now**: 
   - Capture filesystem BEFORE app opens
   - Open app, let user interact
   - Capture filesystem AFTER app closes
   - Calculate EXACT diff = what app created
   - Verify zap stanza covers all created files
   - Prove zap cleanup works by testing it

This means no more incomplete zap stanzas or leftover app data.

## Example: Poll Everywhere Validation

The cask generated perfectly because:

✓ Version resolved correctly (4.0.1)  
✓ Download succeeded and SHA256 matched  
✓ App installed to `/Applications/Poll Everywhere.app`  
✓ Bundle ID: `com.polleverywhere.PollEv-Presenter` correct  
✓ Min macOS: `:sonoma` correct  
✓ Zap stanza covers all created files:
- `~/Library/Caches/com.polleverywhere.PollEv-Presenter`
- `~/Library/HTTPStorages/com.polleverywhere.PollEv-Presenter`
- `~/Library/Preferences/com.polleverywhere.PollEv-Presenter.plist`
- `~/Library/Saved Application State/com.polleverywhere.PollEv-Presenter.savedState`

✓ Livecheck regex works and detects updates  
✓ Reinstall is idempotent  
✓ Zap cleanup removes all traces  

**Result: Ready for Homebrew PR**

## Still Have Questions?

See the detailed guide:
```bash
cat E2E-VALIDATION.md
```

Or run a single app to see the workflow in action:
```bash
bash end-to-end-validate.sh poll-everywhere
```
