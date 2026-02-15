# Plan 01-02 Summary: validate-plugin.sh Two-Layer Validation

## Status: COMPLETE

## Artifacts Created
- `scripts/validate-plugin.sh` — Two-layer plugin validator (executable)

## Validation Layers
- **Layer 1 (Schema):** ajv-cli validates plugin.json against plugin.schema.json
- **Layer 2 (Structural):** bash+jq checks file existence, hook script permissions, agent naming

## Features
- Exit codes: 0=pass, 1=validation failure, 2=dependency/usage error
- Error accumulation: reports all errors, not just first
- `--help` flag with usage info
- `--marketplace` flag for marketplace.json validation
- Agent naming warnings on stderr (not errors)
- Handles string/array union types for commands/agents/skills
- Resolves `${CLAUDE_PLUGIN_ROOT}` in hook commands
- macOS bash 3.2+ compatible (indexed arrays only, `tr` for case)

## Smoke Test Results
- GRD: PASS (exit 0)
- multi-cli-harness: PASS (exit 0, with agent naming warnings)
- Missing name: FAIL as expected (exit 1, schema error)
- Missing file: FAIL as expected (exit 1, structural error)
- Bad version: FAIL as expected (exit 1, schema pattern error)
