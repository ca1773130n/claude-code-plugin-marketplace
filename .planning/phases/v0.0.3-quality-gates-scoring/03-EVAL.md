# Phase 3: Quality Gates & Scoring - Evaluation Plan

**Phase Goal:** Quality rubric, branch protection, scoring in CI

**Success Criteria:**
- Both plugins scored; GRD >= 70, multi-cli-harness >= 75
- No PR merges with failing validation
- Quality score visible in every PR check output

---

## Tier 1: Sanity Checks (< 10 seconds)

Fast, automated checks that must pass before deeper validation. These run on every commit/PR.

### 1.1 Script Syntax & Structure

**Metric:** All shell scripts pass shellcheck and are executable

**Commands:**
```bash
# Validate score-plugin.sh syntax
shellcheck scripts/score-plugin.sh

# Verify executable permissions
test -x scripts/score-plugin.sh && echo "PASS" || echo "FAIL"

# Check for required functions
grep -q "calculate_documentation_score" scripts/score-plugin.sh && \
grep -q "calculate_testing_score" scripts/score-plugin.sh && \
grep -q "calculate_reliability_score" scripts/score-plugin.sh && \
grep -q "calculate_integration_score" scripts/score-plugin.sh && \
grep -q "calculate_maintenance_score" scripts/score-plugin.sh && \
echo "PASS: All scoring functions present" || echo "FAIL: Missing scoring functions"
```

**Pass Criteria:**
- Zero shellcheck errors or warnings
- Script is executable (`chmod +x`)
- All 5 category scoring functions present

### 1.2 Schema Validation

**Metric:** marketplace.schema.json includes quality score fields

**Commands:**
```bash
# Check schema has quality_score object
jq -e '.properties.quality_score' schemas/marketplace.schema.json > /dev/null && \
echo "PASS" || echo "FAIL"

# Verify required score fields
jq -e '.properties.quality_score.properties.overall' schemas/marketplace.schema.json > /dev/null && \
jq -e '.properties.quality_score.properties.category_scores' schemas/marketplace.schema.json > /dev/null && \
echo "PASS: Required score fields present" || echo "FAIL"
```

**Pass Criteria:**
- Schema includes `quality_score` object
- Contains `overall`, `category_scores`, and `last_scored` fields
- All fields have proper type definitions

### 1.3 Workflow Syntax

**Metric:** GitHub Actions workflow files are valid YAML

**Commands:**
```bash
# Validate YAML syntax for validation workflow
yamllint .github/workflows/validate-plugins.yml || \
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/validate-plugins.yml'))" && \
echo "PASS" || echo "FAIL"

# Check for scoring step in workflow
grep -q "score-plugin.sh" .github/workflows/validate-plugins.yml && \
echo "PASS: Scoring step present" || echo "FAIL"
```

**Pass Criteria:**
- Valid YAML syntax (no parse errors)
- Workflow includes quality scoring step
- PR comment action configured

### 1.4 Documentation Exists

**Metric:** Required documentation files are present

**Commands:**
```bash
# Check for QUALITY.md
test -f QUALITY.md && echo "PASS" || echo "FAIL"

# Check for scoring documentation
test -f .planning/phases/03-quality-gates-scoring/QUALITY.md && echo "PASS" || echo "FAIL"

# Verify QUALITY.md has all sections
grep -q "## Scoring Categories" QUALITY.md && \
grep -q "## Scoring Rules" QUALITY.md && \
grep -q "## Minimum Thresholds" QUALITY.md && \
echo "PASS: All sections present" || echo "FAIL"
```

**Pass Criteria:**
- QUALITY.md exists in repository root
- Contains sections for categories, rules, and thresholds
- Planning documentation complete

---

## Tier 2: Proxy Metrics (< 2 minutes)

Automated metrics that approximate real quality without human review.

### 2.1 Plugin Quality Scores

**Metric:** Both plugins meet minimum score thresholds

**Commands:**
```bash
# Score GRD plugin
./scripts/score-plugin.sh plugins/GRD > /tmp/grd-score.json
grd_score=$(jq -r '.quality_score.overall' /tmp/grd-score.json)
echo "GRD Score: $grd_score"
test "$grd_score" -ge 70 && echo "PASS" || echo "FAIL"

# Score multi-cli-harness plugin
./scripts/score-plugin.sh plugins/multi-cli-harness > /tmp/mch-score.json
mch_score=$(jq -r '.quality_score.overall' /tmp/mch-score.json)
echo "Multi-CLI-Harness Score: $mch_score"
test "$mch_score" -ge 75 && echo "PASS" || echo "FAIL"
```

**Pass Criteria:**
- GRD plugin: overall score >= 70
- multi-cli-harness plugin: overall score >= 75
- No JSON parsing errors
- All 5 category scores computed

### 2.2 Scoring Rule Coverage

**Metric:** All 28 scoring rules are implemented and tested

**Commands:**
```bash
# Count implemented rules in score-plugin.sh
rule_count=$(grep -c "# Rule [0-9]" scripts/score-plugin.sh || echo 0)
echo "Implemented Rules: $rule_count / 28"
test "$rule_count" -eq 28 && echo "PASS" || echo "FAIL"

# Verify each category has rules
for category in documentation testing reliability integration maintenance; do
  grep -q "calculate_${category}_score" scripts/score-plugin.sh && \
  echo "PASS: $category category implemented" || echo "FAIL: $category missing"
done
```

**Pass Criteria:**
- Exactly 28 rules implemented (as specified in plan)
- All 5 categories have scoring functions
- Rule numbering is sequential and complete

### 2.3 Marketplace JSON Generation

**Metric:** marketplace.json includes valid quality scores

**Commands:**
```bash
# Generate marketplace.json
./scripts/generate-marketplace.sh

# Validate JSON structure
jq empty marketplace.json && echo "PASS: Valid JSON" || echo "FAIL"

# Check each plugin has quality_score
for plugin in $(jq -r '.plugins[].id' marketplace.json); do
  has_score=$(jq -r ".plugins[] | select(.id==\"$plugin\") | .quality_score.overall" marketplace.json)
  if [ -n "$has_score" ] && [ "$has_score" != "null" ]; then
    echo "PASS: $plugin has quality score ($has_score)"
  else
    echo "FAIL: $plugin missing quality score"
  fi
done
```

**Pass Criteria:**
- marketplace.json generates without errors
- Valid JSON syntax
- All plugins have `quality_score` object with `overall` field
- Scores are numeric values (0-100)

### 2.4 Score Consistency

**Metric:** Scoring is deterministic (same input = same output)

**Commands:**
```bash
# Score GRD twice
./scripts/score-plugin.sh plugins/GRD > /tmp/grd-run1.json
./scripts/score-plugin.sh plugins/GRD > /tmp/grd-run2.json

# Compare overall scores
score1=$(jq -r '.quality_score.overall' /tmp/grd-run1.json)
score2=$(jq -r '.quality_score.overall' /tmp/grd-run2.json)
test "$score1" -eq "$score2" && echo "PASS: Consistent scoring" || echo "FAIL"

# Compare all category scores
diff <(jq -S '.quality_score.category_scores' /tmp/grd-run1.json) \
     <(jq -S '.quality_score.category_scores' /tmp/grd-run2.json) && \
echo "PASS: Category scores consistent" || echo "FAIL"
```

**Pass Criteria:**
- Multiple runs produce identical scores
- No randomness in scoring logic
- Timestamps may differ but scores must match

### 2.5 CI Workflow Integration

**Metric:** Quality scoring runs in CI and produces output

**Commands:**
```bash
# Simulate CI run (local validation)
cd /tmp && git clone /Users/edward.seo/dev/private/project/harness/claude-plugin-marketplace test-ci
cd test-ci

# Run validation workflow steps
./scripts/validate-plugin.sh plugins/GRD
./scripts/score-plugin.sh plugins/GRD > grd-score.json

# Check score is captured
jq -e '.quality_score.overall' grd-score.json > /dev/null && \
echo "PASS: CI produces score output" || echo "FAIL"

# Cleanup
cd /tmp && rm -rf test-ci
```

**Pass Criteria:**
- Validation script runs without errors
- Score output is valid JSON
- Score can be extracted for PR comments
- Exit code reflects validation status

### 2.6 Branch Protection Configuration

**Metric:** GitHub branch protection enforces validation

**Commands:**
```bash
# Check if branch protection is configured (requires gh CLI and repo access)
gh api repos/:owner/:repo/branches/main/protection --jq '.required_status_checks.contexts[]' 2>/dev/null | \
grep -q "validate-plugins" && echo "PASS" || echo "WARN: Check branch protection manually"

# Verify workflow is required check
echo "Manual verification required:"
echo "1. Go to Settings > Branches > main"
echo "2. Verify 'validate-plugins / validate' is required"
echo "3. Verify 'Require status checks to pass before merging' is enabled"
```

**Pass Criteria:**
- Branch protection enabled on `main`
- `validate-plugins` workflow is required check
- No merges allowed if validation fails
- Manual verification documented

---

## Tier 3: Deferred Validation (Manual/Integration)

Tests requiring human judgment, real PRs, or external integration.

### 3.1 Real PR Testing

**Metric:** Quality scoring works in actual GitHub PR flow

**Test Procedure:**
1. Create test branch: `git checkout -b test/quality-scoring`
2. Make a change to a plugin (e.g., update GRD README)
3. Push and create PR
4. Verify CI runs validation workflow
5. Check PR comment shows quality score
6. Verify score changes reflected in comment

**Pass Criteria:**
- [ ] Workflow triggers on PR creation/update
- [ ] Quality score appears in PR checks
- [ ] PR comment shows formatted score breakdown
- [ ] Score updates when changes pushed
- [ ] Failed validation blocks merge

**Evidence:** Screenshot of PR check + comment

### 3.2 Score Accuracy Review

**Metric:** Domain expert validates scoring makes sense

**Review Process:**
1. Generate quality report for both plugins
2. Review each category score against plugin reality
3. Check if rules fairly represent quality indicators
4. Validate weightings make sense

**Questions for Reviewer:**
- Does documentation score reflect actual doc quality?
- Are testing scores fair given test coverage?
- Do reliability indicators match real robustness?
- Is integration score meaningful for the plugin type?
- Are maintenance signals accurate?

**Pass Criteria:**
- [ ] No obvious scoring bugs or inversions
- [ ] Category weightings feel balanced
- [ ] Scores differentiate quality levels
- [ ] Thresholds (70/75) are achievable but meaningful
- [ ] Domain expert approves scoring logic

**Evidence:** Review notes with specific examples

### 3.3 Developer Experience

**Metric:** Contributors understand and can act on quality scores

**User Testing:**
1. Give developer a plugin with low score (< 50)
2. Show them the quality report
3. Ask them to improve one category
4. Measure time to understand what to fix
5. Verify score increases after fix

**Pass Criteria:**
- [ ] Developer can identify low-scoring categories in < 30 seconds
- [ ] QUALITY.md explains how to improve scores
- [ ] Changes targeting specific rules increase that category score
- [ ] Feedback feels actionable, not arbitrary
- [ ] No confusion about scoring methodology

**Evidence:** User testing notes + before/after scores

### 3.4 Edge Case Handling

**Metric:** Scoring handles unusual plugin structures gracefully

**Test Cases:**
```bash
# Test 1: Plugin with no tests
mkdir -p /tmp/no-tests-plugin
echo '{"name":"test"}' > /tmp/no-tests-plugin/manifest.json
./scripts/score-plugin.sh /tmp/no-tests-plugin
# Expected: Low testing score, but no crash

# Test 2: Plugin with minimal manifest
mkdir -p /tmp/minimal-plugin
echo '{"name":"min","version":"1.0.0"}' > /tmp/minimal-plugin/manifest.json
./scripts/score-plugin.sh /tmp/minimal-plugin
# Expected: Low scores, but valid JSON output

# Test 3: Plugin with all optional fields
# Create comprehensive manifest with all fields
# Expected: High scores across categories

# Test 4: Invalid plugin path
./scripts/score-plugin.sh /nonexistent/path
# Expected: Clear error message, non-zero exit
```

**Pass Criteria:**
- [ ] No crashes on unusual inputs
- [ ] Graceful degradation for missing files
- [ ] Clear error messages for invalid plugins
- [ ] Scores range appropriately (0-100)
- [ ] Edge cases documented in QUALITY.md

**Evidence:** Test output logs

### 3.5 Performance at Scale

**Metric:** Scoring remains fast with many plugins

**Load Test:**
```bash
# Simulate marketplace with 50 plugins
time for i in {1..50}; do
  ./scripts/score-plugin.sh plugins/GRD > /tmp/score-$i.json
done

# Measure total time
# Expected: < 5 seconds for 50 plugins (100ms each)

# Generate marketplace with all plugins
time ./scripts/generate-marketplace.sh
# Expected: < 10 seconds total
```

**Pass Criteria:**
- [ ] Single plugin scores in < 200ms
- [ ] 50 plugins score in < 10 seconds
- [ ] marketplace.json generates in < 15 seconds
- [ ] No memory leaks or resource exhaustion
- [ ] CI job completes in < 2 minutes

**Evidence:** Timing measurements

### 3.6 Score Stability Over Time

**Metric:** Scores don't drift without plugin changes

**Long-term Validation:**
1. Score all plugins today
2. Wait 1 week with no changes
3. Score again and compare
4. Check for any score drift

**Pass Criteria:**
- [ ] Scores identical if no code changes
- [ ] Timestamps update but scores stable
- [ ] No environment-dependent variation
- [ ] Git state doesn't affect scoring
- [ ] Reproducible across machines

**Evidence:** Score comparison reports

---

## Summary Dashboard

Run all Tier 1 + Tier 2 checks at once:

```bash
#!/bin/bash
# Quick validation script

echo "=== TIER 1: SANITY CHECKS ==="
echo -n "Script syntax: "
shellcheck scripts/score-plugin.sh && echo "✓ PASS" || echo "✗ FAIL"

echo -n "Schema validation: "
jq -e '.properties.quality_score' schemas/marketplace.schema.json > /dev/null && echo "✓ PASS" || echo "✗ FAIL"

echo -n "Documentation: "
test -f QUALITY.md && echo "✓ PASS" || echo "✗ FAIL"

echo ""
echo "=== TIER 2: PROXY METRICS ==="
echo "GRD Plugin Score:"
./scripts/score-plugin.sh plugins/GRD | jq '.quality_score'

echo ""
echo "Multi-CLI-Harness Score:"
./scripts/score-plugin.sh plugins/multi-cli-harness | jq '.quality_score'

echo ""
echo "Rule Coverage:"
grep -c "# Rule [0-9]" scripts/score-plugin.sh
echo "Expected: 28"

echo ""
echo "=== TIER 3: MANUAL VALIDATION ==="
echo "[ ] Real PR testing complete"
echo "[ ] Score accuracy reviewed"
echo "[ ] Developer experience validated"
echo "[ ] Edge cases tested"
echo "[ ] Performance acceptable"
echo "[ ] Score stability confirmed"
```

**Overall Pass Criteria:**
- All Tier 1 checks pass (blockers)
- >= 90% of Tier 2 checks pass (quality gates)
- >= 4/6 Tier 3 validations complete with evidence (confidence)

---

## Appendix: Quick Reference

### Run All Automated Checks
```bash
# From repository root
./scripts/validate-plugin.sh plugins/GRD
./scripts/score-plugin.sh plugins/GRD | jq
./scripts/generate-marketplace.sh
jq '.plugins[].quality_score' marketplace.json
```

### Debug Scoring Issues
```bash
# Enable verbose mode (if implemented)
DEBUG=1 ./scripts/score-plugin.sh plugins/GRD

# Check individual categories
./scripts/score-plugin.sh plugins/GRD | jq '.quality_score.category_scores'

# Validate against schema
jq -e '.' marketplace.json
ajv validate -s schemas/marketplace.schema.json -d marketplace.json
```

### CI Debugging
```bash
# Run locally with act (GitHub Actions local runner)
act pull_request -W .github/workflows/validate-plugins.yml

# Check workflow syntax
actionlint .github/workflows/validate-plugins.yml
```

---

**Last Updated:** 2026-02-12
**Phase Status:** Ready for implementation
**Next Review:** After initial scoring engine implementation
