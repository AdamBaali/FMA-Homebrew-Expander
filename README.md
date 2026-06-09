# FMA Homebrew Expander

A single batch script — **[`scripts/cask-master.sh`](scripts/cask-master.sh)** — that authors
Homebrew Casks (and matching Fleet-maintained-app requests) for the **Fleet Maintained Apps**
"no-homebrew-cask" backlog: **533** [appcatalog.cloud](https://appcatalog.cloud) apps that had no
Homebrew Cask.

> Submitting is a human step. Run the script on a Mac: `DRYRUN=1` writes + audits every cask and
> opens nothing; a real run opens one homebrew-cask PR + Fleet FR per app. URLs and versions are
> never invented — unverifiable apps are marked review/ineligible and skipped.

## Status

**533 / 533 sourced · 318 authored into the registry** — one `bash scripts/cask-master.sh` run now authors them all. Per-app status is in [`progress/readiness.md`](progress/readiness.md); the `bucket` column of `data/master-list.csv` is the authoritative per-app verdict.

| Bucket | Count |
|---|---|
| Total apps | **533** |
| ✅ Authored in `cask-master.sh` | **318** |
| &nbsp;&nbsp;↳ via built-in source types | 240 |
| &nbsp;&nbsp;↳ via custom `resolve_`/`write_cask_` resolvers | 78 |
| 🛠️ Needs a custom resolver | **0** |
| 🚫 Review / ineligible | **214** |
| DRYRUN-clean | 0 _(validated on macOS by the maintainer)_ |

Authored by source type: `github_tag 71 · direct 55 · direct_latest 69 · custom 78 · direct_arch 18 · github_arch 11 · electron 9 · direct_header 4 · msft_cdn 2 · github_compound 1`. The 69 `direct_latest` rows are `version :latest` + `sha256 :no_check` (prune at DRYRUN); the 78 custom-resolver apps are flagged in `readiness.md` for closer DRYRUN review.

> Counts above are generated from the script's REGISTRY + `master-list.csv` (see `progress/state.json`) — regenerate after edits to avoid drift.

## Layout

```
.
├── scripts/
│   └── cask-master.sh            # the deliverable: batch cask authoring + PR/FR harness
├── data/
│   └── master-list.csv           # one row per app — source of truth + per-app status (`bucket` column)
├── .claude/skills/
│   └── homebrew-cask-author/     # the cask-authoring skill (drives the script; auto-loaded by Claude Code)
├── progress/
│   ├── readiness.md              # ★ per-app status: added / not-added + why
│   ├── custom-todo.md            # verified facts for the apps still needing a custom resolver
│   └── state.json                # counts
├── .gitignore
└── README.md
```

## Running it (macOS only)

`brew audit`/`brew style` for casks are macOS-only, so the script needs a Mac with Homebrew and the
homebrew-cask tap. It's location-independent (operates on the tap and `/tmp/caskwork`).

```bash
DRYRUN=1 bash scripts/cask-master.sh                    # preview: write + audit every cask, open nothing
DRYRUN=1 ONLY="filezilla" bash scripts/cask-master.sh   # one app
bash scripts/cask-master.sh                             # FOR REAL — opens a PR + Fleet FR per app (maintainer)
```

Registry format, per-source spec, and all flags (`ONLY`, `LIMIT`, `STRICT`, `ZAP`, `FILE_FR`,
`CUSTOMER_LABEL`, `SUDO_NOPASSWD`, …) are documented at the top of the script. **Sudo is asked once
and cached for the whole run** (a temporary `/etc/sudoers.d` drop-in, auto-removed on exit), so
installs/uninstalls never re-prompt. Before a real run: `gh auth login` and add your `fork` remote
in `$(brew --repository homebrew/cask)`. Per-app reports land in `/tmp/caskwork/<token>/report.md`.
