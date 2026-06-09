# Claude Code skills

Project skills for this repo. Claude Code (including web sessions) auto-discovers any
`SKILL.md` under `.claude/skills/<name>/`, so dropping a skill here makes it available to
the agent driving the no-homebrew-cask workflow. This replaces the old
`/mnt/skills/user/...` mount the handoff doc referenced — skills now live **in the repo**.

## Installed

| Skill | Purpose | Status |
|---|---|---|
| `homebrew-cask-author/` | Research, author, validate, and submit a Homebrew Cask end-to-end (one runnable script), then file the matching Fleet FMA request. Drives `scripts/cask-master.sh`. | ✅ installed |

## Expected but not yet provided

| Skill | Purpose | Status |
|---|---|---|
| `fleet-maintained-app-request` | Fuller template for the Fleet-maintained-app feature request. | ⏳ pending upload — for now the FR flow is inlined in `homebrew-cask-author/references/end-to-end.md` (and summarised in `pr-and-disclosure.md`). |
| `winget-manifest-author` | Author winget manifests (Windows side). | ⏳ pending upload — not required for the macOS cask backlog. |

Drop a skill in as `.claude/skills/<name>/SKILL.md` (plus any `references/`) and it will be
picked up automatically.
