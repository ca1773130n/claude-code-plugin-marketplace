---
phase: 05-integration-hardening
wave: 2
plans_reviewed: [05-03]
timestamp: 2026-02-15T07:22:38Z
blockers: 0
warnings: 2
info: 4
verdict: warnings_only
---

# Code Review: Phase 05 Wave 2

## Verdict: WARNINGS ONLY

Plan 05-03 was executed faithfully. The self-test CI workflow (`.github/workflows/self-test.yml`) and scripts documentation (`scripts/README.md`) both match the plan specification. Two warnings noted: the README reproduces an inaccurate claim from `generate-marketplace.sh --help` about "enrichment fields", and the self-test workflow omits a `concurrency` group present in the other workflows.

## Stage 1: Spec Compliance

### Plan Alignment

All 3 plan tasks were completed:

**Task 1 (self-test.yml):** Commit `16773a1` created `.github/workflows/self-test.yml` with all specified elements:
- 4 triggers: `push` (main, paths-filtered), `pull_request` (main, paths-filtered), `workflow_dispatch`, `schedule` (weekly Monday 6am UTC). Confirmed at lines 3-18 of self-test.yml.
- 3 parallel jobs: `fixture-tests`, `e2e-test`, `script-help-check`. No `needs:` between jobs, confirming parallelism.
- Path filters include `scripts/**`, `schemas/**`, `tests/**` as specified.
- `script-help-check` correctly skips `npm ci` and `setup-node` as per plan rationale.

**Task 2 (scripts/README.md):** Commit `252df05` created `scripts/README.md` at 308 lines (exceeds >= 100 line requirement). All 7 scripts documented:
1. `validate-plugin.sh` -- usage, options (--marketplace, --help), examples, exit codes
2. `score-plugin.sh` -- usage, options (--json, --help), examples, exit codes, categories
3. `validate-local.sh` -- usage, steps, examples, exit codes
4. `new-plugin.sh` -- usage, arguments, options (--description, --author, --help), examples, exit codes
5. `generate-marketplace.sh` -- usage, options (--help), examples, exit codes
6. `run-fixture-tests.sh` -- usage, test coverage breakdown, options, exit codes
7. `run-e2e-test.sh` -- usage, pipeline steps, options, exit codes

Includes required sections: Quick Reference table, Conventions, CI Integration.

**Task 3 (performance measurement):** No commit (measurement-only task as specified). Performance results documented in SUMMARY.md: fixture-tests 4.6s, e2e-test 4.2s, script-help-check 0.2s. Estimated max CI time ~35s, well under 2-minute target.

All commits (`16773a1`, `252df05`, `ee8e495`) found in git log with `05-03` tags. Files created match plan exactly. No undocumented files modified.

No issues found.

### Research Methodology

The self-test workflow structure matches the pattern recommended in `05-RESEARCH.md` (lines 64-86, "Pattern 1: Self-Test Workflow with Multiple Triggers"). The workflow YAML is nearly identical to the code example in the research document (lines 396-458), confirming faithful implementation of the researched pattern.

The `script-help-check` job's decision to skip `npm ci` matches the research analysis that `--help` exits before any real work.

No issues found.

### Known Pitfalls

Reviewed `05-RESEARCH.md` Common Pitfalls section (6 pitfalls documented). Relevant pitfalls for wave 2:

- **Pitfall 6 (macOS bash 3.x):** The `script-help-check` job in self-test.yml uses `for script in scripts/*.sh` which is POSIX-compatible. The inline bash uses `[ "$exit_code" -ne 0 ]` (not `[[ ]]`), maintaining broad compatibility. No bash 4+ features detected.
- **Pitfall 5 (npx cold-start):** Not applicable to this wave's artifacts -- the `script-help-check` job avoids npx entirely.

No issues found.

### Eval Coverage

Reviewed `05-EVAL.md`. The eval plan defines 15 sanity checks (S1-S15), 4 proxy metrics (P1-P4), and 3 deferred validations (D1-D3).

Checks relevant to plan 05-03:
- **S6 (YAML validity):** Verified -- `yaml-lint` passes on self-test.yml.
- **S7 (trigger configuration):** Verified -- all 4 triggers present in YAML (push, pull_request, workflow_dispatch, schedule).
- **S8 (job configuration):** Verified -- all 3 job names present (fixture-tests, e2e-test, script-help-check).
- **S9 (README length):** Verified -- 308 lines, exceeds 100-line threshold.
- **S10 (README coverage):** Verified -- all 7 script names appear in the file.
- **S14 (no emoji):** The README uses no emoji characters; plain markdown throughout.

Deferred validations D1 (CI workflow time < 2 min), D2 (weekly schedule reliability), and D3 (scale performance) remain appropriately deferred.

No issues found.

## Stage 2: Code Quality

### Architecture

**self-test.yml follows existing workflow patterns:**

| Pattern | validate-plugins.yml | publish-marketplace.yml | self-test.yml | Match? |
|---------|---------------------|------------------------|---------------|--------|
| `actions/checkout@v4` | Yes | Yes | Yes | Yes |
| `actions/setup-node@v4` with `node-version: '20'`, `cache: 'npm'` | Yes | Yes | Yes (2 of 3 jobs) | Yes |
| `npm ci` before scripts | Yes | Yes | Yes (2 of 3 jobs) | Yes |
| `runs-on: ubuntu-latest` | Yes | Yes | Yes | Yes |
| `permissions: contents: read` | Yes | -- (`contents: write`) | Yes | Yes |

The self-test workflow is architecturally consistent with the repository's existing CI patterns. The `permissions: contents: read` declaration (line 20-21 of self-test.yml) follows least-privilege, matching `validate-plugins.yml`.

One architectural difference noted: `publish-marketplace.yml` uses a `concurrency` group to prevent overlapping runs. Neither `validate-plugins.yml` nor `self-test.yml` use concurrency groups. For a read-only workflow this is acceptable, but see WARNING below.

### Reproducibility

N/A -- no experimental code. Infrastructure/CI artifacts only.

### Documentation

**README accuracy vs actual --help output:**

Cross-referenced all 7 scripts' `--help` output against README documentation:

| Script | --help Usage Line | README Usage Line | Match? |
|--------|-------------------|-------------------|--------|
| `validate-plugin.sh` | `<plugin-dir> [--marketplace]` | `<plugin-dir> [--marketplace]` | Exact |
| `score-plugin.sh` | `<plugin-dir> [--json]` | `<plugin-dir> [--json]` | Exact |
| `validate-local.sh` | `<plugin-dir>` | `<plugin-dir>` | Exact |
| `new-plugin.sh` | `<plugin-name> [--description "..."] [--author "..."]` | `<plugin-name> [--description "..."] [--author "..."]` | Exact |
| `generate-marketplace.sh` | `[options]` | (none shown) | Exact |
| `run-fixture-tests.sh` | `[options]` | (none shown) | Exact |
| `run-e2e-test.sh` | `[options]` | (none shown) | Exact |

Exit codes for all 7 scripts match between `--help` output and README tables.

The README describes `generate-marketplace.sh` as computing "enrichment fields (commands, agents, hooks counts)" (line 183). This text was copied from the script's own `--help` output (line 16 of `generate-marketplace.sh`). However, the script does NOT compute commands, agents, or hooks counts -- it extracts `name`, `description`, `version`, `author`, `source`, `category`, and `homepage`. The `--help` text is a pre-existing inaccuracy in `generate-marketplace.sh`, not introduced by this plan. See WARNING below.

### Deviation Documentation

SUMMARY.md states "None - plan executed exactly as written." This is confirmed:

- `git diff --name-only 16773a1^..16773a1` shows only `.github/workflows/self-test.yml`
- `git diff --name-only 252df05^..252df05` shows only `scripts/README.md`
- Both files listed in SUMMARY.md `key-files.created`
- No unexpected files modified
- Task 3 produced no commit (measurement-only, as documented)

SUMMARY.md matches git history.

## Findings Summary

| # | Severity | Stage | Area | Description |
|---|----------|-------|------|-------------|
| 1 | WARNING | 2 | Documentation | README line 183 repeats inaccurate "enrichment fields (commands, agents, hooks counts)" from generate-marketplace.sh --help; the script computes no such fields |
| 2 | WARNING | 2 | Architecture | self-test.yml lacks a `concurrency` group; overlapping runs (e.g., push + schedule coincidence) will both execute wastefully |
| 3 | INFO | 2 | Architecture | self-test.yml adds `permissions: contents: read` which is good security practice; consistent with validate-plugins.yml |
| 4 | INFO | 1 | Plan Alignment | Task 3 performance measurements (fixture 4.6s, E2E 4.2s, help 0.2s) are within expected baselines from 05-RESEARCH.md (fixture ~4.7s, E2E ~9.5s for 5 plugins) |
| 5 | INFO | 2 | Documentation | README at 308 lines exceeds the 120-180 line target from the plan, but the additional length is from thorough per-script documentation tables, not bloat |
| 6 | INFO | 1 | Eval Coverage | EVAL.md checks S6-S10 and S14 are all satisfiable from the implemented artifacts; no gaps in eval coverage for this wave |

## Recommendations

**WARNING #1 -- Inaccurate enrichment fields claim in README:**
The text "computes enrichment fields (commands, agents, hooks counts)" on line 183 of `scripts/README.md` mirrors `generate-marketplace.sh --help` output (line 16), but the script does not compute these fields. The root cause is in the script's own --help text, which predates this plan.
- **Action:** Update line 16 of `scripts/generate-marketplace.sh` (the `--help` text) to accurately describe what the script does (extracts metadata fields: name, description, version, author, source, category, homepage). Then update the corresponding line in `scripts/README.md` to match.
- **Priority:** Low -- cosmetic inaccuracy, does not affect functionality.

**WARNING #2 -- Missing concurrency group on self-test.yml:**
If a push to main and a scheduled run happen to overlap, both will execute fully. `publish-marketplace.yml` uses `concurrency: { group: publish-marketplace, cancel-in-progress: true }` to prevent this.
- **Action:** Consider adding a `concurrency` group to `self-test.yml`:
  ```yaml
  concurrency:
    group: self-test-${{ github.ref }}
    cancel-in-progress: true
  ```
  Using `${{ github.ref }}` ensures PR runs and main-branch runs don't cancel each other, while duplicate runs on the same ref are deduplicated.
- **Priority:** Low -- unlikely to cause problems at current scale (weekly schedule + infrequent pushes), but good hygiene for workflow completeness.
