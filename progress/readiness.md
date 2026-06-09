# Readiness — registry & review/ineligible

This is the Phase 3 deliverable table. It will hold **every registry app** (token, source type,
DRYRUN result) once Phase 2 fills `scripts/cask-master.sh`, plus the apps marked review/ineligible
with the reason. Right now the registry is empty (Phase 1/2 not yet run), so this records the known
baseline only.

_Last updated: 2026-06-09 (Phase 0)._

## Summary

| Bucket | Count |
|---|---|
| Total apps | 533 |
| Sourced | 192 |
| Unsourced (worklist to do) | 341 |
| Registry-ready (eligible & high/med confidence) | 118 |
| Eligible but low-confidence (verify first) | 1 |
| Review / ineligible | 6 |
| AutoPkg rows needing installer-type classification | 67 |
| **In REGISTRY** | **0** (Phase 2 pending) |
| **DRYRUN-clean** | **0** (needs macOS) |

## Registry apps (token | source | DRYRUN)

_None yet — populated in Phase 2 as `scripts/cask-master.sh` REGISTRY rows are added and DRYRUN-validated on a Mac._

| token | source type | artifact | DRYRUN result |
|---|---|---|---|
| _(pending)_ | | | |

## Review / ineligible (do not author)

| token | verdict | reason |
|---|---|---|
| `2do` | no | Mac App Store only (`com.guidedways.TodoMac`) — no direct download |
| `acronis-cyber-protect-connect-client` | review | vendor portal (acronis.com / Nulana Remotix); confirm a direct installer |
| `adobe-acrobat` | review | Creative Cloud / enterprise distribution; not a plain versioned download |
| `adobe-dynamic-media-classic` | review | Adobe enterprise / Scene7; gated |
| `appgate-sdp` | review | portal-gated download (appgate.com) |
| `atera-agent` | review | console-gated agent (atera.com) — per-tenant installer |

## Eligible but low-confidence (verify before authoring)

| token | type | source | note |
|---|---|---|---|
| `adobe-acrobat-cleaner-tool` | dmg | direct (adobe.com) | standalone cleaner; confirm the live versioned URL before adding to the registry |
