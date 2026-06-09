# Cask CI troubleshooting

## What the harness auto-fixes vs. what needs review
After `brew audit --strict --online --new` (strict by default, for CI parity; `STRICT=0` drops it),
the harness runs a bounded auto-fix pass (max 2 rounds): it applies only deterministic transforms,
re-runs `brew style --fix` and `brew audit`, and records each change in the report's "Auto-fixes
applied" section so the human still reviews them.

Auto-fixed (safe, mechanical):
- artifact/cask min-OS mismatch ("Artifact defined :X as the minimum macOS version…") → the cask's
  `depends_on macos:` is set to the symbol the audit names (it is authoritative).
- `desc` containing the platform ("Description shouldn't contain the platform") → the platform word
  (macOS/Mac/Windows/Linux) is removed and the desc re-capitalised.
- redundant `verified:` → the argument is removed (works inline or on its own line).
- `desc` ending in a period → trailing `.` stripped.
- `desc` starting with `A`/`An`/`The` → leading article stripped.
- no minimum macOS declared → `depends_on macos: ">= :<symbol>"` inserted (when the symbol is known).
- formatting/indent/stanza order → handled by `brew style --fix`.

The ship gate checks remaining `brew style` offenses **and** audit problems, so a style-only offense
(like the platform-in-desc one) can no longer slip through to a PR. Note: `inspect` reads a pkg's
minimum macOS from the pkg `Distribution` (`<os-version min=…>`) and skips any bundled Microsoft
AutoUpdate app, so MAU-bundled installers (Remote Help, Copilot) get the right min OS up front.

NOT auto-fixed — surfaced in the report for you/Claude to judge (editing the cask would just hide a
real defect, and Homebrew requires the human to have reviewed it):
- livecheck "could not be parsed as JSON" / binary livecheck / version mismatch → the source is
  UA-gated or the regex is wrong; pick a different livecheck source.
- "Use `sha256 :no_check` when URL is unversioned" / unversioned download → find a versioned asset.
- homepage not reachable (403/timeout) → use a sub-page brew can fetch.
- "GitHub repository not notable enough" / "too new" → notability gate; nothing in the cask fixes it.
- failed signing/notarization (`spctl`, `codesign`, `pkgutil --check-signature`) → artifact issue.
- install/uninstall failures → structural; the logs are in the report, fix the stanza by hand.
- `brew uninstall --zap` failure → a zap path is wrong; fix the `zap trash:` paths (the zap log is in
  the report). The harness exercises zap by default (`ZAP=0` skips it).

CI (the `ci.yml` workflow on the PR) usually fails the first time. Diagnose from the run's
annotations; never disable a check.

## Reading the failure
- Open the failing run or job URL the contributor has, e.g.
  `https://github.com/Homebrew/homebrew-cask/actions/runs/<run-id>` or the per-job link.
- The **Annotations** block lists each error with the offending file and line,
  e.g. `Casks/d/dfu-blaster-pro.rb#L22`. That block renders in the page's static HTML, so it's
  readable without signing in. (The GitHub API and arbitrary log endpoints are not reliably
  fetchable — use the run/job HTML page.)
- The matrix shows which runners ran. macOS-only casks should run only macOS runners
  (e.g. `macos-15`, `macos-26`). If you see `ubuntu-*` runners, the cask is missing
  `depends_on macos:` (see below).

## Iterate
For each fix: edit the named file → `brew style --fix <token>` → `git commit --amend --no-edit`
→ `git push --force-with-lease fork add-<token>`. CI re-runs on push. Re-open the new run and
re-read its annotations.

## Failure → fix table

**`Homebrew/OSDependsOn: Add depends_on :macos` / `Use depends_on macos: :SYMBOL`**
The cask is macOS-only but has no (or a wrongly-formatted) macOS dependency.
- Fix: add `depends_on macos: :SYMBOL` as a **bare symbol** (`:big_sur`, `:ventura`, `:sonoma`…),
  not `">= :SYMBOL"`. `brew style --fix` performs exactly this correction — run it before pushing.

**`macOS is required for this software` on `ubuntu-*` runners**
Same root cause as above: with no `depends_on macos:`, the matrix scheduled Linux runners. Adding
the bare-symbol `depends_on macos:` both satisfies the cop and stops Linux runners being scheduled —
one fix clears all of these errors at once.

**`Some launch jobs were not unloaded, add them to uninstall launchctl: …`**
**`Some packages are still installed, add them to uninstall pkgutil: …`**
The installer dropped daemons/agents or pkg receipts that `uninstall` didn't remove.
- Fix: add the app's **own** components: `uninstall launchctl: "com.vendor.helper", pkgutil:
  "com.vendor.pkg.App"`.
- Exception: if the flagged ids are a **shared** updater (Microsoft AutoUpdate —
  `com.microsoft.autoupdate.helper`, `com.microsoft.update.agent`,
  `com.microsoft.package.Microsoft_AutoUpdate.app`), do **not** add them to `uninstall`. Instead stop
  MAU from installing via a `pkg ... choices:` override that deselects it
  (`"choiceIdentifier" => "com.microsoft.autoupdate"`, `"attributeSetting" => 0`). Do not use
  `depends_on cask: "microsoft-auto-update"` — that dependency was removed from the Microsoft casks.
  See the shared-updater section in `cask-dsl.md`.

**`Some applications are still running, add them to uninstall quit: …`**
A process the cask started is still running at uninstall time.
- Fix: `uninstall quit: "com.vendor.app"`. `quit` stops the process without removing anything —
  the right choice for a shared process like `com.microsoft.autoupdate2`. The accompanying warning
  `Application '…' did not quit. Enable Automation access …` is a CI-sandbox limitation and does
  not fail the build.

**`The homepage URL … is not reachable (HTTP status code 404)`**
- Fix: set `homepage` to a reachable product/download page (verify it returns 200).

**Livecheck failures (`couldn't find versions`, regex errors)**
- Fix: correct the `strategy`/`regex`. Confirm against the real feed/page. For redirect links use
  `:header_match`; for appcasts `:sparkle`; for JSON `:json` with a transform; for history pages
  `:page_match` with a block.

**`sha256 mismatch` / `SHA-256 …` errors**
- Fix: re-download the exact `url` and recompute (`shasum -a 256`). Vendors silently re-cut builds;
  pin the version and hash together.

**`audit` complaints on `desc`/`name`**
- Fix: `desc` is one line, no trailing period, doesn't start with A/An/The; `name` is the
  human-facing app name.

## Principle
Each annotation names a concrete file:line and an exact remedy. Apply the remedy, re-run
`brew style --fix`, push with `--force-with-lease`, and re-read the new run. Most casks go green in
1–3 iterations.

---

## More failure → fix (added from real audit runs)

| Audit / CI message | Cause | Fix |
|---|---|---|
| `the 'verified' parameter of the 'url' stanza is unnecessary` (URL domain matches homepage domain) | `verified:` was added when the download host shares the homepage's **registrable domain** — either the same host (both `github.com`) **or a subdomain** (`static.culturedcode.com` vs `culturedcode.com`) | **Remove the `verified:` line** (and the trailing comma on the `url` line). Compare the last two domain labels, not the full host: a subdomain of the homepage domain never needs `verified:`. |
| `Version 'X' differs from 'Y' retrieved by livecheck` (Y is non-empty/wrong) | the cask `version` ≠ what the livecheck regex captures. Livecheck takes Ruby `scan().first` = **capture group 1** (whole match if no group). A prefixed regex returns group 1 (`Version (\d+…)` → `8.0`); `[0-9]+(\.[0-9]+)+` returns only the last `.N` | Make the regex's group 1 the **entire** version (`([0-9]+(?:\.[0-9]+)+)`, inner groups non-capturing) and set `version` to that same value. See `cask-dsl.md` → livecheck. |
| `Verified URL X does not match URL Y` | `verified:` prefix isn't actually a prefix of the resolved download URL (e.g. `microsoft.com/` vs real host `res.public.onecdn.static.microsoft`) | Set `verified:` to the real download **host + `/`** (derive it from the resolved URL, not the brand domain). |
| `Artifact defined :ventura as the minimum macOS version but the cask declared no minimum macOS version` | the artifact's `LSMinimumSystemVersion` is higher than (or present while) the cask has no `depends_on macos:` | Add `depends_on macos: :<symbol>` (bare symbol) matching the artifact minimum. |
| `Version 'X' differs from '' retrieved by livecheck` | the livecheck regex/strategy returned nothing (regex didn't match the real filename) | Fix the regex to match the **actual** filename — watch for suffixes like `_installer` before `.pkg`. |
| `exception while auditing …: Content could not be parsed as JSON` (but your own `curl` got JSON) | the version endpoint is **user-agent-gated** — it serves JSON to `curl` but HTML/a bot page to Homebrew's livecheck UA | No `:json`/`:page_match` against that URL will work. Switch to a non-gated source (GitHub releases, a Sparkle appcast, an electron `latest-mac.yml`). If none exists, the app isn't cleanly livecheckable — flag it rather than shipping a broken livecheck. |
| `cask token conflicts with an existing homebrew/core formula` | the token (e.g. `goto`) is taken by a formula in homebrew-core | Rename the cask token to a non-colliding, descriptive one (e.g. `goto-desktop`); move the file and update the `cask "…"` line and branch name. |
| `Use sha256 :no_check when URL is unversioned` | the `url` has no `#{version}` in it (a rolling "latest" download) | First prefer a **versioned** URL — electron feeds list versioned files in `latest-mac.yml`; use those. If the vendor only serves a fixed `app.dmg` (Koingo, AKVIS, …), keep the real `version` + a `:page_match` livecheck and just set `sha256 :no_check` — this is **not** the same as `version :latest` and is correct/acceptable. Drop to `version :latest` only when the version is also unknowable. |
| `requires Rosetta 2 but this is not indicated by the caveats` | the artifact is x86_64-only; no Rosetta caveat | Add `caveats do\n requires_rosetta\nend` (last stanza, after `zap`). Detect via `lipo -archs Contents/MacOS/<exe>` showing `x86_64`/`i386` and no `arm64`. |
| `Rosetta`/`Signature verification failed`/`not notable` but your own `curl` 200s / mounts fine | often a **transient** audit-time download blip (Akamai/CDN reset, rate-limit) — distinct from a real signing or notability failure | Re-run the single token. If it recurs, it's real (for signing: `codesign -dvv` shows `adhoc`/no Team ID; for notability: the repo is genuinely under the star/fork/watcher bar). |
| `The homepage URL … is not reachable (HTTP status code 403)` | the vendor site bot-blocks brew (Akamai etc.); even a browser UA may 403 | Use a vendor URL that returns 200 to brew (sometimes a `support.`/docs sub-page); confirm with `curl -fsS -o /dev/null -w '%{http_code}' <url>`. |
