# START HERE — Quick Setup & Usage

## 🎯 What You Have

A professional Homebrew cask generator with:
- ✅ Research registry for 500+ apps
- ✅ End-to-end validation (17 phases)
- ✅ Duplicate detection
- ✅ Filesystem monitoring (zero guessing)
- ✅ Local testing before submission
- ✅ All scripts organized and ready to run

## 🚀 Run Everything Locally in 3 Steps

### Step 1: Navigate to Project

```bash
cd /Users/adam/Documents/GitHub/FMA-Homebrew-Expander
```

### Step 2: Run Validation

```bash
# Validate all 20 open PRs (takes 60-90 minutes)
bash validation/validate-all-prs.sh
```

That's it! The script will:
1. Generate casks for all apps
2. Test each one locally
3. Check for duplicates
4. Monitor file creation
5. Test installation/uninstallation
6. Verify zap cleanup
7. Generate detailed reports

### Step 3: Check Results

```bash
# See the summary
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/SUMMARY.md
```

Shows which apps are:
- ✅ Ready (pass all checks)
- ⚠️ Need review (minor issues to fix)
- ❌ Failed (critical issues)

## 📋 What Gets Checked

**17 Validation Phases:**
1. Cask generation
2. Duplicate detection (vs 14k+ Homebrew casks)
3. System state before app install
4. App installation
5. App launch and user interaction
6. System state after install
7. Filesystem changes captured
8. Zap stanza verified against changes
9. Code style check
10. Homebrew audit check
11. Livecheck (auto-update) validation
12. App metadata (bundle ID, min macOS)
13. Uninstall test
14. Reinstall test (idempotency)
15. Zap cleanup verification
16-17. Plus 2 more checks

**Plus:** 8 code quality checks

## 🔍 Quick Commands

| Task | Command |
|------|---------|
| Validate everything | `bash validation/validate-all-prs.sh` |
| Test one app | `bash validation/end-to-end-validate.sh poll-everywhere` |
| Check code quality | `bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb` |
| Auto-fix issues | `bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb` |
| Find duplicates | `bash validation/check-duplicates.sh ~/caskwork/<app>/<app>.rb` |
| Query app registry | `bash scripts/lib/research-utils.sh stats` |
| Check specific app | `bash scripts/lib/research-utils.sh info poll-everywhere` |

## 📚 Documentation

**For different needs:**

| Want to... | Read... |
|-----------|---------|
| Get started in 5 min | `docs/QUICKSTART.txt` |
| See practical examples | `README-WORKFLOW.md` |
| Understand all 17 phases | `docs/E2E-CHECKS.md` |
| Learn validation system | `docs/VALIDATION-GUIDE.md` |
| Deep dive on research | `research/README.md` |
| See validation details | `validation/README.md` |

## 🎬 Example Workflow

### First Time: Test One App

```bash
# Try on poll-everywhere first
bash validation/end-to-end-validate.sh poll-everywhere

# You'll see:
# [1/5] Generating cask...
# [2/5] Review the generated cask...
# [3/5] Installing app...
# [4/5] Opening app (interact for 1-2 minutes)
# [5/5] Uninstalling and verifying...

# Check results
cat ~/caskwork/e2e-reports/poll-everywhere-validation.md
```

### Then: Run All 20

```bash
# Full batch validation
bash validation/validate-all-prs.sh

# Takes 60-90 minutes, generates detailed reports for each app
```

### Fix Issues

```bash
# See what needs fixing
bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb

# Auto-fix common issues
bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb

# Fix complex issues manually
vim ~/caskwork/<app>/<app>.rb

# Re-validate
bash validation/end-to-end-validate.sh <app>
```

### Submit

```bash
# Once validated, submit all casks
bash scripts/cask-master.sh
```

## 📁 Directory Structure

```
FMA-Homebrew-Expander/
├── validation/              ← RUN FROM HERE
│   ├── validate-all-prs.sh  ← MAIN COMMAND
│   ├── end-to-end-validate.sh
│   ├── analyze-cask.sh
│   ├── cask-fixer.sh
│   └── README.md
│
├── research/                ← App metadata (500+ apps)
│   ├── apps/
│   │   ├── apps-registry.json
│   │   ├── app-template.json
│   │   └── examples.json
│   └── README.md
│
├── scripts/
│   ├── cask-master.sh       ← Cask generation
│   └── lib/
│       └── research-utils.sh ← Query research data
│
├── docs/                    ← Documentation
│   ├── QUICKSTART.txt
│   ├── VALIDATION-GUIDE.md
│   ├── E2E-CHECKS.md
│   └── ...
│
├── data/
│   └── master-list.csv      ← Status tracking
│
└── README-WORKFLOW.md       ← Complete guide
```

## ⚡ One-Liner Commands

```bash
# Validate everything
bash validation/validate-all-prs.sh

# Just one app
bash validation/end-to-end-validate.sh poll-everywhere

# Just check quality
bash validation/analyze-cask.sh ~/caskwork/<app>/<app>.rb

# Auto-fix
bash validation/cask-fixer.sh ~/caskwork/<app>/<app>.rb

# See results
cat ~/caskwork/validation-YYYYMMDD-HHMMSS/SUMMARY.md
```

## 🎯 Success Criteria

A cask is **production-ready** when:

```
Checks passed: 17 / 17
Issues:      0
Warnings:    0
Status: ✓ READY FOR SUBMISSION
```

## ❓ Troubleshooting

### "Permission denied"
```bash
chmod +x validation/*.sh scripts/lib/*.sh
```

### "jq not found"
```bash
brew install jq
```

### "Script not found"
```bash
cd /Users/adam/Documents/GitHub/FMA-Homebrew-Expander
ls -la validation/
```

### Low disk space
```bash
rm -rf ~/caskwork/validation-*
```

## 🏃 Time Estimates

| Task | Time |
|------|------|
| One app validation | 5-10 min |
| All 20 apps | 60-90 min |
| Quality analysis | 30 sec |
| Auto-fix common issues | 1 min |
| Duplicate check | 30 sec |
| Fix/re-validate one app | 5-15 min |
| Submit all | 15 min |

## 📝 Git Integration

```bash
# After validation, save results
git add -A
git commit -m "Validation run for 20 PRs"
git push origin main

# Or create separate branch
git checkout -b validation-2024-06
git add validation-results/
git commit -m "Validation results"
git push origin validation-2024-06
```

## 📞 Next Steps

1. **Read this file** ← You are here (2 min)
2. **Run the script** — `bash validation/validate-all-prs.sh` (60-90 min)
3. **Check results** — `cat ~/caskwork/validation-*/SUMMARY.md` (5 min)
4. **Fix issues** — Use analysis script and manual editing (variable)
5. **Submit** — `bash scripts/cask-master.sh` (15 min)

---

## 📖 Full Documentation

- **README-WORKFLOW.md** — Complete workflow guide
- **docs/QUICKSTART.txt** — Quick reference card
- **docs/VALIDATION-GUIDE.md** — Detailed usage guide
- **research/README.md** — App registry documentation
- **validation/README.md** — Validation system details

---

**Ready to start?**

```bash
bash validation/validate-all-prs.sh
```

That's all you need. The system will handle the rest. ✨
