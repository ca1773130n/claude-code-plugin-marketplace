# Claude Code Plugin Marketplace

A self-service marketplace infrastructure for Claude Code plugins with automated validation, quality scoring, and CI/CD publishing.

## Plugins

| Plugin | Description | Version |
|--------|-------------|---------|
| [HarnessSync](plugins/HarnessSync/) | Sync Claude Code configuration to Codex, Gemini CLI, and OpenCode | 0.1.0 |
| [GetResearchDone](plugins/GetResearchDone/) | R&D workflow automation for Claude Code | 0.1.0 |

## Quick Start

```bash
# Install dependencies
npm ci

# Validate a plugin
./scripts/validate-plugin.sh plugins/HarnessSync

# Score a plugin
./scripts/score-plugin.sh plugins/HarnessSync

# Scaffold a new plugin
./scripts/new-plugin.sh my-plugin

# Run all validation tests
./scripts/run-fixture-tests.sh
```

## Project Structure

```
.
├── plugins/           # Plugin directories
├── schemas/           # JSON Schema (Draft-07) for plugin + marketplace manifests
├── scripts/           # Validation, scoring, scaffolding, and CI scripts
├── templates/         # Plugin scaffold template
├── tests/fixtures/    # 9 test fixtures (4 valid, 5 invalid)
├── docs/              # Contributing guide, quality rubric
├── .github/workflows/ # CI/CD (PR validation, auto-publish)
├── .claude-plugin/    # Auto-generated marketplace manifest
└── .planning/         # Planning docs (v0.0.x pre-release history)
```

## How It Works

**Validation** — Two-layer pipeline via `validate-plugin.sh`:
1. Schema validation (ajv-cli against `schemas/plugin.schema.json`)
2. Structural checks (file existence, hook permissions, naming conventions)

**Quality Scoring** — `score-plugin.sh` rates plugins 0–100 across 5 categories (20 pts each): manifest completeness, documentation, structure integrity, naming conventions, version hygiene. See [docs/QUALITY.md](docs/QUALITY.md) for the rubric.

**CI/CD** — GitHub Actions workflows:
- `validate-plugins.yml` — PR trigger, validates changed plugins and posts quality score as PR comment
- `publish-marketplace.yml` — Push-to-main trigger, regenerates `marketplace.json` and auto-commits

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for the step-by-step guide.

```bash
# Scaffold, validate, and submit
./scripts/new-plugin.sh my-plugin
./scripts/validate-local.sh plugins/my-plugin
# Then open a PR
```

## Tech Stack

Bash + jq + ajv-cli + GitHub Actions. No build step. JSON Schema Draft-07.

## License

MIT
