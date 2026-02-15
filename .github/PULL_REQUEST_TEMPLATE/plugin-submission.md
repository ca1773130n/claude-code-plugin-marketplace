<!-- Title format: feat(plugin): add <plugin-name> -->

## Summary

<!-- Brief description of the plugin being added -->

## Plugin Details

- **Name:** <!-- lowercase-hyphenated, e.g., my-plugin -->
- **Version:** <!-- semver, e.g., 1.0.0 -->
- **Category:** <!-- development | productivity | testing | documentation | devops | research | other -->
- **Author:** <!-- your name or org -->

## Pre-submission Checklist

- [ ] Plugin is in `plugins/<name>/` directory
- [ ] `./scripts/validate-local.sh plugins/<name>` passes
- [ ] Quality score is >= 40 (run `./scripts/score-plugin.sh plugins/<name>`)
- [ ] `plugin.json` has all required fields (name, version, description, author)
- [ ] README.md exists with >= 50 lines
- [ ] CLAUDE.md exists with plugin-specific guidance
- [ ] All paths declared in plugin.json point to existing files
- [ ] No empty artifact directories (agents/, commands/, skills/)
- [ ] Version matches VERSION file (if present)
- [ ] CHANGELOG.md documents the current version

## CI Configuration

> **Important:** After merge, a maintainer must add a filter entry for your plugin
> in `.github/workflows/validate-plugins.yml` under the `dorny/paths-filter` section.
> See CONTRIBUTING.md for details.

## Testing

<!-- Describe how you tested the plugin locally -->

- [ ] Ran `./scripts/validate-local.sh plugins/<name>`
- [ ] Tested commands/agents manually in Claude Code
