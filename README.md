# no-homebrew-cask sourcing — handoff bundle

Source list: Fleet `ee/maintained-apps/app-catalog-parity/no-homebrew-cask.md`
(533 appcatalog.cloud apps that have no Homebrew Cask).

## Status (as of this handoff)

- **533** apps total
- **192 sourced** — Installomator 108, AutoPkg 67, web research 17
- **341 unsourced** — not in Installomator or AutoPkg; need per-app vendor research

The sourcing is the hard part and is only partly done. Everything mined so far,
plus the raw source indexes to keep going, is in this bundle.

## Files

| File | What it is |
|---|---|
| `master-list.csv` | The master list. One row per app (533), with source fields filled for the 192 sourced. **This is the file to keep extending.** |
| `unsourced-worklist.csv` | The 341 not yet sourced (slug, name, appcatalog URL). The to-do list. |
| `source-installomator-fields.tsv` | Raw Installomator fields for the 108 matches: installer type, exact `downloadURL` expression, `appNewVersion` method, `expectedTeamID`, `packageID`, `blockingProcesses`. Join to the master on `installomator_label`. |
| `source-autopkg-index.tsv` | **~7,500 app → source mappings** parsed from 44 AutoPkg recipe repos (normalised name, source class, detail, recipe name). The lookup table for sourcing the rest. |
| `installomator-slug-to-label.tsv` | slug → Installomator label, for the 108. |
| `cask-master.sh` | The cask authoring/PR/FR script. Feed it sourced+eligible rows once you have them. Run `DRYRUN=1` first. |

## `master-list.csv` columns

`slug, name, appcatalog_url, source_origin, installomator_label, installer_type,
fma_eligible, source_class, source_detail, version_method, team_id, pkg_receipt,
blocking_processes, paid_or_gated, bucket, source_confidence`

- **source_origin**: `installomator` | `autopkg` | `web-research` | empty (=unsourced)
- **installer_type**: `pkg` | `dmg` | `zip` (FMA-eligible) | `pkgInDmg`/`appInDmgInZip` (nested, authorable with extra handling) | empty
- **fma_eligible**: `yes` | `yes-nested` | `no` | `review` | `unknown`
- **source_class**: `github` | `direct` | `dynamic-scrape` | `sparkle/feed` | `msft` | `mas` | `vendor` | `unknown`
- **source_detail**: owner/repo for github, host or URL for the rest
- **source_confidence**: `high` (tooling) | `med` | `low` (knowledge/flagged, verify before authoring)

## How the 192 were sourced (provenance)

1. **Installomator** (`Installomator/Installomator` `main`): matched 533 slugs to its labels (93 exact + 15 curated aliases = 108), then extracted each label's full field block. `downloadURL`/type/teamID are authoritative.
2. **AutoPkg**: downloaded 44 recipe repos from the `autopkg` org, parsed 10,090 recipe files (plist + yaml) into a name→source index (`GitHubReleasesInfoProvider` → github repo; `Sparkle` → appcast; `URLDownloader`/`URLTextSearcher` → direct/dynamic URL). Matched 67 of the still-unsourced apps by normalised name.
3. **Web research**: per-vendor searches for clusters (AKVIS, Koingo, Veertu, Acon Digital, Adobe, etc.). Flagged `med`/`low` confidence; gated/App-Store-only apps marked `review`/ineligible.

appcatalog.cloud public pages give bundle ID + Developer (Team) ID but **not** download URLs (that's Root3's paid data), so they weren't a source for the URL.

## Continue in Claude Code

The homebrew-cask-author skill lives at `/mnt/skills/user/homebrew-cask-author/`
(and `fleet-maintained-app-request`, `winget-manifest-author`). Use them.

Suggested prompt:

> Read `master-list.csv` and `unsourced-worklist.csv`. For each unsourced app, resolve its macOS download source in this order, and write the result back into `master-list.csv` (fill `source_origin`, `source_class`, `source_detail`, `installer_type`, `fma_eligible`, `source_confidence`):
> 1. Join the app's normalised name/slug against `source-autopkg-index.tsv`. If hit, use that source (origin=autopkg, confidence=high).
> 2. Else run `autopkg search <app>` and inspect the recipe.
> 3. Else web-search the vendor and confirm a real download URL + installer type, following the homebrew-cask-author skill's research-sources order (vendor, Installomator, AutoPkg, Munki, existing casks). Cross-check two sources. Confidence med/high only if verified.
> Eligibility rules: only `zip`/`dmg`/`pkg` downloads are FMA-eligible. Mark Mac-App-Store-only, paid-portal-gated, or tenant-gated apps as `fma_eligible=review` or `no` and move on — do not invent URLs. Work in batches, you can parallelise across the worklist.
> Once a batch of rows is sourced and eligible, hand them to `cask-master.sh` (registry format is documented at the top of that script): run `DRYRUN=1` first, then for real.

### Speeding it up
- The AutoPkg index is the highest-yield lookup — match against it first.
- Group by vendor: one search/recipe often resolves a whole developer's catalogue.
- For bundle ID + Team ID on any app (feeds the cask `zap`/uninstall and signature checks), fetch its `appcatalog_url` page.

### Authoring (cask-master.sh)
Registry rows are `token | name | desc | artifact | source | homepage | spec`.
Map each sourced app to a source type (`github_tag`, `electron`, `msft_cdn`, `direct`, `custom`) and fill the spec. Always `DRYRUN=1` first; a failing app stops only itself, not the batch; per-app reports land in `/tmp/caskwork/<token>/report.md`.
