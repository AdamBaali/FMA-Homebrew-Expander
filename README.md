# FMA Homebrew Expander

A single batch script — **[`scripts/cask-master.sh`](scripts/cask-master.sh)** — that authors
Homebrew Casks (and matching Fleet-maintained-app requests) for the **Fleet Maintained Apps**
"no-homebrew-cask" backlog: **533** [appcatalog.cloud](https://appcatalog.cloud) apps that had no
Homebrew Cask.

**Source:** the backlog is Fleet's ["appcatalog.cloud apps with no Homebrew cask"](https://github.com/fleetdm/fleet/blob/118e968fac7f45d07f6dcd3bd08bcd055254928b/ee/maintained-apps/app-catalog-parity/no-homebrew-cask.md)
list, shared by Allen Houchins on [2026-06-08](https://fleetdm.slack.com/archives/C02TYJF11P0/p1780941961900449?thread_ts=1780930437.788159&cid=C02TYJF11P0).
It's since been removed from fleet `main`, so the pinned commit is the durable link — see [`NOT-ADDED.md`](NOT-ADDED.md).

## Quick Start

### Audit only (fast, no installation)
```bash
DRYRUN=1 bash scripts/cask-master.sh
```

### Full test (complete verification, no PR submission)
```bash
DRYRUN=1 TEST_INSTALL=1 bash scripts/cask-master.sh
```

### Submit apps (with batching to prevent flooding)
```bash
bash scripts/cask-master.sh              # First 10 apps
BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh   # Next 10 apps
```

**📖 Full documentation:** See [**DOCUMENTATION.md**](DOCUMENTATION.md) for complete guide, all flags, workflows, and troubleshooting.

## Status

**533 / 533 sourced · 317 authored into the registry · 226 shippable** — one `bash scripts/cask-master.sh` run authors all 226 shippable casks; the 91 policy-blocked apps are skipped by default (`RUN_BLOCKED=1` re-tests them). The `bucket` column of [`data/master-list.csv`](data/master-list.csv) is the authoritative per-app verdict; [`NOT-ADDED.md`](NOT-ADDED.md) lists every app that isn't shipped, grouped by reason.

| Bucket | Count |
|---|---|
| Total apps | **533** |
| ✅ Authored in `cask-master.sh` | **317** |
| &nbsp;&nbsp;↳ via built-in source types | 240 |
| &nbsp;&nbsp;↳ via custom `resolve_`/`write_cask_` resolvers | 77 |
| &nbsp;&nbsp;↳ ⛔ blocked by Homebrew **core** policy (`POLICY_BLOCKED`; skipped by default) | 91 |
| &nbsp;&nbsp;↳ ✅ shippable to homebrew-cask core | **226** |
| 🛠️ Needs a custom resolver | **0** |
| 🚫 Not eligible / not sourced | **216** |

Authored by source type: `custom 77 · github_tag 71 · direct_latest 69 · direct 47 · direct_arch 19 · direct_header 12 · github_arch 11 · electron 8 · msft_cdn 2 · github_compound 1`. The 69 `direct_latest` rows are `version :latest` + `sha256 :no_check`.

> A macOS dry run audited 244 of the authored casks (2026-06-10); its failures were triaged into
> registry/resolver fixes plus the **91** apps blocked by Homebrew **core** policy (not notable /
> not notarized / archived / robot-blocked vendors) that can't merge as-is — listed under section 2
> of [`NOT-ADDED.md`](NOT-ADDED.md) and carried in the script as `POLICY_BLOCKED`, so runs skip
> them by default (`RUN_BLOCKED=1` re-tests them). Counts are derived from the script's REGISTRY +
> `master-list.csv`; regenerate after edits to avoid drift.

## Key Features

### 🛡️ Safety First
- **Batch processing** (`BATCH_SIZE=10`) prevents overwhelming Homebrew with too many submissions
- **Duplicate PR prevention** (`SKIP_OPEN_PR=1`) avoids double submissions
- **Safe dry-run** (`DRYRUN=1`) audits without installing, git changes, or PR creation
- **Full testing** (`TEST_INSTALL=1`) validates install/uninstall/zap without committing

### 🔧 Auto-fixes
- Hardcoded version strings → `#{version}` variable
- Deprecated `depends_on` syntax → Correct architecture blocks
- Platform words in descriptions → Removed
- Missing cleanup paths → Auto-detected
- And more...

### 📦 Smart Defaults
- 10 apps per run (safe for Fleet/Homebrew)
- Resumable runs with `SKIP_PASSED=1`
- Parallel prefetch for faster downloads
- Automatic disk cleanup

## Layout

```
.
├── scripts/
│   └── cask-master.sh            # the deliverable: batch cask authoring + PR/FR harness
├── data/
│   └── master-list.csv           # one row per app — source of truth + per-app verdict
├── .claude/skills/
│   └── homebrew-cask-author/     # cask authoring skill
├── DOCUMENTATION.md              # complete guide (all flags, workflows, etc.)
├── CLAUDE.md                     # project operating instructions
├── NOT-ADDED.md                  # apps not shipped, grouped by reason
├── .gitignore
└── README.md
```

## Usage (macOS only)

`brew audit`/`brew style` for casks are macOS-only. The script operates on the Homebrew tap and `/tmp/caskwork`.

### Setup (one-time)
```bash
# Ensure you have Homebrew and the cask tap
brew tap Homebrew/cask
gh auth login  # GitHub CLI, authorized for your fork
cd $(brew --repository homebrew/cask)
git remote add fork https://github.com/YOUR_USERNAME/homebrew-cask
```

### Running
```bash
cd /path/to/FMA-Homebrew-Expander

# Preview: audit all casks without installing or submitting
DRYRUN=1 bash scripts/cask-master.sh

# Test specific app with full install/uninstall/zap
DRYRUN=1 TEST_INSTALL=1 ONLY="escrow-buddy" bash scripts/cask-master.sh

# Submit first 10 apps (creates PRs and Fleet FRs)
bash scripts/cask-master.sh

# Submit next batch
BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh
```

## Common Tasks

| Task | Command |
|------|---------|
| Quick audit | `DRYRUN=1 bash scripts/cask-master.sh` |
| Full test | `DRYRUN=1 TEST_INSTALL=1 bash scripts/cask-master.sh` |
| Test one app | `DRYRUN=1 TEST_INSTALL=1 ONLY="app-name" bash scripts/cask-master.sh` |
| Submit 10 apps | `bash scripts/cask-master.sh` |
| Submit next 10 | `BATCH_SIZE=10 SKIP_PASSED=1 bash scripts/cask-master.sh` |
| Skip existing PRs | `SKIP_OPEN_PR=1 bash scripts/cask-master.sh` |
| Check results | `cat /tmp/caskwork/MASTER-summary.md` |
| Check one app | `cat /tmp/caskwork/app-name/report.md` |
| Resume from failure | `SKIP_PASSED=1 bash scripts/cask-master.sh` |

## Important Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `DRYRUN=1` | 0 | Audit only (no install/push/PR) |
| `TEST_INSTALL=1` | 0 | Full testing (no push/PR) |
| `BATCH_SIZE=N` | 10 | Apps per run (0 = unlimited) |
| `SKIP_OPEN_PR=1` | 0 | Skip apps with open PRs |
| `SKIP_PASSED=1` | 0 | Skip apps that already passed |
| `ONLY="a b c"` | — | Run only these apps |

**Full flag reference:** See [DOCUMENTATION.md](DOCUMENTATION.md#flag-reference)

## Output

Results land in `/tmp/caskwork/`:
- `MASTER-summary.md` — High-level rollup with pass/fail summary
- `results.tsv` — Machine-readable results (import to spreadsheet)
- `<token>/report.md` — Per-app detailed report
- `<token>/audit.log` — Brew audit output
- `<token>/install.log` — Installation test results
- `<token>/zap.log` — Zap stanza verification

Use persistent directory to survive reboots:
```bash
CASKWORK=~/caskwork bash scripts/cask-master.sh
```

## Next Steps

1. Read [**DOCUMENTATION.md**](DOCUMENTATION.md) for complete reference
2. Start with `DRYRUN=1` to preview
3. Test with `DRYRUN=1 TEST_INSTALL=1` on a few apps
4. Submit first batch with `bash scripts/cask-master.sh`
5. Monitor PRs and proceed with next batches using `SKIP_PASSED=1`

## References

- **Operating guide:** [`CLAUDE.md`](CLAUDE.md)
- **Complete documentation:** [`DOCUMENTATION.md`](DOCUMENTATION.md)
- **Policy decisions:** [`NOT-ADDED.md`](NOT-ADDED.md)
- **App registry:** [`data/master-list.csv`](data/master-list.csv)
- **Cask skill:** [`.claude/skills/homebrew-cask-author/`](.claude/skills/homebrew-cask-author/)
