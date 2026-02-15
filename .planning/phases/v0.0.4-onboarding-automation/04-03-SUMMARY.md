---
phase: 04-onboarding-automation
plan: 03
subsystem: onboarding
tags: [scaffolding-script, bash, jq, plugin-generator, portability]

# Dependency graph
requires:
  - phase: 04-onboarding-automation
    provides: Plugin template scaffold at templates/plugin-template/ (Plan 01)
provides:
  - scripts/new-plugin.sh -- plugin scaffolding script that generates valid, high-scoring plugins from template
affects: [04-04 (CONTRIBUTING.md references new-plugin.sh)]

# Tech tracking
tech-stack:
  added: []
  patterns: [jq -n for JSON generation instead of sed on JSON, portable sed without -i flag, while/case argument parsing for Bash 3.x long options]

key-files:
  created:
    - scripts/new-plugin.sh
  modified: []

key-decisions:
  - "Used jq -n for plugin.json generation rather than sed substitution on template JSON -- avoids escaping issues and produces valid JSON by construction"
  - "Static copy of commands/example.md (no placeholder substitution) per plan spec -- users customize these files entirely"
  - "Default author from git config user.name with 'Your Name' fallback -- works in CI and local environments"
  - "Validation integrated post-scaffold to fail-fast on template bugs"

patterns-established:
  - "Scaffolding script pattern: validate input -> create dirs -> generate JSON via jq -> substitute text via sed -> validate output"
  - "Argument parsing pattern: while/case loop with shift for Bash 3.x compatible long option parsing"

# Metrics
duration: 3min
completed: 2026-02-15
---

# Phase 04 Plan 03: Plugin Scaffolding Script Summary

**new-plugin.sh scaffolding script generating 100/100-scoring plugins with input validation, jq-based JSON generation, and BSD/GNU portable text substitution**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-15T06:28:38Z
- **Completed:** 2026-02-15T06:31:10Z
- **Tasks:** 1/1
- **Files created:** 1

## Accomplishments

- Created `scripts/new-plugin.sh` that scaffolds a complete plugin from the template in under 1 second
- Generated plugins score 100/100 on the quality rubric (20/20 in all 5 categories)
- Input validation catches all invalid name patterns: uppercase, spaces, numbers-first, empty, too-long (>64 chars)
- Collision detection prevents overwriting existing plugins
- Post-scaffold validation confirms every generated plugin is valid before reporting success
- Fully portable across macOS Bash 3.2 and Linux Bash 5.x (no Bash 4+ features)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create new-plugin.sh scaffolding script** - `1ad96ce` (feat)

## Files Created/Modified

- `scripts/new-plugin.sh` - Plugin scaffolding script (199 lines, executable)

## Decisions Made

1. **jq -n for JSON generation:** Used `jq -n` with `--arg` flags to generate `plugin.json` from scratch rather than sed-substituting the template JSON. This produces valid JSON by construction and avoids shell escaping issues with special characters in descriptions.

2. **Static copy for commands/example.md:** Copied the command file without placeholder substitution as specified in the plan. The `{{PLUGIN_NAME}}` placeholder in the command's description frontmatter remains, which is consistent with the expectation that users will replace the entire command with their own.

3. **git config user.name default:** The `--author` flag defaults to `git config user.name` output, falling back to "Your Name" if git config is not set. This provides a sensible default in most development environments.

4. **Post-scaffold validation:** Integrated `validate-plugin.sh` call at the end of scaffolding to catch template bugs early. If validation fails, the script exits 1 with a message asking the user to report it as a bug.

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
| `new-plugin.sh test-scaffold-plugin` creates valid structure | PASS |
| `validate-plugin.sh plugins/test-scaffold-plugin` | PASS (exit 0) |
| `score-plugin.sh plugins/test-scaffold-plugin --json \| jq .total` | 100 (target >= 40, expected >= 90) |
| `new-plugin.sh test-custom --description "..." --author "..."` | PASS (description + author populated) |
| `new-plugin.sh "INVALID"` | Error + exit 2 |
| `new-plugin.sh "has spaces"` | Error + exit 2 |
| `new-plugin.sh "123start"` | Error + exit 2 |
| `new-plugin.sh ""` | Error + exit 2 |
| `new-plugin.sh` (no args) | Usage + exit 2 |
| Collision detection (create twice) | Error "already exists" + exit 1 |
| `run-fixture-tests.sh` | 11/11 passed |

### Level 2: Proxy (all passed)

| Check | Result |
|-------|--------|
| Generated `plugin.json` parses with `jq .` | OK |
| Agent file named with plugin prefix | `test-proxy-check-example-agent.md` |
| `--description` populates manifest | "My custom plugin" |
| `--author` populates manifest | "Test Author" |
| `--help` prints usage and exits 0 | OK |

## Next Phase Readiness

- `new-plugin.sh` is ready for Plan 04 (CONTRIBUTING.md will reference it as the recommended way to start a new plugin)
- Script works end-to-end: `./scripts/new-plugin.sh my-plugin` produces a validated, high-scoring plugin ready for customization
- All existing tests continue to pass (no regressions)

---
*Phase: 04-onboarding-automation*
*Completed: 2026-02-15*
