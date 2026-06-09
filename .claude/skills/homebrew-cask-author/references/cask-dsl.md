# Cask DSL reference

Stanza-by-stanza, with the patterns that matter for passing audit/CI. Authoritative source:
`https://docs.brew.sh/Cask-Cookbook`.

## Contents
- version + sha256
- url (interpolation, verified, version.csv)
- name / desc / homepage
- livecheck strategies
- depends_on (macos, arch, cask)
- artifacts: app / pkg
- uninstall (order, directives)
- zap
- Shared updaters (Microsoft AutoUpdate) — the important pattern
- Style notes

## version + sha256
- `version "1.2.3"` — exact upstream version.
- `sha256 "…"` — of the exact file at `url`.
- **`sha256 :no_check` is required whenever the `url` has no `#{version}` in it** (a stable
  "latest" download such as `https://vendor.com/app/download/app.dmg`). Audit error:
  `Use sha256 :no_check when URL is unversioned`. This is **independent of the `version` stanza**:
  you can — and for Fleet should — keep a real `version "1.2.3"` (resolved + tracked by a
  `livecheck`) alongside `sha256 :no_check`. You do **not** need `version :latest`. Only drop to
  `version :latest` when the version is also genuinely unknowable. Many vendors (Koingo, AKVIS,
  etc.) serve a fixed `app.dmg` URL but publish the version on a product page → pin the version,
  add a `:page_match` livecheck, and use `:no_check`.

## url
- Interpolate the version: `url "https://v.example/App-#{version}.pkg"`.
- `verified:` is required only when the download host's **registrable domain (eTLD+1) differs from
  the homepage's** — set it to the shortest stable prefix that proves provenance, e.g.
  `url "https://cdn.example/x/App-#{version}.pkg", verified: "cdn.example/"`.
  - **A subdomain of the homepage domain does NOT need `verified:`.** `static.culturedcode.com`
    vs homepage `culturedcode.com` share the registrable domain `culturedcode.com` → adding
    `verified:` triggers audit error *"the 'verified' parameter … is unnecessary"*. Compare the
    last two domain labels, not the full host. (`release.screen.cloud` vs `screencloud.com` →
    `screen.cloud` ≠ `screencloud.com` → verified **is** needed; S3/CloudFront hosts like
    `*.s3.amazonaws.com` / `*.cloudfront.net` almost always need it.)
  - The `verified:` string must be a real **prefix of the resolved URL** (host + `/`). `www.x.com/`
    when the URL host is `x.com` fails *"Verified URL … does not match URL …"* — derive it from the
    actual download host, not the brand domain.
- **version.csv** splits a compound version when the URL needs two numbers (e.g. a marketing
  version *and* a build):
  ```ruby
  version "4.2,3282"   # first,second
  url "https://host/App_Build-#{version.csv.second}_Version-#{version.csv.first}.dmg",
      verified: "host/"
  ```

## name / desc / homepage
- `name "Full App Name"` (human name; can repeat for aliases).
- `desc` — one line that must satisfy **every** `Cask/Desc` rule, or `brew style` (and CI) fails:
  1. **≤ 80 characters.**
  2. **No platform word** used as the platform: `macOS`, `Mac`, `OS X`, `Mac OS X`, `Windows`,
     `Linux`, or a macOS version name (`Catalina`, …). All casks are macOS, so it's redundant.
     (Edge cases the cop allows: "MAC address" — all-caps MAC; and a platform word that modifies a
     noun, e.g. "manages macOS virtual machines". When unsure, just leave the platform out.)
  3. **Doesn't start with an article** (`A`/`An`/`The`).
  4. **Doesn't start with the cask's own name/token** (e.g. cask `foo-bar` → desc can't start "Foo Bar").
  5. **No Unicode emoji or symbols.**
  6. **Starts with a capital letter.**
  7. **No trailing period.**
  Write a platform-free, capitalised phrase under 80 chars that does not lead with an article or the
  app's name, e.g. `Agent that displays custom notifications and alerts to end users`. The harness
  auto-fixes the mechanical ones (platform word, leading article, trailing period) and the ship gate
  checks `brew style` too, but get it right at authoring time.
- `homepage` — must return HTTP 200 (a 404 fails audit). Prefer the product/download page.

## livecheck
Tells Homebrew how to detect new versions. Pick the strategy that matches the source:
- `:json` — a JSON release feed. Often with a transform block to reshape the field into `version`.
- `:header_match` — follow a redirect / `Location`/filename header and regex the version out
  (common for `go.microsoft.com/fwlink` style links).
- `:sparkle` — a Sparkle appcast (`appcast.xml`); ideal when AutoPkg uses SparkleUpdateInfoProvider.
- `:page_match` — scrape a version-history/HTML page; use a block to build the version string.
```ruby
livecheck do
  url "https://vendor.example/history/"
  regex(%r{App[._-]Build-(\d+)_Version-(\d+(?:[._-]\d+)*)\.dmg}i)
  strategy :page_match do |page, regex|
    match = page.match(regex)
    next if match.blank?

    "#{match[2]},#{match[1]}"   # reassemble to match version.csv order
  end
end
```

### The `version` stanza MUST equal what livecheck returns (capture group 1)
The #1 cause of `Version 'X' differs from 'Y' retrieved by livecheck` audit failures. Homebrew
livecheck runs the regex with Ruby `String#scan` and takes **capture group 1** when the regex has
a group, else the **whole match**. So the static `version` you write must equal *that*:

- **A regex with a literal prefix returns group 1, not the whole match.** `regex(/Version (\d+(?:\.\d+)+)/)`
  on `"Version 8.0"` → livecheck returns `8.0`. If you authored `version "Version 8.0"` (e.g. by
  taking the whole `grep -o` match), it mismatches. When extracting the version yourself, take the
  **capture group**, not the whole match — mirror `scan().first`.
- **`[0-9]+(\.[0-9]+)+` is a trap.** Its only group is the *last* `.N`, so livecheck returns `.0`,
  not `8.0`. Wrap the whole version as group 1 and make inner groups non-capturing:
  **`([0-9]+(?:\.[0-9]+)+)`**. Always write the regex so group 1 is the *entire* version string.
- **Beta/build suffixes** (`0.1.0b5`): the default `:github_latest` regex stops at the first
  non-numeric and returns `0.1.0`. Supply a custom regex that captures the suffix, e.g.
  `regex(/^v?(\d+(?:\.\d+)+(?:b\d+)?)$/i)` with a `:github_latest do |json, regex| … end` block.
- A static `version` with **no** livecheck triggers `differs from '' retrieved by livecheck`
  under `--new`. Every versioned cask needs a working livecheck source.

## depends_on
- **`depends_on macos:` — required for macOS-only casks; use a BARE symbol** for a minimum:
  `depends_on macos: :big_sur` (= Big Sur or newer). `">= :big_sur"` is rewritten by the
  `Homebrew/OSDependsOn` cop and fails CI as written. Omitting it entirely makes the CI matrix
  schedule Linux runners that fail "macOS is required for this software". Symbols: `:big_sur`,
  `:monterey`, `:ventura`, `:sonoma`, `:sequoia`, `:tahoe`. Read the real floor from the app's
  `LSMinimumSystemVersion`; a conservative floor is acceptable if unknown.
- `depends_on arch: :arm64` (Apple-silicon-only) or `:x86_64`.
- **Intel-only artifact ⇒ `caveats { requires_rosetta }` is mandatory** (not optional). Audit fails
  with *"At least one artifact requires Rosetta 2 but this is not indicated by the caveats!"*.
  Detect it by inspecting the bundle's Mach-O: `lipo -archs Contents/MacOS/<CFBundleExecutable>` —
  if it lists `x86_64` (or `i386`) with no `arm64`, add the caveat. `caveats` is the **last**
  stanza, after `zap`:
  ```ruby
  caveats do
    requires_rosetta
  end
  ```
- `depends_on cask: "other-cask"` — declares another cask as a dependency (installed first). Note:
  this is **not** how shared updaters like Microsoft AutoUpdate are handled — see Shared updaters.

## artifacts
- `app "App Name.app"` — for dmg/zip casks that deliver a `.app`.
- `pkg "App Name.pkg"` — for pkg installers. (A pkg inside a dmg still uses `pkg`; Homebrew mounts
  the dmg automatically.)

## uninstall
Runs on every `brew uninstall`. It must reverse what the installer did, or CI flags leftovers.
Canonical directive order (Homebrew enforces it): `early_script`, `launchctl`, `quit`, `signal`,
`login_item`, `kext`, `script`, `pkgutil`, `delete`, `trash`, `rmdir`.
- `launchctl: "com.vendor.helper"` — unload (and remove) a launch daemon/agent the pkg installed.
  Use for the app's **own** non-shared helpers.
- `quit: "com.vendor.app"` — stop a running process. **Stops only; does not remove.** Use this for
  shared processes you must not delete.
- `pkgutil: "com.vendor.pkg.App"` — forget the receipt and remove the files it owns.
- `delete:`/`trash:` — explicit paths (prefer `pkgutil`/`launchctl` where possible).

## zap
Only runs on explicit `brew zap`. May remove resources shared with other apps — that's the user's
informed choice. Put per-app leftovers here:
```ruby
zap trash: [
  "~/Library/Application Support/com.vendor.App",
  "~/Library/Caches/com.vendor.App",
  "~/Library/HTTPStorages/com.vendor.App",
  "~/Library/Preferences/com.vendor.App.plist",
]
```

## Shared updaters (Microsoft AutoUpdate) — the important pattern
Microsoft pkg installers bundle Microsoft AutoUpdate (MAU), which is **shared** with Office, Teams,
Defender, etc. The cask DSL has no "remove only if we installed it" conditional, so removing MAU on
uninstall would break the user's other Microsoft apps. The current, CI-passing pattern (what the
live `microsoft-word`/`microsoft-excel`/`microsoft-outlook`/`microsoft-powerpoint` casks use) is to
**stop the bundled MAU sub-package from installing in the first place**, via a `pkg ... choices:`
override:

```ruby
depends_on macos: :sonoma

pkg "App_Installer_#{version}.pkg",
    choices: [
      {
        "choiceIdentifier" => "com.microsoft.autoupdate", # Office16_all_autoupdate.pkg
        "choiceAttribute"  => "selected",
        "attributeSetting" => 0,   # 0 = deselect → MAU is never installed
      },
    ]

uninstall quit:    "com.microsoft.autoupdate2",  # harmless if MAU is present from another app
          pkgutil: "com.microsoft.app"           # forget only THIS app's receipt

zap trash: [ "~/Library/.../com.microsoft.app", … ]   # only this app's data
```

Why each piece:
- `choices:` with `attributeSetting => 0` deselects the bundled AutoUpdate choice at install time, so
  MAU's launch jobs (`com.microsoft.autoupdate.helper`, `com.microsoft.update.agent`) and receipt
  (`com.microsoft.package.Microsoft_AutoUpdate.app`) are never laid down — the CI leftover check
  passes with nothing about MAU in `uninstall`, and an existing Office install's MAU is untouched.
- `uninstall quit: "com.microsoft.autoupdate2"` covers the case where MAU is already running from
  another Microsoft app; on a clean machine it's a no-op. `quit` never removes MAU.
- Do **not** put `com.microsoft.package.Microsoft_AutoUpdate.app` or MAU launchd labels in `uninstall`,
  and do **not** add `depends_on cask: "microsoft-auto-update"` — the maintainers removed that
  dependency from the Microsoft casks; the `choices:` deselect is the current approach.
- Confirm the choice id with `installer -showChoiceChangesXML -pkg <pkg> -target /` (or read the
  expanded pkg's `Distribution`); it's `com.microsoft.autoupdate` across the Office installers.

## Style notes
- Run `brew style --fix <token>` before every commit; it autocorrects most cops (including the
  bare-symbol `depends_on macos:` fix).
- Two-space indentation, double-quoted strings, trailing commas in multiline arrays.
- Align hash values within a stanza (e.g. the `quit:`/`pkgutil:` keys above) — `style --fix` does it.

---

## Additions (verified, livecheck, arch)

### `verified:` — only when hosts differ
Add `verified:` to the `url` **only when the download host differs from the homepage host**. If
they're the same domain (e.g. a GitHub-release URL with a github.com homepage), `verified:` is an
audit error — omit it. When you do use it, the value must be a real **prefix of the download URL**
(host + `/`, derived from the resolved URL — not the marketing domain).

### `:github_latest` with a compound tag
When the version needs a marketing number **and** a build (tag like `v-3.2.3-b-135` →
`version "3.2.3,135"`), reformat the tag in the strategy block:

```ruby
livecheck do
  url :url
  regex(/v-(\d+(?:\.\d+)+)-b-(\d+)/i)
  strategy :github_latest do |json, regex|
    match = json["tag_name"]&.match(regex)
    next if match.blank?

    "#{match[1]},#{match[2]}"
  end
end
```
For a plain semver GitHub tag, `strategy :github_latest` with no block is enough.

### Electron apps → `:electron_builder`
Apps that ship `latest-mac.yml` (Electron, e.g. GoTo, Groove) use that feed for livecheck:

```ruby
livecheck do
  url "https://vendor.example/path/latest-mac.yml"
  strategy :electron_builder
end
```
The yml also lists the **versioned** dmg/zip filenames — use those for `url`, not an unversioned alias.

### Two architectures, different files
When arm and intel ship as separate files, declare both shas with one `arch` mapping baked into the
filename difference:

```ruby
arch arm: "-arm64", intel: ""           # arm → App-<v>-arm64.dmg ; intel → App-<v>.dmg
version "4.18.0"
sha256 arm:   "…",
       intel: "…"
url "https://vendor.example/App-#{version}#{arch}.dmg"
```
A single universal download needs none of this — one `sha256` and a plain `url`.
