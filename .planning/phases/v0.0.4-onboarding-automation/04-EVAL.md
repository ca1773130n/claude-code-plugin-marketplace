# Evaluation Plan: Phase 4 — Plugin Onboarding Automation

**Designed:** 2026-02-15
**Designer:** Claude (grd-eval-planner)
**Method(s) evaluated:** Template scaffolding, bash scripting portability, GitHub templates, contributor onboarding
**Reference papers:** None (infrastructure engineering phase)

## Evaluation Overview

Phase 4 creates the complete onboarding toolchain that lets a new contributor scaffold a plugin, validate it locally, and submit a PR in under 10 minutes. The phase delivers 4 plans across 2 waves:

**Wave 1 (Independent):**
- 04-01: Plugin template scaffold + validate-local.sh
- 04-02: GitHub Issue/PR templates

**Wave 2 (Depends on Wave 1):**
- 04-03: new-plugin.sh scaffolding script
- 04-04: CONTRIBUTING.md contributor guide

The evaluation focuses on **functional correctness** (does the scaffold work), **cross-platform portability** (macOS Bash 3.2 + Linux Bash 5.x), and **quality optimization** (scaffold achieves >= 40 score, stretch goal >= 90). There is no paper evaluation methodology to reference — this is pure infrastructure engineering validated against the project's own quality rubric.

**Critical success criteria from ROADMAP.md:**
1. Scaffold passes validation with score >= 40 (required)
2. New contributor zero-to-PR in < 10 minutes (UX target)
3. PR template covers all quality gate requirements (completeness)

**Primary technical risk:** macOS BSD sed vs GNU sed incompatibility. Research identifies jq-based JSON generation and no-sed-i patterns as the mitigation strategy.

### Metric Sources

| Metric | Source | Why This Metric |
|--------|--------|----------------|
| Scaffold quality score >= 40 | ROADMAP.md Phase 4 success criterion | Hard requirement for phase completion |
| Scaffold validates successfully | Phase 1-3 validation tooling | Fundamental — invalid scaffold breaks onboarding |
| Script portability (Bash 3.2 + 5.x) | CLAUDE.md project constraint, 04-RESEARCH.md | macOS dev environment uses Bash 3.2.57 |
| Template achieves >= 90 score | 04-RESEARCH.md recommendation | Maximalist template — contributors start strong |
| Onboarding time < 10 minutes | ROADMAP.md Phase 4 success criterion | UX target, deferred to user testing |
| Fixture tests still pass | Phase 1 regression prevention | No regression to existing validation |

### Verification Level Summary

| Level | Count | Purpose |
|-------|-------|---------|
| Sanity (L1) | 12 | Functional verification — does it work on this machine |
| Proxy (L2) | 6 | Cross-platform checks — does it generalize |
| Deferred (L3) | 4 | Integration and user trials |

## Level 1: Sanity Checks

**Purpose:** Verify basic functionality. These MUST ALL PASS before declaring phase complete.

### S1: Template Directory Structure Exists
- **What:** Verify `templates/plugin-template/` exists with expected structure
- **Command:** `ls -R /Users/edward.seo/dev/private/project/harness/claude-plugin-marketplace/templates/plugin-template/`
- **Expected:** Directories present: `.claude-plugin/`, `agents/`, `commands/`. Files present: `CLAUDE.md`, `README.md`, `CHANGELOG.md`, `VERSION`
- **Failure means:** Template was not created — Plan 04-01 incomplete

### S2: Template Passes Schema Validation
- **What:** Template plugin.json conforms to schemas/plugin.schema.json
- **Command:** `./scripts/validate-plugin.sh templates/plugin-template`
- **Expected:** Exit code 0, no validation errors
- **Failure means:** Template manifest is malformed — violates schema

### S3: Template Achieves Quality Score >= 40
- **What:** Template meets minimum quality threshold
- **Command:** `./scripts/score-plugin.sh templates/plugin-template --json | jq .total`
- **Expected:** Numeric value >= 40
- **Failure means:** Phase 4 success criterion unmet

### S4: Template Achieves Stretch Goal >= 90 (Stretch Target)
- **What:** Template optimized to start contributors at near-perfect score
- **Command:** `./scripts/score-plugin.sh templates/plugin-template --json | jq .total`
- **Expected:** Numeric value >= 90
- **Failure means:** Template not optimized — acceptable if >= 40, but indicates room for improvement

### S5: new-plugin.sh Accepts Valid Plugin Name
- **What:** Scaffolding script runs successfully with valid input
- **Command:** `./scripts/new-plugin.sh test-scaffold-plugin && ls -la plugins/test-scaffold-plugin/`
- **Expected:** Directory `plugins/test-scaffold-plugin/` created with complete structure, script exits 0
- **Failure means:** Scaffolding script broken — core functionality failed

### S6: new-plugin.sh Generated Plugin Validates
- **What:** Output of scaffolding script is a valid plugin
- **Command:** `./scripts/validate-plugin.sh plugins/test-scaffold-plugin`
- **Expected:** Exit code 0, no validation errors
- **Failure means:** Script generates invalid output — defeats purpose

### S7: new-plugin.sh Generated Plugin Scores >= 40
- **What:** Generated scaffold meets quality threshold
- **Command:** `./scripts/score-plugin.sh plugins/test-scaffold-plugin --json | jq .total`
- **Expected:** Numeric value >= 40
- **Failure means:** Script regression from template quality

### S8: new-plugin.sh Rejects Invalid Plugin Name
- **What:** Input validation prevents schema violations
- **Command:** `./scripts/new-plugin.sh "INVALID NAME" 2>&1; echo $?`
- **Expected:** Exit code 1 or 2, error message contains "lowercase" or "pattern"
- **Failure means:** No input validation — will generate invalid plugins

### S9: new-plugin.sh Shows Usage on Missing Args
- **What:** User-friendly CLI behavior
- **Command:** `./scripts/new-plugin.sh 2>&1; echo $?`
- **Expected:** Exit code 2, output contains "Usage:" or "required"
- **Failure means:** Poor UX — no guidance on errors

### S10: validate-local.sh Works on Existing Plugin
- **What:** Local validation wrapper functions correctly
- **Command:** `./scripts/validate-local.sh plugins/GRD`
- **Expected:** Exit code 0, output contains validation result and quality score
- **Failure means:** Wrapper broken — onboarding flow incomplete

### S11: Fixture Tests Still Pass (No Regression)
- **What:** Phase 4 changes do not break Phase 1-3 validation
- **Command:** `./scripts/run-fixture-tests.sh`
- **Expected:** Exit code 0, all 9 fixtures pass/fail as expected
- **Failure means:** Regression in validation logic

### S12: Generated plugin.json is Valid JSON
- **What:** jq-based generation produces parseable JSON
- **Command:** `jq . plugins/test-scaffold-plugin/.claude-plugin/plugin.json > /dev/null; echo $?`
- **Expected:** Exit code 0 (valid JSON)
- **Failure means:** JSON generation broken — syntax errors

**Sanity gate:** ALL sanity checks must pass. Any failure blocks phase progression.

## Level 2: Proxy Metrics

**Purpose:** Indirect evaluation of quality and portability.
**IMPORTANT:** Proxy metrics are NOT validated substitutes for full evaluation. Treat results with appropriate skepticism.

### P1: Template README Line Count >= 50
- **What:** Documentation completeness proxy
- **How:** Count lines in template README.md
- **Command:** `wc -l < templates/plugin-template/README.md`
- **Target:** >= 50 lines
- **Evidence:** QUALITY.md Rule 11 deducts 3 points for README < 50 lines. This is a direct check.
- **Correlation with full metric:** HIGH — scoring code checks this exact condition
- **Blind spots:** Line count != quality. A 50-line README can be poorly written.
- **Validated:** No — awaiting deferred validation at Phase 5 integration testing

### P2: Bash 3.2 Compatibility on Local Machine
- **What:** Portability verification on macOS Bash 3.2
- **How:** Run all scripts on local Bash 3.2.57
- **Command:** `bash --version && ./scripts/new-plugin.sh test-compat && ./scripts/validate-local.sh plugins/test-compat`
- **Target:** Exit code 0, no "command not found" or "syntax error"
- **Evidence:** CLAUDE.md constraint: "macOS bash 3.x compatibility" required. Local system is Bash 3.2.57.
- **Correlation with full metric:** MEDIUM — proves local compatibility but not Linux Bash 5.x
- **Blind spots:** Does not test GNU sed/find behavior differences
- **Validated:** No — awaiting deferred validation on CI (Ubuntu Bash 5.x)

### P3: No sed -i Usage in Scripts
- **What:** Portability anti-pattern check
- **How:** Grep for `sed -i` in all new scripts
- **Command:** `grep -r "sed -i" scripts/new-plugin.sh scripts/validate-local.sh; echo $?`
- **Target:** Exit code 1 (no matches found)
- **Evidence:** 04-RESEARCH.md Pitfall 1 — sed -i is the #1 portability failure (BSD vs GNU)
- **Correlation with full metric:** HIGH — sed -i will definitively fail on one platform or the other
- **Blind spots:** Absence of sed -i doesn't guarantee full portability (other flags may differ)
- **Validated:** No — awaiting deferred validation on CI

### P4: Template Agent Naming Follows Convention
- **What:** Agent file uses plugin-name prefix
- **How:** Check agent filename matches pattern `{{name}}-*.md`
- **Command:** `ls templates/plugin-template/agents/ | grep -E '^{{name}}-.*\.md$' | wc -l`
- **Target:** >= 1 (at least one agent with placeholder prefix)
- **Evidence:** QUALITY.md Rule 20 — inconsistent agent naming deducts 4 points
- **Correlation with full metric:** HIGH — directly establishes prefix convention
- **Blind spots:** Placeholder substitution correctness verified by S6, not this check
- **Validated:** No — awaiting deferred validation via user onboarding trial

### P5: GitHub Issue Template YAML Renders
- **What:** Issue form structure is valid
- **How:** Visual inspection of `.github/ISSUE_TEMPLATE/plugin-request.yml` on GitHub
- **Command:** Manual check after merge — visit `https://github.com/<repo>/issues/new/choose`
- **Target:** Form fields render correctly with dropdowns, required indicators
- **Evidence:** GitHub Docs "Syntax for issue forms" — YAML forms provide structured input
- **Correlation with full metric:** MEDIUM — rendering confirms syntax but not UX quality
- **Blind spots:** Does not verify that form fields actually guide contributors effectively
- **Validated:** No — awaiting deferred validation via user trial

### P6: GitHub PR Template Markdown Renders
- **What:** PR template displays correctly in PR creation
- **How:** Visual inspection on GitHub
- **Command:** Manual check after merge — create a test PR and verify template appears
- **Target:** Template sections appear with checkboxes, headings formatted
- **Evidence:** GitHub Docs "About pull request templates" — Markdown templates auto-populate
- **Correlation with full metric:** MEDIUM — rendering confirms structure but not completeness
- **Blind spots:** Does not verify all quality gates are covered in checklist
- **Validated:** No — awaiting deferred validation via user trial

## Level 3: Deferred Validations

**Purpose:** Full evaluation requiring integration or resources not available now.

### D1: Full Onboarding Flow < 10 Minutes — DEFER-04-01
- **What:** End-to-end onboarding time measurement with real contributor
- **How:** Time a volunteer contributor from zero to submitted PR
- **Why deferred:** Requires a real contributor trial (not available during phase execution)
- **Validates at:** Phase 5 integration testing
- **Depends on:** Phase 4 complete, volunteer contributor recruited
- **Target:** < 10 minutes (ROADMAP.md success criterion)
- **Risk if unmet:** UX target missed — indicates friction in onboarding flow. Mitigation: Iterate on CONTRIBUTING.md clarity, add screencast/walkthrough.
- **Fallback:** If 10-20 minutes, acceptable for Phase 4 — iterate in Phase 5. If > 20 minutes, critical — requires redesign.

### D2: CI Runs on Scaffold-Generated Plugin PR — DEFER-04-02
- **What:** GitHub Actions validates a plugin generated by new-plugin.sh
- **How:** Submit PR with scaffold output, verify validate-plugins.yml runs
- **Why deferred:** Requires actual PR submission and CI environment
- **Validates at:** Phase 5 integration testing
- **Depends on:** Phase 4 complete, test PR created
- **Target:** validate-plugins.yml runs successfully, score comment posted
- **Risk if unmet:** CI integration broken — scaffolded plugins cannot be submitted. Mitigation: Debug filter configuration in validate-plugins.yml.
- **Fallback:** Manual validation workaround for Phase 4, fix CI in Phase 5

### D3: Cross-Platform Portability on CI (Ubuntu Bash 5.x) — DEFER-04-03
- **What:** Verify scripts work on GitHub Actions Ubuntu runner
- **How:** CI runs new-plugin.sh as part of self-test or integration test
- **Why deferred:** Requires CI environment (Bash 5.x, GNU sed/find)
- **Validates at:** Phase 5 integration testing (self-test.yml workflow)
- **Depends on:** Phase 4 scripts committed, self-test workflow created
- **Target:** All scripts exit 0 on Ubuntu with Bash 5.x
- **Risk if unmet:** Portability failure — scripts work on macOS dev but fail in CI. Mitigation: Fix GNU/BSD differences identified by CI errors.
- **Fallback:** Detect platform in scripts and branch behavior (not ideal but functional)

### D4: Real Contributor Submission with Templates — DEFER-04-04
- **What:** External contributor uses Issue template, scaffold, and PR template
- **How:** Wait for first external plugin submission after Phase 4 merge
- **Why deferred:** Requires organic contributor participation
- **Validates at:** Post-Phase 5, during marketplace operation
- **Depends on:** Phase 4 merged to main, marketplace publicized
- **Target:** Contributor completes onboarding without requesting help in issues/chat
- **Risk if unmet:** Onboarding flow has undiscovered friction. Mitigation: Contributor feedback loop, iterate on CONTRIBUTING.md and templates.
- **Fallback:** Proactively recruit beta tester, gather feedback before public launch

## Ablation Plan

**Purpose:** Isolate component contributions.

### A1: Minimalist Template vs. Maximalist Template
- **Condition:** Create a minimal template with only required fields vs. full template with all optional fields
- **Expected impact:** Minimal template scores ~40, maximalist template scores 90+ (based on QUALITY.md rule-by-rule analysis in 04-RESEARCH.md)
- **Command:** Compare `score-plugin.sh minimal-template --json` vs `score-plugin.sh templates/plugin-template --json`
- **Evidence:** 04-RESEARCH.md "Scaffold Quality Score Analysis" shows 100/100 possible with all fields populated

### A2: validate-local.sh Wrapper vs. Direct Script Calls
- **Condition:** Measure contributor UX with wrapper vs. requiring them to call validate-plugin.sh and score-plugin.sh separately
- **Expected impact:** Wrapper reduces cognitive load, unclear if it reduces onboarding time
- **Command:** User trial A/B test (deferred)
- **Evidence:** Anecdotal — wrappers improve UX, but no data specific to this project

### A3: YAML Issue Form vs. Markdown Issue Template
- **Condition:** GitHub supports both formats — compare structured YAML form vs. freeform Markdown
- **Expected impact:** YAML form provides validation and reduces incomplete submissions (GitHub Docs claim)
- **Command:** Historical analysis post-deployment — compare issue quality before/after
- **Evidence:** GitHub Docs "Syntax for issue forms" — YAML adds validation and dropdowns

## Baselines

| Baseline | Description | Expected Score | Source |
|----------|-------------|----------------|--------|
| Manual plugin creation (no scaffold) | Current state — contributor manually creates all files | 30-60 (high variance) | ROADMAP.md assumption |
| GRD plugin | Existing plugin with agents, commands, docs | 79/100 | Phase 3 scoring results |
| multi-cli-harness plugin | Existing plugin with full structure | 83/100 | Phase 3 scoring results |
| Minimalist valid plugin | Bare minimum to pass schema | 20-30 | Theoretical — missing most optional fields |

## Evaluation Scripts

**Location of evaluation code:**
```
scripts/validate-plugin.sh   -- Layer 1+2 validation (existing)
scripts/score-plugin.sh      -- Quality scoring (existing)
scripts/run-fixture-tests.sh -- Fixture regression tests (existing)
scripts/new-plugin.sh        -- To be created in Plan 04-03
scripts/validate-local.sh    -- To be created in Plan 04-01
```

**How to run full evaluation:**
```bash
# Prerequisite: npm dependencies installed
npm ci

# Clean slate — remove any previous test scaffolds
rm -rf plugins/test-scaffold-plugin plugins/test-compat

# Run all sanity checks
echo "=== S1: Template structure ==="
ls -R templates/plugin-template/

echo "=== S2: Template validation ==="
./scripts/validate-plugin.sh templates/plugin-template

echo "=== S3: Template score >= 40 ==="
./scripts/score-plugin.sh templates/plugin-template --json | jq '.total >= 40'

echo "=== S4: Template score >= 90 (stretch) ==="
./scripts/score-plugin.sh templates/plugin-template

echo "=== S5: Scaffold valid plugin ==="
./scripts/new-plugin.sh test-scaffold-plugin

echo "=== S6: Scaffold validation ==="
./scripts/validate-plugin.sh plugins/test-scaffold-plugin

echo "=== S7: Scaffold score >= 40 ==="
./scripts/score-plugin.sh plugins/test-scaffold-plugin --json | jq '.total >= 40'

echo "=== S8: Reject invalid name ==="
./scripts/new-plugin.sh "INVALID NAME" 2>&1 | grep -i "error"

echo "=== S9: Usage on missing args ==="
./scripts/new-plugin.sh 2>&1 | grep -i "usage"

echo "=== S10: validate-local.sh wrapper ==="
./scripts/validate-local.sh plugins/GRD

echo "=== S11: Fixture tests ==="
./scripts/run-fixture-tests.sh

echo "=== S12: Valid JSON ==="
jq . plugins/test-scaffold-plugin/.claude-plugin/plugin.json > /dev/null

# Run proxy checks
echo "=== P1: README line count ==="
wc -l < templates/plugin-template/README.md

echo "=== P2: Bash 3.2 compat ==="
bash --version
./scripts/new-plugin.sh test-compat
./scripts/validate-local.sh plugins/test-compat

echo "=== P3: No sed -i ==="
! grep -r "sed -i" scripts/new-plugin.sh scripts/validate-local.sh

echo "=== P4: Agent naming ==="
ls templates/plugin-template/agents/

echo "=== P5+P6: GitHub templates (manual) ==="
echo "After merge: Check https://github.com/<repo>/issues/new/choose"
echo "After merge: Create test PR and verify template appears"

# Cleanup
rm -rf plugins/test-scaffold-plugin plugins/test-compat

echo ""
echo "=== Evaluation Summary ==="
echo "Sanity checks: 12/12 must pass"
echo "Proxy checks: 6 (P5+P6 manual)"
echo "Deferred: 4 (await Phase 5)"
```

## Results Template

*To be filled by grd-eval-reporter after phase execution.*

### Sanity Results

| Check | Status | Output | Notes |
|-------|--------|--------|-------|
| S1: Template structure | | | |
| S2: Template validation | | | |
| S3: Template score >= 40 | | | |
| S4: Template score >= 90 | | | |
| S5: new-plugin.sh runs | | | |
| S6: Generated plugin validates | | | |
| S7: Generated score >= 40 | | | |
| S8: Reject invalid name | | | |
| S9: Show usage | | | |
| S10: validate-local.sh works | | | |
| S11: Fixture tests pass | | | |
| S12: Valid JSON | | | |

### Proxy Results

| Metric | Target | Actual | Status | Notes |
|--------|--------|--------|--------|-------|
| P1: README lines | >= 50 | | | |
| P2: Bash 3.2 compat | exit 0 | | | |
| P3: No sed -i | no matches | | | |
| P4: Agent naming | >= 1 match | | | |
| P5: Issue form renders | manual OK | | | |
| P6: PR template renders | manual OK | | | |

### Ablation Results

| Condition | Expected | Actual | Conclusion |
|-----------|----------|--------|------------|
| A1: Minimal vs. Maximalist | 40 vs. 90+ | | |
| A2: Wrapper vs. Direct | UX improvement | | |
| A3: YAML vs. Markdown | Validation benefit | | |

### Deferred Status

| ID | Metric | Status | Validates At |
|----|--------|--------|-------------|
| DEFER-04-01 | Onboarding < 10 min | PENDING | Phase 5 integration testing |
| DEFER-04-02 | CI runs on scaffold PR | PENDING | Phase 5 integration testing |
| DEFER-04-03 | Ubuntu Bash 5.x compat | PENDING | Phase 5 self-test.yml |
| DEFER-04-04 | Real contributor trial | PENDING | Post-Phase 5 operation |

## Evaluation Confidence

**Overall confidence in evaluation design:** HIGH

**Justification:**
- **Sanity checks:** Adequate — 12 checks cover all critical paths (template validity, script functionality, regression prevention). Each check is executable with clear pass/fail criteria.
- **Proxy metrics:** Well-evidenced — P1, P3, P4 directly verify scoring rules. P2 verifies local Bash 3.2 (known constraint). P5+P6 are manual but low-risk (GitHub template rendering is well-documented).
- **Deferred coverage:** Comprehensive — all integration points identified. D1 and D4 address the UX criterion (< 10 min onboarding). D2 and D3 address CI/portability verification.

**What this evaluation CAN tell us:**
- Template is valid and optimized (S2-S4)
- Scaffolding script generates valid output (S5-S7, S12)
- Scripts work on macOS Bash 3.2 (S1-S12, P2)
- No obvious portability anti-patterns (P3)
- Phase 1-3 functionality not regressed (S11)

**What this evaluation CANNOT tell us:**
- **Cross-platform portability:** Bash 5.x/GNU compatibility deferred to D3 (CI environment required)
- **Real onboarding time:** < 10 min target deferred to D1 (user trial required)
- **Template completeness:** PR template coverage of quality gates deferred to D4 (real contributor feedback required)
- **CI integration:** Scaffold PR flow deferred to D2 (GitHub Actions environment required)

**Evaluation limitations:**
- **Portability verification is incomplete in-phase:** We can prove macOS Bash 3.2 works (local testing) but cannot prove Linux Bash 5.x works without CI. Proxy P3 (no sed -i) is the strongest indicator, but other GNU/BSD differences could exist.
- **UX metrics are fully deferred:** The 10-minute onboarding target cannot be measured during phase execution. We rely on sanity checks proving functionality and defer time measurement to Phase 5.
- **Template quality optimization is based on static analysis:** The >= 90 score target is verified by running score-plugin.sh, which is a proxy for "good template design." Real quality requires contributor feedback (deferred to D4).

**Risk assessment:**
- **Low risk:** Sanity checks are comprehensive. If all 12 pass, phase is functionally complete.
- **Medium risk:** Portability. If D3 fails on CI, we'll need to debug GNU/BSD differences. Mitigation: P3 check reduces likelihood.
- **Low risk:** Quality target. >= 40 is achievable (S3), >= 90 is stretch (S4). If S4 fails but S3 passes, phase succeeds with room for iteration.

---

*Evaluation plan by: Claude (grd-eval-planner)*
*Design date: 2026-02-15*
