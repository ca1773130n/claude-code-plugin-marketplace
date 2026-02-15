# Phase 1: Schema & Validation Tooling - Research

**Researched:** 2026-02-10
**Domain:** JSON Schema validation, Bash scripting, plugin manifest standardization
**Confidence:** HIGH

## Summary

Phase 1 requires building two JSON Schema files (plugin manifest and marketplace manifest), a validation script, and test fixtures. The technical domain is well-established: JSON Schema Draft-07 is a mature specification with excellent tooling. The primary complexity lies not in the schema technology itself but in modeling the divergent structures of the two existing plugins -- GRD uses `commands` (array of path strings) while multi-cli-harness uses `hooks` (nested object with no commands in manifest).

The official Claude Code plugin reference (code.claude.com/docs/en/plugins-reference) documents all supported fields with their types. Only `name` is required. All component path fields accept union types (string|array, or string|array|object for hooks/mcpServers/lspServers). The schema must accommodate both plugins without requiring fields that only one plugin uses.

**Primary recommendation:** Use JSON Schema Draft-07 with ajv-cli v5.0.0 for schema validation, supplemented by a Bash+jq script for structural validation (file existence, path format, naming conventions) that ajv cannot check.

## User Constraints (from CONTEXT.md)

No CONTEXT.md exists. No prior user decisions to honor. All recommendations below are at the researcher's discretion, constrained only by the ROADMAP.md decision log:

- **JSON Schema Draft-07** (locked in ROADMAP.md decision log -- "Consistent with multi-cli-harness")
- **ajv-cli** for schema validation (locked in ROADMAP.md decision log)
- **Bash + jq** for scripting (locked in ROADMAP.md decision log)

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| ajv-cli | 5.0.0 | CLI JSON Schema validation | Official CLI for ajv, the fastest JSON Schema validator. Supports Draft-07 natively via `--spec=draft7` (which is the default). Source: [ajv-cli GitHub](https://github.com/ajv-validator/ajv-cli), [npm](https://www.npmjs.com/package/ajv-cli) |
| ajv | 8.17.1 | Underlying validation engine | Industry-standard JSON Schema validator for Node.js. Used by ajv-cli. Source: [Context7 /ajv-validator/ajv](https://github.com/ajv-validator/ajv) |
| jq | system | JSON parsing and structural validation in Bash | Standard CLI JSON processor. Available on macOS via Homebrew, on Linux via apt/yum. No version pin needed -- API is stable. |
| bash | system | Validation script | POSIX-compatible scripting. Target bash 3.2+ for macOS compatibility. |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| ajv-formats | 3.0.1 | Additional format validators for ajv | NOT needed for this phase. Draft-07 built-in formats suffice. Semver validation uses `pattern`, not `format`. |
| @jirutka/ajv-cli | 6.0.0 | Enhanced fork of ajv-cli | Alternative if ajv-cli 5.0.0 proves problematic. Better error formatting, more recent maintenance. Only adopt if original fails. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ajv-cli (npm) | python-jsonschema | Adds Python runtime dependency. ROADMAP explicitly discarded Python tooling. |
| ajv-cli (npm) | check-jsonschema (pip) | Same issue -- Python dependency. |
| Bash + jq | Node.js custom validator | ROADMAP explicitly discarded as "overkill." |
| JSON Schema Draft-07 | Draft-2020-12 | More features but less ecosystem support, and ROADMAP locks Draft-07 for multi-cli-harness consistency. |

**Installation:**
```bash
npm install -g ajv-cli@5.0.0
# Or as dev dependency in the marketplace repo:
npm install --save-dev ajv-cli@5.0.0
```

## Architecture Patterns

### Recommended Project Structure

```
claude-plugin-marketplace/
├── schemas/
│   ├── plugin.schema.json          # JSON Schema for .claude-plugin/plugin.json
│   └── marketplace.schema.json     # JSON Schema for .claude-plugin/marketplace.json
├── scripts/
│   └── validate-plugin.sh          # Combined schema + structural validation
├── tests/
│   └── fixtures/
│       ├── valid-minimal/          # Minimal valid plugin (name only)
│       │   └── .claude-plugin/
│       │       └── plugin.json
│       ├── valid-commands-only/    # Plugin with commands array (GRD-like)
│       │   ├── .claude-plugin/
│       │   │   └── plugin.json
│       │   └── workflows/
│       │       └── example.md
│       ├── valid-hooks-only/       # Plugin with inline hooks (multi-cli-harness-like)
│       │   ├── .claude-plugin/
│       │   │   └── plugin.json
│       │   └── scripts/
│       │       └── setup.sh
│       ├── valid-full/             # All optional fields populated
│       │   ├── .claude-plugin/
│       │   │   └── plugin.json
│       │   ├── commands/
│       │   ├── agents/
│       │   └── hooks/
│       │       └── hooks.json
│       ├── invalid-no-name/        # Missing required field
│       │   └── .claude-plugin/
│       │       └── plugin.json
│       ├── invalid-bad-version/    # Non-semver version string
│       │   └── .claude-plugin/
│       │       └── plugin.json
│       ├── invalid-bad-paths/      # Absolute paths or missing ./ prefix
│       │   └── .claude-plugin/
│       │       └── plugin.json
│       ├── invalid-missing-files/  # Paths referencing non-existent files
│       │   └── .claude-plugin/
│       │       └── plugin.json
│       └── invalid-extra-fields/   # Unknown top-level fields
│           └── .claude-plugin/
│               └── plugin.json
└── package.json                    # Dev dependencies (ajv-cli)
```

### Pattern 1: Two-Layer Validation

**What:** Separate schema validation (ajv) from structural validation (bash+jq). Schema handles type correctness, required fields, string patterns. Bash script handles filesystem checks that schema cannot express.

**When to use:** Always. JSON Schema cannot validate that a file path actually resolves to a file on disk.

**Example flow:**
```bash
# Layer 1: Schema validation (ajv-cli)
ajv validate -s schemas/plugin.schema.json -d "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  --spec=draft7 --all-errors --errors=text
# Exit 1 on schema failure -- no point checking files

# Layer 2: Structural validation (bash+jq)
# - Check that each path in commands[] resolves to a real file
# - Check that agent files follow naming convention
# - Check that hook scripts are executable
# - Check that ${CLAUDE_PLUGIN_ROOT} references are only in hook commands
```

### Pattern 2: Error Accumulation

**What:** Collect all errors before reporting, rather than failing on the first error. This gives the user a complete picture of what needs fixing.

**When to use:** Always for validation scripts intended for CI.

**Example:**
```bash
errors=()
# ... run checks ...
if [[ -f "$path" ]]; then
  : # ok
else
  errors+=("ERROR: File not found: $path (referenced in commands[$i])")
fi
# ... end of all checks ...
if [[ ${#errors[@]} -gt 0 ]]; then
  for err in "${errors[@]}"; do
    echo "$err" >&2
  done
  exit 1
fi
```

### Anti-Patterns to Avoid

- **Overly strict schema with `additionalProperties: false` at the top level:** The official Claude Code plugin.json format may evolve. Using `additionalProperties: false` would break validation when Claude Code adds new fields. Use `additionalProperties: false` only if you want to be strict about known fields. The safer approach is to omit it or set it to `true` and rely on CI warnings for unknown fields.
- **Validating runtime behavior in a structural validator:** The validator checks file existence and naming, NOT whether scripts actually work. Do not try to execute hook scripts during validation.
- **Requiring both commands and hooks:** Plugins legitimately use one, the other, both, or neither. The schema must not require either.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON Schema validation | Custom JSON validator in bash/jq | ajv-cli | Edge cases in Draft-07 (conditionals, oneOf, pattern) are complex. ajv handles them all correctly. |
| Semver parsing | Custom regex in bash | JSON Schema `pattern` keyword | The regex is standardized. No need for bash string manipulation. |
| JSON pretty-printing errors | Custom error formatting | ajv-cli `--errors=text` | Built-in human-readable error output is sufficient for CI. |
| Recursive file discovery | Custom find logic | `jq -r '.commands[]'` + bash loop | jq extracts paths; bash checks existence. Simple composition beats monolithic code. |

**Key insight:** The only custom code needed is the bash wrapper that orchestrates ajv-cli and performs filesystem checks. Everything else has existing tooling.

## Common Pitfalls

### Pitfall 1: JSON Schema Pattern Anchoring

**What goes wrong:** JSON Schema `pattern` keyword does NOT anchor regex by default. The pattern `"es"` matches `"expression"`. If you write `"pattern": "[0-9]+\\.[0-9]+\\.[0-9]+"` for semver, it matches `"abc1.2.3xyz"`.
**Why it happens:** JSON Schema follows ECMA 262 regex semantics where patterns are unanchored unless `^` and `$` are explicitly included.
**How to avoid:** Always include `^` and `$` anchors in patterns. For semver: `"^[0-9]+\\.[0-9]+\\.[0-9]+(-[a-zA-Z0-9.]+)?(\\+[a-zA-Z0-9.]+)?$"`.
**Warning signs:** Valid-looking data passes when it should fail.
**Source:** [JSON Schema Regular Expressions](https://json-schema.org/understanding-json-schema/reference/regular_expressions) -- "implementations must not take regular expressions to be anchored."

### Pitfall 2: oneOf vs anyOf for Union Types

**What goes wrong:** Using `oneOf` when `anyOf` would suffice. `oneOf` requires EXACTLY ONE subschema to match. If a string value like `"./commands/"` matches both the "string" branch and the first element of the "array" branch, `oneOf` fails. This is because a single string is also a valid array-of-one in some interpretations.
**Why it happens:** Developers assume `oneOf` means "one of these types" when it really means "exactly one subschema validates."
**How to avoid:** Use `anyOf` for union types like `string|array`. Use `oneOf` only when mutual exclusivity matters. Since a string cannot also be an array in JSON (they are different JSON types), `anyOf` with type constraints works cleanly and is more performant.
**Warning signs:** Valid data failing validation with "matched more than one schema" errors.
**Source:** [Context7 - JSON Schema Understanding](https://json-schema.org/understanding-json-schema/reference/combining) -- "anyOf is generally preferred over oneOf for performance when multiple options are acceptable."

### Pitfall 3: Relative Path Validation Too Strict

**What goes wrong:** Schema rejects valid paths because the regex is too restrictive. For example, requiring `^\\.\/[a-zA-Z]` would reject `./123-special/file.md`.
**Why it happens:** Underestimating the variety of valid path characters.
**How to avoid:** Keep the schema pattern simple: `"^\\.\\/.*"` (must start with `./`). Delegate detailed path validation (no `..`, no absolute paths, file existence) to the bash structural validator.
**Warning signs:** Real plugin paths failing schema validation.

### Pitfall 4: macOS bash Compatibility

**What goes wrong:** Scripts use bash 4+ features (associative arrays, `${var,,}` for lowercase) that fail on macOS which ships bash 3.2.
**Why it happens:** Linux development environment has newer bash.
**How to avoid:** Target bash 3.2. Use indexed arrays only. Use `tr '[:upper:]' '[:lower:]'` instead of `${var,,}`. Use `[[ ]]` for conditionals (supported in 3.2). Test on macOS.
**Warning signs:** "syntax error near unexpected token" on macOS.

### Pitfall 5: ajv-cli Exit Codes

**What goes wrong:** Script checks `$?` expecting 0/1 but ajv-cli may exit with other codes for different failure modes.
**Why it happens:** ajv-cli exits 0 (valid), 1 (invalid data), 2 (invalid schema or other error).
**How to avoid:** Handle exit code 2 separately -- it means the schema itself is broken, not the data. Log the distinction clearly.

## Code Examples

### Example 1: Plugin Schema Core Structure (JSON Schema Draft-07)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://claude-plugin-marketplace.example.com/plugin.schema.json",
  "title": "Claude Code Plugin Manifest",
  "description": "Schema for .claude-plugin/plugin.json",
  "type": "object",
  "required": ["name"],
  "properties": {
    "name": {
      "type": "string",
      "description": "Unique plugin identifier (kebab-case, no spaces)",
      "pattern": "^[a-z][a-z0-9-]*$",
      "minLength": 1,
      "maxLength": 64
    },
    "version": {
      "type": "string",
      "description": "Semantic version (MAJOR.MINOR.PATCH with optional pre-release)",
      "pattern": "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(-[a-zA-Z0-9]+(\\.[a-zA-Z0-9]+)*)?(\\+[a-zA-Z0-9]+(\\.[a-zA-Z0-9]+)*)?$"
    },
    "description": {
      "type": "string",
      "maxLength": 500
    },
    "author": {
      "$ref": "#/definitions/authorObject"
    },
    "homepage": {
      "type": "string",
      "format": "uri"
    },
    "repository": {
      "type": "string",
      "format": "uri"
    },
    "license": {
      "type": "string"
    },
    "keywords": {
      "type": "array",
      "items": { "type": "string" },
      "uniqueItems": true
    },
    "commands": {
      "$ref": "#/definitions/pathOrPaths"
    },
    "agents": {
      "$ref": "#/definitions/pathOrPaths"
    },
    "skills": {
      "$ref": "#/definitions/pathOrPaths"
    },
    "hooks": {
      "$ref": "#/definitions/pathOrPathsOrObject"
    },
    "mcpServers": {
      "$ref": "#/definitions/pathOrPathsOrObject"
    },
    "outputStyles": {
      "$ref": "#/definitions/pathOrPaths"
    },
    "lspServers": {
      "$ref": "#/definitions/pathOrPathsOrObject"
    }
  },
  "definitions": {
    "relativePath": {
      "type": "string",
      "pattern": "^\\.\\/.*",
      "description": "Relative path starting with ./"
    },
    "pathOrPaths": {
      "anyOf": [
        { "$ref": "#/definitions/relativePath" },
        {
          "type": "array",
          "items": { "$ref": "#/definitions/relativePath" },
          "minItems": 1
        }
      ]
    },
    "pathOrPathsOrObject": {
      "anyOf": [
        { "$ref": "#/definitions/relativePath" },
        {
          "type": "array",
          "items": { "$ref": "#/definitions/relativePath" },
          "minItems": 1
        },
        { "type": "object" }
      ]
    },
    "authorObject": {
      "type": "object",
      "required": ["name"],
      "properties": {
        "name": { "type": "string" },
        "email": { "type": "string", "format": "email" },
        "url": { "type": "string", "format": "uri" }
      },
      "additionalProperties": false
    }
  }
}
```

**Source:** Derived from official Claude Code plugin reference at [code.claude.com/docs/en/plugins-reference](https://code.claude.com/docs/en/plugins-reference), verified against both existing plugin.json files. Pattern for semver adapted from [Microsoft JSON Schemas](https://github.com/microsoft/json-schemas/blob/main/spfx/semver.schema.json).

### Example 2: Marketplace Schema Core Structure

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://claude-plugin-marketplace.example.com/marketplace.schema.json",
  "title": "Claude Code Plugin Marketplace Manifest",
  "description": "Schema for .claude-plugin/marketplace.json",
  "type": "object",
  "required": ["name", "owner", "plugins"],
  "properties": {
    "name": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9-]*$"
    },
    "owner": {
      "type": "object",
      "required": ["name"],
      "properties": {
        "name": { "type": "string" },
        "email": { "type": "string", "format": "email" }
      },
      "additionalProperties": false
    },
    "metadata": {
      "type": "object",
      "properties": {
        "description": { "type": "string" },
        "version": { "type": "string" },
        "pluginRoot": { "type": "string" }
      }
    },
    "plugins": {
      "type": "array",
      "items": {
        "$ref": "#/definitions/pluginEntry"
      },
      "minItems": 1
    }
  },
  "definitions": {
    "pluginEntry": {
      "type": "object",
      "required": ["name", "source"],
      "properties": {
        "name": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
        "source": {
          "anyOf": [
            { "type": "string" },
            { "type": "object" }
          ]
        },
        "description": { "type": "string" },
        "version": { "type": "string" },
        "author": { "$ref": "#/definitions/authorObject" },
        "homepage": { "type": "string", "format": "uri" },
        "repository": { "type": "string", "format": "uri" },
        "license": { "type": "string" },
        "keywords": { "type": "array", "items": { "type": "string" } },
        "category": { "type": "string" },
        "tags": { "type": "array", "items": { "type": "string" } },
        "strict": { "type": "boolean" },
        "commands": {},
        "agents": {},
        "hooks": {},
        "mcpServers": {},
        "lspServers": {}
      }
    },
    "authorObject": {
      "type": "object",
      "required": ["name"],
      "properties": {
        "name": { "type": "string" },
        "email": { "type": "string", "format": "email" },
        "url": { "type": "string", "format": "uri" }
      },
      "additionalProperties": false
    }
  }
}
```

**Source:** Derived from official Claude Code marketplace reference at [code.claude.com/docs/en/plugin-marketplaces](https://code.claude.com/docs/en/plugin-marketplaces).

### Example 3: ajv-cli Validation Commands

```bash
# Validate a plugin manifest against schema
ajv validate \
  -s schemas/plugin.schema.json \
  -d "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  --spec=draft7 \
  --all-errors \
  --errors=text

# Exit codes:
# 0 = valid
# 1 = invalid data (validation errors)
# 2 = schema error or other failure

# Validate marketplace manifest
ajv validate \
  -s schemas/marketplace.schema.json \
  -d .claude-plugin/marketplace.json \
  --spec=draft7 \
  --all-errors \
  --errors=text

# For JSON-structured error output (useful for CI parsing):
ajv validate \
  -s schemas/plugin.schema.json \
  -d "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  --spec=draft7 \
  --all-errors \
  --errors=json
```

**Source:** [ajv-cli GitHub README](https://github.com/ajv-validator/ajv-cli), [ajv official docs](https://ajv.js.org/packages/ajv-cli.html).

### Example 4: Structural Validation Pattern (Bash)

```bash
#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$1"
MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
errors=()

# Extract commands array and check file existence
commands=$(jq -r '.commands // empty' "$MANIFEST")
if [[ -n "$commands" ]]; then
  # Handle both string and array
  if jq -e '.commands | type == "array"' "$MANIFEST" > /dev/null 2>&1; then
    while IFS= read -r cmd_path; do
      resolved="$PLUGIN_DIR/${cmd_path#./}"
      if [[ ! -f "$resolved" ]]; then
        errors+=("File not found: $cmd_path (declared in commands)")
      fi
    done < <(jq -r '.commands[]' "$MANIFEST")
  else
    cmd_path=$(jq -r '.commands' "$MANIFEST")
    resolved="$PLUGIN_DIR/${cmd_path#./}"
    if [[ ! -f "$resolved" && ! -d "$resolved" ]]; then
      errors+=("Path not found: $cmd_path (declared in commands)")
    fi
  fi
fi

# Check agent naming convention (optional, per-plugin configurable)
if [[ -d "$PLUGIN_DIR/agents" ]]; then
  plugin_name=$(jq -r '.name' "$MANIFEST")
  for agent_file in "$PLUGIN_DIR/agents"/*.md; do
    [[ -f "$agent_file" ]] || continue
    agent_basename=$(basename "$agent_file")
    # Warn (not error) if agent doesn't follow plugin-name prefix convention
    if [[ ! "$agent_basename" =~ ^${plugin_name}- ]]; then
      echo "WARN: Agent '$agent_basename' does not follow '${plugin_name}-*' naming convention" >&2
    fi
  done
fi

# Check hook script existence and permissions
if jq -e '.hooks | type == "object"' "$MANIFEST" > /dev/null 2>&1; then
  while IFS= read -r hook_cmd; do
    # Extract path from command, handling ${CLAUDE_PLUGIN_ROOT} substitution
    script_path=$(echo "$hook_cmd" | sed 's/.*"\${CLAUDE_PLUGIN_ROOT}\///' | sed 's/".*//')
    if [[ -n "$script_path" && "$script_path" != "$hook_cmd" ]]; then
      resolved="$PLUGIN_DIR/$script_path"
      if [[ ! -f "$resolved" ]]; then
        errors+=("Hook script not found: $script_path")
      elif [[ ! -x "$resolved" && "$resolved" == *.sh ]]; then
        errors+=("Hook script not executable: $script_path (run: chmod +x)")
      fi
    fi
  done < <(jq -r '.. | .command? // empty' "$MANIFEST")
fi

# Report results
if [[ ${#errors[@]} -gt 0 ]]; then
  echo "STRUCTURAL VALIDATION FAILED (${#errors[@]} errors):" >&2
  for err in "${errors[@]}"; do
    echo "  - $err" >&2
  done
  exit 1
fi
echo "Structural validation passed."
```

### Example 5: Handling Hooks Object in Schema

The hooks field is the most complex union type. It can be:
1. A string path to a hooks.json file: `"./config/hooks.json"`
2. An array of string paths: `["./hooks/main.json", "./hooks/extra.json"]`
3. An inline object with hook event keys: `{ "SessionStart": [...] }`

```json
"hooks": {
  "anyOf": [
    {
      "type": "string",
      "pattern": "^\\.\\/.*",
      "description": "Path to hooks configuration file"
    },
    {
      "type": "array",
      "items": {
        "type": "string",
        "pattern": "^\\.\\/.*"
      },
      "description": "Array of paths to hooks configuration files"
    },
    {
      "type": "object",
      "description": "Inline hooks configuration keyed by event name",
      "patternProperties": {
        "^(PreToolUse|PostToolUse|PostToolUseFailure|PermissionRequest|UserPromptSubmit|Notification|Stop|SubagentStart|SubagentStop|SessionStart|SessionEnd|TeammateIdle|TaskCompleted|PreCompact)$": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "matcher": { "type": "string" },
              "hooks": {
                "type": "array",
                "items": {
                  "type": "object",
                  "required": ["type"],
                  "properties": {
                    "type": {
                      "type": "string",
                      "enum": ["command", "prompt", "agent"]
                    },
                    "command": { "type": "string" },
                    "timeout": { "type": "number" }
                  }
                }
              }
            }
          }
        }
      },
      "additionalProperties": false
    }
  ]
}
```

**Source:** Hook event names from [code.claude.com/docs/en/plugins-reference](https://code.claude.com/docs/en/plugins-reference). Hook types (command, prompt, agent) from the same source.

## Existing Plugin Divergence Analysis

### Exact Structural Differences

| Field | GRD plugin.json | multi-cli-harness plugin.json | Recommendation |
|-------|-----------------|-------------------------------|----------------|
| `name` | `"grd"` | `"multi-cli-harness"` | Required. Both present. |
| `version` | `"0.1.0"` | `"1.0.0"` | Optional. Both present, both valid semver. |
| `description` | Present (long) | Present (long) | Optional. Both present. |
| `author` | `{ "name": "Cameleon X" }` | `{ "name": "edward-seo" }` | Optional. Both use object with `name` only. No `email` or `url`. |
| `commands` | Array of 36 `./workflows/*.md` paths | **ABSENT** | Optional. GRD declares explicit command paths. multi-cli-harness relies on auto-discovery from `commands/` directory. |
| `hooks` | **ABSENT** | Inline object `{ "SessionStart": [...] }` | Optional. multi-cli-harness uses inline hooks. GRD has no hooks. |
| `agents` | **ABSENT** | **ABSENT** | Optional. Neither declares explicit agent paths. Both rely on auto-discovery from `agents/` directory. |
| `skills` | **ABSENT** | **ABSENT** | Optional. Neither declares explicit skill paths. |
| `homepage` | **ABSENT** | **ABSENT** | Optional. |
| `repository` | **ABSENT** | **ABSENT** | Optional. |
| `license` | **ABSENT** | **ABSENT** | Optional. |
| `keywords` | **ABSENT** | **ABSENT** | Optional. |
| `mcpServers` | **ABSENT** | **ABSENT** | Optional. |
| `outputStyles` | **ABSENT** | **ABSENT** | Optional. |
| `lspServers` | **ABSENT** | **ABSENT** | Optional. |

### How the Schema Handles Each Difference

1. **commands (GRD has it, multi-cli-harness does not):** Make `commands` optional. When present, validate it is a string or array of strings matching `^\.\/.*/`. GRD uses the array form with 36 entries -- all valid relative paths.

2. **hooks (multi-cli-harness has it, GRD does not):** Make `hooks` optional. When present, validate it is a string, array of strings, or an object with event-name keys. multi-cli-harness uses the inline object form with `SessionStart` as the event key.

3. **Neither has agents/skills/mcpServers/lspServers/outputStyles in manifest:** These are all optional per the official reference. Auto-discovery from default directories handles them. Schema marks all as optional.

4. **Both have the same core fields:** `name`, `version`, `description`, `author` are present in both. Only `name` is required. The rest should be optional but validated when present.

### Recommended Field Optionality

| Field | Required? | Rationale |
|-------|-----------|-----------|
| `name` | YES | Only required field per official spec. Both plugins have it. |
| `version` | NO | Official spec says optional. Both have it but new plugins might omit initially. |
| `description` | NO | Highly recommended but not structurally required. |
| `author` | NO | Recommended but not required. |
| `commands` | NO | Many plugins rely on auto-discovery. |
| `hooks` | NO | Most plugins have no hooks. |
| `agents` | NO | Most plugins rely on auto-discovery. |
| `skills` | NO | Most plugins rely on auto-discovery. |
| All other fields | NO | Per official spec. |

## Verification Strategy

### Recommended Verification Tiers for This Phase

| Item | Recommended Tier | Rationale |
|------|-----------------|-----------|
| Schema validates both real plugins (exit 0) | Level 1 (Sanity) | Can check immediately after schema is written |
| Schema rejects invalid fixtures (exit 1) | Level 1 (Sanity) | Can check immediately after fixtures exist |
| Structural validator catches missing files | Level 1 (Sanity) | Can check with test fixtures |
| Structural validator catches bad permissions | Level 1 (Sanity) | Can check by creating fixture with non-executable script |
| Error messages are descriptive | Level 1 (Sanity) | Human review of output |
| Schema covers 100% of fields in both plugins | Level 2 (Proxy) | Requires manual audit of plugin.json vs schema |
| CI integration works end-to-end | Level 3 (Deferred) | Phase 2 concern |

**Level 1 checks to always include:**
- `validate-plugin.sh` exits 0 for `plugins/GRD`
- `validate-plugin.sh` exits 0 for `plugins/multi-cli-harness`
- `validate-plugin.sh` exits 1 for each invalid fixture
- ajv-cli returns exit code 0 for both real plugin.json files against plugin.schema.json
- ajv-cli returns exit code 0 for marketplace.json against marketplace.schema.json

**Level 2 proxy metrics:**
- Manually verify every field present in both plugin.json files has a corresponding schema property
- Verify every field in marketplace.json has a corresponding schema property
- Run ajv with `--all-errors` and confirm zero warnings on real plugins

**Level 3 deferred items:**
- CI pipeline integration (Phase 2)
- Performance with 10+ plugins (Phase 5)
- Cross-platform bash compatibility (Phase 5)

## Experiment Design

### Recommended Validation Test Matrix

This is not an R&D experiment but a test matrix for validation correctness.

**Independent variables:**
- Plugin manifest content (valid vs. various invalid states)
- Plugin directory structure (files present vs. missing)
- Hook script permissions (executable vs. not)

**Dependent variables:**
- Exit code (0 for valid, 1 for invalid)
- Error message content (descriptive, pointing to the specific problem)
- Error count (all errors reported, not just the first)

**Test matrix:**

| Fixture | Expected Exit | Expected Error Pattern |
|---------|--------------|----------------------|
| valid-minimal | 0 | (none) |
| valid-commands-only | 0 | (none) |
| valid-hooks-only | 0 | (none) |
| valid-full | 0 | (none) |
| real: plugins/GRD | 0 | (none) |
| real: plugins/multi-cli-harness | 0 | (none) |
| invalid-no-name | 1 | "name: Required" or similar |
| invalid-bad-version | 1 | "version" + "pattern" |
| invalid-bad-paths | 1 | "pattern" + "./" |
| invalid-missing-files | 1 | "File not found" |
| invalid-extra-fields | 1 or 0 (design decision) | If strict: "additionalProperties" |

## Production Considerations

### Known Failure Modes

- **npm install failure in CI:** ajv-cli requires Node.js. If the CI runner does not have Node.js, validation fails. Prevention: Document Node.js as a prerequisite. Use `command -v ajv` check at script start with a helpful error message. Consider caching `node_modules/` in CI.
- **jq not available on runner:** Some minimal Docker images lack jq. Prevention: Check for jq at script start. Provide installation instructions in error message.
- **Path separator differences:** Windows uses `\` while macOS/Linux use `/`. The schema uses `/` in patterns. Prevention: This marketplace targets macOS/Linux (Bash scripts). Document this limitation. Windows users would need WSL.

### Scaling Concerns

- **At current scale (2 plugins):** Validation runs in under 1 second. No concerns.
- **At 10+ plugins (Phase 5 target):** Validation per-plugin is O(n) where n is the number of declared paths. Still fast. The main bottleneck would be sequential execution of validate-plugin.sh for each plugin. Mitigation: parallel execution or single-pass validation of all plugins.
- **ajv-cli cold start:** First invocation of `ajv` has a Node.js startup cost (~200ms). Subsequent invocations in the same CI job are faster if schema is cached. For 10 plugins, total ajv time should be under 5 seconds.

### Common Implementation Traps

- **Hardcoding plugin paths in the script:** Use arguments (`validate-plugin.sh <plugin-dir>`) not hardcoded paths. This makes the script reusable for any plugin, including test fixtures.
- **Forgetting to handle the string|array union in bash:** The structural validator must check `jq -e '.commands | type'` before iterating. If it is a string, treat it as a single path. If it is an array, iterate over `.commands[]`.
- **Not handling the case where plugin.json is absent:** The official spec says the manifest is optional. However, for THIS marketplace's purposes, we require it (marketplace validation depends on it). Document this requirement explicitly.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| JSON Schema Draft-04 | Draft-07 (or Draft-2020-12) | 2017 (Draft-07) | Draft-07 added `if/then/else`, `const`, `contentMediaType`. We use Draft-07 per ROADMAP decision. |
| Manual JSON validation in bash | ajv-cli | ~2018 | Standardized validation with proper error reporting. |
| ajv-cli v3.x | ajv-cli v5.0.0 | 2021 | v5 supports multiple spec versions via `--spec` flag. |

**Deprecated/outdated:**
- ajv-cli v3.x/v4.x: Do not use. v5.0.0 is the current release with `--spec` flag support.
- JSON Schema Draft-04: Lacks `if/then/else` and `const`. Draft-07 is the minimum for this project's needs.

## Open Questions

1. **Should `additionalProperties: false` be used on the top-level plugin schema?**
   - What we know: The official Claude Code plugin spec may add new fields in the future. Strict `additionalProperties: false` would break validation for plugins using new fields.
   - What's unclear: Whether this marketplace wants to be forward-compatible (allow unknown fields) or strict (reject unknown fields to catch typos).
   - Recommendation: Do NOT use `additionalProperties: false` at the top level. Use it only on nested objects like `author` where the shape is well-defined. For the top level, unknown fields should produce warnings, not errors. The bash structural validator can handle this.

2. **Should agent naming convention be enforced or warned?**
   - What we know: GRD agents follow `grd-*.md` naming. multi-cli-harness agents do not follow a `multi-cli-harness-*` pattern (they use Matrix character names).
   - What's unclear: Whether naming convention should be per-plugin or universal.
   - Recommendation: ROADMAP says "Per-plugin configurable conventions field." For now, make it a warning, not an error. Phase 3 quality scoring can deduct points for non-conventional naming.

3. **Should the schema validate hook event names?**
   - What we know: The official docs list specific event names (SessionStart, PostToolUse, etc.). Using an invalid event name would silently fail at runtime.
   - Recommendation: YES, validate event names using `patternProperties` with an enum-like regex. This catches typos early. New events can be added to the schema as Claude Code evolves.

4. **How to handle `${CLAUDE_PLUGIN_ROOT}` in path validation?**
   - What we know: This variable is only meaningful at runtime, not at validation time. Hook commands use it: `"bash \"${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh\""`.
   - Recommendation: The schema cannot validate paths containing `${CLAUDE_PLUGIN_ROOT}` because it is a runtime variable. The structural validator should extract the relative portion after `${CLAUDE_PLUGIN_ROOT}/`, resolve it against the plugin directory, and check existence. Example: extract `scripts/setup.sh` from `bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh"` and check if `<plugin-dir>/scripts/setup.sh` exists.

## Sources

### Primary (HIGH confidence)
- [Claude Code Plugins Reference](https://code.claude.com/docs/en/plugins-reference) -- Complete plugin.json schema, component types, path rules, hook events, environment variables
- [Claude Code Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) -- Marketplace schema, plugin entry fields, source types
- [Context7: /ajv-validator/ajv](https://github.com/ajv-validator/ajv) -- ajv error object interface, validation API, TypeScript types
- [Context7: /websites/json-schema_understanding-json-schema](https://json-schema.org/understanding-json-schema) -- anyOf vs oneOf semantics, additionalProperties, pattern validation, conditional schemas
- [JSON Schema Draft-07 Validation Spec](https://json-schema.org/draft-07/json-schema-validation) -- Format validators, pattern keyword, dependencies, if/then/else
- [JSON Schema Regular Expressions](https://json-schema.org/understanding-json-schema/reference/regular_expressions) -- Anchoring behavior, regex dialect, interoperability

### Secondary (MEDIUM confidence)
- [ajv-cli GitHub](https://github.com/ajv-validator/ajv-cli) -- CLI flags, error output formats, exit codes, version info
- [ajv-cli npm](https://www.npmjs.com/package/ajv-cli) -- Latest version (5.0.0), installation
- [Microsoft JSON Schemas - semver](https://github.com/microsoft/json-schemas/blob/main/spfx/semver.schema.json) -- Strict semver regex pattern
- [ajv-formats npm](https://www.npmjs.com/package/ajv-formats) -- Additional format validators (not needed for this phase)

### Tertiary (LOW confidence)
- General bash/jq patterns from [Baeldung](https://www.baeldung.com/linux/jq-command-json), [how.wtf](https://how.wtf/how-to-iterate-through-json-arrays-in-bash-using-jq.html) -- JSON iteration patterns in bash (well-known patterns, low risk)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- ajv-cli is the established tool, versions verified against npm, Context7 confirms API
- Architecture: HIGH -- Two-layer validation (schema + structural) is a well-known pattern for this type of problem
- Schema design: HIGH -- Derived directly from official Claude Code documentation, verified against both real plugins
- Pitfalls: MEDIUM -- Based on general JSON Schema experience and documentation; some pitfalls (macOS bash compat) are well-documented but not specific to this project

**Research date:** 2026-02-10
**Valid until:** 2026-04-10 (60 days -- JSON Schema Draft-07 and ajv-cli are stable, low rate of change)
