# Contributing to Claude Plugin Marketplace

Thank you for your interest in contributing a plugin! This guide walks you through
the process from start to finish.

## Prerequisites

Before you begin, make sure you have the following installed:

- **Node.js 20+** and **npm** -- required for validation tooling (ajv-cli)
- **jq** -- used for JSON manipulation in scripts
- **Git** -- for version control and submitting PRs

After cloning, install dependencies:

```bash
npm ci
```

## Quick Start (< 10 minutes)

Follow these steps to create and submit a new plugin:

1. **Fork and clone** the repository:
   ```bash
   git clone https://github.com/YOUR-USERNAME/claude-plugin-marketplace.git
   cd claude-plugin-marketplace
   ```

2. **Install dependencies:**
   ```bash
   npm ci
   ```

3. **Scaffold a new plugin:**
   ```bash
   ./scripts/new-plugin.sh my-plugin
   ```
   This creates a complete plugin skeleton at `plugins/my-plugin/` that passes
   validation and scores 100/100 on the quality rubric out of the box.

4. **Customize the generated files:**
   - Edit `plugins/my-plugin/.claude-plugin/plugin.json` with your details
   - Add your commands in `plugins/my-plugin/commands/`
   - Add your agents in `plugins/my-plugin/agents/`
   - Update `plugins/my-plugin/README.md` with your plugin's documentation
   - Update `plugins/my-plugin/CLAUDE.md` with development guidance

5. **Validate locally:**
   ```bash
   ./scripts/validate-local.sh plugins/my-plugin
   ```
   This runs schema validation, structural checks, and quality scoring.

6. **Commit and push** to your fork:
   ```bash
   git add plugins/my-plugin/
   git commit -m "feat(plugin): add my-plugin"
   git push origin main
   ```

7. **Open a PR** using the plugin submission template. GitHub will auto-populate
   the checklist when you select the "Plugin Submission" template.

## Plugin Structure

Every plugin lives under `plugins/<name>/` and follows this directory layout:

```
plugins/my-plugin/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest (required)
├── agents/               # Agent definitions (optional)
│   └── my-plugin-*.md
├── commands/             # Command definitions (optional)
│   └── *.md
├── CLAUDE.md             # Development guidance (recommended)
├── README.md             # Documentation (recommended, 50+ lines)
├── CHANGELOG.md          # Version history (recommended)
└── VERSION               # Version file (recommended)
```

The only strictly required file is `.claude-plugin/plugin.json`. However,
including all the recommended files will maximize your quality score.

## Plugin Manifest (plugin.json)

The manifest at `.claude-plugin/plugin.json` declares your plugin's metadata
and artifact paths. Here is a complete example:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "A brief description of what my plugin does",
  "author": { "name": "Your Name" },
  "homepage": "https://github.com/YOUR-USERNAME/my-plugin",
  "repository": "https://github.com/YOUR-USERNAME/my-plugin",
  "license": "MIT",
  "keywords": ["claude-code", "plugin", "your-category"],
  "commands": ["./commands/example.md"],
  "agents": ["./agents/my-plugin-example-agent.md"]
}
```

### Field Reference

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Lowercase-hyphenated, pattern: `^[a-z][a-z0-9-]*$` |
| `version` | No (recommended) | Semantic versioning, e.g., `1.0.0` |
| `description` | No (recommended) | At least 20 characters for full score |
| `author` | No (recommended) | Object with `name` field (and optional `email`, `url`) |
| `homepage` | No (recommended) | Plugin homepage URL |
| `repository` | No (recommended) | Source repository URL |
| `license` | No (recommended) | SPDX license identifier, e.g., `MIT` |
| `keywords` | No (recommended) | Array of searchable strings |
| `commands` | No | Path(s) to command `.md` files, must start with `./` |
| `agents` | No | Path(s) to agent `.md` files, must start with `./` |
| `skills` | No | Path(s) to skill files, must start with `./` |
| `hooks` | No | Hook definitions (file paths or inline object) |

All artifact paths (commands, agents, skills) must start with `./` and point to
files that actually exist on disk.

## Naming Conventions

Follow these naming rules to avoid quality score deductions:

- **Plugin name:** Lowercase letters, digits, and hyphens only. Must start with
  a letter. Examples: `my-plugin`, `code-analyzer`, `test-runner`.
- **Agent files:** Prefix with the plugin name for consistency. For example,
  a plugin named `my-plugin` should have agents like `my-plugin-analyzer.md`,
  `my-plugin-helper.md`.
- **Command files:** Place in the `./commands/` directory. Use descriptive
  filenames like `analyze.md`, `generate.md`.
- **Version:** Use semantic versioning (`X.Y.Z`). For example, `1.0.0`.

## Quality Scoring

Every plugin receives an automated quality score from 0 to 100. The score is
computed by `scripts/score-plugin.sh` across **5 categories**, each worth
**20 points**:

| Category | Points | What It Checks |
|----------|--------|----------------|
| Manifest Completeness | 20 | All optional fields populated |
| Documentation | 20 | README (50+ lines), CLAUDE.md, description length |
| Structure Integrity | 20 | Declared paths exist, no empty directories |
| Naming Conventions | 20 | Lowercase-hyphenated names, agent prefix consistency |
| Version Hygiene | 20 | Semver format, VERSION file match, CHANGELOG present |

### Tips for a High Score

- **Use version `1.0.0`** to avoid a 2-point pre-1.0 deduction (Rule 27).
- **Do NOT create empty `skills/` or `hooks/` directories** -- empty artifact
  directories incur a 2-point deduction (Rule 18). Only add these directories
  when you have files to put in them.
- **Write a README.md with at least 50 lines** covering purpose, installation,
  and usage.
- **Fill in all optional manifest fields** (description, author, homepage,
  repository, license, keywords).
- **Include a CHANGELOG.md** documenting the current version.
- **If you include a VERSION file**, make sure its content matches the `version`
  field in plugin.json.

The quality score is currently informational and does not block merges. A future
milestone may introduce a minimum score threshold (>= 60) as a merge gate.

See [QUALITY.md](QUALITY.md) for the complete scoring rubric with all 30 rules.

### Check Your Score Locally

Human-readable output:

```bash
./scripts/score-plugin.sh plugins/my-plugin
```

Machine-readable JSON:

```bash
./scripts/score-plugin.sh plugins/my-plugin --json
```

## Scaffolding Script

The `new-plugin.sh` script generates a complete plugin from the built-in template:

```bash
./scripts/new-plugin.sh <name> [--description "..."] [--author "..."]
```

### What It Creates

Running `./scripts/new-plugin.sh my-plugin` generates:

```
plugins/my-plugin/
├── .claude-plugin/
│   └── plugin.json           # Manifest with your name, description, author
├── agents/
│   └── my-plugin-example-agent.md   # Example agent (rename and customize)
├── commands/
│   └── example.md            # Example command (rename and customize)
├── CLAUDE.md                 # Development guidance template
├── README.md                 # Documentation template (119 lines)
├── CHANGELOG.md              # Initial changelog entry
└── VERSION                   # Version file (1.0.0)
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--description "..."` | "A Claude Code plugin" | Plugin description in manifest |
| `--author "..."` | `git config user.name` or "Your Name" | Author name in manifest |
| `--help` | -- | Show usage information |

### Name Validation

The script enforces naming rules and will reject:
- Names with uppercase letters (e.g., `MyPlugin`)
- Names with spaces (e.g., `my plugin`)
- Names starting with a digit (e.g., `123plugin`)
- Empty names
- Names longer than 64 characters

### Example with Custom Options

```bash
./scripts/new-plugin.sh code-analyzer \
  --description "Static analysis tools for Claude Code" \
  --author "Jane Doe"
```

## Local Validation

The `validate-local.sh` script is a convenience wrapper that runs both
validation and quality scoring in one command:

```bash
./scripts/validate-local.sh plugins/<name>
```

### What It Checks

1. **Schema validation** -- Verifies plugin.json conforms to the JSON schema
2. **Structural checks** -- Ensures declared artifact paths exist on disk
3. **Quality scoring** -- Computes and displays the quality score (informational)

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Validation passed (scoring is informational) |
| 1 | Validation failed |
| 2 | Usage error or missing directory |

Always run `validate-local.sh` before submitting a PR.

## Submitting a PR

1. Push your changes to your fork.
2. Open a pull request against `main`.
3. Select the **Plugin Submission** PR template from the template dropdown.
4. Fill in the plugin details and complete the pre-submission checklist.
5. CI will automatically run validation and post a quality score as a PR comment.

The CI pipeline validates your plugin's schema and structure, then scores it
across all 5 quality categories. The score appears as an auto-updating comment
on your PR.

## CI Configuration Note

> **Important:** The CI workflow uses `dorny/paths-filter` to detect which
> plugins changed in a PR. Each plugin must have its own filter entry in
> `.github/workflows/validate-plugins.yml`.

After your plugin is merged, a maintainer must add a filter entry for it.
The entry goes under the `filters:` key in the `detect-changes` job:

```yaml
my-plugin:
  - 'plugins/my-plugin/**'
```

Without this filter entry, future changes to your plugin will **not** trigger
CI validation on pull requests.

You do not need to add this entry yourself -- maintainers handle it after merge.
But it is helpful to mention in your PR description that this step will be needed.

## Adding Skills (Optional)

Skills are an optional plugin artifact type. Only add a `skills/` directory if
you have skill files to include.

- Declare skills in `plugin.json` under the `skills` field:
  ```json
  {
    "skills": ["./skills/my-skill.md"]
  }
  ```
- Skill paths must start with `./` and point to existing files.
- **Do NOT create an empty `skills/` directory.** Empty artifact directories
  incur a 2-point quality score deduction (Rule 18).

## Adding Hooks (Optional)

Hooks allow your plugin to run scripts in response to Claude Code lifecycle events.

Hooks can be declared inline in `plugin.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "./hooks/pre-tool.sh"
          }
        ]
      }
    ]
  }
}
```

Or as a file path reference:

```json
{
  "hooks": "./hooks/config.json"
}
```

Supported hook events include: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`,
`PermissionRequest`, `UserPromptSubmit`, `Notification`, `Stop`, `SubagentStart`,
`SubagentStop`, `SessionStart`, `SessionEnd`, `TeammateIdle`, `TaskCompleted`,
and `PreCompact`.

Hook scripts must be executable:

```bash
chmod +x hooks/pre-tool.sh
```

Non-executable hook scripts incur a 3-point quality deduction (Rule 17).

## Getting Help

- **Open an issue** using the [Plugin Request](../../issues/new?template=plugin-request.yml) template to propose a new plugin
- **Check existing plugins** (`plugins/GRD`, `plugins/multi-cli-harness`) for real-world examples
- **Read [QUALITY.md](QUALITY.md)** for the complete scoring rubric and tips for improving your score
- **Run the scaffolding script** (`./scripts/new-plugin.sh`) to see the generated template structure
