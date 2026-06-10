# Homebrew Cask Author Skill — Export Guide

This skill is complete and ready to share. To use it in another Claude Code session or project:

## Option 1: Direct folder copy
```bash
# From your project
cp -r .claude/skills/homebrew-cask-author /path/to/another/project/.claude/skills/
```

## Option 2: Archive for sharing
```bash
cd .claude/skills
tar -czf homebrew-cask-author-skill.tar.gz homebrew-cask-author/

# Share homebrew-cask-author-skill.tar.gz with teammates
# They extract it: tar -xzf homebrew-cask-author-skill.tar.gz -C .claude/skills/
```

## Option 3: Git submodule (for repos)
```bash
git submodule add https://github.com/AdamBaali/FMA-Homebrew-Expander.git vendor/fma-homebrew
# Then symlink: ln -s ../../vendor/fma-homebrew/.claude/skills/homebrew-cask-author .claude/skills/homebrew-cask-author
```

## What's included

- **SKILL.md** — Complete guide (single-app and batch mode workflows)
- **references/cask-dsl.md** — Homebrew Cask DSL rules and stanzas
- **references/end-to-end.md** — Single-app script template with all resolver blocks
- **references/ci-troubleshooting.md** — Common audit failures and fixes
- **references/pr-and-disclosure.md** — PR checklist and AI disclosure wording
- **references/research-sources.md** — Where to find app metadata
- **EXPORT.md** — This file

## Key improvements in this version

✅ **Batch mode fully documented** — DRYRUN=1 TEST_INSTALL=1 workflow with all flags  
✅ **Hardcoded version fix** — Script now always replaces version strings even when audit passes  
✅ **Fixed directory creation** — Subshell variable export prevents race conditions  
✅ **Accurate status reporting** — TEST_INSTALL runs now correctly marked as passing, not failed  
✅ **Per-app diagnostics** — Each run generates comprehensive report.md with full audit trail  

## Quick start in new session

1. Copy the skill folder to `.claude/skills/`
2. In Claude Code, ask: `/homebrew-cask-author` to load the skill
3. Follow SKILL.md for single-app or batch mode workflow

## For batch mode

Use the `scripts/cask-master.sh` from the FMA-Homebrew-Expander repo:

```bash
DRYRUN=1 TEST_INSTALL=1 bash scripts/cask-master.sh  # preview
bash scripts/cask-master.sh                          # submit
SKIP_PASSED=1 bash scripts/cask-master.sh           # resume
```

See SKILL.md section "Batch mode — many casks at once" for complete details.

## Contact

Questions? See the main repo: https://github.com/AdamBaali/FMA-Homebrew-Expander
