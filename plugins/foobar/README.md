# foobar

> A Claude Code plugin

<!-- Badges placeholder: add your badges here -->
<!-- ![Version](https://img.shields.io/badge/version-1.0.0-blue) -->
<!-- ![License](https://img.shields.io/badge/license-MIT-green) -->

## Overview

foobar is a Claude Code plugin that provides [describe your plugin's main capability here]. It helps users [describe the primary use case].

## Features

- Feature 1: [Describe a key feature]
- Feature 2: [Describe another feature]
- Feature 3: [Describe another feature]

## Installation

### From the Marketplace

```bash
# Install via Claude Code plugin marketplace (when available)
claude plugin install foobar
```

### Manual Installation

1. Clone or download this plugin into your Claude Code plugins directory
2. Ensure the plugin structure is intact (`.claude-plugin/plugin.json` must exist)
3. Restart Claude Code to load the plugin

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `/example` | An example command -- replace with your actual commands |

#### `/example`

Run the example command:

```
/example [options]
```

**Options:**

- `--help` -- Show usage information
- `--verbose` -- Enable detailed output

### Agents

| Agent | Description |
|-------|-------------|
| `foobar-example-agent` | An example agent -- replace with your actual agents |

The example agent can be invoked when you need help with tasks specific to this plugin's domain.

## Configuration

This plugin does not require additional configuration out of the box. If your plugin needs configuration, document it here:

```yaml
# Example configuration (if applicable)
# setting_name: value
```

## Project Structure

```
foobar/
  .claude-plugin/
    plugin.json          # Plugin manifest
  agents/
    foobar-example-agent.md
  commands/
    example.md
  CLAUDE.md              # Development guidance
  README.md              # This file
  CHANGELOG.md           # Version history
  VERSION                # Current version
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run validation: `./scripts/validate-local.sh path/to/plugin`
5. Ensure quality score is acceptable: `./scripts/score-plugin.sh path/to/plugin`
6. Commit your changes (`git commit -m "feat: add my feature"`)
7. Push to the branch (`git push origin feature/my-feature`)
8. Open a Pull Request

### Development Guidelines

- Follow the plugin naming conventions (lowercase, hyphens)
- Prefix agent files with the plugin name
- Keep `plugin.json` in sync with actual files
- Maintain the CHANGELOG when releasing new versions

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Credits

- Built for [Claude Code](https://claude.ai/code)
- Plugin marketplace: [claude-plugin-marketplace](https://github.com/ca1773130n/claude-plugin-marketplace)
