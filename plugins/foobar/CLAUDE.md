# foobar

A Claude Code plugin

## Architecture

This plugin follows the standard Claude Code plugin structure:

```
.claude-plugin/
  plugin.json          # Plugin manifest (name, version, commands, agents)
agents/
  foobar-*.md # Agent definitions
commands/
  *.md                 # Command definitions
CLAUDE.md              # This file -- development guidance
README.md              # User-facing documentation
CHANGELOG.md           # Version history
VERSION                # Current version string
```

## Commands

| Command | Description |
|---------|-------------|
| `/example` | An example command -- replace with your actual commands |

## Agents

| Agent | Description |
|-------|-------------|
| `foobar-example-agent` | An example agent -- replace with your actual agents |

## Development

### Adding a New Command

1. Create a new `.md` file in `commands/`
2. Add YAML frontmatter with at least a `description` field
3. Add the path to the `commands` array in `.claude-plugin/plugin.json`
4. Run `validate-local.sh` to verify

### Adding a New Agent

1. Create a new `.md` file in `agents/` using the naming convention `foobar-<agent-name>.md`
2. Add YAML frontmatter with `name`, `description`, and `tools` fields
3. Add the path to the `agents` array in `.claude-plugin/plugin.json`
4. Run `validate-local.sh` to verify

### Validation

Run the local validation script before submitting a PR:

```bash
./scripts/validate-local.sh path/to/your/plugin
```

This runs both schema validation and quality scoring.

## Key Constraints

- All paths in `plugin.json` must start with `./` (relative paths)
- Agent files must use `.md` extension
- Agent filenames should be prefixed with the plugin name for consistency
- Plugin name must be lowercase with hyphens only (pattern: `^[a-z][a-z0-9-]*$`)
