# PR submission — current checklist & AI disclosure

## Always use the live template (don't hardcode)
The PR checklist changes over time, so read it live instead of trusting this file. Homebrew's
template lives at `Homebrew/homebrew-cask/.github/PULL_REQUEST_TEMPLATE.md`. Two ways to get the
current one:
- **In the script (preferred):** the tap is a local clone, so after `git pull` the template is on
  disk at `"$(brew --repository homebrew/cask)"/.github/PULL_REQUEST_TEMPLATE.md`. The harness reads
  it, ticks every `- [ ]` box, fills any `<cask>`/`<token>` placeholder, and appends the disclosure.
- **When updating the skill:** `web_fetch` the raw template
  (`https://raw.githubusercontent.com/Homebrew/homebrew-cask/<default-branch>/.github/PULL_REQUEST_TEMPLATE.md`)
  and re-sync the baked-in fallback below. Also check `docs.brew.sh/Acceptable-Casks` for policy
  changes (e.g. the stricter notability thresholds for self-submitted casks).

The checklist below is only the **fallback** used if the live template can't be found, and the
documented reference for what the boxes mean.

## Base branch & title
- PR base is `Homebrew/homebrew-cask`'s default branch, which is **`master`** (detect it rather
  than assuming: `gh repo view Homebrew/homebrew-cask --json defaultBranchRef -q .defaultBranchRef.name`).
- Title: **`Add <token> (new cask)`** (matches accepted new-cask PRs).
- One cask per PR. Use descriptive commit messages; do **not** squash after pushing updates.

## The new-cask checklist (current)
Only tick a box the work actually satisfies. For a new cask all of these apply, and the install +
uninstall must have **really run** locally:

```
#### After making any changes to a cask, existing or new, verify:
- [x] Submission is for a stable version or documented exception
- [x] `brew audit --cask --online <token>` is error-free
- [x] `brew style --fix <token>` reports no offenses

#### Additionally, if adding a new cask:
- [x] Named the cask according to the token reference
- [x] Checked the cask was not already refused
- [x] `brew audit --cask --new <token>` worked successfully
- [x] `HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask <token>` worked successfully
- [x] `brew uninstall --cask <token>` worked successfully

#### If AI-assisted:
- [x] Personally reviewed, tested, and verified all changes including `zap` stanza paths
```

## AI-usage disclosure (mandatory, must be honest)
Homebrew policy (docs.brew.sh/How-To-Open-a-Homebrew-Pull-Request): you must disclose AI/LLM use
**and name the tool/model**, and you must have reviewed all AI-generated content before asking
anyone to review it. Put a short, truthful paragraph in the PR body, e.g.:

> AI (Claude) assisted in creating this PR: it researched the download URL, version, bundle
> identifier, minimum macOS, and pkg receipt, and drafted the cask DSL. I reviewed the result, ran
> `brew style --fix` and `brew audit --cask --strict --online --new` with no offenses or errors, and
> installed, reinstalled, uninstalled, and zapped the cask locally on macOS to verify the artifact, a
> clean uninstall, an idempotent reinstall, and the `zap` stanza paths.

(The harness generates this line from the actual run, so if `STRICT=0` or `ZAP=0` it drops the parts
that did not run — keep it matching what you actually did.)

Do not overstate or understate what AI did, and never tick the "personally reviewed/tested" box
unless the human actually has.

## Opening it non-interactively
```bash
gh pr create --repo Homebrew/homebrew-cask --base "$DEF" \
  --head "<fork-owner>:add-<token>" --title "Add <token> (new cask)" --body-file pr.md
```
`gh` must be authed as the account that owns the fork.

## Then the Fleet side
The cask becomes an FMA only once it's **merged** (Fleet reads the public `formulae.brew.sh` API).
File the Fleet-maintained-app feature request linking the PR — body and `gh issue create` call are in
`end-to-end.md` (or use the `fleet-maintained-app-request` skill for the fuller template).
