# FMA Homebrew Expander

A production-grade **batch Homebrew Cask generator** with comprehensive **end-to-end validation** for the Fleet Maintained Apps backlog: **533** [appcatalog.cloud](https://appcatalog.cloud) apps with no Homebrew Cask.

**New:** Full **local validation system** with 17 comprehensive phases, duplicate detection, filesystem snapshots, and zero-guessing verification. Test everything before submission. ✨

## 🚀 Quick Start (3 Steps)

### 1. Test Everything Locally

```bash
bash validation/validate-all-prs.sh
```

Validates all 20 open PRs (60-90 minutes):
- ✅ Generates casks
- ✅ Checks for duplicates vs 14k+ Homebrew casks
- ✅ Monitors file creation
- ✅ Tests installation/uninstallation
- ✅ Verifies zap cleanup
- ✅ Reports which are ready

### 2. Fix Issues

```bash
bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb
bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb
bash validation/end-to-end-validate.sh <app>
```

### 3. Submit Ready Casks

```bash
bash scripts/cask-master.sh
```

**📖 Next:** Read [`START-HERE.md`](START-HERE.md) or [`README-WORKFLOW.md`](README-WORKFLOW.md)

## What's New

### 🔍 End-to-End Validation System

**17 comprehensive phases** of validation:
1. Cask generation
2. Duplicate detection (vs 14k+ Homebrew casks)
3. System state snapshot (before install)
4-9. Installation, app launch, filesystem monitoring
10. Zap stanza verification (cleanup is complete)
11-17. Code quality, audit, livecheck, metadata, reinstall tests

**Result:** Production-ready casks guaranteed to pass Homebrew CI

### 📚 Research Registry

Centralized app metadata for 500+ apps:
- `research/apps/apps-registry.json` — All app information
- `research/apps/app-template.json` — Template for new entries
- `scripts/lib/research-utils.sh` — Query and manage registry

### 🗂️ Better Organization

```
validation/      — 9 validation scripts
research/        — App metadata registry
scripts/         — Cask generation
docs/            — Complete documentation
```

### ✅ Zero Guessing

- **Filesystem snapshots** capture exactly what each app creates
- **System state monitoring** detects system artifacts
- **Zap stanza verification** ensures cleanup works
- **All tested locally** before submission

## Status

**533 / 533 sourced · 226 shippable to homebrew-cask core**

See [`NOT-ADDED.md`](NOT-ADDED.md) for apps not shipped and why.

The `bucket` column of [`data/master-list.csv`](data/master-list.csv) is the authoritative per-app verdict.

## Key Features

### ✨ Validation System (NEW)
- **17 validation phases** from generation to submission-ready
- **Duplicate detection** against 14k+ Homebrew casks
- **Filesystem snapshots** to verify zap stanza completeness
- **System state monitoring** matching Homebrew CI
- **Local testing** before any PR submission
- **Auto-fix common issues** (hardcoded versions, syntax, formatting)

### 🛡️ Safety First
- **Batch processing** (`BATCH_SIZE=10`) prevents flooding
- **Test before submit** — Run validation locally first
- **Duplicate prevention** — Checks existing casks
- **Safe dry-run** (`DRYRUN=1`) — No installs, PRs, or changes

### 🔧 Smart Generation
- Hardcoded version strings → `#{version}` interpolation
- Deprecated `depends_on` syntax → Modern syntax
- Missing zap paths → Auto-detected via filesystem monitoring
- Missing livecheck → Suggested patterns
- And 8 more quality checks...

### 📦 Professional Workflow
- 10 apps per run (safe defaults)
- Resumable with `SKIP_PASSED=1`
- Parallel prefetch for speed
- Persistent results directory
- Git-ready output

## Repository Structure

```
FMA-Homebrew-Expander/
├── START-HERE.md                 ← Read this first (5 minutes)
├── README-WORKFLOW.md            ← Complete workflow guide
│
├── validation/                   ← End-to-end validation (17 phases)
│   ├── validate-all-prs.sh       ← Main command
│   ├── end-to-end-validate.sh    ← Single app validation
│   ├── analyze-cask.sh           ← Code quality analysis
│   ├── cask-fixer.sh             ← Auto-fix common issues
│   ├── check-duplicates.sh       ← Duplicate detection
│   └── check-system-state.sh     ← System state snapshots
│
├── research/                     ← App research registry
│   └── apps/
│       ├── apps-registry.json    ← All 500+ apps (you build this)
│       ├── app-template.json     ← Template for new entries
│       └── examples.json         ← Example entries
│
├── scripts/
│   ├── cask-master.sh            ← Cask generation harness
│   └── lib/
│       └── research-utils.sh     ← Query registry
│
├── docs/                         ← Documentation
│   ├── QUICKSTART.txt            ← Quick reference
│   ├── VALIDATION-GUIDE.md       ← Detailed usage
│   ├── E2E-VALIDATION.md         ← Deep dive
│   └── E2E-CHECKS.md             ← All 17 phases
│
├── data/
│   ├── master-list.csv           ← App status tracker
│   └── homebrew-apps/            ← Generated casks
│
└── Other files
    ├── DOCUMENTATION.md          ← Original docs
    ├── CLAUDE.md                 ← Project instructions
    ├── NOT-ADDED.md              ← Apps not shipped + why
    └── .claude/skills/           ← Claude Code skills
```

## Usage (macOS only)

`brew audit`/`brew style` for casks are macOS-only. The script operates on the Homebrew tap and `/tmp/caskwork` (or persistent `~/caskwork`).

### Setup (one-time)
```bash
# Ensure you have Homebrew and tools
brew tap homebrew/cask
brew install jq
gh auth login                        # GitHub CLI, authorized for your fork
cd $(brew --repository homebrew/cask)
git remote add fork https://github.com/YOUR_USERNAME/homebrew-cask
```

### Typical Workflow

```bash
cd /Users/adam/Documents/GitHub/FMA-Homebrew-Expander

# 1. Validate everything locally (60-90 min)
bash validation/validate-all-prs.sh

# 2. Review results
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/SUMMARY.md

# 3. Fix any issues
bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb
bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb

# 4. Re-validate fixed apps
bash validation/end-to-end-validate.sh <app>

# 5. Submit ready casks
bash scripts/cask-master.sh

# 6. Track progress
cat ~/caskwork/MASTER-summary.md
```

## Common Tasks

| Task | Command |
|------|---------|
| Validate all 20 | `bash validation/validate-all-prs.sh` |
| Test one app | `bash validation/end-to-end-validate.sh poll-everywhere` |
| Analyze code quality | `bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb` |
| Auto-fix issues | `bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb` |
| Check for duplicates | `bash validation/check-duplicates.sh ~/caskwork/<app>/<app>.rb` |
| Query research registry | `bash scripts/lib/research-utils.sh stats` |
| Generate & audit only | `DRYRUN=1 bash scripts/cask-master.sh` |
| Full test (no submit) | `DRYRUN=1 TEST_INSTALL=1 bash scripts/cask-master.sh` |
| Submit 10 apps | `bash scripts/cask-master.sh` |
| Submit next batch | `BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh` |
| Check results | `cat ~/caskwork/MASTER-summary.md` |
| Check one app | `cat ~/caskwork/<app>/report.md` |

## Validation Commands

| What | Command | Time |
|------|---------|------|
| Validate all | `bash validation/validate-all-prs.sh` | 60-90 min |
| Validate one | `bash validation/end-to-end-validate.sh <app>` | 5-10 min |
| Analyze quality | `bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb` | 30 sec |
| Auto-fix | `bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb` | 1 min |
| Check duplicates | `bash validation/check-duplicates.sh ~/caskwork/<app>/<app>.rb` | 30 sec |

## Key Flags (for cask-master.sh)

| Flag | Default | Purpose |
|------|---------|---------|
| `DRYRUN=1` | 0 | Audit only (no install/push/PR) |
| `TEST_INSTALL=1` | 0 | Full testing (no push/PR) |
| `BATCH_SIZE=N` | 10 | Apps per run (0 = unlimited) |
| `SKIP_PASSED=1` | 0 | Skip apps that already passed |
| `ONLY="a b c"` | — | Run only these apps |

**Full reference:** See [DOCUMENTATION.md](DOCUMENTATION.md)

## Output

### Validation Results

Results land in `~/caskwork/`:

**Batch validation** (`validate-all-prs.sh`):
- `validation-YYYYMMDD-HHMMSS/SUMMARY.md` — High-level results (Ready/Review/Failed)
- `validation-YYYYMMDD-HHMMSS/<app>-e2e.md` — Per-app detailed report
- `validation-YYYYMMDD-HHMMSS/<app>-analysis.txt` — Code quality issues
- `validation-YYYYMMDD-HHMMSS/<app>.log` — Raw logs

**Per-app validation**:
- `e2e-reports/<app>-validation.md` — 17-phase validation report

**Generation results**:
- `<app>/<app>.rb` — Generated cask
- `<app>/report.md` — Generation details
- `<app>/fs_changes.txt` — Files app created
- `<app>/*.log` — Test logs (install, audit, zap, etc.)

Use persistent directory to survive reboots:
```bash
CASKWORK=~/caskwork bash validation/validate-all-prs.sh
```

## Next Steps

1. **Quick start:** Read [`START-HERE.md`](START-HERE.md) (2 minutes)
2. **Run validation:** `bash validation/validate-all-prs.sh` (60-90 min)
3. **Check results:** `cat ~/caskwork/validation-*/SUMMARY.md`
4. **Fix issues:** Use `analyze-cask.sh` and `cask-fixer.sh`
5. **Submit:** `bash scripts/cask-master.sh`

## Documentation

- **Getting started:** [`START-HERE.md`](START-HERE.md)
- **Complete workflow:** [`README-WORKFLOW.md`](README-WORKFLOW.md)
- **Quick reference:** [`docs/QUICKSTART.txt`](docs/QUICKSTART.txt)
- **Validation guide:** [`docs/VALIDATION-GUIDE.md`](docs/VALIDATION-GUIDE.md)
- **All 17 phases:** [`docs/E2E-CHECKS.md`](docs/E2E-CHECKS.md)
- **Research registry:** [`research/README.md`](research/README.md)
- **Operating guide:** [`CLAUDE.md`](CLAUDE.md)
- **Policy decisions:** [`NOT-ADDED.md`](NOT-ADDED.md)

## Source

The app backlog is Fleet's ["appcatalog.cloud apps with no Homebrew cask"](https://github.com/fleetdm/fleet/blob/118e968fac7f45d07f6dcd3bd08bcd055254928b/ee/maintained-apps/app-catalog-parity/no-homebrew-cask.md) list, shared by Allen Houchins on 2026-06-08. See [`NOT-ADDED.md`](NOT-ADDED.md) for details on all 533 apps.
