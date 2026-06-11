# CLAUDE.md — Operating Guide

## Project Summary

A production-grade **Homebrew Cask generator + validator** for 533 apps from Fleet's "no-homebrew-cask" backlog.

**Architecture:**
- **`scripts/cask-master.sh`** — Batch cask generation (PR + FMA filing)
- **`validation/`** — End-to-end validation (17 phases, full local testing)
- **`research/`** — App research registry for metadata
- **`data/master-list.csv`** — Per-app status (source of truth)

## Hard Guardrails

- **NEVER run `scripts/cask-master.sh` without `DRYRUN=1`** unless explicitly approved
  (opens real PRs, files real FMA requests, performs real installations)
- **Always validate locally first:**
  ```bash
  bash validation/validate-all-prs.sh      # Full batch validation
  bash validation/end-to-end-validate.sh <app>  # Single app
  ```
- Don't edit casks in tap directly; fix the REGISTRY and re-run generation
- Don't modify flags like `SUDO_NOPASSWD`, `FILE_FR`, `FRESH` yourself — user's call

## Quick Start — Local Validation (NEW)

```bash
# Validate everything locally (NO PRs, NO installations)
bash validation/validate-all-prs.sh
# 60-90 minutes, generates detailed reports

# Results in ~/caskwork/validation-YYYYMMDD-HHMMSS/
cat ~/caskwork/validation-*/SUMMARY.md
```

If all checks pass, then submit:

```bash
# Submit first 10 apps
bash scripts/cask-master.sh

# Submit next batch
BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh
```

## Key Features

### Validation System (17 Phases)
1. Cask generation
2. Duplicate detection (vs 14k+ Homebrew casks)
3-9. System snapshots, installation, app launch, filesystem monitoring
10. Zap stanza verification (cleanup is complete)
11-17. Style, audit, livecheck, metadata, reinstall, zap verification

**Result:** Production-ready casks guaranteed to pass Homebrew CI

### Generation Features
- **Batch processing** (`BATCH_SIZE=10`) — Safe, prevents flooding
- **Duplicate prevention** (`SKIP_OPEN_PR=1`) — Avoids duplicate PRs
- **Auto-fixes** — Hardcoded versions, deprecated syntax, incomplete zap
- **Resumable** (`SKIP_PASSED=1`) — Resume from failures
- **Research registry** — Centralized metadata for all apps

## Important Flags (for cask-master.sh)

| Flag | Default | Purpose |
|------|---------|---------|
| `DRYRUN=1` | 0 | Audit only (no install/push/PR) |
| `TEST_INSTALL=1` | 0 | Full test (no push/PR) |
| `BATCH_SIZE=N` | 10 | Apps per run (0 = unlimited) |
| `SKIP_PASSED=1` | 0 | Skip already-passed apps |
| `ONLY="a b c"` | — | Run only these apps |

**Full reference:** See [DOCUMENTATION.md](DOCUMENTATION.md)

## Validation Workflow

### Step 1: Validate Locally (Required)
```bash
bash validation/validate-all-prs.sh
cat ~/caskwork/validation-*/SUMMARY.md
```

Shows: Ready (✓) / Need Review (⚠) / Failed (✗)

### Step 2: Fix Issues (if needed)
```bash
bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb
bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb
bash validation/end-to-end-validate.sh <app>
```

### Step 3: Submit
```bash
bash scripts/cask-master.sh
```

## Results

After `scripts/cask-master.sh`:
- `$CASKWORK/MASTER-summary.md` — Human summary; read first
- `$CASKWORK/results.tsv` — Machine-readable results
- `$CASKWORK/<token>/report.md` — Per-app details
- PRs open automatically (if not DRYRUN)

After validation:
- `~/caskwork/validation-YYYYMMDD-HHMMSS/SUMMARY.md` — Batch results
- `~/caskwork/e2e-reports/<app>-validation.md` — Single app report

## Disk Hygiene

Downloads automatically clean up. If disk fills:
```bash
rm -rf ~/caskwork/validation-*               # Delete old validation runs
rm -rf ~/caskwork/*/dl ~/caskwork/*/x        # Keep reports, delete downloads
brew cleanup -s --prune=all                  # Clean brew cache
```

Or use persistent directory:
```bash
CASKWORK=~/caskwork bash validation/validate-all-prs.sh
CASKWORK=~/caskwork bash scripts/cask-master.sh
```

## Repository Structure

```
FMA-Homebrew-Expander/
├── START-HERE.md                 ← Read this first
├── README.md                     ← Updated overview
├── README-WORKFLOW.md            ← Complete workflow
│
├── validation/                   ← NEW: Local validation
│   ├── validate-all-prs.sh       ← Main validation
│   ├── end-to-end-validate.sh
│   ├── analyze-cask.sh
│   ├── cask-fixer.sh
│   └── check-*.sh
│
├── research/                     ← NEW: App registry
│   └── apps/
│       ├── app-template.json
│       └── examples.json
│
├── scripts/
│   ├── cask-master.sh           ← Generation
│   └── lib/research-utils.sh    ← Query registry
│
└── docs/                         ← Documentation
    ├── QUICKSTART.txt
    ├── VALIDATION-GUIDE.md
    └── ...
```

## Documentation

**Getting started:**
- [START-HERE.md](START-HERE.md) — 5-minute quick start
- [README.md](README.md) — Project overview
- [README-WORKFLOW.md](README-WORKFLOW.md) — Complete workflow

**Validation system:**
- [docs/QUICKSTART.txt](docs/QUICKSTART.txt) — Quick reference
- [docs/VALIDATION-GUIDE.md](docs/VALIDATION-GUIDE.md) — Complete guide
- [docs/E2E-CHECKS.md](docs/E2E-CHECKS.md) — All 17 phases explained
- [validation/README.md](validation/README.md) — Validation details

**Research & generation:**
- [research/README.md](research/README.md) — App registry guide
- [DOCUMENTATION.md](DOCUMENTATION.md) — Full cask-master.sh reference
- [NOT-ADDED.md](NOT-ADDED.md) — Apps not shipped, grouped by reason

**Implementation:**
- [.claude/skills/homebrew-cask-author/](.claude/skills/homebrew-cask-author/) — Cask DSL reference
