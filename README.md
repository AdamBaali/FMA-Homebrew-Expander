# FMA Homebrew Expander

Sourcing and Homebrew-Cask authoring for the **Fleet Maintained Apps** "no-homebrew-cask" backlog:
**533** [appcatalog.cloud](https://appcatalog.cloud) apps that currently have no Homebrew Cask.

The goal is to resolve a real macOS download source for each app, then author one Homebrew Cask
(and a matching Fleet-maintained-app request) per eligible app — all driven by a single batch
script and the `homebrew-cask-author` skill.

> Submitting is a human step. This repo gets the casks **authored and DRYRUN-validated**; a
> maintainer runs the script for real to open the homebrew-cask PRs and Fleet FRs. URLs and
> versions are never invented — unverifiable apps are marked `review`/ineligible and skipped.

## Status

**533 / 533 sourced · 234 authored into the cask registry.** Full per-app status — what's added, what isn't, and **why** — lives in **[`progress/readiness.md`](progress/readiness.md)** (the revisit doc).

| Bucket | Count | What it means |
|---|---|---|
| Total apps | **533** | the no-homebrew-cask backlog |
| ✅ **Added** to `cask-master.sh` | **234** | ready to `DRYRUN` on a Mac |
| 🛠️ Not added — needs custom resolver | **84** | verified download, but the URL/version doesn't fit a built-in source — needs a hand-written `resolve_`/`write_cask_` |
| 🚫 Not added — review | **196** | gated / login / paid / unversioned / unverifiable |
| 🚫 Not added — ineligible | **18** | Mac-App-Store-only, discontinued, non-eligible artifact, or duplicate of an existing cask |
| DRYRUN-clean | 0 | _validated on macOS by the maintainer_ |

The 84 "needs resolver" by reason: header-only version 32 · arch-split `.pkg` 10 · build-in-filename/tag skew 10 · per-release hash/token URL 9 · nested container 8 · string-transform version 6 · other 9. Per-app authoring facts are in [`progress/custom-todo.md`](progress/custom-todo.md).

> The 234 authored include 68 `direct_latest` rows (`version :latest` + `sha256 :no_check`) — Homebrew discourages these for new casks, so prune/upgrade them at DRYRUN. All flagged in `readiness.md`.

Live detail in [`progress/`](progress/) — `state.json`, `log.md`, `readiness.md`, `custom-todo.md`.

## Layout

```
.
├── data/                         # the working lists (extend in place)
│   ├── master-list.csv           #   533 rows, one per app — the source of truth
│   └── unsourced-worklist.csv    #   the 341 still to source
├── sources/                      # raw lookup tables mined from Mac-admin tooling
│   ├── source-autopkg-index.tsv  #   ~7,500 app→source mappings (primary lookup)
│   ├── source-installomator-fields.tsv
│   └── installomator-slug-to-label.tsv
├── scripts/
│   └── cask-master.sh            # batch cask authoring + PR/FR harness (run DRYRUN first)
├── .claude/skills/               # project skills, auto-discovered by Claude Code
│   └── homebrew-cask-author/     #   research → author → validate → PR → Fleet FR
├── progress/                     # resumable state + logs + readiness table
│   ├── state.json  log.md  readiness.md
│   └── sourced/                  #   per-chunk sourcing output
├── docs/
│   ├── HANDOFF.md                # original handoff bundle (provenance, status, column spec)
│   └── MASTER-PROMPT.md          # the operative workflow spec (Phases 0–3)
└── README.md
```

## Workflow

1. **Source** each unsourced app's macOS download in order — AutoPkg index → `autopkg search` →
   vendor web — cross-checking two sources, and write the result back into `data/master-list.csv`.
2. **Author** every eligible app (`zip`/`dmg`/`pkg`, high/med confidence) as a REGISTRY row in
   `scripts/cask-master.sh`, then **DRYRUN-validate** on a Mac until `brew style` + `brew audit`
   pass for every row.
3. **Hand off**: a maintainer runs the script for real.

The full spec is in [`docs/MASTER-PROMPT.md`](docs/MASTER-PROMPT.md); the authoring rules live in
the [`homebrew-cask-author`](.claude/skills/homebrew-cask-author/SKILL.md) skill.

### `data/master-list.csv` columns

`slug, name, appcatalog_url, source_origin, installomator_label, installer_type, fma_eligible,
source_class, source_detail, version_method, team_id, pkg_receipt, blocking_processes,
paid_or_gated, bucket, source_confidence` — see [`docs/HANDOFF.md`](docs/HANDOFF.md) for the value
sets.

## Running `cask-master.sh`

**Requires macOS** with Homebrew and the homebrew-cask tap — `brew audit`/`brew style` for casks
are macOS-only, so this cannot run on Linux. The script is location-independent (it operates on the
brew tap and `/tmp/caskwork`), so run it from anywhere:

```bash
DRYRUN=1 bash scripts/cask-master.sh           # preview: write + audit every cask, open nothing
DRYRUN=1 ONLY="filezilla" bash scripts/cask-master.sh   # one app
bash scripts/cask-master.sh                    # FOR REAL — opens a PR + Fleet FR per app (maintainer only)
```

Registry format, per-source spec, and all flags (`ONLY`, `LIMIT`, `STRICT`, `ZAP`, `FILE_FR`,
`CUSTOMER_LABEL`, `SUDO_NOPASSWD`, …) are documented at the top of the script. Before a real run:
`gh auth login`, add your `fork` remote in `$(brew --repository homebrew/cask)`, and optionally set
`CUSTOMER_LABEL=...` for the Fleet FRs. Per-app reports land in `/tmp/caskwork/<token>/report.md`.

**Password prompts:** a real run asks for your sudo password **once** and caches it for the whole
batch — it installs a temporary passwordless-sudo drop-in (`/etc/sudoers.d/cask-master-<pid>`) that
is **auto-removed when the run ends**, so pkg install/uninstall/zap never re-prompt. Set
`SUDO_NOPASSWD=0` to skip that and only keep the sudo credential timestamp warm instead.

## Provenance

The 192 already-sourced apps were resolved from Installomator labels, 44 AutoPkg recipe repos
(~10,090 recipes parsed), and per-vendor web research. Full provenance is in
[`docs/HANDOFF.md`](docs/HANDOFF.md).
