# Phase 5: Integration Testing & Hardening - Research

**Researched:** 2026-02-15
**Domain:** CI/CD integration testing, bash script hardening, GitHub Actions self-test workflows
**Confidence:** HIGH

## Summary

Phase 5 is a hardening phase with no new functionality. The existing infrastructure from Phases 1-4 is functionally complete: 6 scripts, 2 workflows, 9 test fixtures, 2 real plugins, 7-file template, and full contributor onboarding documentation. The primary work is (1) creating a self-test GitHub Actions workflow, (2) adding an E2E test script that chains the full pipeline, (3) hardening error handling across all scripts, (4) auditing performance, and (5) documenting all scripts in `scripts/README.md`.

Research investigated the current codebase state in detail, measured actual timings, audited every script for --help/exit-code compliance, and identified specific gaps. The findings are concrete and actionable -- every recommendation maps to a verified gap in the existing code.

**Primary recommendation:** Focus on the 4 concrete gaps identified (run-fixture-tests.sh lacks --help; validate-local.sh exits 2 on --help; run-fixture-tests.sh ignores invalid args; no E2E test script exists) plus the new self-test workflow and scripts/README.md.

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash | 3.x (macOS) | Script engine | Project constraint -- no associative arrays, no GNU-only flags |
| jq | 1.6+ | JSON manipulation | Already used in all scripts, standard for shell JSON processing |
| ajv-cli | 5.0.0 | JSON Schema validation | Already pinned in package.json, Draft-07 support |
| GitHub Actions | v4 actions | CI/CD | Already configured in Phases 2-3 |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `time` (builtin) | N/A | Performance measurement | E2E timing assertions |
| `mktemp` | BSD/GNU | Temporary plugin scaffolding | E2E test cleanup |
| `diff` | BSD/GNU | Output comparison | Verifying marketplace.json updates |

### Alternatives Considered

| Instead of | Could Use | Tradeoff | Decision |
|------------|-----------|----------|----------|
| Custom bash test runner | bats-core / shunit2 | More structure but adds dependency | Use custom runner -- 6 scripts is too few to justify a test framework |
| shellcheck in CI | Manual review | Catches subtle bash issues | Recommend as optional addition but not required for Phase 5 scope |

**Installation:** No new dependencies. All tooling already in package.json and scripts.

## Architecture Patterns

### Recommended Project Structure (No Changes)

```
scripts/
  validate-plugin.sh       # Layer 1+2 validation
  score-plugin.sh          # 5-category quality scoring
  run-fixture-tests.sh     # Fixture test runner
  generate-marketplace.sh  # marketplace.json generator
  validate-local.sh        # Contributor validation wrapper
  new-plugin.sh            # Plugin scaffolding
  run-e2e-test.sh          # NEW: End-to-end pipeline test
  README.md                # NEW: Script documentation
.github/workflows/
  validate-plugins.yml     # PR validation (existing)
  publish-marketplace.yml  # Auto-publish (existing)
  self-test.yml            # NEW: Self-test on push/schedule
```

### Pattern 1: Self-Test Workflow with Multiple Triggers

**What:** A GitHub Actions workflow that runs the full test suite (fixtures + E2E) on push to main, on PR, and on a schedule.
**When to use:** When you want to catch infrastructure regressions even when no plugins change.

```yaml
name: Self Test
on:
  push:
    branches: [main]
    paths:
      - 'scripts/**'
      - 'schemas/**'
      - 'tests/**'
  pull_request:
    branches: [main]
    paths:
      - 'scripts/**'
      - 'schemas/**'
      - 'tests/**'
  workflow_dispatch: {}
  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 6am UTC
```

**Source:** [GitHub Docs: Workflow syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions) -- workflow_dispatch enables manual testing; schedule enables drift detection.

### Pattern 2: E2E Test as Disposable Scaffold

**What:** The E2E test scaffolds a temporary plugin, runs the full pipeline (validate, score, generate marketplace), then cleans up. Uses `mktemp`-style naming to avoid collisions.
**When to use:** For testing the scaffold-to-publish pipeline without polluting the real plugins directory.

```bash
# Create disposable plugin
TEMP_NAME="e2e-test-$(date +%s)"
./scripts/new-plugin.sh "$TEMP_NAME" --description "E2E test plugin"

# Run full pipeline
./scripts/validate-plugin.sh "plugins/$TEMP_NAME"
./scripts/score-plugin.sh "plugins/$TEMP_NAME" --json
./scripts/generate-marketplace.sh

# Verify marketplace.json contains the new plugin
jq -e ".plugins[] | select(.name == \"$TEMP_NAME\")" .claude-plugin/marketplace.json

# Cleanup
rm -rf "plugins/$TEMP_NAME"
git checkout -- .claude-plugin/marketplace.json
```

### Pattern 3: Consistent Error Handling Boilerplate

**What:** Every script follows the same error handling pattern: `set -euo pipefail`, `--help` exits 0, missing/invalid args exit 2, operational failures exit 1.
**When to use:** Applied to all 6 existing scripts + 1 new script.

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
...
Exit codes:
  0  Success
  1  Operational failure
  2  Usage error or missing dependencies
EOF
  exit 0  # IMPORTANT: --help is NOT an error
}

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage ;;
    -*) echo "Error: Unknown option '$arg'" >&2; exit 2 ;;
  esac
done
```

### Anti-Patterns to Avoid

- **Exit 2 on --help:** The `validate-local.sh` usage() function exits 2, which makes `--help` appear as an error. `--help` must always exit 0 per POSIX convention and the phase success criteria.
- **Ignoring unknown arguments in test runners:** `run-fixture-tests.sh` ignores all arguments including `--badarg`, which silently succeeds. Should reject unknown args with exit 2.
- **Hardcoded fixture lists:** `run-fixture-tests.sh` hardcodes fixture paths. If a new fixture is added to `tests/fixtures/` but not to the script, it is silently skipped. Consider auto-discovery with a naming convention (directories starting with `valid-` or `invalid-`).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON Schema validation | Custom bash JSON parser | ajv-cli (already used) | Edge cases in Draft-07 support |
| JSON field extraction | sed/awk on JSON | jq (already used) | Handles escaping, nested objects |
| Temporary directory cleanup | Manual rm -rf | trap "cleanup" EXIT | Guarantees cleanup on error/interrupt |
| GitHub Actions YAML syntax | Free-form YAML | Documented workflow_dispatch+schedule patterns | Avoids silent trigger failures |

**Key insight:** Phase 5 adds no new technologies. The risk is in polishing what exists, not in introducing new tools.

## Common Pitfalls

### Pitfall 1: validate-local.sh --help exits 2

**What goes wrong:** Running `./scripts/validate-local.sh --help` returns exit code 2 (usage error) instead of 0. This violates the POSIX convention that `--help` is informational, not erroneous.
**Why it happens:** The `usage()` function in `validate-local.sh` calls `exit 2` instead of `exit 0`.
**How to avoid:** Change `exit 2` to `exit 0` inside the `usage()` function.
**Warning signs:** Running `./scripts/validate-local.sh --help; echo $?` shows `2`.
**Verified:** Direct testing on 2026-02-15.

### Pitfall 2: run-fixture-tests.sh has no --help or argument handling

**What goes wrong:** The script ignores all arguments. `--help` runs the full test suite. `--badarg` is silently ignored. No usage documentation is available from the script itself.
**Why it happens:** The script was written as an internal test runner without user-facing argument parsing.
**How to avoid:** Add a usage() function and argument parsing loop with --help and unknown-arg rejection.
**Warning signs:** `run-fixture-tests.sh -h` runs tests instead of showing help.
**Verified:** Direct testing on 2026-02-15.

### Pitfall 3: E2E test pollution in plugins/ directory

**What goes wrong:** If an E2E test scaffolds a plugin and fails mid-pipeline, the temporary plugin directory is left behind, polluting the repo.
**Why it happens:** No cleanup trap is set.
**How to avoid:** Use `trap cleanup EXIT` to always remove the temporary plugin directory, even on failure or interrupt.
**Warning signs:** Stale `e2e-test-*` directories in `plugins/`.

### Pitfall 4: generate-marketplace.sh fetches upstream metadata (network dependency)

**What goes wrong:** The GRD plugin has an `.upstream` file that triggers a `gh api` call during `generate-marketplace.sh`. In CI without GitHub authentication, or on network failure, this may fail or use stale local metadata.
**Why it happens:** The script has a fallback (`WARNING: could not fetch upstream plugin.json, using local copy`) but the E2E test should account for this.
**How to avoid:** In E2E tests, verify marketplace generation succeeds regardless of network availability. The script already handles this gracefully.
**Warning signs:** Different marketplace.json content between local and CI runs.

### Pitfall 5: npx cold-start adds 1-2 seconds per invocation

**What goes wrong:** The first `npx ajv validate` call in a session is slow (1-2s) because npx resolves the package. With 11+ fixture tests each calling npx, this accumulates.
**Why it happens:** npx performs package resolution on each call.
**How to avoid:** The npm ci + npx pattern is already correct (ajv-cli is in devDependencies, npx finds it locally). Performance is adequate: full fixture suite runs in ~4.7s locally.
**Warning signs:** CI runs exceeding the 2-minute target.

### Pitfall 6: macOS bash 3.x compatibility issues

**What goes wrong:** Scripts using bash 4+ features (associative arrays, `${var^^}`, `<<<` with process substitution) break on macOS default bash.
**Why it happens:** macOS ships bash 3.2 due to GPL v3 licensing.
**How to avoid:** Continue the existing pattern: no `declare -A`, no `${var^^}`, use `jq` for all JSON operations. Test on macOS bash 3.x.
**Warning signs:** Scripts working in CI (Ubuntu, bash 5.x) but failing locally on macOS.
**Source:** Project CLAUDE.md documents this constraint.

## Experiment Design

### Recommended Experimental Setup

This is a hardening phase, not a feature phase. "Experiments" are verification runs.

**Independent variables:** Number of plugins (2, 5, 10+)
**Dependent variables:** Total CI run time, script exit codes, marketplace.json correctness
**Controlled variables:** Script versions, schema versions, fixture set

**Baseline comparison:**
- Current fixture test time: ~4.7s (11 tests, local macOS)
- Current validate-plugin.sh time: ~0.8s per plugin
- Current score-plugin.sh time: ~0.9s per plugin
- Current generate-marketplace.sh time: ~2.6s (2 real plugins)
- Full scaffold+validate+score+generate pipeline: ~9.5s (5 plugins, local)

**Performance targets:**
- CI fixture test job: < 60s (including npm ci)
- CI E2E test job: < 90s (including npm ci + scaffold + full pipeline)
- Total self-test workflow: < 2 minutes

**Scaling simulation:**
To verify the "10+ plugins < 3 minutes" target, scaffold 8 temporary plugins (+ 2 real = 10 total) and time the full pipeline. Based on linear extrapolation from the 5-plugin measurement (~9.5s), 10 plugins should complete in ~15-20s locally, well within the 3-minute CI target even with npm ci overhead (~30s).

### Recommended Metrics

| Metric | Why | How to Compute | Baseline |
|--------|-----|----------------|----------|
| Fixture test time | CI budget | `time run-fixture-tests.sh` | 4.7s local |
| E2E pipeline time | CI budget | `time run-e2e-test.sh` | ~9.5s (5 plugins) |
| Script --help compliance | Hardening completeness | Manual audit: `script --help; echo $?` | 4/6 compliant |
| Script exit-2-on-bad-args | Error handling | `script --badarg; echo $?` | 5/6 compliant |
| marketplace.json validity | Pipeline correctness | `npx ajv validate` after generation | Always valid |

## Verification Strategy

### Recommended Verification Tiers for This Phase

| Item | Recommended Tier | Rationale |
|------|-----------------|-----------|
| All scripts have --help (exit 0) | Level 1 (Sanity) | Run each script with --help, verify exit 0 |
| All scripts exit 2 on invalid args | Level 1 (Sanity) | Run each script with --badarg, verify exit 2 |
| run-fixture-tests.sh passes | Level 1 (Sanity) | Already working, run as regression |
| E2E scaffold-to-marketplace pipeline | Level 1 (Sanity) | New script, run locally |
| self-test.yml runs on push | Level 2 (Proxy) | Verify YAML syntax locally, test on push to GitHub |
| CI time < 2 minutes | Level 2 (Proxy) | Measure on actual GitHub Actions run |
| Performance with 10+ plugins | Level 3 (Deferred) | Requires 10+ real plugins or synthetic test |
| Concurrent merge handling | Level 3 (Deferred) | Requires multiple simultaneous PRs merging |
| scripts/README.md accuracy | Level 1 (Sanity) | Cross-reference against actual --help output |

**Level 1 checks to always include:**
- `./scripts/validate-plugin.sh --help` exits 0
- `./scripts/score-plugin.sh --help` exits 0
- `./scripts/run-fixture-tests.sh --help` exits 0
- `./scripts/validate-local.sh --help` exits 0
- `./scripts/new-plugin.sh --help` exits 0
- `./scripts/generate-marketplace.sh --help` exits 0
- `./scripts/run-e2e-test.sh --help` exits 0 (new script)
- All scripts exit 2 on unknown flags (`--badarg`)
- `./scripts/run-fixture-tests.sh` passes all 11 tests
- `./scripts/run-e2e-test.sh` completes with exit 0

**Level 2 proxy metrics:**
- self-test.yml workflow completes successfully on GitHub Actions
- Total workflow time < 2 minutes
- E2E test scaffolds, validates, scores, generates, and cleans up

**Level 3 deferred items:**
- Performance at scale (10+ real plugins)
- Concurrent merge conflict handling
- Weekly scheduled run reliability over 30 days

## Production Considerations

### Known Failure Modes

- **Network-dependent metadata fetch:** `generate-marketplace.sh` fetches upstream plugin.json via `gh api` for remote plugins. If `gh` is not authenticated or network is unavailable, it falls back to local copy with a warning. E2E tests should not depend on network availability.
  - Prevention: The script already has graceful fallback. E2E test should verify the fallback works.
  - Detection: Check for "WARNING: could not fetch upstream plugin.json" in output.

- **npx resolution failure:** If `node_modules` is missing (no `npm ci`), npx tries to download ajv-cli on the fly, which can fail in restricted network environments.
  - Prevention: Always run `npm ci` before any script invocation. Self-test workflow must include this step.
  - Detection: Scripts check `command -v npx` and exit 2 with clear error message.

### Scaling Concerns

- **Linear scaling with plugin count:** Each plugin adds ~2s to marketplace generation (validate + score + generate). With 10 plugins, expect ~20s; with 50, ~100s.
  - At current scale (2 real plugins): No concern.
  - At 10+ plugins: Still within 3-minute CI budget.
  - At 50+ plugins: May need parallel validation or incremental generation.

- **Fixture test count growth:** Each new fixture adds one `npx ajv validate` call (~0.4s). 20 fixtures would add ~4s.
  - At current scale (9 fixtures): 4.7s total, no concern.
  - At 50+ fixtures: Consider parallel execution or batched validation.

### Common Implementation Traps

- **Forgetting trap cleanup in E2E test:** If the E2E test script fails after scaffolding a plugin but before cleanup, the temporary plugin directory persists. Always use `trap cleanup EXIT`.
  - Correct approach: Define cleanup function that removes temp dirs and restores marketplace.json, trap it on EXIT.

- **Git state pollution:** `generate-marketplace.sh` modifies `.claude-plugin/marketplace.json`. The E2E test must restore the original file after running.
  - Correct approach: `git checkout -- .claude-plugin/marketplace.json` in the cleanup function.

- **Self-test workflow triggering publish workflow:** If the self-test workflow modifies marketplace.json and commits it, it could trigger the publish workflow in an infinite loop.
  - Correct approach: The E2E test must never commit changes. It should only operate on the working tree and clean up. The `[skip ci]` tag in the publish workflow's auto-commit already prevents loops.

## Code Examples

### E2E Test Script Skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEMP_PLUGIN_NAME=""

cleanup() {
  if [[ -n "$TEMP_PLUGIN_NAME" && -d "$REPO_ROOT/plugins/$TEMP_PLUGIN_NAME" ]]; then
    rm -rf "$REPO_ROOT/plugins/$TEMP_PLUGIN_NAME"
  fi
  git -C "$REPO_ROOT" checkout -- .claude-plugin/marketplace.json 2>/dev/null || true
}
trap cleanup EXIT

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Runs end-to-end integration test of the full plugin pipeline:
  scaffold -> validate -> score -> generate marketplace -> verify -> cleanup

Options:
  --help    Show this help message

Exit codes:
  0  All E2E tests passed
  1  Test failure
  2  Usage error or missing dependencies
EOF
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage ;;
    -*) echo "Error: Unknown option '$arg'" >&2; exit 2 ;;
  esac
done

# Step 1: Scaffold
TEMP_PLUGIN_NAME="e2e-test-$(date +%s)"
echo "=== E2E Test: Scaffolding $TEMP_PLUGIN_NAME ==="
"$SCRIPT_DIR/new-plugin.sh" "$TEMP_PLUGIN_NAME" --description "E2E integration test"

# Step 2: Validate
echo "=== E2E Test: Validating ==="
"$SCRIPT_DIR/validate-plugin.sh" "$REPO_ROOT/plugins/$TEMP_PLUGIN_NAME"

# Step 3: Score
echo "=== E2E Test: Scoring ==="
SCORE_JSON=$("$SCRIPT_DIR/score-plugin.sh" "$REPO_ROOT/plugins/$TEMP_PLUGIN_NAME" --json)
TOTAL=$(echo "$SCORE_JSON" | jq '.total')
echo "Score: $TOTAL/100"
if [[ "$TOTAL" -lt 80 ]]; then
  echo "FAIL: Scaffolded plugin scores below 80 ($TOTAL)" >&2
  exit 1
fi

# Step 4: Generate marketplace
echo "=== E2E Test: Generating marketplace.json ==="
"$SCRIPT_DIR/generate-marketplace.sh"

# Step 5: Verify plugin in marketplace
echo "=== E2E Test: Verifying marketplace entry ==="
if ! jq -e ".plugins[] | select(.name == \"$TEMP_PLUGIN_NAME\")" \
    "$REPO_ROOT/.claude-plugin/marketplace.json" >/dev/null 2>&1; then
  echo "FAIL: $TEMP_PLUGIN_NAME not found in marketplace.json" >&2
  exit 1
fi

echo ""
echo "=== E2E Test: ALL PASSED ==="
```

### Self-Test Workflow Structure

```yaml
name: Self Test

on:
  push:
    branches: [main]
    paths:
      - 'scripts/**'
      - 'schemas/**'
      - 'tests/**'
  pull_request:
    branches: [main]
    paths:
      - 'scripts/**'
      - 'schemas/**'
      - 'tests/**'
  workflow_dispatch: {}
  schedule:
    - cron: '0 6 * * 1'

jobs:
  fixture-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - name: Run fixture tests
        run: ./scripts/run-fixture-tests.sh

  e2e-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - name: Run E2E pipeline test
        run: ./scripts/run-e2e-test.sh

  script-help-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify all scripts support --help with exit 0
        run: |
          failed=0
          for script in scripts/*.sh; do
            exit_code=0
            ./"$script" --help >/dev/null 2>&1 || exit_code=$?
            if [ "$exit_code" -ne 0 ]; then
              echo "FAIL: $script --help exited with $exit_code (expected 0)"
              failed=1
            else
              echo "PASS: $script --help"
            fi
          done
          exit $failed
```

### run-fixture-tests.sh --help Addition

```bash
# Add before the test runner logic:
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Runs the fixture test suite, validating all test fixtures under tests/fixtures/
and both real plugins. Expects specific exit codes from validate-plugin.sh.

Test coverage:
  - 4 valid fixtures (expect exit 0)
  - 4 invalid fixtures (expect exit 1)
  - 1 extra-fields fixture (expect exit 0 by design)
  - 2 real plugins (expect exit 0)

Options:
  --help    Show this help message

Exit codes:
  0  All tests passed
  1  One or more tests failed
  2  Usage error
EOF
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage ;;
    -*) echo "Error: Unknown option '$arg'" >&2; exit 2 ;;
  esac
done
```

### validate-local.sh Fix

```bash
# Change in usage() function:
# FROM:
  exit 2
# TO:
  exit 0
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No tests | 9 fixtures + test runner | Phase 1 | 80% coverage of validation rules |
| Manual validation | validate-plugin.sh + score-plugin.sh | Phases 1-3 | Automated quality feedback |
| Manual marketplace update | Auto-generated on merge | Phase 2 | Zero drift |
| Manual plugin creation | new-plugin.sh scaffold | Phase 4 | <10 min onboarding |

**What Phase 5 adds:**
- E2E test covering full scaffold-to-publish pipeline
- Self-test CI workflow for infrastructure regression detection
- Consistent --help and exit code behavior across all scripts
- Script documentation (scripts/README.md)

## Open Questions

1. **Should the self-test workflow run on schedule?**
   - What we know: Weekly schedule catches drift from dependency updates or GitHub Actions runner changes.
   - What's unclear: Whether the repo gets enough activity to make scheduled runs useful vs. wasted CI minutes.
   - Recommendation: Include `schedule` trigger (weekly Monday) but it can be removed later if unnecessary. The `workflow_dispatch` trigger enables manual testing regardless.

2. **Should the E2E test verify marketplace.json schema?**
   - What we know: `generate-marketplace.sh` already validates its output against the marketplace schema.
   - What's unclear: Whether the E2E test should independently re-validate, creating redundant but defense-in-depth checking.
   - Recommendation: Let `generate-marketplace.sh` handle validation. The E2E test verifies the plugin entry exists with `jq`, which is sufficient.

3. **Should run-fixture-tests.sh auto-discover fixtures?**
   - What we know: Current script hardcodes 9 fixture paths. Adding a new fixture requires editing the script.
   - What's unclear: Whether the naming convention (`valid-*` and `invalid-*`) is stable enough for auto-discovery.
   - Recommendation: Keep hardcoded list for Phase 5 (explicit > implicit for test stability). Auto-discovery can be added in a future iteration if fixture count grows beyond ~15.

4. **Performance at 10+ real plugins**
   - What we know: 5-plugin pipeline completes in ~9.5s locally. Linear extrapolation suggests 10 plugins in ~20s.
   - What's unclear: CI runners are slower; npm ci adds ~30s; network fetches for upstream plugins add latency.
   - Recommendation: The 2-minute CI target is achievable. Measure after first CI run and optimize if needed. The `generate-marketplace.sh` network fetch for remote plugins is the main variable.

## Codebase Audit Findings

### Script Compliance Matrix (Current State)

| Script | --help | Exit 0 on --help | Exit 2 on bad args | Exit 2 on no args | Has usage() |
|--------|--------|-------------------|---------------------|--------------------|----|
| validate-plugin.sh | Yes | Yes (exit 0) | Yes | Yes | Yes |
| score-plugin.sh | Yes | Yes (exit 0) | Yes | Yes | Yes |
| run-fixture-tests.sh | **NO** | N/A | **NO** (ignores args) | N/A (no args needed) | **NO** |
| generate-marketplace.sh | Yes | Yes (exit 0) | Yes | N/A (no args needed) | Yes |
| validate-local.sh | Yes | **NO (exit 2)** | Yes | Yes | Yes |
| new-plugin.sh | Yes | Yes (exit 0) | Yes | Yes | Yes |

### Gaps to Fix

1. **run-fixture-tests.sh:** Add usage(), --help support (exit 0), and unknown arg rejection (exit 2).
2. **validate-local.sh:** Change `exit 2` to `exit 0` in usage() function.
3. **No E2E test script:** Create `run-e2e-test.sh` covering scaffold -> validate -> score -> generate -> verify pipeline.
4. **No self-test workflow:** Create `.github/workflows/self-test.yml`.
5. **No scripts/README.md:** Create documentation for all scripts.

### Performance Baselines (Measured 2026-02-15, macOS, local)

| Operation | Time | Notes |
|-----------|------|-------|
| validate-plugin.sh (single plugin) | 0.8s | Includes npx ajv-cli |
| score-plugin.sh (single plugin) | 0.9s | All jq, no npx |
| run-fixture-tests.sh (11 tests) | 4.7s | 11 npx invocations |
| generate-marketplace.sh (2 plugins) | 2.6s | Includes gh API fetch for GRD |
| new-plugin.sh (scaffold + validate) | 0.5s | Includes post-scaffold validation |
| Full E2E: scaffold + validate + score + generate (5 plugins) | 9.5s | 2 real + 3 scaffolded |

**CI estimate:** Add ~30s for npm ci + checkout. Total self-test workflow: ~45-60s with parallel jobs.

## Sources

### Primary (HIGH confidence)

- **Direct codebase audit** (2026-02-15) -- Read and tested all 6 scripts, 2 workflows, 9 fixtures, verified exit codes, measured timings
- [GitHub Docs: Workflow syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions) -- workflow triggers (push, pull_request, schedule, workflow_dispatch)
- [GitHub Docs: Using scripts to test your code on a runner](https://docs.github.com/en/actions/examples/using-scripts-to-test-your-code-on-a-runner) -- bash script execution in GitHub Actions

### Secondary (MEDIUM confidence)

- [Red Hat: Error handling in Bash scripts](https://www.redhat.com/en/blog/error-handling-bash-scripting) -- set -euo pipefail, trap EXIT pattern
- [How-To Geek: 3 Bash error handling patterns](https://www.howtogeek.com/bash-error-handling-patterns-i-use-in-every-script/) -- exit code conventions, stderr routing
- [Baeldung: Understanding and ignoring errors in Bash](https://www.baeldung.com/linux/bash-errors) -- exit code semantics

### Tertiary (LOW confidence)

- [nektos/act](https://github.com/nektos/act) -- Local GitHub Actions testing (not recommended for this project, Docker dependency)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- No new tools, all verified in existing codebase
- Architecture: HIGH -- Patterns directly derived from existing workflows and scripts
- Recommendations: HIGH -- Every gap verified by direct testing on 2026-02-15
- Pitfalls: HIGH -- All identified through hands-on codebase audit, not speculation

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (stable -- no fast-moving dependencies)
