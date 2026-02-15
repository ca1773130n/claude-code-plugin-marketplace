# Roadmap — Claude Code Plugin Marketplace

> **Versioning note:** Phases below were developed under the original `claude-plugin-marketplace` repo
> and are preserved here as v0.0.x pre-release history. The `claude-code-plugin-marketplace` repo
> starts fresh at **v0.1.0**.

## Pre-release Phase Overview (v0.0.x — legacy)

| Version | Phase | Name | Goal | Effort | Status | Dependencies |
|---------|-------|------|------|--------|--------|-------------|
| v0.0.1 | 1 | Schema & Validation Tooling | Formal JSON Schema + validation scripts | 2wk | **done** | — |
| v0.0.2 | 2 | CI/CD Pipeline | GitHub Actions for PR validation + auto-publish | 2wk | **done** | v0.0.1 |
| v0.0.3 | 3 | Quality Gates & Scoring | Quality rubric, branch protection, scoring in CI | 2wk | **done** | v0.0.2 |
| v0.0.4 | 4 | Plugin Onboarding Automation | Templates, scaffolding, CONTRIBUTING.md | 2wk | **done** | v0.0.1 |
| v0.0.5 | 5 | Integration Testing & Hardening | E2E tests, error handling, performance | 1wk | **done** | v0.0.2, v0.0.3, v0.0.4 |

**Total: ~9 weeks (pre-release)**

---

## Quality Targets

| Metric | Baseline | Phase 1 | Phase 2 | Final |
|--------|----------|---------|---------|-------|
| Schema validation coverage | 0% | 100% of plugin.json fields | 100% of marketplace.json | 100% all manifests on every PR |
| CI pipeline reliability | N/A | — | 100% of PRs, <3min | 99.5% over 30 days |
| Structural validation depth | 0 checks | File existence for commands | Agent naming, permissions | 15+ rules covering all artifact types |
| Quality score | Not measured | Rubric defined, plugins scored | Displayed in PR checks | >= 60 required to merge |
| Onboarding time | ~1 hour | — | 30 min (template) | <10 min (scaffold + guided PR) |
| Test coverage of validation | 0% | 80% with fixtures | 90% | 95% positive + negative cases |

---

## Phase Details

### v0.0.1 — Schema & Validation Tooling

**Scope:**
- `schemas/plugin.schema.json` — formal JSON Schema for plugin manifest
- `schemas/marketplace.schema.json` — schema for marketplace manifest
- `scripts/validate-plugin.sh` — validates plugin.json against schema, checks file existence, agent naming, hook permissions
- Validate both existing plugins and fix violations
- `tests/fixtures/` with 5+ fixture plugins (valid + invalid)

**Success Criteria:**
- validate-plugin.sh exits 0 for both real plugins
- validate-plugin.sh exits 1 for invalid fixtures with descriptive errors
- Schema covers 100% of fields in both existing plugin.json files

**Risk:** Medium — existing plugins have divergent manifest structures

**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md — JSON schemas (plugin + marketplace) and npm/ajv-cli setup
- [x] 01-02-PLAN.md — validate-plugin.sh two-layer validation script
- [x] 01-03-PLAN.md — Test fixtures (9 fixtures) and integration test runner

---

### v0.0.2 — CI/CD Pipeline

**Scope:**
- `.github/workflows/validate-plugins.yml` — PR trigger, validates changed plugins
- `.github/workflows/publish-marketplace.yml` — push-to-main trigger, regenerates marketplace.json
- `scripts/generate-marketplace.sh` — builds marketplace.json from all plugin.json files
- `CODEOWNERS` file

**Success Criteria:**
- Invalid plugin PRs show failing check within 3 minutes
- Valid plugin PRs show passing check with quality details
- Merging updates marketplace.json automatically within 2 minutes
- CI runs under 3 minutes average

**Risk:** Low — auto-commit conflicts if multiple PRs merge rapidly

**Plans:** 2 plans

Plans:
- [x] 02-01-PLAN.md — generate-marketplace.sh, CODEOWNERS, commit package-lock.json
- [x] 02-02-PLAN.md — GitHub Actions workflows (validate-plugins.yml + publish-marketplace.yml)

---

### v0.0.3 — Quality Gates & Scoring

**Scope:**
- `scripts/score-plugin.sh` with rubric:
  - Manifest completeness (20pts)
  - Documentation (20pts)
  - Structure integrity (20pts)
  - Naming conventions (20pts)
  - Version hygiene (20pts)
- Scoring integrated into CI workflow (displayed in PR comment)
- GitHub branch protection on main (required checks, 1 review, no force-push)
- Quality score in marketplace.json
- `QUALITY.md` explaining rubric

**Success Criteria:**
- Both plugins scored; GRD >= 70, multi-cli-harness >= 75
- No PR merges with failing validation
- Quality score visible in every PR check output

**Risk:** Medium — rubric must accommodate divergent naming conventions

**Plans:** 3 plans

Plans:
- [x] 03-01-PLAN.md — Core scoring engine (score-plugin.sh with 28 rules, 5 categories, dual output)
- [x] 03-02-PLAN.md — Marketplace integration + documentation (schema update, generate-marketplace.sh, QUALITY.md)
- [x] 03-03-PLAN.md — CI integration (validate-plugins.yml scoring step + PR comment)

---

### v0.0.4 — Plugin Onboarding Automation

**Scope:**
- `templates/plugin-template/` scaffold with plugin.json, agents/, commands/, skills/, CLAUDE.md, README.md
- `scripts/new-plugin.sh <name>` — scaffolds plugin from template
- `.github/PULL_REQUEST_TEMPLATE/plugin-submission.md`
- `.github/ISSUE_TEMPLATE/plugin-request.md`
- `CONTRIBUTING.md` — step-by-step guide
- `scripts/validate-local.sh` — local validation wrapper

**Success Criteria:**
- Scaffold passes validation with score >= 40
- New contributor can go from zero to submitted PR in <10 minutes
- PR template covers all quality gate requirements

**Risk:** Low — BSD vs GNU sed differences in scaffolding

**Plans:** 4 plans

Plans:
- [x] 04-01-PLAN.md — Plugin template scaffold + validate-local.sh wrapper
- [x] 04-02-PLAN.md — GitHub Issue/PR templates
- [x] 04-03-PLAN.md — new-plugin.sh scaffolding script
- [x] 04-04-PLAN.md — CONTRIBUTING.md contributor guide

---

### v0.0.5 — Integration Testing & Hardening

**Scope:**
- E2E test: scaffold -> validate -> score -> simulate PR -> merge -> marketplace.json update
- `.github/workflows/self-test.yml` — tests validation/scoring scripts against fixtures
- Error handling hardening (missing deps, clear messages, exit codes)
- Performance audit (<3min with 10+ plugins)
- `scripts/README.md` documenting all scripts

**Success Criteria:**
- Self-test workflow passes on main
- Full dry-run succeeds end-to-end
- All scripts have --help flags, exit code 2 on invalid args
- CI time with 2 real + 5 fixture plugins < 2 minutes

**Risk:** Low — hardening phase, no new functionality

**Plans:** 3 plans

Plans:
- [x] 05-01-PLAN.md — Script hardening: fix --help/exit-code compliance in validate-local.sh and run-fixture-tests.sh
- [x] 05-02-PLAN.md — E2E integration test script (scaffold -> validate -> score -> generate -> verify)
- [x] 05-03-PLAN.md — Self-test CI workflow + scripts/README.md documentation

---

## Approach Selection

**Primary:** Bash + jq + ajv-cli + GitHub Actions
- Language-agnostic for contributors
- JSON Schema Draft-07 (consistent with multi-cli-harness)
- GitHub-native CI (free for public repos)

**Discarded:** Node.js custom validator (overkill), Python tooling (runtime dependency), Docker CI (unnecessary overhead), monorepo tooling (plugins are declarative, not compiled)

---

## Risk Register

| Risk | Prob | Impact | Mitigation |
|------|------|--------|------------|
| Schema divergence between plugins | High | Medium | Optional fields, validate during Phase 1, adjust schema |
| Naming convention conflicts | High | Low | Per-plugin configurable conventions field |
| CI flakiness from npm install | Medium | Medium | Pin versions, cache node_modules |
| Auto-commit conflicts on publish | Medium | Medium | Merge queue or retry logic |
| Scope creep into runtime validation | Medium | High | Explicit non-goal, structural only |

---

## Decision Log

| Decision | Chosen | Rationale |
|----------|--------|-----------|
| Validation language | Bash + jq + ajv-cli | Language-agnostic, no build step |
| CI platform | GitHub Actions | Native, free, no extra service |
| Schema dialect | JSON Schema Draft-07 | Consistent with multi-cli-harness |
| Plugin onboarding | Direct directory inclusion | Simplest, no coupling to external repos |
| marketplace.json generation | Auto-generated on CI | Eliminates drift from manual edits |
| Quality scoring | Numeric 0-100 | Gradation vs binary pass/fail |
| Naming enforcement | Per-plugin configurable | Respects existing diversity |

---

## Iteration Strategy

| Metric | Acceptable | Iterate If |
|--------|-----------|------------|
| CI run time | < 3 min | > 5 min for 3 runs |
| Validation false positives | 0/week | > 2 per 2 weeks |
| Quality score spread | All >= 60 | Any < 50 |
| Onboarding time | < 15 min | > 20 min |
| marketplace.json drift | 0 | Manual edit detected |

**Review points:** After Phase 1 (schema calibration), After Phase 3 (rubric tuning), After Phase 5 (full retrospective).
