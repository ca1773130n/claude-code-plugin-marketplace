# Phase 2: CI/CD Pipeline - Research

**Researched:** 2026-02-12
**Domain:** GitHub Actions CI/CD, changed-files detection, auto-commit patterns, CODEOWNERS
**Confidence:** HIGH

## Summary

Phase 2 builds the CI/CD backbone for the marketplace: a PR validation workflow that runs `validate-plugin.sh` on changed plugins, a push-to-main workflow that regenerates `marketplace.json` from all `plugin.json` files, a `generate-marketplace.sh` script, and a `CODEOWNERS` file. The technical domain is well-established: GitHub Actions is mature, the changed-files detection problem is solved by multiple actions, and the auto-commit pattern has a well-documented safe approach using `GITHUB_TOKEN` (which inherently prevents infinite CI loops).

The key architectural insight is that `GITHUB_TOKEN`-based commits do NOT trigger new workflow runs (GitHub's built-in loop prevention), eliminating the primary risk identified in the roadmap. The `dorny/paths-filter@v3` action is the recommended choice for changed-plugin detection over `tj-actions/changed-files` due to a severe supply-chain compromise of the latter in March 2025. For marketplace generation, `jq` with `--slurp` provides a clean, single-command approach to merge all `plugin.json` files into the `marketplace.json` array.

All Phase 1 artifacts (schemas, validation scripts, test runner) are ready and directly reusable in the CI workflows. The `validate-plugin.sh` script already uses `npx ajv validate` and `jq`, which defines the runtime dependencies for CI (Node.js + jq).

**Primary recommendation:** Use `dorny/paths-filter@v3` for changed-plugin detection, `stefanzweifel/git-auto-commit-action@v7` with `GITHUB_TOKEN` for auto-committing `marketplace.json` (inherently loop-safe), `actions/setup-node@v4` with npm cache for dependency caching, and native `jq --slurp` for marketplace generation.

## User Constraints (from CONTEXT.md)

No CONTEXT.md exists for Phase 2. No prior user decisions to honor. All recommendations below are at the researcher's discretion, constrained only by the ROADMAP.md decision log:

- **GitHub Actions** for CI/CD (locked in ROADMAP.md decision log -- "Native, free, no extra service")
- **Bash + jq + ajv-cli** for scripting (locked in ROADMAP.md decision log)
- **marketplace.json auto-generated on CI** (locked in ROADMAP.md decision log -- "Eliminates drift from manual edits")

## Paper-Backed Recommendations

This phase involves CI/CD infrastructure rather than research algorithms, so recommendations are backed by official documentation and authoritative community sources rather than academic papers.

### Recommendation 1: Use `GITHUB_TOKEN` for Auto-Commits (Inherent Loop Prevention)

**Recommendation:** Use the repository's built-in `GITHUB_TOKEN` secret for all auto-commit operations on push-to-main. Do NOT use a Personal Access Token (PAT).

**Evidence:**
- [GitHub Official Docs: GITHUB_TOKEN](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication) -- "When you use the repository's GITHUB_TOKEN to perform tasks, events triggered by the GITHUB_TOKEN, with the exception of workflow_dispatch and repository_dispatch, will not create a new workflow run. This prevents you from accidentally creating recursive workflow runs."
- [GitHub Official Docs: Triggering a workflow from a workflow](https://docs.github.com/en/actions/using-workflows/triggering-a-workflow) -- Confirms the same behavior: pushes via GITHUB_TOKEN do not trigger push-event workflows.
- [stefanzweifel/git-auto-commit-action README](https://github.com/stefanzweifel/git-auto-commit-action) -- Documents that using GITHUB_TOKEN is the safe default.

**Confidence:** HIGH -- Official GitHub documentation, verified via Context7, multiple independent sources confirm.
**Impact:** Eliminates the primary risk identified in ROADMAP.md ("auto-commit conflicts if multiple PRs merge rapidly") for the infinite-loop dimension. Race conditions on concurrent merges remain (addressed in Recommendation 5).
**Caveats:** Commits made via GITHUB_TOKEN will NOT trigger downstream workflows. If Phase 3+ needs a workflow triggered by marketplace.json changes, a PAT or GitHub App token would be needed (but this introduces loop risk that must be separately mitigated).

### Recommendation 2: Use `dorny/paths-filter@v3` for Changed-Plugin Detection

**Recommendation:** Use `dorny/paths-filter@v3` to detect which plugins changed in a PR. Do NOT use `tj-actions/changed-files`.

**Evidence:**
- [dorny/paths-filter GitHub](https://github.com/dorny/paths-filter) -- 6.4k+ stars, actively maintained, v3 is current. Uses GitHub REST API for PR file detection (no checkout needed for PR events). Supports filter output as JSON array for matrix strategies.
- [tj-actions/changed-files supply-chain compromise (March 2025)](https://www.wiz.io/blog/github-action-tj-actions-changed-files-supply-chain-attack-cve-2025-30066) -- CVE-2025-30066. The action was compromised between March 12-15, 2025, printing repository secrets to build logs. While tagged versions have been updated, the security incident represents a fundamental trust issue.
- [Snyk: Reconstructing the TJ Actions Changed Files Compromise](https://snyk.io/blog/reconstructing-tj-actions-changed-files-github-actions-compromise/) -- Independent analysis confirming the supply-chain attack.

**Confidence:** HIGH -- Multiple security advisories confirm the compromise of tj-actions. dorny/paths-filter has no known security incidents.
**Impact:** Enables targeted validation of only changed plugins in PRs, reducing CI time from O(all-plugins) to O(changed-plugins).
**Caveats:** `dorny/paths-filter` requires `pull-requests: read` permission for PR events when using the GitHub API method. For push events, it requires repository checkout with sufficient `fetch-depth`.

### Recommendation 3: Use `stefanzweifel/git-auto-commit-action@v7` for Auto-Commits

**Recommendation:** Use `stefanzweifel/git-auto-commit-action@v7` to commit and push regenerated `marketplace.json` after merges to main.

**Evidence:**
- [stefanzweifel/git-auto-commit-action GitHub](https://github.com/stefanzweifel/git-auto-commit-action) -- 3.5k+ stars, actively maintained, v7 is current. Supports custom commit messages, file patterns, skip-dirty-check, and commit options.
- Context7 query confirmed: Supports `file_pattern` to restrict commits to specific files (e.g., `.claude-plugin/marketplace.json`), `commit_message` for descriptive messages, and `commit_options` for `--no-verify`.

**Confidence:** HIGH -- Widely adopted, well-documented, verified via Context7.
**Impact:** Clean abstraction for the auto-commit pattern. Handles edge cases (no changes = no commit, git config, push).
**Caveats:** Must pair with `GITHUB_TOKEN` (not PAT) to prevent loop triggers.

### Recommendation 4: Use `actions/setup-node@v4` with Built-in npm Cache

**Recommendation:** Use `actions/setup-node@v4` with `cache: 'npm'` for Node.js setup and dependency caching. Use `npm ci` (not `npm install`) in CI.

**Evidence:**
- [actions/setup-node GitHub](https://github.com/actions/setup-node) -- Official GitHub action, supports built-in caching via `cache` input. Uses `actions/cache` internally, keyed on `package-lock.json` hash.
- [actions/cache GitHub](https://github.com/actions/cache) -- Documents npm cache directory (`~/.npm` on Posix). Cache key strategy: `${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}` with restore-keys fallback.
- [GitHub Docs: Dependency caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows) -- Cache limit: 10 GB per repository. Entries unused for 7 days are evicted.

**Confidence:** HIGH -- Official GitHub actions, verified documentation.
**Impact:** Avoids redundant `npm install` on every CI run. With ajv-cli as the only dependency, cache hit eliminates ~5-10 second install time.
**Caveats:** Requires `package-lock.json` to be committed (already done in Phase 1 setup).

### Recommendation 5: Use Concurrency Groups to Handle Rapid Merges

**Recommendation:** Use GitHub Actions `concurrency` key with `cancel-in-progress: false` on the publish workflow to serialize marketplace.json regeneration.

**Evidence:**
- [GitHub Official Docs: Using concurrency](https://docs.github.com/en/actions/using-jobs/using-concurrency) -- "You can use concurrency to ensure that only a single job or workflow using the same concurrency group will run at a time."
- [GitHub Merge Queue docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue) -- For high-traffic repos, merge queues provide serialized merges.

**Confidence:** HIGH -- Official GitHub documentation.
**Impact:** Prevents race conditions when multiple PRs merge to main in rapid succession. Each publish run sees the latest state of main.
**Caveats:** With `cancel-in-progress: false`, concurrent runs queue up rather than cancel. This is correct for marketplace generation (we want the latest state, but each run must complete to avoid partial writes). An alternative is `cancel-in-progress: true` which cancels stale runs (also safe since the newest run regenerates from all plugins).

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| GitHub Actions | N/A (platform) | CI/CD orchestration | ROADMAP decision: "Native, free, no extra service." No alternative considered. |
| dorny/paths-filter | v3 | Detect changed plugins in PRs | Most trusted changed-files action. No supply-chain incidents. Matrix strategy support. Source: [GitHub](https://github.com/dorny/paths-filter) |
| stefanzweifel/git-auto-commit-action | v7 | Auto-commit marketplace.json on push-to-main | Most popular auto-commit action (3.5k+ stars). File pattern support. Source: [GitHub](https://github.com/stefanzweifel/git-auto-commit-action) |
| actions/setup-node | v4 | Node.js setup with npm caching | Official GitHub action. Built-in cache support. Source: [GitHub](https://github.com/actions/setup-node) |
| actions/checkout | v4 | Repository checkout | Official GitHub action. Required for all workflows. Source: [GitHub](https://github.com/actions/checkout) |
| jq | system (runner) | JSON manipulation for marketplace generation | Pre-installed on GitHub-hosted runners (ubuntu-latest). No install needed. |
| ajv-cli | 5.0.0 | JSON Schema validation | Phase 1 dependency, already in package.json. |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| actions/cache | v4 | Explicit cache control | Only if setup-node built-in cache proves insufficient. Normally not needed. |
| GitHub merge queue | N/A (platform) | Serialized merges | Only if rapid-merge race conditions become a real problem. Overkill for current 2-plugin repo. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| dorny/paths-filter | tj-actions/changed-files | Supply-chain compromise in March 2025 (CVE-2025-30066). Avoid. |
| dorny/paths-filter | Native `git diff` in bash | More code to maintain, no matrix strategy support, must handle PR vs push events differently. |
| stefanzweifel/git-auto-commit-action | Manual `git add/commit/push` | More code, must handle git config, no-changes detection, error handling. |
| setup-node with cache | Manual actions/cache | More configuration, same result. setup-node handles cache key generation automatically. |
| Concurrency groups | GitHub merge queue | Merge queue is heavier, requires branch protection setup, overkill for this repo's merge frequency. |

**Installation:**
```bash
# No local installation needed -- all tools run in GitHub Actions
# Local development uses the same Phase 1 setup:
npm ci  # installs ajv-cli from package.json
```

## Architecture Patterns

### Recommended Project Structure

```
claude-plugin-marketplace/
├── .github/
│   └── workflows/
│       ├── validate-plugins.yml      # PR trigger: validate changed plugins
│       └── publish-marketplace.yml   # Push-to-main: regenerate marketplace.json
├── scripts/
│   ├── validate-plugin.sh            # Phase 1 (exists)
│   ├── run-fixture-tests.sh          # Phase 1 (exists)
│   └── generate-marketplace.sh       # NEW: builds marketplace.json from plugin.json files
├── schemas/
│   ├── plugin.schema.json            # Phase 1 (exists)
│   └── marketplace.schema.json       # Phase 1 (exists)
├── CODEOWNERS                        # NEW: plugin ownership rules
├── package.json                      # Phase 1 (exists, has ajv-cli)
└── package-lock.json                 # Phase 1 (exists)
```

### Pattern 1: Two-Workflow Architecture (Validate on PR, Publish on Push)

**What:** Separate CI into two workflows with different triggers and different responsibilities. The validation workflow runs on `pull_request` events targeting `main`. The publish workflow runs on `push` events to `main`.

**When to use:** Always for this type of validate-then-publish pipeline. Mixing both concerns into one workflow creates complexity around conditional execution and permissions.

**Source:** [GitHub Actions official docs: Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)

**Example:**
```yaml
# .github/workflows/validate-plugins.yml
name: Validate Plugins
on:
  pull_request:
    branches: [main]
    paths:
      - 'plugins/**'
      - 'schemas/**'
      - 'scripts/validate-plugin.sh'

# .github/workflows/publish-marketplace.yml
name: Publish Marketplace
on:
  push:
    branches: [main]
    paths:
      - 'plugins/**'
```

### Pattern 2: Changed-Plugin Detection with Matrix Strategy

**What:** Use `dorny/paths-filter` to detect which plugin directories changed, then validate only those plugins using a matrix strategy. This scales to N plugins without modifying the workflow file.

**When to use:** For the validation workflow (PR trigger). Not needed for the publish workflow (which always regenerates from all plugins).

**Source:** [dorny/paths-filter: Matrix strategy example](https://github.com/dorny/paths-filter#examples)

**Example:**
```yaml
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: read
    outputs:
      plugins: ${{ steps.filter.outputs.changes }}
      any_changed: ${{ steps.filter.outputs.changes != '[]' }}
    steps:
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            multi-cli-harness:
              - 'plugins/multi-cli-harness/**'
            grd:
              - 'plugins/GRD/**'

  validate:
    needs: detect-changes
    if: needs.detect-changes.outputs.any_changed == 'true'
    strategy:
      matrix:
        plugin: ${{ fromJSON(needs.detect-changes.outputs.plugins) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: ./scripts/validate-plugin.sh plugins/${{ matrix.plugin }}
```

### Pattern 3: Auto-Commit with Loop Prevention

**What:** After merging to main, regenerate `marketplace.json` and auto-commit using `GITHUB_TOKEN`. The commit does not trigger a new workflow run (GitHub's built-in prevention).

**When to use:** For the publish-marketplace workflow.

**Source:** [GitHub Docs: GITHUB_TOKEN](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication), [stefanzweifel/git-auto-commit-action](https://github.com/stefanzweifel/git-auto-commit-action)

**Example:**
```yaml
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    concurrency:
      group: publish-marketplace
      cancel-in-progress: true
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/generate-marketplace.sh
      - uses: stefanzweifel/git-auto-commit-action@v7
        with:
          commit_message: 'chore: regenerate marketplace.json [skip ci]'
          file_pattern: '.claude-plugin/marketplace.json'
```

### Pattern 4: Fixture Tests as CI Validation Gate

**What:** Run `run-fixture-tests.sh` in CI to ensure validation scripts themselves work correctly. This catches regressions in the validation tooling.

**When to use:** On every PR that changes schemas or validation scripts. Acts as a self-test.

**Example:**
```yaml
  test-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: ./scripts/run-fixture-tests.sh
```

### Anti-Patterns to Avoid

- **Using a PAT for auto-commits:** A Personal Access Token will trigger downstream workflows, potentially creating infinite loops. Always use `GITHUB_TOKEN` unless you explicitly need to trigger another workflow.
- **Caching `node_modules/` directly:** Cache the npm cache directory (`~/.npm`) instead. Caching `node_modules/` can lead to stale or incompatible cached modules. The `setup-node` action handles this correctly.
- **Validating ALL plugins on every PR:** Use changed-file detection. Validating all plugins wastes CI time and gives misleading feedback when a PR only touches one plugin.
- **Using `pull_request_target` for validation:** `pull_request_target` runs in the context of the base branch and has access to secrets. For forked PRs, this is a security risk. Use `pull_request` which runs in the fork's context with limited permissions.
- **Hardcoding plugin names in workflow filters:** Use `dorny/paths-filter` with a filter per plugin, or use a dynamic detection approach. Hardcoded names require workflow edits for each new plugin.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Changed-file detection | Custom `git diff` parsing | `dorny/paths-filter@v3` | Handles PR vs push events, base branch comparison, file listing, matrix strategy. Custom git diff must handle merge bases, pagination, shallow clones. |
| Auto-commit and push | Manual `git add && git commit && git push` | `stefanzweifel/git-auto-commit-action@v7` | Handles no-changes detection, git config, commit options, branch detection. Manual approach has ~20 lines of boilerplate with edge cases. |
| npm dependency caching | Manual `actions/cache` setup | `actions/setup-node@v4` with `cache: 'npm'` | Built-in cache key generation from lockfile hash. Manual cache requires key construction and path configuration. |
| Marketplace JSON assembly | Custom JSON string concatenation in bash | `jq --slurp` with proper queries | String concatenation produces invalid JSON with commas, escaping issues. jq handles all edge cases. |

**Key insight:** GitHub Actions has a mature ecosystem of verified actions for every CI/CD primitive. The only custom code needed is `generate-marketplace.sh` (marketplace assembly logic) and the workflow YAML itself. Everything else has battle-tested solutions.

## Common Pitfalls

### Pitfall 1: Auto-Commit Infinite Loops

**What goes wrong:** The publish workflow commits `marketplace.json` to main, which triggers the publish workflow again, which commits again, creating an infinite loop.
**Why it happens:** Using a Personal Access Token (PAT) or GitHub App token instead of `GITHUB_TOKEN`. PAT commits trigger workflows; GITHUB_TOKEN commits do not.
**How to avoid:** Always use `GITHUB_TOKEN` for auto-commits. Add `[skip ci]` to commit messages as a defense-in-depth measure (works even if someone later switches to a PAT).
**Warning signs:** Workflow runs spawning new workflow runs without human commits.
**Source:** [GitHub Docs: GITHUB_TOKEN](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication) -- "events triggered by the GITHUB_TOKEN will not create a new workflow run."

### Pitfall 2: Race Conditions on Rapid Merges

**What goes wrong:** Two PRs merge to main in quick succession. Both trigger the publish workflow. The second run starts before the first run's auto-commit is pushed. Both runs generate marketplace.json from the same base, but the second run misses the first PR's plugin changes.
**Why it happens:** No serialization of the publish workflow. Concurrent runs see the same git state.
**How to avoid:** Use `concurrency: { group: publish-marketplace, cancel-in-progress: true }`. The `cancel-in-progress: true` setting cancels the first (now stale) run and lets only the newest run complete (which sees both merges). Alternatively, use `cancel-in-progress: false` to queue runs sequentially.
**Warning signs:** marketplace.json missing a recently merged plugin.
**Source:** [GitHub Docs: Using concurrency](https://docs.github.com/en/actions/using-jobs/using-concurrency)

### Pitfall 3: Shallow Clone Missing File History

**What goes wrong:** `dorny/paths-filter` on push events needs git history to detect changes. With `actions/checkout`'s default `fetch-depth: 1`, there is no history to compare.
**Why it happens:** GitHub Actions defaults to shallow clone for performance.
**How to avoid:** For the validation workflow (PR trigger), `dorny/paths-filter` uses the GitHub API by default, so no extra fetch depth is needed. For push events, set `fetch-depth: 2` (or more) on `actions/checkout` to enable git-based diff.
**Warning signs:** paths-filter reporting no changes on push events.

### Pitfall 4: `npm ci` Fails Without `package-lock.json`

**What goes wrong:** `npm ci` exits with an error because `package-lock.json` is missing from the repository.
**Why it happens:** `package-lock.json` was gitignored or never committed.
**How to avoid:** Ensure `package-lock.json` is committed. Phase 1 setup should have generated it. Verify with `git ls-files package-lock.json`.
**Warning signs:** CI fails on `npm ci` step with "Cannot find lockfile" error.

### Pitfall 5: Plugin Directory Name vs Plugin Name Mismatch

**What goes wrong:** The plugin directory is `plugins/GRD` (uppercase) but the plugin name in `plugin.json` is `"grd"` (lowercase). Scripts that map between directory names and plugin names break.
**Why it happens:** Convention mismatch between filesystem naming and JSON naming.
**How to avoid:** In `generate-marketplace.sh`, read the plugin name from `plugin.json` (not from the directory name). In `dorny/paths-filter`, use the actual directory name (`plugins/GRD/**`). In the matrix strategy, map the filter name to the actual directory path.
**Warning signs:** Validation step fails with "directory not found" for a plugin that clearly exists.

### Pitfall 6: CODEOWNERS Invalid Syntax Silently Ignored

**What goes wrong:** A line in CODEOWNERS has invalid syntax (e.g., bad username format). GitHub silently skips the line without any error. The plugin has no code owner assigned.
**Why it happens:** GitHub does not validate CODEOWNERS on push -- it only applies rules when PRs are opened.
**How to avoid:** Use the GitHub UI "CODEOWNERS" validation (Settings > Branches > Branch protection rules), or add a CI step that runs `gh api repos/{owner}/{repo}/codeowners/errors` to check for syntax errors.
**Warning signs:** PRs not requiring the expected reviewers.
**Source:** [GitHub Docs: About CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) -- "If any line in your CODEOWNERS file contains invalid syntax, that line will be skipped."

### Pitfall 7: Secrets Exposed in Fork PRs

**What goes wrong:** A forked PR runs a workflow that has access to repository secrets, allowing a malicious contributor to exfiltrate secrets.
**Why it happens:** Using `pull_request_target` instead of `pull_request`, or misconfiguring workflow permissions.
**How to avoid:** Use `pull_request` trigger for validation workflows. It runs in the context of the fork with read-only access. Never use `pull_request_target` unless you understand the security implications and have explicit safeguards.
**Warning signs:** Workflow has `secrets.*` references in steps that run for external PRs.
**Source:** [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)

### Pitfall 8: `jq` Producing Invalid JSON from Empty Plugin Set

**What goes wrong:** `generate-marketplace.sh` runs when no plugins exist (or all plugin.json files are removed), producing an invalid marketplace.json with an empty array that may fail schema validation (schema requires `minItems: 1`).
**Why it happens:** Edge case not handled in the generation script.
**How to avoid:** Check that at least one valid plugin.json exists before running jq assembly. Fail with a descriptive error if no plugins are found.
**Warning signs:** marketplace.json contains `"plugins": []` which fails marketplace schema validation.

## Experiment Design

### CI Pipeline Validation Test Plan

This is an infrastructure phase, not an R&D experiment. The "experiment" is a structured test plan for CI correctness.

**Independent variables:**
- PR content (valid plugin change, invalid plugin change, non-plugin change, schema/script change)
- Merge scenario (single merge, rapid consecutive merges)
- Plugin count (2 current plugins, simulated 5+ plugins)

**Dependent variables:**
- CI pass/fail matches expected outcome
- CI run time (target: < 3 minutes)
- marketplace.json correctness after publish
- Auto-commit message and contents

**Test matrix:**

| Scenario | Expected CI Outcome | Expected marketplace.json State |
|----------|--------------------|---------------------------------|
| PR adds valid plugin | Validation passes | (no change until merge) |
| PR adds invalid plugin (bad schema) | Validation fails with descriptive error | (no change) |
| PR modifies existing plugin | Validation passes for that plugin only | (no change until merge) |
| PR changes only README | Validation skipped (no plugin changes) | (no change) |
| PR changes validation script | Fixture tests run and pass | (no change until merge) |
| Merge valid plugin PR to main | N/A (push event) | marketplace.json regenerated with new plugin |
| Two PRs merged rapidly to main | Second run cancels first (or queues) | marketplace.json has both changes |
| Merge changes non-plugin file | Publish skipped (paths filter) | (no change) |

**Baseline comparison:**
- Current state: No CI. Manual validation. marketplace.json manually maintained.
- Target: 100% automated validation on PRs, 100% automated publishing on merge.

### Performance Baseline

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| PR validation time (1 plugin) | < 1 minute | GitHub Actions job duration |
| PR validation time (all plugins) | < 3 minutes | GitHub Actions job duration |
| Publish workflow time | < 2 minutes | GitHub Actions job duration |
| npm ci with cache hit | < 10 seconds | GitHub Actions step duration |
| npm ci without cache | < 30 seconds | GitHub Actions step duration |
| validate-plugin.sh per plugin | < 5 seconds | Script timing |
| generate-marketplace.sh | < 5 seconds | Script timing |

## Verification Strategy

### Recommended Verification Tiers for This Phase

| Item | Recommended Tier | Rationale |
|------|-----------------|-----------|
| Workflows have valid YAML syntax | Level 1 (Sanity) | GitHub will reject invalid YAML on push |
| generate-marketplace.sh produces valid JSON | Level 1 (Sanity) | Can test locally immediately |
| generate-marketplace.sh output matches marketplace schema | Level 1 (Sanity) | Can validate with ajv-cli locally |
| CODEOWNERS has valid syntax | Level 1 (Sanity) | Can verify via GitHub UI after push |
| Validation workflow triggers on PR with plugin changes | Level 2 (Proxy) | Requires actual PR to test |
| Validation workflow skips on PR without plugin changes | Level 2 (Proxy) | Requires actual PR to test |
| Publish workflow regenerates marketplace.json on merge | Level 2 (Proxy) | Requires actual merge to test |
| Auto-commit does not trigger infinite loop | Level 2 (Proxy) | Requires merge + observation |
| CI runs under 3 minutes | Level 2 (Proxy) | Requires actual CI run timing |
| Concurrent merges handled correctly | Level 3 (Deferred) | Requires multiple rapid merges; defer to Phase 5 |
| CI performance with 10+ plugins | Level 3 (Deferred) | Defer to Phase 5 |

**Level 1 checks to always include:**
- `generate-marketplace.sh` exits 0 and produces valid JSON for current 2 plugins
- Output marketplace.json validates against `schemas/marketplace.schema.json`
- Output marketplace.json contains entries for both plugins with correct fields
- CODEOWNERS file passes `gh api` syntax check (or manual review)
- Workflow YAML files are syntactically valid

**Level 2 proxy metrics:**
- Open a test PR touching `plugins/GRD/` -- verify validation workflow triggers and passes
- Open a test PR with an intentionally invalid plugin.json -- verify validation fails
- Merge a test PR -- verify marketplace.json is regenerated and auto-committed
- Verify auto-commit message contains `[skip ci]`
- Verify no secondary workflow run is triggered by the auto-commit
- Measure CI run time for validation and publish workflows

**Level 3 deferred items:**
- Stress test with 10+ plugins (Phase 5)
- Rapid-merge race condition test (Phase 5)
- Cross-platform validation (macOS/Linux) (Phase 5)

## Production Considerations

### Known Failure Modes

- **npm install failure in CI:** GitHub-hosted runners have Node.js pre-installed, but the version may not match. Using `setup-node@v4` with explicit `node-version: '20'` ensures consistency.
  - Prevention: Pin Node.js version in workflow. Use `npm ci` with committed lockfile.
  - Detection: CI step failure with clear npm error message.

- **jq not available on runner:** Ubuntu-latest runners include jq pre-installed. If the runner image changes, jq may be missing.
  - Prevention: Add a `which jq || sudo apt-get install -y jq` step as fallback.
  - Detection: CI step failure with "jq: command not found."

- **GITHUB_TOKEN permission denied on push:** Default GITHUB_TOKEN may have read-only contents permission. The publish workflow needs `contents: write`.
  - Prevention: Explicitly set `permissions: { contents: write }` in the publish workflow.
  - Detection: CI step failure with "Permission denied" on git push.

- **Auto-commit on detached HEAD:** `actions/checkout` may check out a detached HEAD in some event types. `stefanzweifel/git-auto-commit-action` handles this, but manual git commands would fail.
  - Prevention: Use the auto-commit action rather than manual commands.
  - Detection: Git error "You are not currently on a branch."

### Scaling Concerns

- **At current scale (2 plugins):** All operations are near-instant. CI time dominated by npm install and setup.
  - Approach: No optimization needed. Single-job sequential validation is fine.

- **At 10+ plugins:** Matrix strategy parallelizes validation across plugins. Each matrix job installs npm dependencies independently (cached).
  - Approach: Use `dorny/paths-filter` matrix output. Each changed plugin gets its own validation job.
  - Concern: Each matrix job has ~20 seconds of setup overhead. 10 parallel jobs = 10x the setup cost but same wall-clock time.

- **At 50+ plugins:** Filter maintenance becomes a burden (one filter entry per plugin in the workflow YAML).
  - Approach: Switch from static filters to dynamic detection: `find plugins/*/. -name plugin.json` + `git diff` to detect changed plugin directories. This eliminates per-plugin workflow configuration.

- **marketplace.json size:** Currently ~500 bytes. At 100+ plugins with full metadata, could reach 50-100 KB. Still trivially small.

### Common Implementation Traps

- **Forgetting to make scripts executable:** `generate-marketplace.sh` must have `chmod +x` before committing. CI will fail with "Permission denied."
  - Correct approach: `git add --chmod=+x scripts/generate-marketplace.sh`

- **Using `paths` filter in `on:` trigger AND `dorny/paths-filter` in jobs:** These serve different purposes. The `on: paths:` filter prevents the workflow from running at all. The `dorny/paths-filter` detects WHICH paths changed within an already-triggered workflow. Use both: `on: paths:` as a coarse filter (any plugin change), `dorny/paths-filter` for fine-grained per-plugin detection.

- **Hardcoding `./plugins/multi-cli-harness` and `./plugins/GRD` in generate-marketplace.sh:** The script should discover plugins dynamically using `find` or glob. Hardcoded paths require script updates for every new plugin.

## Code Examples

### Example 1: `generate-marketplace.sh` -- Building marketplace.json from plugin.json files

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKETPLACE_FILE="$REPO_ROOT/.claude-plugin/marketplace.json"
MARKETPLACE_SCHEMA="$REPO_ROOT/schemas/marketplace.schema.json"

# Discover all plugin.json files
plugin_files=()
while IFS= read -r f; do
  plugin_files+=("$f")
done < <(find "$REPO_ROOT/plugins" -path '*/.claude-plugin/plugin.json' -type f | sort)

if [[ ${#plugin_files[@]} -eq 0 ]]; then
  echo "Error: No plugin.json files found in plugins/" >&2
  exit 1
fi

# Build plugin entries array using jq
# For each plugin.json, extract fields and add source path
plugins_json="[]"
for pf in "${plugin_files[@]}"; do
  plugin_dir="$(dirname "$(dirname "$pf")")"
  rel_source="./$(realpath --relative-to="$REPO_ROOT" "$plugin_dir")"

  entry=$(jq --arg source "$rel_source" '{
    name: .name,
    source: $source,
    description: (.description // null),
    version: (.version // null),
    author: (.author // null),
    homepage: (.homepage // null),
    repository: (.repository // null),
    license: (.license // null),
    keywords: (.keywords // null)
  } | with_entries(select(.value != null))' "$pf")

  plugins_json=$(echo "$plugins_json" | jq --argjson entry "$entry" '. + [$entry]')
done

# Assemble marketplace.json
jq -n \
  --arg name "claude-plugin-marketplace" \
  --argjson plugins "$plugins_json" \
  '{
    name: $name,
    owner: { name: "edward-seo" },
    plugins: $plugins
  }' > "$MARKETPLACE_FILE"

echo "Generated $MARKETPLACE_FILE with ${#plugin_files[@]} plugins"
```

**Source:** jq techniques from [jq manual](https://jqlang.github.io/jq/manual/), adapted for this marketplace's schema.

### Example 2: validate-plugins.yml -- PR Validation Workflow

```yaml
name: Validate Plugins

on:
  pull_request:
    branches: [main]
    paths:
      - 'plugins/**'
      - 'schemas/**'
      - 'scripts/**'
      - 'tests/**'
      - 'package.json'
      - 'package-lock.json'

permissions:
  contents: read
  pull-requests: read

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      plugins: ${{ steps.filter.outputs.changes }}
      plugins_changed: ${{ steps.filter.outputs.changes != '[]' }}
      infra_changed: ${{ steps.infra.outputs.changed }}
    steps:
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            multi-cli-harness:
              - 'plugins/multi-cli-harness/**'
            grd:
              - 'plugins/GRD/**'
      - id: infra
        run: echo "changed=true" >> $GITHUB_OUTPUT
        if: >-
          contains(github.event.pull_request.changed_files, 'schemas/') ||
          contains(github.event.pull_request.changed_files, 'scripts/')

  validate-plugins:
    needs: detect-changes
    if: needs.detect-changes.outputs.plugins_changed == 'true'
    strategy:
      fail-fast: false
      matrix:
        plugin: ${{ fromJSON(needs.detect-changes.outputs.plugins) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - name: Validate ${{ matrix.plugin }}
        run: |
          # Map filter name to directory
          case "${{ matrix.plugin }}" in
            grd) dir="plugins/GRD" ;;
            *) dir="plugins/${{ matrix.plugin }}" ;;
          esac
          ./scripts/validate-plugin.sh "$dir"

  test-fixtures:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: ./scripts/run-fixture-tests.sh
```

**Source:** Composed from [dorny/paths-filter examples](https://github.com/dorny/paths-filter#examples), [GitHub Actions workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions).

### Example 3: publish-marketplace.yml -- Auto-Publish Workflow

```yaml
name: Publish Marketplace

on:
  push:
    branches: [main]
    paths:
      - 'plugins/**/plugin.json'

permissions:
  contents: write

concurrency:
  group: publish-marketplace
  cancel-in-progress: true

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - name: Generate marketplace.json
        run: ./scripts/generate-marketplace.sh
      - name: Validate generated marketplace.json
        run: |
          npx ajv validate \
            -s schemas/marketplace.schema.json \
            -d .claude-plugin/marketplace.json \
            --spec=draft7 \
            --all-errors \
            --errors=text
      - uses: stefanzweifel/git-auto-commit-action@v7
        with:
          commit_message: 'chore: regenerate marketplace.json [skip ci]'
          file_pattern: '.claude-plugin/marketplace.json'
```

**Source:** Composed from [stefanzweifel/git-auto-commit-action examples](https://github.com/stefanzweifel/git-auto-commit-action), [GitHub Actions concurrency](https://docs.github.com/en/actions/using-jobs/using-concurrency).

### Example 4: CODEOWNERS File

```
# Default owners for the marketplace infrastructure
* @ca1773130n

# Plugin-specific ownership
/plugins/multi-cli-harness/ @ca1773130n
/plugins/GRD/ @ca1773130n

# Marketplace infrastructure (schemas, scripts, workflows)
/schemas/ @ca1773130n
/scripts/ @ca1773130n
/.github/ @ca1773130n
```

**Source:** [GitHub Docs: About CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)

### Example 5: Dynamic Plugin Discovery for generate-marketplace.sh

```bash
# Alternative to static plugin list: discover all plugins dynamically
find "$REPO_ROOT/plugins" -maxdepth 2 -path '*/.claude-plugin/plugin.json' -type f | sort | while read -r pf; do
  plugin_dir="$(dirname "$(dirname "$pf")")"
  plugin_name=$(jq -r '.name' "$pf")
  echo "Found plugin: $plugin_name at $plugin_dir"
done
```

### Example 6: Enrichment Fields for marketplace.json

```bash
# Count components in a plugin for marketplace enrichment
count_files() {
  local dir="$1" pattern="$2"
  find "$dir" -name "$pattern" -type f 2>/dev/null | wc -l | tr -d ' '
}

count_jq_array() {
  local manifest="$1" field="$2"
  jq -r ".$field | if type == \"array\" then length else 0 end" "$manifest" 2>/dev/null || echo 0
}

# Example enrichment for a plugin entry
plugin_dir="plugins/GRD"
manifest="$plugin_dir/.claude-plugin/plugin.json"

commands_count=$(count_jq_array "$manifest" "commands")
agents_count=$(count_files "$plugin_dir/agents" "*.md")
hooks_type=$(jq -r '.hooks | type' "$manifest" 2>/dev/null)
if [[ "$hooks_type" == "object" ]]; then
  hooks_count=$(jq '[.. | .hooks? // empty | length] | add // 0' "$manifest" 2>/dev/null)
else
  hooks_count=0
fi
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `tj-actions/changed-files` | `dorny/paths-filter@v3` | March 2025 (CVE-2025-30066) | Supply-chain compromise forced migration. dorny/paths-filter is now the community standard. |
| `actions/cache` manual setup | `actions/setup-node@v4` built-in cache | 2023+ | Simplified caching -- no separate cache step needed. |
| `git-auto-commit-action@v4` | `git-auto-commit-action@v7` | 2024 | Better defaults, Node.js 20+ support, improved error handling. |
| `actions/checkout@v3` | `actions/checkout@v4` | 2023 | Node.js 20+ support, improved performance. |
| Manual `[skip ci]` in commit messages | GITHUB_TOKEN inherent loop prevention | Always available | `[skip ci]` is defense-in-depth, not primary mechanism. GITHUB_TOKEN is the correct solution. |

**Deprecated/outdated:**
- `tj-actions/changed-files`: Compromised in March 2025. Do not use regardless of version. Source: [CVE-2025-30066](https://www.wiz.io/blog/github-action-tj-actions-changed-files-supply-chain-attack-cve-2025-30066)
- `actions/checkout@v2`, `actions/checkout@v3`: Use v4 for Node.js 20+ and improved caching.
- `actions/setup-node@v3`: Use v4 for latest cache improvements.
- `git-auto-commit-action@v4`/`v5`/`v6`: Use v7 for Node.js 20+ support.

## Open Questions

1. **Should the paths-filter use static filter entries or dynamic plugin discovery?**
   - What we know: Static filters (`multi-cli-harness: plugins/multi-cli-harness/**`) require workflow file edits when adding new plugins. Dynamic detection (git diff + find) is self-maintaining but more complex.
   - Recommendation: Start with static filters for Phase 2 (only 2 plugins). Revisit in Phase 4 (onboarding automation) when new plugins are expected. The workflow file should include a comment noting this scaling concern.

2. **Should `generate-marketplace.sh` include enrichment fields (command count, agent count) in marketplace.json?**
   - What we know: The marketplace schema already defines `commands`, `agents`, `hooks`, `mcpServers`, `lspServers` as integer fields on plugin entries. The current marketplace.json does not include them.
   - Recommendation: YES, include enrichment fields. They are valuable for consumers and cost minimal effort (counting files/array elements in jq). This aligns with Phase 3's quality scoring which will need similar metadata.

3. **Should the validation workflow also validate marketplace.json consistency?**
   - What we know: `validate-plugin.sh` has a `--marketplace` flag that validates marketplace.json. PRs that add new plugins should also update marketplace.json... but wait, marketplace.json is auto-generated on merge. So PRs should NOT manually edit marketplace.json.
   - Recommendation: Do NOT validate marketplace.json in the PR workflow. It is auto-generated on merge. Add a `.gitattributes` or CI check that warns if a PR manually modifies marketplace.json.

4. **What GitHub username/org should CODEOWNERS reference?**
   - What we know: The repo is `ca1773130n/claude-plugin-marketplace`. The marketplace.json owner is `edward-seo`. The actual GitHub org/user needs to be verified.
   - Recommendation: Use `@ca1773130n` as the default owner. Plugin-specific owners can be added as external contributors join. Verify the correct GitHub handle before implementing.

5. **Should the publish workflow run `run-fixture-tests.sh` as a safety check before regenerating?**
   - What we know: Fixture tests validate the validation scripts, not the plugins themselves. Running them on push-to-main adds ~30 seconds but catches broken scripts.
   - Recommendation: YES, run fixture tests in the publish workflow as a pre-generation safety net. If fixture tests fail, do not regenerate marketplace.json. This prevents publishing with a broken validation pipeline.

## Sources

### Primary (HIGH confidence)
- [GitHub Docs: GITHUB_TOKEN automatic token authentication](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication) -- Loop prevention, permissions, limitations
- [GitHub Docs: Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions) -- on: triggers, permissions, concurrency
- [GitHub Docs: Skipping workflow runs](https://docs.github.com/en/actions/managing-workflow-runs/skipping-workflow-runs) -- `[skip ci]` syntax and behavior
- [GitHub Docs: About CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) -- Syntax, precedence rules, limitations
- [GitHub Docs: Using concurrency](https://docs.github.com/en/actions/using-jobs/using-concurrency) -- Concurrency groups, cancel-in-progress
- [GitHub Docs: Dependency caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows) -- Cache limits, eviction policy
- [GitHub Docs: Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions) -- pull_request vs pull_request_target, permissions

### Secondary (MEDIUM confidence)
- [dorny/paths-filter GitHub](https://github.com/dorny/paths-filter) -- v3 features, matrix strategy, file listing
- [stefanzweifel/git-auto-commit-action GitHub](https://github.com/stefanzweifel/git-auto-commit-action) -- v7 configuration, file_pattern, commit_message
- [actions/cache GitHub](https://github.com/actions/cache) -- npm cache examples, key strategies, restore-keys
- [actions/setup-node GitHub](https://github.com/actions/setup-node) -- Built-in cache, Node.js version management
- [actions/checkout GitHub](https://github.com/actions/checkout) -- fetch-depth, persist-credentials
- [CVE-2025-30066: tj-actions/changed-files compromise (Wiz)](https://www.wiz.io/blog/github-action-tj-actions-changed-files-supply-chain-attack-cve-2025-30066) -- Supply-chain attack details
- [CVE-2025-30066: tj-actions/changed-files compromise (Snyk)](https://snyk.io/blog/reconstructing-tj-actions-changed-files-github-actions-compromise/) -- Independent analysis

### Tertiary (LOW confidence)
- [Graphite: GitHub Actions caching guide](https://graphite.com/guides/github-actions-caching) -- General caching patterns
- [Aviator: Code Reviews at Scale with CODEOWNERS](https://www.aviator.co/blog/code-reviews-at-scale/) -- CODEOWNERS workflow patterns
- [StepSecurity: 7 GitHub Actions Security Best Practices](https://www.stepsecurity.io/blog/github-actions-security-best-practices) -- Security checklist

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All tools are official GitHub Actions or well-established community actions with 1000+ stars
- Architecture: HIGH -- Two-workflow pattern (validate on PR, publish on push) is the canonical CI/CD architecture
- Loop prevention: HIGH -- Official GitHub documentation confirms GITHUB_TOKEN behavior
- Security: HIGH -- CVE-2025-30066 is a documented, verified supply-chain attack
- Pitfalls: HIGH -- All pitfalls documented from official sources or verified community reports
- CODEOWNERS: MEDIUM -- Syntax verified from official docs; specific ownership handles need verification

**Research date:** 2026-02-12
**Valid until:** 2026-04-11 (60 days -- GitHub Actions and listed actions are stable, low rate of change)
