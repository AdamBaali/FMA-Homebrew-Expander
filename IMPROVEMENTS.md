# Cask Generation Process Improvements

This document describes the enhancements made to `scripts/cask-master.sh` to address common Homebrew cask audit failures and improve the quality of generated casks.

**Version:** Updated with batch limiting, duplicate PR prevention, and improved autofix capabilities.

## Key Features

### 🚀 Batch Processing (NEW)
Safely process apps in controlled batches to avoid overwhelming Homebrew and Fleet:
- `BATCH_SIZE=10` (default) — processes up to 10 apps per run
- `BATCH_SIZE=0` — no limit (process all selected apps)
- Perfect for testing before large-scale runs

### 🛡️ Duplicate PR Prevention (NEW)
Prevents accidental duplicate PR creation:
- `SKIP_OPEN_PR=1` — automatically skips apps with open PRs
- Prevents "double submission" when re-running with updates
- Logs exact PR URL when skipping

## Problems Addressed

### 1. Deprecated `depends_on macos:` Syntax
**Problem:** When a cask uses `on_arm`/`on_intel` architecture-specific blocks, Homebrew 5.x deprecates the top-level `depends_on macos: :symbol` syntax.

**Deprecation Warning:**
```
Warning: Calling `depends_on :macos` with `depends_on macos:` is deprecated!
Use `depends_on :macos` with `depends_on macos:` inside an `on_macos` block instead.
```

**Solution:** The new `fix_depends_on_syntax()` function detects this pattern and moves the `depends_on` line into each architecture-specific block where it belongs.

### 2. Hardcoded Version Strings in Filenames
**Problem:** Some casks use hardcoded version numbers in filenames instead of using the `#{version}` variable.

**Example (before):**
```ruby
pkg "Escrow.Buddy-1.0.0.pkg"
```

**Example (after):**
```ruby
pkg "Escrow.Buddy-#{version}.pkg"
```

**Benefit:** Using `#{version}` ensures the filename automatically updates when the cask version is bumped, reducing maintenance overhead.

### 3. Basic Zap Stanzas
**Problem:** The default `zap_for()` function only generates a minimal trash stanza based on the bundle ID, missing many app-specific cleanup locations.

**Current (basic):**
```ruby
zap trash: [
  "~/Library/Caches/org.herf.Flux",
  "~/Library/HTTPStorages/org.herf.Flux",
  "~/Library/Preferences/org.herf.Flux.plist",
  "~/Library/Saved Application State/org.herf.Flux.savedState",
]
```

**Improved (with brew generate-zap):**
```ruby
zap trash: [
  "~/Library/Application Support/Flux",
  "~/Library/Caches/org.herf.Flux",
  "~/Library/Containers/com.justgetflux.flux",
  "~/Library/Cookies/org.herf.Flux.binarycookies",
  "~/Library/Preferences/org.herf.Flux.plist",
]
```

---

## Batch Processing & Duplicate Prevention

### BATCH_SIZE Flag
Limits the number of apps processed in a single run to avoid flooding Homebrew and Fleet with requests.

**Default:** `BATCH_SIZE=10` (safe default for testing)

**Usage:**
```bash
# Process first 10 apps only (default, safe for testing)
DRYRUN=1 bash scripts/cask-master.sh

# Process first 5 apps (smaller batch for testing)
DRYRUN=1 BATCH_SIZE=5 bash scripts/cask-master.sh

# Process all selected apps (no limit)
BATCH_SIZE=0 bash scripts/cask-master.sh

# Combine with ONLY to process specific apps
BATCH_SIZE=0 ONLY="escrow-buddy pique icons" bash scripts/cask-master.sh
```

**Behavior:**
- Stops processing after N apps are queued (respects other filters like ONLY, START_AT, LIMIT)
- Each subsequent run processes the next batch of apps
- Works with SKIP_PASSED=1 to resume from failures
- Perfect for staged rollouts:
  1. Run 1: BATCH_SIZE=10 (test first 10)
  2. Run 2: BATCH_SIZE=10 SKIP_PASSED=1 (process next 10)
  3. Run 3: BATCH_SIZE=0 (finish remaining)

### SKIP_OPEN_PR Flag
Automatically skips apps that already have an open PR to prevent duplicate submissions.

**Default:** `SKIP_OPEN_PR=0` (allow re-running to update PRs)

**Usage:**
```bash
# Skip apps with open PRs (safe for re-running with updates)
SKIP_OPEN_PR=1 bash scripts/cask-master.sh

# Allow re-testing and updating existing PRs
bash scripts/cask-master.sh  # SKIP_OPEN_PR=0 (default)
```

**Behavior:**
- When enabled, checks Homebrew GitHub for open PRs before processing
- Skips apps with existing PRs and logs the PR URL
- Does NOT skip in DRYRUN mode (preview mode always runs all apps)
- Prevents accidental double-submission

**Practical workflow:**
```bash
# First run: create initial batch
DRYRUN=1 BATCH_SIZE=10 bash scripts/cask-master.sh
# Review results, then:
bash scripts/cask-master.sh

# Later: re-run to push updates to existing PRs
bash scripts/cask-master.sh  # Updates existing PRs, creates new ones for failures

# To avoid updating existing PRs:
SKIP_OPEN_PR=1 bash scripts/cask-master.sh  # Only processes apps without PRs
```

---

## New Functions

### `zap_for_auto(bundle_id)`
Generates comprehensive zap stanzas using Homebrew's built-in `brew generate-zap` command.

**Requirements:**
- macOS with Homebrew installed
- The application must be installed on the system
- Homebrew `generate-zap` command available

**Usage:**
```bash
zap_for_auto "com.justgetflux.flux"
```

**Behavior:**
- Attempts to use `brew generate-zap <bundle_id>` first
- Falls back to `zap_for()` if `generate-zap` is unavailable or fails
- Always returns a valid zap stanza

**Note:** This function requires the app to be installed at run time to gather comprehensive cleanup paths. The standard `zap_for()` remains available as a fallback.

### `fix_hardcoded_versions(cask_file)`
Replaces hardcoded version strings in `pkg` and `app` filenames with the `#{version}` template variable.

**How it works:**
1. Extracts the version from `$VERSION` environment variable
2. Escapes special regex characters in the version string
3. Finds all occurrences of that version in pkg/app filenames
4. Replaces them with `#{version}`

**Example:**
- Input: `pkg "Escrow.Buddy-1.0.0.pkg"`
- Output: `pkg "Escrow.Buddy-#{version}.pkg"`

**Automatic Detection:**
The `autofix()` function automatically calls this when it detects pkg/app stanzas with version numbers in filenames.

### `fix_depends_on_syntax(cask_file)`
Fixes the deprecated `depends_on macos:` syntax when used with architecture-specific blocks.

**Problem it solves:**
```ruby
# ❌ DEPRECATED: depends_on at top level with architecture blocks
on_arm do
  sha256 "..."
  url "..."
end
on_intel do
  sha256 "..."
  url "..."
end
depends_on macos: :monterey  # ❌ Wrong position
```

**After fix:**
```ruby
# ✅ CORRECT: depends_on moved into each block
on_arm do
  sha256 "..."
  url "..."
  depends_on macos: :monterey
end
on_intel do
  sha256 "..."
  url "..."
  depends_on macos: :monterey
end
```

**Automatic Detection:**
The `autofix()` function automatically calls this when Homebrew's audit detects the deprecated syntax warning.

---

## Integration with `autofix()`

All three improvements are integrated into the existing `autofix()` function, which is called automatically after `brew audit`:

```bash
# Fix deprecated depends_on syntax (detected by brew audit warning)
if printf '%s' "$a" | grep -qiE 'Calling.*depends_on.*deprecated|should use.*on_macos block'; then
  fix_depends_on_syntax "$CASK"
  AUTOFIX+="fixed deprecated depends_on :macos syntax; "
fi

# Fix hardcoded versions (detected by grep)
if grep -qE '^\s*(pkg|app)\s+"[^"]*-[0-9]' "$CASK"; then
  fix_hardcoded_versions "$CASK"
  AUTOFIX+="replaced hardcoded versions with #{version}; "
fi
```

---

## Usage

### Standard workflow (no changes needed)
The improvements are automatically applied during the normal cask generation process:

```bash
DRYRUN=1 bash scripts/cask-master.sh
```

Auto-fixes are applied automatically:
1. After `brew style --fix`
2. After `brew audit --strict --online --new`
3. Improvements are logged in the `AUTOFIX` variable and reported in results

### Optional: Using enhanced zap stanzas
To use `brew generate-zap` for richer zap stanzas on macOS:

1. Install the app through the normal workflow
2. After initial cask generation, manually run:
```bash
brew generate-zap <bundle_id>
```

3. Copy the output into the cask's `zap` stanza

Or integrate it into the workflow by uncommenting the `zap_for_auto()` call in custom `write_cask_*` functions (requires app to be installed).

---

## Examples

### Example 1: Escrow Buddy (hardcoded version fix)

**Before:**
```ruby
cask "escrow-buddy" do
  version "1.0.0"
  sha256 "abc123..."
  url "https://github.com/macadmins/escrow-buddy/releases/download/v1.0.0/Escrow.Buddy-1.0.0.pkg"
  
  pkg "Escrow.Buddy-1.0.0.pkg"
  uninstall pkgutil: "com.macadmins.escrow-buddy"
end
```

**After autofix:**
```ruby
cask "escrow-buddy" do
  version "1.0.0"
  sha256 "abc123..."
  url "https://github.com/macadmins/escrow-buddy/releases/download/v1.0.0/Escrow.Buddy-#{version}.pkg"
  
  pkg "Escrow.Buddy-#{version}.pkg"
  uninstall pkgutil: "com.macadmins.escrow-buddy"
end
```

### Example 2: Architecture-specific cask (depends_on fix)

**Before:**
```ruby
cask "barcode-studio" do
  version "17.2.0.32089"
  
  on_arm do
    sha256 "abc..."
    url "https://www.tec-it.com/download/Unix/Mac-OS/bcstudio-#{version}-mac-12.0-arm64.pkg.zip"
  end
  on_intel do
    sha256 "def..."
    url "https://www.tec-it.com/download/Unix/Mac-OS/bcstudio-#{version}-mac-11.0.pkg.zip"
  end
  
  depends_on macos: :monterey  # ❌ Wrong position - brew audit warns
end
```

**After autofix:**
```ruby
cask "barcode-studio" do
  version "17.2.0.32089"
  
  on_arm do
    sha256 "abc..."
    url "https://www.tec-it.com/download/Unix/Mac-OS/bcstudio-#{version}-mac-12.0-arm64.pkg.zip"
    depends_on macos: :monterey
  end
  on_intel do
    sha256 "def..."
    url "https://www.tec-it.com/download/Unix/Mac-OS/bcstudio-#{version}-mac-11.0.pkg.zip"
    depends_on macos: :monterey
  end
end
```

### Example 3: Better zap stanza (brew generate-zap)

**Before (heuristic):**
```ruby
zap trash: [
  "~/Library/Caches/org.herf.Flux",
  "~/Library/HTTPStorages/org.herf.Flux",
  "~/Library/Preferences/org.herf.Flux.plist",
  "~/Library/Saved Application State/org.herf.Flux.savedState",
]
```

**After (brew generate-zap):**
```ruby
zap trash: [
  "~/Library/Application Support/Flux",
  "~/Library/Caches/org.herf.Flux",
  "~/Library/Containers/com.justgetflux.flux",
  "~/Library/Cookies/org.herf.Flux.binarycookies",
  "~/Library/Preferences/org.herf.Flux.plist",
]
```

---

## Testing the Improvements

### Dry-run with improvements
Test the improved process without pushing changes:

```bash
DRYRUN=1 bash scripts/cask-master.sh
```

Check the report for applied fixes:
```bash
cat /tmp/caskwork/MASTER-summary.md | grep -i "autofix\|deprecated\|hardcoded"
```

### Per-app testing
Test a specific app with all improvements:

```bash
DRYRUN=1 ONLY="escrow-buddy" bash scripts/cask-master.sh
```

Review the full report:
```bash
cat /tmp/caskwork/escrow-buddy/report.md
```

### Check what was fixed
The autofix log is included in each app's report:
```bash
grep "AUTOFIX:" /tmp/caskwork/*/report.md
```

---

## Technical Details

### Regex Patterns Used

**Version detection in filenames:**
```bash
grep -qE '^\s*(pkg|app)\s+"[^"]*-[0-9]'
```
Finds any pkg or app stanza with a hyphen followed by a digit (likely a version number).

**Deprecated depends_on detection:**
```bash
'Calling.*depends_on.*deprecated|should use.*on_macos block'
```
Matches Homebrew's audit warning messages.

### Perl-based Transformations

All fixes use Perl regex for reliable, multi-line transformations:

- **Version string replacement:** Uses character escaping for special regex chars
- **Depends_on moving:** Uses non-greedy matching to isolate architecture blocks
- **String substitution:** Preserves indentation and formatting

---

## Compatibility

- ✅ Works with existing casks generated before these improvements
- ✅ Backward compatible with `zap_for()` fallback
- ✅ Safe to run multiple times (fixes are idempotent)
- ✅ Works on macOS with Homebrew (all platforms for dry-runs)
- ✅ Compliant with Homebrew 5.x+ audit standards

---

## Future Enhancements

Potential improvements for future versions:

1. **Automatic app installation for `zap_for_auto()`**
   - Auto-install the app temporarily during cask generation
   - Clean up after extracting zap stanza

2. **Smart version detection**
   - Detect version patterns in URLs and filenames
   - Automatically suggest `#{version}` replacements in specs

3. **Architecture detection**
   - Auto-detect when a cask needs both arm64 and x86_64 versions
   - Suggest splitting into architecture blocks

4. **More Homebrew audit auto-fixes**
   - Fix other common audit issues detected by Homebrew
   - Expand the autofix catalog

---

## Support

For issues with the improved cask generation process:

1. Check `/tmp/caskwork/<token>/report.md` for detailed logs
2. Review `/tmp/caskwork/MASTER-summary.md` for a rollup view
3. Test with `DRYRUN=1` to preview changes before applying
4. Use `LIVECHECK=0` for faster iteration during development

---

**Last updated:** 2026-06-10
**Script version:** Includes zap_for_auto, fix_hardcoded_versions, fix_depends_on_syntax
