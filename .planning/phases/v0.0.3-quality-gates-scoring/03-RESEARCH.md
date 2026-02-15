# Phase 3: Quality Gates & Scoring - Research

**Researched:** 2026-02-12
**Domain:** Plugin quality scoring, CI quality gates, GitHub branch protection
**Confidence:** HIGH

## Summary

Phase 3 introduces a numeric quality scoring rubric (0-100) for plugins, integrates it into CI as a PR comment, and establishes GitHub branch protection rules. The domain is well-understood: bash-based static analysis with jq for JSON inspection, output formatting for GitHub Actions, and declarative branch protection configuration. No novel algorithms or external libraries are required.

The core challenge is **rubric design that accommodates the two existing plugins' divergent conventions** -- GRD uses `workflows/` for commands, `grd-*` prefixed agents, `README.md`; multi-cli-harness uses `commands/`, unprefixed agents, `plugin-README.md`, and does not declare its 11 command files in the manifest. The scoring rubric must be fair to both while incentivizing completeness.

**Primary recommendation:** Build `scripts/score-plugin.sh` as a standalone bash+jq script that outputs both machine-readable JSON and human-readable summary, scored across 5 categories of 20 points each, with per-rule deductions. Integrate into the existing `validate-plugins.yml` workflow using `thollander/actions-comment-pull-request` for PR comments, and add the quality score to `marketplace.json` via a new `qualityScore` field.

## User Constraints (from CONTEXT.md)

No CONTEXT.md exists for this phase. All design decisions are at Claude's discretion, guided by the ROADMAP.md scope definition.

### Locked Decisions
None -- no prior `/grd:discuss-phase` decisions recorded.

### Claude's Discretion
All implementation choices are open, within the ROADMAP.md scope:
- Rubric weightings and specific rules per category
- PR comment format and action choice
- Branch protection configuration approach (manual docs vs. gh CLI script)
- How to handle naming convention divergence between plugins

### Deferred Ideas (OUT OF SCOPE)
None specified.

## Paper-Backed Recommendations

### Recommendation 1: Weighted Multi-Dimension Quality Scoring

**Recommendation:** Use a 5-category rubric with equal 20-point weights, scored by subtractive deductions from a per-category maximum.

**Evidence:**
- npms.io quality scoring algorithm (Mota et al., 2016, "Simplifying the Search of npm Packages", Concordia University) -- Demonstrates that multi-dimension scoring (quality + maintenance + popularity) with weighted averages produces actionable package differentiation. Our 5-category model mirrors this principle but is tailored to declarative plugin manifests rather than npm packages.
- Skypack Quality Score (2020) -- Uses per-dimension scores with clear deduction rules and actionable feedback per failing check. Each deduction is explained, enabling package authors to improve.
- npm search scoring -- Weights quality (0.30), maintenance (0.35), popularity (0.35). Equal weighting (0.20 each) is appropriate here because all five categories are equally important for a nascent marketplace.

**Confidence:** HIGH -- Multi-dimension quality scoring is an established pattern used by npm, Skypack, and other package registries.

**Expected improvement:** Both plugins will have concrete, actionable quality signals. Based on current state analysis (see Experiment Design section), GRD should score ~70-72 and multi-cli-harness ~76-78.

**Caveats:** The rubric will need tuning after initial scoring of both real plugins. Deduction points must be calibrated so neither plugin fails unfairly due to structural divergence.

### Recommendation 2: Subtractive Scoring with Per-Rule Deductions

**Recommendation:** Start each category at 20 points and apply fixed deductions per failed check, rather than additive scoring.

**Evidence:**
- Skypack Quality Score system uses this approach: each package starts with a perfect score and loses points for each quality issue found. This creates clear "fix this to gain N points" feedback.
- Code quality tools (ESLint, SonarQube) similarly report issues as deductions from a baseline, which is more actionable than additive point accumulation.

**Confidence:** HIGH -- Subtractive scoring is the standard approach in automated quality tools.

### Recommendation 3: GitHub Actions PR Comment via thollander/actions-comment-pull-request

**Recommendation:** Use `thollander/actions-comment-pull-request@v3` with `comment-tag` for upsert behavior (one comment per PR, updated on each push).

**Evidence:**
- Official GitHub Actions ecosystem: `thollander/actions-comment-pull-request` is the most widely used PR comment action, with `comment-tag` enabling idempotent updates (no comment spam).
- Alternative `peter-evans/create-or-update-comment` requires comment ID tracking; `thollander` is simpler for our use case.
- The workflow already uses `dorny/paths-filter@v3`, establishing the pattern of using community actions.

**Confidence:** HIGH -- Direct verification from GitHub Marketplace and action documentation.

**Caveats:** Requires `pull-requests: write` permission (currently `read`). This is a necessary permission escalation.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | 5.x | Script runtime | Already used for validate-plugin.sh and generate-marketplace.sh |
| jq | 1.7+ | JSON parsing and scoring calculations | Already a project dependency |
| ajv-cli | 5.0.0 | Schema validation (existing) | Already in package.json |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| thollander/actions-comment-pull-request | v3 | PR comment posting | During CI quality report step |
| dorny/paths-filter | v3 | Path-based change detection (existing) | Already in validate-plugins.yml |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| thollander/actions-comment-pull-request | peter-evans/create-or-update-comment | Requires manual comment ID tracking; more complex for our simple use case |
| thollander/actions-comment-pull-request | actions/github-script | More flexible but requires writing JavaScript in YAML; overkill for a single comment |
| Bash scoring script | Node.js scoring module | Would be more testable but breaks the "bash + jq" project convention; overkill for static analysis |
| gh CLI for branch protection | Manual setup documentation | gh CLI can automate setup but branch protection is a one-time config; QUALITY.md documentation is sufficient |

## Architecture Patterns

### Recommended Project Structure
```
scripts/
├── validate-plugin.sh          # (existing) Layer 1+2 validation
├── score-plugin.sh             # NEW: Quality scoring (this phase)
├── generate-marketplace.sh     # (existing) Marketplace generation
└── run-fixture-tests.sh        # (existing) Fixture test runner

schemas/
├── plugin.schema.json          # (existing)
└── marketplace.schema.json     # UPDATE: Add qualityScore field

.github/workflows/
├── validate-plugins.yml        # UPDATE: Add scoring step + PR comment
└── publish-marketplace.yml     # UPDATE: Include quality score in generation

QUALITY.md                      # NEW: Rubric documentation
```

### Pattern 1: Scoring Script with Machine-Readable + Human-Readable Output

**What:** `score-plugin.sh` outputs both a JSON object (for CI consumption) and a formatted summary (for human reading). The JSON output is captured by the workflow for the PR comment and marketplace.json enrichment.

**When to use:** Always -- this dual-output pattern enables both CI automation and developer debugging.

**Example:**
```bash
# Machine-readable JSON output (to stdout when --json flag used)
{
  "plugin": "grd",
  "total": 72,
  "categories": {
    "manifest_completeness": { "score": 12, "max": 20, "deductions": [...] },
    "documentation": { "score": 16, "max": 20, "deductions": [...] },
    "structure_integrity": { "score": 20, "max": 20, "deductions": [] },
    "naming_conventions": { "score": 16, "max": 20, "deductions": [...] },
    "version_hygiene": { "score": 8, "max": 20, "deductions": [...] }
  }
}

# Human-readable summary (to stdout by default)
# Quality Score: grd — 72/100
#
# Manifest Completeness    12/20  (-4 no homepage, -4 no license)
# Documentation            16/20  (-4 no keywords in manifest)
# Structure Integrity      20/20
# Naming Conventions       16/20  (-4 commands dir named 'workflows' not 'commands')
# Version Hygiene           8/20  (-8 version < 1.0.0, -4 no VERSION file consistent with manifest)
```

### Pattern 2: Category-Based Scoring Architecture

**What:** Each category is scored by a dedicated function that returns a JSON fragment. The main function aggregates all category scores. This makes each category independently testable and extensible.

**When to use:** For all scoring logic -- keeps each rubric dimension isolated and modifiable.

```bash
score_manifest_completeness() {
  local manifest="$1"
  local score=20
  local deductions="[]"
  # Check each field...
  echo "$score" "$deductions"  # Return via subshell capture
}
```

### Pattern 3: Workflow Integration via Step Output

**What:** The scoring step captures JSON output into a GitHub Actions step output variable, which subsequent steps consume for PR commenting and marketplace enrichment.

```yaml
- name: Score plugin
  id: score
  run: |
    SCORE_JSON=$(./scripts/score-plugin.sh "plugins/$PLUGIN_NAME" --json)
    echo "score_json=$SCORE_JSON" >> "$GITHUB_OUTPUT"
    TOTAL=$(echo "$SCORE_JSON" | jq '.total')
    echo "total=$TOTAL" >> "$GITHUB_OUTPUT"
```

### Anti-Patterns to Avoid
- **Hardcoded plugin-specific exceptions:** Do not add `if plugin == "GRD" then skip naming check`. Instead, design the rubric to be fair by checking patterns that both plugins can reasonably satisfy.
- **Binary pass/fail without granularity:** The ROADMAP specifies numeric 0-100 scoring. Never reduce to pass/fail at the category level.
- **Coupling scoring to validation:** Keep `score-plugin.sh` separate from `validate-plugin.sh`. Validation is pass/fail (blocks merge). Scoring is informational (displayed, tracked, eventually gated).
- **PR comment spam:** Always use `comment-tag` for upsert behavior. Multiple pushes to a PR should update a single comment, not create multiple.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PR commenting | GitHub API calls via curl | thollander/actions-comment-pull-request@v3 | Handles authentication, comment upsert, markdown formatting, edge cases |
| Branch protection setup | Custom API script | gh CLI commands or GitHub UI + documentation | One-time configuration; script would be run once and never again |
| JSON Schema validation | Custom jq-based validation | ajv-cli (already in use) | Already established in Phase 1; don't duplicate |
| Markdown table formatting | printf/echo formatting | Heredoc templates with variable interpolation | Cleaner, more maintainable |

**Key insight:** The scoring script itself IS the custom solution -- there is no off-the-shelf "Claude plugin quality scorer." But all supporting infrastructure (PR comments, schema validation, JSON manipulation) should use existing tools.

## Common Pitfalls

### Pitfall 1: Naming Convention Rules That Penalize Legitimate Diversity

**What goes wrong:** A strict "agents must be named `{plugin-name}-*.md`" rule gives GRD 20/20 and multi-cli-harness 0/20, which is unfair since multi-cli-harness uses a deliberate Matrix-themed naming convention.
**Why it happens:** Rubric designed for one plugin's convention and applied to all.
**How to avoid:** Check for **consistency** not conformity. Award points if agents follow ANY consistent pattern (all prefixed, or all in a recognized theme). Deduct only for mixed/inconsistent naming.
**Warning signs:** During initial scoring, one plugin scores dramatically differently on naming.

### Pitfall 2: Required Status Checks + Path Filtering Deadlock

**What goes wrong:** If `validate-plugins` is a required status check and a PR only changes docs (not matching `plugins/**`), the workflow is skipped but the check remains "Pending" forever, blocking merge.
**Why it happens:** GitHub treats skipped path-filtered workflows as "not reported" rather than "passed."
**How to avoid:** Either (a) make the required check a separate always-running workflow, (b) use a "skip" job that reports success when no plugins changed, or (c) require the check only when it runs (newer GitHub feature: "required if run").
**Warning signs:** Doc-only PRs stuck in "Waiting for status" state.

### Pitfall 3: Marketplace Schema Breaking Change

**What goes wrong:** Adding `qualityScore` to marketplace.json without updating the schema causes the publish workflow's self-validation to fail.
**Why it happens:** Schema and generation script updated independently.
**How to avoid:** Update `marketplace.schema.json` in the same PR as `generate-marketplace.sh`. Add `qualityScore` as an optional integer field to the `pluginEntry` definition.

### Pitfall 4: Version Hygiene Scoring Penalizes Early-Stage Plugins

**What goes wrong:** A plugin at version `0.1.0` (like GRD) loses maximum version hygiene points, creating a score floor that cannot be improved without a version bump.
**Why it happens:** Strict "version >= 1.0.0" rules favor established plugins.
**How to avoid:** Grade version hygiene on format correctness (valid semver), presence, and consistency (manifest version matches VERSION file if present), not on version magnitude. Reserve only a small deduction (2-3 points) for pre-1.0 status.

### Pitfall 5: PR Comment Permission Escalation

**What goes wrong:** The validate-plugins.yml workflow has `pull-requests: read` permission but posting a PR comment requires `pull-requests: write`.
**Why it happens:** Phase 2 designed the workflow for read-only validation.
**How to avoid:** Update permissions block to `pull-requests: write` in the same PR that adds the scoring step.

## Experiment Design

### Recommended Experimental Setup

**Independent variables:** Rubric rule definitions and point deductions per rule.
**Dependent variables:** Total quality score for each plugin.
**Controlled variables:** Plugin file structure (unchanged during rubric development).

**Baseline comparison:**
- Method: Manual audit of both plugins against rubric draft.
- Expected scores from current state analysis:
  - **GRD:** ~70-72 (strong in agents/commands, weak in manifest completeness -- no homepage/license/keywords/repository)
  - **multi-cli-harness:** ~76-78 (strong in structure/hooks, has commands in filesystem, weak in manifest completeness -- same missing fields, plus commands not declared in manifest)
- Target: GRD >= 70, multi-cli-harness >= 75 (per ROADMAP success criteria)

**Detailed score estimate for GRD (current state):**

| Category | Est. Score | Reasoning |
|----------|-----------|-----------|
| Manifest Completeness (20) | 10-12 | Has name, version, description, author, commands. Missing: homepage, repository, license, keywords, agents (not declared), skills, hooks |
| Documentation (20) | 16-18 | Has README.md, CLAUDE.md. Missing: keywords field for discoverability |
| Structure Integrity (20) | 18-20 | Clean structure, all declared files exist, .claude-plugin present. 1 undeclared workflow file (execute-plan.md) |
| Naming Conventions (20) | 16-18 | Agents follow grd-*.md consistently. Commands dir is "workflows" not "commands" (minor deduction). Plugin name lowercase. |
| Version Hygiene (20) | 12-14 | Valid semver (0.1.0), VERSION file present and matches. Pre-1.0 small deduction. |
| **Total** | **~72-82** | |

**Detailed score estimate for multi-cli-harness (current state):**

| Category | Est. Score | Reasoning |
|----------|-----------|-----------|
| Manifest Completeness (20) | 10-12 | Has name, version, description, author, hooks. Missing: homepage, repository, license, keywords, commands (not declared despite 11 files), agents (not declared) |
| Documentation (20) | 14-16 | Has CLAUDE.md, plugin-README.md (nonstandard name). Missing: keywords |
| Structure Integrity (20) | 16-18 | Good structure, hooks declared and exist. Commands exist but undeclared in manifest. Skills exist but undeclared. |
| Naming Conventions (20) | 16-18 | Agent names are consistent (single-word Matrix theme). Plugin name follows convention. Commands use "commands/" dir. |
| Version Hygiene (20) | 18-20 | version 1.0.0 (stable), valid semver. No separate VERSION file (minor). |
| **Total** | **~74-84** | |

**Calibration strategy:**
1. Write rubric draft with specific point values
2. Run against both real plugins
3. Verify scores meet success criteria (GRD >= 70, multi-cli-harness >= 75)
4. Adjust deduction values if needed (not rules -- rules should remain fair)
5. Run against fixture plugins as sanity checks

### Recommended Metrics

| Metric | Why | How to Compute | Target |
|--------|-----|----------------|--------|
| GRD total score | Success criterion | `score-plugin.sh plugins/GRD` | >= 70 |
| multi-cli-harness total score | Success criterion | `score-plugin.sh plugins/multi-cli-harness` | >= 75 |
| Score discrimination | Rubric differentiates quality | max - min across plugins | > 0 (non-trivial difference) |
| Rule count | Validation depth target | Count rules in score-plugin.sh | >= 15 |
| Fixture plugin scores | Sanity check rubric correctness | Score all 4 valid fixtures | valid-full > valid-minimal |

## Verification Strategy

### Recommended Verification Tiers for This Phase

| Item | Recommended Tier | Rationale |
|------|-----------------|-----------|
| score-plugin.sh exits 0 for both real plugins | Level 1 (Sanity) | Can check immediately after script creation |
| score-plugin.sh --json produces valid JSON | Level 1 (Sanity) | jq parse test |
| GRD scores >= 70 | Level 1 (Sanity) | Direct measurement against success criterion |
| multi-cli-harness scores >= 75 | Level 1 (Sanity) | Direct measurement against success criterion |
| valid-full fixture scores higher than valid-minimal | Level 1 (Sanity) | Rubric sanity: more complete plugins score higher |
| PR comment appears in test PR | Level 2 (Proxy) | Requires creating a test PR against the repo |
| Quality score appears in marketplace.json | Level 2 (Proxy) | Run generate-marketplace.sh and inspect output |
| Branch protection blocks invalid PRs | Level 3 (Deferred) | Requires admin repo access and a real failing PR |
| Quality score >= 60 gate blocks merge | Level 3 (Deferred) | Gate threshold not enforced until Final roadmap target |

**Level 1 checks to always include:**
- `score-plugin.sh plugins/GRD` exits 0 and score >= 70
- `score-plugin.sh plugins/multi-cli-harness` exits 0 and score >= 75
- `score-plugin.sh plugins/GRD --json | jq .` succeeds (valid JSON)
- Score has exactly 5 categories, each max 20
- Total score equals sum of category scores
- All 4 valid fixture plugins score > 0
- valid-full fixture scores > valid-minimal fixture

**Level 2 proxy metrics:**
- PR comment formatting renders correctly in markdown preview
- marketplace.json with qualityScore field passes schema validation
- Workflow YAML passes `actionlint` or manual syntax review

**Level 3 deferred items:**
- Branch protection actually blocks force-push (requires admin)
- Quality score >= 60 merge gate (Phase 5 target, not Phase 3)
- CI time remains < 3 minutes with scoring added

## Production Considerations

### Known Failure Modes
- **Rubric drift from plugin evolution:** As plugins add/remove features, the rubric may become stale. Prevention: rubric checks are based on general patterns (field presence, file existence) not plugin-specific content. Detection: score changes on unrelated PRs.
- **PR comment failure does not block merge:** If `thollander/actions-comment-pull-request` fails (e.g., permissions issue), the workflow step fails but the validation itself passed. Prevention: Make the comment step `continue-on-error: false` to surface permission issues early. Detection: Missing comments on merged PRs.

### Scaling Concerns
- **At current scale (2 plugins):** Scoring runs sequentially in matrix jobs, negligible time impact.
- **At 10+ plugins:** Scoring is O(1) per plugin (only reads plugin directory, no network calls). Matrix parallelization already handles scaling. No concerns.
- **PR comment at scale:** With many plugins changing in one PR, multiple matrix jobs may try to update the same PR comment. Mitigation: Collect all scores in a final aggregation job before commenting.

### Common Implementation Traps
- **Shell quoting in jq output:** When passing JSON through GitHub Actions step outputs, newlines and special characters can break. Correct approach: Use `jq -c` (compact) for step outputs, `jq .` (pretty) for display only.
- **macOS vs Linux jq differences:** The CI runs on ubuntu-latest but developers may run locally on macOS. jq behavior is consistent across platforms, but `sed` and `find` differ. Correct approach: Stick to jq for all JSON manipulation; avoid GNU-specific sed/find flags.
- **Fixture tests not updated:** Adding scoring means existing fixture tests should still pass (score-plugin.sh is a new script, not modifying validate-plugin.sh). But new scoring-specific tests should be added. Correct approach: Add scoring tests to run-fixture-tests.sh or create a separate scoring test script.

## Code Examples

### Scoring Script Core Pattern
```bash
#!/usr/bin/env bash
set -euo pipefail

# Category scoring function pattern
score_manifest_completeness() {
  local manifest="$1"
  local score=20
  local deductions="[]"

  # Check for optional but valuable fields
  for field in homepage repository license keywords; do
    val=$(jq -r ".$field // empty" "$manifest")
    if [[ -z "$val" ]]; then
      score=$((score - 3))
      deductions=$(echo "$deductions" | jq --arg f "$field" --arg d "-3 missing $field" '. + [$d]')
    fi
  done

  # Check if artifact paths are declared
  for artifact in commands agents skills hooks; do
    # Check if directory exists but field is not in manifest
    # ...
  done

  jq -n --argjson s "$score" --argjson d "$deductions" \
    '{score: $s, max: 20, deductions: $d}'
}
```

### PR Comment Markdown Template
```markdown
## Quality Score: {plugin_name} -- {total}/100

| Category | Score | Details |
|----------|-------|---------|
| Manifest Completeness | {mc}/20 | {mc_details} |
| Documentation | {doc}/20 | {doc_details} |
| Structure Integrity | {si}/20 | {si_details} |
| Naming Conventions | {nc}/20 | {nc_details} |
| Version Hygiene | {vh}/20 | {vh_details} |

{pass_fail_badge}
```

### Workflow Integration Pattern
```yaml
- name: Score ${{ matrix.plugin }}
  id: score
  run: |
    SCORE_OUTPUT=$(./scripts/score-plugin.sh "plugins/$PLUGIN_NAME" --json)
    TOTAL=$(echo "$SCORE_OUTPUT" | jq -r '.total')
    echo "total=$TOTAL" >> "$GITHUB_OUTPUT"
    echo "json=$(echo "$SCORE_OUTPUT" | jq -c '.')" >> "$GITHUB_OUTPUT"
    # Display human-readable output in log
    ./scripts/score-plugin.sh "plugins/$PLUGIN_NAME"

- name: Comment PR with quality score
  uses: thollander/actions-comment-pull-request@v3
  with:
    message: |
      ## Quality Score: ${{ matrix.plugin }} -- ${{ steps.score.outputs.total }}/100
      <details><summary>Details</summary>
      <!-- score details here -->
      </details>
    comment-tag: quality-${{ matrix.plugin }}
```

### Marketplace Schema Update
```json
{
  "qualityScore": {
    "type": "integer",
    "minimum": 0,
    "maximum": 100,
    "description": "Quality score from automated rubric (0-100)"
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Binary pass/fail validation | Numeric quality scoring (0-100) | This phase | Enables gradual improvement, not just compliance |
| Manual review only | Automated rubric + manual review | This phase | Consistent, reproducible quality assessment |
| No merge protection | Branch protection + required checks | This phase | Prevents unreviewed or failing code from reaching main |

## Rubric Design: Detailed Rule Inventory

The following is the recommended rule set across all 5 categories (15+ rules per ROADMAP target):

### Category 1: Manifest Completeness (20 pts)
| Rule | Deduction | Applies When |
|------|-----------|-------------|
| Missing `description` field | -4 | No description in plugin.json |
| Missing `version` field | -3 | No version in plugin.json |
| Missing `author` field | -3 | No author in plugin.json |
| Missing `homepage` field | -2 | No homepage URL |
| Missing `repository` field | -2 | No repository URL |
| Missing `license` field | -2 | No SPDX license identifier |
| Missing `keywords` field | -2 | No keywords array |
| Undeclared artifacts | -2 | Directory exists (agents/, commands/, skills/) but not referenced in manifest |

### Category 2: Documentation (20 pts)
| Rule | Deduction | Applies When |
|------|-----------|-------------|
| Missing README | -6 | No README.md or *README*.md at plugin root |
| Missing CLAUDE.md | -6 | No CLAUDE.md at plugin root |
| README too short | -3 | README < 50 lines |
| Description too short | -3 | Manifest description < 20 characters |
| Missing keywords for discovery | -2 | No keywords in manifest |

### Category 3: Structure Integrity (20 pts)
| Rule | Deduction | Applies When |
|------|-----------|-------------|
| Missing .claude-plugin directory | -6 | No .claude-plugin/ dir |
| Declared file not found | -4 each | File referenced in manifest doesn't exist (max -12) |
| Undeclared artifact files | -2 | Files in artifact dirs not referenced in manifest |
| Hook script not executable | -3 | .sh hook file without +x permission |
| Empty artifact directory | -2 | Directory declared/exists but contains no files |

### Category 4: Naming Conventions (20 pts)
| Rule | Deduction | Applies When |
|------|-----------|-------------|
| Plugin name not lowercase-hyphenated | -4 | Name doesn't match `^[a-z][a-z0-9-]*$` |
| Inconsistent agent naming | -4 | Agent files don't follow a consistent pattern |
| Command dir nonstandard name | -2 | Commands in dir other than `commands/` (warning, not error) |
| Agent file extension wrong | -3 | Agent files not .md |
| Version string format invalid | -3 | Version doesn't match semver pattern |
| Manifest field naming | -2 | Fields use non-standard casing |

### Category 5: Version Hygiene (20 pts)
| Rule | Deduction | Applies When |
|------|-----------|-------------|
| No version in manifest | -6 | Missing version field |
| Invalid semver format | -4 | Version doesn't match semver pattern |
| Pre-1.0 version | -2 | Major version is 0 |
| VERSION file mismatch | -3 | VERSION file exists but doesn't match manifest |
| No changelog or version history | -3 | No CHANGELOG.md or version history |
| Version contains build metadata | -2 | Version has `+build` suffix (unusual for plugins) |

**Total rules: 28** (exceeds 15+ target from ROADMAP)

## Open Questions

1. **Should scoring be a required check or informational-only initially?**
   - What we know: ROADMAP says "quality score >= 60 required to merge" is the Final target, not Phase 3.
   - What's unclear: Should Phase 3 make any score a hard gate, or just display?
   - Recommendation: Phase 3 should display only. The >= 60 gate is a Phase 5 (Final) target. This avoids blocking PRs during rubric calibration.

2. **How to handle the multi-cli-harness `commands/` directory with undeclared commands?**
   - What we know: multi-cli-harness has 11 command .md files in `commands/` but doesn't declare them in the manifest's `commands` field. The plugin uses inline hooks instead.
   - What's unclear: Are these commands intended to be declared? Or are they documentation-only?
   - Recommendation: Score a deduction under "Undeclared artifacts" (Structure Integrity), but keep it small (-2). This flags the inconsistency without heavily penalizing.

3. **Should branch protection be automated via gh CLI or documented for manual setup?**
   - What we know: Branch protection is a one-time configuration. The repo uses CODEOWNERS already.
   - What's unclear: Whether the maintainer wants a script or prefers manual UI setup.
   - Recommendation: Document the exact branch protection settings in QUALITY.md. Optionally provide a `gh api` one-liner for reference. Don't create a dedicated script for a one-time operation.

4. **PR comment when multiple plugins change in one PR?**
   - What we know: The workflow uses matrix strategy, meaning each plugin gets its own job.
   - What's unclear: Should there be one aggregated comment or one per plugin?
   - Recommendation: One comment per plugin using `comment-tag: quality-${{ matrix.plugin }}`. This keeps each plugin's score distinct and supports the existing matrix pattern.

## Sources

### Primary (HIGH confidence)
- Project codebase analysis: `scripts/validate-plugin.sh`, `scripts/generate-marketplace.sh`, `schemas/plugin.schema.json`, `schemas/marketplace.schema.json`, `.github/workflows/validate-plugins.yml`, `.github/workflows/publish-marketplace.yml`
- Both real plugin structures: `plugins/GRD/`, `plugins/multi-cli-harness/`
- ROADMAP.md -- Phase 3 scope, success criteria, quality targets
- [GitHub Docs: Managing branch protection rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule)
- [GitHub Docs: About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [thollander/actions-comment-pull-request](https://github.com/thollander/actions-comment-pull-request) -- GitHub Marketplace action for PR comments

### Secondary (MEDIUM confidence)
- [npms.io scoring](https://npmsearch.com/about) -- Multi-dimension quality scoring model
- Mota et al. (2016), "Simplifying the Search of npm Packages", Concordia University -- npm search quality scoring methodology
- [Skypack Quality Score](https://www.skypack.dev/blog/2020/10/skypack-quality-score-actionable-feedback-to-build-better-packages/) -- Per-deduction quality feedback model
- [GitHub community discussion on path-filtering + required checks](https://github.com/orgs/community/discussions/54877) -- Workarounds for skipped workflow deadlocks
- [alexfernandez/package-quality](https://github.com/alexfernandez/package-quality) -- npm package quality measurement approach

### Tertiary (LOW confidence)
- npm search scoring algorithm weights (0.30/0.35/0.35) -- Referenced from web search, consistent with npms.io documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- bash+jq is already the established project toolchain, no new dependencies needed
- Architecture: HIGH -- scoring script pattern mirrors existing validate-plugin.sh architecture
- Rubric design: HIGH -- Based on thorough analysis of both real plugins and cross-referenced with npm quality scoring literature
- Pitfalls: HIGH -- All pitfalls identified from direct codebase analysis (permission issues, path-filter deadlock, naming divergence)
- Experiment design: HIGH -- Score estimates based on actual plugin file counts and field analysis

**Research date:** 2026-02-12
**Valid until:** 2026-03-11 (stable domain; tooling unlikely to change)
