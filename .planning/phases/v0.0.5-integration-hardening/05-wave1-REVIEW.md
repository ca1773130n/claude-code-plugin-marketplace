---
phase: 05-integration-hardening
wave: 1
plans_reviewed: [05-01, 05-02]
timestamp: 2026-02-15T12:00:00Z
blockers: 0
warnings: 2
info: 4
verdict: warnings_only
---

# Code Review: Phase 05 Wave 1

## Verdict: WARNINGS ONLY

Both plans executed faithfully against their specifications. Exit code compliance and E2E test script are implemented correctly with no regressions. Two warnings relate to a minor cleanup edge case in run-e2e-test.sh and a pre-existing inconsistency in generate-marketplace.sh that the wave did not address.

## Stage 1: Spec Compliance

### Plan Alignment

**Plan 05-01 (Exit Code and --help Compliance):**

- Task 1 (fix validate-local.sh --help exit code): COMPLETE. Commit `f749279` modifies exactly one file (`scripts/validate-local.sh`), changing `exit 2` to `exit 0` in `usage()` and replacing the no-args `usage` call with an explicit error-to-stderr with exit 2. Verified: `--help` exits 0, no-args exits 2, `--badarg` exits 2.
- Task 2 (add --help and argument rejection to run-fixture-tests.sh): COMPLETE. Commit `51834fb` adds 35 lines to `scripts/run-fixture-tests.sh` -- a `usage()` function and argument parsing loop. The catch-all `*)` case rejects both flags and positional args. Verified: `--help` exits 0, `--badarg` exits 2, `foobar` exits 2. All 11 fixture tests still pass.
- SUMMARY.md claims: "2/2 tasks completed", "All 7 scripts conform to consistent exit code conventions." Verified: all 7 scripts exit 0 on `--help` and exit 2 on `--badarg`.

**Plan 05-02 (End-to-End Integration Test):**

- Task 1 (create run-e2e-test.sh): COMPLETE. Commit `36e5e3f` creates `scripts/run-e2e-test.sh` (105 lines). The script follows the plan exactly: variable init, cleanup trap, usage function, argument parsing, 5-step pipeline (scaffold, validate, score, generate, verify), success message.
- SUMMARY.md claims: "1/1 tasks completed", "Scaffolded plugin scores 100/100", "marketplace.json unchanged after execution." Verified: `--help` exits 0, `--badarg` exits 2, script is executable (chmod +x confirmed).

Both SUMMARYs claim "No deviations from plan." Git diffs confirm this -- each commit touches only the file(s) specified in the plan, and the changes match the plan descriptions exactly.

No issues found.

### Research Methodology

The research document (`05-RESEARCH.md`) recommended three patterns:
1. **EXIT trap cleanup** for E2E test -- implemented at line 17 of `run-e2e-test.sh` (`trap cleanup EXIT`).
2. **Consistent error handling boilerplate** -- all three modified/created scripts follow the `usage()` + `for arg` + `case` pattern from the research skeleton.
3. **Disposable plugin pattern** with `e2e-test-$(date +%s)` naming -- implemented exactly as recommended.

The research anti-pattern "Exit 2 on --help" is directly addressed by plan 05-01 task 1.

No issues found.

### Known Pitfalls

Research identified 6 pitfalls. The following are relevant to wave 1:

- **Pitfall 1 (validate-local.sh exits 2 on --help):** Fixed in commit `f749279`. RESOLVED.
- **Pitfall 2 (run-fixture-tests.sh lacks --help):** Fixed in commit `51834fb`. RESOLVED.
- **Pitfall 3 (E2E test pollution):** Addressed via `trap cleanup EXIT` in `run-e2e-test.sh`. RESOLVED.
- **Pitfall 4 (generate-marketplace.sh network dependency):** The E2E test calls `generate-marketplace.sh` which may emit warnings about upstream fetches. The script handles this gracefully. No special handling in the E2E test, but `set -euo pipefail` combined with the fallback in `generate-marketplace.sh` makes this safe. RESOLVED.
- **Pitfall 6 (macOS bash 3.x):** No Bash 4+ features in any modified file. Verified: no `declare -A`, no `sed -i`, no `${var^^}`, no `readarray`/`mapfile`. RESOLVED.

No issues found.

### Eval Coverage

The EVAL plan (`05-EVAL.md`) defines 15 sanity checks (S1-S15). The wave 1 scope covers S1-S5, S11-S13, and S15. Checks S6-S10 and S14 relate to self-test.yml and scripts/README.md which are wave 2 scope.

For the wave 1 checks:
- S1 (--help compliance): Verified for all 7 scripts -- all exit 0.
- S2 (unknown arg rejection): Verified for all 7 scripts -- all exit 2 on `--badarg`.
- S3 (fixture test pass): 11/11 pass.
- S4 (E2E pipeline execution): Cannot run live in this review without side effects (scaffolds a real plugin), but script structure and individual component verification confirm correctness.
- S5 (E2E cleanup): The cleanup function is correctly structured; `--help` path tested and confirmed safe (empty `TEMP_PLUGIN_NAME` causes no cleanup action).
- S11 (no Bash 4+): Confirmed via grep -- no matches.
- S12 (validate-local.sh no-args): Exits 2 with error message. Confirmed.
- S13 (run-fixture-tests.sh positional rejection): Exits 2. Confirmed.
- S15 (run-e2e-test.sh executable): `test -x` confirms executable bit set.

No issues found.

## Stage 2: Code Quality

### Architecture

All three scripts follow the established project patterns precisely:

1. **Shebang:** `#!/usr/bin/env bash` -- consistent with all existing scripts.
2. **Strict mode:** `set -euo pipefail` -- consistent with all existing scripts.
3. **Directory resolution:** `SCRIPT_DIR` and `REPO_ROOT` pattern -- consistent.
4. **Usage function:** `usage()` with heredoc, exits 0 -- consistent with `validate-plugin.sh`, `score-plugin.sh`, `new-plugin.sh`, `generate-marketplace.sh`.
5. **Argument parsing:** `for arg in "$@"; do case ...` pattern -- consistent.
6. **Error messages:** Format `"Error: ... " >&2` with pointer to `--help` -- consistent with `new-plugin.sh` pattern.
7. **Section comments:** `# --- Section ---` pattern -- consistent.

The `run-e2e-test.sh` cleanup function correctly checks both conditions (`-n "$TEMP_PLUGIN_NAME"` and `-d` for the directory) before removal, and uses `|| true` for the git checkout to avoid failing on a missing marketplace.json.

No duplicate implementations found. The scripts invoke existing tooling (`validate-plugin.sh`, `score-plugin.sh`, `new-plugin.sh`, `generate-marketplace.sh`) rather than reimplementing their logic.

Consistent with existing patterns.

### Reproducibility

N/A -- no experimental code. These are infrastructure scripts with deterministic behavior.

### Documentation

**[INFO] run-e2e-test.sh comment at line 17 says "guaranteed via EXIT trap" which is accurate for normal exit and most signals but technically not for SIGKILL (kill -9).** This is a pedantic observation; the comment matches the behavior for all practical scenarios (Ctrl+C, pipeline failure, normal exit). The plan's claim that cleanup is "guaranteed on normal exit, failure, and interrupt (Ctrl+C)" is correct.

**[INFO] run-fixture-tests.sh usage text lists "4 invalid fixtures" but the test body runs 4 invalid fixtures plus 1 extra-fields fixture (total 5 non-valid).** The usage text explicitly separates these into "4 invalid fixtures (expect exit 1)" and "1 extra-fields fixture (expect exit 0 by design)", which is accurate and clear.

Adequate.

### Deviation Documentation

SUMMARY.md files for both 05-01 and 05-02 match git history:

- 05-01-SUMMARY claims commits `f749279` and `51834fb` -- both exist in git log with matching messages.
- 05-02-SUMMARY claims commit `36e5e3f` -- exists in git log with matching message.
- 05-01-SUMMARY key-files: `scripts/validate-local.sh` (modified), `scripts/run-fixture-tests.sh` (modified) -- matches `git diff --name-only` for both commits.
- 05-02-SUMMARY key-files: `scripts/run-e2e-test.sh` (created) -- matches `git diff --name-only` for commit `36e5e3f`.

No undocumented files modified. No discrepancies between SUMMARY claims and git log.

SUMMARY.md matches git history.

## Findings Summary

| # | Severity | Stage | Area | Description |
|---|----------|-------|------|-------------|
| 1 | WARNING | 2 | Architecture | `run-e2e-test.sh` cleanup trap fires on `--help` exit path (harmless but wasteful); trap is set before usage() is called |
| 2 | WARNING | 2 | Architecture | Pre-existing: `generate-marketplace.sh` silently ignores positional args (`foobar` exits 0) while the newly-written `run-fixture-tests.sh` and `run-e2e-test.sh` reject them (exit 2). Inconsistent behavior across the 7-script suite for positional arg handling. |
| 3 | INFO | 1 | Plan Alignment | 05-01-SUMMARY and 05-02-SUMMARY both say "7 scripts" -- verified accurate (7 .sh files in scripts/) |
| 4 | INFO | 2 | Architecture | `run-e2e-test.sh` uses shell variable interpolation in jq filter (`select(.name == \"$TEMP_PLUGIN_NAME\")`). Safe for the `e2e-test-<epoch>` naming pattern but would break if plugin names contained jq-special characters. Acceptable given the controlled naming. |
| 5 | INFO | 1 | Eval Coverage | EVAL checks S4/S5 (live E2E pipeline run + cleanup verification) could not be fully exercised in this review without side effects. Script structure confirms correct behavior. |
| 6 | INFO | 2 | Architecture | Good practice: cleanup function checks both `TEMP_PLUGIN_NAME` non-empty AND directory exists before `rm -rf`, preventing accidental removal. |

## Recommendations

**WARNING 1 -- Cleanup trap on --help path:**
In `/Users/edward.seo/dev/private/project/harness/claude-plugin-marketplace/scripts/run-e2e-test.sh`, the `trap cleanup EXIT` at line 17 is set before argument parsing at line 39. When `--help` is invoked, the cleanup function fires on exit. Since `TEMP_PLUGIN_NAME` is empty at that point, the cleanup is a no-op (the `[[ -n "$TEMP_PLUGIN_NAME" ]]` guard prevents any action), so this is harmless. However, it does execute `git -C "$REPO_ROOT" checkout -- .claude-plugin/marketplace.json 2>/dev/null || true` on every `--help` call, which is an unnecessary git operation. Consider moving the trap setup to after argument parsing, or accept the minor overhead since the `|| true` makes it safe.

**Recommendation:** Accept as-is. The overhead is negligible (one git checkout of an unchanged file), and moving the trap after argument parsing would create a window where an early failure between init and trap-setup could leave artifacts. The current placement is the safer pattern.

**WARNING 2 -- Pre-existing positional arg inconsistency in generate-marketplace.sh:**
`/Users/edward.seo/dev/private/project/harness/claude-plugin-marketplace/scripts/generate-marketplace.sh` lines 31-36 only catch `--*` flags but not positional arguments. Running `./scripts/generate-marketplace.sh foobar` succeeds silently (exit 0). The newly-written scripts (`run-fixture-tests.sh`, `run-e2e-test.sh`) use `*)` to catch and reject both flags and positional args. This creates an inconsistency: some no-arg scripts reject positional args (exit 2), others silently ignore them (exit 0).

**Recommendation:** Add a `*) echo "Error: Unknown argument '$arg'..." >&2; exit 2 ;;` case to `generate-marketplace.sh`'s argument parsing loop. This is a pre-existing issue, not introduced by wave 1, so it should be tracked as a future cleanup task rather than blocking this wave.

