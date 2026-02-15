#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_SCHEMA="$REPO_ROOT/schemas/plugin.schema.json"
MARKETPLACE_SCHEMA="$REPO_ROOT/schemas/marketplace.schema.json"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") <plugin-dir> [--marketplace]

Validates a Claude Code plugin using two-layer validation:
  Layer 1: JSON Schema validation via ajv-cli
  Layer 2: Structural validation (file existence, permissions, naming)

Options:
  --marketplace   Also validate marketplace.json at repo root
  --help          Show this help message

Exit codes:
  0  All validations passed
  1  Validation errors found
  2  Missing dependencies or usage error
EOF
  exit 0
}

# --- Argument parsing ---
PLUGIN_DIR=""
VALIDATE_MARKETPLACE=false

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage ;;
    --marketplace) VALIDATE_MARKETPLACE=true ;;
    -*) echo "Error: Unknown option '$arg'" >&2; exit 2 ;;
    *) PLUGIN_DIR="$arg" ;;
  esac
done

if [[ -z "$PLUGIN_DIR" ]]; then
  echo "Error: Plugin directory argument required." >&2
  echo "Usage: $(basename "$0") <plugin-dir> [--marketplace]" >&2
  exit 2
fi

# Resolve to absolute path
if [[ "$PLUGIN_DIR" != /* ]]; then
  PLUGIN_DIR="$(cd "$PLUGIN_DIR" 2>/dev/null && pwd)" || {
    echo "Error: Plugin directory '$1' not found." >&2
    exit 2
  }
fi

MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: Plugin manifest not found at $MANIFEST" >&2
  exit 2
fi

# --- Dependency checks ---
if ! command -v npx >/dev/null 2>&1; then
  echo "Error: npx not found. Install Node.js to use this validator." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found. Install jq (brew install jq) to use this validator." >&2
  exit 2
fi

if [[ ! -f "$PLUGIN_SCHEMA" ]]; then
  echo "Error: Plugin schema not found at $PLUGIN_SCHEMA" >&2
  exit 2
fi

# --- Error accumulation ---
errors=()
add_error() {
  errors+=("$1")
}

plugin_name=$(jq -r '.name // "unknown"' "$MANIFEST" 2>/dev/null)

# =========================================
# Layer 1: Schema Validation (ajv-cli)
# =========================================
schema_output=""
schema_exit=0
schema_output=$(npx ajv validate \
  -s "$PLUGIN_SCHEMA" \
  -d "$MANIFEST" \
  --spec=draft7 \
  --all-errors \
  --errors=text 2>&1) || schema_exit=$?

if [[ "$schema_exit" -eq 2 ]]; then
  echo "FATAL: Schema itself is invalid. Fix $PLUGIN_SCHEMA" >&2
  exit 2
fi

if [[ "$schema_exit" -ne 0 ]]; then
  # Extract error lines from ajv output
  while IFS= read -r line; do
    if [[ -n "$line" && "$line" != *"valid"* ]]; then
      add_error "Schema: $line"
    fi
  done <<< "$schema_output"
fi

# Skip Layer 2 if schema failed (structural checks depend on valid structure)
if [[ "$schema_exit" -ne 0 ]]; then
  echo "FAIL: $plugin_name validation failed (${#errors[@]} errors):"
  for err in "${errors[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

# =========================================
# Layer 2: Structural Validation (bash+jq)
# =========================================

# Helper: check if a file exists relative to plugin dir
check_file_exists() {
  local rel_path="$1"
  local field_name="$2"
  # Strip leading ./ for resolution
  local resolved="${rel_path#./}"
  local full_path="$PLUGIN_DIR/$resolved"
  if [[ ! -e "$full_path" ]]; then
    add_error "File not found: $rel_path (declared in $field_name)"
  fi
}

# Helper: validate path array or string field
check_path_field() {
  local field_name="$1"
  local field_type
  field_type=$(jq -r ".$field_name | type" "$MANIFEST" 2>/dev/null)

  if [[ "$field_type" == "array" ]]; then
    local count
    count=$(jq -r ".$field_name | length" "$MANIFEST")
    local i=0
    while [[ $i -lt $count ]]; do
      local path_val
      path_val=$(jq -r ".$field_name[$i]" "$MANIFEST")
      check_file_exists "$path_val" "$field_name"
      i=$((i + 1))
    done
  elif [[ "$field_type" == "string" ]]; then
    local path_val
    path_val=$(jq -r ".$field_name" "$MANIFEST")
    check_file_exists "$path_val" "$field_name"
  fi
}

# 1. File existence for commands
check_path_field "commands"

# 2. File existence for agents
check_path_field "agents"

# 3. File existence for skills
check_path_field "skills"

# 4. Hook script existence
hooks_type=$(jq -r '.hooks | type' "$MANIFEST" 2>/dev/null)
if [[ "$hooks_type" == "object" ]]; then
  # Inline hooks object - extract all command values
  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    # Check for ${CLAUDE_PLUGIN_ROOT} paths
    if [[ "$cmd" == *'${CLAUDE_PLUGIN_ROOT}'* ]]; then
      # Extract the path after ${CLAUDE_PLUGIN_ROOT}/
      local_path=$(echo "$cmd" | sed 's/.*\${CLAUDE_PLUGIN_ROOT}\///' | sed 's/".*//' | sed "s/'.*//")
      full_path="$PLUGIN_DIR/$local_path"
      if [[ ! -e "$full_path" ]]; then
        add_error "Hook script not found: $local_path (from hook command)"
      elif [[ "$local_path" == *.sh && ! -x "$full_path" ]]; then
        # 5. Hook script permissions
        add_error "Hook script not executable: $local_path (chmod +x required)"
      fi
    fi
  done < <(jq -r '.. | .command? // empty' "$MANIFEST" 2>/dev/null)
elif [[ "$hooks_type" == "string" ]]; then
  check_file_exists "$(jq -r '.hooks' "$MANIFEST")" "hooks"
elif [[ "$hooks_type" == "array" ]]; then
  check_path_field "hooks"
fi

# 6. Agent naming convention (WARNING only, not error)
agents_dir="$PLUGIN_DIR/agents"
if [[ -d "$agents_dir" ]]; then
  for agent_file in "$agents_dir"/*.md; do
    [[ -e "$agent_file" ]] || continue
    agent_basename=$(basename "$agent_file")
    # Check if agent file follows <plugin-name>-*.md naming
    expected_prefix=$(echo "$plugin_name" | tr '[:upper:]' '[:lower:]')
    if [[ "$agent_basename" != "${expected_prefix}-"* ]]; then
      echo "WARN: Agent file '$agent_basename' does not follow naming convention '${expected_prefix}-*.md'" >&2
    fi
  done
fi

# 7. Plugin directory structure check (defensive)
if [[ ! -d "$PLUGIN_DIR/.claude-plugin" ]]; then
  add_error "Missing .claude-plugin directory"
fi

# --- Optional: Marketplace validation ---
if [[ "$VALIDATE_MARKETPLACE" == true ]]; then
  marketplace_file="$REPO_ROOT/.claude-plugin/marketplace.json"
  if [[ ! -f "$marketplace_file" ]]; then
    add_error "Marketplace manifest not found at $marketplace_file"
  elif [[ -f "$MARKETPLACE_SCHEMA" ]]; then
    mp_output=""
    mp_exit=0
    mp_output=$(npx ajv validate \
      -s "$MARKETPLACE_SCHEMA" \
      -d "$marketplace_file" \
      --spec=draft7 \
      --all-errors \
      --errors=text 2>&1) || mp_exit=$?
    if [[ "$mp_exit" -ne 0 ]]; then
      add_error "Marketplace schema validation failed: $mp_output"
    fi
  fi
fi

# --- Report results ---
if [[ ${#errors[@]} -gt 0 ]]; then
  echo "FAIL: $plugin_name validation failed (${#errors[@]} errors):"
  for err in "${errors[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

echo "PASS: $plugin_name validated successfully (schema + structural)"
exit 0
