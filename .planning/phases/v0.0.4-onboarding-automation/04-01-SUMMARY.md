---
phase: 04-onboarding-automation
plan: 01
subsystem: onboarding
tags: [plugin-template, scaffold, validation, bash]

# Dependency graph
requires:
  - phase: 03-quality-gates
    provides: score-plugin.sh quality rubric and validate-plugin.sh validation pipeline
provides:
  - Plugin template scaffold at templates/plugin-template/ (7 files, 100/100 quality score)
  - validate-local.sh wrapper script for contributor pre-PR validation
affects: [04-02 (scaffold script uses template), 04-03 (new-plugin.sh copies template)]

# Tech tracking
tech-stack:
  added: []
  patterns: [maximalist plugin template for high quality baseline, validation wrapper pattern]

key-files:
  created:
    - templates/plugin-template/.claude-plugin/plugin.json
    - templates/plugin-template/agents/example-plugin-example-agent.md
    - templates/plugin-template/commands/example.md
    - templates/plugin-template/CLAUDE.md
    - templates/plugin-template/README.md
    - templates/plugin-template/CHANGELOG.md
    - templates/plugin-template/VERSION
    - scripts/validate-local.sh
  modified: []

key-decisions:
  - "Used placeholder URLs (https://github.com/YOUR-USERNAME/example-plugin) instead of empty strings to avoid -2 homepage/-2 repository deductions"
  - "Omitted skills/ directory entirely (no empty artifact directories = no Rule 18 deduction)"
  - "Used 1.0.0 version to avoid pre-1.0 deduction, matching VERSION file for Rule 28"
  - "Agent file named example-plugin-example-agent.md to establish plugin-name prefix convention"

patterns-established:
  - "Template scaffold pattern: complete plugin with all optional fields populated for maximum quality score"
  - "validate-local.sh pattern: validation + scoring wrapper with clear exit codes (0=pass, 1=fail, 2=usage)"

# Metrics
duration: 2min
completed: 2026-02-15
---

# Phase 04 Plan 01: Plugin Template Scaffold Summary

**Complete plugin template scoring 100/100 with validate-local.sh wrapper for contributor pre-PR validation**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-15T06:23:36Z
- **Completed:** 2026-02-15T06:26:24Z
- **Tasks:** 2/2
- **Files created:** 8

## Accomplishments

- Created a complete plugin template at `templates/plugin-template/` that scores a perfect 100/100 on the quality rubric -- 20/20 in every category (Manifest Completeness, Documentation, Structure Integrity, Naming Conventions, Version Hygiene)
- Built `validate-local.sh` wrapper that gives contributors a single command to run validation + scoring before submitting a PR
- Template passes schema validation and all structural checks out of the box
- README.md has 119 lines (well above the 50-line threshold for Rule 11)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create plugin template directory with all scaffold files** - `3da71e9` (feat)
2. **Task 2: Create validate-local.sh wrapper script** - `cdd4d8a` (feat)

## Files Created/Modified

- `templates/plugin-template/.claude-plugin/plugin.json` - Complete plugin manifest with all optional fields
- `templates/plugin-template/agents/example-plugin-example-agent.md` - Example agent with plugin-name prefix convention
- `templates/plugin-template/commands/example.md` - Example command demonstrating markdown command format
- `templates/plugin-template/CLAUDE.md` - Development guidance with placeholder sections
- `templates/plugin-template/README.md` - 119-line README with full documentation sections
- `templates/plugin-template/CHANGELOG.md` - Initial 1.0.0 changelog entry
- `templates/plugin-template/VERSION` - Version file (1.0.0, matches plugin.json)
- `scripts/validate-local.sh` - Local validation wrapper (validation + scoring)

## Decisions Made

1. **Placeholder URLs over empty strings:** Used `https://github.com/YOUR-USERNAME/example-plugin` for homepage and repository fields. Empty strings trigger `-2` deductions each (Rules 4-5 use `jq -r '.field // empty'` which treats empty string as falsy). Placeholder URLs avoid this while being clearly substitutable.

2. **No skills/ directory:** Research identified that empty artifact directories incur a `-2` deduction (Rule 18). Since skills are uncommon (only 1 of 2 existing plugins uses them), the template omits skills/ entirely.

3. **Version 1.0.0 as default:** Chose `1.0.0` over `0.1.0` to avoid the `-2` pre-1.0 deduction (Rule 27). Contributors who prefer pre-release versioning can change it at a 2-point cost.

4. **Static template with placeholders:** Used `{{PLUGIN_NAME}}` and `{{PLUGIN_DESCRIPTION}}` placeholders in non-JSON files (CLAUDE.md, README.md, CHANGELOG.md, commands, agents). The plugin.json uses literal `example-plugin` since Plan 03's `new-plugin.sh` will generate it via `jq` rather than `sed`-substituting it.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Verification Results

### Level 1: Sanity (all passed)

| Check | Result |
|-------|--------|
| `validate-plugin.sh templates/plugin-template` | PASS (exit 0) |
| `score-plugin.sh templates/plugin-template --json \| jq .total` | 100 (target >= 90) |
| `validate-local.sh plugins/GRD` | PASS (exit 0) |
| `validate-local.sh plugins/multi-cli-harness` | PASS (exit 0) |
| `validate-local.sh templates/plugin-template` | PASS (exit 0) |
| `validate-local.sh` (no args) | Usage printed, exit 2 |
| `validate-local.sh /nonexistent` | Error printed, exit 2 |
| `run-fixture-tests.sh` | 11/11 passed |

### Level 2: Proxy (all passed)

| Check | Result |
|-------|--------|
| README.md >= 50 lines | 119 lines |
| plugin.json valid JSON | OK |
| Agent uses `example-plugin-` prefix | `example-plugin-example-agent.md` |
| validate-local.sh edge cases | Correct exit codes |

## Next Phase Readiness

- Template is ready for Plan 02 (GitHub Issue/PR templates) and Plan 03 (`new-plugin.sh` scaffolding script)
- `validate-local.sh` can be referenced in CONTRIBUTING.md (Plan 04)
- Template structure establishes the pattern that `new-plugin.sh` will copy and customize

---
*Phase: 04-onboarding-automation*
*Completed: 2026-02-15*
