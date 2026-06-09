# Progress log (append-only)

## 2026-06-09 — Phase 0: repo setup

- Imported the handoff bundle (7 files) and reorganised the repo into
  `data/`, `sources/`, `scripts/`, `docs/`, `.claude/skills/`, `progress/`.
- Installed the **homebrew-cask-author** skill at
  `.claude/skills/homebrew-cask-author/` (canonical Claude Code location → auto-discovered
  in future web sessions). Reviewed all 6 skill files; they are verified and sound, so the
  content is verbatim — the only change is an additive **"Batch mode"** section in `SKILL.md`.
- Baseline counts from `data/master-list.csv`: **533** total; **192 sourced**
  (Installomator 108, AutoPkg 67, web-research 17); **341 unsourced**.
- Eligibility of the sourced set: **118 registry-ready** (`fma_eligible` yes|yes-nested AND
  `source_confidence` high|med); **1** eligible but low-confidence (`adobe-acrobat-cleaner-tool`);
  **6** review/ineligible (`2do`, `acronis-cyber-protect-connect-client`, `adobe-acrobat`,
  `adobe-dynamic-media-classic`, `appgate-sdp`, `atera-agent`); **67** AutoPkg rows still need
  `installer_type` + `fma_eligible` classification.
- Tooling: `python3`, `git`, `jq`, `curl`, network reachable. Missing: `brew` (macOS-only;
  blocks Phase 2 DRYRUN on this Linux box), `autopkg` (optional), `gh` (submit-time only).
- Phase 1 has **not** started — awaiting the go-ahead and any further skills.

`sourced 192/533 | in-registry 0 | dryrun-clean 0 | needs-me: remaining skills + a macOS host for DRYRUN (or confirm you'll run DRYRUN on your Mac), then say "go" for Phase 1`

## 2026-06-09 — Phase 2: github_tag batch (14 authored)

- Resolved all 24 GitHub-class eligible apps deterministically (repo from Installomator
  `downloadURLFromGit`, tag via `releases/latest` redirect, assets via `expanded_assets`).
- Authored **14** clean single-asset `github_tag` rows into `scripts/cask-master.sh`
  (statically verified; **not** DRYRUN'd — needs a Mac).
- Excluded: `dockutil`,`mist-cli`,`container`,`jupyterlab` (homebrew-core formula collision);
  `obs-studio`,`nextcloud-desktop-client` (duplicate existing casks); `homebrew` (bogus) → review/no.
- Arch-split pending custom: `apache-netbeans-15`,`microsoft-powershell`,`visualz`.
- Fixed `airbattery` installer_type zip→dmg (master-list error); filled GitHub repos into `source_detail`.

`sourced 192/533 | in-registry 14 | dryrun-clean 0 | needs-me: DRYRUN the 14 on your Mac; then I continue with electron/msft/direct batches + the 341`

## 2026-06-09 — Phase 2: subagent batch consolidated (43 rows total)

- 5 parallel research subagents sourced the 97 remaining-eligible apps (chunks 1-5); chunk 6 (JDKs/misc) direct.
- All 97 triaged: 29 row, 36 custom, 45 review/ineligible (incl. duplicate-of-existing-cask catches).
- Inserted 29 verified direct/electron/msft rows -> 43 registry rows total (github + this batch). Tokens checked vs cask+formula APIs.
- 36 apps need custom resolvers (facts in progress/custom-todo.md).

`sourced 192/533 | in-registry 43 | dryrun-clean 0 | custom-todo 36 | needs-me: DRYRUN on Mac; Phase 1 (341) pending`

## 2026-06-09 — Phase 1 wave 1 (chunks 1-5, 94 apps)

- 5 parallel subagents cold-sourced 94 of the 341 unsourced apps.
- Triage: 19 row (authored), 32 custom (resolver to-do), 36 review, 7 ineligible.
- Registry now 62 rows; sourced 286/533; unsourced 247 remain.
- Reclassified azul-zulu-jdk-22/24 custom->review (non-LTS; zulu cask tracks latest).

`sourced 286/533 | in-registry 62 | custom 68 | review/inelig 88 | unsourced 247 | dryrun-clean 0`

## 2026-06-09 — Phase 1 wave 2 (chunks 6-10, 95 apps)

- 5 subagents cold-sourced 95 apps. Triage: 23 row, 34 custom, 37 review, 1 ineligible.
- Registry now 85 rows; sourced 381/533; unsourced 152 remain.

`sourced 381/533 | in-registry 85 | custom 102 | review/inelig 126 | unsourced 152 | dryrun-clean 0`

## 2026-06-09 — Phase 1 wave 3 (chunks 11-15, 95 apps)

- 5 subagents cold-sourced 95 apps. Triage: 17 row, 37 custom, 37 review, 4 ineligible.
- Registry now 102 rows; sourced 476/533; unsourced 57 remain.

`sourced 476/533 | in-registry 102 | custom 139 | review/inelig 167 | unsourced 57 | dryrun-clean 0`

## 2026-06-09 — Phase 1 wave 4 (chunks 16-18, 56 apps) — PHASE 1 COMPLETE

- 3 subagents cold-sourced the final 56 apps. Triage: 8 row, 20 custom, 28 review, 0 ineligible.
- Registry now 110 rows; sourced 532/533; unsourced 1 remain.

`sourced 532/533 | in-registry 110 | custom 159 | review/inelig 195 | unsourced 1 | dryrun-clean 0`

## 2026-06-09 — Author batch A: GitHub arch-split + single-asset (+20 rows)

- Added `github_arch` source handler (on_arm/on_intel, dmg/zip).
- Authored 11 arch-split + 1 single (nextai-translator) custom GitHub apps + 8 AutoPkg-github apps = 20 rows. brackets -> review (discontinued, no mac asset).
- Registry now 130 rows.

`sourced 533/533 | in-registry 130 | custom 148 | autopkg-pending 58 | review/inelig 196 | dryrun-clean 0`

## 2026-06-09 — Author batch B: direct_latest/direct_arch (+44 rows)

- Converted 44 of 95 wave-1 customs into rows: direct_latest 34, direct_arch 9, direct 1. 51 remain bespoke-custom.
- Registry now 174 rows.

`in-registry 174 | custom 104 | autopkg-pending 58 | review/inelig 196 | dryrun-clean 0`

## 2026-06-09 — Author batch C (+30 rows)

- Converted 30 of 53 wave-2 customs -> rows (direct_latest 22, direct_arch 6, github_tag 2). 23 remain bespoke.
- quilt -> quilt-app (formula collision). Registry now 204 rows.

`in-registry 204 | custom 74 | autopkg-pending 58 | review/inelig 196 | dryrun-clean 0`
