---
phase: 02-ci-cd-pipeline
plan: 02
subsystem: github-actions-workflows
tags: [ci-cd, github-actions, workflows, validation, publishing]
requires:
  - scripts/validate-plugin.sh
  - scripts/run-fixture-tests.sh
  - scripts/generate-marketplace.sh
  - schemas/marketplace.schema.json
  - package.json
  - package-lock.json
provides:
  - .github/workflows/validate-plugins.yml
  - .github/workflows/publish-marketplace.yml
affects:
  - .claude-plugin/marketplace.json (auto-committed on merge)
tech-stack: [github-actions, dorny/paths-filter@v3, stefanzweifel/git-auto-commit-action@v7, actions/setup-node@v4, actions/checkout@v4]
key-files:
  - .github/workflows/validate-plugins.yml
  - .github/workflows/publish-marketplace.yml
key-decisions:
  - "Filter names match actual directory names (GRD, multi-cli-harness) to avoid case-mapping pitfall"
  - "Used env var for matrix.plugin in run: step per GitHub Actions security best practices"
  - "cancel-in-progress: true on publish workflow (newest run always sees latest state)"
  - "Fixture tests run as parallel job in validation and as safety gate in publish"
duration: ~5 minutes
completed: 2026-02-12
---

# 02-02 Summary: GitHub Actions CI/CD workflows for PR validation and auto-publish

Created two GitHub Actions workflows: validate-plugins.yml (PR validation with per-plugin matrix and fixture tests) and publish-marketplace.yml (auto-publish marketplace.json on merge with safety gates and loop prevention).

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~5 minutes |
| Task count | 2 |
| File count (created) | 2 |
| validate-plugins.yml lines | 65 |
| publish-marketplace.yml lines | 47 |

## Accomplishments

1. **validate-plugins.yml** (65 lines): Three-job PR validation workflow. `detect-changes` uses `dorny/paths-filter@v3` with static filter entries matching actual plugin directory names (GRD, multi-cli-harness). `validate-plugins` runs as a matrix strategy job that validates only changed plugins using `validate-plugin.sh`, with `fail-fast: false` to check all changed plugins even if one fails. `test-fixtures` runs `run-fixture-tests.sh` in parallel to catch validation script regressions. Uses `pull_request` trigger (not `pull_request_target`) with explicit read-only permissions. Node.js 20 with npm cache.

2. **publish-marketplace.yml** (47 lines): Single-job auto-publish workflow triggered on push to main when `plugins/**/plugin.json` changes. Runs fixture tests as safety gate, generates marketplace.json via `generate-marketplace.sh`, validates output against marketplace schema via ajv-cli, then auto-commits using `stefanzweifel/git-auto-commit-action@v7` with `GITHUB_TOKEN` (inherent loop prevention). Includes `concurrency: { group: publish-marketplace, cancel-in-progress: true }` for rapid-merge handling and `[skip ci]` in commit message as defense-in-depth.

## Task Commits

| Task | Hash | Description |
|------|------|-------------|
| Task 1 | `12c8a44` | feat(02-02): create validate-plugins.yml PR validation workflow |
| Task 2 | `86f9d37` | feat(02-02): create publish-marketplace.yml auto-publish workflow |

## Files Created/Modified

| File | Status | Lines |
|------|--------|-------|
| `.github/workflows/validate-plugins.yml` | Created | 65 |
| `.github/workflows/publish-marketplace.yml` | Created | 47 |

## Decisions Made

1. **Filter names match directory names**: Used `GRD` (not `grd`) and `multi-cli-harness` as `dorny/paths-filter` filter names, matching the actual directory names under `plugins/`. This eliminates the case-mapping pitfall identified in Research Pitfall 5 -- `matrix.plugin` value IS the directory name, so no translation is needed in the validate step.

2. **Environment variable for matrix.plugin in run: step**: Instead of using `${{ matrix.plugin }}` directly in `run:`, used an `env:` block (`PLUGIN_NAME: ${{ matrix.plugin }}`) and referenced `$PLUGIN_NAME` in the shell. While `matrix.plugin` values come from workflow-controlled filter names (not user input), this follows GitHub Actions security best practices for avoiding command injection patterns.

3. **cancel-in-progress: true for publish**: Chose `cancel-in-progress: true` over `false` for the publish concurrency group. Since `generate-marketplace.sh` regenerates from all plugins (not from diff), the newest run always produces the correct result. Canceling stale runs saves CI time.

4. **Fixture tests as safety gate in publish**: Added `run-fixture-tests.sh` before `generate-marketplace.sh` in the publish workflow, per Research Open Question 5 recommendation. This prevents publishing with broken validation scripts.

## Deviations from Plan

1. **Added env var indirection for matrix.plugin**: The plan showed `./scripts/validate-plugin.sh "plugins/${{ matrix.plugin }}"` directly in the `run:` block. Changed to use an `env:` block with `$PLUGIN_NAME` variable to follow GitHub Actions security best practices (avoid `${{ }}` expressions in `run:` blocks). Functionally identical.

2. **No other deviations**: All other requirements followed as specified.

## Issues Encountered

None. Both tasks executed cleanly on first attempt.

## Next Phase Readiness

Plan 02-02 completes Phase 2 (CI/CD Pipeline). All Phase 2 artifacts are ready:
- `scripts/generate-marketplace.sh` (Plan 02-01) -- marketplace generation script
- `CODEOWNERS` (Plan 02-01) -- code ownership rules
- `.github/workflows/validate-plugins.yml` (Plan 02-02) -- PR validation
- `.github/workflows/publish-marketplace.yml` (Plan 02-02) -- auto-publish on merge

Phase 3 (Quality Gates & Scoring) can begin. It will:
- Add `scripts/score-plugin.sh` with quality rubric
- Integrate scoring into CI workflow (PR comment display)
- Set up GitHub branch protection rules
- Add quality score to marketplace.json

Deferred validation items (require actual GitHub Actions runs):
- CI workflow triggers on PR with plugin changes
- CI workflow auto-commits marketplace.json on merge
- Auto-commit does not trigger infinite loop
- CI runs complete within 3 minutes
