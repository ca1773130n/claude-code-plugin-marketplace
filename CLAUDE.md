# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A Claude Code plugin marketplace — hosts plugins under `plugins/` (as git submodules) and provides infrastructure for validation, quality scoring, and automated publishing via CI. The marketplace manifest at `.claude-plugin/marketplace.json` is auto-generated; never edit it by hand.

## Plugins

Three plugins are registered:
- **grd** (GetResearchDone) — R&D workflow automation, git submodule
- **HarnessSync** — Multi-backend config sync (Claude Code → Codex/Gemini/OpenCode), git submodule
- **foobar** — Example/reference plugin, local directory

## Commands

```bash
# Install dependencies (required before any script)
npm ci

# Validate a single plugin
./scripts/validate-plugin.sh plugins/foobar

# Score a plugin (human-readable)
./scripts/score-plugin.sh plugins/foobar

# Score a plugin (JSON)
./scripts/score-plugin.sh plugins/foobar --json

# Run all fixture tests (validates real plugins + 9 test fixtures)
./scripts/run-fixture-tests.sh

# Regenerate marketplace.json from all plugins
./scripts/generate-marketplace.sh

# Scaffold a new plugin
./scripts/new-plugin.sh my-plugin

# Deploy: sync submodule plugins to latest origin/main + update versions
./scripts/deploy.sh
./scripts/deploy.sh --dry-run
```

## Architecture

**Toolchain:** Bash + jq + ajv-cli (JSON Schema Draft-07). No build step. All scripts are standalone bash.

**Validation pipeline (two layers):**
1. `validate-plugin.sh` Layer 1: Schema validation via ajv-cli against `schemas/plugin.schema.json`
2. `validate-plugin.sh` Layer 2: Structural checks (file existence, hook permissions, directory structure)

**Quality scoring** (`score-plugin.sh`): 5 categories x 20 pts each = 100 total. Subtractive model (start at 20, deduct per failed rule). 28 rules across: Manifest Completeness, Documentation, Structure Integrity, Naming Conventions, Version Hygiene. See `docs/QUALITY.md` for the full rubric.

**Deploy workflow** (`deploy.sh`): Fetches origin/main for all plugin submodules, reads version from plugin.json (or git tag if HEAD is tagged), updates marketplace.json, ensures .gitmodules tracks `branch = main`, and stages everything for commit.

**CI workflows:**
- `validate-plugins.yml` — PR trigger. Detects changed plugins via `dorny/paths-filter`, runs validation + scoring per plugin, posts quality score as PR comment.
- `publish-marketplace.yml` — Push-to-main trigger. Regenerates `marketplace.json` and auto-commits.
- `self-test.yml` — Tests validation/scoring scripts against fixtures. Does not checkout submodules (private repos).

**marketplace.json format:** Auto-generated. Plugin entries use `source` as either a relative path (local plugins) or `{"source": "url", "url": "..."}` object (submodule plugins). See `schemas/marketplace.schema.json` for the full spec.

## Key Constraints

- **macOS bash 3.x compatibility** — No associative arrays (`declare -A`), no GNU-specific sed/find flags. Use `jq` for all JSON manipulation.
- **Plugin schema allows additionalProperties** — Top-level `plugin.json` intentionally allows unknown fields for forward compatibility with new Claude Code features.
- **Scoring is informational, not a merge gate** — The scoring step uses `if: always()` and does not block validation.
- **Submodule plugins are private repos** — CI workflows use `submodules: false` since GitHub Actions default token cannot access private submodule repos.
- **Version source of truth** — `plugin.json` in each plugin's `.claude-plugin/` directory. Git tags are only used when directly on origin/main HEAD.

## Project Structure

```
.
├── plugins/           # Plugin directories (submodules + local)
├── schemas/           # JSON Schema for plugin + marketplace manifests
├── scripts/           # Validation, scoring, deploy, scaffolding scripts
├── templates/         # Plugin scaffold template
├── tests/fixtures/    # 9 test fixtures (4 valid, 5 invalid)
├── docs/              # CONTRIBUTING.md, QUALITY.md
├── .github/workflows/ # CI/CD workflows
├── .claude-plugin/    # Auto-generated marketplace manifest
└── .planning/         # Planning docs (v0.0.x pre-release history)
```

## Test Fixtures

Located at `tests/fixtures/`. 4 valid + 5 invalid fixtures covering: minimal manifest, full manifest, commands-only, hooks-only, missing name, bad version, bad paths, missing files, extra fields.
