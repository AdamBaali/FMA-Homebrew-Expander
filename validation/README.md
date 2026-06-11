# Validation Scripts — End-to-End Cask Testing

This directory contains the complete validation system for Homebrew casks.

## Quick Start

```bash
# Validate all 20 open PRs
bash validate-all-prs.sh

# Validate one app
bash end-to-end-validate.sh poll-everywhere

# Analyze code quality
bash analyze-cask.sh ~/caskwork/<app>/<app>.rb

# Auto-fix issues
bash cask-fixer.sh ~/caskwork/<app>/<app>.rb

# Check for duplicates
bash check-duplicates.sh ~/caskwork/<app>/<app>.rb
```

## Scripts

| Script | Purpose | Time | Input |
|--------|---------|------|-------|
| `validate-all-prs.sh` | Orchestrate all 20 apps | 60-90 min | None (uses predefined list) |
| `end-to-end-validate.sh` | Single/multiple app validation | 5-10 min each | App token(s) |
| `analyze-cask.sh` | Code quality check | 30 sec | Cask file path |
| `cask-fixer.sh` | Auto-fix common issues | 1 min | Cask file path |
| `check-duplicates.sh` | Find duplicate casks | 30 sec | Cask file path |
| `check-system-state.sh` | System snapshots | 10 sec | capture/compare + args |

## Validation Phases (17 Total)

1. **Cask Generation** — Generate from source
2. **Duplicate Detection** — Check vs 14k+ Homebrew casks
3. **Metadata Extraction** — Parse app info
4. **Pre-install System Snapshot** — Capture system state
5. **Pre-app Filesystem Snapshot** — Capture file system
6. **App Installation** — Install via Homebrew
7. **App Launch & Monitoring** — User tests app
8. **Post-install System Snapshot** — Verify no system pollution
9. **Post-app Filesystem Snapshot** — See what app created
10. **Zap Stanza Verification** — Verify cleanup paths
11. **Code Style Check** — Run brew style
12. **Audit Cask** — Run brew audit --strict
13. **Livecheck Validation** — Test version detection
14. **App Metadata Verification** — Check bundle ID, min macOS
15. **Uninstall Test** — Test uninstall
16. **Reinstall Test** — Test idempotency
17. **Zap Cleanup Verification** — Verify zap removal

## Quality Analysis (8 Additional Checks)

1. Hardcoded versions in URLs
2. Deprecated syntax
3. Verified sources
4. Livecheck quality
5. Complete zap stanza
6. App metadata correctness
7. SHA256 & version format
8. Code style issues

## Output

### Single App Validation

Results: `~/caskwork/e2e-reports/<app>-validation.md`

Contains all 17 phases with pass/fail status.

### Batch Validation

Results: `~/caskwork/validation-YYYYMMDD-HHMMSS/`

- `SUMMARY.md` — High-level results
- `<app>-e2e.md` — Per-app detailed report
- `<app>-analysis.txt` — Code quality issues
- `<app>.log` — Raw validation logs

## Exit Status

- ✓ All checks pass → Cask is production-ready
- ⚠ Some warnings → Review before submission
- ✗ Failed checks → Fix before submission

## Common Issues

### Duplicate Found
```bash
bash check-duplicates.sh ~/caskwork/<app>/<app>.rb
# May need to rename with -desktop, -web suffix
```

### Zap Stanza Incomplete
```bash
cat ~/caskwork/<app>/fs_changes.txt
# Add missing paths to cask
```

### Livecheck Not Working
```bash
brew livecheck --cask <app> --verbose
# Fix regex or try different strategy
```

### Audit Failures
```bash
brew audit --cask --strict --online --new ~/caskwork/<app>/<app>.rb
# Fix issues reported
```

## Success Criteria

```
Checks passed: 17 / 17
Issues:      0
Warnings:    0
Suggestions: 0
Status: ✓ READY FOR SUBMISSION
```

When all checks pass, the cask is guaranteed to pass Homebrew CI.

## For More Information

- `../docs/QUICKSTART.txt` — Quick reference
- `../docs/VALIDATION-GUIDE.md` — Complete usage guide
- `../docs/E2E-CHECKS.md` — Detailed explanation of phases
- `../README-WORKFLOW.md` — Complete workflow
