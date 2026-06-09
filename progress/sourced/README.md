# progress/sourced

Per-app **sourcing provenance** from the cask-authoring pipeline (the multi-agent research
output), consolidated into one file per phase. Each row records what was found for an app and the
verdict. Columns: `slug, status, registry_row, confidence, notes` (status ∈ `row`/`source-type`,
`custom`, `review`, `ineligible`).

| File | Rows | What it is |
|---|---|---|
| `phase2-results.tsv` | 97 | The first-pass eligible apps (Installomator/AutoPkg-seeded + early web research). |
| `phase1-results.tsv` | 341 | The cold-sourced backlog (apps with no Installomator/AutoPkg match) — full vendor web research. |
| `autopkg-results.tsv` | 58 | The AutoPkg-indexed apps whose installer type/version had to be resolved from their sparkle/scrape source. |

These are the **research record** (URLs, versions, livecheck strategies, and the reason anything
was marked custom/review). The authoritative *current* outputs are elsewhere:
`data/master-list.csv` (per-app verdict in the `bucket` column), `scripts/cask-master.sh` (the
authored REGISTRY rows), `../readiness.md` (the added / not-added + why summary), and
`../custom-todo.md` (facts for the apps still needing a hand-written resolver).

> During an active run, transient per-chunk scratch (`in-*.tsv`, `out-*.tsv`) appears here and is
> git-ignored; it's consolidated into the `*-results.tsv` files above and cleaned up afterward.
