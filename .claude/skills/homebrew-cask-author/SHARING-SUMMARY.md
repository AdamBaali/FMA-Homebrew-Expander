# Homebrew Cask Author Skill — Sharing Summary

**Latest version:** June 10, 2026  
**Status:** Production-ready with batch mode support

## What this skill does

Automates the full process of authoring and submitting new Homebrew Casks:
- Research app metadata (version, download URL, bundle ID, minimum macOS)
- Generate audit-clean cask DSL
- Validate with real `brew install` + `uninstall` + `zap`
- Open PR to `Homebrew/homebrew-cask`
- File companion Fleet-maintained-app feature request

## Two workflows

### Single app (one-shot)
```
Request: "Add [app] to Homebrew"
↓
Research + emit one script
↓
User runs DRYRUN=1 to preview
↓
User runs for real
↓
PR + FR opened
```

### Batch mode (10+ apps)
```
Registry CSV (token | name | desc | artifact | source | homepage | spec)
↓
DRYRUN=1 TEST_INSTALL=1 bash scripts/cask-master.sh  (preview all)
↓
Fix failures (edit registry rows)
↓
bash scripts/cask-master.sh  (submit in batches of 10)
↓
SKIP_PASSED=1 bash scripts/cask-master.sh  (resume)
↓
All PRs + FRs opened
```

## Recent improvements (2026-06-10)

**Critical fixes:**
- ✅ Fixed directory creation race condition in subshells (was causing "No such file or directory" errors)
- ✅ Fixed hardcoded version replacement (now runs even when audit passes, not just on errors)
- ✅ Fixed TEST_INSTALL status reporting (no longer incorrectly marked as failures)

**Documentation:**
- ✅ Complete batch mode workflow with all flags documented
- ✅ Per-app diagnostics and report structure explained
- ✅ Common issues and solutions included
- ✅ Livecheck strategy guidance (custom vs simple)

## Files included

```
.claude/skills/homebrew-cask-author/
├── SKILL.md                      ← Main guide (start here)
├── EXPORT.md                     ← How to share/import
├── SHARING-SUMMARY.md            ← This file
├── README.md                     ← Technical overview
└── references/
    ├── cask-dsl.md               ← Homebrew DSL rules
    ├── end-to-end.md             ← Script template + resolvers
    ├── ci-troubleshooting.md     ← Audit error fixes
    ├── pr-and-disclosure.md      ← PR checklist
    └── research-sources.md       ← Metadata sources
```

## Key learning: Batch mode assumptions

The skill assumes you have:
- ✅ Homebrew installed (`brew --version`)
- ✅ `gh` CLI authed as your fork owner (with `fleetdm/fleet` access)
- ✅ A `fork` remote in the homebrew-cask tap (`git -C $(brew --repository homebrew/cask) remote -v`)
- ✅ `sudo` available (for pkg testing)
- ✅ macOS (install/uninstall testing must run on a Mac)

## Common use case: Fixing cask PRs

When a PR gets review feedback (e.g., "hardcoded version", "livecheck strategy"):

1. **Identify the issue** in the report or comment
2. **Edit the registry row** (data/master-list.csv) with the app's source type and URL fix
3. **Re-run with the fixed row:**
   ```bash
   DRYRUN=1 TEST_INSTALL=1 ONLY="app-token" bash scripts/cask-master.sh
   ```
4. **Copy the corrected cask** from `/tmp/caskwork/app-token/app-token.rb`
5. **Push to your PR branch** and update the PR

## Sharing instructions

**For teammates using Claude Code:**

1. Copy the `.claude/skills/homebrew-cask-author/` folder to their `.claude/skills/`
2. In Claude Code, type `/homebrew-cask-author` to load the skill
3. Ask to author a cask; it will guide them through the workflow

**For general sharing (GitHub):**

```bash
# Create an archive
cd .claude/skills && tar -czf homebrew-cask-author-skill.tar.gz homebrew-cask-author/

# Share the tarball; recipients extract with:
tar -xzf homebrew-cask-author-skill.tar.gz -C .claude/skills/
```

## Recommended reading order

1. **SKILL.md** — Overview and workflow options (5 min)
2. **SKILL.md § Batch mode** — For batch runs (3 min)
3. **references/end-to-end.md** — For single-app scripts (read as needed)
4. **references/cask-dsl.md** — Rules reference (bookmark, use for lookups)
5. **references/ci-troubleshooting.md** — For audit failures (read when needed)

## Batch mode quick reference

| Flag | Default | Purpose |
|------|---------|---------|
| `DRYRUN=1` | 0 | Preview only (write + audit, no install/push/PR) |
| `TEST_INSTALL=1` | 0 | Full test (install + uninstall + zap) before submit |
| `BATCH_SIZE=N` | 10 | Submit N apps per run (prevents flooding) |
| `SKIP_PASSED=1` | 0 | Skip apps that already passed |
| `ONLY="a b c"` | — | Run only these tokens |
| `KEEP=1` | 0 | Keep downloads after run (saves disk otherwise) |
| `ZAP=0` | 1 | Skip reinstall + zap test |

## Results

Each run writes to `$CASKWORK` (default `/tmp/caskwork`):

```
/tmp/caskwork/
├── MASTER-summary.md          ← Human-readable rollup (read first)
├── results.tsv                ← Machine-readable results
└── <token>/
    ├── report.md              ← Full diagnostics (resolve, audit, logs)
    ├── <token>.rb             ← Generated cask
    ├── summary.txt            ← Quick status
    ├── result.env             ← Environment variables
    └── *.log                  ← Install, uninstall, zap logs
```

Exit code is **non-zero if any app failed**, making it CI-friendly.

## Questions?

See the main repo: https://github.com/AdamBaali/FMA-Homebrew-Expander  
Check the CLAUDE.md for detailed setup and troubleshooting.
