---
phase: 05-integration-hardening
plan: 01
subsystem: testing
tags: [bash, exit-codes, cli-ux, posix]

# Dependency graph
requires:
  - phase: 04-onboarding-automation
    provides: validate-local.sh and run-fixture-tests.sh scripts
provides:
  - Consistent --help exit 0 across all 7 scripts
  - Consistent exit 2 on unknown arguments across all 7 scripts
  - usage() function in run-fixture-tests.sh
affects: [05-03 self-test workflow, CI compliance checks]

# Tech tracking
tech-stack:
  added: []
  patterns: [usage-function-exit-0, separate-help-from-error, argument-rejection-loop]

key-files:
  created: []
  modified:
    - scripts/validate-local.sh
    - scripts/run-fixture-tests.sh

key-decisions:
  - "Separated no-args error from --help in validate-local.sh: no-args prints brief error pointing to --help and exits 2, while --help calls usage() which exits 0"
  - "run-fixture-tests.sh rejects ALL arguments (flags and positional) since it takes no arguments; only --help/-h is accepted"

patterns-established:
  - "usage() exits 0: All scripts follow POSIX convention where --help is informational, not an error"
  - "Error-to-help pointer: Missing/invalid args print error to stderr with 'Run ... --help' suggestion, then exit 2"

# Metrics
duration: 2min
completed: 2026-02-15
---

# Phase 5 Plan 01: Exit Code and --help Compliance Summary

**Hardened exit codes across validate-local.sh and run-fixture-tests.sh: all 7 scripts now exit 0 on --help and exit 2 on unknown arguments**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-15T07:07:56Z
- **Completed:** 2026-02-15T07:09:57Z
- **Tasks:** 2/2 completed
- **Files modified:** 2

## Accomplishments

- Fixed validate-local.sh to exit 0 on --help (was incorrectly exiting 2) and separated the no-args error case to exit 2 with a helpful message
- Added complete --help support and argument rejection to run-fixture-tests.sh, which previously had no argument handling at all
- All 7 scripts in scripts/ now conform to consistent exit code conventions: 0 for --help, 2 for usage errors
- All 11 fixture tests continue to pass with no regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix validate-local.sh --help exit code** - `f749279` (fix)
2. **Task 2: Add --help support and argument rejection to run-fixture-tests.sh** - `51834fb` (feat)

## Files Created/Modified

- `scripts/validate-local.sh` - Changed usage() exit from 2 to 0; replaced no-args usage() call with explicit error message pointing to --help, exiting 2
- `scripts/run-fixture-tests.sh` - Added usage() function with test coverage description and argument parsing loop that rejects all arguments except --help/-h

## Decisions Made

1. **Separated no-args from --help in validate-local.sh:** Rather than having both paths call the same usage() function (which would make no-args exit 0 after the fix), the no-args case now prints a brief error to stderr with a pointer to --help, then exits 2. This matches the pattern used by new-plugin.sh and score-plugin.sh.

2. **Catch-all argument rejection for run-fixture-tests.sh:** Since the script takes no arguments at all, the argument parsing loop uses a wildcard `*` case to reject both unknown flags (--badarg) and positional arguments (foo) with the same error message and exit 2.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 7 scripts now have consistent --help and error handling behavior
- Ready for Plan 05-03 (self-test workflow) which will verify --help compliance as part of CI
- No blockers identified

## Self-Check: PASSED

All files verified present, both task commits confirmed in git log.

---
*Phase: 05-integration-hardening*
*Completed: 2026-02-15*
