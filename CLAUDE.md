# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A Claude Code plugin marketplace -- hosts plugins under `plugins/` and provides infrastructure for validation, quality scoring, and automated publishing via CI. The marketplace manifest at `.claude-plugin/marketplace.json` is auto-generated; never edit it by hand.

## Commands

```bash
# Install dependencies (required before any script)
npm ci

# Validate a single plugin
./scripts/validate-plugin.sh plugins/GRD
./scripts/validate-plugin.sh plugins/multi-cli-harness

# Score a plugin (human-readable)
./scripts/score-plugin.sh plugins/GRD

# Score a plugin (JSON)
./scripts/score-plugin.sh plugins/GRD --json

# Run all fixture tests (validates both real plugins + 9 test fixtures)
./scripts/run-fixture-tests.sh

# Regenerate marketplace.json from all plugins
./scripts/generate-marketplace.sh
```

## Architecture

**Toolchain:** Bash + jq + ajv-cli (JSON Schema Draft-07). No build step. All scripts are standalone bash.

**Validation pipeline (two layers):**
1. `validate-plugin.sh` Layer 1: Schema validation via ajv-cli against `schemas/plugin.schema.json`
2. `validate-plugin.sh` Layer 2: Structural checks (file existence, hook permissions, directory structure)

**Quality scoring** (`score-plugin.sh`): 5 categories x 20 pts each = 100 total. Subtractive model (start at 20, deduct per failed rule). 28 rules across: Manifest Completeness, Documentation, Structure Integrity, Naming Conventions, Version Hygiene. See `QUALITY.md` for the full rubric.

**CI workflows:**
- `validate-plugins.yml` -- PR trigger. Detects changed plugins via `dorny/paths-filter`, runs validation + scoring per plugin, posts quality score as PR comment via `thollander/actions-comment-pull-request@v3` with upsert.
- `publish-marketplace.yml` -- Push-to-main trigger. Regenerates `marketplace.json` and auto-commits.

**marketplace.json format:** Must conform to Claude Code's internal schema. Only these fields are allowed per plugin entry: `name`, `description`, `version`, `author`, `source`, `category`. No custom enrichment fields -- Claude Code rejects unrecognized keys.

## Key Constraints

- **macOS bash 3.x compatibility** -- No associative arrays (`declare -A`), no GNU-specific sed/find flags. Use `jq` for all JSON manipulation.
- **Plugin schema allows additionalProperties** -- Top-level `plugin.json` intentionally allows unknown fields for forward compatibility with new Claude Code features.
- **Scoring is informational, not a merge gate** -- The scoring step uses `if: always()` and does not block validation. Quality score >= 60 gate is a future milestone target.
- **Adding a new plugin to CI** requires adding a filter entry in `validate-plugins.yml` under `dorny/paths-filter`.

## Test Fixtures

Located at `tests/fixtures/`. 4 valid + 5 invalid fixtures covering: minimal manifest, full manifest, commands-only, hooks-only, missing name, bad version, bad paths, missing files, extra fields.
