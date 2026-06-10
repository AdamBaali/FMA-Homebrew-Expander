# CLAUDE.md — Operating Guide

This repo is one deliverable: **`scripts/cask-master.sh`**, a macOS batch harness that
authors Homebrew Casks (and Fleet FMA requests) for apps in its REGISTRY.
`data/master-list.csv` is the per-app source of truth (`bucket` column = verdict).

## Hard Guardrails

- **NEVER run without `DRYRUN=1` unless explicitly approved.** Live runs open real PRs,
  file real issues, and do real installations.
- Don't set `SUDO_NOPASSWD`, `FILE_FR`, `FRESH`, `BATCH_SIZE`, or `SKIP_OPEN_PR` yourself —
  those are the user's call.
- Don't edit casks in the tap checkout directly; fix the REGISTRY row or custom resolver
  in `scripts/cask-master.sh` and re-run.

## Quick Start

```bash
# Fast audit (30 sec per app, no install)
DRYRUN=1 bash scripts/cask-master.sh

# Full test (2-3 min per app, with install/uninstall/zap)
DRYRUN=1 TEST_INSTALL=1 bash scripts/cask-master.sh

# Submit first 10 apps (safe default batch size)
bash scripts/cask-master.sh

# Submit next 10 apps (skip what passed)
BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh
```

## Key Features

- **Batch processing** (`BATCH_SIZE=10`) — Prevent flooding, safe defaults
- **Duplicate prevention** (`SKIP_OPEN_PR=1`) — Avoid duplicate PRs
- **Full testing** (`TEST_INSTALL=1`) — Complete validation without submission
- **Auto-fixes** — Hardcoded versions, deprecated syntax, zap stanzas
- **Resumable** (`SKIP_PASSED=1`) — Resume from failures or interruptions

## Important Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `DRYRUN=1` | 0 | Audit only (no install/push/PR) |
| `TEST_INSTALL=1` | 0 | Full test (no push/PR) |
| `BATCH_SIZE=N` | 10 | Apps per run (0 = unlimited) |
| `SKIP_OPEN_PR=1` | 0 | Skip apps with open PRs |
| `SKIP_PASSED=1` | 0 | Skip apps that already passed |
| `ONLY="a b c"` | — | Run only these apps |

**Full reference:** See [DOCUMENTATION.md](DOCUMENTATION.md)

## Triage After a Run

- Exit code is non-zero if any app failed
- `$CASKWORK/MASTER-summary.md` — Human summary; read this first
- `$CASKWORK/results.tsv` — Machine-readable results
- `$CASKWORK/<token>/report.md` — Per-app details
- 91 `skipped (policy-blocked)` rows are EXPECTED — see [NOT-ADDED.md](NOT-ADDED.md)

## Disk Hygiene

Downloads are automatically cleaned up. If disk fills:
```bash
rm -rf /tmp/caskwork/*/dl /tmp/caskwork/*/x  # Keep reports, delete downloads
brew cleanup -s --prune=all                   # Clean brew cache
```

Or use persistent directory:
```bash
CASKWORK=~/caskwork bash scripts/cask-master.sh
```

## Documentation

- [README.md](README.md) — Project overview and quick start
- [DOCUMENTATION.md](DOCUMENTATION.md) — Complete guide (flags, workflows, troubleshooting)
- [NOT-ADDED.md](NOT-ADDED.md) — Apps not shipped, grouped by reason
- [.claude/skills/homebrew-cask-author/](.claude/skills/homebrew-cask-author/) — Cask DSL, research sources, CI troubleshooting
