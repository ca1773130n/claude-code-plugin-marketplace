# State — Claude Code Plugin Marketplace

Last updated: 2026-02-15

> **Versioning note:** All phases below are pre-release work from the original `claude-plugin-marketplace` repo,
> preserved as v0.0.x history. The `claude-code-plugin-marketplace` repo starts fresh at **v0.1.0**.

## Current Version

**v0.1.0** (planning — fresh start)

## Pre-release History (v0.0.x — all complete)

| Version | Phase | Plan | Status | Summary |
|---------|-------|------|--------|---------|
| v0.0.1 | 1 | 01-01 | done | JSON schemas (plugin + marketplace) and npm/ajv-cli setup |
| v0.0.1 | 1 | 01-02 | done | validate-plugin.sh two-layer validation script |
| v0.0.1 | 1 | 01-03 | done | Test fixtures (9 fixtures) and integration test runner |
| v0.0.2 | 2 | 02-01 | done | generate-marketplace.sh, CODEOWNERS, package-lock.json |
| v0.0.2 | 2 | 02-02 | done | GitHub Actions workflows (validate-plugins.yml + publish-marketplace.yml) |
| v0.0.3 | 3 | 03-01 | done | score-plugin.sh with 30-rule rubric across 5 categories |
| v0.0.3 | 3 | 03-02 | done | qualityScore in schema/marketplace + QUALITY.md documentation |
| v0.0.3 | 3 | 03-03 | done | CI scoring integration -- PR comments with quality scores |
| v0.0.4 | 4 | 04-01 | done | Plugin template scaffold (100/100 score) + validate-local.sh wrapper |
| v0.0.4 | 4 | 04-02 | done | GitHub issue & PR templates for plugin submissions |
| v0.0.4 | 4 | 04-03 | done | new-plugin.sh scaffolding script (100/100 generated plugins) |
| v0.0.4 | 4 | 04-04 | done | CONTRIBUTING.md contributor guide (358 lines, 14 sections) |
| v0.0.5 | 5 | 05-01 | done | Exit code and --help compliance hardening across all scripts |
| v0.0.5 | 5 | 05-02 | done | E2E integration test (run-e2e-test.sh) -- full pipeline coverage |
| v0.0.5 | 5 | 05-03 | done | Self-test CI workflow + scripts/README.md documentation |

## Key Artifacts

| Artifact | Status | Notes |
|----------|--------|-------|
| `schemas/plugin.schema.json` | stable | Phase 1 |
| `schemas/marketplace.schema.json` | **updated** | Phase 3 Plan 02 -- added qualityScore field |
| `scripts/validate-plugin.sh` | stable | Phase 1 |
| `scripts/run-fixture-tests.sh` | **updated** | Phase 5 Plan 01 -- added --help and argument rejection |
| `scripts/generate-marketplace.sh` | **updated** | Phase 3 Plan 02 -- integrates score-plugin.sh |
| `scripts/score-plugin.sh` | stable | Phase 3 Plan 01 -- 30-rule quality rubric |
| `CODEOWNERS` | stable | Phase 2 Plan 01 -- @ca1773130n all paths |
| `package-lock.json` | tracked | Phase 2 Plan 01 -- committed for npm ci |
| `.claude-plugin/marketplace.json` | regenerated | Enrichment fields + qualityScore |
| `.github/workflows/validate-plugins.yml` | **updated** | Phase 3 Plan 03 -- added scoring step + PR comments |
| `.github/workflows/publish-marketplace.yml` | stable | Phase 2 Plan 02 -- auto-publish on merge |
| `QUALITY.md` | **new** | Phase 3 Plan 02 -- scoring rubric documentation (141 lines) |
| `templates/plugin-template/` | **new** | Phase 4 Plan 01 -- 7-file scaffold, 100/100 quality score |
| `scripts/validate-local.sh` | **updated** | Phase 5 Plan 01 -- fixed --help exit code (was 2, now 0) |
| `.github/ISSUE_TEMPLATE/plugin-request.yml` | **new** | Phase 4 Plan 02 -- YAML issue form for plugin requests |
| `.github/PULL_REQUEST_TEMPLATE/plugin-submission.md` | **new** | Phase 4 Plan 02 -- PR template with submission checklist |
| `scripts/new-plugin.sh` | **new** | Phase 4 Plan 03 -- plugin scaffolding script (199 lines) |
| `CONTRIBUTING.md` | **new** | Phase 4 Plan 04 -- comprehensive contributor guide (358 lines) |
| `scripts/run-e2e-test.sh` | **new** | Phase 5 Plan 02 -- E2E integration test (105 lines, 5-step pipeline) |
| `.github/workflows/self-test.yml` | **new** | Phase 5 Plan 03 -- 3 parallel jobs, 4 triggers |
| `scripts/README.md` | **new** | Phase 5 Plan 03 -- comprehensive script reference (308 lines) |

## Baselines

| Metric | Value | Measured |
|--------|-------|----------|
| Plugin count | 2 (GRD, multi-cli-harness) | 2026-02-12 |
| GRD commands | 36 | 2026-02-12 |
| GRD agents | 18 | 2026-02-12 |
| GRD hooks | 0 | 2026-02-12 |
| multi-cli-harness commands | 0 | 2026-02-12 |
| multi-cli-harness agents | 17 | 2026-02-12 |
| multi-cli-harness hooks | 1 | 2026-02-12 |
| generate-marketplace.sh runtime | <1s | 2026-02-12 |
| GRD qualityScore | 79/100 | 2026-02-12 |
| multi-cli-harness qualityScore | 81/100 | 2026-02-12 |
| example-plugin (template) qualityScore | 100/100 | 2026-02-15 |
| Fixture tests (local) | 4.6s | 2026-02-15 |
| E2E pipeline test (local) | 4.2s | 2026-02-15 |
| Script help check (local) | 0.2s | 2026-02-15 |

## Deferred Validations

| Item | Deferred To | Reason |
|------|------------|--------|
| CI workflow triggers on PR | Post-push to GitHub | Requires actual GitHub Actions run |
| CI workflow auto-commits marketplace.json | Post-push to GitHub | Requires actual merge to main |
| Auto-commit does not trigger infinite loop | Post-push to GitHub | Requires merge + observation |
| CI runs complete within 3 minutes | Post-push to GitHub | Requires actual CI run timing |
| Concurrent merge handling | Phase 5 | Requires multiple rapid merges |
| CI performance with 10+ plugins | Phase 5 | Requires more plugins |
| PR quality score comment appears | Post-push to GitHub | Requires actual PR with plugin changes |
| comment-tag upsert works (update, not duplicate) | Post-push to GitHub | Requires second push to same PR |
| Score table markdown renders correctly | Post-push to GitHub | Requires visual check of PR comment |
| CI time < 3 minutes with scoring added | Post-push to GitHub | Requires actual CI run timing |
| Issue template renders as YAML form on GitHub | Post-push to GitHub | Requires push + new issue creation |
| PR template auto-populates on new plugin PRs | Post-push to GitHub | Requires PR against main |
| Self-test workflow triggers on scripts/schemas/tests changes | Post-push to GitHub | Requires actual push/PR with those paths |
| Self-test weekly schedule fires Monday 6am UTC | Post-push to GitHub | Requires 1+ week observation |
| Self-test CI time < 2 minutes | Post-push to GitHub | Local proxy: ~35s (longest job 4.6s + 30s npm ci) |

## Open Decisions

None at this time.
