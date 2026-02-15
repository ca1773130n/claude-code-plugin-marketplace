# Evaluation Plan: Phase 5 — Integration Testing & Hardening

**Designed:** 2026-02-15
**Designer:** Claude (grd-eval-planner)
**Method(s) evaluated:** Script hardening, E2E integration testing, CI self-testing
**Reference papers:** N/A (infrastructure hardening phase)

## Evaluation Overview

Phase 5 is a hardening and integration testing phase with no new functionality. The evaluation focuses on verifying that the existing infrastructure (6 scripts + 2 workflows from Phases 1-4) meets quality and consistency standards. This phase adds compliance checking (--help/exit codes), integration testing (E2E pipeline), and self-testing CI workflows.

The evaluation design is based on concrete baselines measured directly from the codebase on 2026-02-15 (documented in 05-RESEARCH.md). All metrics trace to either project success criteria (ROADMAP.md) or measured performance baselines.

**What we're evaluating:**
- Script interface compliance (--help, exit codes, error handling)
- End-to-end pipeline correctness (scaffold → validate → score → generate → verify)
- CI workflow reliability and performance
- Documentation accuracy and completeness

### Metric Sources

| Metric | Source | Why This Metric |
|--------|--------|----------------|
| Script --help exit codes | ROADMAP.md Phase 5 success criteria | "All scripts have --help flags, exit code 2 on invalid args" |
| Script argument validation | ROADMAP.md Phase 5 success criteria + POSIX conventions | Invalid args must exit 2, --help must exit 0 |
| E2E pipeline correctness | ROADMAP.md Phase 5 success criteria | "Full dry-run succeeds end-to-end" |
| CI workflow completion time | ROADMAP.md Phase 5 success criteria | "CI time with 2 real + 5 fixture plugins < 2 minutes" |
| Fixture test pass rate | Existing test coverage baseline | 11 tests (9 fixtures + 2 real plugins) must all pass |
| Documentation accuracy | ROADMAP.md Phase 5 success criteria | "scripts/README.md documenting all scripts" |
| Performance baselines | 05-RESEARCH.md measurements | validate-plugin: ~0.8s, score: ~0.9s, fixtures: ~4.7s, E2E: ~9.5s |

### Verification Level Summary

| Level | Count | Purpose |
|-------|-------|---------|
| Sanity (L1) | 15 checks | Script compliance, test pass/fail, syntax validation |
| Proxy (L2) | 4 metrics | Performance timing, CI completion, documentation cross-validation |
| Deferred (L3) | 3 validations | Real-world CI reliability, scheduled workflow execution, scale testing |

## Level 1: Sanity Checks

**Purpose:** Verify basic functionality and compliance. These MUST ALL PASS before proceeding.

### S1: Script --help Compliance (7 scripts)
- **What:** Every script in scripts/ exits 0 on --help
- **Command:** `for s in scripts/*.sh; do ./"$s" --help >/dev/null 2>&1; echo "$s: $?"; done`
- **Expected:** All 7 scripts print ": 0" (validate-plugin, score-plugin, run-fixture-tests, generate-marketplace, validate-local, new-plugin, run-e2e-test)
- **Failure means:** Plan 05-01 incomplete (validate-local.sh or run-fixture-tests.sh not fixed) or Plan 05-02 incomplete (run-e2e-test.sh missing --help)

### S2: Script Unknown Argument Rejection (7 scripts)
- **What:** Every script exits 2 when given unknown arguments
- **Command:** `for s in scripts/*.sh; do ./"$s" --badarg >/dev/null 2>&1; echo "$s: $?"; done`
- **Expected:** All 7 scripts print ": 2"
- **Failure means:** Argument parsing logic incomplete in one or more scripts

### S3: Fixture Test Suite Pass
- **What:** All 11 fixture tests pass (9 fixtures + 2 real plugins)
- **Command:** `./scripts/run-fixture-tests.sh`
- **Expected:** Output ends with "All tests passed." and exit code 0
- **Failure means:** Regression in validate-plugin.sh or fixture definitions

### S4: E2E Pipeline Execution
- **What:** Full scaffold → validate → score → generate → verify pipeline completes
- **Command:** `./scripts/run-e2e-test.sh`
- **Expected:** Output ends with "=== E2E Test: ALL PASSED ===" and exit code 0
- **Failure means:** E2E script broken or pipeline component failure

### S5: E2E Cleanup Verification
- **What:** Temporary plugin removed and marketplace.json restored after E2E test
- **Command:** `./scripts/run-e2e-test.sh && (ls plugins/ | grep e2e-test || echo "OK: no temp dirs") && (git diff --name-only .claude-plugin/marketplace.json || echo "OK: marketplace unchanged")`
- **Expected:** "OK: no temp dirs" and "OK: marketplace unchanged" (or empty diff output)
- **Failure means:** Cleanup trap not working in run-e2e-test.sh

### S6: self-test.yml YAML Validity
- **What:** Workflow file is valid YAML syntax
- **Command:** `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/self-test.yml'))" && echo "VALID"`
- **Expected:** "VALID" with exit code 0
- **Failure means:** Syntax error in workflow file

### S7: self-test.yml Trigger Configuration
- **What:** Workflow has all 4 required triggers
- **Command:** `grep -E '^\s+(push|pull_request|workflow_dispatch|schedule):' .github/workflows/self-test.yml | wc -l`
- **Expected:** 4 matches
- **Failure means:** Missing trigger in workflow

### S8: self-test.yml Job Configuration
- **What:** Workflow has 3 parallel jobs (fixture-tests, e2e-test, script-help-check)
- **Command:** `grep -E '^\s+(fixture-tests|e2e-test|script-help-check):' .github/workflows/self-test.yml | wc -l`
- **Expected:** 3 matches
- **Failure means:** Missing job in workflow

### S9: scripts/README.md Existence and Length
- **What:** README exists and documents all scripts
- **Command:** `test -f scripts/README.md && wc -l scripts/README.md`
- **Expected:** File exists with >= 100 lines
- **Failure means:** README not created or too minimal

### S10: scripts/README.md Coverage
- **What:** All 7 scripts are documented in README
- **Command:** `for s in validate-plugin score-plugin run-fixture-tests generate-marketplace validate-local new-plugin run-e2e-test; do grep -q "$s" scripts/README.md && echo "$s: OK" || echo "$s: MISSING"; done`
- **Expected:** All 7 scripts print ": OK"
- **Failure means:** Incomplete documentation

### S11: No Bash 4+ Features in Modified Scripts
- **What:** No associative arrays or GNU-specific syntax introduced
- **Command:** `grep -n 'declare -A' scripts/validate-local.sh scripts/run-fixture-tests.sh scripts/run-e2e-test.sh`
- **Expected:** No matches (exit code 1 from grep)
- **Failure means:** macOS bash 3.x incompatibility introduced

### S12: validate-local.sh No-Args Handling
- **What:** Script exits 2 when called with no arguments (usage error, not help)
- **Command:** `./scripts/validate-local.sh 2>&1; echo "EXIT: $?"`
- **Expected:** "EXIT: 2" and error message about missing argument
- **Failure means:** validate-local.sh incorrectly treats no-args as --help

### S13: run-fixture-tests.sh Positional Arg Rejection
- **What:** Script exits 2 when given positional arguments (takes no args)
- **Command:** `./scripts/run-fixture-tests.sh foobar 2>&1; echo "EXIT: $?"`
- **Expected:** "EXIT: 2" and error message about unknown argument
- **Failure means:** Argument validation incomplete

### S14: No Emoji in Documentation
- **What:** scripts/README.md contains no emoji characters
- **Command:** `grep -P '[^\x00-\x7F]' scripts/README.md | wc -l`
- **Expected:** 0 matches (only ASCII)
- **Failure means:** Documentation violates project style

### S15: E2E Script Executability
- **What:** run-e2e-test.sh has execute bit set
- **Command:** `test -x scripts/run-e2e-test.sh && echo "OK"`
- **Expected:** "OK"
- **Failure means:** Script not marked executable

**Sanity gate:** ALL sanity checks must pass. Any failure blocks progression.

## Level 2: Proxy Metrics

**Purpose:** Indirect evaluation of performance and correctness.
**IMPORTANT:** Proxy metrics are NOT validated substitutes for full evaluation. Treat results with appropriate skepticism.

### P1: Fixture Test Performance
- **What:** Fixture test suite completes within expected time
- **How:** Measure wall-clock time for fixture test run
- **Command:** `time ./scripts/run-fixture-tests.sh`
- **Target:** < 10 seconds (baseline: 4.7s local, allowing 2x overhead for CI)
- **Evidence:** 05-RESEARCH.md measured 11 tests at 4.7s locally (0.4s per test)
- **Correlation with full metric:** MEDIUM — local timing correlates with CI timing but CI runners are slower
- **Blind spots:** Network latency, npm ci overhead, CI runner variability
- **Validated:** No — awaiting deferred validation in real CI

### P2: E2E Pipeline Performance
- **What:** End-to-end pipeline completes within expected time
- **How:** Measure wall-clock time for E2E test run
- **Command:** `time ./scripts/run-e2e-test.sh`
- **Target:** < 20 seconds (baseline: 9.5s for 5-plugin pipeline, allowing 2x overhead)
- **Evidence:** 05-RESEARCH.md measured scaffold+validate+score+generate at 9.5s for 5 plugins
- **Correlation with full metric:** MEDIUM — local timing proxy for CI, but CI has npm ci overhead (~30s)
- **Blind spots:** CI npm cache, GitHub API rate limits (for generate-marketplace.sh upstream fetch)
- **Validated:** No — awaiting deferred validation in real CI

### P3: Script Help Check Performance
- **What:** --help invocation for all scripts completes quickly
- **How:** Measure time to run --help on all 7 scripts
- **Command:** `time (for s in scripts/*.sh; do ./"$s" --help >/dev/null 2>&1; done)`
- **Target:** < 2 seconds (7 scripts, each exits immediately on --help)
- **Evidence:** Baseline expectation: --help exits before any real work, ~0.1s per script
- **Correlation with full metric:** HIGH — --help has no dependencies, timing is deterministic
- **Blind spots:** None significant (no file I/O, no external calls)
- **Validated:** No — awaiting deferred validation in CI script-help-check job

### P4: Documentation Accuracy Cross-Check
- **What:** scripts/README.md usage examples match actual --help output
- **How:** Compare documented usage for validate-plugin.sh with actual --help output
- **Command:** `./scripts/validate-plugin.sh --help | head -3 && grep -A 3 'validate-plugin.sh' scripts/README.md | head -3`
- **Target:** First line of --help usage matches README documented usage
- **Evidence:** Manual cross-reference between script --help and README
- **Correlation with full metric:** HIGH — direct comparison of documented vs actual behavior
- **Blind spots:** Only spot-checks validate-plugin.sh; doesn't verify all 7 scripts
- **Validated:** No — full verification requires human review of all script documentation

## Level 3: Deferred Validations

**Purpose:** Full evaluation requiring integration or resources not available now.

### D1: CI Workflow Completion Time — DEFER-05-01
- **What:** self-test.yml workflow completes on GitHub Actions in < 2 minutes
- **How:** Push to main (touching scripts/), observe workflow duration in GitHub Actions UI
- **Why deferred:** Requires actual GitHub Actions execution environment
- **Validates at:** First push to main after Phase 5 completion
- **Depends on:** self-test.yml committed and pushed to GitHub
- **Target:** Total workflow time < 120 seconds (2 minutes)
- **Risk if unmet:** CI time budget exceeded; may need to reduce test coverage or parallelize differently
- **Fallback:** Identify slowest job (fixture-tests, e2e-test, or script-help-check) and optimize

### D2: Weekly Scheduled Workflow Reliability — DEFER-05-02
- **What:** self-test.yml scheduled trigger (weekly Monday 6am UTC) executes successfully
- **How:** Observe GitHub Actions scheduled runs over 30 days
- **Why deferred:** Requires time passage and multiple cron executions
- **Validates at:** 30 days after Phase 5 completion
- **Depends on:** self-test.yml deployed with schedule trigger
- **Target:** 4/4 weekly runs succeed (100% success rate over 1 month)
- **Risk if unmet:** Scheduled workflows may be silently disabled by GitHub if repository inactive
- **Fallback:** Use workflow_dispatch manual trigger for periodic testing

### D3: Performance at Scale (10+ Real Plugins) — DEFER-05-03
- **What:** Full pipeline (validate + score + generate) completes in < 3 minutes with 10+ real plugins
- **How:** Wait for marketplace to grow to 10+ plugins, measure validate-plugins.yml workflow time
- **Why deferred:** Only 2 real plugins exist currently; requires marketplace growth
- **Validates at:** When marketplace contains 10+ real plugins
- **Depends on:** Organic plugin submissions or manual plugin addition
- **Target:** CI time < 3 minutes with 10 plugins (linear scaling from 2-plugin baseline)
- **Risk if unmet:** May need parallel validation or incremental marketplace generation
- **Fallback:** Implement parallel plugin validation using GitHub Actions matrix strategy

## Ablation Plan

**No ablation plan** — This phase involves no algorithmic components or methods to isolate. It is pure infrastructure hardening and integration testing. The E2E pipeline test itself serves as an ablation: it verifies that all 5 components (scaffold, validate, score, generate, verify) work together, and failure at any step pinpoints the broken component.

## Baselines

| Baseline | Description | Expected Score | Source |
|----------|-------------|----------------|--------|
| validate-plugin.sh time | Single plugin validation (schema + structure) | ~0.8s | 05-RESEARCH.md |
| score-plugin.sh time | Single plugin quality scoring | ~0.9s | 05-RESEARCH.md |
| run-fixture-tests.sh time | 11 fixture tests (9 fixtures + 2 real) | ~4.7s | 05-RESEARCH.md |
| generate-marketplace.sh time | Marketplace generation (2 real plugins) | ~2.6s | 05-RESEARCH.md |
| Full E2E pipeline time | Scaffold + validate + score + generate (5 plugins) | ~9.5s | 05-RESEARCH.md |
| CI npm ci overhead | Dependency installation in GitHub Actions | ~30s | Estimated from typical CI runs |
| Script --help compliance | Count of scripts exiting 0 on --help | 4/6 → 7/7 | 05-RESEARCH.md (before → after) |
| Script arg-rejection compliance | Count of scripts exiting 2 on bad args | 5/6 → 7/7 | 05-RESEARCH.md (before → after) |

## Evaluation Scripts

**Location of evaluation code:**
```
scripts/run-fixture-tests.sh  (Wave 1: add --help support)
scripts/run-e2e-test.sh       (Wave 1: create new)
.github/workflows/self-test.yml (Wave 2: create new)
```

**How to run full evaluation:**

```bash
# Prerequisites
npm ci

# Level 1: Sanity Checks (local)
# S1-S2: Script compliance
for s in scripts/*.sh; do ./"$s" --help >/dev/null 2>&1 && echo "$s: PASS" || echo "$s: FAIL"; done
for s in scripts/*.sh; do ./"$s" --badarg >/dev/null 2>&1; [ $? -eq 2 ] && echo "$s: PASS" || echo "$s: FAIL"; done

# S3: Fixture tests
./scripts/run-fixture-tests.sh

# S4-S5: E2E pipeline
./scripts/run-e2e-test.sh
ls plugins/ | grep e2e-test  # Should be empty (cleanup)
git diff --name-only .claude-plugin/marketplace.json  # Should be empty (restored)

# S6-S8: Workflow validation
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/self-test.yml'))"
grep -E 'push|pull_request|workflow_dispatch|schedule' .github/workflows/self-test.yml
grep -E 'fixture-tests|e2e-test|script-help-check' .github/workflows/self-test.yml

# S9-S10: Documentation
wc -l scripts/README.md
for s in validate-plugin score-plugin run-fixture-tests generate-marketplace validate-local new-plugin run-e2e-test; do grep -q "$s" scripts/README.md && echo "$s: OK" || echo "$s: MISSING"; done

# Level 2: Proxy Metrics (local)
time ./scripts/run-fixture-tests.sh       # Target: < 10s
time ./scripts/run-e2e-test.sh            # Target: < 20s
time (for s in scripts/*.sh; do ./"$s" --help >/dev/null 2>&1; done)  # Target: < 2s

# Level 3: Deferred (requires GitHub Actions)
# Push to main and observe self-test.yml workflow in GitHub Actions UI
# Monitor scheduled runs over 30 days
# Wait for 10+ plugins to measure scale performance
```

## Results Template

*To be filled by grd-eval-reporter after phase execution.*

### Sanity Results

| Check | Status | Output | Notes |
|-------|--------|--------|-------|
| S1: Script --help compliance (7 scripts) | [PASS/FAIL] | [script names + exit codes] | |
| S2: Script unknown arg rejection (7 scripts) | [PASS/FAIL] | [script names + exit codes] | |
| S3: Fixture test suite pass | [PASS/FAIL] | [test count + result] | |
| S4: E2E pipeline execution | [PASS/FAIL] | [pipeline steps + result] | |
| S5: E2E cleanup verification | [PASS/FAIL] | [temp dirs + git diff] | |
| S6: self-test.yml YAML validity | [PASS/FAIL] | [VALID or error] | |
| S7: self-test.yml trigger config | [PASS/FAIL] | [trigger count] | |
| S8: self-test.yml job config | [PASS/FAIL] | [job count] | |
| S9: scripts/README.md length | [PASS/FAIL] | [line count] | |
| S10: scripts/README.md coverage | [PASS/FAIL] | [scripts documented] | |
| S11: No Bash 4+ features | [PASS/FAIL] | [grep results] | |
| S12: validate-local.sh no-args | [PASS/FAIL] | [exit code] | |
| S13: run-fixture-tests.sh positional reject | [PASS/FAIL] | [exit code] | |
| S14: No emoji in documentation | [PASS/FAIL] | [grep count] | |
| S15: E2E script executability | [PASS/FAIL] | [test -x result] | |

### Proxy Results

| Metric | Target | Actual | Status | Notes |
|--------|--------|--------|--------|-------|
| P1: Fixture test time | < 10s | [measured]s | [MET/MISSED] | |
| P2: E2E pipeline time | < 20s | [measured]s | [MET/MISSED] | |
| P3: Script help check time | < 2s | [measured]s | [MET/MISSED] | |
| P4: Documentation accuracy | Usage matches | [PASS/FAIL] | [MET/MISSED] | |

### Deferred Status

| ID | Metric | Status | Validates At | Target |
|----|--------|--------|-------------|--------|
| DEFER-05-01 | CI workflow completion time | PENDING | First push to main | < 2 min |
| DEFER-05-02 | Weekly scheduled reliability | PENDING | 30 days post-deploy | 4/4 success |
| DEFER-05-03 | Performance at 10+ plugins | PENDING | Marketplace growth to 10+ | < 3 min |

## Evaluation Confidence

**Overall confidence in evaluation design:** HIGH

**Justification:**
- Sanity checks: ADEQUATE — 15 checks cover all critical compliance points (--help, exit codes, test pass/fail, YAML validity, documentation existence). Every sanity check is deterministic and verifiable locally.
- Proxy metrics: WELL-EVIDENCED — All 4 proxy metrics trace to measured baselines from 05-RESEARCH.md or direct cross-validation. Targets are derived from research, not arbitrary.
- Deferred coverage: COMPREHENSIVE — All 3 deferred items are clearly documented with specific validation conditions. They cover the gaps that cannot be verified locally (CI timing, scheduled execution, scale performance).

**What this evaluation CAN tell us:**
- Script interface compliance is complete (--help, exit codes, error messages)
- Full pipeline works end-to-end (scaffold → validate → score → generate → verify)
- Integration tests catch regressions (fixture tests + E2E test)
- Documentation exists and covers all scripts
- Local performance meets expectations (proxy for CI performance)

**What this evaluation CANNOT tell us:**
- Real CI timing in GitHub Actions environment — validated at first push to main (DEFER-05-01)
- Scheduled workflow reliability over time — validated after 30 days (DEFER-05-02)
- Performance at scale (10+ plugins) — validated when marketplace grows (DEFER-05-03)
- Concurrent merge handling (multiple PRs merging simultaneously) — not covered by this phase
- Real-world contributor experience (whether CONTRIBUTING.md + scripts are intuitive) — requires user testing, not automated validation

---

*Evaluation plan by: Claude (grd-eval-planner)*
*Design date: 2026-02-15*
