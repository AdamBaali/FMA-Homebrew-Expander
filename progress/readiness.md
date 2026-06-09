# Readiness — registry & review/ineligible

_Last updated: 2026-06-09 (Phase 2 — github_tag batch)._

## Summary

| Bucket | Count |
|---|---|
| Total apps | 533 |
| Sourced | 192 |
| Eligible (yes/yes-nested & high/med) | 111 |
| **In REGISTRY (authored)** | **14** |
| Eligible remaining to author | 97 |
| Review / ineligible | 13 |
| AutoPkg rows needing installer-type classification | 67 |
| **DRYRUN-clean** | **0** (requires macOS) |

Remaining eligible by source_class: `{'direct': 58, 'unknown': 5, 'github': 3, 'sparkle/feed': 7, 'dynamic-scrape': 23, 'msft': 1}`

## Registry apps (token | source | artifact | DRYRUN)

All statically verified (repo + latest-release redirect + single macOS asset + `{v}` templating + no token collision). **Not yet DRYRUN-validated** — run `DRYRUN=1 bash scripts/cask-master.sh` on a Mac.

| token | source | artifact | DRYRUN result |
|---|---|---|---|
| `airbattery` | github_tag | dmg | ⏳ pending (run DRYRUN on Mac) |
| `backgrounds` | github_tag | pkg | ⏳ pending (run DRYRUN on Mac) |
| `elevate24` | github_tag | pkg | ⏳ pending (run DRYRUN on Mac) |
| `escrow-buddy` | github_tag | pkg | ⏳ pending (run DRYRUN on Mac) |
| `icons` | github_tag | pkg | ⏳ pending (run DRYRUN on Mac) |
| `jamf-pppc-utility` | github_tag | zip | ⏳ pending (run DRYRUN on Mac) |
| `jamf-printer-manager` | github_tag | zip | ⏳ pending (run DRYRUN on Mac) |
| `jamf-reenroller` | github_tag | zip | ⏳ pending (run DRYRUN on Mac) |
| `jamfcheck` | github_tag | dmg | ⏳ pending (run DRYRUN on Mac) |
| `managed-app-schema-builder` | github_tag | zip | ⏳ pending (run DRYRUN on Mac) |
| `mobile-to-local` | github_tag | zip | ⏳ pending (run DRYRUN on Mac) |
| `pique` | github_tag | pkg | ⏳ pending (run DRYRUN on Mac) |
| `sym-helper` | github_tag | zip | ⏳ pending (run DRYRUN on Mac) |
| `utiluti` | github_tag | pkg | ⏳ pending (run DRYRUN on Mac) |

> Note: `pique` is a beta-only release (`0.1.0b5`) — fine for a documented exception, flag at PR time.

## Review / ineligible (do not author)

| token | verdict | reason |
|---|---|---|
| `2do` | no | Mac App Store only (com.guidedways.TodoMac) |
| `acronis-cyber-protect-connect-client` | review | vendor portal (acronis.com / Nulana Remotix) |
| `adobe-acrobat` | review | Creative Cloud / enterprise distribution |
| `adobe-dynamic-media-classic` | review | Adobe enterprise / Scene7, gated |
| `appgate-sdp` | review | portal-gated download |
| `atera-agent` | review | console-gated per-tenant agent |
| `container` | review | homebrew-core formula collision; apple CLI runtime |
| `dockutil` | review | homebrew-core formula collision (brew install dockutil) |
| `homebrew` | no | bogus: Homebrew itself, not a cask |
| `jupyterlab` | review | formula collision + arch-split; needs token jupyterlab-desktop + custom |
| `mist-cli` | review | homebrew-core formula collision (brew install mist-cli) |
| `nextcloud-desktop-client` | review | duplicate of existing cask 'nextcloud' |
| `obs-studio` | review | duplicate of existing cask 'obs' |

## Arch-split GitHub apps — pending `source=custom`

Two-architecture downloads (`github_tag` is single-asset only): `apache-netbeans-15` (also version-pin naming), `microsoft-powershell`, `visualz`. Author later as custom resolver/writer.

