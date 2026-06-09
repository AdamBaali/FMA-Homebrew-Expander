# progress/sourced

Per-app sourcing results from the cask-authoring pipeline (the multi-agent
research output), consolidated into one file per phase.

| File | What it is |
|---|---|
| `phase2-results.tsv` | The 97 already-sourced (Installomator/AutoPkg/web) eligible apps, triaged: `status` ∈ `row` (authored into `scripts/cask-master.sh`), `custom` (needs a bespoke resolver — see `../custom-todo.md`), `review`, `ineligible`. Columns: `slug, status, registry_row, confidence, notes`. |

During an active sourcing run, transient per-chunk input/output files
(`in-chunk*.tsv`, `out-chunk*.tsv`) may appear here; they are consolidated into a
`*-results.tsv` and removed when the run completes. The authoritative outputs are
`data/master-list.csv` (verdicts), `scripts/cask-master.sh` (the REGISTRY rows),
`../readiness.md`, and `../custom-todo.md`.
