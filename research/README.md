# App Research Directory

This directory contains research data, templates, and utilities for cask generation.

## Structure

```
research/
├── README.md                    # This file
├── apps/
│   ├── apps-registry.json      # All 500+ apps with metadata
│   ├── app-template.json       # Template for new app entries
│   └── sources.md              # How to research apps
├── cask-sources.md             # Where to find download URLs
└── examples/
    └── poll-everywhere.json    # Example fully researched app
```

## Quick Reference

### Looking up an app

```bash
# Query the registry
jq '.apps[] | select(.name == "MyApp")' research/apps/apps-registry.json

# List all apps by status
jq '.apps[] | select(.status == "ready") | .name' research/apps/apps-registry.json
```

### Adding a new app

1. Copy `apps/app-template.json`
2. Fill in all fields
3. Add to `apps/apps-registry.json`
4. Reference in `scripts/cask-master.sh`

### Research sources

See `apps/sources.md` for:
- Download URL patterns
- Version detection strategies
- Bundle ID discovery
- Common zap locations

## App Registry Schema

```json
{
  "name": "App Name",
  "vendor": "Vendor Name",
  "token": "app-name",
  "download_url": "https://example.com/download",
  "url_pattern": "Contains version number: true/false",
  "version_detection": "regex pattern or strategy",
  "bundle_id": "com.company.app",
  "min_macos": "monterey|ventura|sonoma",
  "artifact_type": "dmg|pkg|zip|tar.gz",
  "verified": "domain for verified source",
  "zap_locations": [
    "~/Library/Application Support/App",
    "~/Library/Preferences/com.company.app.plist",
    "~/Library/Caches/com.company.app"
  ],
  "notes": "Special handling, known issues, etc.",
  "status": "pending|researched|ready|duplicate|blocked",
  "research_date": "2024-06-11",
  "researched_by": "name"
}
```

## Status Meanings

- **pending**: Not yet researched
- **researched**: Research done, needs verification
- **ready**: Ready for cask generation
- **duplicate**: Already exists in Homebrew
- **blocked**: Can't be added (policy, license, etc.)

## Workflow

1. **Collect** → Build apps-registry.json with all 500+ apps
2. **Research** → Fill in metadata for each app
3. **Verify** → Double-check URLs, bundle IDs, etc.
4. **Generate** → Reference registry in cask-master.sh
5. **Validate** → Use validation scripts
6. **Submit** → Create Homebrew PRs

## See Also

- `../scripts/lib/research-utils.sh` — Helper functions to read this data
- `../docs/VALIDATION-GUIDE.md` — How to validate generated casks
- `../scripts/cask-master.sh` — How to generate casks from this data
