---
phase: 04-onboarding-automation
plan: 02
subsystem: infra
tags: [github-templates, issue-forms, pr-templates, onboarding]

requires:
  - phase: 03-quality-gates
    provides: quality scoring scripts referenced in PR template checklist
provides:
  - YAML issue form for structured plugin requests
  - PR template with 10-item pre-submission checklist and CI reminder
affects: [04-onboarding-automation, contributing-guide]

tech-stack:
  added: [github-yaml-issue-forms]
  patterns: [structured-issue-intake, submission-checklist]

key-files:
  created:
    - .github/ISSUE_TEMPLATE/plugin-request.yml
    - .github/PULL_REQUEST_TEMPLATE/plugin-submission.md

key-decisions:
  - "Used YAML issue form format (not Markdown) for plugin requests to enforce required fields and dropdowns"
  - "PR template references validate-local.sh which will be created in a separate plan within this phase"

patterns-established:
  - "GitHub YAML forms for structured community input with required field validation"
  - "PR checklist pattern covering validation, scoring, documentation, and CI configuration"

duration: 2min
completed: 2026-02-15
---

# Phase 04 Plan 02: GitHub Issue & PR Templates Summary

**YAML issue form with 6 structured fields and PR template with 10-item submission checklist standardizing the plugin contribution flow.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-15T06:23:33Z
- **Completed:** 2026-02-15T06:25:11Z
- **Tasks:** 2/2 completed
- **Files created:** 2

## Accomplishments

- Created YAML-based GitHub issue form with input validation, dropdown categories, and required field enforcement for plugin requests
- Created Markdown PR template with comprehensive 10-item pre-submission checklist covering validation, scoring, documentation, and CI setup
- Both templates reference the correct scripts (validate-local.sh, score-plugin.sh) and CI workflow (validate-plugins.yml)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create YAML issue form for plugin requests** - `0e9460d` (feat)
2. **Task 2: Create PR template for plugin submissions** - `286aa0c` (feat)

## Files Created/Modified

- `.github/ISSUE_TEMPLATE/plugin-request.yml` - YAML issue form with 6 body fields: 2 inputs, 2 textareas, 1 dropdown, 1 checkboxes
- `.github/PULL_REQUEST_TEMPLATE/plugin-submission.md` - PR template with summary, plugin details, 10-item checklist, CI note, and testing section

## Decisions Made

1. **YAML form format over Markdown issue template** - YAML forms allow `type: input` with `required: true`, `type: dropdown` for categories, and `type: checkboxes` with per-option required flags. Markdown templates lack these validation capabilities.
2. **PR template references validate-local.sh before it exists** - The script is planned for creation in another plan within phase 04. The PR template serves as documentation of the expected workflow even before all scripts exist.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Issue and PR templates are ready for use once pushed to main branch on GitHub
- Templates will render correctly once GitHub processes the `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE/` directories
- Deferred verification: actual rendering on GitHub requires push (added to deferred validations)

---
*Phase: 04-onboarding-automation*
*Completed: 2026-02-15*
