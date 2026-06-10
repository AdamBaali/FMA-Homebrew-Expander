# CLAUDE.md — operating guide for this repo

This repo is one deliverable: **`scripts/cask-master.sh`**, a macOS batch harness that
authors Homebrew Casks (and Fleet FMA requests) for the apps in its embedded REGISTRY.
`data/master-list.csv` is the per-app source of truth (`bucket` column = verdict).

## Hard guardrails

- **NEVER run the script without `DRYRUN=1` unless the user explicitly asks for a live
  run in this conversation.** A live run opens real PRs against Homebrew/homebrew-cask,
  files real fleetdm/fleet issues, does real `brew install`s, and (by default) writes a
  temporary passwordless-sudo drop-in for the duration of the run.
- Never set `SUDO_NOPASSWD`, `FILE_FR`, or `FRESH` yourself — those are the user's call.
- Don't edit casks inside the user's homebrew-cask tap checkout directly; fix the
  REGISTRY row (or custom resolver/writer) in `scripts/cask-master.sh` and re-run.

## Standard workflow (macOS only — brew style/audit for casks need a Mac)

```bash
DRYRUN=1 bash scripts/cask-master.sh                      # full preview, never ships
DRYRUN=1 ONLY="token-a token-b" bash scripts/cask-master.sh   # iterate on specific apps
DRYRUN=1 SKIP_PASSED=1 bash scripts/cask-master.sh        # re-run only what hasn't passed
CHECK=1 bash scripts/cask-master.sh                       # registry vs master-list.csv drift (runs anywhere)
```

Useful flags: `JOBS=N` (parallel download prefetch, default 4; `JOBS=0` = serial),
`LIMIT=N`, `START_AT=token` (resume), `LIVECHECK=0` (faster iteration),
`KEEP=1` (keep downloads — off by default to protect disk), `CASKWORK=dir`
(work dir; default `/tmp/caskwork`, which macOS wipes on reboot).
The full flag reference is in the script header.

## Triage after a run

- Exit code is non-zero if any app failed.
- `$CASKWORK/results.tsv` — one row per app (`token  status  stage  version  pr  fr  report`).
  Read this first; don't open 300 reports.
- 90 rows saying `skipped (policy-blocked)` are EXPECTED on a full run — those apps are
  known brew-audit policy rejections (NOT-ADDED.md §2; `POLICY_BLOCKED` in the script).
  Don't try to fix them; only re-test with `RUN_BLOCKED=1 ONLY="tok"` if upstream changed
  (app got notarized, repo gained stars), and delete the entry if it now passes.
- `$CASKWORK/MASTER-summary.md` — human rollup; failures are listed at the bottom with a
  ready-made `ONLY="..."` line to re-run just the failures.
- `$CASKWORK/<token>/report.md` — full per-app bundle (resolved values, cask text,
  style/audit output, install logs). In DRYRUN the written cask is also kept at
  `$CASKWORK/<token>/<token>.rb`.
- Typical fixes live in the REGISTRY row's `spec` field (livecheck `vregex`, asset
  filenames) or, for `source=custom`, in the `resolve_<tfn>` / `write_cask_<tfn>`
  functions. Re-verify with `DRYRUN=1 ONLY="<token>"`.

## Disk hygiene

The script deletes each app's download + extracted tree as soon as that app finishes
(and prunes brew's per-cask download cache on live runs); at most `JOBS` downloads are
on disk at once. If a machine still fills up, reclaim space with:

```bash
rm -rf /tmp/caskwork          # or just the bulky bits: rm -rf /tmp/caskwork/*/x /tmp/caskwork/*/dl*
brew cleanup -s --prune=all   # brew's own download cache
```

## Skill

`.claude/skills/homebrew-cask-author/` documents the cask DSL, research sources, CI
troubleshooting, and the PR/disclosure flow — load it when authoring or fixing casks.
