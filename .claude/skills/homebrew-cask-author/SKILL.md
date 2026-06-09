---
name: homebrew-cask-author
description: Author and submit a new Homebrew Cask to Homebrew/homebrew-cask for a macOS app, end to end, as one runnable script. Research the app's download URL, version, sha256, bundle identifier, pkg receipt, minimum macOS, and uninstall/zap behavior (from the vendor, Installomator, AutoPkg, Munki, and existing casks); write the cask DSL; validate with brew style, brew audit, and a real install and uninstall on a Mac; push the branch and open the PR with the current checklist and an honest AI-usage disclosure; then file the matching Fleet-maintained-app feature request linking the PR. Use whenever someone wants to add an app to Homebrew Cask or Fleet-maintained apps, write, fix, or validate a cask .rb file, or resolve cask CI errors (OSDependsOn, leftover launch jobs, shared Microsoft AutoUpdate, redundant verified, unversioned sha256, token conflicts, homepage or livecheck failures). Trigger even on brief asks like 'add this app to Homebrew'.
---

# Authoring a Homebrew Cask (one-shot)

Takes a macOS app from "we want it in Homebrew" to an open, audit-clean PR against
`Homebrew/homebrew-cask` **and** a filed Fleet-maintained-app feature request — delivered as a
single script the user runs on their Mac, which prints a summary to paste back.

**The deliverable is ONE script.** Do the research up front, then emit one self-contained bash
script that does everything below and writes `/tmp/caskwork/summary.txt`. Do not hand over a
plan, partial steps, or multiple scripts. The full, copy-ready script template and the per-source
building blocks are in **`references/end-to-end.md`** — assemble the script from it every time.

**Hard rules**
- One cask per PR (one branch, one PR per app).
- A Mac with Homebrew is required (sha256, bundle id, audit, install/uninstall all run there).
- Never tick a PR checklist box the script did not actually verify. The script runs a real
  `brew install` + `brew uninstall`, so the install/uninstall boxes are honest — or it stops.
- AI-usage disclosure is mandatory and must be honest about what AI did and what the human verified.

---

## Step 1 — Research (you, before emitting the script)

Resolve enough to pick the script's resolver + cask shape. Produce:

| Field | Notes |
|---|---|
| `token` | lowercased app name, hyphens (e.g. `ibm-notifier`). Check it does not collide with a homebrew-core formula (`brew info <token>`); if it does, qualify it (e.g. `goto-desktop`). |
| app `name`, one-line `desc` | `desc` must obey **all** `Cask/Desc` rules or `brew style` fails: ≤80 chars; no platform word (macOS/Mac/OS X/Windows/Linux/version names); not starting with an article or the cask's own name; starts capitalised; no trailing period; no emoji. See `references/cask-dsl.md`. |
| installer type | `zip`, `dmg`, or `pkg` only. **Anything else (e.g. `.tbz`, `.tar.gz`) is not FMA-eligible — stop.** |
| download source + URL pattern | GitHub release / electron `latest-mac.yml` / vendor CDN redirect / direct versioned. This picks the resolver block. |
| homepage that brew can reach | some vendor sites 403 brew (Akamai). Verify a 200; if the product page is blocked, use a reachable sub-page. |
| livecheck source | GitHub releases, electron feed, header/redirect, Sparkle appcast. Avoid endpoints that are user-agent-gated (they hand brew non-JSON). |
| eligibility / availability | gated, tenant-only, or region-locked downloads (and apps removed from homebrew-cask for adware) can't be cask/FMA — say so and stop. |

`references/research-sources.md` has the exact sources and commands (Installomator label → AutoPkg →
Munki → existing cask → the app itself). The remaining runtime values — `sha256`, bundle id,
`LSMinimumSystemVersion`, pkg receipt, bundled launch daemons, bundled Microsoft AutoUpdate — are
derived **by the script** from the real download, so you don't need them up front.

If the app's cask **already exists** in homebrew-cask, there's no PR to open: skip straight to the
Fleet FR (use the `fleet-maintained-app-request` skill / the FR block in `references/end-to-end.md`).

### Eligibility pre-flight — check BEFORE authoring (saves wasted work)
Two homebrew-cask **core** gates can't be fixed from the cask side, and across a real batch they
account for a large share of failures (in one 144-app run, ~53 were blocked this way). Triage first:
- **Notarization.** The artifact must be signed + Apple-notarized. Spot-check the downloaded app:
  `codesign -dvv <app>` showing `adhoc`/`linker-signed` or `TeamIdentifier=not set` ⇒ **not
  notarizable into core.** Common for open-source/indie macOS apps (even popular ones).
- **Notability.** A `github.com` download URL requires the repo to clear ≥75★ **or** ≥30 forks
  **or** ≥30 watchers. Below that ⇒ blocked (`gh api repos/OWNER/REPO`). A **non-GitHub** vendor
  download URL sidesteps this gate — prefer one if it exists.
- Also: **archived** repos and tokens that **conflict with a homebrew/core formula** or **contain a
  reserved word** (e.g. `desktop`) are rejected.

If an app is blocked by any of these and there's no workaround, **skip it for core** (or route it to
a Fleet-owned custom tap via the `fleet-maintained-app-request` custom-tap variant) rather than
burning a full author+audit cycle on a cask that can't merge.

---

## Step 2 — Emit the one script

Assemble the script from `references/end-to-end.md`: fill the config block (`token`, `name`,
`desc`), drop in the matching **resolver** and **`write_cask`** block for the source type, and keep
the fixed harness. The harness, in order, with a hard stop + summary line at any failure:

1. fresh `add-<token>` branch off the tap's real default branch (detect it; it is `master`).
2. resolve version + download the installer; compute `sha256`.
3. inspect the artifact → bundle id, `LSMinimumSystemVersion` (→ bare `depends_on macos:` symbol),
   pkg receipt; scan a pkg payload for LaunchDaemons/Agents (→ `uninstall launchctl:`) and for a
   bundled `com.microsoft.autoupdate` choice (→ `pkg choices:` deselect + `quit:`).
4. write `Casks/<l>/<token>.rb`; `brew style --fix`; `brew audit --cask --strict --online --new`
   (strict by default for **CI parity**; `STRICT=0` drops `--strict`). The ship gate checks **both**
   remaining `brew style` offenses and audit problems. On failure, run a **bounded auto-fix pass**
   (safe, mechanical fixes only — adopt the artifact min OS the audit names, drop a platform word /
   leading article / trailing period from `desc`, remove redundant `verified:`, add a missing
   `depends_on macos:`, fix style/order — then re-`style`/re-audit, max 2 rounds), recording each
   change for review. If style or audit still fails, **stop** — see `references/ci-troubleshooting.md`.
5. real `brew install --cask`, then `brew uninstall --cask`; then (default) reinstall once for
   **idempotency** and `brew uninstall --zap --cask` to **exercise the zap stanza paths**. **Stop on
   any failure.** (`ZAP=0` skips the reinstall + zap.)
6. push `add-<token>` to the fork; open the PR (title `Add <token> (new cask)`). Build the body from
   Homebrew's **current** template — read `.github/PULL_REQUEST_TEMPLATE.md` from the freshly pulled
   tap, tick its boxes, and append the AI disclosure (which must name the tool/model) — so the
   checklist never goes stale if Homebrew changes it.
7. file the Fleet FMA FR (title `New FMA: <name>`), kept simple: the Homebrew cask PR link, direct
   links to the cask file and the installer, the file type, and the token. Always add the
   `:help-solutions-consulting` team label; the customer/prospect label is added by hand (or via
   `CUSTOMER_LABEL`). No customer/vendor/user story in the body.
8. write a **review bundle** — always, on success or failure — to `/tmp/caskwork/report.md` and print
   it. It records the outcome and the exact stage any failure hit, the resolved values
   (version/url/sha/bundle id/min-OS/receipt/launchd/MAU), the full cask, the captured `brew
   style` / `brew audit` / `brew livecheck` output, the auto-fixes applied, the
   `install`/`uninstall`/`reinstall`/`zap` logs, git state, and the progress log — i.e. everything
   needed to diagnose without a second round-trip.

Build in `DRYRUN=1` (preview the cask + PR/FR text, touch nothing), a `CUSTOMER_LABEL` variable for
the Fleet FR, `STRICT` (default 1, CI-parity audit) and `ZAP` (default 1, reinstall + zap test)
escape hatches, and prerequisite checks (`gh` authed as the fork owner with `fleetdm/fleet` access,
the token not already a cask, no homebrew-core formula collision).

Then tell the user exactly two things: run `DRYRUN=1 bash …` to preview, then run for real; and if
anything fails, **paste back `/tmp/caskwork/report.md`** (the printed review bundle) for review.

---

## Step 3 — On the pasted review bundle

- All green (audit OK, install/uninstall OK, PR + FR URLs printed) → done.
- A stage failed → the bundle names the failing stage and includes that stage's captured output;
  map it with **`references/ci-troubleshooting.md`**, and
  emit a small **patch script** (edit the cask on its branch, re-`style`/`audit`, `git commit --amend`)
  — not a fresh full run. Common ones: redundant `verified:` (remove it), missing `depends_on macos:`
  (add the bare symbol), livecheck "could not be parsed as JSON" (the endpoint is UA-gated — switch
  source or, if none exists, the app isn't cleanly livecheckable), unversioned URL → `sha256 :no_check`
  (find the versioned asset instead), token collides with a core formula (rename), homepage 403
  (use a reachable URL).

---

## What the rules are (read the references)

- **`references/cask-dsl.md`** — every stanza, `version.csv`/interpolation, all livecheck strategies,
  the arch (`sha256 arm:, intel:`) shape, `verified:` only when the URL domain differs from the
  homepage domain, and the shared-updater (`pkg choices:`) pattern.
- **`references/end-to-end.md`** — the canonical one-shot script, the per-source resolver + cask
  blocks, the current PR checklist, the honest AI-disclosure text, and the Fleet FR body + `gh` calls.
- **`references/ci-troubleshooting.md`** — the failure→fix table (always fix the named file:line,
  never disable a check).
- **`references/pr-and-disclosure.md`** — the exact current new-cask checklist and disclosure wording.

Highest-value DSL rules to never forget: `depends_on macos:` is a **bare** symbol and mandatory;
`uninstall` must unload daemons the pkg drops; never remove shared Microsoft AutoUpdate — deselect it
at install with `pkg choices:` and `quit:` it; `verified:` is an **error** when the URL and homepage
are the same domain; new casks need a real install **and** uninstall before the PR.

---

## Batch mode — many casks at once

When you have a backlog (e.g. a list of apps with no cask yet), don't re-derive the script per app.
Wrap **this same harness** in a loop over a small registry — one row per app:
`token | name | desc | artifact | source | homepage | spec` — where `source` selects the matching
resolver (`github_tag`, `github_compound`, `electron`, `msft_cdn`, `direct`, `custom`). Do all the
research up front, fill the registry, then:

1. `DRYRUN=1` the whole batch — each app writes + audits its cask and touches nothing else.
2. For any app that fails, read its `report.md` and fix only that row (livecheck regex and arch dmg
   filenames are the usual culprits); re-run `DRYRUN=1` until every row is clean.
3. Run for real — each app still gets its **own** `add-<token>` branch, its own homebrew-cask PR, and
   its own Fleet FR. One cask per PR is preserved; a failing app stops only itself, not the batch.

The per-app gates, hard stops, and AI disclosure are identical to the single-app flow above — batch
mode only saves re-pasting the harness. In this repository the batch wrapper is
`scripts/cask-master.sh` (registry format and per-source spec are documented at the top of that script).
