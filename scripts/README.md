# Scripts Reference

This directory contains all CLI scripts for the Claude Code Plugin Marketplace.
All scripts follow consistent conventions: `--help` for usage (exit 0),
exit 2 on invalid arguments, exit 1 on operational failure.

## Prerequisites

Run `npm ci` before using any script (required for ajv-cli JSON Schema validation).

## Quick Reference

| Script | Purpose | Arguments | Exit Codes |
|--------|---------|-----------|------------|
| validate-plugin.sh | Validate plugin structure and manifest | `<plugin-dir> [--marketplace]` | 0=pass, 1=fail, 2=usage |
| score-plugin.sh | Score plugin quality (0-100) | `<plugin-dir> [--json]` | 0=scored, 1=error, 2=usage |
| validate-local.sh | Validate + score (contributor wrapper) | `<plugin-dir>` | 0=pass, 1=fail, 2=usage |
| new-plugin.sh | Scaffold new plugin from template | `<name> [--description] [--author]` | 0=created, 1=error, 2=usage |
| generate-marketplace.sh | Regenerate marketplace.json | (none) | 0=generated, 1=error, 2=usage |
| run-fixture-tests.sh | Run validation test fixtures | (none) | 0=pass, 1=fail, 2=usage |
| run-e2e-test.sh | End-to-end pipeline test | (none) | 0=pass, 1=fail, 2=usage |

## Detailed Reference

### validate-plugin.sh

**Purpose:** Validates a Claude Code plugin using two-layer validation. Layer 1 performs JSON Schema validation via ajv-cli against `schemas/plugin.schema.json`. Layer 2 runs structural checks for file existence, permissions, and naming.

**Usage:**

```
validate-plugin.sh <plugin-dir> [--marketplace]
```

**Options:**

| Flag | Description |
|------|-------------|
| `--marketplace` | Also validate marketplace.json at repo root |
| `--help` | Show usage and exit |

**Examples:**

```bash
# Validate a single plugin
./scripts/validate-plugin.sh plugins/GetResearchDone

# Validate plugin and marketplace manifest
./scripts/validate-plugin.sh plugins/GetResearchDone --marketplace
```

**Exit Codes:**

| Code | Meaning |
|------|---------|
| 0 | All validations passed |
| 1 | Validation errors found |
| 2 | Missing dependencies or usage error |

---

### score-plugin.sh

**Purpose:** Scores a Claude Code plugin across 5 quality categories on a 100-point scale. Each category starts at 20 points; deductions are subtracted per failed check.

**Categories:**
1. Manifest Completeness (20 pts)
2. Documentation (20 pts)
3. Structure Integrity (20 pts)
4. Naming Conventions (20 pts)
5. Version Hygiene (20 pts)

**Usage:**

```
score-plugin.sh <plugin-dir> [--json]
```

**Options:**

| Flag | Description |
|------|-------------|
| `--json` | Output machine-readable JSON to stdout |
| `--help` | Show usage and exit |

**Examples:**

```bash
# Human-readable score report
./scripts/score-plugin.sh plugins/GetResearchDone

# Machine-readable JSON output
./scripts/score-plugin.sh plugins/GetResearchDone --json
```

**Exit Codes:**

| Code | Meaning |
|------|---------|
| 0 | Scoring completed successfully |
| 1 | Scoring failed (internal error) |
| 2 | Missing dependencies or usage error |

---

### validate-local.sh

**Purpose:** Convenience wrapper for contributors. Runs validation followed by quality scoring on a plugin directory. Validation must pass; scoring is informational.

**Usage:**

```
validate-local.sh <plugin-dir>
```

**Steps:**
1. Validates plugin structure and manifest (validate-plugin.sh)
2. Scores plugin quality across 5 categories (score-plugin.sh)

**Examples:**

```bash
# Check your plugin before submitting a PR
./scripts/validate-local.sh plugins/my-plugin
```

**Exit Codes:**

| Code | Meaning |
|------|---------|
| 0 | Validation passed (scoring is informational) |
| 1 | Validation failed |
| 2 | Usage error or missing directory |

---

### new-plugin.sh

**Purpose:** Scaffolds a new Claude Code plugin from the template directory (`templates/plugin-template/`). Generates all required files including plugin.json, README.md, CHANGELOG.md, and directory structure via jq.

**Usage:**

```
new-plugin.sh <plugin-name> [--description "..."] [--author "..."]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `plugin-name` | Plugin identifier (lowercase, hyphens allowed, must start with letter) |

**Options:**

| Flag | Description |
|------|-------------|
| `--description "..."` | Plugin description (default: "A Claude Code plugin") |
| `--author "..."` | Author name (default: git config user.name or "Your Name") |
| `--help` | Show usage and exit |

**Examples:**

```bash
# Scaffold with defaults
./scripts/new-plugin.sh my-plugin

# Scaffold with custom metadata
./scripts/new-plugin.sh my-plugin --description "Does useful things" --author "Jane Doe"
```

**Exit Codes:**

| Code | Meaning |
|------|---------|
| 0 | Plugin scaffolded successfully |
| 1 | Scaffold error (collision, template missing) |
| 2 | Usage error (invalid name, missing args) |

---

### generate-marketplace.sh

**Purpose:** Generates `.claude-plugin/marketplace.json` from all `plugin.json` files found under `plugins/`. Dynamically discovers plugins, extracts metadata (detecting git submodule URLs automatically), and validates the result against the marketplace schema.

**Usage:**

```
generate-marketplace.sh
```

**Options:**

| Flag | Description |
|------|-------------|
| `--help` | Show usage and exit |

**Examples:**

```bash
# Regenerate marketplace manifest from all plugins
./scripts/generate-marketplace.sh
```

**Exit Codes:**

| Code | Meaning |
|------|---------|
| 0 | marketplace.json generated and validated successfully |
| 1 | Generation or validation failed |
| 2 | Missing dependencies or no plugins found |

---

### run-fixture-tests.sh

**Purpose:** Runs the fixture test suite, validating all test fixtures under `tests/fixtures/` and real plugins (dynamically discovered). Expects specific exit codes from validate-plugin.sh for each fixture.

**Test Coverage:**
- 4 valid fixtures (expect exit 0)
- 4 invalid fixtures (expect exit 1)
- 1 extra-fields fixture (expect exit 0 by design)
- Real plugins with plugin.json (expect exit 0, dynamically discovered)

**Usage:**

```
run-fixture-tests.sh
```

**Options:**

| Flag | Description |
|------|-------------|
| `--help` | Show usage and exit |

**Examples:**

```bash
# Run all fixture tests
./scripts/run-fixture-tests.sh
```

**Exit Codes:**

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |
| 2 | Usage error |

---

### run-e2e-test.sh

**Purpose:** Runs end-to-end integration test of the full plugin pipeline. Tests the complete lifecycle: scaffold a plugin, validate it, score it, generate the marketplace manifest, verify the result, and clean up.

**Pipeline Steps:**
1. Scaffold a test plugin via new-plugin.sh
2. Validate the scaffolded plugin via validate-plugin.sh
3. Score the plugin via score-plugin.sh
4. Regenerate marketplace.json via generate-marketplace.sh
5. Verify the plugin appears in marketplace.json
6. Clean up the test plugin

**Usage:**

```
run-e2e-test.sh
```

**Options:**

| Flag | Description |
|------|-------------|
| `--help` | Show usage and exit |

**Examples:**

```bash
# Run E2E pipeline test
./scripts/run-e2e-test.sh
```

**Exit Codes:**

| Code | Meaning |
|------|---------|
| 0 | All E2E tests passed |
| 1 | Test failure |
| 2 | Usage error or missing dependencies |

## Conventions

All scripts follow these patterns:
- Shebang: `#!/usr/bin/env bash`
- Error handling: `set -euo pipefail`
- Path resolution: `SCRIPT_DIR` and `REPO_ROOT` via `cd + pwd`
- macOS bash 3.x compatible (no associative arrays, no GNU-specific flags)
- `--help` / `-h` prints usage and exits 0
- Unknown arguments exit 2 with error message to stderr
- Operational failures exit 1

## CI Integration

These scripts are invoked by GitHub Actions workflows:
- `validate-plugins.yml` -- Runs validate-plugin.sh and score-plugin.sh on PRs
- `publish-marketplace.yml` -- Runs generate-marketplace.sh on merge to main
- `self-test.yml` -- Runs run-fixture-tests.sh, run-e2e-test.sh, and --help checks
