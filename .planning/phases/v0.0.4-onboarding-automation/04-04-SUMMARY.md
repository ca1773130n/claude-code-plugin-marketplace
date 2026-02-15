---
phase: 04-onboarding-automation
plan: 04
subsystem: onboarding
tags: [contributing-guide, documentation, onboarding, bash-scripts]

# Dependency graph
requires:
  - phase: 04-onboarding-automation
    provides: Plugin template (Plan 01), validate-local.sh (Plan 01), GitHub templates (Plan 02), new-plugin.sh (Plan 03)
provides:
  - CONTRIBUTING.md -- comprehensive contributor guide tying together all Phase 4 artifacts
affects: [new contributors, plugin submissions, onboarding flow]

# Tech tracking
tech-stack:
  added: []
  patterns: [single-source-of-truth contributor guide referencing all onboarding scripts]

key-files:
  created:
    - CONTRIBUTING.md
  modified: []

key-decisions:
  - "Structured guide in 14 sections following the contributor journey from prerequisites through PR submission"
  - "Prominently documented the dorny/paths-filter CI limitation in a callout section"
  - "Included explicit warnings about empty artifact directories (skills/, hooks/) to prevent common score deductions"
  - "Used relative links to QUALITY.md for cross-referencing within the repository"

patterns-established:
  - "Contributor onboarding pattern: prerequisites -> quick start -> detailed reference sections -> submission workflow"

# Metrics
duration: 2min
completed: 2026-02-15
---

# Phase 04 Plan 04: CONTRIBUTING.md Contributor Guide Summary

**358-line contributor guide documenting the full plugin onboarding flow from prerequisites through PR submission, referencing all Phase 4 tools (new-plugin.sh, validate-local.sh, PR template) with accurate paths**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-15T06:33:54Z
- **Completed:** 2026-02-15T06:35:56Z
- **Tasks:** 1/1
- **Files created:** 1

## Accomplishments

- Created a comprehensive 358-line CONTRIBUTING.md covering the full contributor journey in 14 structured sections
- All script references verified accurate: new-plugin.sh, validate-local.sh, validate-plugin.sh, score-plugin.sh, score-plugin.sh --json
- Documented the CI dorny/paths-filter limitation with exact YAML snippet for the filter entry
- Included quality scoring tips (empty directories, pre-1.0 version, README length) to help contributors maximize their score
- All 11 fixture tests continue to pass (no regressions)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create CONTRIBUTING.md contributor guide** - `59a9b39` (feat)

## Files Created/Modified

- `CONTRIBUTING.md` - Comprehensive contributor guide (358 lines) covering prerequisites, quick start, plugin structure, manifest fields, naming conventions, quality scoring, scaffolding, validation, PR submission, CI config, skills, hooks, and getting help

## Decisions Made

1. **14-section structure following contributor journey:** Organized from prerequisites (what you need) through quick start (10-minute path) to detailed reference sections (manifest fields, naming rules, quality scoring) to submission workflow (PR template, CI). This mirrors the natural progression of a new contributor.

2. **Prominent CI filter documentation:** The dorny/paths-filter limitation is non-obvious and critical -- without the filter entry, future PRs modifying a plugin won't trigger CI. Documented in a dedicated section with a blockquote callout and exact YAML to add.

3. **Explicit empty-directory warnings:** Mentioned the empty artifact directory penalty (Rule 18, -2 points) in both the Quality Scoring section and the Adding Skills section to prevent the most common avoidable deduction.

4. **Relative links for cross-references:** Used `[QUALITY.md](QUALITY.md)` rather than absolute URLs so links work both on GitHub and in local clones.

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
| `wc -l CONTRIBUTING.md` >= 100 | 358 lines |
| `grep "new-plugin.sh"` | PASS |
| `grep "validate-local.sh"` | PASS |
| `grep "validate-plugins.yml"` | PASS |
| `grep "QUALITY.md"` | PASS |
| `grep "score-plugin.sh"` | PASS |
| `grep "dorny/paths-filter"` | PASS |
| All referenced scripts exist | PASS (4/4 found) |
| `run-fixture-tests.sh` | 11/11 passed |

## Next Phase Readiness

- Phase 4 (Onboarding Automation) is now complete with all 4 plans executed
- The full contributor flow is in place: scaffold (new-plugin.sh) -> validate (validate-local.sh) -> submit (PR template) -> document (CONTRIBUTING.md)
- CONTRIBUTING.md ties together all Phase 4 artifacts into a single coherent onboarding guide
- Remaining deferred validations (CI triggers, GitHub template rendering) require pushing to GitHub

---
*Phase: 04-onboarding-automation*
*Completed: 2026-02-15*
