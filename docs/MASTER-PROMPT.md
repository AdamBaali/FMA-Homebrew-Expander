# Master prompt — Fleet no-homebrew-cask sourcing + cask authoring

This is the operative spec that drives the repo. It is preserved here for resumability.
Paths below reflect the current repo layout (`data/`, `sources/`, `scripts/`,
`.claude/skills/`); the original handoff used flat filenames (see `docs/HANDOFF.md`).

> **Environment note (2026-06-09):** the `homebrew-cask-author` skill now lives in-repo at
> `.claude/skills/homebrew-cask-author/` (not `/mnt/skills/user/`). `brew` is macOS-only, so
> Phase 2 DRYRUN validation must run on a Mac — it cannot run on a Linux web container.

---

The goal: 533 appcatalog.cloud apps that have no Homebrew Cask. A prior pass sourced 192. The
job is to finish sourcing the remaining 341, then fill ONE script — `scripts/cask-master.sh` —
that the user runs to open the Homebrew cask PRs and the Fleet FMA requests. Do all the sourcing,
fill the script, and prove it dry-runs clean. Do **not** open any real PRs or FRs — submitting is
the user's job. Work autonomously and in parallel, persist progress so the work can resume, and
**never invent download URLs or versions**.

Use the **homebrew-cask-author** skill for all sourcing and authoring decisions, and
**fleet-maintained-app-request** for the Fleet FRs. Read their `SKILL.md` first.

## Files
- `data/master-list.csv` — the master list (533 rows). EXTEND THIS IN PLACE. Schema below.
- `data/unsourced-worklist.csv` — the 341 still to source (slug, name, appcatalog_url).
- `sources/source-autopkg-index.tsv` — ~7,500 app→source mappings from 44 AutoPkg repos. Primary lookup.
- `sources/source-installomator-fields.tsv` — raw Installomator fields for the 108 already done.
- `sources/installomator-slug-to-label.tsv` — slug→Installomator label.
- `scripts/cask-master.sh` — the authoring/PR/FR script. Registry format documented at its top.
- `docs/HANDOFF.md` — context and provenance.

### `data/master-list.csv` columns
`slug, name, appcatalog_url, source_origin, installomator_label, installer_type,
fma_eligible, source_class, source_detail, version_method, team_id, pkg_receipt,
blocking_processes, paid_or_gated, bucket, source_confidence`
- source_origin: installomator | autopkg | web-research | "" (=unsourced)
- installer_type: zip | dmg | pkg (eligible) | pkgInDmg/appInDmgInZip (yes-nested) | ""
- fma_eligible: yes | yes-nested | no | review | unknown
- source_class: github | direct | dynamic-scrape | sparkle/feed | msft | mas | vendor | unknown
- source_detail: owner/repo for github, else host or full URL
- source_confidence: high (verified/tooling) | med | low

## Phase 0 — preflight (do once, then print a plan)
1. Read `docs/HANDOFF.md` and the homebrew-cask-author `SKILL.md`.
2. Verify tooling: `brew` and the homebrew-cask tap (needed for DRYRUN validation), `python3`,
   and `autopkg` (optional). `gh` auth and a `fork` remote in `$(brew --repository homebrew/cask)`
   are only needed at submit time — do not block on them for DRYRUN; just flag at the end if missing.
3. Create `progress/`: `progress/state.json` (resumable cursor), `progress/log.md` (append-only),
   `progress/sourced/` (per-chunk output).
4. Print: current counts from master-list.csv, number unsourced, and the plan.

## Phase 1 — source the 341 (parallel subagents)
1. Read `data/unsourced-worklist.csv`. Split into chunks of ~20 apps.
2. Launch a subagent (Task) per chunk, up to 5 concurrently. Each subagent follows the SOURCING
   SPEC and writes `progress/sourced/<chunk>.csv` only — never edit master-list.csv inside a subagent.
3. When chunks finish, merge `progress/sourced/*.csv` into `data/master-list.csv` by `slug`, filling
   the source columns. Append a status line to `progress/log.md`. Update `state.json`.
4. Repeat until every worklist app has been attempted.

### SOURCING SPEC (each subagent, per app)
Resolve the macOS download source in this order; stop at the first solid hit:
1. **AutoPkg index** — normalise name and slug (lowercase, strip non-alphanumerics), look up in
   `sources/source-autopkg-index.tsv`. Hit → source_origin=autopkg, take its class/detail, confidence=high.
2. **`autopkg search <app>`** (if autopkg installed) — inspect the `.download` recipe for the URL/processor.
3. **Vendor web** (WebSearch + WebFetch) — find the official site, confirm a real, current macOS
   download URL and installer type. Follow the skill's research-sources order (vendor → Installomator
   → AutoPkg → Munki → existing casks). Cross-check at least two sources.

Write back per app: source_origin, source_class, source_detail, installer_type, fma_eligible, source_confidence.

Hard rules:
- Eligible installer types are **zip, dmg, pkg only**. Nested (pkgInDmg / appInDmgInZip / pkgInZip)
  → `fma_eligible=yes-nested`.
- Mac App Store-only, paid-portal-gated, tenant/SSO-gated, or login-required downloads →
  `fma_eligible=review` (or `no`) with a one-word note in source_detail. DO NOT invent a URL.
- NEVER fabricate URLs or versions. If you can't verify, leave source_origin empty and note why.
  `confidence=high` only when checked against the live vendor source; `med` for a strong but
  unconfirmed pattern; `low` for a guess.
- Group by vendor — one lookup often resolves a whole developer's catalogue (e.g. AKVIS, Koingo).

## Phase 2 — fill the PR+FR script (DO NOT submit)
The single final deliverable is a populated, DRYRUN-clean `scripts/cask-master.sh` that the user
runs to open the PRs and Fleet FRs. Fill it and validate it; never run it for real.
For rows where `fma_eligible` is `yes` or `yes-nested` AND `source_confidence` is `high` or `med`:
1. Map each to a `cask-master.sh` REGISTRY row (the editable block at the top of the script):
   `token | name | desc | artifact | source | homepage | spec`
   - desc ≤80 chars, no platform word, no leading article, no trailing period, must not start with the token.
   - source type from source_class: github→`github_tag` (or `github_compound` for `v-<ver>-b-<build>`
     tags), electron feed→`electron`, aka.ms/Microsoft CDN→`msft_cdn`, plain versioned vendor
     URL→`direct`, Sparkle/scrape→`direct` with `vers`+`vregex`, anything that doesn't fit→`custom`
     (and write the `resolve_<token>`/`write_cask_<token>` functions per the script's instructions).
2. Append every such app to the REGISTRY. Keep going in batches until all eligible sourced apps are in it.
3. Validate ONLY with `DRYRUN=1 bash scripts/cask-master.sh` — this writes and audits the casks and
   opens nothing. For any app that fails, read `/tmp/caskwork/<token>/report.md` and fix its registry
   row (livecheck regex and arch dmg names are the usual culprits). Re-run DRYRUN until every row
   passes `brew style` + `brew audit`.
4. Do NOT run `cask-master.sh` without DRYRUN, and do NOT call `gh` to open PRs or issues.

Guardrails: keep the script's built-in real install/uninstall/zap test and its honest AI-usage
disclosure intact (they fire at submit time). Do not edit those out. One cask per PR.

## Phase 3 — deliver, loop, persist
Final output is three things: (a) the updated `data/master-list.csv`, (b) a fully-populated,
DRYRUN-clean `scripts/cask-master.sh` whose REGISTRY holds every eligible sourced app, and
(c) `progress/readiness.md` — a table of every registry app (token, source, DRYRUN result) plus
the apps marked review/ineligible with the reason.
- Update `progress/state.json` after every chunk and batch so the work can resume after interruption.
- Keep going batch after batch without waiting for confirmation. Stop only when: every worklist app
  is sourced or marked review/ineligible, every eligible app is in the REGISTRY, and DRYRUN passes
  for all of them — OR a hard blocker needs the user.
- After each batch print one line: `sourced X/533 | in-registry Y | dryrun-clean Z | needs-me: …`.
- When finished, tell the user exactly how to submit:
  - `DRYRUN=1 bash scripts/cask-master.sh` to re-preview (opens nothing),
  - `bash scripts/cask-master.sh` to open every PR + Fleet FR,
  - `ONLY="tok1 tok2" bash scripts/cask-master.sh` for a subset,
  - and remind them to `gh auth login`, add their `fork` remote, and set `CUSTOMER_LABEL=...` if they
    want it on the Fleet FRs.
