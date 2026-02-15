# Phase 4: Plugin Onboarding Automation - Research

**Researched:** 2026-02-15
**Domain:** Project scaffolding, GitHub templates, contributor onboarding, portable Bash scripting
**Confidence:** HIGH

## Summary

Phase 4 creates the tooling and documentation that lets a new contributor go from zero to a submitted plugin PR in under 10 minutes. The deliverables are: a plugin template directory, a scaffolding script (`new-plugin.sh`), GitHub Issue/PR templates, a `CONTRIBUTING.md` guide, and a `validate-local.sh` wrapper. The domain is well-understood: Bash-based file templating with `sed`/`jq` substitutions, GitHub template YAML/Markdown, and contributor documentation.

The primary technical risk is **macOS BSD `sed` vs GNU `sed` incompatibility** in the scaffolding script. The system under development runs Bash 3.2.57 (confirmed) on macOS, which lacks associative arrays, GNU `sed -i` semantics, and GNU `find` flags. The research below provides a portable strategy that avoids `sed -i` entirely in favor of `jq` for JSON manipulation and a temporary-file pattern for text substitution.

A secondary concern is **achieving the >= 40 quality score target** for the generated scaffold. Detailed rule-by-rule analysis shows that including `plugin.json` with all optional fields, a 50+ line `README.md`, a `CLAUDE.md`, a `CHANGELOG.md`, and a `VERSION` file yields a score of 93-95 out of 100 -- well above the 40-point threshold. The template should be designed to score as high as possible so contributors start from a strong baseline.

**Primary recommendation:** Build `new-plugin.sh` using `jq` for all JSON generation (not `sed` on JSON files), use the temporary-file pattern for any text substitutions, and structure the template as a complete plugin directory that passes validation out of the box.

## User Constraints (from CONTEXT.md)

No CONTEXT.md exists for this phase. All design decisions are at Claude's discretion, constrained only by the ROADMAP.md scope and CLAUDE.md project constraints.

### Locked Decisions
None -- no prior `/grd:discuss-phase` decisions recorded.

### Claude's Discretion
All implementation choices are open, within the ROADMAP.md scope:
- Template directory structure and content
- Scaffolding script approach and variable substitution method
- PR template sections and checklist items
- Issue template format (YAML form vs Markdown)
- CONTRIBUTING.md structure and level of detail
- validate-local.sh implementation approach

### Deferred Ideas (OUT OF SCOPE)
None specified.

## Paper-Backed Recommendations

### Recommendation 1: Template-Based Scaffolding with Parameterized JSON Generation

**Recommendation:** Use `jq` to generate `plugin.json` from template values rather than `sed`-substituting placeholders in a JSON file. Use a copy-and-rename approach for non-JSON template files.

**Evidence:**
- "How to Write Portable Shell Scripts" (OneUpTime, 2026) -- Documents that `sed -i` is the #1 portability failure between BSD and GNU systems. Recommends avoiding `sed -i` entirely for critical operations.
- "Writing portable Bash scripts across different UNIX flavors" (LinuxBash.sh, 2025) -- Catalogs 15+ differences between BSD and GNU utilities. Recommends using language-native tools (like `jq` for JSON) instead of text manipulation.
- bash3boilerplate (kvz/bash3boilerplate, GitHub, 2.3k stars) -- Demonstrates the pattern of using templates with variable expansion rather than sed substitution for robust scaffolding.
- "Portable sed -i across MacOS and Linux" (John D. Cook, 2023) -- Confirms that `sed -i ''` (BSD) vs `sed -i` (GNU) is a persistent incompatibility with no clean single-syntax solution.

**Confidence:** HIGH -- Multiple independent sources confirm the `sed -i` portability issue. Using `jq` for JSON generation sidesteps the problem entirely.

**Expected improvement:** Zero portability failures on macOS (Bash 3.2.57, confirmed on this system) and Linux CI (Ubuntu, Bash 5.x).

**Caveats:** Non-JSON files (README.md, CLAUDE.md) still need variable substitution. The portable approach is: `sed "s/PLACEHOLDER/value/g" template > output` (no `-i` flag, write to new file).

### Recommendation 2: GitHub Issue Forms (YAML) Over Markdown Templates

**Recommendation:** Use YAML-based issue forms (`.yml` extension) for the plugin request template, and Markdown for the PR template.

**Evidence:**
- GitHub Docs: "Syntax for issue forms" (docs.github.com) -- YAML issue forms support input validation, dropdowns, and required fields natively. This prevents incomplete submissions without manual review.
- GitHub Docs: "About issue and pull request templates" (docs.github.com) -- PR templates only support Markdown format (no YAML forms). Issue templates support both formats.
- pkbullock.com "GitHub Tip: Adding Issue Forms" (2024) -- Demonstrates that YAML forms with `type: input`, `type: dropdown`, and `type: checkboxes` create structured, parseable issue bodies.

**Confidence:** HIGH -- Official GitHub documentation.

**Caveats:** YAML issue forms are not supported in GitHub Enterprise Server versions before 3.6. This is irrelevant for github.com public repos.

### Recommendation 3: Maximalist Template Scaffold for Quality Score Optimization

**Recommendation:** Design the scaffold template to achieve the highest possible quality score (target: >= 90), not just the minimum 40-point threshold.

**Evidence:**
- Analysis of the project's own scoring rubric (`score-plugin.sh`, 30 rules across 5 categories) shows that every deduction is avoidable in a template:
  - Manifest Completeness: All 8 fields can have placeholder values (20/20)
  - Documentation: README with 50+ lines and CLAUDE.md with content (20/20)
  - Structure Integrity: `.claude-plugin/` exists, all declared files exist (20/20)
  - Naming Conventions: lowercase-hyphenated name, consistent agent prefix (20/20)
  - Version Hygiene: `1.0.0` version, matching VERSION file, CHANGELOG.md present (20/20)
- Skypack Quality Score philosophy: "Start high, deduct for issues." A maximalist template means contributors only lose points when they intentionally remove things, not when they forget to add them.
- npm package.json generator (`npm init`) -- Creates a complete package.json with all standard fields filled, following the principle that a scaffold should be production-ready by default.

**Confidence:** HIGH -- Direct analysis of the scoring code confirms achievability.

**Expected improvement:** Contributors start at 93+ quality score instead of needing to manually fill in 15+ fields to reach 40.

**Caveats:** The `-2 pre-1.0 version` deduction is avoidable by defaulting to `1.0.0`, but some contributors may prefer `0.1.0` for initial development. The template should use `1.0.0` with a comment explaining the choice.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | 3.2+ | Script runtime | macOS default, project constraint |
| jq | 1.7+ | JSON generation for plugin.json | Already a project dependency, avoids sed-on-JSON portability issues |
| cp/mkdir | POSIX | File/directory copying | Universal, no compatibility issues |
| sed | BSD/GNU | Text placeholder substitution (non-JSON only) | Used without `-i` flag for portability |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| validate-plugin.sh | existing | Validate scaffold output | Called by validate-local.sh |
| score-plugin.sh | existing | Score scaffold output | Called by validate-local.sh for feedback |
| basename/dirname | POSIX | Path manipulation | Used in new-plugin.sh |

### Alternatives Considered
| Instead of | Could Use | Tradeoff | Decision |
|------------|-----------|----------|----------|
| jq for JSON | sed on plugin.json | sed is simpler but has quoting/escaping issues with JSON special chars | Use jq |
| cp template dir | tar archive | tar adds complexity, no benefit | Use cp -r |
| YAML issue forms | Markdown issue template | Markdown is simpler but lacks validation | Use YAML for issues |
| Single PR template | Multiple PR templates | Multiple adds overhead for one use case | Use single template |

**Installation:**
```bash
# No new dependencies -- jq and bash already required by project
npm ci  # Ensures ajv-cli is available for validation
```

## Architecture Patterns

### Recommended Project Structure
```
templates/
└── plugin-template/           # Complete scaffold template
    ├── .claude-plugin/
    │   └── plugin.json        # Generated by jq, not copied
    ├── agents/
    │   └── {{name}}-example-agent.md
    ├── commands/
    │   └── example.md
    ├── skills/                # Empty but declared (optional)
    ├── CLAUDE.md              # Template with {{PLUGIN_NAME}} placeholders
    ├── README.md              # 50+ line template
    ├── CHANGELOG.md           # Initial changelog entry
    └── VERSION                # "1.0.0"

scripts/
├── new-plugin.sh             # Scaffolding script
└── validate-local.sh         # Local validation wrapper

.github/
├── ISSUE_TEMPLATE/
│   └── plugin-request.yml    # YAML issue form
└── PULL_REQUEST_TEMPLATE/
    └── plugin-submission.md  # Markdown PR template

CONTRIBUTING.md               # Step-by-step contributor guide
```

### Pattern 1: jq-Based JSON Generation
**What:** Generate `plugin.json` by constructing JSON with `jq` rather than substituting text in a template file.
**When to use:** Always, for any JSON file in the scaffold.
**Example:**
```bash
# Source: project convention, verified with jq docs
jq -n \
  --arg name "$PLUGIN_NAME" \
  --arg desc "$DESCRIPTION" \
  --arg author "$AUTHOR" \
  '{
    name: $name,
    version: "1.0.0",
    description: $desc,
    author: { name: $author },
    homepage: "",
    repository: "",
    license: "MIT",
    keywords: [],
    commands: ["./commands/example.md"]
  }' > "$DEST/.claude-plugin/plugin.json"
```

### Pattern 2: Portable Text Substitution (No sed -i)
**What:** Use `sed` to write to a new file, never in-place. For template files, read from template and write to destination.
**When to use:** For README.md, CLAUDE.md, and other text files with placeholders.
**Example:**
```bash
# Source: "Portable sed -i" (John D. Cook, 2023)
# BSD-compatible: never use sed -i
sed "s/{{PLUGIN_NAME}}/$PLUGIN_NAME/g" \
    "$TEMPLATE_DIR/README.md" > "$DEST/README.md"
```

### Pattern 3: Validation-First Scaffold Verification
**What:** After scaffolding, immediately run validation and scoring to confirm the output is valid.
**When to use:** At the end of `new-plugin.sh` to give the contributor instant feedback.
**Example:**
```bash
# Run validation
echo "Validating scaffold..."
if "$SCRIPT_DIR/validate-plugin.sh" "$DEST"; then
  echo "PASS: Scaffold validates successfully"
else
  echo "FAIL: Scaffold has validation errors -- please report this bug"
  exit 1
fi

# Run scoring
echo ""
"$SCRIPT_DIR/score-plugin.sh" "$DEST"
```

### Anti-Patterns to Avoid
- **sed -i on macOS:** BSD `sed -i` requires a backup extension argument; GNU does not. Using `sed -i ''` fails on Linux. Never use `sed -i` in this project.
- **Heredoc JSON construction:** Using `cat <<EOF` to build JSON is fragile -- special characters in user input will break the JSON. Always use `jq` for JSON construction.
- **Associative arrays in Bash:** Bash 3.x (macOS default) does not support `declare -A`. Use indexed arrays or jq for key-value pairs.
- **GNU find flags:** `-regextype`, `-printf`, `-maxdepth` as non-first argument are not portable. Use POSIX-compatible find usage.
- **Template with agents/ and skills/ directories that are empty:** Empty artifact directories incur a -2 scoring deduction (Rule 18). Either populate them with example files or do not create them.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON generation | sed/echo/heredoc on JSON strings | `jq -n --arg` | jq handles escaping, quoting, and structure correctly |
| JSON Schema validation | Custom bash checks | `npx ajv validate` | Already in the project, comprehensive and correct |
| Quality scoring | Manual checklist | `score-plugin.sh` | Already exists, 30 rules, JSON output |
| Plugin validation | Recreate checks | `validate-plugin.sh` | Already exists, two-layer validation |
| PR comment formatting | Custom comment script | `thollander/actions-comment-pull-request` | Already used in CI |

**Key insight:** Phase 4 should compose existing Phase 1-3 tools, not rebuild any validation/scoring logic. The scaffolding script's job is file generation; verification uses existing scripts.

## Common Pitfalls

### Pitfall 1: sed -i Portability Failure
**What goes wrong:** Script works on developer's Linux machine, fails on macOS CI or contributor machines. Or works on macOS with `sed -i ''` but fails on Linux where empty string is not recognized.
**Why it happens:** BSD sed (macOS) requires `sed -i extension` while GNU sed (Linux) uses `sed -i` with no argument.
**How to avoid:** Never use `sed -i`. Always write to a new file: `sed 's/X/Y/' input > output`.
**Warning signs:** Any occurrence of `sed -i` in a script file.
**Source:** "Portable sed -i across MacOS and Linux" (John D. Cook, 2023); confirmed by testing on Bash 3.2.57 on this system.

### Pitfall 2: Template Plugin Name Containing Special Characters
**What goes wrong:** If a user passes a plugin name with spaces, uppercase, or special characters, the scaffold generates an invalid `plugin.json` (fails schema validation where name must match `^[a-z][a-z0-9-]*$`).
**Why it happens:** No input validation on the `<name>` argument.
**How to avoid:** Validate the name argument against the schema regex before any file operations. Exit with clear error message if invalid.
**Warning signs:** Script proceeds without checking `$1`.

### Pitfall 3: Template Score Regression
**What goes wrong:** A change to the template reduces the scaffold's quality score below 40, breaking the success criterion, but nobody notices because there's no test.
**How to avoid:** Add a test fixture test or a CI step that scaffolds a plugin and scores it, asserting >= 40.
**Warning signs:** Template changes without running `score-plugin.sh` on the output.

### Pitfall 4: CI Filter Not Updated for New Plugin
**What goes wrong:** A new plugin is submitted and merged, but CI never runs validation on it because `validate-plugins.yml` has a hardcoded `dorny/paths-filter` list.
**Why it happens:** The `filters:` section in `validate-plugins.yml` requires a manual entry per plugin (see lines 29-32 of the current workflow).
**How to avoid:** Document this requirement prominently in CONTRIBUTING.md and the PR template checklist. Optionally, add a wildcard filter `'plugins/**'` that catches all plugin changes.
**Warning signs:** PR merged without validation comment appearing.

### Pitfall 5: Inconsistent Agent Naming in Scaffold
**What goes wrong:** Template agent file is named `example-agent.md` but the plugin name is `my-tool`, leading to an inconsistent naming deduction (-4 points, Rule 20) when the contributor adds their own agents without following a prefix pattern.
**Why it happens:** Agent naming convention check looks for majority-prefix consistency.
**How to avoid:** Name the template agent `{{name}}-example-agent.md` so it establishes the correct prefix convention from the start. When the contributor adds more agents, they follow the pattern naturally.
**Warning signs:** Agent files in the template that don't use the plugin name as a prefix.

## Experiment Design

### Recommended Experimental Setup

**Independent variables:**
- Template content completeness (minimal vs. full)
- Scaffolding method (jq-based vs. sed-based vs. cp-only)

**Dependent variables:**
- Quality score of generated scaffold (target: >= 40, stretch: >= 90)
- Validation pass/fail of generated scaffold
- Time to scaffold (should be < 2 seconds)
- Portability (works on both Bash 3.2 macOS and Bash 5.x Linux)

**Controlled variables:**
- Validation and scoring scripts (unchanged from Phase 3)
- Schema (unchanged from Phase 1)

**Baseline comparison:**
- Method: Manual plugin creation (current state -- no scaffolding)
- Expected performance: ~30 minutes for experienced developer, ~1 hour for new contributor
- Our target: < 10 minutes total (scaffold + customize + submit PR)

**Ablation plan:**
1. Full scaffold vs. minimal scaffold (name-only) -- tests whether maximalist template actually helps contributors
2. validate-local.sh vs. raw validate-plugin.sh -- tests whether the wrapper improves contributor experience

**Statistical rigor:**
- Not applicable for this phase (infrastructure tooling, not algorithmic)
- Verification is binary: does the scaffold pass validation and score >= 40? Yes/No.

### Recommended Metrics

| Metric | Why | How to Compute | Target |
|--------|-----|----------------|--------|
| Scaffold quality score | Primary success criterion | `score-plugin.sh templates/plugin-template --json \| jq .total` | >= 40 (threshold), >= 90 (stretch) |
| Scaffold validation | Must pass | `validate-plugin.sh templates/plugin-template; echo $?` | Exit code 0 |
| Script portability | Must work on macOS + Linux | Run on Bash 3.2 (macOS) and Bash 5.x (Ubuntu) | Both pass |
| Onboarding time | UX criterion | Manual timing of scaffold-to-PR flow | < 10 minutes |

## Verification Strategy

### Recommended Verification Tiers for This Phase

| Item | Recommended Tier | Rationale |
|------|-----------------|-----------|
| Template passes validation | Level 1 (Sanity) | Run validate-plugin.sh on template dir |
| Template scores >= 40 | Level 1 (Sanity) | Run score-plugin.sh on template dir |
| new-plugin.sh generates valid plugin | Level 1 (Sanity) | Run script, then validate output |
| new-plugin.sh rejects bad names | Level 1 (Sanity) | Test with invalid inputs |
| validate-local.sh works | Level 1 (Sanity) | Run on a real plugin |
| Scaffold works on Bash 3.2 | Level 2 (Proxy) | Test on macOS locally |
| PR template renders correctly | Level 2 (Proxy) | Visual check on GitHub |
| Issue template renders correctly | Level 2 (Proxy) | Visual check on GitHub |
| Fixture tests still pass | Level 1 (Sanity) | run-fixture-tests.sh must still pass |
| Full onboarding flow < 10 min | Level 3 (Deferred) | Requires a real contributor trial |
| CI filter updated for scaffold plugin | Level 3 (Deferred) | Requires actual PR submission |

**Level 1 checks to always include:**
- `validate-plugin.sh templates/plugin-template` exits 0
- `score-plugin.sh templates/plugin-template --json | jq .total` >= 40
- `new-plugin.sh test-plugin` creates `plugins/test-plugin/` with valid structure
- `new-plugin.sh INVALID NAME` exits with error
- `new-plugin.sh` with no args prints usage and exits 2
- `validate-local.sh plugins/GRD` exits 0 (works on existing plugin)
- `run-fixture-tests.sh` still passes (no regression)

**Level 2 proxy metrics:**
- Run `new-plugin.sh` on Bash 3.2 (this system) -- confirms macOS compatibility
- Inspect generated `plugin.json` with `jq .` -- confirms valid JSON
- Check README.md line count >= 50

**Level 3 deferred items:**
- Real contributor onboarding trial (needs a volunteer)
- GitHub Actions CI run with a scaffold-generated plugin PR
- End-to-end: scaffold -> PR -> validation -> scoring -> merge -> marketplace.json update

## Production Considerations (from KNOWHOW.md)

No KNOWHOW.md exists for this project. The following considerations are derived from project constraints documented in CLAUDE.md and the existing codebase:

### Known Failure Modes
- **BSD/GNU sed incompatibility:** The most common cross-platform scripting failure. Already mitigated by the "no sed -i" rule.
  - Prevention: Use `jq` for JSON, `sed` without `-i` for text, always write to new files.
  - Detection: CI runs on Ubuntu (GNU); local dev on macOS (BSD). Both environments must be tested.

- **Bash 3.x incompatibility:** macOS ships Bash 3.2.57. Associative arrays (`declare -A`), `readarray`/`mapfile`, `${var^^}` (uppercase), and `|&` (pipe both) are unavailable.
  - Prevention: Never use Bash 4+ features. Test locally on macOS before committing.
  - Detection: `bash --version` check or shellcheck with `--shell=bash` and Bash 3.x target.

### Scaling Concerns
- **Template maintenance:** As the schema evolves (new fields like `outputStyles`, `lspServers`), the template must be updated. This is manual but low-frequency.
  - At current scale: Manual update when schema changes.
  - At production scale: Could auto-generate template from schema (future Phase 5+ consideration).

### Common Implementation Traps
- **Hardcoded paths in template:** Template files should use `{{PLUGIN_NAME}}` or `${CLAUDE_PLUGIN_ROOT}` placeholders, not absolute paths.
  - Correct approach: All paths in template are relative (start with `./`).

- **Forgetting to update dorny/paths-filter:** When a new plugin is added, the CI workflow needs a new filter entry. This is easy to forget.
  - Correct approach: Document prominently in CONTRIBUTING.md, include in PR template checklist, and consider a wildcard filter.

## Code Examples

Verified patterns from the project's existing codebase and official tool documentation:

### Portable Plugin Name Validation
```bash
# Source: plugin.schema.json name pattern: ^[a-z][a-z0-9-]*$
validate_plugin_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Error: Plugin name is required." >&2
    return 1
  fi
  if ! echo "$name" | grep -qE '^[a-z][a-z0-9-]*$'; then
    echo "Error: Plugin name must be lowercase letters, digits, and hyphens (e.g., 'my-plugin')." >&2
    echo "Pattern: ^[a-z][a-z0-9-]*$" >&2
    return 1
  fi
  if [[ ${#name} -gt 64 ]]; then
    echo "Error: Plugin name must be 64 characters or fewer." >&2
    return 1
  fi
}
```

### jq-Based plugin.json Generation
```bash
# Source: project convention (validate-plugin.sh, generate-marketplace.sh use jq throughout)
generate_plugin_json() {
  local name="$1"
  local description="${2:-A Claude Code plugin}"
  local author="${3:-$(git config user.name 2>/dev/null || echo 'Your Name')}"

  jq -n \
    --arg name "$name" \
    --arg desc "$description" \
    --arg author "$author" \
    '{
      name: $name,
      version: "1.0.0",
      description: $desc,
      author: { name: $author },
      homepage: "",
      repository: "",
      license: "MIT",
      keywords: [],
      commands: ["./commands/example.md"],
      agents: ["./agents/" + $name + "-example-agent.md"]
    }'
}
```

### Portable sed Substitution (No -i Flag)
```bash
# Source: "Portable sed -i" (John D. Cook, 2023)
# Works on both BSD sed (macOS) and GNU sed (Linux)
substitute_placeholders() {
  local template_file="$1"
  local output_file="$2"
  local plugin_name="$3"
  local plugin_description="${4:-A Claude Code plugin}"

  sed \
    -e "s/{{PLUGIN_NAME}}/$plugin_name/g" \
    -e "s/{{PLUGIN_DESCRIPTION}}/$plugin_description/g" \
    "$template_file" > "$output_file"
}
```

### validate-local.sh Wrapper Pattern
```bash
# Source: project convention (existing scripts use SCRIPT_DIR/REPO_ROOT pattern)
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PLUGIN_DIR="${1:?Usage: $(basename "$0") <plugin-dir>}"

# Resolve to absolute path
if [[ "$PLUGIN_DIR" != /* ]]; then
  PLUGIN_DIR="$(cd "$PLUGIN_DIR" 2>/dev/null && pwd)" || {
    echo "Error: Plugin directory '$1' not found." >&2
    exit 2
  }
fi

echo "=== Validation ==="
"$SCRIPT_DIR/validate-plugin.sh" "$PLUGIN_DIR"
echo ""
echo "=== Quality Score ==="
"$SCRIPT_DIR/score-plugin.sh" "$PLUGIN_DIR"
```

### GitHub Issue Form (YAML)
```yaml
# Source: GitHub Docs "Syntax for issue forms"
name: Plugin Request
description: Request a new plugin be added to the marketplace
title: "[Plugin Request]: "
labels: ["plugin-request"]
body:
  - type: input
    id: plugin-name
    attributes:
      label: Plugin Name
      description: lowercase-hyphenated identifier (e.g., my-awesome-plugin)
      placeholder: my-plugin
    validations:
      required: true
  - type: textarea
    id: description
    attributes:
      label: Description
      description: What does this plugin do?
    validations:
      required: true
  - type: dropdown
    id: category
    attributes:
      label: Category
      options:
        - development
        - productivity
        - testing
        - documentation
        - other
    validations:
      required: true
  - type: input
    id: repository
    attributes:
      label: Source Repository
      description: URL of the plugin's git repository (if external)
      placeholder: https://github.com/user/repo
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Markdown issue templates | YAML issue forms | GitHub 2022 | Structured input with validation, dropdowns, checkboxes |
| `sed -i` for in-place editing | Write to new file / use jq | Long-standing best practice | Cross-platform portability |
| Manual plugin creation | Scaffold template + script | Phase 4 (this phase) | 10x faster onboarding |

**Deprecated/outdated:**
- Markdown-only issue templates: Still supported but YAML forms provide validation and structured input. Use YAML for issues, Markdown for PRs (PR templates only support Markdown).

## Open Questions

1. **Should `new-plugin.sh` auto-update `validate-plugins.yml` with a new dorny/paths-filter entry?**
   - What we know: The filter list is hardcoded YAML. Programmatic YAML editing in Bash is fragile.
   - What's unclear: Whether the complexity of auto-updating YAML is worth it vs. documenting it in CONTRIBUTING.md.
   - Recommendation: Do NOT auto-update the workflow file. Instead, document the manual step prominently in CONTRIBUTING.md and include it as a PR template checklist item. Consider a future enhancement using a wildcard filter (`plugins/**`) in Phase 5.

2. **Should the template include an agents/ directory by default?**
   - What we know: Both existing plugins have agents. The scoring rubric deducts for empty artifact directories (-2, Rule 18) and undeclared artifact directories (-2, Rule 8/16).
   - What's unclear: Whether most new plugins will need agents.
   - Recommendation: YES, include `agents/` with one example agent file (`{{name}}-example-agent.md`) and declare it in `plugin.json`. This avoids empty-directory deductions and establishes the naming convention.

3. **Should the template include a skills/ directory?**
   - What we know: Only multi-cli-harness has skills. Creating an empty skills/ directory would cause a -2 deduction.
   - Recommendation: NO, do not include skills/ by default. Mention it in CONTRIBUTING.md as an optional addition.

4. **What default version should the template use: 0.1.0 or 1.0.0?**
   - What we know: `0.x.y` incurs a -2 deduction (Rule 27, pre-1.0 version). GRD uses 0.1.0, multi-cli-harness uses 1.0.0.
   - Recommendation: Use `1.0.0` in the template to maximize score. Add a comment in CONTRIBUTING.md explaining the choice and noting that `0.x.y` is acceptable for early-stage plugins at a 2-point cost.

## Scaffold Quality Score Analysis

Detailed rule-by-rule analysis of what a well-designed template would score:

### Category 1: Manifest Completeness (20/20 possible)
| Rule | Check | Template Status | Points |
|------|-------|----------------|--------|
| 1 | description | Populated with placeholder | 0 deduction |
| 2 | version | "1.0.0" | 0 deduction |
| 3 | author | { name: "..." } | 0 deduction |
| 4 | homepage | "" (empty string counts as present) | -2 deduction* |
| 5 | repository | "" (empty string counts as present) | -2 deduction* |
| 6 | license | "MIT" | 0 deduction |
| 7 | keywords | [] (empty array, type is "array" not "null") | 0 deduction |
| 8 | undeclared artifacts | All dirs declared | 0 deduction |

*Note: Rules 4-5 check for empty strings. The scoring code uses `jq -r '.homepage // empty'` which returns empty for both null and empty string. So `""` values WILL incur deductions. The template should use placeholder URLs like `https://github.com/YOUR-USERNAME/YOUR-PLUGIN` to avoid this.

**Expected: 20/20** (with placeholder URLs) or **16/20** (with empty strings)

### Category 2: Documentation (20/20 possible)
| Rule | Check | Template Status | Points |
|------|-------|----------------|--------|
| 9 | README.md exists | Yes, 50+ lines | 0 deduction |
| 10 | CLAUDE.md exists | Yes | 0 deduction |
| 11 | README >= 50 lines | Template designed for 50+ lines | 0 deduction |
| 12 | description >= 20 chars | Template description is descriptive | 0 deduction |
| 13 | keywords present | Array exists | 0 deduction |

**Expected: 20/20**

### Category 3: Structure Integrity (20/20 possible)
| Rule | Check | Template Status | Points |
|------|-------|----------------|--------|
| 14 | .claude-plugin/ exists | Yes | 0 deduction |
| 15 | declared files exist | All exist | 0 deduction |
| 16 | undeclared artifact dirs | None | 0 deduction |
| 17 | hook scripts executable | No hooks in template | 0 deduction |
| 18 | empty artifact dirs | None empty (agents/ has file, commands/ has file) | 0 deduction |

**Expected: 20/20**

### Category 4: Naming Conventions (20/20 possible)
| Rule | Check | Template Status | Points |
|------|-------|----------------|--------|
| 19 | lowercase-hyphenated name | Enforced by new-plugin.sh | 0 deduction |
| 20 | consistent agent naming | Single agent with correct prefix | 0 deduction |
| 21 | commands in standard dir | ./commands/ | 0 deduction |
| 22 | agent .md extension | Yes | 0 deduction |
| 23 | valid semver | "1.0.0" | 0 deduction |
| 24 | no unexpected fields | Only known fields used | 0 deduction |

**Expected: 20/20**

### Category 5: Version Hygiene (20/20 possible)
| Rule | Check | Template Status | Points |
|------|-------|----------------|--------|
| 25 | version present | "1.0.0" | 0 deduction |
| 26 | valid semver | "1.0.0" | 0 deduction |
| 27 | pre-1.0 | 1.0.0 (not pre-1.0) | 0 deduction |
| 28 | VERSION file match | VERSION contains "1.0.0" | 0 deduction |
| 29 | CHANGELOG.md exists | Yes | 0 deduction |
| 30 | no build metadata | No "+" in version | 0 deduction |

**Expected: 20/20**

### Total Expected: 100/100 (with placeholder URLs) or 96/100 (with empty strings)

This far exceeds the >= 40 threshold. Even if a contributor removes half the optional fields, the score would stay above 60.

## Sources

### Primary (HIGH confidence)
- `schemas/plugin.schema.json` -- Plugin manifest schema (field names, patterns, required fields)
- `scripts/score-plugin.sh` -- All 30 scoring rules with exact deduction values
- `scripts/validate-plugin.sh` -- Two-layer validation logic
- `QUALITY.md` -- Scoring rubric documentation
- `validate-plugins.yml` -- CI workflow with dorny/paths-filter pattern
- GitHub Docs: [Syntax for issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
- GitHub Docs: [About issue and pull request templates](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/about-issue-and-pull-request-templates)

### Secondary (MEDIUM confidence)
- [Portable sed -i across MacOS and Linux](https://www.johndcook.com/blog/2023/10/18/portable-sed-i/) -- John D. Cook (2023)
- [Writing portable Bash scripts across different UNIX flavors](https://www.linuxbash.sh/post/writing-portable-bash-scripts-across-different-unix-flavors) -- LinuxBash.sh
- [How to Write Portable Shell Scripts](https://oneuptime.com/blog/post/2026-01-24-portable-shell-scripts/view) -- OneUpTime (2026)
- [bash3boilerplate](https://github.com/kvz/bash3boilerplate) -- Bash 3 compatible script templates (2.3k stars)
- [Fixing 'sed -i' In-Place Edit Errors Across GNU and BSD/macOS Systems](https://sqlpey.com/bash/sed-in-place-portability-fix/)

### Tertiary (LOW confidence)
- [GitHub PR template best practices](https://axolo.co/blog/p/part-3-github-pull-request-template) -- Axolo blog
- [Enhancing Pull Request Descriptions Templates](https://www.gitkraken.com/blog/enhancing-pull-request-descriptions-templates) -- GitKraken blog

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools already in the project, no new dependencies
- Architecture: HIGH - File copy + jq generation is straightforward, patterns verified in existing scripts
- Paper recommendations: HIGH - Portability issues are well-documented with multiple independent sources
- Pitfalls: HIGH - sed portability is the #1 documented issue; verified bash version is 3.2.57 on this system
- Experiment design: HIGH - Binary verification (passes validation or not), clear metrics
- Scaffold scoring: HIGH - Direct analysis of scoring source code, rule-by-rule verification

**Research date:** 2026-02-15
**Valid until:** 2026-06-15 (stable domain -- bash scripting and GitHub templates change slowly)
