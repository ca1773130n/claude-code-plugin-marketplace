---
argument-hint: [options]
description: An example command for {{PLUGIN_NAME}} that demonstrates the command file format
---

# /example

This is an example command for the {{PLUGIN_NAME}} plugin. Replace this file with your actual command definitions.

## Usage

```
/example [options]
```

## Behavior

1. Parse the user's arguments
2. Perform the command's primary action
3. Report the results

## Options

- `--help` -- Show usage information
- `--verbose` -- Enable detailed output

## Examples

```
/example
/example --verbose
```

## Notes

- Commands are defined as Markdown files in the `commands/` directory
- Each command file should have YAML frontmatter with `description` at minimum
- The filename (without `.md`) becomes the command name
